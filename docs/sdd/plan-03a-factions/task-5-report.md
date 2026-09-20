# Task 5 实现报告 · 社会矛盾 tension + 政治事件 + tick 接线

**任务**：计划 03a Task 5（brief：`.superpowers/sdd/2026-09-20-hp-magic-era-03-factions/task-5-brief.md`）
**提交**：`ab9ceb8`（单提交，7 files / +369 −7）
**状态**：DONE_WITH_CONCERNS（绿灯 + 破坏实验全过；但含 2 处**超出 brief** 的必要改动 + 1 处**计划文本缺陷**，需控制器裁定/改计划，见 §8）

---

## 1. 改动 / 新建文件清单

| 文件 | 类型 | 内容 |
| --- | --- | --- |
| `data/political_events.json` | **新建**（12 行） | 5 条政治事件内容，文案逐字取自 brief（改革运动 / 政变 / 阿兹卡班越狱 / 古灵阁金融危机 / 魔法部镇压） |
| `src/core/registry.gd` | 改（+8） | `TABLE_FILES` 注册 `"political_events"`；`_validate_entry` 增加该表分支（`category` ∈ {politics,economy,law}、`text` 非空、`condition` 非空） |
| `src/rules/factions.gd` | 改（+111 −1） | 新增 `TENSION_THRESHOLD=0.55`、`compute_tension`、`tension_of`、`event_condition_met`、`pick_political_event`、`apply_rumor_reveals`（**空实现**，Task 6 填实）；`evolve()` 末尾写 `TENSION_FLAG` 并返回事件数组；新增 `QUANTIZE_DECIMALS=4`、`quantize()`、`quantize_state()`（见 §8-A） |
| `src/model/world_state.gd` | 改（+15 −7） | `tick()` 在传闻阶段后插入「③ 传闻揭示」「④ 派系演化」两步并把后三步注释顺延为 5/6/7；传闻事件字典补 `"rumor_id"` |
| `tests/factions_test.gd` | 改（+149） | tension/事件/tick 接线 + 裁定 4a 注释订正 + 裁定 4b（`structure_pull` 七分支 + `society` 恒 0 + 控制权滞后） |
| `tests/registry_test.gd` | 改（+29） | 新表 5 条/字段/`condition` 白名单/坏内容三条红例 |
| `tests/world_tick_test.gd` | 改（+52） | tick 既有语义未被破坏 + 传闻事件结构（含 `rumor_id`）+ 政治事件 12 个月间隔 + 派系状态界内 |

新建内容表**没有**产生 `.uid`/`.import`（JSON 不是导入资源）；`git status` 提交后干净。

---

## 2. 流程证据：红 → 绿

### 步 1–2：先写失败测试，确认「红」

`bash tools/test.sh` → **EXIT=1**（原始输出：`task-5-test-red.log`）

```
[registry] 政治事件表 5 条: 期望 <5>，实际 <0>
[registry] 五个政治事件的条件互不重复（实际 0 种）: 期望 <5>，实际 <0>
[registry] 政治事件坏 category 必须报错: 期望为真
[registry] 政治事件缺 text 必须报错: 期望为真
[registry] 政治事件缺 condition 必须报错: 期望为真
[registry] 断言=217 失败=5
==== 总计失败=7，失败套件=3 ====
SCRIPT ERROR: Parse Error: Static function "compute_tension()" not found in base "WorldFactions".   （同类共 20 条）
```

`[factions]` / `[world_tick]` 两个套件因缺 `compute_tension`/`TENSION_THRESHOLD`/`event_condition_met` 而**编译失败**（合计 3 个失败套件 = registry + factions + world_tick），证明「红」是缺实现而不是测试写错。

> 红步的 5 条 registry 失败里有 **1 条是我测试自己写错**：`五个政治事件的条件互不重复` 期望 5 种，但 `coup_attempt` 与 `crackdown` 都指向 `lawlessness`（内容表里只有 4 种条件）。已改为「每条 `condition` 必须落在代码白名单内 + 至少覆盖 4 种不同条件」——这比数个数更有判别力（能抓条件名写错）。

### 步 3–4：实现后跑绿

`bash tools/test.sh` → **EXIT=0**（原始输出：`task-5-test-green.log`）

