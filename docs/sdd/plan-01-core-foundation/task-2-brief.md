### Task 2: 内容注册表 + 正典内容表

**Files:**
- Create: `src/core/registry.gd`
- Create: `data/eras.json`
- Create: `data/bloodlines.json`
- Create: `data/birth_identities.json`
- Create: `data/aptitudes.json`
- Create: `data/houses.json`
- Create: `data/sim_styles.json`
- Create: `data/political_leanings.json`
- Create: `tests/registry_test.gd`
- Modify: `tests/run_tests.gd`（`SUITES` 追加一行）

**Interfaces:**
- Consumes: `TestAssert`（任务 1）
- Produces:
  - `Registry`（`class_name`，`extends RefCounted`）
    - `TABLE_FILES: Dictionary`（表名 → 文件名）
    - `duplicate_ids: PackedStringArray`
    - `static from_tables(tables: Dictionary) -> Registry`（`tables` 为 表名 → 条目数组；每个条目是含 `id`/`label` 的 Dictionary）
    - `static load_default() -> Registry`（读 `res://data/*.json`）
    - `entry(table: String, id: String) -> Dictionary`（缺失返回空字典 `{}`）
    - `has(table: String, id: String) -> bool`
    - `ids(table: String) -> PackedStringArray`（已排序）
    - `table_dict(table: String) -> Dictionary`（id → 条目）
    - `validate() -> PackedStringArray`（空 = 通过）
  - 内容表字段约定（后续任务全部按此读取）：
    - `eras`: `id,label,start_year,canon_note,secrecy_law,ministry_exists,world_vars{galleons 无关的 7 项世界变量}`
    - `bloodlines`: `id,label,magic_aptitude(bool),prejudice(float 0..1),wealth_tier(int),skill_bias{skill_id:int},default_flags[],risk,note`
    - `birth_identities`: `id,label,start_knuts(int),skill_bias{},contacts(int),note`
    - `aptitudes`: `id,label,failure_delta(float),grants[],special_options[],note`
    - `houses`: `id,label,traits[],note`
    - `sim_styles`: `id,label,event_intensity(float),mundane_ratio(float),note`
    - `political_leanings`: `id,label,pureblood_opinion(float -1..1),ministry_opinion(float -1..1),risk,note`

- [ ] **Step 1: 写失败测试**

创建 `tests/registry_test.gd`：

