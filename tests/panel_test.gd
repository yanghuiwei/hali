class_name PanelTest
extends RefCounted

func make_world() -> WorldState:
	var reg := Registry.load_default()
	var p := PlayerState.new_default()
	p.name_text = "张三"
	p.gender = "男"
	p.bloodline_id = "muggle_born"
	p.birth_identity_id = "ordinary_wizard_family"
	p.house_id = "gryffindor"
	p.aptitude_id = "normal"
	p.age_months = 132
	p.money_knuts = 4930
	p.location_id = "london_muggle"
	p.job = "学生"
	p.life_goal = "我想知道魔法到底能走多远"
	p.current_goal = p.life_goal
	p.magic_tier = MagicLevel.Tier.FIRST_YEAR
	p.wand = {"wood": "holly", "core": "phoenix_feather", "length_inches": 11.0, "flexibility": "supple",
		"label": "冬青木，凤凰羽毛，11.00英寸，易弯曲"}
	p.skills["potions"] = 3
	p.relations["npc_severus"] = {"name": "西弗勒斯·斯内普", "identity": "魔药课教授", "bloodline": "混血巫师",
		"relation": "师生", "trust": -5, "interest": 0, "hostility": 10, "recent": "在课堂上讽刺了你的坩埚"}
	var w := WorldState.create("modern", p, 1, reg)
	w.clock.year = 1991
	w.clock.month = 9
	return w

