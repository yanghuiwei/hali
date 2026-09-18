# Task 9 简报：状态面板格式化 + 第七十二章强制自检

> 给实现者（worker）的完整作业书。仓库根 = `E:/Hali`（Windows + Git Bash），分支 `plan-01-core-foundation`，
> 起点应为 `463a73d`（Task 8 收尾后的交接提交），工作区干净。
> **先读** `HANDOFF.md`（第 3、4、6 节）与计划原文
> `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 9`（第 3403–3879 行，Step 1–6）。
> 本简报与计划冲突时以本简报为准。

## 目标

- 新建 `src/ui/panel_formatter.gd`（`PanelFormatter`，`extends RefCounted`）
- 修改 `src/rules/self_check.gd`（用完整实现**替换** Task 8 的最小桩）
- 新建 `tests/panel_test.gd`（`class_name PanelTest`）
- 新建 `tests/selfcheck_test.gd`（`class_name SelfCheckTest`）
- 修改 `tests/run_tests.gd`（`SUITES` 在 `"res://tests/gm_test.gd",` 之后追加 `"res://tests/panel_test.gd",`
  与 `"res://tests/selfcheck_test.gd",`）

**不要**碰其它任务的文件（`src/model/`、`src/gm/`、`src/core/`、`data/` 等保持不动）。
`SelfCheck.is_audit_turn` 的既有实现与 `gm_test.gd` 的断言都必须继续通过。

## 强制裁定：提交时必须包含新建脚本的 `*.gd.uid`（计划 Step 6 的 `git add` 漏了）

计划 Step 6 的 `git add` 只列了 `.gd`/`.gd` 测试文件，**没有**列新建脚本自动生成的 `.gd.uid`。
HANDOFF §4 第 5 条是硬性要求（`.uid` 必须入库，否则引用漂移）。因此提交时显式 `git add`：

- `src/ui/panel_formatter.gd.uid`（新）
- `tests/panel_test.gd.uid`（新）
- `tests/selfcheck_test.gd.uid`（新）
- `src/rules/self_check.gd.uid`（已存在，内容可能因重写脚本而变化——若变化一并提交）

`self_check.gd.uid` 与 `run_tests.gd.uid` 已在库中，`git add -u` 或显式路径均可。

## 其它必须遵守的点

1. 除上述 `.uid` 补充外，`panel_formatter.gd`、`self_check.gd`、`tests/panel_test.gd`、
   `tests/selfcheck_test.gd` 全部**逐字**按计划 Step 1/3/4 的代码块照抄；`tests/run_tests.gd` 只追加两条套件路径。
   **不要**自行"改进"格式、增删字段或调整断言。
2. 计划 Step 2 用 `sed` 追加两条套件路径（在 `gm_test.gd` 那行之后），可用该命令或等价的 edit。
3. GDScript 字符串里**不要**写 `\u` / `\x` 转义。
4. 所有新脚本的 `*.gd.uid` 必须一起提交（见上）。
5. 测试唯一入口 `bash tools/test.sh`；**不要并发跑两个 Godot 实例**。
6. 冷机器/新脚本首次跑 `tools/test.sh` 的 `1/3 --import` 会为新脚本生成 `.uid`——先让它跑完再 `git status`。
7. **提交前必须绿灯**：`[panel] 失败=0`、`[selfcheck] 失败=0`、`[gm] 失败=0`、`总计失败=0`、
   `ALL TESTS PASSED`、`全部通过。`、退出码 0。把**原始输出**粘进报告。
8. 若逐字照抄的代码真的报错（例如类型/`String.join` 问题），**先停下来在本报告里记录**，做**最小**修正
   （不得改变可观察输出与断言含义），并在报告的「偏离」节写明。不要顺手重构。

## 执行步骤

1. 确认起点：`git status --short` 为空，`git log --oneline -1` = `463a73d`。
2. Step 1：创建 `tests/panel_test.gd`、`tests/selfcheck_test.gd`（逐字照抄计划）。
3. Step 2：把两个套件加入 `SUITES`，跑 `bash tools/test.sh`，确认**红**（`PanelFormatter`/`SelfCheck.snapshot` 未定义），退出码 1。
4. Step 3：创建 `src/ui/panel_formatter.gd`。
5. Step 4：用计划 Step 4 的完整实现替换 `src/rules/self_check.gd`。
6. Step 5：跑 `bash tools/test.sh` 到绿，记录原始输出。
7. Step 6：提交（**含 `.uid`**）：

```bash
cd /e/Hali
git add src/ui/panel_formatter.gd src/ui/panel_formatter.gd.uid \
        src/rules/self_check.gd src/rules/self_check.gd.uid \
        tests/panel_test.gd tests/panel_test.gd.uid \
        tests/selfcheck_test.gd tests/selfcheck_test.gd.uid \
        tests/run_tests.gd
git commit -m "feat(ui): 第六十二至六十五章面板与第七十二章强制自检"
```

8. **提交后立刻**写报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-9-report.md`。

## 报告格式（task-9-report.md）

```markdown
# Task 9 报告

## 结果
一句话：完成/未完成，测试是否全绿，退出码。

## 提交
<commit hash> <commit message>

## 文件
- 新建：...
- 修改：...

## 计划修正
- `.uid` 补充（若非空）；逐字照抄之外的任何偏离（若无写「无」）。

## 测试原始输出
<粘贴 bash tools/test.sh 的完整原始输出，含 1/3、2/3、3/3 与 EXIT 码；先红后绿两段都要>

## 遇到的问题 / 偏离
如实记录；没有就写「无」。
```

## 完成后返回

最终输出里给出：commit hash、改动文件清单、`bash tools/test.sh` 的结论行（`[panel]`/`[selfcheck]`/`[gm]` 失败数、
`总计失败=0`、`ALL TESTS PASSED`、退出码）、报告文件路径。不要贴大段 diff。
