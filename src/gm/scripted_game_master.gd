class_name ScriptedGameMaster
extends GameMaster

const TRAIN_KEYWORDS: Array[String] = ["练习", "学习", "训练", "钻研", "研究", "复习", "上课"]
const WORK_KEYWORDS: Array[String] = ["打工", "赚钱", "上班", "经商", "接活", "做生意"]
const SOCIAL_KEYWORDS: Array[String] = ["打听", "询问", "聊天", "结交", "社交", "谈"]
const REST_KEYWORDS: Array[String] = ["休息", "睡觉", "吃饭", "喝", "闲逛", "发呆", "回家"]
const CAST_KEYWORDS: Array[String] = ["念", "施展", "使用咒语", "施法", "用魔杖"]

# 计划 03a（Task 9）：派系动作关键词。派系名/别名一律从内容表（data/factions.json）取，代码不硬编码中文派系名。
# 关键词必须是**不带省略号**的普通词：「做事」而非「为…做事」（含 U+2026 的写法玩家几乎不可能原样输入，等于死关键词）。
const FACTION_JOIN: Array[String] = ["加入", "投靠", "效力", "做事", "入伙"]
const FACTION_LEAVE: Array[String] = ["退出", "脱离", "叛出", "不再属于"]
const FACTION_SUPPORT: Array[String] = ["支持", "拥护", "声援", "捐款", "赞助"]
const FACTION_OPPOSE: Array[String] = ["反对", "抗议", "抨击", "揭露", "抵制"]

# 计划 03b（Task 9）：离线替身的经济动作关键词。与派系分支同款 —— 只增不改既有分支。
const ECON_DEPOSIT: Array[String] = ["存进古灵阁", "存入古灵阁", "存钱", "存款", "存入"]
const ECON_WITHDRAW: Array[String] = ["取出", "取钱", "取款"]
const ECON_BUY: Array[String] = ["买", "购买", "购入"]
const ECON_SELL: Array[String] = ["卖", "出售", "卖出"]
const ECON_EXCHANGE: Array[String] = ["换外币", "换成外币", "兑换外币", "外汇兑换", "换汇"]

const SKILL_BY_KEYWORD: Dictionary = {
	"魔药": "potions", "草药": "herbology", "魔咒": "charms", "变形": "transfiguration",
	"黑魔法防御": "dada", "防御": "dada", "历史": "history_of_magic", "天文": "astronomy",
	"占卜": "divination", "魔文": "ancient_runes", "神奇生物": "care_of_magical_creatures",
	"魁地奇": "quidditch", "治疗": "healing", "社交": "social", "口才": "social",
}

var rng: RngService = null

func _init(rng_: RngService = null) -> void:
	rng = rng_ if rng_ != null else RngService.new(0)

func _contains_any(text: String, keywords: Array) -> bool:
	for k in keywords:
		if text.contains(str(k)):
			return true
	return false

func _detect_skill(text: String) -> String:
	# 第六十三章：主修科目来自玩家长期投入
	for keyword in SKILL_BY_KEYWORD.keys():
		if text.contains(str(keyword)):
			return str(SKILL_BY_KEYWORD[keyword])
	return "charms"

func _detect_spell(world: WorldState, text: String) -> String:
	for spell_id in world.registry.ids("spells"):
		var label := str(world.registry.entry("spells", spell_id).get("label", ""))
		if not label.is_empty() and text.contains(label):
			return str(spell_id)
	return ""

# 计划 03a：识别玩家嘴里提到的“已揭示”派系（label 或 aliases）。未揭示的一律识别为空（第四十三/五十七章）。
# tie-break：按 `visible_faction_ids()`（id 字典序）返回**第一个**命中者 —— 同句提到多个派系时仍确定性可复现。
func _detect_faction(world: WorldState, text: String) -> String:
	for fid in WorldFactions.visible_faction_ids(world):
		var id := str(fid)
		var entry := world.registry.entry("factions", id)
		var label := str(entry.get("label", ""))
		if not label.is_empty() and text.contains(label):
			return id
		# Task 9 审查 M1：内容畸形（aliases 不是数组）时 `as Array` 会**运行期报错并中止本函数**，
		# 于是 id 字典序靠后的派系再也扫不到（静默降级为“未命中”）。这里先做类型守卫。
		var aliases = entry.get("aliases", [])
		if typeof(aliases) != TYPE_ARRAY:
			continue
		for alias in (aliases as Array):
			if not str(alias).is_empty() and text.contains(str(alias)):
				return id
	return ""

