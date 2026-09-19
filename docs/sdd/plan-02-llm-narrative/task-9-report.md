# Task 9 报告：`TurnEngine.submit_async`

## 结果
- 绿灯通过。`[llm] 断言=51 失败=0`；既有 `[gm] 断言=63 失败=0`（语义未变）；全 16 套件失败=0；主场景 `main scene ready`；EXIT=0。
- 起点 `fed4767`（分支 `plan-02-llm-narrative`），交付提交 `878e9e3`。
- 实现逐字取自计划 `docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md` `### Task 9` Step 3，测试逐字取自 Step 1，无偏离；仅改 `src/core/turn_engine.gd` + `tests/llm_test.gd`（硬性 #1）。

## 改动（2 文件，+56/-9）
- `src/core/turn_engine.gd`（+39/-9）：把原 `submit()` 拆成三段，返回键与守卫语义逐字保留：
  - `_blank_result()`：原内联字典（`narration/deltas_applied/op_errors/events/audit/blocked`）原样提取。
  - `_pre_submit(out) -> bool`：死亡（第五十三章）+ 自检挂起（第七十二章）两个守卫，命中即 `blocked=true` 并写提示，返回 `false`。
  - `_resolve(out, result) -> Dictionary`：`StateOps.apply` → 追加 `result.warnings` 到 `op_errors`（Task 8 新增字段）→ `world.tick()` → 写回 `world.rng_state` → 第 15 回合自检 + `awaiting_audit_ack`。
  - `submit()`：`_blank_result` + `_pre_submit`；若 `gm is LlmGameMaster` 则 `push_error("submit() 不能驱动 LlmGameMaster；请用 submit_async()")`、`blocked=true` 并返回，**不推进回合**；否则 `_resolve(out, gm.act(...))`。
  - `submit_async()`：同一 `_blank_result`/`_pre_submit`，`var result = await gm.act(world, action_text)` 后 `_resolve`。
- `tests/llm_test.gd`（`return a.report("llm")` 前，+26 行）：按计划 Step 1 追加 `submit_async` 端到端用例，mock provider + `ScriptedGameMaster` 兜底、不联网。5 条断言：异步叙事透传（`你练成了。`）、`clock.turn` +1、`gain_skill(amount=99)` 经 `StateOps`/反刷后 `skill("potions") > 0`、死亡玩家 `blocked`、blocked 不推进回合。

## TDD 记录
- Step 2（实现前，`./Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd`）：
```
SCRIPT ERROR: Invalid call. Nonexistent function 'submit_async' in base 'RefCounted (TurnEngine)'.
[llm] 套件未正常结束（未调用 report，运行期错误？）
==== 总计失败=1，失败套件=1 ====
EXIT=1
```
  与计划预期方向一致（`submit_async` 不存在 → 失败）。
- Step 4（实现后）：全绿，见下。

## 提交
- `878e9e3` — `feat(core): TurnEngine.submit_async 与共用守卫/结算`
- `git show --stat`：`src/core/turn_engine.gd | 39 ++++++++++++++++++++++++++++++---------`、`tests/llm_test.gd | 26 ++++++++++++++++++++++++++`，2 files changed，未触碰其它文件。

## 验收核对（硬性 #2/#3）
- `[gm]` 全绿：63/0（与 Task 8 基线一致，`submit()` 的死亡/自检/存档往返 3 组用例全部照跑通过）。
- 新增 `submit()` 对 `LlmGameMaster` 的分支另做一次性探针（跑完即删，未提交）验证：
```
ERROR: submit() 不能驱动 LlmGameMaster；请用 submit_async()
PROBE blocked=true turn_same=true narration=
```
  即 `push_error` + `blocked=true` + 不推进回合，符合计划目标。
- 套件数：`SUITES` 实为 16 项（brief 亦写 16）；`[probe]` 是运行器自带的「故意失败探针」，不计入套件。