```
[harness] 断言=8 失败=0
[registry] 断言=237 失败=0
[money] 断言=18 失败=0
[magic_level] 断言=48 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=151 失败=0
[creation] 断言=176 失败=0
[spell] 断言=229 失败=0
[gm] 断言=71 失败=0
[panel] 断言=71 失败=0
[selfcheck] 断言=32 失败=0
[save] 断言=107 失败=0
[async_probe] 断言=2 失败=0
[llm] 断言=88 失败=0
[prompt] 断言=13 失败=0
[debug_mirror] 断言=23 失败=0
[factions] 断言=155 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
...
main scene ready, godot=4.7.2-stable (official)
[HALI] PROBE-APPEND-MARK
全部通过。
```

- `[probe] 断言=1 失败=1` 是断言库自检探针（故意失败，不在 `SUITES` 里）。
- **`SCRIPT ERROR` 条数 = 2，基线 = 2**（`task-1-baseline.log`）：本次新增 0 条噪音。那 2 条分别是 `save_test.gd:80` 的畸形载荷负例与解析层负例，均为既有刻意噪音。

---

## 3. 断言数前后对比（基线 = Task 4 修复轮后 `task-4-fix1-verify.log`）

| 套件 | 前 | 后 | Δ | 说明 |
| --- | --- | --- | --- | --- |
| `[factions]` | 115 | **155** | **+40** | tension/事件/tick 接线 + 4a/4b 收口 |
| `[registry]` | 212 | **237** | **+25** | 新表字段/条件白名单/坏内容 |
| `[world_tick]` | 104 | **151** | **+47** | tick 语义 + 事件结构与配额 |
| `[save]` | 107 | 107 | 0 | 但**内容**变了：它现在会因为 ULP 往返而变红（见 §8-A），是本次的隐形护栏 |
| 其余 15 个套件 | — | — | 0 | `[gm] 71`、`[panel] 71`、`[llm] 88`、`[prompt] 13`、`[debug_mirror] 23` 等全部不变 |

---

## 4. 裁定 4b 收口（含「能失败」的证据）

### 4a 注释事实订正（`tests/factions_test.gd:328`）
原文写「death_eaters 同时是 **4** 对的败者（ministry/auror_office/order_of_phoenix/hogwarts），四对合计压制 ≈ **0.09**」。
I1 修复（无向对键）后它同时是 **6** 对的败者：`ministry / auror_office / wizengamot / mysteries / hogwarts / order_of_phoenix`（`wizengamot`、`mysteries` 正是 I1 之前被静默丢弃的那两对），各对压制被各自下限 `max(0.05, base×0.25)` 截断，实际生效下降量合计 ≈ **0.06**。已按事实改写，**未动任何断言**。

### 4b-1 `structure_pull` 分支方向（brief 之前只有 ministry/dark/resistance 有断言）

新增 7 条：`institution`（部里越稳越强）、`pureblood`、`commerce`、`media`、`foreign`、`school` 各自方向正确；`society`（未列入 match 的 kind）**恒为 0.0**。
**能失败的证据**：破坏实验 **E5**（把 `_` 分支 `return 0.0` 改成 `return 0.10`）→
`[factions] society（未列入 match 的 kind）拉力恒为 0，不泄漏其他分支: 期望 0.000000 ± 0.000000，实际 0.100000`（runner 退出码 1）。

### 4b-2 机构控制权以 0.5 系数向实力靠拢

用「只有一个派系、无 rivals」的最小夹具排除敌对压制对 `power` 的二次修改，于是 `evolve` 后的 `power` 就是滞后所用的 `next`，可精确核对 `control_after == control_before + (power_after − control_before) × 0.5`；另加前置断言 `solo_power < 0.9`（否则 relation 断言可能空转）。
**容差 2e-4** 的理由：`evolve` 末尾会量化到 1e-4（§8-A），关系式只在量化精度内成立；把系数改成 0.25 偏差 ≈ 0.1 ≫ 2e-4，断言仍会红。
**能失败的证据**：**E4**（系数 0.5 → 0.25）→ `期望 0.691000 ± 0.000200，实际 0.595500`（退出码 1）。

---

## 5. 破坏实验 E1–E7（逐条证明新断言/新代码可失败）

