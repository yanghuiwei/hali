# Task 5 简报：PromptBuilder
> worker：仓库 `E:/Hali`，分支 `plan-02-llm-narrative`，起点 `b0d2258`。逐字用计划 `### Task 5` 代码。
## 目标
- 新建 `src/gm/prompt_builder.gd`（`build`/`build_repair`/`system_prompt`/`content_index`/`state_digest`；截断阈值与计划一致：log>200→max_log5, >400→0, >800→max_history2, >1600→0）。
- 新建 `tests/prompt_test.gd`（计划 Task 5 Step 1）；登记到 `SUITES`。
## 硬性
1. 不动其它 `src/`/`tests/*`；两个新脚本 `.gd.uid` 一起提交。
2. 绿灯：`[prompt]` 失败=0、16 套件失败=0、`main scene ready`、EXIT=0。
3. 提交 `feat(gm): 提示词构造与状态摘要`；提交后立刻写 `task-5-report.md`。
## 返回
commit、文件、`[prompt]` 断言/失败、总计、EXIT、报告路径。
