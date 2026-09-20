### Task 5: 社会矛盾 `tension` + 政治事件 + `tick()` 接线

**Files:**
- Create: `data/political_events.json`
- Modify: `src/core/registry.gd`、`src/rules/factions.gd`、`src/model/world_state.gd`
- Test: `tests/factions_test.gd`、`tests/registry_test.gd`、`tests/world_tick_test.gd`

**Interfaces:**
- Consumes: Task 4 的 `evolve()`；既有 `WorldState.MAJOR_EVENT_GAP`、`world.flags["last_major_turn"]`、`world.add_fact()`。
- Produces:
  - 表名 `"political_events"`（字段 `id,label,category,condition,text,major`）
  - `static func compute_tension(world: WorldState) -> float`（0..1，纯函数）
  - `static func tension_of(world: WorldState) -> float`（读 `flags[TENSION_FLAG]`，缺省现算）
  - `static func event_condition_met(world: WorldState, condition: String) -> bool`
  - `static func pick_political_event(world: WorldState) -> Dictionary`
  - `static func apply_rumor_reveals(world: WorldState, events: Array) -> void`（本任务先给空实现，Task 6 填实）
  - 常量 `TENSION_THRESHOLD := 0.55`
  - `evolve()` 现在返回事件数组（元素含 `kind="faction"`、`category`、`text`、`major`、`turn`、`event_id`）

- [ ] **Step 1: 写失败测试**

在 `tests/factions_test.gd` 末尾追加：

```gdscript
	# ---- 社会矛盾与政治事件（Task 5） ----
	var calm := make_world("modern")
	calm.world_vars["corruption"] = 0.05
	calm.world_vars["pureblood_influence"] = 0.05
	calm.world_vars["muggle_relations"] = 0.9
	calm.world_vars["war_pressure"] = 0.05
	calm.world_vars["economy_index"] = 0.9
	calm.world_vars["secrecy_integrity"] = 0.95
	var angry := make_world("modern")
	angry.world_vars["corruption"] = 0.9
	angry.world_vars["pureblood_influence"] = 0.9
	angry.world_vars["muggle_relations"] = 0.1
	angry.world_vars["war_pressure"] = 0.9
	angry.world_vars["economy_index"] = 0.1
	angry.world_vars["secrecy_integrity"] = 0.1
	a.between(WorldFactions.compute_tension(calm), 0.0, 1.0, "tension 值域")
	a.is_true(WorldFactions.compute_tension(angry) > WorldFactions.compute_tension(calm),
		"腐败/纯血/战争高、经济差 → tension 更高")

	WorldFactions.initialize(angry)
	a.is_true(WorldFactions.event_condition_met(angry, "economic_slump"), "经济萧条条件成立")
	a.is_false(WorldFactions.event_condition_met(calm, "economic_slump"), "经济好时不成立")
	a.is_true(WorldFactions.event_condition_met(angry, "oligarchy_pressure"), "寡头压力条件成立")
	a.is_false(WorldFactions.event_condition_met(calm, "oligarchy_pressure"), "无寡头压力时不成立")
	a.is_false(WorldFactions.event_condition_met(angry, "不存在的条件"), "未知条件恒不成立")

	var pev := WorldFactions.pick_political_event(angry)
	a.is_true(not pev.is_empty(), "紧张局势下能选出政治事件")
	a.is_true(angry.registry.has("political_events", str(pev.get("id", ""))), "事件 id 来自内容表")
	a.is_true(not str(pev.get("text", "")).is_empty(), "事件有文案")
	a.eq(int(angry.flags.get("last_major_turn", -1)), angry.clock.turn, "事件占用本月重大事件配额")
	a.is_true(WorldFactions.pick_political_event(angry).is_empty(), "同一回合不再重复触发（MAJOR_EVENT_GAP）")

	# tick 接线：evolve 产出的事件进入本回合 events 与 log
	var tw := make_world("modern")
	tw.world_vars["corruption"] = 0.95
	tw.world_vars["pureblood_influence"] = 0.95
	tw.world_vars["muggle_relations"] = 0.05
	tw.world_vars["war_pressure"] = 0.95
	tw.world_vars["economy_index"] = 0.05
	tw.world_vars["secrecy_integrity"] = 0.05
	tw.flags["last_major_turn"] = -99
	var tick_events := tw.tick()
	a.is_true(tw.flags.has(WorldFactions.TENSION_FLAG), "tick 后 tension 已写入 flags")
	a.is_true(tw.flags.has(WorldFactions.GOVERNMENT_FLAG), "tick 后政体缓存已写入 flags")
	var politics := 0
	var in_log := 0
	for ev in tick_events:
		if str(ev.get("kind", "")) == "faction":
			politics += 1
	for ev in tw.log:
		if str(ev.get("kind", "")) == "faction":
			in_log += 1
	a.is_true(politics >= 1, "tick 返回的 events 里含派系/政治事件")
	a.eq(in_log, politics, "同一批事件也进了 world.log")
```

