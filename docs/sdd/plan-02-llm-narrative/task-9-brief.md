# Task 9 简报：TurnEngine.submit_async
> worker：仓库 `E:/Hali`，分支 `plan-02-llm-narrative`，起点（当前 HEAD）。逐字用计划 `### Task 9`。
## 目标
- 改 `src/core/turn_engine.gd`：抽 `_blank_result`/`_pre_submit`/`_resolve`；保留 `submit()`（对 `LlmGameMaster` push_error + blocked）；新增 `submit_async()`。
- 追加 `tests/llm_test.gd` 的 `submit_async` 端到端用例（计划 Task 9 Step 1）。
## 硬性
1. 只改 `turn_engine.gd` + 追加 `tests/llm_test.gd`；不动其它。
2. **必须保持既有 `[gm]` 全绿**（`submit()` 语义不变）。
3. 绿灯：`[llm]`/`[gm]` 失败=0、全 16 套件失败=0、`main scene ready`、EXIT=0。
4. 提交 `feat(core): TurnEngine.submit_async 与共用守卫/结算`；提交后立刻写 `task-9-report.md`。
## 返回
commit、文件、`[llm]`/`[gm]` 断言/失败、总计、EXIT、报告路径。
