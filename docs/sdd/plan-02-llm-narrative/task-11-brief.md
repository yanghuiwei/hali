# Task 11 简报：UI 异步接线
> worker：仓库 `E:/Hali`，分支 `plan-02-llm-narrative`，起点（当前 HEAD）。逐字用计划 `### Task 11`。
## 目标
改 `src/ui/main.gd`：
1. `_build_gm()`：`LlmSettings.load_from()` 配置齐全 → `LlmGameMaster.new(OpenAiCompatProvider.from_settings(self, settings), ScriptedGameMaster.new(rng))`；否则提示 + `ScriptedGameMaster.new(rng)`。
2. `_on_start_pressed`/`_on_load` 用 `engine = TurnEngine.new(world, _build_gm(), rng)`（保持 rng 共享）。
3. `_on_command_submitted` 改协程：`command_edit.editable=false` → 提示「世界正在回应…」→ `await engine.submit_async(text)` → 打印 → `editable=true`。
## 硬性
1. 只改 `src/ui/main.gd`；不动其它。
2. 冒烟必须仍打印 `main scene ready`，全 16 套件失败=0、EXIT=0（`bash tools/test.sh`）。
3. 提交 `feat(ui): 回合异步接线与 LLM 配置提示`；提交后立刻写 `task-11-report.md`。
## 返回
commit、文件、冒烟是否 `main scene ready`、总计、EXIT、报告路径。
