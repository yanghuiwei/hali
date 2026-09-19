# Task 1 审查记录

## 结论
- 规格符合：✅（代码逐字符合计划 Task 1；验收项 5/5 通过）
- 裁定：Approved with findings
- Critical=0 Important=1 Minor=1

## 证据

**核对 1（代码一致性 + uid 入库）**
- `tests/async_probe_test.gd` 与计划 Task 1 Step 1 代码逐字一致（17 行，`git show ccd08ef:tests/async_probe_test.gd` 与当前工作区 md5 均为 `5c2e82abe59c9a86c8e85e57521bf452`）。
- `tests/run_tests.gd` 相对 `4459586` 仅 2 处改动：`L18` 追加 `"res://tests/async_probe_test.gd",`；`L28` `await _run_suite(path)`、`L60` `await suite.run()`。其余（`report_calls` 哨兵、`quit()` 路径、注释）保持原样；`_run_suite` 与计划 Step 3 目标形态逐字一致。
- `tests/async_probe_test.gd.uid`（`uid://dhv413gv5p2dr`）已随提交入库，且 `.godot/uid_cache.bin` 中存在该 uid（无冲突）。

**核对 2（quit() 保证 + 哨兵）**
- 正常路径：`_initialize` await 后正常走到末尾 `quit(0)`，`SceneTree._initialize` 可 await，未挂住。
- 套件同步抛错（money_test 注入越界）→ `套件未正常结束（未调用 report...）` + `总计失败=1` + EXIT=1，哨兵有效。
- 套件加载失败（parse error）→ `套件无法实例化` + `总计失败=1` + EXIT=1。
- 协程 await 之后抛错（async_probe 注入越界）→ 调用方仍被唤醒，`套件未正常结束` + `总计失败=1` + EXIT=1，未挂住。
- **协程永不返回**（async_probe 注入 `await never.timeout`，6000s timer）→ `[save]` 之后无 `总计失败` 行、无 quit，进程挂住，`timeout 45` 强杀 `EXIT=124`。即 `run_tests.gd:27` 注释“保证任何情况下都以 quit(...) 结束，不会挂住进程”在 async 化后不再成立（见发现 I-1）。
- 哨兵在 async 化后仍有效：其判定在 `await suite.run()` 之后执行，语义未变（`report_calls` 未增即返回 null）。

**核对 3（反证，已还原）**
- 在 `tests/money_test.gd` 的 `run()` 顶部注入 `var arr: Array = []` / `var v = arr[0]`：输出 `SCRIPT ERROR: Out of bounds...`、`套件未正常结束`、`==== 总计失败=1，失败套件=1 ====`、EXIT=1（符合简报预期）。
- 另注入 async_probe 两种故障（await 后越界、永不返回），见上。
- 三次注入后均以备份还原，`git diff` 为空，`md5sum` 与 `ccd08ef` 内文件一致，工作区仅剩预存的未跟踪审查包 `docs/sdd/plan-02-llm-narrative/`；无残留 Godot 进程。

**核对 4（改动范围）**
- `git diff --name-only 4459586..ccd08ef` = 仅 `tests/async_probe_test.gd`、`tests/async_probe_test.gd.uid`、`tests/run_tests.gd`（3 文件）。未改 `src/`、`tests/assert.gd`、其它套件。
- `docs/sdd/plan-02-llm-narrative/review-4459586..ccd08ef.diff` 中 `== diff ==` 段与 `git diff 4459586..ccd08ef` 逐字节一致；该审查包为未跟踪文件，不计入提交。
- 分支 `plan-02-llm-narrative`，HEAD=`ccd08ef`，父=`4459586`。

**核对 5（自跑）**
- `bash tools/test.sh`：`[async_probe] 断言=2 失败=0`；`harness`→`save` 共 13 套件全部 `失败=0`；`==== 总计失败=0，失败套件=0 ====`；`ALL TESTS PASSED`；`main scene ready, godot=4.7.2-stable (official)`；`全部通过。`；EXIT=0。（还原后复跑同样 EXIT=0）

## 发现

| 严重度 | 文件:行 | 问题 | 依据 | 建议 |
| --- | --- | --- | --- | --- |
| Important | `tests/run_tests.gd:27,28,60` | “任何情况下都 quit()、不挂进程”的保证在 async 化后失效：若某套件 `run()` 的协程永不恢复（await 一个永不触发的信号/超长 timer），`await _run_suite` 永久挂起，永不 print/quit，测试进程需外部强杀。 | 反证：async_probe 注入 `await never.timeout`（6000s）后输出止于 `[save]`，无 `总计失败` 行，`timeout 45 bash tools/test.sh` 得 EXIT=124；对比 await 后抛错/加载失败/同步抛错均能正常 EXIT=1。异步化首次引入“套件可把运行器挂死”的路径。 | 二选一：①加看门狗（如 `_initialize` 内 `OS.get_ticks_msec()` 预算 + 超时强制 `quit(1)`，或每秒读秒的 watchdog），使“协程未返回”也能退出；②若判定该场景不可控/代价过高，至少修正 L25–27 注释与计划措辞，明确“协程永不返回时无法保证退出”，并在后续 HTTP provider（Task 3+）确保所有 await 都有 timeout。备份方案（call_deferred + process_frame 轮询）同样无法解决此点，故不宜作为补救。 |
| Minor | `tests/save_test.gd:79`（经 `src/model/player_state.gd:97`、`src/core/game_clock.gd:10`） | `report_calls` 哨兵只能发现“完全没调用 `report()`”的中途报错；运行中产生 SCRIPT ERROR 但仍走到 `report()` 的套件会被判为通过（`save_test` 输出 2 处 SCRIPT ERROR 却 `断言=96 失败=0`）。 | 基线输出即存在，`save_test` 为既有套件，非本提交引入；但与本任务“运行器静默假绿”的目的事关。 | 属既有现象、超出 Task 1 范围，不阻塞。可选改进：让 run_tests 解析/转发引擎错误计数（如通过 `Engine` 无接口时至少 grep stderr），或在 `save_test` 对 fail-closed 路径显式断言，消除噪声。 |

## 未验证/存疑
- `SceneTree._initialize` 中 await 与后续 Task 的 HTTP/定时器等异步依赖在真实网络挂起下的交互未验证（本任务无相关代码）；I-1 是其主要风险点。
- 提交时工作区是否干净无法回溯验证；仅确认当前 HEAD 与工作区一致、审查后无残留改动。
- “协程永不返回”为人为构造场景；是否要求提交前修复取决于计划对“任何情况”的口径（简报虽列出该场景，但计划与备份方案均未提供对应机制）。
