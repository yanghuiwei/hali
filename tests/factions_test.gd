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
	# 为何「按到下限」与 seed 无关：death_eaters 在真实内容表里同时是 6 对的败者（ministry/auror_office/
	# wizengamot/mysteries/hogwarts/order_of_phoenix——I1 修复后非对称声明也生效，故是 6 对不是 4 对）。
	# 口径订正（修复轮 1 M4）：这 6 对的**未截断潜在**压制合计 ≈ 0.09；但本夹具里压制前 power =
	# 0.06 + (0.45−0.06)×0.04 + noise = 0.0756±0.02，下限 = max(0.05, 0.05×0.25) = 0.05，
	# 所以**实际生效的下降量** ∈ [0.0056, 0.0456]（典型 ≈0.026），远小于潜在值——关键是它远大于 noise 带宽下的所需余量，
	# 且下限 0.05 使终值必然落在下限。
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
	a.is_true(WorldFactions.compute_tension(angry) >= WorldFactions.TENSION_THRESHOLD,
		"极端格局的 tension 达到事件阈值（否则后续断言可能空转）")

	WorldFactions.initialize(angry)
	a.is_true(WorldFactions.event_condition_met(angry, "economic_slump"), "经济萧条条件成立")
	a.is_false(WorldFactions.event_condition_met(calm, "economic_slump"), "经济好时不成立")
	a.is_true(WorldFactions.event_condition_met(angry, "oligarchy_pressure"), "寡头压力条件成立（pureblood_influence 分支）")
	a.is_false(WorldFactions.event_condition_met(calm, "oligarchy_pressure"), "无寡头压力时不成立")
	# 单独钉住 power_share 那条分支：必须把 pureblood_influence 压在 0.65 以下，否则 OR 的另一条会救场、
	# 该分支即使被写成死阀值（如计划原稿的 0.40）也测不出来（破坏实验 E2 实证）。
	var olig := make_world("modern")
	WorldFactions.initialize(olig)
	olig.world_vars["pureblood_influence"] = 0.30
	WorldFactions.ensure_state(olig, "sacred_twenty_eight")["power"] = 0.9
	WorldFactions.ensure_state(olig, "reformist_pureblood")["power"] = 0.9
	a.is_true(float(WorldFactions.power_share(olig).get("pureblood", 0.0)) >= 0.26,
		"前置：纯血四角占比确实 ≥ 0.26（否则断言空转）")
	a.is_false(float(olig.world_vars.get("pureblood_influence", 0.0)) >= 0.65,
		"前置：pureblood_influence 低于 0.65（确保不是 OR 的另一条救场）")
	a.is_true(WorldFactions.event_condition_met(olig, "oligarchy_pressure"),
		"纯血占比达标即触发寡头压力（power_share 分支单独可判）")
	a.is_true(WorldFactions.event_condition_met(angry, "lawlessness"), "无法纪条件成立")
	a.is_false(WorldFactions.event_condition_met(calm, "lawlessness"), "低腐败时不成立")
	a.is_true(WorldFactions.event_condition_met(angry, "war_exhaustion"), "战争疲态条件成立")
	a.is_false(WorldFactions.event_condition_met(calm, "war_exhaustion"), "和平时不成立")
	a.is_true(WorldFactions.event_condition_met(angry, "secrecy_crisis"), "保密法危机条件成立")
	a.is_false(WorldFactions.event_condition_met(calm, "secrecy_crisis"), "保密法稳固时不成立")
	a.is_false(WorldFactions.event_condition_met(angry, "不存在的条件"), "未知条件恒不成立")

	var pev := WorldFactions.pick_political_event(angry)
	a.is_true(not pev.is_empty(), "紧张局势下能选出政治事件")
	a.is_true(angry.registry.has("political_events", str(pev.get("event_id", ""))), "事件 id 来自内容表")
	a.is_true(not str(pev.get("text", "")).is_empty(), "事件有文案")
	a.eq(str(pev.get("kind", "")), "faction", "事件 kind=faction")
	a.eq(int(pev.get("turn", -1)), angry.clock.turn, "事件带当前回合")
	a.eq(int(angry.flags.get("last_major_turn", -1)), angry.clock.turn, "事件占用本月重大事件配额")
	a.is_true(angry.history.size() >= 1, "事件进 history（add_fact）")
	a.is_true(WorldFactions.pick_political_event(angry).is_empty(), "同一回合不再重复触发（MAJOR_EVENT_GAP）")

	# 低 tension 时一个都不该选出来
	WorldFactions.initialize(calm)
	a.is_true(WorldFactions.pick_political_event(calm).is_empty(), "低 tension 时不触发政治事件")

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
	# 容差 2e-4：flags 里存的是量化后的 tension（同上，为存档往返稳定）
	a.near(WorldFactions.tension_of(tw), WorldFactions.compute_tension(tw), 0.0002,
		"tension_of 与 compute_tension 一致（tick 写的是同一口径，量化后余差 ≤1e-4）")

	# ---- 修复轮 1（M3）：证明 tension_of 走的是 flags 路径，而不是每次现算 ----
	# 上面那条 near 在 flags 缺失时会走 compute_tension 兜底（差 0 也绿），单独证明不了「读到的是存的值」。
	var tf := make_world("modern")
	tf.flags[WorldFactions.TENSION_FLAG] = 0.42
	var tension_before := WorldFactions.compute_tension(tf)
	tf.world_vars["corruption"] = 0.99
	tf.world_vars["war_pressure"] = 0.99
	tf.world_vars["muggle_relations"] = 0.01
	a.is_true(WorldFactions.compute_tension(tf) > tension_before + 0.05,
		"前置：改 world_vars 后 compute_tension 确实变了（否则下面的断言会空转）")
	a.near(WorldFactions.tension_of(tf), 0.42, 0.0000001, "tension_of 读 flags：不随 world_vars 变")
	tf.flags.erase(WorldFactions.TENSION_FLAG)
	a.near(WorldFactions.tension_of(tf), WorldFactions.compute_tension(tf), 0.0000001,
		"只有缺 flags 时才回退到现算")
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

	# ---- Task 5 收口 4a：注释事实订正（I1 修复后 death_eaters 同时是 6 对的败者） ----
	# 该注释在「可判别压制用例」上方，只改文字不改断言。

	# ---- Task 5 收口 4b-1：structure_pull 各分支方向正确（此前只有 ministry/dark/resistance 有断言） ----
	var low := make_world("modern")
	var high := make_world("modern")
	low.world_vars["ministry_stability"] = 0.1
	high.world_vars["ministry_stability"] = 0.9
	a.is_true(WorldFactions.structure_pull(high, "auror_office") > WorldFactions.structure_pull(low, "auror_office"),
		"institution 分支：部里越稳，机构越强")
	low.world_vars["pureblood_influence"] = 0.1
	high.world_vars["pureblood_influence"] = 0.9
	a.is_true(WorldFactions.structure_pull(high, "sacred_twenty_eight")
		> WorldFactions.structure_pull(low, "sacred_twenty_eight"), "pureblood 分支：纯血影响力越高越强")
	low.world_vars["economy_index"] = 0.1
	high.world_vars["economy_index"] = 0.9
	a.is_true(WorldFactions.structure_pull(high, "gringotts") > WorldFactions.structure_pull(low, "gringotts"),
		"commerce 分支：经济越好商业越强")
	a.is_true(WorldFactions.structure_pull(high, "daily_prophet") > WorldFactions.structure_pull(low, "daily_prophet"),
		"media 分支：经济越好舆论越强")
	low.world_vars["muggle_relations"] = 0.1
	high.world_vars["muggle_relations"] = 0.9
	a.is_true(WorldFactions.structure_pull(high, "muggle_world") > WorldFactions.structure_pull(low, "muggle_world"),
		"foreign 分支：麻瓜关系越好，外部势力越强")
	low.world_vars["secrecy_integrity"] = 0.1
	high.world_vars["secrecy_integrity"] = 0.9
	a.is_true(WorldFactions.structure_pull(high, "hogwarts") > WorldFactions.structure_pull(low, "hogwarts"),
		"school 分支：保密法越稳，学校越强")
	a.near(WorldFactions.structure_pull(high, "common_folk"), 0.0, 0.0000001,
		"society（未列入 match 的 kind）拉力恒为 0，不泄漏其他分支")

	# ---- Task 5 收口 4b-2：机构控制权以 0.5 系数向实力靠拢（此前无任何断言） ----
	# 用「只有一个派系、无 rivals」的最小夹具，排除敌对压制对 power 的二次修改，
	# 于是 evolve 后的 power 就是控制权滞后所用的 next，可精确核对关系式。
	var solo_reg := Registry.from_tables({
		"eras": [{"id": "modern", "label": "现代", "world_vars": {"economy_index": 0.5}}],
		"factions": [
			{"id": "solo", "label": "独派", "kind": "commerce", "legal_status": "legal", "secrecy": "public",
				"base_power": 0.4, "institutions": ["gringotts"], "rivals": [], "allies": [],
				"domains": ["economy"], "aliases": ["独派"], "era_overrides": {}},
		],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
		"political_events": [],
	})
	var solo := WorldState.create("modern", PlayerState.new_default(), 9, solo_reg)
	var solo_state := WorldFactions.ensure_state(solo, "solo")
	solo_state["power"] = 0.9
	solo_state["control"]["gringotts"] = 0.5
	WorldFactions.evolve(solo)
	var solo_power := float(WorldFactions.state_of(solo, "solo")["power"])
	var solo_control := float((WorldFactions.state_of(solo, "solo")["control"] as Dictionary)["gringotts"])
	a.is_true(solo_power < 0.9, "前置：实力向目标（0.4）回归而下降（否则滞后断言可能空转）")
	# 容差 2e-4：evolve 末尾会把 power/control 量化到 1e-4（存档往返不变量，见 WorldFactions.QUANTIZE_DECIMALS），
	# 因此关系式只在量化精度内成立；若把系数 0.5 改成 0.25，偏差约 0.1 ≫ 2e-4，断言仍会红。
	a.near(solo_control, 0.5 + (solo_power - 0.5) * 0.5, 0.0002,
		"机构控制权以 0.5 系数向新实力靠拢：control += (power − control) × 0.5")

	# ---- 修复轮 1（M2）：last_change_turn 必须与「量化后的持久值是否真的变了」双向一致 ----
	# 旧实现用未量化的 next 就地判定 → 「持久值没变、却标记为本月变化」；
	# 且敌对压制（apply_rival_pressure）改值时不标记 → 「变了却没标记」。
	# 现在 evolve 在本回合所有写入结束后统一判定，两个方向都应恰好一致。
	var stale := make_world("modern")
	WorldFactions.initialize(stale)
	var mark_mismatch := 0
	var mark_samples := 0
	for i in 30:
		var before_q := {}
		for fid in stale.registry.ids("factions"):
			before_q[str(fid)] = WorldFactions.quantize(WorldFactions.power_of(stale, str(fid)))
		stale.tick()
		for fid in stale.registry.ids("factions"):
			var sid := str(fid)
			var after_q := WorldFactions.quantize(WorldFactions.power_of(stale, sid))
			var persisted_changed := not is_equal_approx(after_q, float(before_q[sid]))
			var marked := int(WorldFactions.state_of(stale, sid).get("last_change_turn", -1)) == stale.clock.turn
			mark_samples += 1
			if persisted_changed != marked:
				mark_mismatch += 1
	a.eq(mark_mismatch, 0, "last_change_turn 与「量化持久值是否真的变了」双向一致（%d 个样本）" % mark_samples)
	a.is_true(mark_samples == 510, "样本数应为 30 回合 × 17 派系 = 510（实际=%d，防循环写错导致空转）" % mark_samples)

	# ---- 信息保护与揭示（Task 6） ----
	var rw := make_world("modern")
	WorldFactions.initialize(rw)
	a.is_false(WorldFactions.reveal(rw, "death_eaters", ""), "空来源不能揭示")
	a.is_false(WorldFactions.reveal(rw, "death_eaters", "system"), "system 来源不能揭示（第四十三/五十七章）")
	a.is_false(bool(WorldFactions.state_of(rw, "death_eaters")["revealed"]), "被拒的揭示不写状态")
	a.is_false(WorldFactions.reveal(rw, "不存在的派系", "破釜酒吧传闻"), "未知派系不能揭示")
	a.is_true(WorldFactions.reveal(rw, "death_eaters", "破釜酒吧传闻"), "合法来源可以揭示")
	a.is_true(bool(WorldFactions.state_of(rw, "death_eaters")["revealed"]), "揭示后 revealed=true")
	a.is_true(WorldFactions.visible_faction_ids(rw).has("death_eaters"), "揭示后进入可见列表")
	a.is_true(rw.history.size() >= 1, "揭示写入 history（可追溯）")
	a.is_false(WorldFactions.reveal(rw, "death_eaters", "破釜酒吧传闻"), "重复揭示返回 false（幂等）")
	a.is_false(WorldFactions.visible_faction_ids(rw).has("order_of_phoenix"), "未揭示派系不在可见列表")

	# 来源必须原样记录在 fact 文案里（可追溯性）
	var reveal_fact_text := ""
	for fact in rw.history:
		if str((fact as Dictionary).get("kind", "")) == "faction_revealed":
			reveal_fact_text = str((fact as Dictionary).get("text", ""))
	a.is_true(reveal_fact_text.contains("破釜酒吧传闻"), "揭示记录里带来源")
	a.is_true(reveal_fact_text.contains("食死徒"), "揭示记录里带派系 label")

	# 传闻揭示：只有带 reveals_faction 的传闻才揭示
	var secret_before := WorldFactions.visible_faction_ids(rw).size()
	WorldFactions.apply_rumor_reveals(rw, [{"rumor_id": "不存在的传闻", "category": "政治", "text": "x"}])
	WorldFactions.apply_rumor_reveals(rw, ["不是字典"])
	WorldFactions.apply_rumor_reveals(rw, [{"category": "政治", "text": "没有 rumor_id"}])
	a.eq(WorldFactions.visible_faction_ids(rw).size(), secret_before, "无效事件不揭示任何派系")
	a.is_false(WorldFactions.visible_faction_ids(rw).has("order_of_phoenix"), "无 reveals_faction 的传闻不揭示")

	var rumor_with_reveal := ""
	for rid in rw.registry.ids("rumors"):
		var reveal_target := str(rw.registry.entry("rumors", str(rid)).get("reveals_faction", ""))
		if reveal_target.is_empty():
			continue
		if WorldFactions.visible_faction_ids(rw).has(reveal_target):
			continue
		if rumor_with_reveal.is_empty():
			rumor_with_reveal = str(rid)
	a.is_true(not rumor_with_reveal.is_empty(), "内容表里至少有一条带 reveals_faction 的未揭示传闻")
	if not rumor_with_reveal.is_empty():
		var target := str(rw.registry.entry("rumors", rumor_with_reveal).get("reveals_faction", ""))
		WorldFactions.apply_rumor_reveals(rw, [{"rumor_id": rumor_with_reveal, "category": "政治", "text": "传闻"}])
		a.is_true(WorldFactions.visible_faction_ids(rw).has(target), "被抽中的传闻揭示对应派系（%s）" % target)

	# ---- 端到端（确定性，不依赖随机抽中）：真实传闻被 tick() 处理 → 该派系进入可见列表 ----
	# 做法：用 Registry.from_tables 造一份「rumors 表只留一条带 reveals_faction 的传闻」的注册表，
	# 于是该传闻是唯一候选（PlayerState 的 location_id 落在它的 zones 里）→ 每次 tick 必被抽中。
	var tables := {}
	for table_name in Registry.TABLE_FILES.keys():
		var entries: Array = []
		for eid in reg.ids(table_name):
			entries.append(reg.entry(table_name, str(eid)))
		tables[table_name] = entries
	var only_rumor: Dictionary = {}
	for e in (tables["rumors"] as Array):
		if str((e as Dictionary).get("id", "")) == "rumor_marked_ones":
			only_rumor = e
	a.is_true(not only_rumor.is_empty(), "内容表里存在 rumor_marked_ones（E2E 前置）")
	a.eq(str(only_rumor.get("reveals_faction", "")), "death_eaters", "rumor_marked_ones 揭示食死徒")
	tables["rumors"] = [only_rumor]
	var e2e_reg := Registry.from_tables(tables)
	var e2e_p := PlayerState.new_default()
	e2e_p.name_text = "测试者"
	e2e_p.location_id = "knockturn_alley"
	var e2e := WorldState.create("modern", e2e_p, 777, e2e_reg)
	a.is_false(WorldFactions.visible_faction_ids(e2e).has("death_eaters"), "E2E 前置：食死徒初始不可见")
	var e2e_events := e2e.tick()
	var saw_rumor := false
	for ev in e2e_events:
		if str(ev.get("rumor_id", "")) == "rumor_marked_ones":
			saw_rumor = true
	a.is_true(saw_rumor, "tick 处理了带 reveals_faction 的传闻（最小 rumors 表 ⇒ 确定）")
	a.is_true(WorldFactions.visible_faction_ids(e2e).has("death_eaters"), "E2E：tick 后该派系进入可见列表")
	var reveal_facts := 0
	for fact in e2e.history:
		if str((fact as Dictionary).get("kind", "")) == "faction_revealed":
			reveal_facts += 1
	a.eq(reveal_facts, 1, "E2E：第一次 tick 写一条揭示记录")
	e2e.tick()
	var reveal_facts_after := 0
	for fact in e2e.history:
		if str((fact as Dictionary).get("kind", "")) == "faction_revealed":
			reveal_facts_after += 1
	a.eq(reveal_facts_after, 1, "E2E：第二次 tick 走幂等路径，不重复写揭示记录")
	a.is_true(WorldFactions.visible_faction_ids(e2e).has("death_eaters"), "E2E：已揭示后仍可见")

	return a.report("factions")
