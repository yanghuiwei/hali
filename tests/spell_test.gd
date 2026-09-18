class_name SpellTest
extends RefCounted

func make_world(reg: Registry, tier: int) -> WorldState:
	var p := PlayerState.new_default()
	p.bloodline_id = "half_blood"
	p.aptitude_id = "normal"
	p.magic_tier = tier
	p.location_id = "hogwarts"
	var w := WorldState.create("modern", p, 20260918, reg)
	return w

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	a.eq(reg.validate().size(), 0, "魔咒表加入后仍无校验错误")
	a.is_true(reg.ids("spells").size() >= 24, "魔咒表至少 24 条")

	# 内容完整性：每条魔咒的 min_tier 必须是合法等级标签，守卫必须是已定义守卫
	for spell_id in reg.ids("spells"):
		var spell := reg.entry("spells", spell_id)
		a.is_true(MagicLevel.index_of_label(str(spell.get("min_tier", ""))) >= 0, "魔咒 %s 的 min_tier 非法" % spell_id)
		for guard in (spell.get("guards", []) as Array):
			a.is_true(SpellResolver.GUARDS.has(str(guard)), "魔咒 %s 引用未知守卫 %s" % [spell_id, str(guard)])
		a.is_true((spell.get("side_effects", []) as Array).size() > 0, "魔咒 %s 必须有失败副作用" % spell_id)

	# ---- 等级不足被拦截（第二十三章） ----
	var low := make_world(reg, MagicLevel.Tier.FIRST_YEAR)
	var rng := RngService.new(1)
	var blocked := SpellResolver.cast(low, "expecto_patronum", {}, rng)
	a.is_true(blocked.blocked, "新生无法施展守护神咒")
	a.is_true(blocked.blocked_reason.contains("等级"), "拦截原因说明等级不足")
	a.is_false(blocked.ok, "被拦截时 ok=false")

	var unknown := SpellResolver.cast(low, "没有这条魔咒", {}, rng)
	a.is_true(unknown.blocked, "未知魔咒被拦截")
	a.is_true(unknown.blocked_reason.contains("未知"), "未知魔咒原因明确")

	# ---- 第五十五条：复制咒不得无限复制稀有资源 ----
	var mid := make_world(reg, MagicLevel.Tier.ADULT)
	var rare := SpellResolver.cast(mid, "geminio", {"target_rarity": "rare"}, RngService.new(2))
	a.is_true(rare.blocked, "复制稀有资源被拦截")
	a.is_true(rare.blocked_reason.contains("稀有"), "稀有资源原因明确")
	var common := SpellResolver.cast(mid, "geminio", {"target_rarity": "common"}, RngService.new(2))
	a.is_false(common.blocked, "复制普通物品不被拦截")
	# 稀有度词表必须同时识别中文（否则中文「稀有」会静默绕过反复制守卫）
	var rare_cn := SpellResolver.cast(mid, "geminio", {"target_rarity": "稀有"}, RngService.new(2))
	a.is_true(rare_cn.blocked, "中文「稀有」也必须被反复制守卫拦截")

	# ---- 第五十五条：治疗咒不得无限复活 ----
	var dead := SpellResolver.cast(mid, "vulnera_sanentur", {"target_alive": false}, RngService.new(3))
	a.is_true(dead.blocked, "对死者施治疗术被拦截")
	a.is_true(dead.blocked_reason.contains("复活") or dead.blocked_reason.contains("死者"), "复活原因明确")
	var alive_target := SpellResolver.cast(mid, "vulnera_sanentur", {"target_alive": true}, RngService.new(3))
	a.is_false(alive_target.blocked, "对活人施治疗术不被拦截")

	# ---- 第五十五条：时间转换器不得无限回溯 ----
	var master := make_world(reg, MagicLevel.Tier.MASTER)
	master.flags["time_rewind_count"] = 0
	a.is_false(SpellResolver.cast(master, "time_turner", {}, RngService.new(4)).blocked, "首次时间回溯允许（但受严格限制）")
	master.flags["time_rewind_count"] = 1
	a.is_true(SpellResolver.cast(master, "time_turner", {}, RngService.new(4)).blocked, "第二次时间回溯被拦截")

	# ---- 第五十五条：低阶咒语无限叠加 ----
	master.flags["energy_loop_count"] = 0
	a.is_false(SpellResolver.cast(master, "lumos", {}, RngService.new(5)).blocked, "正常照明咒")
	master.flags["energy_loop_count"] = 3
	a.is_true(SpellResolver.cast(master, "lumos", {}, RngService.new(5)).blocked, "低阶咒语叠加过量被拦截")

	# ---- 第二十五章：不可饶恕咒不拦截，但必须留下法律风险 ----
	var unforgivable := SpellResolver.cast(master, "imperio", {}, RngService.new(6))
	a.is_false(unforgivable.blocked, "不可饶恕咒可以被使用")
	a.is_true(unforgivable.legal_risk, "不可饶恕咒带法律风险")
	a.is_true(forbidden_count(reg) >= 6, "至少 6 条禁忌/受限魔咒")

	# ---- 魂器：终身禁忌，永久拦截（需要神话级才能绕过等级拦截，真正让守卫生效） ----
	var myth := make_world(reg, MagicLevel.Tier.MYTH)
	var horcrux := SpellResolver.cast(myth, "horcrux", {}, RngService.new(7))
	a.is_true(horcrux.blocked, "魂器永远被拦截")
	a.is_true(horcrux.guards.has("forbidden_lifetime"), "魂器带终身禁忌守卫")
	a.is_true(horcrux.blocked_reason.contains("禁忌"), "魂器拦截原因说明禁忌")

	# ---- 需登记的阿尼马格斯 ----
	master.player.flags.erase("animagus_registered")
	a.is_true(SpellResolver.cast(master, "animagus", {}, RngService.new(8)).blocked, "未登记不得变形")
	master.player.flags["animagus_registered"] = true
	a.is_false(SpellResolver.cast(master, "animagus", {}, RngService.new(8)).blocked, "登记后可变形")

	# ---- 需魔法部批准的门钥匙 ----
	master.flags.erase("ministry_approval")
	a.is_true(SpellResolver.cast(master, "portkey", {}, RngService.new(12)).blocked, "无魔法部批准不得使用门钥匙")
	master.flags["ministry_approval"] = true
	a.is_false(SpellResolver.cast(master, "portkey", {}, RngService.new(12)).blocked, "有批准后可使用门钥匙")

	# ---- 失败率必须落在规格区间内（用难度 0 的咒语对齐等级区间），环境因素抬高失败率 ----
	var adult := make_world(reg, MagicLevel.Tier.ADULT)
	var calm := SpellResolver.cast(adult, "lumos", {}, RngService.new(9))
	a.between(calm.failure_rate, 0.02, 0.05, "熟练成年巫师基础咒语失败率 2-5%（第二十二章）")
	# 咒语难度是在等级区间之上的额外偏移
	var hard := SpellResolver.cast(adult, "confringo", {}, RngService.new(9))
	a.is_true(hard.failure_rate > calm.failure_rate, "高难度咒语失败率更高")
	var stressed := SpellResolver.cast(adult, "lumos", {
		"combat_stress": 1.0, "injury": 1.0, "emotion": 1.0,
		"wand_mismatch": 1.0, "unfamiliar_spell": 1.0, "dark_magic_interference": 1.0,
	}, RngService.new(9))
	a.between(stressed.failure_rate, 0.92, 0.95, "六项满值环境因素把失败率推到上界")
	a.is_true(modifiers_from_test(adult) > 0.0, "未知条件被忽略")
	a.is_false(SpellResolver.modifiers_from({"不存在的因素": 1.0}).has("不存在的因素"), "未知条件键被丢弃")

	# ---- 确定性 ----
	var seq_a := []
	var seq_b := []
	for i in 10:
		seq_a.append(SpellResolver.cast(adult, "expelliarmus", {}, RngService.new(100 + i)).success)
		seq_b.append(SpellResolver.cast(adult, "expelliarmus", {}, RngService.new(100 + i)).success)
	a.eq(seq_a, seq_b, "同种子同结果")

	# ---- 成功与失败都要有旁白；失败必须有副作用 ----
	var any_success := false
	var any_failure := false
	for i in 50:
		var out := SpellResolver.cast(adult, "stupefy", {"combat_stress": 1.0}, RngService.new(200 + i))
		a.is_true(out.narration.length() > 0, "必须有旁白")
		if out.success:
			any_success = true
			a.eq(out.side_effect, "", "成功无副作用")
		else:
			any_failure = true
			a.is_true(out.side_effect.length() > 0, "失败必有副作用（第二十二章）")
	a.is_true(any_success, "50 次里应有成功")
	a.is_true(any_failure, "50 次里应有失败")

	return a.report("spell")

func forbidden_count(reg: Registry) -> int:
	var n := 0
	for spell_id in reg.ids("spells"):
		if bool(reg.entry("spells", spell_id).get("forbidden", false)):
			n += 1
	return n

func modifiers_from_test(w: WorldState) -> float:
	var m := SpellResolver.modifiers_from({"不存在的因素": 1.0, "combat_stress": 0.5})
	return float(m.get("combat_stress", 0.0))
