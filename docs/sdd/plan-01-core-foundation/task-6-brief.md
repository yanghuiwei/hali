# Task 6 简报：角色创建流水线

> 给实现者（worker）的完整作业书。仓库根 = `E:/Hali`（Windows + Git Bash），分支 `plan-01-core-foundation`，
> 起点应为 `d4186c5`（Task 5 完成后的交接提交），工作区干净。
> **先读** `HANDOFF.md`（第 3、4、6 节）与计划原文
> `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 6: 角色创建流水线`
> （第 1896–2448 行，Step 1–6 的完整代码块）。本简报与计划冲突时以本简报为准。

## 目标

- 新建 `src/rules/character_creation.gd`（`CharacterCreation`）
- 新建 `data/skills.json`、`data/wand_woods.json`、`data/wand_cores.json`、`data/wand_flexibilities.json`、`data/wand_lengths.json`
- 修改 `src/core/registry.gd`：`TABLE_FILES` 追加 `skills`、`wand_woods`、`wand_cores`、`wand_flexibilities`、`wand_lengths`
- 新建 `tests/creation_test.gd`；修改 `tests/run_tests.gd`（`SUITES` 追加 `res://tests/creation_test.gd`）

**不要**碰其它任务的文件。

## 强制裁定：计划里的 `generate_wand` 有一处类型错误（必须修）

计划 Step 4 的 `generate_wand` 第一行写成：

```gdscript
	var wood: Dictionary = rng.stream_pick("wand_wood", registry.ids("wand_woods").duplicate())
```

`stream_pick` 返回的是被抽中的**元素**（这里是木材 id 字符串），把它赋给 `Dictionary` 类型变量会在运行期报
`Trying to assign value of type 'String' to a variable of type 'Dictionary'`，测试必红。改为：

```gdscript
	var wood: String = str(rng.stream_pick("wand_wood", registry.ids("wand_woods").duplicate()))
```

其余不变（后面的 `registry.entry("wand_woods", str(wood))` 与 `"wood": str(wood)` 无需改动）。
同时把**计划原文**这一行也改成上面的形式（计划级修正），并在报告里写明依据。

> 已用探针验证：`stream_pick(name, PackedStringArray)` 可正常接受 PackedStringArray（隐式转 Array），返回 String，无需额外包裹 `Array(...)`。

## 其它必须遵守的点

1. 除上述 `wood` 修正外，`data/*.json`、`character_creation.gd`、`creation_test.gd`、`registry.gd` 的改动**逐字**按计划
   Step 1–4 的代码块照抄，不要自由发挥、不要加功能。
   - 计划 Step 3 里那句「同时把测试里那两行魔杖断言改为…」是冗余说明：Step 1 的测试代码块**已经**包含
     `wand_lengths`/`wand_cores`/`wand_woods` 的正确断言，直接照抄 Step 1 即可。
2. `tests/run_tests.gd` 的 `SUITES` 在 `"res://tests/world_tick_test.gd",` 之后追加 `"res://tests/creation_test.gd",`。
3. GDScript 字符串里**不要**写 `\u` / `\x` 转义。
4. 新脚本的 `*.gd.uid`（`character_creation.gd.uid`、`creation_test.gd.uid`）必须一起提交。
5. 测试唯一入口 `bash tools/test.sh`；**不要并发跑两个 Godot 实例**。
6. **提交前必须绿灯**：`[creation] 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、退出码 0。把**原始输出**粘进报告。
7. 数据表一致性：`skills` 至少 19 项、`wand_woods` ≥10、`wand_cores` ≥6、`wand_lengths` ≥10；
   所有表条目都要有非空 `label`（`Registry.validate()` 强制）。

## 执行步骤

1. 确认起点：`git status --short` 为空，`git log --oneline -1` = `d4186c5`。
2. Step 1：创建 `tests/creation_test.gd`。
3. Step 2：把 `creation_test.gd` 加入 `SUITES`，跑 `bash tools/test.sh`，确认**红**
   （`CharacterCreation` 未定义 / `缺少数据表: skills`），退出码 1。
4. Step 3：创建 `data/skills.json` 与四张魔杖表；修改 `src/core/registry.gd` 的 `TABLE_FILES`。
5. Step 4：创建 `src/rules/character_creation.gd`（含强制的 `wood` 修正）。
6. Step 5：跑 `bash tools/test.sh` 到绿，记录原始输出。
7. Step 6：提交（含 `.uid` 与计划文档）：

```bash
cd /e/Hali
git add src/rules/character_creation.gd src/core/registry.gd \
        data/skills.json data/wand_woods.json data/wand_cores.json data/wand_flexibilities.json data/wand_lengths.json \
        tests/creation_test.gd tests/run_tests.gd \
        src/rules/character_creation.gd.uid tests/creation_test.gd.uid \
        docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
git commit -m "feat(creation): 第七十五章启动界面到玩家档案的创建流水线"
```

8. **提交后立刻**写报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-6-report.md`。

## 报告格式（task-6-report.md）

```markdown
# Task 6 报告

## 结果
一句话：完成/未完成，测试是否全绿，退出码。

## 提交
<commit hash> <commit message>

## 文件
- 新建：...
- 修改：...

## 计划修正
说明 generate_wand 的 `wood` 类型修正与依据。

## 测试原始输出
<粘贴 bash tools/test.sh 的完整原始输出，含 1/3、2/3、3/3 与 EXIT 码>

## 遇到的问题 / 偏离
如实记录；没有就写「无」。
```

## 完成后返回

最终输出里给出：commit hash、改动文件清单、`bash tools/test.sh` 的结论行（`[creation]` 失败数、`总计失败=0`、`ALL TESTS PASSED`、退出码）、报告文件路径。不要贴大段 diff。
