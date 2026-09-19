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

	return a.report("panel")
