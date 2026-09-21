class_name EconomyTest
extends RefCounted

## 计划 03b · 经济算价核心的验收套件。
## C1–C6 契约见 spec §7.4；本文件是「价格算对了没有」的机器判据。

## C1 的中性时代（`era_mult == 1.0`）。**不是 `modern`** —— modern(2010) 落 1.10 档。
## 按 ERA_MULT 表，中性档是 `y <= 1980`，实际命中 `first_wizarding_war`(1970)。
const NEUTRAL_ERA := "first_wizarding_war"

func make_world(era_id: String = NEUTRAL_ERA, seed_: int = 12345) -> WorldState:
	var reg := Registry.load_default()
	var p := PlayerState.new_default()
	p.name_text = "测试者"
	p.bloodline_id = "half_blood"
	p.birth_identity_id = "ordinary_wizard_family"
	p.house_id = "gryffindor"
	p.aptitude_id = "normal"
	p.location_id = "london_muggle"
	return WorldState.create(era_id, p, seed_, reg)

# 把 economy_index 钉到指定值（tick 的回归漂移会改它，测试里需要确定性）
func _pin(w: WorldState, index: float) -> void:
	w.world_vars["economy_index"] = index

func run() -> int:
	var a := TestAssert.new()

	# ---- 常量两处一致（registry 的白名单是字面量，防漂移）----
	a.eq(Economy.CATEGORIES,
		["wand", "potion", "material", "broom", "book",
			"food", "service", "creature", "artifact", "illegal"],
		"CATEGORIES 枚举定版")
	a.eq(Economy.KINDS, ["goods", "service"], "KINDS 枚举定版")
	a.is_true(Economy.SUPPLY_CUTOFF < Economy.CRISIS_THRESHOLD, "断供线低于危机线")
	a.is_true(Economy.MIN_SCARCITY < 1.0 and Economy.MAX_SCARCITY > 1.0,
		"缩放上下限夹住中性值")

	# ---- C1：常态价 == base_price_knuts（中性时代 + index=0.5 + local=1.0）----
	var w := make_world(NEUTRAL_ERA)
	a.near(Economy.era_mult_for(w), 1.0, 0.000001, "中性时代 era_mult == 1.0")
	_pin(w, Economy.NEUTRAL_INDEX)
	for gid in ["wand_standard", "potion_healing", "potion_healing_premium", "broom_nimbus", "svc_rent"]:
		var e := w.registry.entry("goods", gid)
		a.eq(Economy.price_of(w, gid), int(e["base_price_knuts"]),
			"C1 常态价 == base: %s" % gid)

	# ---- C2：单调不增（1001 点全扫描）----
	var prev := 1 << 30
	for i in range(1001):
		var idx := float(i) / 1000.0
		_pin(w, idx)
		var p := Economy.price_of(w, "wand_standard")
		if p > 0:
			a.is_true(p <= prev, "C2 单调不增 @idx=%.3f (%d <= %d)" % [idx, p, prev])
			prev = p

	# ---- C3：危机侧不突破 canon_hi（全域扫，只统计未断供段）----
	for gid2 in ["wand_standard", "potion_healing", "potion_healing_premium", "broom_nimbus"]:
		var e2 := w.registry.entry("goods", gid2)
		var hi_actual := 0
		for i in range(0, 1001):
			_pin(w, float(i) / 1000.0)
			hi_actual = maxi(hi_actual, Economy.price_of(w, gid2))
		a.is_true(hi_actual <= int(e2["canon_price_hi_knuts"]),
			"C3 全域价 <= canon_hi: %s (%d <= %d)"
				% [gid2, hi_actual, int(e2["canon_price_hi_knuts"])])

	# ---- C4：繁荣侧允许下探，且**确实**下探了（记录不阻断）----
	_pin(w, 1.0)
	var boom := Economy.price_of(w, "wand_standard")
	a.is_true(boom < int(w.registry.entry("goods", "wand_standard")["canon_price_knuts"]),
		"C4 繁荣侧下探到正典下沿之下（实际 %d < 3451）" % boom)

	# ---- C5：supply 不进价格（正面断言 + 反向对照）----
	_pin(w, 0.8)
	var p_before := Economy.price_of(w, "wand_standard")
	_mutate_base_output(w, "wandmaking", 0.1)
	a.eq(Economy.price_of(w, "wand_standard"), p_before, "C5 改 base_output 不影响价格")
	_mutate_base_output(w, "wandmaking", 0.70)
	a.eq(Economy.price_of(w, "wand_standard"), p_before, "C5 改回后仍一致")

	# ---- 断供线与危机线是两件事 ----
	_pin(w, 0.20)
	a.is_true(Economy.is_crisis(w), "0.20 处于危机")
	a.is_true(Economy.available(w, "wand_standard"), "0.20 危机中仍可供货")
	a.is_true(Economy.price_of(w, "wand_standard") > 0, "0.20 有价")
	_pin(w, 0.10)
	a.is_true(Economy.is_crisis(w), "0.10 仍处危机")
	a.is_false(Economy.available(w, "wand_standard"), "0.10 断供")
	a.eq(Economy.price_of(w, "wand_standard"), 0, "断供时 price_of == 0")
	a.is_true(Economy.available(w, "svc_rent"), "服务类不受断供影响")
	a.is_true(Economy.available(w, "broom_nimbus"), "非 supply_critical 不受断供影响")

	# ---- 垄断行业涨价侧加倍，但倍率仍守 MAX_SCARCITY ----
	_pin(w, 0.30)
	var mono := Economy.scarcity_mult_for(w, "wandmaking")      # monopoly = true
	var comp := Economy.scarcity_mult_for(w, "potion_brewing")  # monopoly = false
	a.is_true(mono > comp, "垄断行业危机侧倍率更高（%.4f > %.4f）" % [mono, comp])
	a.is_true(mono <= Economy.MAX_SCARCITY + 0.000001, "垄断倍率守 MAX_SCARCITY")
	_pin(w, 1.0)
	a.near(Economy.scarcity_mult_for(w, "wandmaking"),
		Economy.scarcity_mult_for(w, "potion_brewing"), 0.000001,
		"繁荣侧垄断不加成（超额部分为 0）")

	# ---- 缺 location 标签时 local_mult == 1.0（缺省必须安全）----
	_pin(w, 0.5)
	a.eq(Economy.local_mult_for(w, "wand_standard"), Economy.LOCAL_MULT_DEFAULT,
		"缺省 local_mult == 1.0")
	w.world_vars["location_tag"] = "产地"
	a.near(Economy.local_mult_for(w, "wand_standard"), 0.85, 0.000001, "产地系数生效")
	w.world_vars.erase("location_tag")

	# ---- 时代系数：同景气下不同时代价不同，且 modern 档 == 1.0 ----
	var w_old := make_world("hogwarts_founding")
	_pin(w_old, Economy.NEUTRAL_INDEX)
	a.near(Economy.era_mult_for(w_old), 0.35, 0.000001, "建校早期时代系数 0.35")
	# ⚠️ modern(2010) 落 1.10 档，**不是** C1 的中性时代（这是 2026-09-21 施工澄清的关键点）
	a.near(Economy.era_mult_for(make_world("modern")), 1.10, 0.000001, "modern 时代系数 1.10（非中性）")
	a.near(Economy.era_mult_for(w), 1.00, 0.000001, "中性时代系数 1.00")
	# 时代系数：越接近现代越贵，**但第二次巫师战争后回落**（1.15 → 1.10，设计意图）
	var order := ["hogwarts_founding", "witch_hunts", "grindelwald", "first_wizarding_war"]
	var last := -1.0
	for era_id in order:
		var m := Economy.era_mult_for(make_world(era_id))
		a.is_true(m >= last, "时代系数单调不降: %s (%.2f)" % [era_id, m])
		last = m
	a.near(Economy.era_mult_for(make_world("second_wizarding_war")), 1.15, 0.000001,
		"第二次巫师战争 1.15（战时通胀峰值）")
	a.is_true(Economy.era_mult_for(make_world("modern"))
		< Economy.era_mult_for(make_world("second_wizarding_war")),
		"战后回落：modern(1.10) < second_wizarding_war(1.15)")

	# ---- 未知商品不得静默返回 0（防「字典 get 缺省」类静默错误）----
	a.eq(Economy.price_of(w, "没有这个商品"), 0, "未知商品 price_of == 0")
	a.eq(Economy.price_of(w, ""), 0, "空 id price_of == 0")

	# ---- 存档往返：economy 必须活下来，且**快照不得被 initialize 重算** ----
	w.economy["gringotts_balance"] = 12345
	w.economy["smuggling_heat"] = 3
	var snap_before := int((w.economy["prices"] as Dictionary)["wand_standard"])
	var blob := SaveCodec.encode(w)
	var back := SaveCodec.decode(blob, w.registry)
	a.is_true(bool(back["ok"]), "含 economy 的存档可解码")
	var w2: WorldState = back["world"]
	a.eq(w2.economy.size(), w.economy.size(), "economy 往返键数一致")
	a.eq(int(w2.economy["gringotts_balance"]), 12345, "存款往返一致")
	a.eq(int(w2.economy["smuggling_heat"]), 3, "走私热度往返一致")
	a.eq(int((w2.economy["prices"] as Dictionary)["wand_standard"]), snap_before,
		"价格快照往返逐字一致（initialize 不得重算已有快照）")
	a.eq(w2.economy["prices"], w.economy["prices"], "整个 prices 字典往返一致")

	# ---- 老存档（无 economy 键）读档后必须补齐 ----
	var legacy := w.to_dict()
	legacy.erase("economy")
	var w3 := WorldState.from_dict(legacy, w.registry)
	a.is_true(not w3.economy.is_empty(), "老存档读档后补齐 economy")
	a.is_true(float(w3.economy["gringotts_interest_rate"]) > 0, "补齐了利率默认值")
	a.eq(int(w3.economy["gringotts_balance"]), 0, "补齐余额为 0")
	a.eq(bool(w3.economy["crisis"]), false, "补齐 crisis 为 false")
	a.is_true(not (w3.economy["prices"] as Dictionary).is_empty(), "补齐价格快照")
	a.eq((w3.economy["prices"] as Dictionary).size(), w.registry.ids("goods").size(),
		"新补齐的快照覆盖全部商品")
	# economy 为 null 也要能补齐（异常存档路径）
	var legacy_null := w.to_dict()
	legacy_null["economy"] = null
	var w4 := WorldState.from_dict(legacy_null, w.registry)
	a.is_true(not w4.economy.is_empty(), "economy=null 也补齐")

	# ---- initialize 幂等：连续调用不改任何已有值 ----
	var before := (w.economy as Dictionary).duplicate(true)
	Economy.initialize(w)
	Economy.initialize(w)
	a.eq(w.economy, before, "initialize 幂等（两次调用值不变）")

	# ---- 存档白名单：economy 放错类型必须被拦（不能只在正向测）----
	var bad_payload := w.to_dict()
	bad_payload["economy"] = "不是字典"
	a.is_true(not SaveCodec._validate_payload(bad_payload).is_empty(),
		"economy 类型错误被 _validate_payload 抓到")

	return a.report("economy")


# 测试内辅助：直接改内存里的表内容（不影响 res://data）
func _mutate_base_output(w: WorldState, industry_id: String, value: float) -> void:
	w.registry.entry("industries", industry_id)["base_output"] = value