```gdscript
class_name RegistryTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	# 正典内容表完整性
	var errors := reg.validate()
	for e in errors:
		a.fail("内容表校验失败: " + e)
	a.eq(errors.size(), 0, "默认内容表应无错误")

	# 第七十五章启动界面的选项数量必须与规格一致
	a.eq(reg.ids("eras").size(), 8, "时代 8 项")
	a.eq(reg.ids("bloodlines").size(), 12, "血统 12 项")
	a.eq(reg.ids("birth_identities").size(), 11, "出生身份 11 项")
	a.eq(reg.ids("aptitudes").size(), 6, "魔法资质 6 项")
	a.eq(reg.ids("houses").size(), 6, "学院倾向 6 项")
	a.eq(reg.ids("sim_styles").size(), 6, "模拟风格 6 项")
	a.eq(reg.ids("political_leanings").size(), 6, "政治倾向 6 项")

	# 标签必须与规格逐字一致
	a.eq(reg.entry("eras", "hogwarts_founding")["label"], "霍格沃茨建校早期", "第一时代标签")
	a.eq(reg.entry("eras", "custom")["label"], "自定义时代", "第八时代标签")
	a.eq(reg.entry("bloodlines", "squib")["label"], "哑炮", "哑炮标签")
	a.eq(reg.entry("bloodlines", "obscurial")["label"], "默然者", "默然者标签")
	a.eq(reg.entry("aptitudes", "squib")["label"], "哑炮无魔法天赋", "资质标签")

	# 关键字查询
	a.is_true(reg.has("bloodlines", "werewolf"), "狼人存在")
	a.is_false(reg.has("bloodlines", "dragon"), "不存在的血统")
	a.eq(reg.entry("eras", "没有这个时代"), {}, "缺失条目返回空字典")
	a.eq(reg.entry("bloodlines", "hogwarts_founding"), {}, "跨表查询不得命中")

	# 关键语义字段
	a.is_false(reg.entry("bloodlines", "squib")["magic_aptitude"], "哑炮无魔法天赋")
	a.is_true(reg.entry("bloodlines", "muggle_born")["magic_aptitude"], "麻瓜出身有魔法天赋")
	a.eq(reg.entry("eras", "witch_hunts")["start_year"], 1692, "保密法年份 1692")
	a.eq(reg.entry("eras", "custom")["start_year"], null, "自定义时代年份为空")
	a.eq(reg.entry("aptitudes", "squib")["grants"].size(), 0, "哑炮不授予特殊天赋")

	# 校验器必须能抓到坏数据
	var dup := Registry.from_tables({
		"eras": [
			{"id": "a", "label": "甲"},
			{"id": "a", "label": "乙"},
		],
	})
	var dup_errors := dup.validate()
	var joined := " | ".join(dup_errors)
	a.is_true(joined.contains("重复 id"), "重复 id 必须报错")
	a.is_true(joined.contains("缺少数据表"), "缺失数据表必须报错")

	var no_label := Registry.from_tables({"eras": [{"id": "a"}]})
	a.is_true(" | ".join(no_label.validate()).contains("缺少 label"), "缺 label 必须报错")

	# ids() 必须稳定排序，保证 UI 下拉顺序可复现
	var ids := reg.ids("houses")
	var sorted_copy := ids.duplicate()
	sorted_copy.sort()
	a.eq(ids, sorted_copy, "ids 已排序")

	return a.report("registry")
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /e/Hali
sed -i 's|"res://tests/harness_test.gd",|"res://tests/harness_test.gd",\n\t"res://tests/registry_test.gd",|' tests/run_tests.gd
bash tools/test.sh
```

预期：`套件无法加载（语法错误？）: res://tests/registry_test.gd`（`Registry` 未定义），退出码 1。

- [ ] **Step 3: 写注册表实现**

创建 `src/core/registry.gd`：

```gdscript
class_name Registry
extends RefCounted

const TABLE_FILES: Dictionary = {
	"eras": "eras.json",
	"bloodlines": "bloodlines.json",
	"birth_identities": "birth_identities.json",
	"aptitudes": "aptitudes.json",
	"houses": "houses.json",
	"sim_styles": "sim_styles.json",
	"political_leanings": "political_leanings.json",
}

var duplicate_ids: PackedStringArray = PackedStringArray()
var _tables: Dictionary = {}

static func from_tables(tables: Dictionary) -> Registry:
	var r := Registry.new()
	for table_name in tables.keys():
		var index := {}
		var entries = tables[table_name]
		if typeof(entries) != TYPE_ARRAY:
			continue
		for entry in entries:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var key := str(entry.get("id", ""))
			if index.has(key):
				r.duplicate_ids.append("%s/%s" % [table_name, key])
			index[key] = entry
		r._tables[table_name] = index
	return r

static func load_default() -> Registry:
	var tables := {}
	for table_name in TABLE_FILES.keys():
		var path := "res://data/%s" % TABLE_FILES[table_name]
		var raw := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(raw)
		tables[table_name] = parsed if typeof(parsed) == TYPE_ARRAY else []
	return from_tables(tables)

func entry(table_name: String, id: String) -> Dictionary:
	var index: Dictionary = _tables.get(table_name, {})
	if not index.has(id):
		return {}
	return index[id]

func has(table_name: String, id: String) -> bool:
	return (_tables.get(table_name, {}) as Dictionary).has(id)

func ids(table_name: String) -> PackedStringArray:
	var out := PackedStringArray()
	for key in (_tables.get(table_name, {}) as Dictionary).keys():
		out.append(str(key))
	out.sort()
	return out

func table_dict(table_name: String) -> Dictionary:
	return _tables.get(table_name, {})

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for dup in duplicate_ids:
		errors.append("重复 id: %s" % dup)
	for table_name in TABLE_FILES.keys():
		if not _tables.has(table_name):
			errors.append("缺少数据表: %s" % table_name)
			continue
		var index: Dictionary = _tables[table_name]
		if index.is_empty():
			errors.append("数据表为空: %s" % table_name)
			continue
		for key in index.keys():
			if str(key).is_empty():
				errors.append("%s: 存在空 id 条目" % table_name)
			var e: Dictionary = index[key]
			if str(e.get("label", "")).is_empty():
				errors.append("%s/%s: 缺少 label" % [table_name, key])
	return errors
```