# 计划 03b（Task 9）：从句内抽取第一个整数（用于「存 100 纳特」「买 2 根魔杖」）。
# 返回 -1 表示**没有**数字 —— 调用方据此放弃产出 op（不瞎猜金额）。
func _detect_amount(text: String) -> int:
	var digits := ""
	for i in text.length():
		var c := text[i]
		if c >= "0" and c <= "9":
			digits += c
		elif not digits.is_empty():
			break
	if digits.is_empty():
		return -1
	return int(digits)

# 计划 03b（Task 9）：按内容表 label 反查商品 id（代码不硬编码中文商品名）。
# tie-break：按 `registry.ids()`（id 字典序）取**第一个**命中者 —— 与 `_detect_faction()` 同款确定性规则。
# ⚠️ 只认 `label` 完全包含，且**优先最长 label** —— 避免「普通魔杖」被「魔杖」类短 label 抢先命中。
func _detect_good(world: WorldState, text: String) -> String:
	var best_id := ""
	var best_len := 0
	for gid in world.registry.ids("goods"):
		var id := str(gid)
		var label := str(world.registry.entry("goods", id).get("label", ""))
		# 去掉括号后缀（如「房租（月）」→「房租」），否则玩家几乎不可能原样输入
		var bare := label
		var paren := label.find("（")
		if paren > 0:
			bare = label.substr(0, paren)
		if bare.is_empty():
			continue
		if text.contains(bare) and bare.length() > best_len:
			best_id = id
			best_len = bare.length()
	return best_id

