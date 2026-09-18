# Task 4 报告

## 结果
完成。`bash tools/test.sh` 全绿：`[model] 断言=46 失败=0`、`==== 总计失败=0，失败套件=0 ====`、`ALL TESTS PASSED`，退出码 **0**。

## 提交
`2e3deb8` feat(model): 时钟、玩家与世界状态模型

（12 files changed, 356 insertions(+), 2 deletions(-)）

## 文件
- 新建：
  - `src/core/game_clock.gd`（+ `.gd.uid`）
  - `src/core/json_util.gd`（+ `.gd.uid`）
  - `src/model/player_state.gd`（+ `.gd.uid`）
  - `src/model/world_state.gd`（+ `.gd.uid`）
  - `tests/model_test.gd`（+ `.gd.uid`）
- 修改：
  - `tests/run_tests.gd`：`SUITES` 里 `"res://tests/magic_level_test.gd",` 之后追加 `"res://tests/model_test.gd",`
  - `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`：第 1059–1060 行（魔杖价修正，见下）

## 计划修正
依据正典 `哈利·波特·魔法纪元.md:223`（第十八章·货币与贸易系统）：

> 一根普通魔杖：7‑10加隆。

计划原文（`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`）第 1059–1060 行的测试把「买魔杖」写成扣 1 加隆（493 纳特）并标注「剩 9 加隆」，与正典的 7‑10 加隆区间冲突。按 HANDOFF 第 4 节第 9 条「正典优先」，改价格下限 7 加隆 = 7 × 493 = 3451 纳特，期望余额 4930 − 3451 = 1479 = 3 × 493，即 `"3加隆 0西可 0纳特"`。

同一修正同时落在两处，内容逐字一致：
- `tests/model_test.gd`（实际测试代码）
- 计划原文同两行（计划级修正），替换为：

```gdscript
	# 正典第十八章：一根普通魔杖 7‑10 加隆；取价格下限 7 加隆 = 7 × 493 = 3451 纳特
	p.set_money(p.money().subtract(Money.from_knuts(7 * Money.KNUTS_PER_GALLEON)))
	a.eq(p.money().formatted(), "3加隆 0西可 0纳特", "买 7 加隆普通魔杖后剩 3 加隆（正典第十八章）")
```

## 测试原始输出
红（Step 2，实现前；退出码 1）：

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
SCRIPT ERROR: Parse Error: Identifier "GameClock" not declared in the current scope.
   at: GDScript::reload (res://tests/model_test.gd:9)
   ...
ERROR: Failed to load script "res://tests/model_test.gd" with error "Parse error".
套件无法实例化（语法错误？）: res://tests/model_test.gd
==== 总计失败=1，失败套件=1 ====
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
测试失败：单测=1 冒烟=0
EXIT=1
```

绿（Step 6，提交前的最终状态；退出码 0）：

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
[model] 断言=46 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```

## 遇到的问题 / 偏离
- 计划 Step 4 块中 `from_dict` 的 `p.political_leaning_id = str(d.get("political_leading_id", d.get("political_leaning_id", "")))` 含键名拼写差异（`political_leading_id`）；按简报「逐字照抄、不自由发挥」原样保留，行为等价（取不到时回退到正确键）。
- 计划文档自身 Step 7 的 `git add` 漏了 `src/core/json_util.gd` 与计划文档；实际按**简报**给出的 `git add` 命令执行（已包含二者），未按计划 Step 7。
- 其余按计划 Step 1–7 逐字执行，无功能增减。

## 修复轮（scoped，controller 执行，提交 8264ef9）

第一轮审查（见 task-4-review.md）给出 Approved with findings（Critical=0 / Important=2 / Minor=6）。controller 处置其中 1 项 Important 与 1 项 Minor，并加 3 条回归断言，提交 `8264ef9`。

- `src/model/world_state.gd` `create()`：`duplicate(true)` → `JsonUtil.normalize((...).duplicate(true))`，使 create 与 from_dict 产出的 `world_vars` 同型（第一轮 Important #1）。
- `src/model/player_state.gd`：`political_leading_id` 拼写回退 → `political_leaning_id`（第一轮 Minor #3）。
- `tests/model_test.gd`：新增 p3（玩家状态经 JSON 字符串端到端往返）、w3（世界状态经 JSON 字符串端到端往返）、we2（`witch_hunts` 时代 create/from_dict 的 `world_vars` 类型一致）共 3 条断言；`[model]` 断言数 46 → 49。
- 计划文档 Step 1/4/5 同步为与代码逐字一致。

### 反证（证明 we2 非空转）

把 `create()` 临时改回 `duplicate(true)` 后运行 `bash tools/test.sh`：

```
[model] world_vars 类型在 create 与 from_dict 间一致: 期望 <{ "war_pressure": 0.3, "ministry_stability": 0.5, "corruption": 0.3, "pureblood_influence": 0.5, "muggle_relations": 0.1, "economy_index": 0.4, "secrecy_integrity": 1.0 }>，实际 <{ "war_pressure": 0.3, "ministry_stability": 0.5, "corruption": 0.3, "pureblood_influence": 0.5, "muggle_relations": 0.1, "economy_index": 0.4, "secrecy_integrity": 1 }>
[model] 断言=49 失败=1
==== 总计失败=1，失败套件=1 ====
测试失败：单测=1 冒烟=0
EXIT=1
```

随后已还原；最终 `bash tools/test.sh` 绿（`[model] 断言=49 失败=0`，EXIT=0）。

### 修复轮 scoped 复审

结论：**通过**——第一轮 Important #1 ADDRESSED、Minor #3 ADDRESSED、无夹带、无新代码缺陷。全文见 `task-4-review.md` 后半。
