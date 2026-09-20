# Task 5 审查记录 · a1fa03d..ab9ceb8

> 审查者：只读 `reviewer`（deepseek-flash，run c4afe7f1）｜审查包：`review-a1fa03d..ab9ceb8.diff`（1 commit / 33380B）
> 结论：**Spec ✅ 符合；Task quality = Approved**；Critical 0 / **Important 1（死断言）** / Minor 9
> 控制器核对（`task-5-test-verify.log`）：`EXIT=0`、`[factions] 155`、`[registry] 237`、`[world_tick] 151`、`[save] 107` 全 0 失败、`SCRIPT ERROR` 2 = 基线。

## Spec Compliance（8 条全绿 + 2 处文档漂移）

1. `data/political_events.json` 5 条、字段齐全、文案与 brief **逐字一致**；表注册于 `"rumors"` 之后（`registry.gd:16`），`_validate_entry` 分支与 brief 逐字相同（`:130-136`）。
2. `compute_tension`（`factions.gd:325-340`）六项权重 + 四角失衡项 + 末级 clamp 与 brief 完全一致。
3. `event_condition_met`（`:348-365`）五条件一致、未知 → false；`oligarchy_pressure` 用 **0.26**。
4. `pick_political_event`（`:367-394`）三重门齐备、同流名同算法、事件字典 6 字段齐全。
5. `tick()` 插入（`world_state.gd:142-150`）位置正确、恰好两段；后三步**只改注释序号**（代码在 diff 中均为上下文行）；传闻事件补 `rumor_id`（`:134`）。
6/7. 收口项 ①（注释订正）与 ②（`structure_pull` 七分支 + 滞后 0.5）齐备（`factions_test.gd:562-582`、`:588-609`）。
8. ⚠️ 文档漂移：计划 `:1172` 的 `pev.get("id")` 应为 `event_id`（控制器已改，见 `ad67396`）；brief Step 3 的 tick 片段仍写 `world`（计划已改）。

## Concerns 判定

| Concern | 判定 | 依据（审查者独立核对） |
| --- | --- | --- |
| **A 量化** | **成立**：是「恢复既有不变量」，对 `§8#50` 只是**收窄触发面**（已按此登记，可接受） | `quantize()` 幂等且确定（`pow/round/clampf`，无 RNG）；`flags["social_tension"]` 生产读取方只有 `tension_of()`；`to_dict`/`SAVE_VERSION`/`SaveCodec` 未动；量化误差 1e-4 远小于阈值间距，E2 用 0.9 vs 0.65 大间距钉住分支 → 不脆 |
| **B `self`** | **确认**：`world_state.gd:143/146` 均为 `self`，`src/` 内无遗留裸 `world` | grep 全仓 + 计划/设计文档对比 |
| **C 容差 2e-4** | **诚实且仍有判别力** | 既有断言容差**一个都没被动过**（diff 删除行只有两行注释）；系数 0.5→0.25 偏差 0.0955 ≫ 2e-4；删 `TENSION_FLAG` 时 `:538` 的 `has()` 会红 |

## 点名 6 风险的结论

1. 量化 vs `last_change_turn`：判据在量化**之前** → 约 0.2%/派系/月 不自洽（无生产读取方）→ **Minor 2**。
2. `events` 顺序：无既有断言依赖 `events[0]` 类型；`events_block` 按 `category/text` 通用渲染 → **无影响**。
3. `last_major_turn` 共用：不会饿死，但存在**系统性偏向**——高张力时代政治事件几乎吃掉全部重大配额（≈95%），现代 era 一个都不触发（手算 tension≈0.33）→ **Minor 6**。
4. `pick_political_event` 的 `add_fact` 副作用：当前 tick 路径一致（`evolve()` 先整体求值再 append）→ **Minor 1（plan-mandated）**。
5. `tension_of`(量化) vs `compute_tension`：差 ≤1e-4；假绿只在删 flag 写入时成立，被 `:538` 拦住 → **Minor 3**。
6. `apply_rumor_reveals` 空实现：确认零副作用，无断言依赖 → **无问题**。

## Issues

### Important（1，已进修复轮）
**I1** `tests/world_tick_test.gd:129-131` **死断言**：`:129` 恒真；`:131` 被 `if political_count >= 2` 挡住；夹具 `modern`（tension≈0.33 < 0.55）→ 40 回合政治事件恒 0 → 该块**从未断言任何东西**。交叉印证：实现者 E7 自述 8 条红，审查者逐条数出正好 8 条、**该块贡献 0 条**。

### Minor（9）
1. `pick_political_event` 三重副作用（plan-mandated）→ 控制器已改计划加提示（`ad67396`）。
2. `last_change_turn` 用未量化 `next` 判定 → 修复轮按更强修法收口（见 rereview）。
3. `:541` 的 `near` 判别力弱于文案 → 修复轮补 flags 路径断言。
4. ⚠️**控制器给的数字是错的**：「六对累计压制 ≈0.06」→ 实际生效下降量 ∈[0.0056,0.0456]、≈0.09 是**未截断潜在**合计 → 修复轮改注释口径。
5. `§8#50` 只是收窄（`world_vars`/`player.*`/`flags` 未处理）→ **Task 13 必须保证它不被当"已结案"**。
6. 按 era 的事件配比需普查后调参 → Task 13/03b。
7. `factions.gd` 428 行 / 6+ 职责 → 控制器裁定不拆分（Task 6 后评估）。
8. `secrecy_crisis` 无对应内容（只在单测可达）→ 登记为内容缺口。
9. 计划 `:1172` key 名 → 控制器已改（`ad67396`）。