方法：每次改一处 → 只跑 `--script res://tests/run_tests.gd`（含 stdout+stderr）→ 记录 → 从备份逐字还原 → `md5sum` 校验。
**实验前后 md5 完全一致**（`factions.gd 53fabfc2…`、`world_state.gd 1b883b4f…`）。

| # | 破坏 | 结果 | 命中的断言 |
| --- | --- | --- | --- |
| **E1** | 注释掉 `evolve()` 末尾的 `quantize_state(world)` | **红**（1 失败） | `[save] 读档后重建引擎续跑：世界状态一致` → 证明量化是**承重**的（§8-A） |
| **E2** | `oligarchy_pressure` 阈值 0.26 → 0.40（计划原稿的死分支） | **红**（1 失败） | `[factions] 纯血占比达标即触发寡头压力（power_share 分支单独可判）` |
| **E3** | 删掉 `world.flags[TENSION_FLAG] = …` | **红** | `[factions] tick 后 tension 已写入 flags: 期望为真` |
| **E4** | 控制权滞后系数 0.5 → 0.25 | **红** | `[factions] 机构控制权以 0.5 系数向新实力靠拢…` |
| **E5** | `structure_pull` 的 `_` 分支返回 0.10 | **红** | `[factions] society…拉力恒为 0…` |
| **E6** | 传闻事件去掉 `"rumor_id"` | **红**（2 失败） | `[world_tick] 传闻事件含 rumor_id（Task 6 揭示用）: 缺少键 <rumor_id>` + `rumor_id 是内容表里的真实传闻` |
| **E7** | `pick_political_event()` 开头直接 `return {}` | **红**（8 失败） | `[factions] tick 返回的 events 里含派系/政治事件: 期望为真` 等 |

### 实验暴露并已修掉的两处**断言盲区**（这是本轮最有价值的产出）

1. **E2 首跑没红**：我最初只用 `angry`（`pureblood_influence=0.9`）断言 `oligarchy_pressure`，而该条件是 `power_share ≥ 0.26 **or** pureblood_influence ≥ 0.65` —— **OR 的另一条救场**，把阈值改成不可达的 0.40 照样绿。
   **修法**：新增专用用例 `olig`（`pureblood_influence=0.30` 明确 < 0.65 + 两派纯血 power 0.9），并加两条**前置断言**（占比 ≥0.26、influence <0.65）确保不是别的分支救场。修后 E2 干净变红。
2. **E6 首跑是「套件中止」而不是干净失败**：我原来写 `str(e["rumor_id"])`，缺键时下标访问抛运行期错误、整个 `world_tick` 套件中止（靠运行器的 `report_calls` 哨兵才被判失败——正是 `§8#56` 描述的陷阱）。
   **修法**：改成 `str(e.get("rumor_id", ""))`，缺键时得到一条**干净**的断言失败（E6 重跑 → 2 条失败，其中一条明确写「缺少键 <rumor_id>」）。

---

## 6. tick 既有语义未被破坏（证据）

`tests/world_tick_test.gd` 新增块（断言全部通过）：

- `年龄仍每回合 +1`（`age_months` 前/后对比）
- `回合仍每回合 +1`（`clock.turn` 前/后对比）
- `日志仍被裁剪到 200 条以内`
- `政体缓存已写入`（新增阶段确实跑到了）
- 既有断言保持不变并继续通过：`a.eq(reg.validate().size(), 0, "新增表后仍无校验错误")`、240 个月的 `major 事件 ≤ 20 / min_gap ≥ 12`、`wa.tick() == wb.tick()`（同 seed 完全一致）、信息保护（不泄漏「魔法部内幕」）、`world_vars` 全部落在 `[0,1]`。
- 新增阶段的位置与顺序：传闻筛选 → **③ `apply_rumor_reveals`（空实现）** → **④ `WorldFactions.evolve()`** → ⑤ 生活基线 → ⑥ 年龄 → ⑦ 日志裁剪；后三步只改了注释序号，**代码逐字未动**。
- 政治事件**占用与传闻共用的 `last_major_turn` 配额**，因此 240 个月里 major 事件总数仍 ≤ 20、相邻间隔仍 ≥ 12（既有断言未变红即是证据）。

---

## 7. 事件通道证据