- [ ] **Step 4: 写内容表数据**

创建 `data/eras.json`（8 时代，含第七十五章标签与第四时代锚点；`world_vars` 为世界变量基线，第七十四章第6条「权力是流动的」由此初始化）：

```json
[
	{"id": "hogwarts_founding", "label": "霍格沃茨建校早期", "start_year": 990, "canon_note": "原著未给出确切建校年份，通说约公元10世纪；四位创始人共同建校，斯莱特林与格兰芬多的分裂成为派系斗争开端", "secrecy_law": false, "ministry_exists": false, "world_vars": {"war_pressure": 0.1, "ministry_stability": 0.2, "corruption": 0.1, "pureblood_influence": 0.4, "muggle_relations": 0.5, "economy_index": 0.3, "secrecy_integrity": 0.0}},
	{"id": "witch_hunts", "label": "中世纪猎巫时期", "start_year": 1692, "canon_note": "1692年《国际巫师保密法》正式实施，魔法世界与麻瓜世界彻底分离，魔法部成立", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.3, "ministry_stability": 0.5, "corruption": 0.3, "pureblood_influence": 0.5, "muggle_relations": 0.1, "economy_index": 0.4, "secrecy_integrity": 1.0}},
	{"id": "grindelwald", "label": "格林德沃崛起时代", "start_year": 1926, "canon_note": "格林德沃提出“为了更伟大的利益”，战争席卷欧洲，最终被邓布利多击败", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.6, "ministry_stability": 0.5, "corruption": 0.4, "pureblood_influence": 0.6, "muggle_relations": 0.2, "economy_index": 0.6, "secrecy_integrity": 0.9}},
	{"id": "first_wizarding_war", "label": "第一次巫师战争", "start_year": 1970, "canon_note": "汤姆·里德尔以伏地魔之名聚集食死徒，魔法部陷入腐败与恐惧，凤凰社成立抵抗", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.8, "ministry_stability": 0.4, "corruption": 0.6, "pureblood_influence": 0.7, "muggle_relations": 0.3, "economy_index": 0.5, "secrecy_integrity": 0.8}},
	{"id": "second_wizarding_war", "label": "第二次巫师战争", "start_year": 1995, "canon_note": "魔法部一度被食死徒渗透，霍格沃茨全面开战，最终伏地魔死亡、魂器毁灭", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.9, "ministry_stability": 0.3, "corruption": 0.7, "pureblood_influence": 0.6, "muggle_relations": 0.4, "economy_index": 0.5, "secrecy_integrity": 0.7}},
	{"id": "reconstruction", "label": "战后重建时代", "start_year": 1998, "canon_note": "战后纯血家族瓦解、魔法部改革、麻瓜出身平权等问题依然存在", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.3, "ministry_stability": 0.5, "corruption": 0.5, "pureblood_influence": 0.3, "muggle_relations": 0.5, "economy_index": 0.5, "secrecy_integrity": 0.8}},
	{"id": "modern", "label": "现代巫师社会", "start_year": 2010, "canon_note": "黑魔法的阴影并未完全消散，纯血主义的幽灵仍在游荡，新的魔法知识与麻瓜科技正在改变世界", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.1, "ministry_stability": 0.7, "corruption": 0.3, "pureblood_influence": 0.2, "muggle_relations": 0.6, "economy_index": 0.7, "secrecy_integrity": 0.9}},
	{"id": "custom", "label": "自定义时代", "start_year": null, "canon_note": "由玩家指定年份；系统据年份反查最近的原著锚点", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.2, "ministry_stability": 0.6, "corruption": 0.3, "pureblood_influence": 0.3, "muggle_relations": 0.5, "economy_index": 0.6, "secrecy_integrity": 0.8}}
]
```

