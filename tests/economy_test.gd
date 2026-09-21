class_name EconomyTest
extends RefCounted

## 计划 03b · 经济算价核心的验收套件。
## C1–C6 契约见 spec §7.4；本文件是「价格算对了没有」的机器判据。

## C1 的中性时代（`era_mult == 1.0`）。**不是 `modern`** —— modern(2010) 落 1.10 档。
## 按 ERA_MULT 表，中性档是 `y <= 1980`，实际命中 `first_wizarding_war`(1970)。
const NEUTRAL_ERA := "first_wizarding_war"

## C1 的中性地点（`local_mult == 1.0`）。`diagon_alley.zone == "wizarding"` → 档位「常规」。
## ⚠️ 2026-09-21 缺陷⑧：`local_mult` 改按 `zone` 推导后，**不能再用 `london_muggle`** ——
## 它是 `zone == "muggle"` ⇒ 档位「偏远」⇒ `local_mult == 1.2`，会让 C1 的
## 「常态价 == base_price_knuts」整体偏 1.2 倍而全面变红。
## 这与 C1 的「中性时代」是同一种错误：**定义点必须落在所有因子都等于 1 的那一点上**。
const NEUTRAL_LOCATION := "diagon_alley"

func make_world(era_id: String = NEUTRAL_ERA, seed_: int = 12345) -> WorldState:
	var reg := Registry.load_default()
	var p := PlayerState.new_default()
	p.name_text = "测试者"
	p.bloodline_id = "half_blood"
	p.birth_identity_id = "ordinary_wizard_family"
	p.house_id = "gryffindor"
	p.aptitude_id = "normal"
	p.location_id = NEUTRAL_LOCATION
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

	# ---- local_mult 按 location.zone 推导（缺陷⑧ 修正）+ 缺省安全 ----
	_pin(w, 0.5)
	a.eq(Economy.local_mult_for(w, "wand_standard"), Economy.LOCAL_MULT_DEFAULT,
		"常规地点（wizarding）local_mult == 1.0")
	# 换地点 ⇒ 价格真的跟着变（原实现在这里必然不变，因为 world_vars 与地点无关）
	var p_here := Economy.price_of(w, "wand_standard")
	a.eq(p_here, 3451, "常规地点常态价 == base（前置：C1 在此成立）")
	w.player.location_id = "forbidden_forest"        # zone == "forbidden" → 档位「产地」
	a.near(Economy.local_mult_for(w, "wand_standard"), 0.85, 0.000001,
		"禁林（forbidden）走「产地」档 0.85")
	a.is_true(Economy.price_of(w, "wand_standard") < p_here,
		"换到产区后价格真的下降（不是死路径）")
	w.player.location_id = "london_muggle"           # zone == "muggle" → 档位「偏远」
	a.near(Economy.local_mult_for(w, "wand_standard"), 1.2, 0.000001,
		"麻瓜世界（muggle）走「偏远」档 1.2")
	a.is_true(Economy.price_of(w, "wand_standard") > p_here,
		"换到偏远后价格真的上升")
	# 缺省安全：地点 id 为空 / 未知 / zone 缺字段 ⇒ 一律平价（不得变成 0 倍价）
	w.player.location_id = ""
	a.eq(Economy.local_mult_for(w, "wand_standard"), Economy.LOCAL_MULT_DEFAULT,
		"空 location_id 走缺省 1.0")
	w.player.location_id = "不存在的地点"
	a.eq(Economy.local_mult_for(w, "wand_standard"), Economy.LOCAL_MULT_DEFAULT,
		"未知地点走缺省 1.0")
	var zone_backup = w.registry.entry("locations", NEUTRAL_LOCATION).get("zone", null)
	w.registry.entry("locations", NEUTRAL_LOCATION).erase("zone")
	w.player.location_id = NEUTRAL_LOCATION
	a.eq(Economy.local_mult_for(w, "wand_standard"), Economy.LOCAL_MULT_DEFAULT,
		"地点缺 zone 字段走缺省 1.0（缺字段不得变成 0 倍价）")
	w.registry.entry("locations", NEUTRAL_LOCATION)["zone"] = zone_backup
	w.player.location_id = NEUTRAL_LOCATION
	a.eq(Economy.local_mult_for(w, "wand_standard"), Economy.LOCAL_MULT_DEFAULT,
		"恢复 zone 后回到 1.0（夹具自检）")
	# 指定地点的价（trade_money 跨地算价用）：与改 player.location_id 结果一致
	a.eq(Economy.price_at(w, "wand_standard", "forbidden_forest"),
		roundi(3451 * 0.85), "price_at 产区价与换地点一致")
	a.eq(Economy.price_at(w, "wand_standard", NEUTRAL_LOCATION), 3451,
		"price_at 常规价 == base")
	a.eq(Economy.price_at(w, "wand_standard", "不存在的地点"), 3451,
		"price_at 未知地点走缺省 1.0")

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

	_check_jobs_table(a)
	_check_settlement(a)

	return a.report("economy")


