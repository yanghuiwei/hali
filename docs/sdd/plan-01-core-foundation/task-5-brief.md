# Task 5 简报：确定性随机 + 月度世界演化

> 给实现者（worker）的完整作业书。仓库根 = `E:/Hali`（Windows + Git Bash），分支 `plan-01-core-foundation`，
> 起点应为 `dcf25e1`（Task 4 完成后的交接提交），工作区干净。
> **先读** `HANDOFF.md`（第 3、4、6 节）与计划原文
> `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 5: 确定性随机 + 月度世界演化`
> （第 1434–1857 行，Step 1–7 的完整代码块）。本简报与计划冲突时以本简报为准。

## 目标

- 新建 `src/core/rng_service.gd`（`RngService`）
- 新建 `data/locations.json`（21 项）、`data/rumors.json`（16 项）
- 修改 `src/core/registry.gd`：`TABLE_FILES` 追加 `"locations": "locations.json"`、`"rumors": "rumors.json"`
- 修改 `src/model/world_state.gd`：追加 `tick()` 及其常量/私有方法（计划 Step 6）
- 新建 `tests/clock_test.gd`、`tests/world_tick_test.gd`
- 修改 `tests/run_tests.gd`：`SUITES` 追加这两个套件

**不要**碰其它任务的文件（`data/` 已有 7 张表、`src/rules/`、`src/model/money.gd` / `player_state.gd` / `game_clock.gd`、
`src/core/json_util.gd` 等）。

## 强制裁定：计划里的 `rumors.json` 缺 `label`，会违反 Registry 完整性契约（必须修）

计划 Task 5 的 `data/rumors.json` 样例每项只有 `id/category/text/weight/major/min_year/zones/requires_flags`，
**没有 `label`**。但 `Registry.validate()`（`src/core/registry.gd`）要求**每张表每个条目都有非空 `label`**，
且 `tests/registry_test.gd` 明确断言「缺 label 必须报错」。因此按计划原样写：
- `tests/world_tick_test.gd` 的 `a.eq(reg.validate().size(), 0, "新增表后仍无校验错误")` 必红；
- 这是真实的数据完整性缺陷，不能靠改测试掩盖。

**修正方式：给 `data/rumors.json` 的每一条补一个短中文 `label`（作为传闻标题/显示名），插在 `"id"` 之后。**
逐条对应如下（**逐字使用**）：

| id | label |
| --- | --- |
| ministry_election | 魔法部改选 |
| ministry_internal | 魔法部内幕 |
| war_rumor | 北方失踪 |
| wizard_life | 破釜酒吧新酒 |
| creature_activity | 马人驱赶学生 |
| creature_dragon | 龙越界 |
| economy_price | 魔药材料涨价 |
| economy_wand | 魔杖木材短缺 |
| international | 国际巫师联合会会议 |
| quidditch | 魁地奇转会 |
| school_term | 霍格沃茨开学 |
| daily_life | 平静日常 |
| major_azkaban_break | 阿兹卡班越狱 |
| major_ministry_coup | 魔法部政变传闻 |
| major_gringotts_crisis | 古灵阁停摆 |
| major_hogwarts_occupied | 霍格沃茨异变 |

同时把**计划原文** `data/rumors.json` 代码块里对应 16 行也补上同样的 `"label"`（计划级修正）。
在报告里写明：依据「`Registry.validate()` 要求每条目有非空 label；`tests/registry_test.gd` 断言缺 label 必须报错」。

## 其它必须遵守的点

1. 除上述 `label` 修正外，`data/locations.json`、`data/rumors.json`、`RngService`、`WorldState.tick()`、
   两个测试文件**逐字**按计划 Step 1–6 的代码块照抄，不要自由发挥、不要加功能。
2. `RngService` 必须保证：同 seed 同流可复现、不同命名流互不干扰、`state_dict()`/`load_state()` 能续跑一致。
3. `tests/run_tests.gd` 的 `SUITES` 在 `"res://tests/model_test.gd",` 之后追加
   `"res://tests/clock_test.gd",` 与 `"res://tests/world_tick_test.gd",`。
4. GDScript 字符串里**不要**写 `\u` / `\x` 转义。
5. 新脚本的 `*.gd.uid` 必须一起提交。
6. 测试唯一入口 `bash tools/test.sh`；**不要并发跑两个 Godot 实例**。
7. **提交前必须绿灯**：`[clock] 失败=0`、`[world_tick] 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、退出码 0。
   把**原始输出**粘进报告。
8. 世界变量必须始终被 clamp 在 `[0,1]`；major 事件受 `MAJOR_EVENT_GAP` + `major_gate` 双闸门约束。

## 执行步骤

1. 确认起点：`git status --short` 为空，`git log --oneline -1` = `dcf25e1`。
2. Step 1：创建 `tests/clock_test.gd`、`tests/world_tick_test.gd`。
3. Step 2：把两个套件加入 `SUITES`，跑 `bash tools/test.sh`，确认**红**
   （`RngService` 未定义 / `缺少数据表: locations`），退出码 1。
4. Step 3：创建 `src/core/rng_service.gd`。
5. Step 4：创建 `data/locations.json`、`data/rumors.json`（**含 label 修正**）。
6. Step 5：修改 `src/core/registry.gd` 的 `TABLE_FILES`。
7. Step 6：在 `src/model/world_state.gd` 的 `add_fact()` 之后追加 `tick()` 等（计划 Step 6 逐字；注意 `tick()` 引用 `RngService`）。
8. Step 7：跑 `bash tools/test.sh` 到绿，记录原始输出。
9. 提交（含 `.uid` 与计划文档）：

```bash
cd /e/Hali
git add src/core/rng_service.gd src/core/registry.gd src/model/world_state.gd \
        data/locations.json data/rumors.json tests/clock_test.gd tests/world_tick_test.gd tests/run_tests.gd \
        src/core/rng_service.gd.uid tests/clock_test.gd.uid tests/world_tick_test.gd.uid \
        docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
git commit -m "feat(world): 确定性随机与月度世界演化"
```

10. **提交后立刻**写报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-5-report.md`。

## 报告格式（task-5-report.md）

```markdown
# Task 5 报告

## 结果
一句话：完成/未完成，测试是否全绿，退出码。

## 提交
<commit hash> <commit message>

## 文件
- 新建：...
- 修改：...

## 计划修正
说明 rumors 缺 label 的修正与依据（Registry.validate 契约 + registry_test 断言）。

## 测试原始输出
<粘贴 bash tools/test.sh 的完整原始输出，含 1/3、2/3、3/3 与 EXIT 码>

## 遇到的问题 / 偏离
如实记录；没有就写「无」。
```

## 完成后返回

最终输出里给出：commit hash、改动文件清单、`bash tools/test.sh` 的结论行（`[clock]` / `[world_tick]` 失败数、`总计失败=0`、`ALL TESTS PASSED`、退出码）、报告文件路径。不要贴大段 diff。
