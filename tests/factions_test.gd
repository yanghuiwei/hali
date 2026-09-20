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

	# ---- 玩家立场与加入/退出（Task 3） ----
	var pw := make_world("modern")
	WorldFactions.initialize(pw)
	a.eq(pw.player.standing, {}, "初始无立场记录")
	a.eq(pw.player.standing_of("ministry"), 0, "未记录即 0")

	var errs := StateOps.apply(pw, [
		{"op": "join_faction", "faction_id": "不存在的派系"},
	])
	a.is_true(" | ".join(errs).contains("未知派系"), "加入未知派系被拒")
	a.eq(pw.player.faction_id, "", "被拒的加入不写状态")

	errs = StateOps.apply(pw, [{"op": "join_faction", "faction_id": "death_eaters"}])
	a.is_true(" | ".join(errs).contains("未揭示"), "未揭示的派系不能加入")
	a.eq(pw.player.faction_id, "", "未揭示派系的加入不写状态")

	errs = StateOps.apply(pw, [{"op": "join_faction", "faction_id": "ministry"}])
	a.eq(errs.size(), 0, "加入已揭示派系无错误")
	a.eq(pw.player.faction_id, "ministry", "所属写入")

	errs = StateOps.apply(pw, [{"op": "faction_standing_delta", "faction_id": "ministry", "delta": 500}])
	a.eq(errs.size(), 0, "立场调整无错误")
	a.eq(pw.player.standing_of("ministry"), 100, "立场钳到 100")
	a.is_true(int(WorldFactions.state_of(pw, "ministry").get("stance_to_player", 0)) > 0,
		"玩家立场反向影响派系对玩家的态度")

	errs = StateOps.apply(pw, [{"op": "leave_faction"}])
	a.eq(errs.size(), 0, "退出无错误")
	a.eq(pw.player.faction_id, "", "退出后无所属")
	a.eq(pw.player.standing_of("ministry"), 100, "退出不清立场")

	# outlaw 派系：先揭示才能加入；加入成功但要留痕（正典第五十章允许，代价留 03c）
	WorldFactions.ensure_state(pw, "death_eaters")["revealed"] = true
	errs = StateOps.apply(pw, [{"op": "join_faction", "faction_id": "death_eaters"}])
	a.eq(pw.player.faction_id, "death_eaters", "已揭示的 outlaw 派系可以加入")
	a.eq(str(pw.flags.get("illegal_affiliation", "")), "death_eaters", "非法所属被记录进 flags")
	a.is_true(" | ".join(errs).contains("非法"), "非法所属给出警告")

	# ---- 演化：确定性、结构拉力、政体缓存（Task 4，brief 原文） ----
	var e1 := make_world("modern")
	var e2 := make_world("modern")
	WorldFactions.initialize(e1)
	WorldFactions.initialize(e2)
	for i in 3:
		WorldFactions.evolve(e1)
		WorldFactions.evolve(e2)
	for fid in e1.registry.ids("factions"):
		a.near(WorldFactions.power_of(e1, str(fid)), WorldFactions.power_of(e2, str(fid)), 0.0000001,
			"%s 实力演化可复现（同 seed）" % str(fid))
	# 逐字段对比（M2 修复轮 1：原先的 compared_fields/expected_fields 是同源算术互证，已改成真逐字段遍历）：
	# 遍历 17 派系的实际键集（power / control / revealed / stance_to_player / last_change_turn / notes），
	# 逐键用类型严格的 != 比较并把差异收集成列表，最后断言差异为 0；JSON 整体序列化作为冗余护栏。
	var compared_fields := 0
	var mismatches: Array[String] = []
	for fid in e1.registry.ids("factions"):
		var st1: Dictionary = WorldFactions.state_of(e1, str(fid))
		var st2: Dictionary = WorldFactions.state_of(e2, str(fid))
		var keys: Array = st1.keys().duplicate()
		for key in st2.keys():
			if not keys.has(key):
				keys.append(key)
		for key in keys:
			compared_fields += 1
			if st1.get(key, null) != st2.get(key, null):
				mismatches.append("%s.%s" % [str(fid), str(key)])
	a.eq(compared_fields, 102, "逐字段对比实际遍历 102 个字段（17 派系 × 6 键）")
	a.eq(mismatches.size(), 0, "同 seed 双世界逐字段全等（差异字段：%s）" % str(mismatches))
	a.eq(JSON.stringify(e1.factions), JSON.stringify(e2.factions),
		"同 seed 双世界的 factions 字典整体序列化一致（冗余护栏，%d 字段）" % compared_fields)
	a.eq(str(e1.flags.get(WorldFactions.GOVERNMENT_FLAG, "")), WorldFactions.government_type(e1),
		"演化后政体缓存与本回合推导一致")
	a.is_true(e1.registry.has("governments", str(e1.flags[WorldFactions.GOVERNMENT_FLAG])),
		"政体缓存 id 在内容表里存在")

	# 结构拉力：战争/腐败推高黑暗势力与抵抗组织，压低魔法部目标值
	var hawk := make_world("modern")
	hawk.world_vars["war_pressure"] = 0.9
	hawk.world_vars["corruption"] = 0.8
	var dove := make_world("modern")
	dove.world_vars["war_pressure"] = 0.05
	dove.world_vars["corruption"] = 0.05
	a.is_true(WorldFactions.structure_pull(hawk, "death_eaters") > WorldFactions.structure_pull(dove, "death_eaters"),
		"战争与腐败推高黑暗势力")
	a.is_true(WorldFactions.structure_pull(hawk, "order_of_phoenix") > WorldFactions.structure_pull(dove, "order_of_phoenix"),
		"战争推高抵抗组织")
	a.is_true(WorldFactions.structure_pull(hawk, "ministry") < WorldFactions.structure_pull(dove, "ministry"),
		"腐败压低魔法部")

	# 敌对压制（brief 原用例）：强的一方压低弱的一方，但不会归零
	var press := make_world("modern")
	WorldFactions.initialize(press)
	WorldFactions.ensure_state(press, "ministry")["power"] = 0.95
	WorldFactions.ensure_state(press, "death_eaters")["power"] = 0.60
	var before_weak := WorldFactions.power_of(press, "death_eaters")
	WorldFactions.evolve(press)
	a.is_true(WorldFactions.power_of(press, "death_eaters") < before_weak, "敌对强者压制弱者")
	a.is_true(WorldFactions.power_of(press, "death_eaters") >= WorldFactions.SUPPRESS_FLOOR - 0.0001,
		"压制有下限，不会归零")

	# 非对称声明：只有字典序较大的一方声明敌对，也必须生效（I1 回归；真实内容里 black_market 单方声明 auror_office）
	var asym := make_world("modern")
	WorldFactions.ensure_state(asym, "auror_office")["power"] = 0.90
	WorldFactions.ensure_state(asym, "black_market")["power"] = 0.60
	var asym_before := WorldFactions.power_of(asym, "black_market")
	WorldFactions.apply_rival_pressure(asym)
	a.is_true(WorldFactions.power_of(asym, "black_market") < asym_before,
		"非对称敌对声明（black_market 单方声明 auror_office）也必须被处理")
	a.is_true(WorldFactions.power_of(asym, "auror_office") > 0.90,
		"非对称敌对的胜者也获得收益")

	# 可判别压制用例（M5 修复轮 1：删掉与 seed 挂钩的「< 起点」那一条，只留与 seed 无关的下限断言）：
	# war/corruption 拉高黑暗势力目标值（0.45），败者起点 0.06 高于 SUPPRESS_FLOOR。
	# 为何删「< 起点」：纯回归值 = 0.06 + (0.45-0.06)*0.04 + noise = 0.0756 + noise，
	# 要它在「无压制」时仍 ≥ 起点需 noise > -0.0156——只差 0.0043 的余量，换 seed / 改 EVOLVE_NOISE 就会退化成恒真。
	# 为何「按到下限」与 seed 无关：death_eaters 在真实内容表里同时是 4 对的败者（ministry/auror_office/
	# order_of_phoenix/hogwarts），四对合计压制 ≈ 0.09 ≫ noise 带宽 ±0.02 → 必被压到下限。
	var press2 := make_world("modern")
	WorldFactions.initialize(press2)
	press2.world_vars["war_pressure"] = 1.0
	press2.world_vars["corruption"] = 1.0
	WorldFactions.ensure_state(press2, "ministry")["power"] = 0.95
	WorldFactions.ensure_state(press2, "death_eaters")["power"] = 0.06
	WorldFactions.evolve(press2)
	a.near(WorldFactions.power_of(press2, "death_eaters"), WorldFactions.SUPPRESS_FLOOR, 0.0001,
		"压制把败者按到下限，不会归零（与 seed 无关）")

	# 直接调用压制函数（无回归/无噪音）：用**只有两个派系、互为 rivals** 的最小夹具隔离单对，幅度必须恰好
	# 等于 SUPPRESS_RATE × 实力差。（在 17 派系的真实内容表上会同时处理多对，net 跌幅不等于单对幅度。）
	var pair_reg := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代"}],
		"factions": [
			{"id": "alpha", "label": "甲", "kind": "ministry", "legal_status": "legal", "secrecy": "public",
				"base_power": 0.75, "institutions": [], "rivals": ["beta"], "allies": [],
				"domains": ["law"], "aliases": ["甲"], "era_overrides": {}},
			{"id": "beta", "label": "乙", "kind": "dark", "legal_status": "outlaw", "secrecy": "secret",
				"base_power": 0.05, "institutions": [], "rivals": ["alpha"], "allies": [],
				"domains": ["warfare"], "aliases": ["乙"], "era_overrides": {}},
		],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	var pair_w := WorldState.create("modern", PlayerState.new_default(), 1, pair_reg)
	WorldFactions.ensure_state(pair_w, "alpha")["power"] = 0.95
	WorldFactions.ensure_state(pair_w, "beta")["power"] = 0.60
	WorldFactions.apply_rival_pressure(pair_w)
	a.near(0.60 - WorldFactions.power_of(pair_w, "beta"), WorldFactions.SUPPRESS_RATE * 0.35, 0.0001,
		"单对压制幅度 = SUPPRESS_RATE × 实力差（0.03 × 0.35）")
	a.near(WorldFactions.power_of(pair_w, "alpha"), 0.95 + WorldFactions.SUPPRESS_RATE * 0.35 * 0.5, 0.0001,
		"胜者获得一半收益（+0.00525）")

	# ---- Task 2 审查 Minor 1：dark 派系未声明机构时按 0 计（不得借用全局归并持有值） ----
	var dark_w := make_world("modern")
	WorldFactions.initialize(dark_w)
	WorldFactions.ensure_state(dark_w, "death_eaters")["control"] = {}
	WorldFactions.ensure_state(dark_w, "ministry")["control"]["law_enforcement"] = 0.75
	WorldFactions.ensure_state(dark_w, "wizengamot")["control"]["wizengamot"] = 0.58
	a.is_false(WorldFactions.government_type(dark_w) == "death_eater_dictatorship",
		"黑暗势力未声明任何机构 → 不得判独裁（缺失键按 0 计）")
	a.eq(WorldFactions.government_type(dark_w), "ministry_bureaucracy", "该格局回落为官僚制")

	# ---- Task 2 审查 Minor 2：null clock / null registry 的硬化必须可断言 ----
	var naked := WorldState.new()
	WorldFactions.initialize(naked)
	a.is_true(naked.clock == null, "前置：裸世界的 clock 为 null")
	a.eq(naked.factions.size(), 0, "裸世界（无 registry/clock）不被写入派系状态")
	var half := WorldState.new()
	half.registry = Registry.load_default()
	half.era_id = "modern"
	WorldFactions.initialize(half)
	a.eq(half.factions.size(), 0, "registry 齐但 clock 为 null：仍不补齐（不读 clock.turn）")
	var half_state := WorldFactions.ensure_state(half, "ministry")
	a.near(float(half_state.get("power", -1.0)), 0.75, 0.0001, "clock 为 null 时 ensure_state 仍能建出状态")
	a.eq(int(half_state.get("last_change_turn", -1)), 0, "clock 为 null 时 last_change_turn 兜底为 0")
	# M3 修复轮 1：evolve() 也必须对 null registry / null clock 早退（旧实现紧接着读 world.clock.turn 会崩）
	a.eq(WorldFactions.evolve(naked).size(), 0, "裸世界调用 evolve 返回空数组（早退，不崩）")
	a.eq(WorldFactions.evolve(half).size(), 0, "registry 齐但 clock 为 null 时 evolve 也早退（不读 clock.turn）")

	# ---- Task 2 审查 Minor 3：institutions/rivals/allies 必须补数组类型守卫 ----
	var bad_inst_type_entry := base_entry.duplicate(true)
	bad_inst_type_entry["institutions"] = "law_enforcement"
	var bad_inst_type := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代"}],
		"factions": [bad_inst_type_entry],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	a.is_true(" | ".join(WorldFactions.validate_content(bad_inst_type)).contains("institutions 必须是数组"),
		"字符串型 institutions 被 validate_content 抓到（不崩）")

	var bad_rivals_type_entry := base_entry.duplicate(true)
	bad_rivals_type_entry["rivals"] = {"x": 1}
	var bad_rivals_type := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代"}],
		"factions": [bad_rivals_type_entry],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	a.is_true(" | ".join(WorldFactions.validate_content(bad_rivals_type)).contains("rivals 必须是数组"),
		"字典型 rivals 被 validate_content 抓到（不崩）")

	var bad_allies_type_entry := base_entry.duplicate(true)
	bad_allies_type_entry["allies"] = 42
	var bad_allies_type := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代"}],
		"factions": [bad_allies_type_entry],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	a.is_true(" | ".join(WorldFactions.validate_content(bad_allies_type)).contains("allies 必须是数组"),
		"数值型 allies 被 validate_content 抓到（不崩）")

	var missing_fields_entry := base_entry.duplicate(true)
	missing_fields_entry.erase("institutions")
	missing_fields_entry.erase("rivals")
	var missing_fields := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代"}],
		"factions": [missing_fields_entry],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	var missing_joined := " | ".join(WorldFactions.validate_content(missing_fields))
	a.is_true(missing_joined.contains("institutions 缺失"), "缺失 institutions 被 validate_content 抓到")
	a.is_true(missing_joined.contains("rivals 缺失"), "缺失 rivals 被 validate_content 抓到")

	# ---- Task 2 审查 Minor 4：era_overrides 引用不存在的时代（分支早已实现，此处补红例） ----
	var bogus_era_entry := base_entry.duplicate(true)
	bogus_era_entry["era_overrides"] = {"bogus_era": {"base_power": 0.5}}
	var bogus_era := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代"}],
		"factions": [bogus_era_entry],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	a.is_true(" | ".join(WorldFactions.validate_content(bogus_era)).contains("引用不存在的时代"),
		"era_overrides 引用不存在的时代被 validate_content 抓到")

	# ---- Task 3 审查 Minor 2：直接改换所属（不先 leave）的语义钉住（不改生产代码） ----
	var switcher := make_world("modern")
	WorldFactions.initialize(switcher)
	a.is_true(WorldFactions.visible_faction_ids(switcher).has("gringotts"), "前置：古灵阁是公开派系")
	StateOps.apply(switcher, [{"op": "join_faction", "faction_id": "ministry"}])
	StateOps.apply(switcher, [{"op": "faction_standing_delta", "faction_id": "ministry", "delta": 30}])
	a.eq(switcher.player.faction_id, "ministry", "前置：先属于魔法部")
	var switch_errs := StateOps.apply(switcher, [{"op": "join_faction", "faction_id": "gringotts"}])
	a.eq(switch_errs.size(), 0, "直接改换无错误（不需要先 leave）")
	a.eq(switcher.player.faction_id, "gringotts", "直接改换覆盖所属")
	a.eq(switcher.player.standing_of("ministry"), 30, "改换不移除原派系立场")

	# ---- Task 3 审查 Minor 3：delta / 2 向零截断（既定语义，留给后续统一） ----
	var trunc := make_world("modern")
	WorldFactions.initialize(trunc)
	StateOps.apply(trunc, [{"op": "join_faction", "faction_id": "ministry"}])
	var trunc_errs := StateOps.apply(trunc, [{"op": "faction_standing_delta", "faction_id": "ministry", "delta": -5}])
	a.eq(trunc_errs.size(), 0, "负向立场调整无错误")
	a.eq(trunc.player.standing_of("ministry"), -5, "玩家立场为 -5（原值）")
	a.eq(int(WorldFactions.state_of(trunc, "ministry").get("stance_to_player", 0)), -2,
		"派系态度为 -2：delta/2 向零截断（既定语义）")

	return a.report("factions")