| 断言 | 结果 |
| --- | --- |
| 事件来自内容表（`event_id` ∈ `political_events`） | ✅ |
| `kind == "faction"`、`turn == clock.turn`、`text` 非空、`major` | ✅ |
| 写 `history`（`add_fact("major", …)`） | ✅ |
| 写 `last_major_turn == clock.turn`，**同回合第二次调用返回空**（`MAJOR_EVENT_GAP`） | ✅ |
| tick 返回的 `events` 与写进 `world.log` 的 `kind=="faction"` 事件**条数相等** | ✅ |
| 低 tension（`calm` 世界）**一个都选不出来** | ✅ |
| 事件条件逐条正/负例：`economic_slump` / `oligarchy_pressure` / `lawlessness` / `war_exhaustion` / `secrecy_crisis` / 未知条件恒 false | ✅ |

---

## 8. 偏离 brief 之处与计划文本缺陷（**需控制器处理**）

### A. 超出 brief 的新增：数值量化（`QUANTIZE_DECIMALS=4` + `quantize_state()`）—— 必要，但不在 brief 里

**现象**：接上演化后 `[save]` 的既有不变量断言 `a.eq(w3r.to_dict(), w3.to_dict(), "读档后重建引擎续跑：世界状态一致")` 变红。**根因不是 key 顺序**（Godot 的 Dictionary `==` 与顺序无关，已实测证明），而是 **1 ULP**：

```
内存值     0.21739610501640022
存盘文本   "power":0.21739610501640022      ← 文本逐字正确
解析回来   0.21739610501640025              ← 差 1 ULP，a - b = -2.78e-17
```

即计划 02 登记的 `§8#50`（`full_precision` 不保证 double 逐位往返）被**新触发面**激活：回归+噪声产生的连续长尾浮点恰好命中它。这会让「存档往返逐字一致」这条计划 01 的设计不变量失效。
**修法**：`evolve()` 末尾把 `power` / `control` / `tension` 量化到 **4 位小数**（幂等；远超玩法精度，面板只显示 2 位），从而让持久化数值的文本短、往返稳定。**不改存档格式与 `SAVE_VERSION`。**
**证据**：E1（注释掉量化 → save 断言变红）；量化后全仓绿。
⚠️ **控制器需要做的**：计划 Task 4/5 的 `evolve()` 代码块都没有这一步 → 请照「改计划、不顺着错的计划写实现」补进计划（否则 Task 6 之后照抄者会再次踩坑）。另外这也意味着 Task 4 的计划文本与实现又出现一处漂移。

### B. 计划 Task 5 Step 3 的 tick 片段用了**未定义标识符** `world`

brief（与计划原文）写：
```gdscript
	WorldFactions.apply_rumor_reveals(world, events)
	for political_event in WorldFactions.evolve(world):
```
但这段代码要插进 **`WorldState.tick()` 内部**，那里没有 `world` 这个变量（成员是 `self`）→ 直接照抄会得到
`SCRIPT ERROR: Parse Error: Identifier "world" not declared in the current scope.`（红步日志 6 条）。
**我改为 `self`**（语义等价、必然如此）。⚠️ 请控制器改计划 Task 5 的代码块（`world` → `self`），否则下一个任务照抄还会踩。

### C. 我对**自己新写的断言**放松了两处容差（都有注释说明，不是放宽既有断言）

`tension_of(tw) vs compute_tension(tw)` 与 4b-2 的控制权关系式，容差从 1e-6 放到 **2e-4** —— 因为 `flags` 里存的是**量化后**的 tension、`control` 也被量化（§8-A）。既有测试的容差**一个都没动**（`save_test` 那条严格等式反而因量化重新变绿）。

---

## 9. 未验证项 / 残余

