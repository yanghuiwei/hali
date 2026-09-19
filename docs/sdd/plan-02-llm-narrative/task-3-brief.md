# Task 3 简报：LlmSettings
> worker：仓库 `E:/Hali`，分支 `plan-02-llm-narrative`，起点 `a33a33a`。逐字用计划 `### Task 3` 的代码。
## 目标
- 新建 `src/gm/llm_settings.gd`（`LlmSettings`：`load_from(path=DEFAULT_PATH)`、`save_to`、`is_configured`、env `HALI_LLM_API_KEY` 覆盖）。
- 追加 `tests/llm_test.gd` 的 LlmSettings 用例（计划 Task 3 Step 1）；不改 `SUITES`（套件已登记）。
## 硬性
1. 不动其它 `src/`/`tests/*`；`.gd.uid` 一起提交。
2. 绿灯：`[llm]` 失败=0、14 套件失败=0、`main scene ready`、EXIT=0。
3. 提交 `feat(gm): LLM 配置读写与环境变量覆盖`；提交后立刻写 `task-3-report.md`。
## 完成后返回
commit、文件、`[llm]` 断言/失败、总计、EXIT、报告路径。
