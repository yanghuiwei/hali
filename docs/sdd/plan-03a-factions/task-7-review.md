# Task 7 审查记录 · 0be229f..9e896de

> 审查者：只读 `reviewer`（deepseek-flash，run 2b83a0b9）｜审查包：`review-0be229f..9e896de.diff`（1 commit / 5 files / +161-15）
> 结论：**Spec ✅ 符合；Task quality = Approved**；Critical 0 / **Important 0** / Minor 7 → **无修复轮**
> 控制器核对：`task-7-test-verify.log`（`EXIT=0`、`[panel] 99`、`[factions] 193`、`[save] 112`、`[world_tick] 180`、`SCRIPT ERROR` 2 = 基线）；**`task-7-b1-verify.log`：`bash tools/b1_acceptance.sh` → 断言 78 / 失败 0 / EXIT=0**（审查者列的 ⚠️ 项 5 由此闭合）。

## Spec Compliance（5/5）

1. **行 1 的 10 项指标** ✅ 逐参数核对（`panel_formatter.gd:112-121`）：4 项机构级来自 `institution_control()` 的 value+holder；5 项标量来自 `world_vars`；政体经 `_label(world,"governments",…)`。旧「7 标签→4 world_vars」错映射（`war_pressure` 冒「法律执行」、`国际←muggle_relations`）**已被完全替换**；`panel_test.gd:118` 钉住全文无「待定」。
2. **行 2 霍格沃茨 / 行 3 家族** ✅（`panel_formatter.gd:122-126`、`:129-138`；无家族时占位「无家族（家族制度属计划 03c）」）。
3. **行 4【已知势力】** ✅ 只遍历 `visible_faction_ids()`、实力降序、带立场与 `[所属]`、空集占位。
4. **收口 4a/4b/4c** ✅ 均在各自 `return a.report(...)` 之前：4a `factions_test.gd:763-772`（**状态型**：`reveal()==false` **且** `state_of(...).is_empty()`）；4b `save_test.gd:189-197`（reveal → encode/decode → 读档后仍在可见列表 + `factions.size()==17`）；4c `world_tick_test.gd:40-47`（对 `w.log` 每条 `kind=="rumor"` 断言 `rumor_id` 非空，**用 `.get` 不用下标**，另有 `>=1` 防空转）。
5. **既有断言未被削弱** ✅ `panel_test.gd:74-84` 的 15 字段循环保留，panel_test hunk **纯新增无删除**。

## 六个点名风险的结论

1. **`_institution_value()` 与 brief 内联等价** ✅：`institution_control()` 对 8 个机构**恒**写入 `{"value": float, "holder": String}`（`factions.gd:183-205`），故 `.get("value", 0.0)` 在所有可达输入上与 brief 的 `["value"]` 输出相同；`null→0.0` 路径不存在；holder 空 → 「无人」与 brief 一致。
2. **隐藏派系控制权「值」仍显示** → 判定 **可接受**（见 M1）。
3. **`sort_custom` 并列顺序** → **不会 flaky**：输入序固定（`registry.ids()`）、比较函数确定；唯一排序断言钉的是**唯一最大者**（魔法部 0.75 vs 次高 0.65）。
4. **政体缓存路径** ✅ 无陈旧风险：`world_vars` 唯一改写点是 `tick()` 内部，而 `evolve()` 在同一次 tick **尾部**写缓存 → 同回合原子刷新；缺缓存（新建/旧档）走现算回退并有断言。
5. **holder 未揭示判定与信息保护一致** ✅：面板中派系标签只有两个出口（`_institution_holder_label` 6 次调用、`_known_factions_line`），二者共用 `visible_faction_ids()` 口径。
6. **既有断言未被削弱** ✅（同上）。
7. **报告可核对性** ✅：绿灯/红步日志、2 条基线 `SCRIPT ERROR`（与 `task-1-baseline.log:19/28` 逐字相同）、断言数增量（+28/+2/+5/+26）全部可从包内复核；红步 `96 + 3 = 99` **证实报告 §⑦.1 的自曝**（3 条政体缓存断言是红步后补的，非 TDD 红步）。

## Strengths（节选）

- **§8#7 是"结构性 + 行为式"双证据修复**：先钉 `is_false(world_vars.has("auror_office"))` 排除标量来源，再用改 control 到 0.90 观察面板变化；比单纯字符串断言强得多。
- **信息保护集中到单一出口**（`_institution_holder_label`），把「值=世界事实、身份=受保护」这条裁定落成一处可复用守卫，且【已知势力】行复用同一 `visible_faction_ids()` 口径 → 不存在两套揭示语义。
- 4a 用状态型断言替代弱断言并写明旧三条 `is_false` 为何无判别力；4c 用 `.get` + 防空转，正是 Task 5 E6 教训的正确应用。

## Issues

### Critical / Important
无。

### Minor（7，全部登记并给出归属）

| # | 内容（file:line） | 控制器裁定/归属 |
| --- | --- | --- |
| **M1** | 隐藏派系控制权**值**仍显示（`panel_formatter.gd:115-119,148-154`）→ 玩家能观察到「存在一个未知强权」。审查者判**不越界**（第四十三/五十七章保护的是**身份/时点真相**；面板任何位置都无未揭示派系的 label/id；值本身是派生世界事实，替代方案更糟） | **接受**。已登记升级条件：若人类把「不得主动剧透隐藏真相」读作涵盖**存在性**，则升为 Important(plan-mandated)。留 03b/05「信息可信度」评估是否把数值模糊化 |
| **M2** | `_institution_value` 的防御性默认值 `0.0` 当前不可达（`:142-143`） | 登记（纯可读性） |
| **M3** | `sort_custom` 并列顺序未定义（`:167`） | 登记：若将来断言第二/第三名，须先定平局序（如 power 相同按 id 升序） |
| **M4** | `tools/b1_acceptance.gd:269` 的观察文案**已过期**（还写着「§8#7 …映射到 4 个 world_vars …已登记」），且验收通道对势力面板**只断言标题**、零回归判别力 | **并入 Task 8**：更新文案 + 补一条「机构指标随派系控制权变化」式断言 |
| **M5** | `panel_formatter.gd:46` `player_panel` 的【所属势力】打印原始 `faction_id`（如 `death_eaters`），既不用 `_label` 也不查揭示 | **并入 Task 8**：改用 `_label(world,"factions",…)` + 补 panel_test 断言 |
| **M6** | 霍格沃茨行把正典的「院长」换成「校方控制」并**去掉「派系」**字段（plan-mandated，报告未登记） | **控制器裁定：接受**（「派系」信息由「校方控制」+【已知势力】覆盖，单列会重复）；**Task 13 在 `HANDOFF §8` 登记为有意的面板偏差 + 理由** |
| **M7** | ① 报告称 holder label 调 `visible_faction_ids()` 5 次、实为 6 次；② `panel_test` 把 `0.75/0.60/0.58/0.90/0.91` 硬编码绑定 `data/factions.json` 的 `base_power`（内容微调即红） | ① 登记（无功能影响）；② 登记：审查者认定"钉住具体行为可接受的取舍"，暂不改为从 registry 取数 |
