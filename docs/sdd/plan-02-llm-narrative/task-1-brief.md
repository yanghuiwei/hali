# Task 1 简报：协程探针 + 运行器 async 化（计划 02）

> 给实现者（worker）。仓库根 `E:/Hali`，分支 **`plan-02-llm-narrative`**，起点 `4459586`，工作区干净。
> 计划原文：`docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md` 的 `### Task 1`。本简报与计划冲突以本简报为准。

## 目标
1. 新建 `tests/async_probe_test.gd`（逐字用计划 Task 1 Step 1 的代码）。
2. 修改 `tests/run_tests.gd`：`_initialize` 与 `_run_suite` 改为 `await`，保留 `report_calls` 哨兵与「任何情况都 quit()」保证（逐字用计划 Task 1 Step 3 的目标 `_run_suite`）。
3. 把 `res://tests/async_probe_test.gd` 追加进 `SUITES`。

## 关键未知与备份方案
`SceneTree._initialize` 能否 `await`（协程）是本任务唯一未知。**先按计划直接 `await`**：
- 若 `bash tools/test.sh` 正常跑完并出现 `[async_probe] 断言=2 失败=0` → 通过。
- 若**挂住不动**（引擎空转、不退出）或报 `await` 相关解析错误 → 停止，不要硬改运行器架构，在报告里写明现象，然后**改用备份方案**：`_initialize` 不 await，改为串行启动一个 `call_deferred` 的驱动函数，用 `await Engine.get_main_loop().process_frame` 轮询 `_run_suite` 的协程；保证最终 `quit(code)`。备份方案也要跑绿。

## 硬性要求
1. 不改 `tests/assert.gd`（`report_calls` 已存在）。
2. 不改任何 `src/` 文件。
3. `async_probe_test.gd.uid` 必须一起提交。
4. 跑测试前确认没有并发 Godot 实例（`tasklist | grep -i godot` 应为空）。
5. **提交前必须绿灯**：`[async_probe] 断言=2 失败=0` + 原有 13 套件失败=0 + `main scene ready` + `全部通过。` + EXIT=0。把原始输出粘进报告。
6. 提交：
```bash
cd /e/Hali
git add tests/async_probe_test.gd tests/async_probe_test.gd.uid tests/run_tests.gd
git commit -m "test(async): 运行器支持协程套件 + 异步探针"
```
7. **提交后立刻**写报告到 `.superpowers/sdd/2026-09-19-hp-magic-era-02-llm-narrative/task-1-report.md`。

## 报告格式
```markdown
# Task 1 报告
## 结果
## 提交
## 文件
## 是否走了备份方案（是/否 + 现象）
## 测试原始输出（完整，含 EXIT）
## 偏离
```

## 完成后返回
commit hash、改动文件、`bash tools/test.sh` 结论行（async_probe 失败数、总计、EXIT）、是否走备份方案、报告路径。
