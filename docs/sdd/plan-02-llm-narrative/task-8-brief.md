# Task 8 简报：GmResult.warnings + LlmGameMaster
> worker：仓库 `E:/Hali`，分支 `plan-02-llm-narrative`，起点（当前 HEAD）。逐字用计划 `### Task 8`。
## 目标
- 改 `src/gm/game_master.gd`：`GmResult` 加 `var warnings: PackedStringArray = PackedStringArray()`。
- 新建 `src/gm/llm_game_master.gd`（`LlmGameMaster`：`MAX_ATTEMPTS=2`、`FALLBACK_NOTE`、重试 1 次 + 解析失败用 `build_repair` 再试、失败/无 provider 降级 `ScriptedGameMaster`、`OpGuard.sanitize_detailed` 净化并把 warnings 放进 `GmResult.warnings`）。
- 追加 `tests/llm_test.gd` 的 LlmGameMaster 用例（计划 Task 8 Step 1）。
## 硬性
1. 只改 `game_master.gd` + 新建 `llm_game_master.gd`(+uid) + 追加 `tests/llm_test.gd`；不动其它。
2. 绿灯：`[llm]` 失败=0、全 17 套件失败=0、`main scene ready`、EXIT=0。
3. 提交 `feat(gm): LlmGameMaster（重试 + 降级 + 净化）`；提交后立刻写 `task-8-report.md`。
## 返回
commit、文件、`[llm]` 断言/失败、总计、EXIT、报告路径。