1. **政治事件在真实玩法里的频率未观察**：只做了构造用例与 240 个月的配额约束断言，没有「连续 100 回合的具体事件分布」统计。事件频率是否体感过高/过低需要实跑（配合 B1 镜像通道最方便）。
2. **`oligarchy_pressure` 的 0.26 与 `government_type` 的 0.28 是两套阈值**：前者是「事件条件」、后者是「政体判定」，两者语义不同但数值接近，可能在未来调参时互相干扰（建议 Task 13 或 03b 一并复核）。
3. **`secrecy_crisis` 条件没有对应内容**：`event_condition_met` 支持 5 种条件，但 `data/political_events.json` 里没有 `secrecy_crisis` 事件（brief 只给了 5 条内容、其中 4 种条件）→ 该分支目前**只在单测里可达**、生产路径不可达。这是内容缺口，不是代码缺陷（登记）。
4. **`apply_rumor_reveals` 是空实现**（按裁定）：`tick` 每回合都会调一次它，当前是 no-op；Task 6 填实前，「传闻揭示」这一步没有可观测效果（已在断言上避免依赖它）。
5. **量化精度是拍数**：4 位小数对 power/control 足够，但如果将来要把 `power` 用于更精细的权重计算（03b 经济挂钩），需要复核 1e-4 是否够（当前 `power_share` 归一化误差 ~1e-4 级别，面板只显示 2 位）。
6. **`stance_to_player` 仍是 int**、`notes` 仍是空数组（本任务未涉及），未做量化（int 无需）。

---

## 10. 是否触碰 brief 未列出的文件

**没有。** 改动恰好是 brief「Files」列出的 7 个文件：新建 `data/political_events.json`；改 `src/core/registry.gd`、`src/rules/factions.gd`、`src/model/world_state.gd`、`tests/factions_test.gd`、`tests/registry_test.gd`、`tests/world_tick_test.gd`。
（裁定 4a/4b 的收口都落在 brief 已允许的 `tests/factions_test.gd` / `src/rules/factions.gd` 内。）
无新增脚本 → 无需 `.uid`；无临时探针残留（`tools/_tmp_*.gd` 均已删除，`git status` 干净）。


---

# 修复轮 1（审查后）

**提交**：`413cd3f`（3 files / +94 −17：`src/rules/factions.gd`、`tests/factions_test.gd`、`tests/world_tick_test.gd`）
**绿灯**：`bash tools/test.sh` → **EXIT=0**；`[factions] 160 失败=0`、`[world_tick] 154 失败=0`、`[registry] 237 失败=0`、`[save] 107 失败=0`；`总计失败=0，失败套件=0`；**`SCRIPT ERROR` 2 条 = 基线 2 条**
（原始输出：`task-5-fix1-green.log`）
**破坏实验**：5/5 均按预期变红（见下），每次实验后源码 `md5sum` 逐字还原（`exp2/orig.md5` 对照一致）

---

## I1（Important）死断言 → 换成高张力夹具（选方案 (a)）

### 为什么选 (a) 而不是 (b)
(b)（删掉这段、指注释到既有 240 月断言）成本更低，但那样「政治事件**真的会触发**」这件事只在 `factions_test` 的构造调用里被覆盖，而**跨 tick 的真实链路**（`tick → evolve → pick → events/log`）在 `world_tick_test` 里就没有断言了；而这一层恰恰是 Task 6（传闻揭示）与后续面板要依赖的。方案 (a) 用可控夹具把这条链路钉住，代价只是几十行、跑 40 回合（很快），所以我选 (a)。

### 修法
```gdscript
	# 高张力夹具：每月重置极端 world_vars（模拟持续紧张的世界），使 tension 恒过阈、条件恒成立，
	# 于是「事件是否触发」只由配额（MAJOR_EVENT_GAP）决定；玩家无地点 ⇒ 传闻候选集为空 ⇒ 配额纯归政治事件。
	var tense := WorldState.create("modern", PlayerState.new_default(), 777, pre_reg)
	... 每月重置 corruption/pureblood_influence/war_pressure = 0.99，muggle/economy/secrecy = 0.01 ...
	for i in 40:
		<重置 world_vars>
		for e in tense.tick():
			if str(e.get("kind", "")) == "faction":
				faction_events += 1
				political_gap = mini(political_gap, int(e["turn"]) - political_last)
				political_last = int(e["turn"])
	a.is_true(faction_events >= 2, "高张力世界 40 回合内至少触发 2 次政治事件（实际=%d）" % faction_events)
	a.is_true(political_gap >= WorldState.MAJOR_EVENT_GAP,
		"相邻政治事件至少相隔 %d 个月（实际最小间隔=%d）" % [WorldState.MAJOR_EVENT_GAP, political_gap])
```
并加**两条前置断言**（放在进入循环前，防「条件没成立 → 计数 0 → 静默空转」）：
- `compute_tension(tense) >= TENSION_THRESHOLD`
- `event_condition_met(tense, "lawlessness") and event_condition_met(tense, "war_exhaustion") and event_condition_met(tense, "economic_slump")`

