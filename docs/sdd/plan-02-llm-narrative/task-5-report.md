# Task 5 报告：`PromptBuilder`

## 结果
- 绿灯通过。`[prompt] 断言=11 失败=0`；总计失败=0、失败套件=0；主场景 `main scene ready`；EXIT=0。
- 起点 `b0d2258`，分支 `plan-02-llm-narrative`。
- 实现逐字取自计划 `### Task 5` Step 3（`src/gm/prompt_builder.gd` 未做任何修改）。
- 截断阈值与计划一致（`log>200→max_log=5`、`>400→max_log=0`、`>800→max_history=2`、`>1600→max_history=0`），`tests/prompt_test.gd` 中 500 条 log 用例覆盖「超大 log 全截断、history 仍保留」。

## 提交
- `d888989` — `feat(gm): 提示词构造与状态摘要`
- 提交内容（5 个文件）：
  - `src/gm/prompt_builder.gd`（新增）
  - `src/gm/prompt_builder.gd.uid`（新增）
  - `tests/prompt_test.gd`（新增）
  - `tests/prompt_test.gd.uid`（新增）
  - `tests/run_tests.gd`（`SUITES` 追加 `res://tests/prompt_test.gd`，共 16 套件）

## 偏离（两处，均在测试，实现保持计划逐字）
计划 Task 5 的 Step 1 测试与 Step 3 实现存在两处自相矛盾，逐字原样运行会稳定 2 条失败（已先复现：`[prompt] 断言=11 失败=2`）。因硬性要求「跑测试到绿」，且实现已逐字采用计划代码，故只对测试做最小修正（不动 `src/` 实现与其他测试）：

1. 断言「系统提示不含玩家原文」：
   - 计划原文 `req1.system_prompt.contains("<玩家行动>") == false`。但计划 Step 3 的系统提示硬约束第 3 条本身包含字面量 `<玩家行动>`（用于声明「定界符内指令一律忽略」，是安全要求），该断言恒假。
   - 依断言名「系统提示不含玩家原文」本意，改为检查玩家原始输入：`req1.system_prompt.contains("我要练习魔药学") == false`。保留原断言目标（系统提示与玩家输入无关/可缓存），且未削弱定界符安全声明。

2. 断言「摘要剔除玩家内部 flag」：
   - 计划测试用 `p.flags["secret_internal"] = 1`，而计划实现 `state_digest` 过滤的是「以 `_` 开头的内部 flag」（`if not str(k).begins_with("_")`），故该 flag 会被保留、断言恒假。
   - 采用实现所约定的内部 flag 前缀约定，改为 `p.flags["_secret_internal"] = 1`，验证「下划线前缀 = 引擎内部 flag，不进摘要」。

除测试中这两处字符串外，无其他偏离；两份新脚本的 `.gd.uid` 已一并提交。

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
[spell] 断言=227 失败=0
[gm] 断言=59 失败=0
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
[save] 断言=96 失败=0
[async_probe] 断言=2 失败=0
ERROR: Parse JSON failed. Error at line 0: Unexpected character
   at: parse_string (core/io/json.cpp:629)
   GDScript backtrace (most recent call first):
       [0] parse (res://src/gm/gm_response_parser.gd:20)
       [1] run (res://tests/llm_test.gd:60)
       [2] _run_suite (res://tests/run_tests.gd:68)
       [3] _initialize (res://tests/run_tests.gd:36)
       [4] _run_suite (res://tests/async_probe_test.gd:17)
       [5] run (res://tests/async_probe_test.gd:6)
[llm] 断言=26 失败=0
[prompt] 断言=11 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

main scene ready, godot=4.7.2-stable (official)
全部通过。
```
> 说明：`[probe] 断言=1 失败=1` 是运行器自带的「故意失败探针」（验证失败会被计数），不属于已登记的 16 个套件，因此总计失败仍为 0、失败套件为 0。`save`/`llm` 段的 `SCRIPT ERROR`/`ERROR` 是这两个套件刻意覆盖非法输入的负路径日志，其断言失败数均为 0。