创建 `data/bloodlines.json`（12 血统，第七章 + 第七十五章选项；`prejudice` 为第十章结构性偏见强度）：

```json
[
	{"id": "muggle_born", "label": "麻瓜出身", "magic_aptitude": true, "prejudice": 0.4, "wealth_tier": 0, "skill_bias": {"muggle_world": 2, "social": 1}, "default_flags": [], "risk": "", "note": "在麻瓜世界长到十一岁，缺少魔法社会人脉与背景"},
	{"id": "half_blood", "label": "混血巫师", "magic_aptitude": true, "prejudice": 0.2, "wealth_tier": 0, "skill_bias": {"social": 1}, "default_flags": [], "risk": "", "note": "许多最强大的巫师是混血"},
	{"id": "pureblood_cadet", "label": "纯血旁支", "magic_aptitude": true, "prejudice": 0.1, "wealth_tier": 1, "skill_bias": {"history_of_magic": 1}, "default_flags": [], "risk": "", "note": "拥有姓氏带来的便利，也背负家族期望与偏见"},
	{"id": "sacred_twenty_eight", "label": "神圣二十八族", "magic_aptitude": true, "prejudice": 0.05, "wealth_tier": 2, "skill_bias": {"history_of_magic": 2, "social": 1}, "default_flags": [], "risk": "", "note": "神圣二十八族只是英国的一部分"},
	{"id": "squib", "label": "哑炮", "magic_aptitude": false, "prejudice": 0.7, "wealth_tier": 0, "skill_bias": {"muggle_world": 2}, "default_flags": ["no_magic"], "risk": "", "note": "出生于巫师家庭但无法使用魔法；仍可看见魔法世界，从事非魔法工作"},
	{"id": "obscurial", "label": "默然者", "magic_aptitude": true, "prejudice": 0.6, "wealth_tier": -1, "skill_bias": {}, "default_flags": ["obscurial"], "risk": "极高：几乎总是无法活到成年，力量极不稳定", "note": "幼年压抑魔法能力而诞生的危险黑暗力量，不是职业而是被诅咒的状态"},
	{"id": "part_veela", "label": "混血媚娃", "magic_aptitude": true, "prejudice": 0.4, "wealth_tier": 0, "skill_bias": {"social": 2}, "default_flags": ["veela_heritage"], "risk": "", "note": "拥有特殊魅力，也面临严重偏见"},
	{"id": "werewolf", "label": "狼人", "magic_aptitude": true, "prejudice": 0.8, "wealth_tier": -1, "skill_bias": {"dada": 1}, "default_flags": ["werewolf", "registered_werewolf"], "risk": "月圆之夜无法自控，就业与登记法歧视", "note": "狼人不等于怪物"},
	{"id": "half_giant", "label": "半巨人", "magic_aptitude": true, "prejudice": 0.7, "wealth_tier": -1, "skill_bias": {"care_of_magical_creatures": 2}, "default_flags": ["giant_blood"], "risk": "体格显眼，难以隐藏身份", "note": "巨人被驱逐，半巨人同样受歧视"},
	{"id": "half_centaur", "label": "半马人", "magic_aptitude": true, "prejudice": 0.7, "wealth_tier": -1, "skill_bias": {"astronomy": 2, "divination": 1}, "default_flags": ["centaur_blood"], "risk": "马人被划为“野兽”，法律地位低下", "note": "马人语言部分人类无法理解"},
	{"id": "elf_bound", "label": "家养小精灵契约相关", "magic_aptitude": true, "prejudice": 0.9, "wealth_tier": -2, "skill_bias": {"household_magic": 3}, "default_flags": ["bound_contract"], "risk": "契约奴役，逃跑即被追捕", "note": "家养小精灵可能真心认同奴役，也可能渴望自由"},
	{"id": "custom", "label": "自定义", "magic_aptitude": true, "prejudice": 0.0, "wealth_tier": 0, "skill_bias": {}, "default_flags": [], "risk": "", "note": "玩家自定血统；不得与原著明确事实冲突"}
]
```