在 `tests/registry_test.gd` 的派系段追加：

```gdscript
	a.eq(reg.ids("political_events").size(), 5, "政治事件表 5 条")
	for eid in reg.ids("political_events"):
		var pe := reg.entry("political_events", str(eid))
		a.is_true(not str(pe.get("text", "")).is_empty(), "政治事件 %s 有文案" % str(eid))
		a.is_true(["politics", "economy", "law"].has(str(pe.get("category", ""))), "政治事件 %s category 合法" % str(eid))
```

在 `tests/world_tick_test.gd` 的 `run()` 末尾（`return a.report("world_tick")` 之前）追加：

```gdscript
	# ---- 计划 03a：新增演化阶段不得破坏 tick 的既有语义 ----
	var pre_reg := Registry.load_default()
	var pre_w := WorldState.create("modern", PlayerState.new_default(), 4242, pre_reg)
	var age_before := pre_w.player.age_months
	var turn_before := pre_w.clock.turn
	pre_w.tick()
	a.eq(pre_w.player.age_months, age_before + 1, "年龄仍每回合 +1")
	a.eq(pre_w.clock.turn, turn_before + 1, "回合仍每回合 +1")
	a.is_true(pre_w.log.size() <= 200, "日志仍被裁剪到 200 条以内")
	a.is_true(pre_w.flags.has(WorldFactions.GOVERNMENT_FLAG), "政体缓存已写入")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[registry\]|^\[world_tick\]|总计"`
Expected: 失败（`compute_tension` 等未定义；`political_events` 表缺失）。

- [ ] **Step 3: 实现**

新建 `data/political_events.json`：

```json
[
  {"id": "reform_movement", "label": "改革运动", "category": "politics", "condition": "oligarchy_pressure", "major": true,
   "text": "《预言家日报》称，一批麻瓜出身巫师与改革派纯血联名要求威森加摩改革席位分配；纯血家族则指责有人「借改革之名夺权」。"},
  {"id": "coup_attempt", "label": "政变", "category": "politics", "condition": "lawlessness", "major": true,
   "text": "魔法部内部传出消息：有人试图用夺魂咒控制关键部门的司长。政变没有成功，但没人说得清到底是谁在动手。"},
  {"id": "prison_break", "label": "阿兹卡班越狱", "category": "law", "condition": "war_exhaustion", "major": true,
   "text": "阿兹卡班发生越狱。摄魂怪失职的说法在巫师之间流传，魔法部只承认「正在统计失踪人数」。"},
  {"id": "financial_crisis", "label": "古灵阁金融危机", "category": "economy", "condition": "economic_slump", "major": true,
   "text": "古灵阁收紧兑付，几家老店开始只收加隆不收西可。《预言家日报》称之为「技术性调整」，对角巷的店主们管它叫挤兑。"},
  {"id": "crackdown", "label": "魔法部镇压", "category": "law", "condition": "lawlessness", "major": true,
   "text": "魔法部宣布一批「保密法违规」的紧急逮捕令。被抓的人里有走私犯，也有只是说了几句难听话的普通巫师。"}
]
```

`src/core/registry.gd`：`TABLE_FILES` 增加 `"political_events": "political_events.json",`（放在 `"rumors"` 之后）。`_validate_entry` 增加分支：

```gdscript
	if table_name == "political_events":
		if not ["politics", "economy", "law"].has(str(e.get("category", ""))):
			errors.append("%s: category 非法" % where)
		if str(e.get("text", "")).is_empty():
			errors.append("%s: 缺少 text" % where)
		if str(e.get("condition", "")).is_empty():
			errors.append("%s: 缺少 condition" % where)
```

`src/rules/factions.gd`：把 `evolve()` 的 `return []` 替换为：

```gdscript
	world.flags[GOVERNMENT_FLAG] = government_type(world)
	world.flags[TENSION_FLAG] = compute_tension(world)
	var events: Array = []
	var picked := pick_political_event(world)
	if not picked.is_empty():
		events.append(picked)
	return events
```

并追加：

