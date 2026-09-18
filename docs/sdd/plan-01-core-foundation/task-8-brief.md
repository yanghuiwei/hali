# Task 8 简报：叙事接口 + 状态操作 + 反刷成长 + 回合引擎

> 给实现者（worker）的完整作业书。仓库根 = `E:/Hali`（Windows + Git Bash），分支 `plan-01-core-foundation`，
> 起点应为 `79d15aa`（Task 7 收尾后的交接提交），工作区干净。
> **先读** `HANDOFF.md`（第 3、4、6 节，尤其 §8 第 27 条已裁定的 per-turn 语义）与计划原文
> `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 8`（第 2886–3401 行，Step 1–8）。
> 本简报与计划冲突时以本简报为准。

## 目标

- 新建 `src/gm/game_master.gd`（`GameMaster` + 内嵌 `GmResult`）
- 新建 `src/gm/scripted_game_master.gd`（`ScriptedGameMaster extends GameMaster`）
- 新建 `src/rules/state_ops.gd`（`StateOps`）
- 新建 `src/rules/progression.gd`（`Progression`）
- 新建 `src/rules/self_check.gd`（**任务 8 的最小桩**，任务 9 用完整实现替换；计划明说，属刻意安排）
- 新建 `src/core/turn_engine.gd`（`TurnEngine`）
- 新建 `tests/gm_test.gd`；修改 `tests/run_tests.gd`（`SUITES` 追加 `res://tests/gm_test.gd`）

**不要**碰其它任务的文件（`src/model/`、`src/core/rng_service.gd` 等保持不动）。

## 强制裁定 1：Progression 测试的 `total` 少加了 g2/g3（必须修）

计划 Step 1 的测试：

```gdscript
	var total := g1
	for i in 20:
		total += Progression.gain(w3, "potions", 4)
	a.eq(total, 8, "同一地点重复 23 次的总收益恰好 8（4+2+1+1，之后归零）")
```

按 `Progression.gain` 的公式：call1=4、call2=2、call3=1、call4=1、call5 起=0。
`total := g1` 后又跑了 20 次（即 call4..call23），得 `4 + 1 = 5`，**不等于 8**，断言必红。
按注释意图（23 次总和 = 4+2+1+1 = 8）改为：

```gdscript
	var total := g1 + g2 + g3
	for i in 20:
		total += Progression.gain(w3, "potions", 4)
	a.eq(total, 8, "同一地点重复 23 次的总收益恰好 8（4+2+1+1，之后归零）")
```

同时同步计划原文该行。在报告里写明依据与逐次推算。

## 强制裁定 2：未知行动测试文本误撞 REST 关键词「发呆」（必须修）

计划 Step 1 的测试：

```gdscript
	var unknown := gm.act(w4, "我对着墙发呆并思考宇宙的尽头")
	a.is_true(unknown.narration.length() > 0, "未知行动也要有叙事，而不是崩溃")
	a.is_true(unknown.tags.has("idle"), "未知行动归为 idle")
```

但 `REST_KEYWORDS` 含「发呆」，该文本会走 REST 分支拿到 `rest` 标签，`tags.has("idle")` 必红。
按测试意图（未知行动 → idle）把文本改为不含任何关键词：

```gdscript
	var unknown := gm.act(w4, "我对着墙思考宇宙的尽头")
	a.is_true(unknown.narration.length() > 0, "未知行动也要有叙事，而不是崩溃")
	a.is_true(unknown.tags.has("idle"), "未知行动归为 idle")
```

同时同步计划原文该行。`REST_KEYWORDS` 本身不变。

## 其它必须遵守的点

1. 除上述两处修正外，`progression.gd`、`state_ops.gd`、`self_check.gd`、`turn_engine.gd`、`game_master.gd`、
   `scripted_game_master.gd`、`tests/gm_test.gd`、`registry` 无需改动，全部**逐字**按计划 Step 1/3/4/5/6 的代码块照抄。
2. `tests/run_tests.gd` 的 `SUITES` 在 `"res://tests/spell_test.gd",` 之后追加 `"res://tests/gm_test.gd",`。
3. GDScript 字符串里**不要**写 `\u` / `\x` 转义。
4. 所有新脚本的 `*.gd.uid` 必须一起提交（`game_master`、`scripted_game_master`、`state_ops`、`progression`、
   `self_check`、`turn_engine`、`gm_test`）。
5. 测试唯一入口 `bash tools/test.sh`；**不要并发跑两个 Godot 实例**。
6. **提交前必须绿灯**：`[gm] 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、退出码 0。把**原始输出**粘进报告。
7. `self_check.gd` 是**任务 8 的最小桩**（计划明确说明，任务 9 替换）——这是刻意安排，不要自行扩展成完整实现。
8. 已用探针确认：子类里用父类的内嵌类 `GmResult.new()` 可正常解析（继承常量子类可见），无需改写为 `GameMaster.GmResult`。

## 执行步骤

1. 确认起点：`git status --short` 为空，`git log --oneline -1` = `79d15aa`。
2. Step 1：创建 `tests/gm_test.gd`（含两处强制修正）。
3. Step 2：把 `gm_test.gd` 加入 `SUITES`，跑 `bash tools/test.sh`，确认**红**（`StateOps` 未定义），退出码 1。
4. Step 3–6：依次创建 `progression.gd`、`state_ops.gd`、`game_master.gd`、`scripted_game_master.gd`、`self_check.gd`、`turn_engine.gd`。
5. Step 7：跑 `bash tools/test.sh` 到绿，记录原始输出。
6. Step 8：提交（含 `.uid` 与计划文档）：

```bash
cd /e/Hali
git add src/gm/game_master.gd src/gm/scripted_game_master.gd src/rules/state_ops.gd src/rules/progression.gd \
        src/rules/self_check.gd src/core/turn_engine.gd tests/gm_test.gd tests/run_tests.gd \
        src/gm/game_master.gd.uid src/gm/scripted_game_master.gd.uid src/rules/state_ops.gd.uid \
        src/rules/progression.gd.uid src/rules/self_check.gd.uid src/core/turn_engine.gd.uid tests/gm_test.gd.uid \
        docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
git commit -m "feat(gm): 叙事接口、状态操作、反刷成长与回合引擎"
```

7. **提交后立刻**写报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-8-report.md`。

## 报告格式（task-8-report.md）

```markdown
# Task 8 报告

## 结果
一句话：完成/未完成，测试是否全绿，退出码。

## 提交
<commit hash> <commit message>

## 文件
- 新建：...
- 修改：...

## 计划修正
说明两处强制修正（Progression total、未知行动文本）与逐次推算/依据。

## 测试原始输出
<粘贴 bash tools/test.sh 的完整原始输出，含 1/3、2/3、3/3 与 EXIT 码>

## 遇到的问题 / 偏离
如实记录；没有就写「无」。
```

## 完成后返回

最终输出里给出：commit hash、改动文件清单、`bash tools/test.sh` 的结论行（`[gm]` 失败数、`总计失败=0`、`ALL TESTS PASSED`、退出码）、报告文件路径。不要贴大段 diff。