创建 `data/birth_identities.json`（11 项；`start_knuts` 为 11 岁起始个人财产，`4969` = 10加隆 1西可，用于自洽性测试）：

```json
[
	{"id": "ordinary_wizard_family", "label": "普通巫师家庭", "start_knuts": 4930, "skill_bias": {"charms": 1}, "contacts": 3, "note": "普通巫师家庭年收入约数百加隆"},
	{"id": "muggle_family", "label": "麻瓜家庭", "start_knuts": 1479, "skill_bias": {"muggle_world": 2}, "contacts": 0, "note": "对魔法一无所知，完全依赖学校与猫头鹰"},
	{"id": "orphan", "label": "孤儿", "start_knuts": 0, "skill_bias": {"stealth": 1, "social": 1}, "contacts": 0, "note": "无家庭资源，人脉靠自己建立"},
	{"id": "declined_pureblood", "label": "纯血没落家族", "start_knuts": 2465, "skill_bias": {"history_of_magic": 2}, "contacts": 4, "note": "姓氏仍在，财富已去，背负家族期望"},
	{"id": "noble_pureblood", "label": "纯血豪门", "start_knuts": 98600, "skill_bias": {"history_of_magic": 2, "social": 1}, "contacts": 8, "note": "巨额财产不代表可以无代价"},
	{"id": "ministry_official", "label": "魔法部官员家庭", "start_knuts": 19720, "skill_bias": {"social": 2, "history_of_magic": 1}, "contacts": 6, "note": "一封推荐信可以打开霍格沃茨董事会的大门"},
	{"id": "auror_family", "label": "傲罗家庭", "start_knuts": 12325, "skill_bias": {"dada": 2, "charms": 1}, "contacts": 5, "note": "傲罗是执法者，也是政治工具"},
	{"id": "professor_family", "label": "教授家庭", "start_knuts": 14790, "skill_bias": {"charms": 1, "transfiguration": 1, "history_of_magic": 1}, "contacts": 5, "note": "学术资源与人脉，社会地位稳固"},
	{"id": "goblin_contract", "label": "古灵阁妖精契约相关", "start_knuts": 7395, "skill_bias": {"ancient_runes": 2, "social": 1}, "contacts": 4, "note": "妖精与巫师的关系充满历史仇恨与契约陷阱"},
	{"id": "st_mungo_family", "label": "圣芒戈治疗师家庭", "start_knuts": 9860, "skill_bias": {"healing": 2, "potions": 1}, "contacts": 4, "note": "治疗师不是万能复活机，很多伤害无法完全治愈"},
	{"id": "custom", "label": "自定义", "start_knuts": 4930, "skill_bias": {}, "contacts": 2, "note": "玩家自定出生身份"}
]
```

创建 `data/aptitudes.json`（6 项；`failure_delta` 为失败率偏移，负值更擅长施法）：

```json
[
	{"id": "squib", "label": "哑炮无魔法天赋", "failure_delta": 1.0, "grants": [], "special_options": [], "note": "无法施展咒语，人生可转向麻瓜世界或非魔法工作"},
	{"id": "normal", "label": "普通", "failure_delta": 0.0, "grants": [], "special_options": [], "note": "标准巫师天赋"},
	{"id": "good", "label": "良好", "failure_delta": -0.05, "grants": [], "special_options": [], "note": "学习魔咒较顺手"},
	{"id": "excellent", "label": "优秀", "failure_delta": -0.10, "grants": [], "special_options": [], "note": "天赋突出，仍不是传奇"},
	{"id": "special", "label": "特殊", "failure_delta": -0.10, "grants": [], "special_options": ["metamorphmagus", "parselmouth", "seer", "transfiguration_talent", "occlumency_talent"], "note": "需指定具体天赋：易容马格斯/蛇佬腔/预言天分/变形天赋/大脑封闭术天赋"},
	{"id": "random", "label": "随机", "failure_delta": 0.0, "grants": [], "special_options": [], "note": "创建时由系统掷定资质"}
]
```

创建 `data/houses.json`（6 项，第四章 + 第二十四章「学院不是性格标签」）：

