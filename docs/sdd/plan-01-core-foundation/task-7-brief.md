# Task 7 简报：魔咒解析器与反漏洞守卫

> 给实现者（worker）的完整作业书。仓库根 = `E:/Hali`（Windows + Git Bash），分支 `plan-01-core-foundation`，
> 起点应为 `9899229`（Task 6 完成后的交接提交），工作区干净。
> **先读** `HANDOFF.md`（第 3、4、6 节）与计划原文
> `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 7: 魔咒解析器与反漏洞守卫`
> （第 2481–2857 行，Step 1–6 的完整代码块）。本简报与计划冲突时以本简报为准。

## 目标

- 新建 `src/rules/spell_resolver.gd`（`SpellResolver`）
- 新建 `data/spells.json`（32 条）
- 修改 `src/core/registry.gd`：`TABLE_FILES` 追加 `"spells": "spells.json"`
- 新建 `tests/spell_test.gd`；修改 `tests/run_tests.gd`（`SUITES` 追加 `res://tests/spell_test.gd`）

**不要**碰其它任务的文件。

## 强制裁定：计划里的拦截文案与测试断言对不上（必须修）

计划 Step 1 的测试有一条：

```gdscript
	var common := SpellResolver.cast(mid, "geminio", {"target_rarity": "common"}, RngService.new(2))
	...
	a.is_true(rare.blocked_reason.contains("稀有"), "稀有资源原因明确")
```

但计划 Step 4 的实现对 `no_rare_resource_duplication` 生成的原因是：

```gdscript
	return _blocked_outcome("复制咒无法复制%s级资源：世界资源必须有成本、有产出、有消耗" % target_rarity, guard_ids)
```

`target_rarity` 的取值是英文 `"rare"`，因此原因字符串是「复制咒无法复制rare级资源…」，**不含「稀有」两字**，该断言必红。
按正典/测试意图修正文案（实现与计划原文同步，**只改这一行**）：

```gdscript
					return _blocked_outcome("复制咒无法复制稀有资源（%s）：世界资源必须有成本、有产出、有消耗" % target_rarity, guard_ids)
```

其余不变。在报告里写明依据。

## 其它必须遵守的点

1. 除上述文案修正外，`data/spells.json`、`spell_resolver.gd`、`spell_test.gd`、`registry.gd` 的改动**逐字**按计划
   Step 1、Step 3、Step 4、Step 5 的代码块照抄，不要自由发挥、不要加功能。
2. `tests/run_tests.gd` 的 `SUITES` 在 `"res://tests/creation_test.gd",` 之后追加 `"res://tests/spell_test.gd",`。
3. GDScript 字符串里**不要**写 `\u` / `\x` 转义。
4. 新脚本的 `*.gd.uid`（`spell_resolver.gd.uid`、`spell_test.gd.uid`）必须一起提交。
5. 测试唯一入口 `bash tools/test.sh`；**不要并发跑两个 Godot 实例**。
6. **提交前必须绿灯**：`[spell] 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、退出码 0。把**原始输出**粘进报告。
7. 数据完整性：`spells` ≥24 条、每条都有非空 `label`、`min_tier` 必须是 `MagicLevel.LABELS` 中的合法标签、
   `guards` 必须全在 `SpellResolver.GUARDS` 中、`side_effects` 非空（`Registry.validate()` 与测试都会查）。

## 执行步骤

1. 确认起点：`git status --short` 为空，`git log --oneline -1` = `9899229`。
2. Step 1：创建 `tests/spell_test.gd`。
3. Step 2：把 `spell_test.gd` 加入 `SUITES`，跑 `bash tools/test.sh`，确认**红**
   （`SpellResolver` 未定义 / `缺少数据表: spells`），退出码 1。
4. Step 3：创建 `data/spells.json`。
5. Step 4：创建 `src/rules/spell_resolver.gd`（含强制的「稀有」文案修正）。
6. Step 5：在 `src/core/registry.gd` 的 `TABLE_FILES` 追加 `"spells": "spells.json"`，跑 `bash tools/test.sh` 到绿。
7. Step 6：提交（含 `.uid` 与计划文档）：

```bash
cd /e/Hali
git add src/rules/spell_resolver.gd src/core/registry.gd data/spells.json tests/spell_test.gd tests/run_tests.gd \
        src/rules/spell_resolver.gd.uid tests/spell_test.gd.uid \
        docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
git commit -m "feat(spell): 魔咒解析器与第五十五条反漏洞守卫"
```

8. **提交后立刻**写报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-7-report.md`。

## 报告格式（task-7-report.md）

```markdown
# Task 7 报告

## 结果
一句话：完成/未完成，测试是否全绿，退出码。

## 提交
<commit hash> <commit message>

## 文件
- 新建：...
- 修改：...

## 计划修正
说明「稀有」拦截文案的修正与依据。

## 测试原始输出
<粘贴 bash tools/test.sh 的完整原始输出，含 1/3、2/3、3/3 与 EXIT 码>

## 遇到的问题 / 偏离
如实记录；没有就写「无」。
```

## 完成后返回

最终输出里给出：commit hash、改动文件清单、`bash tools/test.sh` 的结论行（`[spell]` 失败数、`总计失败=0`、`ALL TESTS PASSED`、退出码）、报告文件路径。不要贴大段 diff。
