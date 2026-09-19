# Task 2 简报：LlmProvider 接口 + MockLlmProvider

> worker：仓库 `E:/Hali`，分支 `plan-02-llm-narrative`，起点 `f44c50d`，工作区干净。
> 计划原文：`docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md` 的 `### Task 2`。**逐字用计划里的代码**。

## 目标
- 新建 `src/gm/llm_provider.gd`（`LlmProvider` + 内嵌 `LlmRequest`/`LlmResponse`）。
- 新建 `src/gm/providers/mock_provider.gd`（`MockLlmProvider`；**注意 nested 类型要写成 `LlmProvider.LlmRequest`/`LlmProvider.LlmResponse` 限定**，计划里已是限定版）。
- 新建 `tests/llm_test.gd`（计划 Task 2 Step 1 的 provider 用例）；登记 `res://tests/llm_test.gd` 到 `tests/run_tests.gd` 的 `SUITES`。

## 硬性
1. 不动其它 `src/`、`tests/*`（除 `run_tests.gd` 加一行）、不动 `assert.gd`。
2. 两个新脚本的 `.gd.uid` 一起提交。
3. 提交前绿灯：`[llm] 断言=10 失败=0`、14 套件失败=0（async_probe 在内）、`main scene ready`、`全部通过。`、EXIT=0。原始输出贴进报告。
4. 提交：
```bash
git add src/gm/llm_provider.gd src/gm/llm_provider.gd.uid src/gm/providers/mock_provider.gd src/gm/providers/mock_provider.gd.uid tests/llm_test.gd tests/llm_test.gd.uid tests/run_tests.gd
git commit -m "feat(gm): LlmProvider 接口与 Mock provider"
```
5. 提交后立刻写报告 `.superpowers/sdd/2026-09-19-hp-magic-era-02-llm-narrative/task-2-report.md`。

## 报告格式
`# Task 2 报告` → 结果 / 提交 / 文件 / 测试原始输出 / 偏离。

## 完成后返回
commit hash、文件清单、`[llm]` 失败数 + 总计 + EXIT、报告路径。
