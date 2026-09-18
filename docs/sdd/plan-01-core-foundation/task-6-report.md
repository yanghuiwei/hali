# Task 6 报告

## 结果

完成。`bash tools/test.sh` 全绿：`[creation] 失败=0`、`总计失败=0，失败套件=0`、`ALL TESTS PASSED`、`全部通过。`，退出码 0。

## 提交

`f3d8a31` feat(creation): 第七十五章启动界面到玩家档案的创建流水线

（起点 `d4186c5`，工作区提交前为空；提交后 `git status --short` 为空。）

## 文件

- 新建：
  - `src/rules/character_creation.gd`（+ `.gd.uid`）
  - `data/skills.json`
  - `data/wand_woods.json`
  - `data/wand_cores.json`
  - `data/wand_flexibilities.json`
  - `data/wand_lengths.json`
  - `tests/creation_test.gd`（+ `.gd.uid`）
- 修改：
  - `src/core/registry.gd`（`TABLE_FILES` 追加 `skills`、`wand_woods`、`wand_cores`、`wand_flexibilities`、`wand_lengths`，各 1 行）
  - `tests/run_tests.gd`（`SUITES` 在 `world_tick_test.gd` 之后追加 `res://tests/creation_test.gd`）
  - `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`（计划级修正：`generate_wand` 的 `wood` 一行）

提交统计：12 files changed, 448 insertions(+), 1 deletion(-)。

## 计划修正

计划 Step 4 原文（第 2298 行）：

```gdscript
	var wood: Dictionary = rng.stream_pick("wand_wood", registry.ids("wand_woods").duplicate())
```

`RngService.stream_pick(name, options)` 返回的是被抽中的**元素**，此处即木材 id 字符串（`String`）。把它赋给类型化 `Dictionary` 变量，运行期会抛
`Trying to assign value of type 'String' to a variable of type 'Dictionary'`，测试必红。

按简报强制修正为：

```gdscript
	var wood: String = str(rng.stream_pick("wand_wood", registry.ids("wand_woods").duplicate()))
```

依据：`stream_pick` 的签名（`src/core/rng_service.gd`）为 `if options.is_empty(): return null` 后 `return options[stream(name).randi_range(0, options.size() - 1)]` —— 返回值类型跟随 `Array` 元素；传入 `PackedStringArray`（隐式转 `Array`）时元素为 `String`。`str(...)` 包裹同时兼容空表返回 `null` 的情形。后续 `registry.entry("wand_woods", str(wood))` 与 `"wood": str(wood)` 保持计划原文不变，无需改动。

同时把**计划原文**该行按上式改正（已随本次提交入库，diff 中计划文档 1 处改动即此），实现与计划现已一致。

## 测试原始输出

```
$ bash tools/test.sh; echo "EXIT=$?"
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
[creation] 断言=141 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```

（`[probe]` 是断言库自检探针，故意失败，probe 套件不在 `SUITES` 中，不计入总计。）

红灯阶段（Step 2，加入 `SUITES` 后、写数据表与实现前）退出码 1，关键行为
`Parse Error: Identifier "CharacterCreation" not declared in the current scope.` 与
`套件无法实例化（语法错误？）: res://tests/creation_test.gd`、`==== 总计失败=1，失败套件=1 ====`。

## 遇到的问题 / 偏离

- 无功能偏离。除简报强制的 `wood` 类型修正外，`data/*.json`、`character_creation.gd`、`creation_test.gd`、`registry.gd` 均逐字照抄计划 Step 1–4 代码块。
- 计划 Step 3 里「同时把测试里那两行魔杖断言改为…」的说明按简报判为冗余（Step 1 代码块已含 `wand_lengths`/`wand_cores`/`wand_woods` 正确断言），未额外改动测试。
- 数据表一致性：`skills` 19 项、`wand_woods` 16、`wand_cores` 6、`wand_flexibilities` 6、`wand_lengths` 13，全部条目均有非空 `label`；`reg.validate()` 无错误，跨表 `skill_bias` 完整性断言通过。
- `character_creation.gd.uid` 与 `creation_test.gd.uid` 由 4.7.2 导入生成并随提交入库。

## 修复轮 1（scoped，controller 执行，提交 2341540）

第一轮审查（见 task-6-review.md）给出 Critical=0 / Important=3 / Minor=5。controller 处置 2 项 Important 与 1 项 Minor：

- `character_creation.gd` `validate_choices`：`aptitude_id != "special"` 时携带 `aptitude_special` 直接报错；`create()` 只在 `aptitude_id == "special"` 时写 `p.aptitude_special` 与天赋标记（封堵反漏洞绕过）。
- `character_creation.gd` `validate_choices`：新增 `birthplace` 必须是合法 `locations` id 的校验（避免世界演化静默过滤传闻）。
- `validate_choices`：`personality` 关键词必须非空；`create()` 用 `.duplicate()` 复制性格数组。
- `tests/creation_test.gd`：新增漏洞负例、非法出生地、空关键词、哑炮不判学院共 +5 断言（141 → 146）；`sly_house` 改精确 `== "slytherin"`。
- 计划 Step 1/4 同步。

反证：临时删除 `aptitude_special` 的 `elif` 门与 `birthplace` 校验 → `[creation] 失败=3`，EXIT=1；随后还原。

修复轮 1 复审：**通过**（#1/#2 ADDRESSED，Minor #5 已收窄，无夹带）；提出 N1：`random` 可掷出 `special` 但无具体天赋。

## 修复轮 2（scoped，controller 执行，提交 61ad053）

- `character_creation.gd`：随机资质池排除条件加入 `special`（`random` 只在 `normal/good/excellent` 中掷定）。
- `tests/creation_test.gd`：随机资质循环新增 `a.ne(aptitude_id, "special", ...)`（+30 断言，146 → 176）。
- 计划 Step 1/4 同步。

反证：把 `special` 放回随机池 → `[creation] 失败=4`（30 个种子中 4 个命中），EXIT=1；随后还原。

修复轮 2 复审：**通过**（N1 ADDRESSED，新增断言非空转；无夹带）。剩余均为 Minor/Nit（`rarity` 死字段、自带魔杖长度未校验、`prejudice_level` 写入 flags、`no_magic` 部分空转、冗余写入、`assign_house` 双向 contains 过宽、存档载入不重校验），已登记入 HANDOFF §8。

最终全绿：`[creation] 断言=176 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、EXIT=0。