设计要点：玩家 `location_id` 保持默认空串 → 传闻候选集为空 → 传闻重大事件不会抢配额 → 配额完全由政治事件支配 → 间隔断言变成**无条件**的强断言（不再是 `if political_count >= 2`）。实测事件出现在第 1/13/25/37 回合（4 次、最小间隔恰好 12）。

### 能失败的证据（两条破坏实验，原始输出）

**I1-a：让 `pick_political_event()` 恒返回 `{}`**
```
=== I1-a 让 pick_political_event 恒返回 {}（新夹具必须变红）
    退出码=1   ==== 总计失败=9，失败套件=2 ====
    >> [world_tick] 高张力世界 40 回合内至少触发 2 次政治事件（实际=0）: 期望为真
```

**I1-b：不写 `world.flags["last_major_turn"]`（破坏配额）**
```
=== I1-b 不占用 last_major_turn 配额（间隔断言必须变红）
    退出码=1   ==== 总计失败=5，失败套件=2 ====
    >> [world_tick] 相邻政治事件至少相隔 12 个月（实际最小间隔=1）: 期望为真
```
即：**旧版这段代码在两种破坏下都是绿的**（它当时恒真/被 `if` 挡住），新版两种破坏下都红 —— 这正是「死断言 → 真断言」的判据。

---

## M2（真实缺陷）`last_change_turn` 自洽 —— 我做的是**比最小修法更进一步**的修法，附理由

### 最小修法不够：断言跑出了 55/510 个假标记
先按审查者建议的最小修法实现（`var nq := clampf(quantize(next), …)`，用 `is_equal_approx(nq, current)` 就地判定），然后写下「持久值未变却标记」的不变量断言，**它当场红了**：
```
[factions] 不存在「量化后持久值未变却标记本月变化」的假标记（510 个样本）: 期望 <0>，实际 <55>
```
用一次性探针定位（`tools/_tmp_m2probe.gd`，已删）：
```
STALE turn=1 death_eaters before=0.05 after=0.05
STALE turn=2 death_eaters before=0.05 after=0.05
...
```
机制**不是量化**，而是**敌对压制把值改回来了**：`death_eaters` 的回归步骤把它推高到 0.0501（于是标记本月变化），紧接着 `apply_rival_pressure()`（它同时是 6 对的败者）又把它压回下限 0.05 → 持久值前后一样（0.05 → 0.05），却带着「本月变了」的标记。而最小修法动的是「判定用什么值」，动不了「判定发生在压制之前」这件事。

### 实际修法：把标记判定移到本回合所有写入**之后**，按持久值双向统一
```gdscript
	# 先快照本回合开始时的量化持久值
	var power_before: Dictionary = {}
	for fid in world.registry.ids("factions"):
		power_before[str(fid)] = quantize(power_of(world, str(fid)))
	... 回归循环（写 nq、control 滞后，不在这里标记）...
	apply_rival_pressure(world)
	quantize_state(world)
	# 统一判定：只有「量化持久值真的变了」的派系才标记本月变化
	for fid in world.registry.ids("factions"):
		var mark_id := str(fid)
		var mark_state := state_of(world, mark_id)
		if mark_state.is_empty():
			continue
		if not is_equal_approx(quantize(float(mark_state.get("power", 0.0))), float(power_before.get(mark_id, 0.0))):
			mark_state["last_change_turn"] = world.clock.turn
```
这样 `last_change_turn` 的语义变成「**本回合持久值变过**」，两个方向都自洽（也不再需要循环内那个量化判据）。**这比控制器给的最小修法多覆盖了「压制改值不标记」这一半**；如果你认为「压制不应影响 last_change_turn 语义」，那本条只剩最小修法的一半、并且我的断言要收窄到只查单向——**请裁定**。

