# Task 7 报告

## 结果
完成。`bash tools/test.sh` 全绿：`[spell] 断言=212 失败=0`、`总计失败=0，失败套件=0`、`ALL TESTS PASSED`，退出码 0。

## 提交
`f323b55` feat(spell): 魔咒解析器与第五十五条反漏洞守卫

## 文件
- 新建：
  - `src/rules/spell_resolver.gd`（`SpellResolver`，含 `Outcome`、`GUARDS`、`cast()`、`modifiers_from()`）
  - `src/rules/spell_resolver.gd.uid`
  - `data/spells.json`（32 条魔咒）
  - `tests/spell_test.gd`（212 条断言）
  - `tests/spell_test.gd.uid`
- 修改：
  - `src/core/registry.gd`（`TABLE_FILES` 追加 `"spells": "spells.json"`）
  - `tests/run_tests.gd`（`SUITES` 在 `res://tests/creation_test.gd` 之后追加 `res://tests/spell_test.gd`）
  - `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`（同步「稀有」拦截文案修正，仅一行）

## 计划修正
计划 Step 1 的测试断言 `rare.blocked_reason.contains("稀有")`，但计划 Step 4 原实现生成的原因为
`"复制咒无法复制%s级资源：..." % target_rarity`，而 `target_rarity` 取英文 `"rare"`，得到「复制咒无法复制rare级资源…」，不含「稀有」两字，断言必红。

按简报的强制裁定修正实现与计划原文（各仅该行），改为：

```gdscript
return _blocked_outcome("复制咒无法复制稀有资源（%s）：世界资源必须有成本、有产出、有消耗" % target_rarity, guard_ids)
```

依据：`SpellResolver.RARE_RARITIES` 同时接受英文 `"rare"`/`"legendary"` 与中文 `"史诗"`/`"传奇"`/`"神话"`，
因此原因文案不能假设 `target_rarity` 一定是中文。改为「稀有资源（%s）」后，英文 rarity 也稳定包含「稀有」，
与测试意图及第五十五条「禁止复制咒无限复制稀有资源」的正典表述一致。测试实测通过。

## 测试原始输出

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
[spell] 断言=212 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```

（Step 2 的红灯证据：套件因 `SpellResolver` 未定义而 `套件无法实例化（语法错误？）: res://tests/spell_test.gd`，
`总计失败=1，失败套件=1`，`EXIT=1`。）

## 遇到的问题 / 偏离
- 除简报强制的「稀有」文案修正外，`data/spells.json`、`spell_resolver.gd`、`spell_test.gd`、
  `registry.gd`、`run_tests.gd` 均逐字照抄计划 Step 1/3/4/5，未自由发挥、未加功能。
- `Registry.validate()` 实际只校验 `label` 与表非空（不校验 `min_tier`/`guards`/`side_effects`）；
  这些数据完整性由 `tests/spell_test.gd` 逐条覆盖（32 条全部通过），不构成偏离。
- 无其它偏离。

## 修复轮 1（scoped，controller 执行，提交 3499881）

第一轮审查（见 task-7-review.md）给出 Critical=0 / Important=2 / Minor=4。controller 处置 Important #1：

- `RARE_RARITIES` 补中文「稀有」「传说」（原先只有英文 `rare/legendary` 与中文「史诗/传奇/神话」，漏了「稀有」→ 传中文 `"稀有"` 可绕过反复制守卫）。
- 补测试：中文「稀有」必须被拦、`portkey`（`requires_ministry_approval` 此前零覆盖）无批准→拦截/有批准→放行、`modifiers_from` 必须丢弃未知键（+4 断言，212 → 216）。
- 计划 Step 1/4 同步。
- 反证：移除「稀有」→ `[spell] 失败=1`，EXIT=1。

修复轮 1 复审：**通过**（#1 ADDRESSED）；提出 R1（denylist + 精确匹配仍可被繁体/大小写/空白/未知值绕过）。

## 修复轮 2（scoped，controller 执行，提交 d52ebda）

- `spell_resolver.gd`：把 denylist `RARE_RARITIES` 改为 **fail-closed 白名单** `COMMON_RARITIES = ["common","普通","常见"]`；
  `target_rarity` 先 `strip_edges().to_lower()` 归一；守卫改为「不在普通白名单内即拦截」。
- 测试：变体负例 `Rare`/`稀有 `/`傳說`/`uncommon`/`epic` 必拦，正例 `普通`/` Common ` 放行（+7 断言，216 → 223）。
- 计划 Step 1/4 与 Interfaces（`target_rarity` 说明）同步。
- 反证：去掉归一化 → `[spell] 归一化后 Common 视为普通物品: 期望为假`，失败=1。

修复轮 2 复审：**通过**（R1 ADDRESSED；独立枚举无任何绕过路径，正/负断言均非空转；无夹带）。

最终全绿：`[spell] 断言=223 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、EXIT=0。

## 未处置（留到 Task 8 / Human 裁定）

- **Important #2（Task 8 实施前必须由 Human 裁定）**：`energy_loop_count` 只在成功时自增、全代码无重置点，第 4 次成功施放基础咒（lumos/wingardium_leviosa）即**终身**封禁；Task 8 计划（2956–2958）已把该语义固化。需裁定 per-turn / per-scene / per-life，并同步改计划。
- Minor #3 `illegal_cast_count` 仅成功时自增；#4 被拦截 `Outcome` 的 `failure_rate=1.0` 语义；#5 其余测试缺口；#6 `difficulty` 为绝对偏移；R4 `常见` 零覆盖；R5 全角空白/全角拉丁被过度拦截。
