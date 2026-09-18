# Task 8 报告

## 结果
完成。`bash tools/test.sh` 全绿：`[gm] 断言=38 失败=0`、`总计失败=0，失败套件=0`、`ALL TESTS PASSED`、`全部通过。`，退出码 0。

## 提交
`432adc8` feat(gm)：叙事接口、状态操作、反刷成长与回合引擎

起点为 `79d15aa`（Task 7 收尾交接），开工时 `git status --short` 为空。提交后工作区干净。

## 文件
- 新建：
  - `src/gm/game_master.gd`（+`.gd.uid`）
  - `src/gm/scripted_game_master.gd`（+`.gd.uid`）
  - `src/rules/state_ops.gd`（+`.gd.uid`）
  - `src/rules/progression.gd`（+`.gd.uid`）
  - `src/rules/self_check.gd`（+`.gd.uid`，任务 8 最小桩，任务 9 替换）
  - `src/core/turn_engine.gd`（+`.gd.uid`）
  - `tests/gm_test.gd`（+`.gd.uid`）
- 修改：
  - `tests/run_tests.gd`：`SUITES` 在 `"res://tests/spell_test.gd",` 之后追加 `"res://tests/gm_test.gd",`
  - `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`：同步两处强制修正

除两处强制修正外，六个实现脚本、测试、registry 均逐字照抄计划 Step 1/3/4/5/6 的代码块。

## 计划修正

### 修正 1：Progression 测试 `total` 漏加 g2/g3（计划 Step 1）
按 `Progression.gain`（`factor = 1/(1+repeats)`，向下取整）在同一地点（`hogwarts`）、`clock.turn` 恒为 0（窗口内）逐次推算：

| 调用 | repeats | factor | `int(4*factor)` |
| --- | --- | --- | --- |
| call1 (g1) | 0 | 1/1 | 4 |
| call2 (g2) | 1 | 1/2 | 2 |
| call3 (g3) | 2 | 1/3 | 1 |
| call4（循环第 1 次） | 3 | 1/4 | 1 |
| call5..call23 | ≥4 | ≤1/5 | 0 |

23 次总和 = 4+2+1+1 = 8。原代码 `total := g1` 只加了首次的 4，再跑 20 次（call4..call23）得 `4+1 = 5`，断言必红。按注释意图（23 次总和 = 4+2+1+1 = 8）改为 `var total := g1 + g2 + g3`，得 `7+1 = 8`。计划原文该行已同步。

### 修正 2：未知行动测试文本误撞 REST 关键词「发呆」（计划 Step 1）
`REST_KEYWORDS` 含「发呆」，原文 `"我对着墙发呆并思考宇宙的尽头"` 会先命中 REST 分支拿到 `rest` 标签，导致 `tags.has("idle")` 必红。按测试意图（未知行动 → idle）改为不含任何关键词的 `"我对着墙思考宇宙的尽头"`（不含 TRAIN/WORK/SOCIAL/REST/CAST 关键词，且无魔咒 label 命中）。`REST_KEYWORDS` 本身未改。计划原文该行已同步。

## 测试原始输出

### Step 2：加入套件后确认红（`StateOps` 未定义）
```
== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/3 单元测试 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

[probe] 故意失败: 期望 <2>，实际 <1>
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=15 失败=0
[magic_level] 断言=22 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=176 失败=0
[spell] 断言=227 失败=0
SCRIPT ERROR: Parse Error: Identifier "StateOps" not declared in the current scope.
   at: GDScript::reload (res://tests/gm_test.gd:23)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:45)
       [1] _initialize (res://tests/run_tests.gd:24)
（……同类 Parse Error 省略，均为 StateOps / Progression / ScriptedGameMaster / TurnEngine 未声明……）
ERROR: Failed to load script "res://tests/gm_test.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:45)
       [1] _initialize (res://tests/run_tests.gd:24)
套件无法实例化（语法错误？）: res://tests/gm_test.gd
==== 总计失败=1，失败套件=1 ====
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
测试失败：单测=1 冒烟=0
EXIT=1
```

### Step 7：实现后确认绿
```
== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/3 单元测试 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

[probe] 故意失败: 期望 <2>，实际 <1>
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=15 失败=0
[magic_level] 断言=22 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=176 失败=0
[spell] 断言=227 失败=0
[gm] 断言=38 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```

## 遇到的问题 / 偏离
无。`self_check.gd` 按计划保留为任务 8 最小桩（任务 9 用完整实现替换），未自行扩展。

## 审查（Task 8 无修复轮）

第一轮审查（见 task-8-review.md）给出 Critical=0 / **Important=3** / Minor=5。三处 Important 均为**计划级/架构级**：

1. `StateOps.world_gm_rng` 每次调用新建 RNG（`game_seed + turn*15485863`）→ 同一回合内所有 `cast_spell` 掷出同一 `spell_roll`、失败副作用也相同；
2. `TurnEngine.rng` 从不掷数，而真正影响叙事的 `ScriptedGameMaster.rng` 未入 `world.rng_state` → 读档后叙事随机流从头开始（与 HANDOFF §8#17 `rng_state` 死字段同源）；
3. `ScriptedGameMaster.act` 直接改世界（`SpellResolver.cast` / `Progression.gain`），绕过 `StateOps`（计划内已文档化，HANDOFF §8#3），审查补充了三条新后果：副作用不进 `deltas_applied`、被拦截施法无 `op_errors`、`last_cast_*` flag 在生产路径恒不可达。

按 HANDOFF 流程（Task 5 先例），这三项与 5 条 Minor **不在 Task 8 内修复**，登记进 HANDOFF §8，交后续任务/人类裁定。两处强制修正经 reviewer 独立核对为「唯一正确、无夹带」，其余 7 个计划代码块与代码逐字一致。