### 断言（双向）+ 能失败的证据
```gdscript
	a.eq(mark_mismatch, 0, "last_change_turn 与「量化持久值是否真的变了」双向一致（%d 个样本）" % mark_samples)
	a.is_true(mark_samples == 510, "样本数应为 30 回合 × 17 派系 = 510（实际=%d，防循环写错导致空转）" % mark_samples)
```
```
=== M2-a 还原旧实现（循环内用未量化 next 判定 + 去掉统一判定）
    退出码=1   ==== 总计失败=1，失败套件=1 ====
    >> [factions] last_change_turn 与「量化持久值是否真的变了」双向一致（510 个样本）: 期望 <0>，实际 <56>
=== M2-b 只去掉统一判定（标记承重性）
    退出码=1   ==== 总计失败=1，失败套件=1 ====
    >> ... : 期望 <0>，实际 <453>
```
`M2-a` 复现的正是旧实现的 bug（56 个不一致）；`M2-b` 证明新增的统一判定循环是承重的（去掉后 453 个不一致）。修后两个方向都是 0。

---

## M3（断言判别力）`tension_of` 必须走 flags 路径

```gdscript
	var tf := make_world("modern")
	tf.flags[WorldFactions.TENSION_FLAG] = 0.42
	var tension_before := WorldFactions.compute_tension(tf)
	tf.world_vars["corruption"] = 0.99
	tf.world_vars["war_pressure"] = 0.99
	tf.world_vars["muggle_relations"] = 0.01
	a.is_true(WorldFactions.compute_tension(tf) > tension_before + 0.05, "前置：改 world_vars 后 compute_tension 确实变了（否则下面的断言会空转）")
	a.near(WorldFactions.tension_of(tf), 0.42, 0.0000001, "tension_of 读 flags：不随 world_vars 变")
	tf.flags.erase(WorldFactions.TENSION_FLAG)
	a.near(WorldFactions.tension_of(tf), WorldFactions.compute_tension(tf), 0.0000001, "只有缺 flags 时才回退到现算")
```
**能失败的证据**：
```
=== M3 tension_of 改成每次现算（flags 路径断言必须变红）
    退出码=1   ==== 总计失败=1，失败套件=1 ====
    >> [factions] tension_of 读 flags：不随 world_vars 变: 期望 0.420000 ± 0.000000，实际 0.769669
```
原来的 `near(tension_of(tw), compute_tension(tw), 2e-4)` 保留（它验证「同一口径」），但判别力现在由这条补上。

---

## M4（数字口径）/ M1（一行注释）

- **M4**：`tests/factions_test.gd` 的夹具注释已改为与事实一致 —— 「这 6 对的**未截断潜在**压制合计 ≈0.09；但本夹具压制前 power = 0.06+(0.45−0.06)×0.04+noise = 0.0756±0.02，下限 = max(0.05, 0.05×0.25) = 0.05，所以**实际生效的下降量** ∈ [0.0056, 0.0456]（典型 ≈0.026）；关键是它远大于所需余量，且下限 0.05 使终值必然落在下限」。**未改任何断言。**
- **M1**：`pick_political_event()` 上方代码注释已加副作用提示：
  ```gdscript
  # 注意：本函数有副作用（命中时写 history 并占用 last_major_turn 配额），不是纯查询；请勿用于预览/面板。
  ```

---

## 本轮断言数变化

| 套件 | 修复轮前 | 修复轮后 | 说明 |
| --- | --- | --- | --- |
| `[factions]` | 155 | **160** | +M2 双向不变量（2 条）+ M3（3 条） |
| `[world_tick]` | 151 | **154** | I1 换夹具后：前置 2 条 + 事件计数/间隔 2 条（原死段 1+1 条删除） |
| 其余 | — | 0 变化 | `[registry] 237`、`[save] 107` 等均不变 |

---

## 本轮新增未验证项 / 残余

1. **`apply_rival_pressure` 现在会影响 `last_change_turn`**（我把它纳入统一判定）→ 语义从「回归是否改动」变成「持久值是否改动」。这是我主动做的语义收窄，**需要你确认**（见 M2 小节的裁定请求）。
2. M2 断言用的是 **modern + 17 派系 + 30 回合**的样本（510）；没有覆盖「目标值等于当前值」的极端静止世界（那种世界里 power 几乎不变、标记应恒为 false——理论上同样成立，但未单独构造）。
3. I1 夹具的**每月重置 world_vars** 是测试装置（模拟持续紧张），不代表真实演化；真实频率分布仍未普查（控制器已登记 M6 由 Task 13/03b 处理）。