# ============================================================================
# Task 5：jobs 表（缺陷⑩）+ 月度结算（E4② / spec §7.6）
# ============================================================================

func _check_jobs_table(a: TestAssert) -> void:
	var w := make_world()
	var reg := w.registry

	# ⑱ 职业表存在且注册（缺陷⑩ 本体：原 plan 假设「若已存在则复用」，实测**不存在**）
	a.is_true(reg.has("jobs", "shopkeeper"), "jobs 表已注册且含 shopkeeper")
	a.eq(reg.ids("jobs").size(), 9, "职业表正好 9 条（正典 198 行逐条对应，不多不少）")

	# ⑲ 正典依据：9 条职业与正典 198 行完全一致
	var expected := ["商人", "魔药师", "记者", "治疗师", "店员", "酒吧老板",
		"扫帚修理工", "猫头鹰驯养师", "魁地奇球员"]
	var actual := PackedStringArray()
	for jid in reg.ids("jobs"):
		actual.append(str(reg.entry("jobs", jid).get("label", "")))
	actual.sort()
	var exp_sorted := PackedStringArray(expected)
	exp_sorted.sort()
	a.eq(actual, exp_sorted, "9 条 label 与正典 198 行职业清单逐字一致")

	# ⑳ 量级锚点（硬约束，spec §7.6 + 缺陷⑪修正口径）：
	#    下沿 2958（6 加隆）是硬约束 —— 9 条全部满足；
	#    上沿放宽到 9860，且**只有 quidditch_pro 可达 9860**（其余 8 条严格小于）。
	#    ⚠️ 原 spec 写「其余 8 条全部在 [2958, 7395]」是错的：healer=8874(18加隆)、
	#    pub_owner=7888(16加隆) 都越出 7395。缺陷⑪：改断言口径，不改数值。
	for jid in reg.ids("jobs"):
		var e: Dictionary = reg.entry("jobs", jid)
		var wage := int(e.get("wage_knuts", 0))
		a.is_true(int(e.get("canon_line", 0)) == 198,
			"job/%s canon_line == 198" % jid)
		a.is_true(wage >= 2958, "job/%s 工资 %d >= 6 加隆下沿" % [jid, wage])
		a.is_true(wage <= 9860, "job/%s 工资 %d <= 20 加隆上沿" % [jid, wage])
		if str(jid) == "quidditch_pro":
			a.eq(wage, 9860, "魁地奇球员破格到 20 加隆（正典 233 行「也是商业」）")
		else:
			a.is_true(wage < 9860, "job/%s 不允许触及 9860 上沿（仅魁地奇球员可）" % jid)

	# ㉑ 正典 223 行「普通家庭年收入约数百加隆」：**这是量级自洽的真判据**
	#    （缺陷⑪ 的元教训：不要用「每条都 <= 15 加隆」这种倒推的软参考当判据）
	var wages := PackedInt32Array()
	for jid in reg.ids("jobs"):
		wages.append(int(reg.entry("jobs", jid).get("wage_knuts", 0)))
	wages.sort()
	var median_wage := wages[wages.size() / 2]
	var year_galleons := float(median_wage * 12) / float(Money.KNUTS_PER_GALLEON)
	a.eq(median_wage, 6900, "中位工资 == 6900（14 加隆）")
	a.is_true(year_galleons >= 100.0 and year_galleons <= 999.0,
		"中位工资年收入 %.1f 加隆落在「数百加隆」档" % year_galleons)


