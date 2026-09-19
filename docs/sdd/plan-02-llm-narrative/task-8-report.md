# Task 8 报告：`GmResult.warnings` + `LlmGameMaster`

## 结果
- 绿灯通过。`[llm] 断言=46 失败=0`；总计失败=0、失败套件=0；主场景 `main scene ready`；EXIT=0。
- 起点 `59a70ed`（分支 `plan-02-llm-narrative`），交付提交 `fed4767`。
- 实现逐字取自计划 `docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md` `### Task 8` Step 3，测试逐字取自 Step 1，无偏离；`SUITES` 未改动，未触碰其它文件。

## 改动（4 文件，+86）
- `src/gm/game_master.gd`（+1 行）：`GmResult` 增加 `var warnings: PackedStringArray = PackedStringArray()`（`tags` 与 `audit_required` 之间）。
- `src/gm/llm_game_master.gd`（新建，55 行）
  - `MAX_ATTEMPTS=2`、`FALLBACK_NOTE="（叙事引擎暂不可用，已用本地规则结算）"`；字段 `provider` / `fallback` / `last_error`。
  - `act`：无 provider 直接降级；否则最多 2 次尝试——provider 报错则下一次重新发原请求，JSON 解析失败则改用 `PromptBuilder.build_repair(world, action, parsed.error)` 再试；两次后仍失败即降级，`reason` 依次取「无响应 / provider.error / parser.error」。
  - 成功路径：`OpGuard.sanitize_detailed(world, parsed.ops)` → `deltas = guard.ops`、`warnings = guard.warnings`（其余 `narration`/`tags` 透传）。
  - `_fallback`：记录 `last_error`；无 fallback 时产出 `FALLBACK_NOTE（原因：...）`，有 fallback 时调用其 `act` 并追加 `FALLBACK_NOTE`。
- `src/gm/llm_game_master.gd.uid`（新建，Godot 生成的资源 UID，一并提交）。
- `tests/llm_test.gd`（`return a.report("llm")` 前，+29 行）：按计划 Step 1 追加 LlmGameMaster 用例：5 条断言（重试后拿到叙事、`gain_skill`→`train_skill` 净化、tags 透传、全失败降级含「本地规则结算」、无 provider 也有叙事）。

## TDD 记录
- Step 2（实现前，`bash tools/test.sh`）：预期 `LlmGameMaster not declared` / `GmResult` 无 `warnings`、EXIT=1。实测为同一根因的连锁报错（脚本无法编译）：
```
SCRIPT ERROR: Parse Error: Cannot infer the type of "gm3" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/llm_test.gd:134)
ERROR: Failed to load script "res://tests/llm_test.gd" with error "Parse error".
套件无法实例化（语法错误？）: res://tests/llm_test.gd
[prompt] 断言=13 失败=0
==== 总计失败=1，失败套件=1 ====
测试失败：单测=1 冒烟=0
```
  `test.sh` 判定失败（`测试失败`），与计划预期方向一致。
- Step 4（实现后）：全绿，见下。

## 提交
- `fed4767` — `feat(gm): LlmGameMaster（重试 + 降级 + 净化）`
- 仅 `src/gm/game_master.gd`、`src/gm/llm_game_master.gd`、`src/gm/llm_game_master.gd.uid`、`tests/llm_test.gd` 四个文件，未触碰其它 `src/`／`tests/*`。

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
[llm] 断言=46 失败=0
[prompt] 断言=13 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

main scene ready, godot=4.7.2-stable (official)
全部通过。
```
> 说明：`[probe]` 是运行器自带的「故意失败探针」，不计入套件；`save` 的 `SCRIPT ERROR` 与两条 `Parse JSON failed` 分别是 save 负路径和 llm 解析负路径的刻意日志，其断言失败数均为 0。

## 备注 / 观察（不阻塞）
- brief 写「全 17 套件失败=0」，但 `tests/run_tests.gd` 的 `SUITES` 实为 16 项（harness/registry/money/magic_level/model/clock/world_tick/creation/spell/gm/panel/selfcheck/save/async_probe/llm/prompt）。Task 7 报告同样沿用了「17」，属历史笔误；本次未改 `SUITES`（硬性 #1 只允许改 3 类文件）。实际「16 套件 + 1 探针 = 0 失败」。
- `MAX_ATTEMPTS=2` 表示「首次 + 重试 1 次」；两次都解析失败时，第二次的 request 已带 `build_repair` 提示，符合任务目标的「重试 + 解析失败用 build_repair 再试」。
- `nl.ops` 为空数组时 `sanitize_detailed` 返回空 `deltas`，`warnings` 也为空；本任务未对空 ops 做额外告警（计划未要求）。
- 未新增覆盖：`last_error` 内容、`MAX_ATTEMPTS` 恰为 2 次的调用计数断言、`warnings` 实际填充路径——计划 Step 1 未列，登记为后续候选。
