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

	# ---- 内容校验：Task 1 审查 Minor 的收口（domains / aliases / base_power 类型 / era_overrides）----
	var base_entry := {"id": "x", "label": "甲", "kind": "dark", "legal_status": "legal",
		"secrecy": "public", "base_power": 0.5, "institutions": [], "rivals": [], "allies": [],
		"domains": ["law"], "aliases": ["甲"], "era_overrides": {}}
	var bad_domain_entry := base_entry.duplicate(true)
	bad_domain_entry["domains"] = ["不存在的领域"]
	var bad_domain := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代"}],
		"factions": [bad_domain_entry],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	a.is_true(" | ".join(WorldFactions.validate_content(bad_domain)).contains("domain 非法"),
		"坏 domains 被 validate_content 抓到")

	var bad_alias_entry := base_entry.duplicate(true)
	bad_alias_entry["aliases"] = ["甲", "   "]
	var bad_alias := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代"}],
		"factions": [bad_alias_entry],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	a.is_true(" | ".join(WorldFactions.validate_content(bad_alias)).contains("alias 为空"),
		"空白别名被 validate_content 抓到")

	var bad_alias_type := base_entry.duplicate(true)
	bad_alias_type["aliases"] = []
	var bad_alias_type_reg := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代"}],
		"factions": [bad_alias_type],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	a.is_true(" | ".join(WorldFactions.validate_content(bad_alias_type_reg)).contains("aliases 为空"),
		"空 aliases 数组被 validate_content 抓到")

	var bad_power_entry := base_entry.duplicate(true)
	bad_power_entry["base_power"] = "0.5"
	var bad_power := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代"}],
		"factions": [bad_power_entry],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	a.is_true(" | ".join(WorldFactions.validate_content(bad_power)).contains("base_power 类型非法"),
		"字符串型 base_power 被 validate_content 抓到")

	var no_override_entry := base_entry.duplicate(true)
	no_override_entry.erase("era_overrides")
	var no_override := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代"}],
		"factions": [no_override_entry],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	a.is_true(" | ".join(WorldFactions.validate_content(no_override)).contains("era_overrides 缺失"),
		"缺失 era_overrides 被 validate_content 抓到")

	var bad_override_type_entry := base_entry.duplicate(true)
	bad_override_type_entry["era_overrides"] = ["modern"]
	var bad_override_type := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代"}],
		"factions": [bad_override_type_entry],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	a.is_true(" | ".join(WorldFactions.validate_content(bad_override_type)).contains("era_overrides 必须是 Dictionary"),
		"非字典 era_overrides 被 validate_content 抓到")

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

	# 幂等：只补缺失的条目（部分状态的世界）
	var partial := make_world("modern")
	partial.factions.clear()
	partial.factions["ministry"] = {"power": 0.42, "control": {}, "stance_to_player": 0,
		"revealed": true, "last_change_turn": 7, "notes": []}
	WorldFactions.initialize(partial)
	a.eq(partial.factions.size(), 17, "部分状态的世界补齐到 17 条")
	a.near(WorldFactions.power_of(partial, "ministry"), 0.42, 0.0001, "已存在的条目不被覆盖（部分状态）")

	# 时代覆盖
	var old := make_world("second_wizarding_war")
	WorldFactions.initialize(old)
	a.near(WorldFactions.base_power(old, "ministry"), 0.45, 0.0001, "二战期魔法部 base_power 被覆盖")
	a.near(WorldFactions.base_power(old, "death_eaters"), 0.45, 0.0001, "二战期食死徒 base_power 被覆盖")

	# create() / from_dict() 两条路径都自带补齐（设计 §9.5）
	a.eq(make_world("modern").factions.size(), 17, "create() 路径自动补齐（不需要外部调 initialize）")
	var encoded := SaveCodec.encode(w)
	var decoded := SaveCodec.decode(encoded, reg)
	a.is_true(bool(decoded["ok"]), "往返可解码")
	var restored: WorldState = decoded["world"]
	a.eq(restored.factions.size(), 17, "from_dict() 路径自动补齐")
	a.near(WorldFactions.power_of(restored, "ministry"), 0.75, 0.0001, "读档后派系实力与存档一致")

	# 老存档（完全没有 factions 数据）必须被补齐且不报错
	var legacy_w := make_world("modern")
	legacy_w.factions = {}
	var legacy_text := SaveCodec.encode(legacy_w)
	var legacy_decoded := SaveCodec.decode(legacy_text, reg)
	a.is_true(bool(legacy_decoded["ok"]), "factions 为空的老存档仍可解码")
	a.eq((legacy_decoded["world"] as WorldState).factions.size(), 17, "老存档读档后被补齐到 17 条")

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

	# 平局：取 power 更高者（持平的机构控制权）
	WorldFactions.ensure_state(w, "wizengamot")["control"]["wizengamot"] = 0.70
	WorldFactions.ensure_state(w, "sacred_twenty_eight")["control"]["wizengamot"] = 0.70
	var tie_ic := WorldFactions.institution_control(w)
	a.eq(str((tie_ic["wizengamot"] as Dictionary)["holder"]), "wizengamot", "控制权持平取 power 更高者")
	WorldFactions.ensure_state(w, "wizengamot")["control"]["wizengamot"] = 0.58
	WorldFactions.ensure_state(w, "sacred_twenty_eight")["control"]["wizengamot"] = 0.55

	# 无任何派系声明 control 时：8 个机构键仍全在，value=0.0、holder=""
	var empty_w := make_world("modern")
	for fid in empty_w.registry.ids("factions"):
		empty_w.factions[str(fid)]["control"] = {}
	var empty_ic := WorldFactions.institution_control(empty_w)
	a.eq(empty_ic.keys().size(), WorldFactions.INSTITUTIONS.size(), "机构控制权返回全部 8 个机构键")
	var all_zero := true
	var all_unheld := true
	for inst in WorldFactions.INSTITUTIONS:
		var row: Dictionary = empty_ic[str(inst)]
		if float(row["value"]) != 0.0:
			all_zero = false
		if str(row["holder"]) != "":
			all_unheld = false
	a.is_true(all_zero, "无派系声明时 value 全为 0.0")
	a.is_true(all_unheld, "无派系声明时 holder 全为空串")

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

	# 政体 id 必须都能在内容表里查到（面板/Task 7 依赖）
	for gov_id in ["ministry_bureaucracy", "pureblood_oligarchy", "death_eater_dictatorship", "order_resistance"]:
		a.is_true(reg.has("governments", gov_id), "政体 id 在内容表里：%s" % gov_id)

	return a.report("factions")
