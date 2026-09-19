# Task 1 修复轮 scoped 复审（reviewer，只读）

> 只读：read、bash（仅只读命令 + `bash tools/test.sh`）。禁止改文件/写 git。仓库 `E:/Hali`，分支 `plan-02-llm-narrative`。

## 背景
Task 1 首轮审查 Important：async 化后若套件协程永不恢复，`_initialize` 永久挂起，`quit()` 保证失效。控制器提交 `632ff2e` 加全局看门狗。diff：`docs/sdd/plan-02-llm-narrative/review-ccd08ef..632ff2e.diff`。

## 必须核对
1. `tests/run_tests.gd` 是否在 `_initialize` 开头用 `create_timer(SUITE_TIMEOUT_SEC)` + `quit(1)` 兜底；lambda 能否访问 `quit`；`SUITE_TIMEOUT_SEC` 是否合理（当前 300s）。
2. **反证**（自行改后还原）：把 `SUITE_TIMEOUT_SEC` 临时改为 `2.0`，并在某套件 `run()` 注入永不恢复的 await（如 `await Engine.get_main_loop().create_timer(6000.0).timeout`），跑 `bash tools/test.sh`——应在约 2 秒内打印「测试总超时」并 EXIT=1，而不是挂死。随后还原。
3. 正常路径仍绿：`[async_probe] 断言=2 失败=0`、13 套件失败=0、`main scene ready`、`全部通过。`、EXIT=0。
4. 范围：`git diff --name-only ccd08ef..632ff2e` 是否只有 `tests/run_tests.gd` + 计划 + 审查包；无 `src/` 改动。

## 输出格式
```markdown
# Task 1 修复轮 scoped 复审记录
## 结论
- Important（协程挂死→quit）：ADDRESSED / PARTIAL / NOT ADDRESSED
- 新缺陷：无/有
- 裁定：通过 / 不通过
## 证据（含反证）
## 残余风险/建议
## 未验证/存疑
```