## 测试原始输出（完整，含 EXIT）
命令：`bash tools/test.sh` → EXIT=0
```
== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/3 单元测试 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

[probe] 故意失败: 期望 <2>，实际 <1>
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=18 失败=0
[magic_level] 断言=48 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=176 失败=0
[spell] 断言=229 失败=0
[gm] 断言=63 失败=0
[panel] 断言=71 失败=0
[selfcheck] 断言=32 失败=0
SCRIPT ERROR: Invalid assignment of property or key 'personality' with value of type 'int' on a base object of type 'RefCounted (PlayerState)'.
   at: from_dict (res://src/model/player_state.gd:97)
   GDScript backtrace (most recent call first):
       [0] from_dict (res://src/model/player_state.gd:97)
       [1] from_dict (res://src/model/world_state.gd:177)
       [2] decode (res://src/persist/save_codec.gd:81)
       [3] run (res://tests/save_test.gd:79)
       [4] _run_suite (res://tests/run_tests.gd:68)
       [5] _initialize (res://tests/run_tests.gd:36)
SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor.
   at: from_dict (res://src/core/game_clock.gd:10)
   GDScript backtrace (most recent call first):
       [0] from_dict (res://src/core/game_clock.gd:10)
       [1] from_dict (res://src/model/world_state.gd:176)
       [2] decode (res://src/persist/save_codec.gd:81)
       [3] run (res://tests/save_test.gd:79)
       [4] _run_suite (res://tests/run_tests.gd:68)
       [5] _initialize (res://tests/run_tests.gd:36)
[save] 断言=97 失败=0
[async_probe] 断言=2 失败=0
ERROR: Parse JSON failed. Error at line 0: Unexpected character
   at: parse_string (core/io/json.cpp:629)
   GDScript backtrace (most recent call first):
       [0] parse (res://src/gm/gm_response_parser.gd:20)
       [1] run (res://tests/llm_test.gd:60)
       [2] _run_suite (res://tests/run_tests.gd:68)
       [3] _initialize (res://tests/run_tests.gd:36)
       [4] _run_suite (res://tests/run_tests.gd:77)
       [5] run (res://tests/async_probe_test.gd:17)
       [6] async_double (res://tests/async_probe_test.gd:6)
ERROR: Parse JSON failed. Error at line 0: Unexpected character
   at: parse_string (core/io/json.cpp:629)
   GDScript backtrace (most recent call first):
       [0] parse (res://src/gm/gm_response_parser.gd:20)
       [1] act (res://src/gm/llm_game_master.gd:24)
       [2] run (res://tests/llm_test.gd:122)
       [3] _run_suite (res://tests/run_tests.gd:68)
       [4] _initialize (res://tests/run_tests.gd:36)
       [5] _run_suite (res://tests/run_tests.gd:77)
       [6] run (res://tests/async_probe_test.gd:17)
       [7] async_double (res://tests/async_probe_test.gd:6)
[llm] 断言=51 失败=0
[prompt] 断言=13 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

main scene ready, godot=4.7.2-stable (official)
全部通过。
EXIT=0
```
> 说明：`[probe]` 是运行器自带的「故意失败探针」，不计入套件；`save` 的 `SCRIPT ERROR` 与两条 `Parse JSON failed` 分别是 save 负路径和 llm 解析负路径的刻意日志，其断言失败数均为 0。

## 备注 / 观察（不阻塞）
- `_resolve` 现在把 `GmResult.warnings` 追加进 `op_errors`（计划 Step 3 明确要求，用于 Task 8 的 OpGuard 警告透出）。本任务的 5 条断言未直接覆盖 warnings，但 `submit_async` 走同一 `_resolve`，Task 8 的 `[llm]` 净化用例已覆盖 warnings 的产生。
- `submit_async` 是协程（内部 `await`）；若 `gm.act` 永不恢复，调用方将挂起——与 Task 1 登记的「看门狗是整轮预算」同一残余风险，Task 11 UI 接线时需注意。
- 未覆盖：`submit()` 的 `LlmGameMaster` 报错分支（计划 Step 1 未列，仅用一次性探针人工验证，未保留测试）——登记为后续候选。
