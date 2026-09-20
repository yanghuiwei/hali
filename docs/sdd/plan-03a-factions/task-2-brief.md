### Task 2: `WorldFactions` 规则层（初始化 / 机构控制权 / 权力四角 / 政体推导）

**Files:**
- Modify: `src/rules/factions.gd`（加函数）、`src/model/world_state.gd`（`create()`/`from_dict()` 调 `initialize`）、`src/ui/main.gd`（把 `validate_content` 的错误也打进 `push_warning`）
- Test: `tests/factions_test.gd`（新建，必须加进 `SUITES`）、`tests/registry_test.gd`（引用完整性交叉检查）

**Interfaces:**
- Consumes: Task 1 的常量与内容表；`Registry.ids/entry/has`；`WorldState.registry/era_id/clock/factions/flags/world_vars`。
- Produces（后续任务全部依赖这些签名，**不得改名**）：
  - `static func validate_content(registry: Registry) -> PackedStringArray`
  - `static func initialize(world: WorldState) -> void`（幂等）
  - `static func ensure_state(world: WorldState, faction_id: String) -> Dictionary`
  - `static func state_of(world: WorldState, faction_id: String) -> Dictionary`
  - `static func base_power(world: WorldState, faction_id: String) -> float`
  - `static func power_of(world: WorldState, faction_id: String) -> float`
  - `static func power_share(world: WorldState) -> Dictionary`（4 键，和为 1）
  - `static func institution_control(world: WorldState) -> Dictionary`（`{inst: {"value": float, "holder": String}}`）
  - `static func government_type(world: WorldState) -> String`

- [ ] **Step 1: 写失败测试**

新建 `tests/factions_test.gd`：