```gdscript
# ---------- 社会矛盾与政治事件（第四十六/四十九/六十八章） ----------

const TENSION_THRESHOLD := 0.55

# 社会矛盾：腐败、纯血垄断、保密法紧张、战争、经济衰退、四角失衡共同累积（正典第四十九章）
static func compute_tension(world: WorldState) -> float:
	var v := world.world_vars
	var corruption := float(v.get("corruption", 0.3))
	var pureblood := float(v.get("pureblood_influence", 0.3))
	var muggle := float(v.get("muggle_relations", 0.5))
	var war := float(v.get("war_pressure", 0.2))
	var economy := float(v.get("economy_index", 0.6))
	var secrecy := float(v.get("secrecy_integrity", 0.8))
	var raw := corruption * 0.25 + pureblood * 0.20 + (1.0 - muggle) * 0.15 \
		+ war * 0.20 + (1.0 - economy) * 0.15 + (1.0 - secrecy) * 0.05
	var share := power_share(world)
	var top := 0.0
	for key in share.keys():
		top = maxf(top, float(share[key]))
	raw += clampf((top - 0.25) * 0.5, 0.0, 0.25)
	return clampf(raw, 0.0, 1.0)

static func tension_of(world: WorldState) -> float:
	if world.flags.has(TENSION_FLAG):
		return clampf(float(world.flags[TENSION_FLAG]), 0.0, 1.0)
	return compute_tension(world)

# 事件条件：代码判定，文案在 data/political_events.json（内容进 data）
static func event_condition_met(world: WorldState, condition: String) -> bool:
	var v := world.world_vars
	match condition:
		"economic_slump":
			return float(v.get("economy_index", 0.6)) <= 0.35
		"oligarchy_pressure":
			return float(power_share(world).get("pureblood", 0.0)) >= 0.26 \
				or float(v.get("pureblood_influence", 0.3)) >= 0.65
		"lawlessness":
			return float(v.get("corruption", 0.3)) >= 0.65 \
				or government_type(world) == "death_eater_dictatorship"
		"war_exhaustion":
			return float(v.get("war_pressure", 0.2)) >= 0.65
		"secrecy_crisis":
			return float(v.get("secrecy_integrity", 0.8)) <= 0.30
		_:
			return false

# 选举本月政治事件：必须同时满足「tension 过阈」「条件成立」「重大事件配额可用」（第六十八章）
static func pick_political_event(world: WorldState) -> Dictionary:
	if tension_of(world) < TENSION_THRESHOLD:
		return {}
	var last_major := int(world.flags.get("last_major_turn", -WorldState.MAJOR_EVENT_GAP))
	if world.clock.turn - last_major < WorldState.MAJOR_EVENT_GAP:
		return {}
	var candidates: Array = []
	for eid in world.registry.ids("political_events"):
		var entry := world.registry.entry("political_events", str(eid))
		if event_condition_met(world, str(entry.get("condition", ""))):
			candidates.append(entry)
	if candidates.is_empty():
		return {}
	var rng := RngService.new(world.game_seed + world.clock.turn * 524287)
	var picked: Dictionary = rng.stream_pick("political_event", candidates)
	if picked.is_empty():
		return {}
	world.flags["last_major_turn"] = world.clock.turn
	var ev := {
		"kind": "faction",
		"category": str(picked.get("category", "politics")),
		"text": str(picked.get("text", "")),
		"major": bool(picked.get("major", true)),
		"turn": world.clock.turn,
		"event_id": str(picked.get("id", "")),
	}
	world.add_fact("major", str(picked.get("text", "")))
	return ev

# Task 6 填实：把传闻事件里指向的派系标记为已揭示
static func apply_rumor_reveals(world: WorldState, _events: Array) -> void:
	pass
```

`src/model/world_state.gd` 的 `tick()`：在既有「2) 本月区级动态」代码块**之后**、「3) 生活基线」**之前**插入两段，并把后面三步的注释序号改为 5/6/7：

```gdscript
	# 3) 计划 03a：传闻揭示（第四十三/五十七章）——玩家通过传闻获知秘密派系
	WorldFactions.apply_rumor_reveals(world, events)

	# 4) 计划 03a：派系与政治演化（第十二/四十六/四十七/四十九章）
	for political_event in WorldFactions.evolve(world):
		events.append(political_event)
		log.append(political_event)
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[registry\]|^\[world_tick\]|总计|全部通过"`
Expected: 全部 `失败=0`；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add data/political_events.json src/core/registry.gd src/rules/factions.gd src/model/world_state.gd tests/factions_test.gd tests/registry_test.gd tests/world_tick_test.gd
git commit -m "feat(factions): 社会矛盾与政治事件 + tick 演化接线（计划 03a Task 5）"
```

---

