# Task 5 scoped 复审记录（Fix round 1）· ad67396..413cd3f

> 复审者：只读 `reviewer`（deepseek-flash，run 2998066b）｜修复 diff：`review-ad67396..413cd3f.diff`（1 commit / 15670B）
> 结论：**Fix round 1 = Accepted**；I1/M2/M3/M4/M1 全部**已解决**；新引入仅 2 条 Minor（1 处错字 + 1 条附赠弱断言）
> 控制器核对（`task-5-fix1-verify.log`）：`EXIT=0`、`[factions] 160 失败=0`、`[world_tick] 154 失败=0`、`[registry] 237`、`[save] 107`、`SCRIPT ERROR` 2 = 基线。

## Findings 判定

| Finding | 判定 | 复审者独立核实的要点 |
| --- | --- | --- |
| **I1** 死断言 | **已解决** | 夹具与两条**无条件**断言在 `world_tick_test.gd:120-152`（前置 `:130-134`、主体 `:136-149`、强断言 `:150`/`:151-152`）。**关键前提经独立核实成立**：`PlayerState.new_default()` 的 `location_id` 默认 `""`（`player_state.gd:33`），`data/rumors.json` 全部 17 条 `zones` 均非空且不含 `""` ⇒ `world_state.gd:96-97` 对所有传闻为真 ⇒ `candidates` 为空 ⇒ 传闻不抢配额。政治事件选路无概率门（只有阈值+配额两道）⇒ 每次配额允许必出事件（回合 1/13/25/37，最小间隔恰 12） |
| **M2** `last_change_turn` | **已解决** | `factions.gd:297-300` 快照、`:310` 写 `nq`、`:315-316` 压制+量化、`:317-325` 统一判定；断言 `factions_test.gd:633-651`。约束复核：`tick()` 五步未动、无新持久化键、`SAVE_VERSION` 未动、无新 RNG |
| **M3** `tension_of` 路径 | **已解决** | `factions_test.gd:549-560`：写 flags → 改 `world_vars` → 前置断言（`compute_tension` 确实变了）→ 断言 `tension_of == 0.42` 不随变 → 缺 flag 回退。若改成现算必红（`≈0.72` vs `0.42`） |
| **M4** 数字口径 | **已解决** | `factions_test.gd:331-334` 注释已按事实改写、断言未动；复审者独立验算：实际生效下降量 ∈[0.0056,0.0456]（典型 0.0256），6 对未截断潜在合计 ≈0.085≈0.09 |
| **M1** 副作用注释 | **已解决** | `factions.gd:378-379` 已加提示，与 `:407`/`:409` 的副作用相符 |

## M2 语义决定评估（控制器裁定接受「持久值变过」语义）

1. **更强修法正确、双向自洽** ✅：⟹ 方向——快照在任何写入之前取，统一判定覆盖同回合**全部**写入方（回归/压制/量化），"抬高又被压回"被正确判为"未变"（正是旧实现 56/510 假标记的机制）；⟸ 方向——全仓 `last_change_turn` 仅两处写入（建状态 `:134` 与 `:324`），而 `evolve` 先 `initialize` ⇒ `:134` 在同回合内不可达 ⇒ 唯一写入者 `:324`。语义变更与控制器裁定一致，且该字段**无生产读取方**（grep 确认）。
2. **未引入实质新问题** ✅：`power_before = quantize(power_of(...))` 仍在 [0,1]、两侧同网格（差 1e-4 ≫ `is_equal_approx` 容差）；状态缺失侧跳过 ⇒ 无"半写"；两循环以 `str(fid)` 为键 ⇒ 顺序无关。附带行为变化（`control` 滞后改用 `nq`，偏差 ≤1e-4）已被既有 2e-4 容差覆盖。
3. **样本数断言是观测值** ✅：`mark_samples` 由测试侧逐回合×逐派系自增，期望 510 是硬编码字面量；被测代码不产出 510；若循环/夹具写错（如 registry 只剩 1 个派系 → 30 ≠ 510）会红 ⇒ 有效防空转。

## 修复引入的新问题

- **Critical / Important：无**（未改 `tick()` 步骤与顺序、未动存档格式/`SAVE_VERSION`、未新增 RNG 流、无第三方依赖）。
- **Minor 1（错字）**：`factions.gd:379`、`world_tick_test.gd:121`、`:131` 把「过**阈**」写成「过**阀**」→ **并入 Task 6 顺手改正**（Task 6 本来就动 `factions.gd`）。
- **Minor 2（report-only）**：`factions_test.gd:559-560` 第三条断言在缺 flag 时两侧都调 `compute_tension`，近乎恒真；核心判别力由 `:557` 提供，无需改动。

## ⚠️ 复审者无法判定（控制器已处理）
- 破坏实验日志（I1-a/I1-b/M2-a=56/M2-b=453/M3 的 0.769669）不在包内 → 复审者从代码判定方向"均必红"，与实现者数字一致；控制器已核对 `task-5-fix1-verify.log` 的绿灯与断言数。
- 断言数增量算术自洽：`[factions] +5`（M3 3 + M2 2）→ 160；`[world_tick]` 删 1 增 4 → 154。
