# Task 4 简报：GmResponseParser
> worker：仓库 `E:/Hali`，分支 `plan-02-llm-narrative`，起点 `2544bec`。逐字用计划 `### Task 4` 代码。
## 目标
- 新建 `src/gm/gm_response_parser.gd`（`GmResponseParser` + 内嵌 `Result`；`MAX_NARRATION=4000`、tags 白名单、围栏剥离、fail-closed）。
- 追加 `tests/llm_test.gd` 的解析用例（计划 Task 4 Step 1）；不改 SUITES。
## 硬性
1. 不动其它 `src/`/`tests/*`；`.gd.uid` 一起提交。
2. 绿灯：`[llm]` 失败=0、15 套件失败=0、`main scene ready`、EXIT=0。
3. 提交 `feat(gm): LLM 响应解析（fail-closed）`；提交后立刻写 `task-4-report.md`。
## 返回
commit、文件、`[llm]` 断言/失败、总计、EXIT、报告路径。