```json
[
	{"id": "system", "label": "系统判定", "traits": [], "note": "由系统根据血统、资质、性格关键词判定"},
	{"id": "gryffindor", "label": "格兰芬多", "traits": ["勇气", "胆识", "骑士精神"], "note": "学院不是性格标签，格兰芬多也可以是懦夫"},
	{"id": "slytherin", "label": "斯莱特林", "traits": ["野心", "血统", "精明", "意志"], "note": "斯莱特林也可以是英雄"},
	{"id": "ravenclaw", "label": "拉文克劳", "traits": ["智慧", "知识", "创造力", "好奇"], "note": "知识垄断带来政治权力"},
	{"id": "hufflepuff", "label": "赫奇帕奇", "traits": ["忠诚", "勤勉", "公平", "坚韧"], "note": "勤勉者构成魔法社会大多数"},
	{"id": "none", "label": "未入学/成年/其他学校", "traits": [], "note": "含布斯巴顿、德姆斯特朗、伊法魔尼等"}
]
```

创建 `data/sim_styles.json`（6 项；`event_intensity` 与 `mundane_ratio` 供第六十八章防过度热闹使用）：

```json
[
	{"id": "brutal_realism", "label": "极度现实", "event_intensity": 0.5, "mundane_ratio": 0.8, "note": "代价真实，失败常见"},
	{"id": "campus_adventure", "label": "经典校园冒险", "event_intensity": 0.6, "mundane_ratio": 0.7, "note": "霍格沃茨生活为主轴"},
	{"id": "epic_wizarding_war", "label": "史诗巫师战争", "event_intensity": 1.0, "mundane_ratio": 0.4, "note": "战争推进，但世界仍不会每月都是决战"},
	{"id": "dark_fantasy", "label": "黑暗奇幻", "event_intensity": 0.8, "mundane_ratio": 0.5, "note": "黑魔法与禁忌更常见"},
	{"id": "daily_life", "label": "日常人生", "event_intensity": 0.2, "mundane_ratio": 1.0, "note": "上课、做魔药、打魁地奇、喝黄油啤酒"},
	{"id": "mixed", "label": "混合模式", "event_intensity": 0.5, "mundane_ratio": 0.7, "note": "默认模式"}
]
```

创建 `data/political_leanings.json`（6 项）：

```json
[
	{"id": "blood_equality", "label": "血统平等", "pureblood_opinion": -1.0, "ministry_opinion": 0.2, "risk": "在纯血势力当权时可能被针对", "note": "推动麻瓜出身平权、狼人权益、家养小精灵解放"},
	{"id": "pureblood_conservative", "label": "纯血保守", "pureblood_opinion": 1.0, "ministry_opinion": 0.5, "risk": "战后公开表态可能招致调查", "note": "维护传统与血统秩序"},
	{"id": "neutral_opportunist", "label": "中立投机", "pureblood_opinion": 0.0, "ministry_opinion": 0.5, "risk": "两边都可做生意，两边都不信任你", "note": "商人式政治"},
	{"id": "order_of_phoenix", "label": "凤凰社支持", "pureblood_opinion": -0.5, "ministry_opinion": -0.3, "risk": "没有官方身份，以信任与牺牲维持运作", "note": "独立于魔法部的抵抗网络"},
	{"id": "death_eater_sympathy", "label": "食死徒同情", "pureblood_opinion": 0.8, "ministry_opinion": -0.8, "risk": "被傲罗追捕、被威森加摩审判", "note": "黑巫师有政治目标，不是无脑反派"},
	{"id": "free_independent", "label": "自由独立", "pureblood_opinion": 0.0, "ministry_opinion": 0.0, "risk": "没有靠山", "note": "不站队，靠本事吃饭"}
]
```

- [ ] **Step 5: 运行测试，确认通过**

```bash
cd /e/Hali
bash tools/test.sh
```

预期：`[registry] 断言=... 失败=0`、`ALL TESTS PASSED`、`全部通过。`

- [ ] **Step 6: 提交**

```bash
cd /e/Hali
git add src/core/registry.gd data/ tests/registry_test.gd tests/run_tests.gd
git commit -m "feat(content): 内容注册表与七张正典内容表"
```

---