func _check_settlement(a: TestAssert) -> void:
	var w := make_world()
	_pin(w, Economy.NEUTRAL_INDEX)

	# ㉒ 成年门槛常量与正典口径对齐（K2）
	a.eq(Economy.ADULT_MONTHS, 204, "ADULT_MONTHS == 17 × 12")
	a.eq(Economy.FOOD_UNITS_PER_MONTH, 60, "FOOD_UNITS_PER_MONTH == 60（两餐/日）")
	a.eq(Economy.UNKNOWN_WAGE_KNUTS, 4930, "UNKNOWN_WAGE_KNUTS == 店员档 4930")

	# ㉓ 月支出 = 房租 + 食物 × 60，且**必须走 price_of**（危机期物价翻倍则开销跟着涨）
	var rent := Economy.price_of(w, "svc_rent")
	var food := Economy.price_of(w, "food_pumpkin_pastry")
	a.eq(rent, 4437, "中性地点房租 == base 4437")
	a.eq(food, 34, "食物单价 == 34（缺陷⑨ 修正值）")
	var expected_expense := rent + food * Economy.FOOD_UNITS_PER_MONTH
	a.eq(expected_expense, 6477, "月支出 == 6477 纳特（≈13.14 加隆，spec §7.6 实算）")

	# ⚠️ 幂等门是 `last_settlement_turn == clock.turn`，而新建世界的 `turn` 与
	# `last_settlement_turn` **都是 0** ⇒ 不推回合的话第一次结算就被门挡掉。
	# 真实流程里 `tick()` **先** `advance_month()`（turn 0→1）**再**结算，故此处模拟之。
	# 这不是绕过守卫，是**复现真实调用序**（spec §9 第 5 条的门是为「同回合重复调用」设的）。

	# ㉔ 有业者：净收 > 0 但很薄；无业者：净收 < 0（K2「不工作会饿」有牙齿）
	w.player.age_months = Economy.ADULT_MONTHS
	w.player.job = "商人"
	w.economy["last_settlement_turn"] = 0
	w.clock.advance_month()
	var net := Economy.monthly_settlement(w)
	a.eq(int(net.get("income", 0)), 6900, "商人月工资 == 6900")
	a.eq(int(net.get("expense", 0)), expected_expense, "结算开销 == 应收开销")
	a.is_true(int(net.get("income", 0)) - int(net.get("expense", 0)) > 0,
		"有业者月净收 > 0（但仅 +423 纳特，很薄）")
	a.eq(int(w.economy["last_month_income"]), 6900, "写回 last_month_income")
	a.eq(int(w.economy["last_month_expense"]), expected_expense, "写回 last_month_expense")
	a.eq(int(w.player.money_knuts), 6900 - expected_expense, "现金按净额变更")

	# 无业者：只有支出
	var w0 := make_world()
	_pin(w0, Economy.NEUTRAL_INDEX)
	w0.player.age_months = Economy.ADULT_MONTHS
	w0.player.job = ""
	var before0 := int(w0.player.money_knuts)
	w0.clock.advance_month()
	var net0 := Economy.monthly_settlement(w0)
	a.eq(int(net0.get("income", 0)), 0, "无业者无工资")
	a.is_true(int(net0.get("expense", 0)) > 0, "无业者仍有开销")
	a.is_true(int(w0.player.money_knuts) < before0, "无业者现金净减少")
	a.eq(int(w0.player.money_knuts) - before0, -expected_expense, "无业者恰好花掉一个月开销")

	# 未成年：整月跳过 —— 收支皆 0（缺陷⑫ 读法 B，锁定为契约）
	var wk := make_world()
	_pin(wk, Economy.NEUTRAL_INDEX)
	wk.player.age_months = Economy.ADULT_MONTHS - 1
	wk.player.job = "商人"
	var beforek := int(wk.player.money_knuts)
	wk.clock.advance_month()
	var netk := Economy.monthly_settlement(wk)
	a.eq(int(netk.get("income", 0)), 0, "未成年无工资")
	a.eq(int(netk.get("expense", 0)), 0, "未成年**也不收生活费**（缺陷⑫ 读法 B：由家庭/学校供养）")
	a.eq(int(netk.get("interest", 0)), 0, "未成年无利息")
	a.eq(int(wk.player.money_knuts), beforek, "未成年现金不变")
	a.eq(int(wk.economy["last_settlement_turn"]), int(wk.clock.turn),
		"未成年也推进结算回合（下月不会被重复扫）")

	# 未成年但有存款：利息也**不结算**（整月跳过的一致性）
	var wk2 := make_world()
	_pin(wk2, Economy.NEUTRAL_INDEX)
	wk2.player.age_months = Economy.ADULT_MONTHS - 1
	wk2.economy["gringotts_balance"] = 100000
	wk2.clock.advance_month()
	Economy.monthly_settlement(wk2)
	a.eq(int(wk2.economy["gringotts_balance"]), 100000, "未成年整月跳过：利息也不结算")

	# 成年边界：正好 204 个月 ⇒ 开始结算（门槛是 >=，不是 >）
	var wb0 := make_world()
	_pin(wb0, Economy.NEUTRAL_INDEX)
	wb0.player.age_months = Economy.ADULT_MONTHS
	wb0.player.job = "店员"
	wb0.clock.advance_month()
	var netb0 := Economy.monthly_settlement(wb0)
	a.eq(int(netb0.get("income", 0)), 4930, "正好 204 个月即成年 ⇒ 发工资（>= 不是 >）")
	a.is_true(int(netb0.get("expense", 0)) > 0, "成年后开始收生活费")

	# ㉕ 自由文本职业宽容匹配：精确 → 包含 → 兜底（不得变成零收入）
	var wf := make_world()
	_pin(wf, Economy.NEUTRAL_INDEX)
	wf.player.age_months = Economy.ADULT_MONTHS
	wf.player.job = "魔药师"
	a.eq(Economy._wage_for(wf, "魔药师"), 7395, "精确匹配 label → 7395")
	a.eq(Economy._wage_for(wf, "霍格沃茨的魔药师"), 7395, "包含匹配 → 7395")
	a.eq(Economy._wage_for(wf, "见习傲罗"), Economy.UNKNOWN_WAGE_KNUTS,
		"无法匹配 → 兜底 4930（不是 0）")
	a.eq(Economy._wage_for(wf, ""), Economy.UNKNOWN_WAGE_KNUTS, "空职业 → 兜底 4930")
	a.eq(Economy._wage_for(wf, "apothecary"), 7395, "按 id 也能匹配 → 7395")

	# ㉖ 利息：只对正余额计息，负余额不计（spec §7.6）
	var wi := make_world()
	_pin(wi, Economy.NEUTRAL_INDEX)
	wi.player.age_months = Economy.ADULT_MONTHS
	wi.player.job = ""
	wi.player.money_knuts = 0
	wi.economy["gringotts_balance"] = 100000
	wi.economy["gringotts_interest_rate"] = 0.002
	wi.clock.advance_month()
	var neti := Economy.monthly_settlement(wi)
	a.eq(int(neti.get("interest", 0)), 200, "利息 == floori(100000 × 0.002) == 200")
	a.eq(int(wi.economy["gringotts_balance"]), 100200, "利息只加本金、不资本化")

	var wn := make_world()
	_pin(wn, Economy.NEUTRAL_INDEX)
	wn.player.age_months = Economy.ADULT_MONTHS
	wn.player.job = ""
	wn.economy["gringotts_balance"] = -5000
	wn.economy["gringotts_interest_rate"] = 0.002
	wn.clock.advance_month()
	var netn := Economy.monthly_settlement(wn)
	a.eq(int(netn.get("interest", 0)), 0, "负余额不计息（不资本化债务）")
	a.eq(int(wn.economy["gringotts_balance"]), -5000, "负余额不被利息改动")

	# ㉗ 幂等：同回合二次结算直接返回 0，且**不改任何字段**（spec §9 第 5 条）
	var wd := make_world()
	_pin(wd, Economy.NEUTRAL_INDEX)
	wd.player.age_months = Economy.ADULT_MONTHS
	wd.player.job = "商人"
	wd.clock.advance_month()
	# 先做一次真实结算，让 last_settlement_turn 跟上 turn
	Economy.monthly_settlement(wd)
	var cur_turn := int(wd.clock.turn)
	a.eq(int(wd.economy["last_settlement_turn"]), cur_turn, "结算推进 last_settlement_turn")
	var snap_money := int(wd.player.money_knuts)
	var snap_econ := (wd.economy as Dictionary).duplicate(true)
	var netd := Economy.monthly_settlement(wd)
	a.eq(int(netd.get("income", 0)), 0, "幂等：二次结算无收入")
	a.eq(int(netd.get("expense", 0)), 0, "幂等：二次结算无开销")
	a.eq(int(netd.get("interest", 0)), 0, "幂等：二次结算无利息")
	a.eq(int(wd.player.money_knuts), snap_money, "幂等：现金不变")
	a.eq(wd.economy, snap_econ, "幂等：economy 字典逐字不变")

	# 再推一个月 ⇒ 又能结算（门只挡同回合，不挡下一回合）
	wd.clock.advance_month()
	var netd2 := Economy.monthly_settlement(wd)
	a.eq(int(netd2.get("income", 0)), 6900, "下一回合恢复结算（门只挡同回合）")
	a.eq(int(wd.economy["last_settlement_turn"]), int(wd.clock.turn), "再次推进结算回合")

	# ㉘ 确定性：同输入两次结果逐字一致（无随机）
	var wa := make_world()
	_pin(wa, Economy.NEUTRAL_INDEX)
	wa.player.age_months = Economy.ADULT_MONTHS
	wa.player.job = "记者"
	wa.clock.advance_month()
	var wb := make_world()
	_pin(wb, Economy.NEUTRAL_INDEX)
	wb.player.age_months = Economy.ADULT_MONTHS
	wb.player.job = "记者"
	wb.clock.advance_month()
	a.eq(Economy.monthly_settlement(wa), Economy.monthly_settlement(wb),
		"同输入两次结算结果逐字一致（确定性）")

	# ㉙ 开销走 price_of：景气变差（危机）时开销真的变贵
	var wc := make_world()
	_pin(wc, Economy.CRISIS_THRESHOLD - 0.05)
	wc.player.age_months = Economy.ADULT_MONTHS
	wc.player.job = ""
	wc.clock.advance_month()
	var netc := Economy.monthly_settlement(wc)
	a.is_true(int(netc.get("expense", 0)) > expected_expense,
		"危机期月开销高于中性期（%d > %d）" % [int(netc.get("expense", 0)), expected_expense])


# 测试内辅助：直接改内存里的表内容（不影响 res://data）
func _mutate_base_output(w: WorldState, industry_id: String, value: float) -> void:
	w.registry.entry("industries", industry_id)["base_output"] = value
