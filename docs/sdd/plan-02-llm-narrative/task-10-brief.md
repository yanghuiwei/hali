# Task 10 简报：OpenAiCompatProvider
> worker：仓库 `E:/Hali`，分支 `plan-02-llm-narrative`，起点（当前 HEAD）。逐字用计划 `### Task 10`（含 nested 类型限定 `LlmProvider.LlmRequest/LlmResponse`）。
## 目标
- 新建 `src/gm/providers/openai_compat_provider.gd`（`from_settings`、`_chat_url`、`_build_headers`、`_build_body`、`static _parse_http`、`complete`（HTTPRequest 协程））。
- 追加 `tests/llm_test.gd` 纯函数用例（计划 Task 10 Step 1；**不联网**）。
## 硬性
1. 只加实现 + 追加 `tests/llm_test.gd`；不动其它；`.gd.uid` 一起提交。
2. 绿灯：`[llm]` 失败=0、全 16 套件失败=0、`main scene ready`、EXIT=0。
3. 提交 `feat(gm): OpenAI 兼容 HTTP provider`；提交后立刻写 `task-10-report.md`。
## 返回
commit、文件、`[llm]` 断言/失败、总计、EXIT、报告路径。
