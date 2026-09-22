class_name Registry
extends RefCounted

const TABLE_FILES: Dictionary = {
	"eras": "eras.json",
	"factions": "factions.json",
	"governments": "governments.json",
	"bloodlines": "bloodlines.json",
	"birth_identities": "birth_identities.json",
	"aptitudes": "aptitudes.json",
	"houses": "houses.json",
	"sim_styles": "sim_styles.json",
	"political_leanings": "political_leanings.json",
	"locations": "locations.json",
	"rumors": "rumors.json",
	"political_events": "political_events.json",
	"skills": "skills.json",
	"wand_woods": "wand_woods.json",
	"wand_cores": "wand_cores.json",
	"wand_flexibilities": "wand_flexibilities.json",
	"wand_lengths": "wand_lengths.json",
	"spells": "spells.json",
	"goods": "goods.json",
	"industries": "industries.json",
	"jobs": "jobs.json",
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
			errors.append_array(_validate_entry(table_name, str(key), e))
	return errors

# 计划 03a：按表做字段级校验（枚举与引用完整性由 WorldFactions.validate_content 负责，
# 这里只保证「字段存在且类型/值域合法」，避免 registry 反向依赖 rules 层造成类循环）。
const _KINDS := ["ministry", "institution", "pureblood", "school", "commerce", "media",
	"resistance", "dark", "foreign", "society"]
const _LEGAL := ["legal", "shadow", "outlaw"]
const _SECRECY := ["public", "semi", "secret"]
const _INSTITUTIONS := ["law_enforcement", "auror_office", "wizengamot", "mysteries",
	"hogwarts", "gringotts", "daily_prophet", "international"]

# 计划 03b：经济内容表白名单。
# ⚠️ 必须与 Economy.CATEGORIES / Economy.KINDS 同步 —— registry 在 Economy 的上游，
#    反向 preload 会造成类循环，故此处写字面量，由 tests/registry_test.gd 的
#    「商品 category 枚举两处一致 / kind 枚举两处一致」断言钉死两处不漂移。
## ⚠️ `_GOODS_KINDS` 需与 `Economy.KINDS` 一致（一致性由 `registry_test` 断言钉死）；
## 其余四张数量表的白名单**在本文件内没有对应常量**（其枚举与 `Economy` 无共享来源），
## 故不在此处凑数 —— 见 tests/registry_test.gd 的「白名单 == 实测内容」断言。
const _GOODS_CATEGORIES := ["wand", "potion", "material", "broom", "book",
	"food", "service", "creature", "artifact", "illegal"]
const _GOODS_KINDS := ["goods", "service"]
# A-11：`_SCARCITY_MAX` 是 `Economy.MAX_SCARCITY` 的**镜像常量**。
# 为什么是镜像而不是引用：registry 处于 Economy 的**上游**（data → Registry → Economy），
#   preload 会造成循环依赖，所以两边各写一份字面量。
# 为什么不能只留一份：校验器要核「roundi(base × MAX_SCARCITY) 不得突破 canon_price_hi_knuts」，
#   它必须知道这个数。
# ⇒ 两处一致性由 `tests/registry_test.gd` 的显式断言钉死（不是靠注释自觉）。
# ⚠️ 历史上用「canon_lo × MAX/MIN 反推上界」的做法已废弃 —— 那条式子隐含
#   「一条商品 = 一个 canon 窗口且 base 就在下沿」，对 potion_healing_premium
#   （共享区间、base 取上段）会误判（spec §7.1 / §13 缺陷⑦）。
const _SCARCITY_MAX := 1.40

func _validate_entry(table_name: String, key: String, e: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var where := "%s/%s" % [table_name, key]
	if table_name == "factions":
		var kind := str(e.get("kind", ""))
		if not _KINDS.has(kind):
			errors.append("%s: kind 非法（%s）" % [where, kind])
		var legal := str(e.get("legal_status", ""))
		if not _LEGAL.has(legal):
			errors.append("%s: legal_status 非法（%s）" % [where, legal])
		var secrecy := str(e.get("secrecy", ""))
		if not _SECRECY.has(secrecy):
			errors.append("%s: secrecy 非法（%s）" % [where, secrecy])
		if not e.has("base_power"):
			errors.append("%s: 缺少 base_power" % where)
		elif float(e["base_power"]) < 0.0 or float(e["base_power"]) > 1.0:
			errors.append("%s: base_power 超值域（%s）" % [where, str(e["base_power"])])
		for field in ["institutions", "rivals", "allies"]:
			if not e.has(field):
				errors.append("%s: 缺少 %s" % [where, field])
			elif typeof(e[field]) != TYPE_ARRAY:
				errors.append("%s: %s 必须是数组" % [where, field])
		for inst in (e.get("institutions", []) as Array):
			if not _INSTITUTIONS.has(str(inst)):
				errors.append("%s: 机构非法（%s）" % [where, str(inst)])
	if table_name == "rumors":
		if e.has("reveals_faction") and typeof(e["reveals_faction"]) != TYPE_STRING:
			errors.append("%s: reveals_faction 必须是字符串" % where)
	if table_name == "governments":
		if str(e.get("summary", "")).is_empty():
			errors.append("%s: 缺少 summary" % where)
	if table_name == "political_events":
		if not ["politics", "economy", "law"].has(str(e.get("category", ""))):
			errors.append("%s: category 非法" % where)
		if str(e.get("text", "")).is_empty():
			errors.append("%s: 缺少 text" % where)
		if str(e.get("condition", "")).is_empty():
			errors.append("%s: 缺少 condition" % where)
	if table_name == "goods":
		errors.append_array(_validate_goods(where, e))
	if table_name == "industries":
		errors.append_array(_validate_industry(where, e))
	if table_name == "jobs":
		errors.append_array(_validate_job(where, e))
	return errors

# 计划 03b：商品字段与引用校验（C3/C6 的价格合理带在此落地）。
func _validate_goods(where: String, e: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var category := str(e.get("category", ""))
	if not _GOODS_CATEGORIES.has(category):
		errors.append("%s: category 非法（%s）" % [where, category])
	var kind := str(e.get("kind", ""))
	if not _GOODS_KINDS.has(kind):
		errors.append("%s: kind 非法（%s）" % [where, kind])
	var base := int(e.get("base_price_knuts", 0))
	if base <= 0:
		errors.append("%s: base_price_knuts 必须为正（%d）" % [where, base])
	var canon := int(e.get("canon_price_knuts", 0))
	if canon < 0:
		errors.append("%s: canon_price_knuts 不得为负（%d）" % [where, canon])
	if str(e.get("unit", "")).is_empty():
		errors.append("%s: 缺少 unit" % where)
	if kind == "goods":
		# ⚠️ 2026-09-21 缺陷⑨：`food_*`（黄油啤酒/南瓜馅饼）的 `industry_id` 由错误的
		# `publishing` 改为 `""`（无产业）—— 食物不是出版社的产物，这是原填充事故。
		# 故此处对**空 industry_id** 放行：它表示「无产业归属」，与 `svc_*` 服务行同款语义。
		# 非空时必须指向真实产业（引用完整性不变）。
		var iid := str(e.get("industry_id", ""))
		if not iid.is_empty() and not has("industries", iid):
			errors.append("%s: industry_id 不存在（%s）" % [where, iid])
	if canon > 0:
		if int(e.get("canon_line", 0)) <= 0:
			errors.append("%s: 锚点商品缺少 canon_line" % where)
		var hi := int(e.get("canon_price_hi_knuts", 0))
		if hi <= 0:
			errors.append("%s: 锚点商品缺少 canon_price_hi_knuts（正典区间上沿）" % where)
		else:
			# ① 常态价必须落在正典区间内（C6）
			if base < canon or base > hi:
				errors.append("%s: base_price_knuts 超出正典合理带 [%d, %d]（实际 %d）"
					% [where, canon, hi, base])
			# ② 危机峰价不得突破正典上沿（C3 —— 这才是契约本体）
			var peak := roundi(float(base) * _SCARCITY_MAX)
			if peak > hi:
				errors.append("%s: 危机峰价突破正典上沿（%d × %.2f = %d > %d）"
					% [where, base, _SCARCITY_MAX, peak, hi])
	return errors

# 计划 03b：产业字段与 produces 引用校验。
func _validate_industry(where: String, e: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not e.has("base_output"):
		errors.append("%s: 缺少 base_output" % where)
	else:
		var out := float(e["base_output"])
		if out < 0.0 or out > 1.0:
			errors.append("%s: base_output 超值域（%s）" % [where, str(e["base_output"])])
	if not e.has("monopoly"):
		errors.append("%s: 缺少 monopoly" % where)
	elif typeof(e["monopoly"]) != TYPE_BOOL:
		errors.append("%s: monopoly 必须是布尔" % where)
	if not e.has("produces"):
		errors.append("%s: 缺少 produces" % where)
	elif typeof(e["produces"]) != TYPE_ARRAY:
		errors.append("%s: produces 必须是数组" % where)
	else:
		for p in (e["produces"] as Array):
			if not has("goods", str(p)):
				errors.append("%s: produces 引用不存在的商品（%s）" % [where, str(p)])
	return errors

# 计划 03b Task 5：职业表字段校验（spec §7.6）。
# 量级锚点（硬下沿 + 硬上沿）：
#   下沿 2958 纳特（6 加隆）—— 正典 223 行「普通家庭年收入约数百加隆」⇒ 月收入 6–15 加隆。
#   上沿 9860 纳特（20 加隆）—— 正典 233 行「魁地奇也是商业」允许顶端破格。
#   ⚠️ 缺陷⑪（2026-09-21）订正：**两条都是硬约束**，校验器两条都查。
#     旧注释把上沿写成「只做下沿守卫、上沿由测试钉死」，与下面的 `wage > _JOB_WAGE_MAX`
#     分支自相矛盾，且会让人误以为上沿是软参考。
#   「仅 quidditch_pro 可达 9860、其余 8 条严格小于」这个**更细的口径**才由
#   tests/registry_test.gd 的显式断言钉死（校验器不该写死职业名）。
const _JOB_WAGE_MIN := 2958
const _JOB_WAGE_MAX := 9860

func _validate_job(where: String, e: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not e.has("wage_knuts"):
		errors.append("%s: 缺少 wage_knuts" % where)
		return errors
	var wage := int(e["wage_knuts"])
	if wage < _JOB_WAGE_MIN or wage > _JOB_WAGE_MAX:
		errors.append("%s: wage_knuts 超出量级锚点 [%d, %d]（实际 %d）"
			% [where, _JOB_WAGE_MIN, _JOB_WAGE_MAX, wage])
	if int(e.get("canon_line", 0)) <= 0:
		errors.append("%s: 职业行缺少 canon_line（正典 198 行职业清单）" % where)
	return errors
