# Task 7 简报：OpGuard
> worker：仓库 `E:/Hali`，分支 `plan-02-llm-narrative`，起点 `0a86471`。逐字用计划 `### Task 7` 代码。
## 目标
- 新建 `src/gm/op_guard.gd`（`sanitize`/`sanitize_detailed` + 内嵌 `Result`；MAX_OPS 20、MAX_MONEY_GAIN 1000、MAX_RELATION_DELTA 20、gain_skill→train_skill、set_magic_tier ±1、下划线 flag 拒绝、system 来源拒绝、未知 op 透传给 StateOps）。
- 追加 `tests/llm_test.gd` 的 OpGuard 用例（计划 Task 7 Step 1）；不改 SUITES。
## 硬性
1. 只加实现与测试；不动其它 `src/`/`tests/*`；`.gd.uid` 一起提交。
2. 绿灯：`[llm]` 失败=0、17 套件失败=0、`main scene ready`、EXIT=0。
3. 提交 `feat(gm): OpGuard 净化与钳制`；提交后立刻写 `task-7-report.md`。
## 返回
commit、文件、`[llm]` 断言/失败、总计、EXIT、报告路径。