func act(world: WorldState, action_text: String) -> GmResult:
	var r := GmResult.new()
	var text := action_text.strip_edges()

	if text.is_empty():
		r.narration = "你没有做任何事。世界继续向前。"
		r.tags.append("idle")
		return r

	# 施法意图优先，避免「练习魔咒」被误判
	var spell_id := _detect_spell(world, text)
	if not spell_id.is_empty() and _contains_any(text, CAST_KEYWORDS):
		r.tags.append("cast")
		# 这里直接调用规则层，因为它必须产出旁白；守卫与代价由 cast() 内部结算。
		# 若由 StateOps 的 cast_spell 操作重放，会掷两次骰并重复结算守卫。
		var outcome := SpellResolver.cast(world, spell_id, {}, rng)
		r.narration = outcome.narration
		if not outcome.blocked and outcome.success:
			# 成功一次即算入门；重复施法不再重复记录（PlayerState.learn_spell 幂等）
			r.deltas.append({"op": "learn_spell", "spell_id": spell_id})
		return r

	# 计划 03a：派系动作（第五十章「可以支持凤凰社、加入食死徒、反对魔法部」）
	# 位置：施法分支之后、TRAIN 之前；**未命中派系时不提前 return**，继续走原有分支。
	var faction_id := _detect_faction(world, text)
	if not faction_id.is_empty():
		var faction_label := str(world.registry.entry("factions", faction_id).get("label", faction_id))
		if _contains_any(text, FACTION_LEAVE):
			r.tags.append("faction")
			# Task 9 审查 M3：旧实现无条件清空所属，于是「已是魔法部成员时输入『我要退出古灵阁』」
			# 会清掉魔法部却旁白说古灵阁（旁白与效果不一致）。现在只有真的属于该派系才产出 op。
			if world.player.faction_id == faction_id:
				r.deltas.append({"op": "leave_faction", "faction_id": faction_id})
				r.narration = "你与%s断了关系。名字从名单上划掉，代价还看不出来。" % faction_label
			else:
				var current_label := "无归属"
				if not world.player.faction_id.is_empty():
					current_label = str(world.registry.entry("factions", world.player.faction_id).get("label", world.player.faction_id))
				r.narration = "你并不属于%s（你当前归属：%s）。这句话没掀起任何波澜。" % [faction_label, current_label]
			return r
		if _contains_any(text, FACTION_JOIN):
			r.tags.append("faction")
			r.deltas.append({"op": "join_faction", "faction_id": faction_id})
			r.narration = "你向%s表明愿意效力。他们先记下你的名字，再看看你能做什么。" % faction_label
			return r
		if _contains_any(text, FACTION_SUPPORT):
			r.tags.append("faction")
			r.deltas.append({"op": "faction_standing_delta", "faction_id": faction_id, "delta": 5})
			r.narration = "你公开支持%s。有人点头，有人把这件事记在了心里。" % faction_label
			return r
		if _contains_any(text, FACTION_OPPOSE):
			r.tags.append("faction")
			r.deltas.append({"op": "faction_standing_delta", "faction_id": faction_id, "delta": -5})
			r.narration = "你公开反对%s。他们会记住你的立场。" % faction_label
			return r

	# 计划 03b（Task 9）：经济动作（存 / 取 / 汇 / 贸）。
	# 位置：派系分支之后、TRAIN 之前；**未命中经济关键词时不提前 return**，继续走原有分支。
	# ⚠️ 缺金额/物品不在内容表时**不产出 op**（返回继续走原分支），绝不瞎猜数值。
	if _contains_any(text, ECON_EXCHANGE):
		var ex_knuts := _detect_amount(text)
		if ex_knuts > 0:
			r.tags.append("economy")
			r.deltas.append({"op": "exchange_money", "knuts": ex_knuts, "direction": "buy"})
			r.narration = "你把 %s 换成了外币。" % Money.from_knuts(ex_knuts).formatted()
			return r

	if _contains_any(text, ECON_DEPOSIT):
		var dep_knuts := _detect_amount(text)
		if dep_knuts > 0:
			r.tags.append("economy")
			r.deltas.append({"op": "deposit_money", "knuts": dep_knuts})
			r.narration = "你把 %s 存进了古灵阁。" % Money.from_knuts(dep_knuts).formatted()
			return r

	if _contains_any(text, ECON_WITHDRAW):
		var wd_knuts := _detect_amount(text)
		if wd_knuts > 0:
			r.tags.append("economy")
			r.deltas.append({"op": "withdraw_money", "knuts": wd_knuts})
			r.narration = "你从古灵阁取出了 %s。" % Money.from_knuts(wd_knuts).formatted()
			return r

	# 贸易：必须同时命中「买/卖」与一个**内容表里存在的**商品；缺一不可。
	var trade_good := _detect_good(world, text)
	if not trade_good.is_empty():
		var trade_mode := ""
		if _contains_any(text, ECON_BUY):
			trade_mode = "buy"
		elif _contains_any(text, ECON_SELL):
			trade_mode = "sell"
		if not trade_mode.is_empty():
			var trade_qty := _detect_amount(text)
			if trade_qty <= 0:
				trade_qty = 1     # 「买根魔杖」没说数量 → 默认 1，比拒绝更符合直觉
			r.tags.append("economy")
			r.deltas.append({"op": "trade_money", "good_id": trade_good, "mode": trade_mode, "qty": trade_qty})
			var good_label := str(world.registry.entry("goods", trade_good).get("label", trade_good))
			r.narration = "你%s了 %d 件%s。" % ["买" if trade_mode == "buy" else "卖", trade_qty, good_label]
			return r

	if _contains_any(text, TRAIN_KEYWORDS):
		var skill_id := _detect_skill(text)
		var amount := Progression.gain(world, skill_id, 4)
		r.tags.append("train")
		r.deltas.append({"op": "gain_skill", "skill_id": skill_id, "amount": amount})
		var skill_label := str(world.registry.entry("skills", skill_id).get("label", skill_id))
		if amount >= 4:
			r.narration = "你花了整整一个月钻研%s，进步明显。" % skill_label
		elif amount > 0:
			r.narration = "你继续练%s，但收获不如从前（重复练习收益下降）。" % skill_label
		else:
			r.narration = "你在同一个地方反复练%s，几乎没有任何进步。你需要新的环境或新的问题。" % skill_label
		return r

	if _contains_any(text, WORK_KEYWORDS):
		var income := 30 + int(world.player.skill("social")) * 2 + int(rng.stream_int("work", 0, 20))
		r.tags.append("work")
		r.deltas.append({"op": "add_money", "knuts": income})
		r.narration = "你忙了一个月，赚到 %s。" % Money.from_knuts(income).formatted()
		return r

	if _contains_any(text, SOCIAL_KEYWORDS):
		var roll := rng.stream_float("social")
		r.tags.append("social")
		if roll < 0.5:
			r.deltas.append({"op": "know_fact", "fact_id": "rumor_%d" % world.clock.turn, "source": "破釜酒吧传闻"})
			r.narration = "你在酒吧里听人说了一些事。真假难辨，但至少有了线索。"
		else:
			r.narration = "你试着搭话，对方只是敷衍了几句。信息不会免费送上门。"
		return r

	if _contains_any(text, REST_KEYWORDS):
		r.tags.append("rest")
		r.narration = "你过了一个平常的月份：吃饭、睡觉、读《预言家日报》。"
		return r

	r.tags.append("idle")
	r.narration = "你尝试做了些别的事。世界未必回应，但它仍在继续。"
	return r
