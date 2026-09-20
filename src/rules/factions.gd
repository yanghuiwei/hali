class_name WorldFactions
extends RefCounted

# 机构 id 枚举：顺序即势力面板的展示顺序（第六十五章）。代码只硬编码 id，中文标签进 data/factions.json 的 institutions。
const INSTITUTIONS: Array[String] = ["law_enforcement", "auror_office", "wizengamot", "mysteries",
	"hogwarts", "gringotts", "daily_prophet", "international"]

# 派系类别枚举（第十二章权力四角 + 第六/二十六章）
const KINDS: Array[String] = ["ministry", "institution", "pureblood", "school", "commerce",
	"media", "resistance", "dark", "foreign", "society"]
const LEGAL_STATUS: Array[String] = ["legal", "shadow", "outlaw"]
const SECRECY: Array[String] = ["public", "semi", "secret"]

# kind → 权力四角（第十二章）。不在表里的 kind（resistance/dark/foreign/society）不进四角，
# 它们通过 control 与政体判定体现影响力。
const CORNERS: Dictionary = {
	"ministry": ["ministry", "institution"],
	"pureblood": ["pureblood"],
	"hogwarts": ["school"],
	"commerce": ["commerce", "media"],
}

const MINISTRY_ID := "ministry"
const RESISTANCE_ID := "order_of_phoenix"

# 状态键（都存在既有容器里：tension 进 world.flags，政体进 world.flags，派系状态进 world.factions）
const TENSION_FLAG := "social_tension"
const GOVERNMENT_FLAG := "government_type"

# domains 白名单（Task 1 审查 Minor 收口：domains 此前零消费零校验，写错没有任何测试会失败）
const DOMAINS: Array[String] = ["law", "administration", "education", "economy", "media",
	"secrecy_enforcement", "warfare", "intelligence"]

# ---------- 内容校验（枚举 + 引用完整性 + 字段类型；registry.validate 只管字段与值域，避免反向依赖） ----------

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
		if not e.has("era_overrides"):
			errors.append("factions/%s: era_overrides 缺失" % id)
		elif typeof(e["era_overrides"]) != TYPE_DICTIONARY:
			errors.append("factions/%s: era_overrides 必须是 Dictionary" % id)
		else:
			for era_id in (e["era_overrides"] as Dictionary).keys():
				if not registry.has("eras", str(era_id)):
					errors.append("factions/%s: era_overrides 引用不存在的时代（%s）" % [id, str(era_id)])
		if not e.has("domains"):
			errors.append("factions/%s: domains 缺失" % id)
		elif typeof(e["domains"]) != TYPE_ARRAY:
			errors.append("factions/%s: domains 必须是数组" % id)
		else:
			for domain in (e["domains"] as Array):
				if not DOMAINS.has(str(domain)):
					errors.append("factions/%s: domain 非法（%s）" % [id, str(domain)])
		if not e.has("aliases"):
			errors.append("factions/%s: aliases 缺失" % id)
		elif typeof(e["aliases"]) != TYPE_ARRAY:
			errors.append("factions/%s: aliases 必须是数组" % id)
		elif (e["aliases"] as Array).is_empty():
			errors.append("factions/%s: aliases 为空" % id)
		else:
			for alias in (e["aliases"] as Array):
				if str(alias).strip_edges().is_empty():
					errors.append("factions/%s: alias 为空（第 %d 项）" % [id, (e["aliases"] as Array).find(alias)])
		if not e.has("base_power"):
			errors.append("factions/%s: base_power 缺失" % id)
		elif typeof(e["base_power"]) != TYPE_INT and typeof(e["base_power"]) != TYPE_FLOAT:
			errors.append("factions/%s: base_power 类型非法（%s）" % [id, str(e["base_power"])])
	return errors

# ---------- 初始化与读取 ----------

# 幂等：只为「还没有状态」的派系建状态；旧存档/已演化的值一律不动。
# clock 为 null 时直接返回：畸形载荷的负例路径（save_test 的毒对象用例）会让 `GameClock.from_dict` 失败并留下 null clock，
# 此时不能再去读 `clock.turn`（会往 stderr 喷 17 条 SCRIPT ERROR）。
static func initialize(world: WorldState) -> void:
	if world == null or world.registry == null or world.clock == null:
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
		"last_change_turn": world.clock.turn if world.clock != null else 0,
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
	# 阈值 0.28：四角归一化下单角现实上限约 1/3（构造用例 0.3010、理论上限 0.3017、默认 0.1627）；原稿 0.45 不可达，见 spec §13.2 勘误（人类裁定 A，2026-09-20）。
	if float(power_share(world).get("pureblood", 0.0)) >= 0.28 and power_of(world, MINISTRY_ID) < 0.5:
		return "pureblood_oligarchy"
	# 4) 默认：官僚制（第十一章第 1 条）
	return "ministry_bureaucracy"
