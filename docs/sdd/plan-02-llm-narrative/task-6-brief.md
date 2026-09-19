# Task 6 简报：StateOps.train_skill + §8#33 RNG 加盐
> worker：仓库 `E:/Hali`，分支 `plan-02-llm-narrative`，起点（当前 HEAD）。逐字用计划 `### Task 6`。
## 目标
- 改 `src/rules/state_ops.gd`：新增 `train_skill` op（`Progression.gain` 记账 + `add_skill`）；`world_gm_rng` 按 `_gm_rng_counter` 加盐（`game_seed + turn*15485863 + counter*2654435761`，计数器入 `world.flags`）。
- 追加 `tests/gm_test.gd`（train_skill）与 `tests/spell_test.gd`（§8#33）的断言（计划 Task 6 Step 1；注意 spell_test 已有 `make_world(reg, tier)`）。
## 硬性
1. 只改这两个源文件的相关函数与两个测试；不动其它。
2. 绿灯：`[gm]`/`[spell]` 失败=0、全 17 套件失败=0、`main scene ready`、EXIT=0。
3. 提交 `feat(rules): StateOps.train_skill + 施法 RNG 加盐（§8#33）`；提交后立刻写 `task-6-report.md`。
## 返回
commit、文件、`[gm]`/`[spell]` 断言/失败、总计、EXIT、报告路径。