func run() -> int:
	var a := TestAssert.new()
	var w := make_world()

	# ---- 第六十二章人生状态面板 ----
	var panel := PanelFormatter.player_panel(w)
	a.is_true(panel.contains("《哈利·波特·魔法纪元·人生状态》"), "面板标题")
	for label in ["【时间】", "【年龄】", "【血统】", "【身份】", "【所在地】", "【职业】", "【财富】", "【家庭】",
			"【社会地位】", "【魔法能力】", "【战斗能力】", "【魔药/治疗】", "【技能】", "【声望】",
			"【重要关系】", "【所属势力】", "【当前目标】"]:
		a.is_true(panel.contains(str(label)), "第六十二章含字段 %s" % str(label))
	a.is_true(panel.contains("1991年9月"), "含时间")
	a.is_true(panel.contains("麻瓜出身"), "血统译名（不是 id）")
	a.is_true(panel.contains("10加隆 0西可 0纳特"), "财富格式")
	a.is_true(panel.contains("张三"), "姓名")

	# ---- 第六十三章魔法面板 ----
	var magic_panel := PanelFormatter.magic_panel(w)
	for label in ["【魔杖】", "【魔力容量】", "【控制精度】", "【魔法亲和】", "【主修科目】",
			"【已掌握魔咒】", "【实验中的魔法】", "【魔药水平】", "【大脑封闭术】", "【幻影移形】", "【守护神形态】"]:
		a.is_true(magic_panel.contains(str(label)), "第六十三章含字段 %s" % str(label))
	a.is_true(magic_panel.contains("冬青木"), "魔杖可读描述")

	# 哑炮必须显示无魔法，而不是空白
	var reg := Registry.load_default()
	var squib := PlayerState.new_default()
	squib.name_text = "李四"
	squib.bloodline_id = "squib"
	squib.aptitude_id = "squib"
	squib.magic_tier = MagicLevel.Tier.SQUIB
	squib.wand = {}
	var w2 := WorldState.create("modern", squib, 1, reg)
	var squib_magic := PanelFormatter.magic_panel(w2)
	a.is_true(squib_magic.contains("无魔法天赋"), "哑炮面板说明无魔法")
	a.is_true(squib_magic.contains("未拥有"), "哑炮没有魔杖")

	# ---- 第六十四章社会关系面板 ----
	var rel := PanelFormatter.relation_panel(w)
	a.is_true(rel.contains("【关键人物】"), "关系面板标题")
	for label in ["身份", "血统", "关系", "信任", "利益", "敌意", "最近动态"]:
		a.is_true(rel.contains(str(label)), "第六十四章含 %s" % str(label))
	a.is_true(rel.contains("西弗勒斯·斯内普"), "含 NPC 姓名")

	# ---- 第六十五章势力面板 ----
	var power := PanelFormatter.power_panel(w)
	a.is_true(power.contains("【魔法部状态】"), "魔法部面板")
	a.is_true(power.contains("【霍格沃茨】"), "霍格沃茨面板")
	for label in ["部长", "法律执行", "傲罗", "威森加摩", "稳定度", "腐败度", "纯血影响", "麻瓜关系",
			"学院", "学业", "学院杯", "魁地奇", "禁林状况", "祖宅", "继承"]:
		a.is_true(power.contains(str(label)), "第六十五章含 %s" % str(label))

	# ---- 状态行与事件块 ----
	a.is_true(PanelFormatter.status_line(w).contains("1991年9月"), "状态行含时间")
	var events := [{"kind": "rumor", "category": "经济", "text": "魔药材料涨价了", "major": false}]
	var block := PanelFormatter.events_block(events)
	a.is_true(block.contains("经济"), "事件块含分类")
	a.is_true(block.contains("魔药材料涨价了"), "事件块含文本")

	# 空/边界分支
	a.eq(PanelFormatter.events_block([]), "本月没有特别的消息。", "空事件块")
	var empty_p := PlayerState.new_default()
	var w_empty := WorldState.create("modern", empty_p, 1, reg)
	a.is_true(PanelFormatter.status_line(w_empty).contains("未知"), "未知地点回退为未知")
	a.is_true(PanelFormatter.relation_panel(w_empty).contains("暂无关键人物"), "空关系面板")
	a.is_true(PanelFormatter.player_panel(w_empty).contains("未知"), "空政治倾向回退为未知")
	# 非哑炮但无魔杖 → 未拥有
	var no_wand := PlayerState.new_default()
	no_wand.name_text = "王五"
	no_wand.magic_tier = MagicLevel.Tier.FIRST_YEAR
	no_wand.wand = {}
	var w_nw := WorldState.create("modern", no_wand, 1, reg)
	a.is_true(PanelFormatter.magic_panel(w_nw).contains("未拥有"), "无魔杖的巫师显示未拥有")
	a.is_true(PanelFormatter.magic_panel(w_nw).contains("未成形"), "无守护神显示未成形")

	# ---- 计划 03a：势力面板（第六十五章 + 【已知势力】） ----
	WorldFactions.initialize(w)
	power = PanelFormatter.power_panel(w)   # 复用 :74 已声明的 power（同函数内不得重复声明）
	a.is_true(power.contains("《哈利·波特·魔法纪元·势力面板》"), "势力面板标题")
	a.is_true(power.contains("政体：魔法部官僚制"), "政体来自内容表")
	a.is_true(power.contains("法律执行：0.75（魔法部）"), "机构指标来自控制权 + holder 标签")
	a.is_true(power.contains("傲罗：0.60（傲罗指挥部）"), "傲罗控制权来自傲罗指挥部")
	a.is_true(power.contains("威森加摩：0.58（威森加摩）"), "威森加摩控制权来自威森加摩派系")
	a.is_true(power.contains("国际："), "含国际指标")
	a.is_true(power.contains("财政："), "含财政指标")
	a.is_true(power.contains("稳定度："), "含稳定度指标")
	a.is_true(power.contains("腐败度："), "含腐败度指标")
	a.is_true(power.contains("纯血影响："), "含纯血影响指标")
	a.is_true(power.contains("麻瓜关系："), "含麻瓜关系指标")
	a.is_false(power.contains("待定"), "不再有占位「待定」")
	a.is_true(power.contains("【已知势力】"), "含【已知势力】行")
	a.is_true(power.contains("【已知势力】魔法部：0.75"), "已知势力按实力降序（魔法部居首）")
	a.is_true(power.contains("食死徒") == false, "未揭示的派系不得出现（第四十三/五十七章）")

	WorldFactions.ensure_state(w, "death_eaters")["revealed"] = true
	w.player.faction_id = "ministry"
	w.player.add_standing("ministry", 30)
	var power2 := PanelFormatter.power_panel(w)
	a.is_true(power2.contains("食死徒"), "揭示后出现在面板里")
	a.is_true(power2.contains("立场 +30"), "显示玩家立场")
	a.is_true(power2.contains("[所属]"), "标出玩家所属派系")

	# ---- §8#7 修好的证据：机构指标取自派系控制权（world_vars 里根本没有这些键） ----
	a.is_false(w.world_vars.has("auror_office"), "world_vars 不含机构键（下面那条不可能是从标量读的）")
	WorldFactions.ensure_state(w, "auror_office")["control"]["auror_office"] = 0.90
	a.is_true(PanelFormatter.power_panel(w).contains("傲罗：0.90（傲罗指挥部）"),
		"傲罗指标随派系控制权变化（若仍读 world_vars 会是 0.00）")
	WorldFactions.ensure_state(w, "auror_office")["control"]["auror_office"] = 0.60
	# 注意：神圣二十八族也声明了 wizengamot（0.55），所以必须设到 0.91 才会成为 holder
	# （设 0.31 时 holder 仍是神圣二十八族——面板显示 0.55（神圣二十八族），本断言当年因此红过）
	WorldFactions.ensure_state(w, "wizengamot")["control"]["wizengamot"] = 0.91
	a.is_true(PanelFormatter.power_panel(w).contains("威森加摩：0.91（威森加摩）"), "威森加摩指标随控制权变化")
	WorldFactions.ensure_state(w, "wizengamot")["control"]["wizengamot"] = 0.58

	# ---- 信息保护：未揭示的派系不得通过机构 holder 泄漏 ----
	var w_hidden := make_world()
	WorldFactions.initialize(w_hidden)
	WorldFactions.ensure_state(w_hidden, "death_eaters")["control"]["law_enforcement"] = 0.99
	var hidden_panel := PanelFormatter.power_panel(w_hidden)
	a.is_true(hidden_panel.contains("法律执行：0.99（未知势力）"),
		"未揭示的 holder 显示为「未知势力」（控制权值照常显示）")
	a.is_false(hidden_panel.contains("食死徒"), "未揭示派系的 label 一个字都不得出现")
	WorldFactions.reveal(w_hidden, "death_eaters", "破釜酒吧传闻")
	a.is_true(PanelFormatter.power_panel(w_hidden).contains("法律执行：0.99（食死徒）"),
		"揭示后同一 holder 显示真名")

	# ---- 政体优先读 world.flags 缓存（evolve 每回合刷新），无缓存才现算 ----
	var w_flag := make_world()
	WorldFactions.initialize(w_flag)
	a.is_false(w_flag.flags.has(WorldFactions.GOVERNMENT_FLAG), "新建世界尚未缓存政体")
	a.is_true(PanelFormatter.power_panel(w_flag).contains("政体：魔法部官僚制"), "无缓存时现算政体")
	w_flag.flags[WorldFactions.GOVERNMENT_FLAG] = "pureblood_oligarchy"
	a.is_true(PanelFormatter.power_panel(w_flag).contains("政体：纯血寡头制"),
		"有缓存时以 flags 为准（若忽略缓存而现算，这里会是官僚制 → 必红）")

	# ---- 全部派系都未揭示时，已知势力行为占位文案 ----
	var w_dark := make_world()
	WorldFactions.initialize(w_dark)
	for fid in w_dark.registry.ids("factions"):
		WorldFactions.ensure_state(w_dark, str(fid))["revealed"] = false
	a.is_true(PanelFormatter.power_panel(w_dark).contains("【已知势力】暂无已知势力"), "全隐藏时显示占位文案")

	return a.report("panel")
