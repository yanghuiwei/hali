# Task 10 简报：存档与读档（第七十一章）

> 给实现者（worker）的完整作业书。仓库根 = `E:/Hali`（Windows + Git Bash），分支 `plan-01-core-foundation`，
> 起点应为 `04b0ce7`（Task 9 收尾提交），工作区干净。
> **先读** `HANDOFF.md`（第 3、4、6 节，尤其 §8#34 的端到端要求）与计划原文
> `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 10`（第 3881–4153 行，Step 1–6）。
> 本简报与计划冲突时以本简报为准。

## 目标

- 新建 `src/persist/save_codec.gd`（`SaveCodec`）
- 新建 `src/persist/save_store.gd`（`SaveStore`）
- 新建 `tests/save_test.gd`（`class_name SaveTest`）
- 修改 `tests/run_tests.gd`（`SUITES` 在 `"res://tests/selfcheck_test.gd",` 之后追加 `"res://tests/save_test.gd",`）

**不要**碰其它任务的文件（`src/model/`、`src/gm/`、`src/rules/`、`src/ui/`、`data/` 等保持不动）。

## 强制裁定 1：提交时必须包含新建脚本的 `*.gd.uid`

计划 Step 6 的 `git add` 没列新脚本自动生成的 `.gd.uid`。HANDOFF §4 第 5 条是硬性要求。
提交时显式包含：`src/persist/save_codec.gd.uid`、`src/persist/save_store.gd.uid`、`tests/save_test.gd.uid`
（跑过一次 `bash tools/test.sh` 后会生成；`git status` 里应能看到）。

## 强制裁定 2：追加「读档后重建引擎续跑」端到端断言（§8#34）

HANDOFF §6 明确要求 Task 10 补 `submit → to_dict → JSON → from_dict → 重建引擎 → submit` 的端到端对比；
计划 Step 1 的测试只验证了 `rng_state` 经 JSON 往返后随机流一致，**没有**验证重建引擎后续提交与原时间线一致。
请在 `tests/save_test.gd` 的 `return a.report("save")` **之前**追加以下代码块（逐字，插在随机流对比之后）：

```gdscript
	# ---- 存档后重建引擎继续提交，必须与原时间线逐字一致（HANDOFF §8#34 端到端；Task 10 强制补充） ----
	var w3 := make_world()
	var rng3 := RngService.new(w3.game_seed)
	var engine3 := TurnEngine.new(w3, ScriptedGameMaster.new(rng3), rng3)
	engine3.submit("我要去上课")
	var checkpoint := SaveCodec.encode(w3)
	var w3r: WorldState = SaveCodec.decode(checkpoint, reg)["world"]
	var r_orig := engine3.submit("我要去对角巷打工赚钱")
	var rng3r := RngService.new(w3r.game_seed)
	var engine3r := TurnEngine.new(w3r, ScriptedGameMaster.new(rng3r), rng3r)
	var r_copy := engine3r.submit("我要去对角巷打工赚钱")
	a.eq(r_copy.narration, r_orig.narration, "读档后重建引擎续跑：叙事一致")
	a.eq(w3r.to_dict(), w3.to_dict(), "读档后重建引擎续跑：世界状态一致")
```

同步计划原文 Step 1 的 `save_test.gd` 代码块（把该块插到同位置）。该块依赖已实现的 `SaveCodec`/`SaveStore`、
`TurnEngine`、`ScriptedGameMaster`、`RngService`，不需要改动任何实现代码。

## 其它必须遵守的点

1. 除强制裁定 2 的追加块外，`src/persist/save_codec.gd`、`src/persist/save_store.gd`、`tests/save_test.gd`
   全部**逐字**按计划 Step 1/3/4 的代码块照抄；`tests/run_tests.gd` 只追加一条套件路径。
   **不要**自行改动 `WorldState`/`RngService` 的序列化格式（`game_seed` 的 int64 字符串化属另一笔债，见 HANDOFF §8#19，本轮不做）。
2. 计划 Step 2 的 `sed` 追加套件路径可用，或用等价 edit。
3. GDScript 字符串里**不要**写 `\u` / `\x` 转义。
4. 测试唯一入口 `bash tools/test.sh`；**不要并发跑两个 Godot 实例**。测试用 `user://test_saves` 独立目录，开始前会自清理，不要写正式 `user://saves`。
5. **提交前必须绿灯**：`[save] 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、`全部通过。`、退出码 0。把**原始输出**粘进报告。
6. 若逐字照抄的代码真的报错（例如 lambda 的 `fail.call`、`make_dir_recursive_absolute`、`String.split`），
   **先停下来在报告里记录**，做**最小**修正（不得改变可观察输出与断言含义），并在报告「偏离」节写明。不要顺手重构。

## 执行步骤

1. 确认起点：`git status --short` 为空，`git log --oneline -1` = `04b0ce7`。
2. Step 1：创建 `tests/save_test.gd`（含强制裁定 2 的追加块）。
3. Step 2：把套件加入 `SUITES`，跑 `bash tools/test.sh`，确认**红**（`SaveCodec` 未定义），退出码 1。
4. Step 3：创建 `src/persist/save_codec.gd`。
5. Step 4：创建 `src/persist/save_store.gd`。
6. Step 5：跑 `bash tools/test.sh` 到绿，记录原始输出。
7. Step 6：提交（**含 `.uid`**）：

```bash
cd /e/Hali
git add src/persist/save_codec.gd src/persist/save_codec.gd.uid \
        src/persist/save_store.gd src/persist/save_store.gd.uid \
        tests/save_test.gd tests/save_test.gd.uid tests/run_tests.gd \
        docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
git commit -m "feat(persist): 第七十一章存档编解码与存槽"
```

8. **提交后立刻**写报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-10-report.md`。

## 报告格式（task-10-report.md）

```markdown
# Task 10 报告

## 结果
一句话：完成/未完成，测试是否全绿，退出码。

## 提交
<commit hash> <commit message>

## 文件
- 新建：...
- 修改：...

## 计划修正
- `.uid` 补充；强制裁定 2 的端到端块；逐字照抄之外的任何偏离（若无写「无」）。

## 测试原始输出
<粘贴 bash tools/test.sh 的完整原始输出，含 1/3、2/3、3/3 与 EXIT 码；先红后绿两段都要>

## 遇到的问题 / 偏离
如实记录；没有就写「无」。
```

## 完成后返回

最终输出里给出：commit hash、改动文件清单、`bash tools/test.sh` 的结论行（`[save]` 失败数、`总计失败=0`、
`ALL TESTS PASSED`、退出码）、报告文件路径。不要贴大段 diff。
