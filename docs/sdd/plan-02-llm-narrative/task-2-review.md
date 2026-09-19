# Task 2 审查记录

## 结论
- **规格：✅ 通过**（计划 Task 2 逐字落地，nested 类型已限定，`.uid` 入库，无越界改动；自跑测试全绿 EXIT=0）
- **裁定：可通过**（无需修改；唯一 Minor 为计划文档内部断言数矛盾，已由报告如实记录，不影响代码规格）
- **Critical = 0 / Important = 0 / Minor = 1**

## 证据

**提交与改动面**
- `git log`：`a33a33a feat(gm): LlmProvider 接口与 Mock provider`，父 `f44c50d`，分支 `plan-02-llm-narrative`。
- `git diff --name-status f44c50d..a33a33a`：6×`A` + 1×`M`
  - A `src/gm/llm_provider.gd`、`src/gm/llm_provider.gd.uid`、`src/gm/providers/mock_provider.gd`、`src/gm/providers/mock_provider.gd.uid`、`tests/llm_test.gd`、`tests/llm_test.gd.uid`
  - M `tests/run_tests.gd`
- `git show --stat HEAD`：`7 files changed, 80 insertions(+)`，`tests/run_tests.gd | 1 +`（纯 +1，0 删除）。`tests/assert.gd` 与其它 `src/`、`tests/*` 均不在 diff 中。

**与计划 Task 2 逐字一致（脚本级 diff）**
从计划 `### Task 2`（第 153–275 行）抽取三处代码块与工作区文件做 `diff`：
```
== test diff ==     OK_TEST
== provider diff == OK_PROVIDER
== mock diff ==     OK_MOCK
```
- `src/gm/llm_provider.gd`：`LlmProvider extends RefCounted` + 内嵌 `LlmRequest`/`LlmResponse`；基类 `complete()` 返回 `未实现的 provider`。
- `src/gm/providers/mock_provider.gd`：签名使用限定类型 `LlmProvider.LlmRequest` / `LlmProvider.LlmResponse`（brief 要点满足）。
- `tests/llm_test.gd`：与计划 Step 1 完全一致（`class_name LlmTest`）。

**`.uid` 入库且稳定**
- `git ls-files '*.uid'` 含三个新 uid；内容 `uid://y0nnuht4jsox` / `uid://myoqnhxl4fgt` / `uid://0p5msw86bl7v`，与 diff 中 index 一致。
- 跑完 `bash tools/test.sh`（含 `--import` 重建 `.godot` 缓存）后 `git status --short` 仅剩未跟踪的审查 diff 文件，`.uid` 未被引擎改写 → 入库 uid 稳定有效。

**Mock 语义核对（代码 + 用例）**
- 错误优先：先查 `errors[index]` 非空即返回 `r.error`（`ok` 保持 false），再查 `queue`。
- 越界返失败：`index >= queue.size()` → `r.error = "mock 队列为空"`、`ok=false`。
- requests 记录：每次 `complete` 先 `requests.append(request)`，`index = size-1` 与 `errors`/`queue` 对齐。
- `await` 同步函数：`run()` 内 3 处 `await mock.complete(req)` + 2 处 `await mock2.complete(req)`；测试正常打印 `[llm] 断言=9 失败=0`，说明未抛“非协程不可 await”类错误，取值正确（若返回 null，typed `LlmProvider.LlmResponse` 赋值会报错中止且被 runner 的 `report_calls` 哨兵捕获）。
- 断言计数：`grep -o 'a\.[a-z_]*' tests/llm_test.gd` → `eq×5 + is_false×2 + is_true×2 + report×1`，9 条断言全部执行。

**自跑测试（`bash tools/test.sh`）**
```
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=18 失败=0
[magic_level] 断言=48 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=176 失败=0
[spell] 断言=227 失败=0
[gm] 断言=59 失败=0
[panel] 断言=71 失败=0
[selfcheck] 断言=32 失败=0
[save] 断言=96 失败=0
[async_probe] 断言=2 失败=0
[llm] 断言=9 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
main scene ready, godot=4.7.2-stable (official)
全部通过。
EXIT=0
```
- `[probe] 失败=1` 为 `harness_test.gd` 历来故意探针，不计入总计。
- 两条 `SCRIPT ERROR`（`player_state.gd:97`、`game_clock.gd:10`）来自 `save_test` 畸形存档用例，`[save] 失败=0`，基线既有、非本任务引入。
- 既有 14 套件（harness…async_probe）失败均为 0，加入 `llm_test` 后运行器共 15 套件、`失败套件=0`，满足 brief 语义。

## 发现表

| # | 级别 | 位置 | 发现 | 证据 | 处置 |
|---|------|------|------|------|------|
| 1 | Minor | 计划文档 `### Task 2` Step 4 vs Step 1 代码块 | 计划 Step 4 期望 `[llm] 断言=10`，但 Step 1 逐字代码只有 9 条断言（`eq×5`/`is_false×2`/`is_true×2`）；task-2-brief 硬性第 3 条亦沿用 10。审查 brief 已改为预期 9。 | `grep -c '^\s*a\.' tests/llm_test.gd` → 9；计划 Step 4 原文 “`[llm] 断言=10 失败=0`” | 非阻断。worker 以「逐字用计划代码」优先并在报告「偏离 1」如实记录；无需改代码。建议后续任务顺手修正计划文本或补一条断言。 |
| 2 | Minor（观察） | `tests/llm_test.gd` | 计划用例未覆盖基类 `LlmProvider.complete()` 的默认失败路径，且第二次成功仅断言 `r2.text` 未断言 `r2.ok`。 | 计划 Task 2 代码为逐字抄录范围，非本任务要求 | 不要求本任务处理；Task 3+ 扩充测试时可补。 |

## 未验证
- 未验证 Mock/接口在后续任务（Task 3 `LlmSettings`、Task 10 `OpenAiCompatProvider` 等）中的适配性——超出 Task 2 范围。
- 未独立构造新用例验证 `await` 非协程返回值的引擎级语义，仅通过现有套件执行结果与 typed 赋值推断（无报错、9/9 断言执行且失败=0）。
- 未核对计划中 `断言=10` 是否原本意图包含一条被遗漏的断言；仅确认现状与 Step 1 代码逐字一致。
- 未验证工作区外（如 CI/其它机器）`.uid` 生成稳定性，仅确认本机 `--import` 后未被改写。