```gdscript
class_name FactionsTest
extends RefCounted

func make_world(era_id: String = "modern") -> WorldState:
	var reg := Registry.load_default()
	var p := PlayerState.new_default()
	p.name_text = "测试者"
	p.bloodline_id = "half_blood"
	p.birth_identity_id = "ordinary_wizard_family"
	p.house_id = "gryffindor"
	p.aptitude_id = "normal"
	p.location_id = "london_muggle"
	return WorldState.create(era_id, p, 12345, reg)

func run() -> int:
	var a := TestAssert.new()

	# ---- 内容校验 ----
	var reg := Registry.load_default()
	a.eq(WorldFactions.validate_content(reg).size(), 0, "内容表引用/枚举全部合法")

	var broken := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代", "world_vars": {}}],
		"factions": [
			{"id": "a", "label": "甲", "kind": "dark", "legal_status": "legal", "secrecy": "public",
				"base_power": 0.5, "institutions": ["bogus"], "rivals": ["不存在"], "allies": []},
		],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	var broken_errors := " | ".join(WorldFactions.validate_content(broken))
	a.is_true(broken_errors.contains("机构非法"), "坏 institutions 被 validate_content 抓到")
	a.is_true(broken_errors.contains("引用不存在"), "坏 rivals 被 validate_content 抓到")

	# ---- 初始化 ----
	var w := make_world("modern")
	WorldFactions.initialize(w)
	a.eq(w.factions.size(), 17, "初始化后 17 个派系都有状态")
	var ministry := WorldFactions.state_of(w, "ministry")
	a.near(float(ministry["power"]), 0.75, 0.0001, "魔法部 power 取 base_power")
	a.is_true(bool(ministry["revealed"]), "public 派系初始已揭示")
	a.is_true(not WorldFactions.state_of(w, "death_eaters").is_empty(), "食死徒有状态")
	a.is_false(bool(WorldFactions.state_of(w, "death_eaters")["revealed"]), "secret 派系初始未揭示")
	var control: Dictionary = ministry["control"]
	a.near(float(control.get("law_enforcement", 0.0)), 0.75, 0.0001, "机构控制权初始 = base_power")

	# 幂等：已有状态不被覆盖
	w.factions["ministry"]["power"] = 0.10
	WorldFactions.initialize(w)
	a.near(WorldFactions.power_of(w, "ministry"), 0.10, 0.0001, "initialize 幂等（不覆盖已有值）")
	w.factions["ministry"]["power"] = 0.75

	# 时代覆盖
	var old := make_world("second_wizarding_war")
	WorldFactions.initialize(old)
	a.near(WorldFactions.base_power(old, "ministry"), 0.45, 0.0001, "二战期魔法部 base_power 被覆盖")
	a.near(WorldFactions.base_power(old, "death_eaters"), 0.45, 0.0001, "二战期食死徒 base_power 被覆盖")

	# ---- 权力四角 ----
	var share := WorldFactions.power_share(w)
	var total := 0.0
	for k in share.keys():
		total += float(share[k])
	a.near(total, 1.0, 0.0001, "权力四角归一化到 1")
	a.eq(share.keys().size(), 4, "权力四角只有 4 键")

	# ---- 机构控制权归并 ----
	WorldFactions.ensure_state(w, "death_eaters")["control"]["law_enforcement"] = 0.90
	var ic := WorldFactions.institution_control(w)
	a.eq(str((ic["law_enforcement"] as Dictionary)["holder"]), "death_eaters", "控制权最高的派系成为 holder")
	a.near(float((ic["law_enforcement"] as Dictionary)["value"]), 0.90, 0.0001, "holder 的值取最大值")
	a.eq(str((ic["international"] as Dictionary)["holder"]), "international_confederation", "国际机构 holder")
	WorldFactions.ensure_state(w, "death_eaters")["control"]["law_enforcement"] = 0.05

	# ---- 政体推导：四种格局各一条构造用例 ----
	w.world_vars["war_pressure"] = 0.2
	a.eq(WorldFactions.government_type(w), "ministry_bureaucracy", "默认格局 → 官僚制")

	WorldFactions.ensure_state(w, "sacred_twenty_eight")["power"] = 0.9
	WorldFactions.ensure_state(w, "reformist_pureblood")["power"] = 0.9
	WorldFactions.ensure_state(w, "ministry")["power"] = 0.30
	a.eq(WorldFactions.government_type(w), "pureblood_oligarchy", "纯血权重高 + 魔法部弱 → 寡头制")

	WorldFactions.ensure_state(w, "ministry")["power"] = 0.75
	WorldFactions.ensure_state(w, "death_eaters")["power"] = 0.8
	WorldFactions.ensure_state(w, "death_eaters")["control"]["law_enforcement"] = 0.7
	WorldFactions.ensure_state(w, "death_eaters")["control"]["wizengamot"] = 0.7
	a.eq(WorldFactions.government_type(w), "death_eater_dictatorship", "黑暗势力掌握司法 → 独裁")

	WorldFactions.ensure_state(w, "death_eaters")["control"]["law_enforcement"] = 0.0
	WorldFactions.ensure_state(w, "death_eaters")["control"]["wizengamot"] = 0.0
	WorldFactions.ensure_state(w, "order_of_phoenix")["power"] = 0.95
	w.world_vars["war_pressure"] = 0.8
	a.eq(WorldFactions.government_type(w), "order_resistance", "战争压力高 + 抵抗组织最强 → 凤凰社抵抗")

	return a.report("factions")
```

同时：
1) 在 `tests/run_tests.gd` 的 `SUITES` 末尾追加 `"res://tests/factions_test.gd",`
2) 在 `tests/registry_test.gd` 末尾追加一条与 `WorldFactions` 常量的一致性断言（防两处枚举漂移）：

```gdscript
	# registry 的表内枚举与 WorldFactions 常量必须一致（防两处定义漂移）
	a.eq(insts, WorldFactions.INSTITUTIONS, "机构枚举两处一致")
	a.eq(kinds, WorldFactions.KINDS, "kind 枚举两处一致")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|缺少测试套件|总计"`
Expected: `[factions]` 套件报错（`WorldFactions.initialize` 等未定义 → 套件未调用 `report`，运行器判失败）。

