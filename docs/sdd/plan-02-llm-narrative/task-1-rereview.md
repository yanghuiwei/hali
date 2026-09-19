# Task 1 修复轮 scoped 复审记录

## 结论
- Important（协程挂死→quit）：**ADDRESSED**
- 新缺陷：**无**
- 裁定：**通过**

## 证据（含反证）

### 1. 代码核对（`tests/run_tests.gd`, commit `632ff2e`）
- `const SUITE_TIMEOUT_SEC := 300.0`（第 3 行），在 `_initialize()` **最开头**（任何 `await _run_suite` 之前）就 `create_timer(SUITE_TIMEOUT_SEC).timeout.connect(...)`，因此看门狗先于挂死点被注册。
- lambda 可访问 `quit`：lambda 定义在 `SceneTree` 实例方法内，隐式捕获 `self`，`quit(1)` 解析为 `SceneTree.quit`。**并且这是实测过的**——反证中该 lambda 真的执行并终止了进程（否则不会出现退出码 1），不是纸面推断。
- `SceneTreeTimer` 由主循环逐帧推进，独立于协程 `await`，所以套件挂死不阻塞看门狗；`printerr` 在 `quit(1)` 之前，消息可见。
- `300.0` 合理性：整轮单测实测 ≈1s（全套 14 套件），冒烟由 `--quit-after 5` 限时；300s 有约 2 个数量级的余量，不会误杀。

### 2. 反证（自改后已还原）
改动 A：`SUITE_TIMEOUT_SEC := 300.0 → 2.0`；改动 B：`tests/async_probe_test.gd` 的 `run()` 首行注入 `await Engine.get_main_loop().create_timer(6000.0).timeout`（永不恢复）。

| 场景 | 结果 |
|---|---|
| 看门狗 2.0s + 注入挂死 | 第 38 行打印 `测试总超时（2 秒），强制退出`；`tools/test.sh` 输出 `测试失败：单测=1 冒烟=0`；**EXIT=1**，整体 9s（导入 + 约 2s 单测 + 冒烟），未挂死 |
| 对照：看门狗恢复 300.0s + 同一注入 | 外部 `timeout 20` 在 20s 强杀，**EXIT=124**（真挂死），证明注入的 await 确实永不恢复，是看门狗而非别的原因救了这次运行 |

还原：`git checkout -- tests/run_tests.gd tests/async_probe_test.gd`，`md5sum` 与改动前完全一致（`f0bc9b06…` / `5c2e82ab…`），`grep 6000.0` 命中 0，`SUITE_TIMEOUT_SEC` 回到 300.0；`git status` 仅剩简报即有的未跟踪 `review-ccd08ef..632ff2e.diff`，工作区无我留下的改动。

### 3. 正常路径复测（还原后重跑 `bash tools/test.sh`）
- `[async_probe] 断言=2 失败=0`（第 38 行）
- `==== 总计失败=0，失败套件=0 ====`（第 39 行；`SUITES` 现为 14 个套件）
- `main scene ready, godot=4.7.2-stable (official)`（第 44 行）
- `全部通过。`（第 45 行），**EXIT=0**；无 `leaked`、无 `测试总超时`。

### 4. 范围
`git diff --name-only ccd08ef..632ff2e`：
- `tests/run_tests.gd`
- `docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md`（Step 3 同步为含看门狗的目标形态）
- `docs/sdd/plan-02-llm-narrative/review-4459586..ccd08ef.diff`（上一轮审查包）

`git diff --stat ccd08ef..632ff2e -- src/` 输出为空 → **无 `src/` 改动**，无范围外代码改动。

## 残余风险/建议
1. **看门狗是"整轮总预算"而非"逐套件预算"**（300s 覆盖全部套件，当前约 1s）。Task 2 起套件增长后，某个真慢的套件可能被整体判超时，且日志不指明是谁挂的。建议（非阻塞）：超时消息里带上当前套件路径（如把 `current_suite` 变量也放进 lambda 的打印），或在 Task 2 需要时改造成逐套件计时。
2. **只覆盖 `await` 类挂死**：若某套件在 `run()` 里同步死循环（不让出帧），主循环被独占，`SceneTreeTimer` 同样不会推进，看门狗失效。这是 `SceneTreeTimer` 方案的固有边界，与首轮 Important 描述的失败模式（协程永不恢复）吻合，故不阻塞；建议在计划里写明该边界。
3. `tools/test.sh` 的步骤 1（`--import`）与步骤 3（冒烟）无超时保护，CI 里若这两步挂住仍会卡死。属脚本层面，不在本次修复范围。

## 未验证/存疑
- 未实测"同步死循环"场景（见残余风险 2），仅据引擎主循环语义推断，未做注入验证。
- 未验证多套件同时/连续挂死、或挂死发生在 `_run_suite` 更早阶段（`load`/`new`）时的表现；代码路径上这些均为同步，不属挂死风险面。
- 简报把 `review-ccd08ef..632ff2e.diff` 列为本次 diff 依据，但该文件**未跟踪**（工作区文件）；提交 `632ff2e` 内实际纳入的是上一轮包 `review-4459586..ccd08ef.diff`。内容上两者互补，不影响范围判定，但流程记录口径略有不一致，建议后续提交把当轮审查包也一并入库。
