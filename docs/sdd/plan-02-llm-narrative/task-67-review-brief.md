# Tasks 6–7 审查简报（reviewer，只读）
只读 read/bash；禁止改文件/写 git。仓库 `E:/Hali`，分支 `plan-02-llm-narrative`。
对象：`0a86471`（Task6 StateOps train_skill + §8#33）、`38589b4`（Task7 OpGuard）；diff `docs/sdd/plan-02-llm-narrative/review-0a86471^..38589b4.diff`；计划 `### Task 6/7`；spec §8/§11。
核对：
1. **Task 6 行为**：`train_skill` 是否经 `Progression.gain` 记账（反刷在 StateOps 内）；`world_gm_rng` 加盐是否使同回合多次 cast 掷不同 roll；`_gm_rng_counter` 入 `world.flags` 且能随存读档往返；既有 `[gm]`/`[spell]` 不回归。
2. **Task 7 行为**：`OpGuard.sanitize_detailed` 的每条规则（ops 上限 20、gain_skill→train_skill、add_money 回合累计钳 1000、relation_delta ±20、set_magic_tier ±1、下划线/空 flag 拒绝、know_fact system/空拒绝、未知 op 透传、cast_spell/learn_spell/set_location/set_job 透传）。
3. **§8#33 反证**：把 `world_gm_rng` 改回不含 counter 的旧实现，`[spell]` 的「同回合 roll 不同」断言是否变红；还原。
4. **OpGuard 反证**：去掉 `add_money` 钳制或下划线 flag 拒绝，确认 `[llm]` 变红；还原。
5. 越界：`git diff --name-only 0a86471^..38589b4` 仅 `src/rules/state_ops.gd`、`src/gm/op_guard.gd`(+uid)、`tests/gm_test.gd`、`tests/spell_test.gd`、`tests/llm_test.gd`。
6. 自跑 `bash tools/test.sh`：`[gm] 63`、`[spell] 229`、`[llm] 39`、全 17 套件失败=0、`main scene ready`、EXIT=0。
输出：`# Tasks 6–7 审查记录` → 结论/证据（含反证）/发现表/未验证。