- [ ] **Step 3: 实现**

在 `src/rules/factions.gd` 追加（常量之后）：

```gdscript
# ---------- 内容校验（枚举 + 引用完整性；registry.validate 只管字段与值域，避免反向依赖） ----------

static func validate_content(registry: Registry) -> PackedStringArray:
	var errors := PackedStringArray()
	for fid in registry.ids("factions"):
		var id := str(fid)
		var e := registry.entry("factions", id)
		for inst in (e.get("institutions", []) as Array):
			if not INSTITUTIONS.has(str(inst)):
				errors.append("factions/%s: 机构非法（%s）" % [id, str(inst)])
		for field in ["rivals", "allies"]:
			for other in (e.get(field, []) as Array):
				if not registry.has("factions", str(other)):
					errors.append("factions/%s: %s 引用不存在的派系（%s）" % [id, field, str(other)])
		var overrides = e.get("era_overrides", {})
		if typeof(overrides) == TYPE_DICTIONARY:
			for era_id in (overrides as Dictionary).keys():
				if not registry.has("eras", str(era_id)):
					errors.append("factions/%s: era_overrides 引用不存在的时代（%s）" % [id, str(era_id)])
	return errors

# ---------- 初始化与读取 ----------

# 幂等：只为「还没有状态」的派系建状态；旧存档/已演化的值一律不动。
static func initialize(world: WorldState) -> void:
	if world == null or world.registry == null:
		return
	if typeof(world.factions) != TYPE_DICTIONARY:
		world.factions = {}
	for fid in world.registry.ids("factions"):
		ensure_state(world, str(fid))

static func entry_of(world: WorldState, faction_id: String) -> Dictionary:
	return world.registry.entry("factions", faction_id)

static func base_power(world: WorldState, faction_id: String) -> float:
	var entry := entry_of(world, faction_id)
	var p := float(entry.get("base_power", 0.0))
	var overrides = entry.get("era_overrides", {})
	if typeof(overrides) == TYPE_DICTIONARY and (overrides as Dictionary).has(world.era_id):
		var o = (overrides as Dictionary)[world.era_id]
		if typeof(o) == TYPE_DICTIONARY and (o as Dictionary).has("base_power"):
			p = float((o as Dictionary)["base_power"])
	return clampf(p, 0.0, 1.0)

static func ensure_state(world: WorldState, faction_id: String) -> Dictionary:
	if typeof(world.factions) != TYPE_DICTIONARY:
		world.factions = {}
	var existing = world.factions.get(faction_id, null)
	if typeof(existing) == TYPE_DICTIONARY:
		return existing
	var entry := entry_of(world, faction_id)
	if entry.is_empty():
		return {}
	var power := base_power(world, faction_id)
	var control := {}
	for inst in (entry.get("institutions", []) as Array):
		control[str(inst)] = power
	var st := {
		"power": power,
		"control": control,
		"stance_to_player": 0,
		"revealed": str(entry.get("secrecy", "public")) == "public",
		"last_change_turn": world.clock.turn,
		"notes": [],
	}
	world.factions[faction_id] = st
	return st

static func state_of(world: WorldState, faction_id: String) -> Dictionary:
	if typeof(world.factions) != TYPE_DICTIONARY:
		return {}
	var st = world.factions.get(faction_id, null)
	return st if typeof(st) == TYPE_DICTIONARY else {}

static func power_of(world: WorldState, faction_id: String) -> float:
	return clampf(float(state_of(world, faction_id).get("power", 0.0)), 0.0, 1.0)

# ---------- 权力四角（第十二章） ----------

static func power_share(world: WorldState) -> Dictionary:
	var totals := {"ministry": 0.0, "pureblood": 0.0, "hogwarts": 0.0, "commerce": 0.0}
	for fid in world.registry.ids("factions"):
		var kind := str(entry_of(world, str(fid)).get("kind", ""))
		for corner in CORNERS.keys():
			if (CORNERS[corner] as Array).has(kind):
				totals[corner] = float(totals[corner]) + power_of(world, str(fid))
	var sum := 0.0
	for key in totals.keys():
		sum += float(totals[key])
	if sum <= 0.0:
		return {"ministry": 0.25, "pureblood": 0.25, "hogwarts": 0.25, "commerce": 0.25}
	var out := {}
	for key in totals.keys():
		out[key] = float(totals[key]) / sum
	return out

# ---------- 机构控制权（第二十六章） ----------

static func institution_control(world: WorldState) -> Dictionary:
	var out := {}
	for inst in INSTITUTIONS:
		out[inst] = {"value": 0.0, "holder": ""}
	for fid in world.registry.ids("factions"):
		var id := str(fid)
		var control = state_of(world, id).get("control", {})
		if typeof(control) != TYPE_DICTIONARY:
			continue
		for inst in (control as Dictionary).keys():
			if not out.has(str(inst)):
				continue
			var value := clampf(float((control as Dictionary)[inst]), 0.0, 1.0)
			var current: Dictionary = out[str(inst)]
			var better := value > float(current["value"])
			if is_equal_approx(value, float(current["value"])):
				better = power_of(world, id) > power_of(world, str(current["holder"]))
			if better:
				out[str(inst)] = {"value": value, "holder": id}
	return out

# ---------- 政体推导（第十一章 + 第十二章） ----------

static func government_type(world: WorldState) -> String:
	var ic := institution_control(world)
	var law := float((ic["law_enforcement"] as Dictionary)["value"])
	var wiz := float((ic["wizengamot"] as Dictionary)["value"])
	# 1) 凤凰社抵抗：战争压力高 + 抵抗组织强于魔法部（第十一章第 4 条）
	if float(world.world_vars.get("war_pressure", 0.0)) >= 0.6 \
			and power_of(world, RESISTANCE_ID) > power_of(world, MINISTRY_ID):
		return "order_resistance"
	# 2) 食死徒独裁：黑暗势力掌握执法与司法（第十一章第 3 条）
	var dark_sum := 0.0
	var dark_count := 0
	for fid in world.registry.ids("factions"):
		var id := str(fid)
		if str(entry_of(world, id).get("kind", "")) != "dark":
			continue
		var control: Dictionary = state_of(world, id).get("control", {})
		for inst in ["law_enforcement", "wizengamot"]:
			dark_sum += clampf(float(control.get(inst, law if inst == "law_enforcement" else wiz)), 0.0, 1.0)
			dark_count += 1
	if dark_count > 0 and (dark_sum / float(dark_count)) >= 0.6:
		return "death_eater_dictatorship"
	# 3) 纯血寡头：纯血权重高 + 魔法部弱（第十一章第 2 条）
	if float(power_share(world).get("pureblood", 0.0)) >= 0.45 and power_of(world, MINISTRY_ID) < 0.5:
		return "pureblood_oligarchy"
	# 4) 默认：官僚制（第十一章第 1 条）
	return "ministry_bureaucracy"
```

修改 `src/model/world_state.gd`：

1) `create()` 的 `return w` 之前插入：

```gdscript
	WorldFactions.initialize(w)
```

2) `from_dict()` 的 `return w` 之前插入：

```gdscript
	# 老存档（无 factions 或只有部分）在此补齐；幂等，不覆盖已存档的值（设计 §9.3/§9.5）
	WorldFactions.initialize(w)
```

修改 `src/ui/main.gd` 的 `_ready()`：

```gdscript
	var errors := registry.validate()
	errors.append_array(WorldFactions.validate_content(registry))
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[registry\]|^\[save\]|总计|全部通过"`
Expected: `[factions] 断言=... 失败=0`；其余套件失败=0；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/rules/factions.gd src/model/world_state.gd src/ui/main.gd tests/factions_test.gd tests/factions_test.gd.uid tests/registry_test.gd tests/run_tests.gd
git commit -m "feat(factions): WorldFactions 规则层（初始化/控制权/权力四角/政体推导）（计划 03a Task 2）"
```

---

