### Task 1: 内容表 `factions` / `governments` + Registry 注册与字段校验

**Files:**
- Create: `data/factions.json`、`data/governments.json`、`src/rules/factions.gd`（本任务只放常量）
- Modify: `src/core/registry.gd`（`TABLE_FILES` + `validate()`）
- Test: `tests/registry_test.gd`

**Interfaces:**
- Consumes: 无（本任务是最底层内容）。
- Produces:
  - 表名 `"factions"` / `"governments"`，可用 `Registry.ids(...)` / `Registry.entry(...)` / `Registry.has(...)` 访问。
  - `WorldFactions.INSTITUTIONS: Array[String]`（8 个机构 id，**顺序即面板展示顺序**）
  - `WorldFactions.KINDS: Array[String]`、`WorldFactions.LEGAL_STATUS: Array[String]`、`WorldFactions.SECRECY: Array[String]`
  - `WorldFactions.TENSION_FLAG := "social_tension"`、`WorldFactions.GOVERNMENT_FLAG := "government_type"`
  - `WorldFactions.MINISTRY_ID := "ministry"`、`WorldFactions.RESISTANCE_ID := "order_of_phoenix"`
  - 派系条目字段契约（后续任务全部依赖）：`id, label, kind, aliases, legal_status, secrecy, domains, agenda, base_power, rivals, allies, institutions, era_overrides`
  - 政体条目字段契约：`id, label, summary, canon_line`

- [ ] **Step 1: 写失败测试**

在 `tests/registry_test.gd` 的 `run()` 末尾（`return a.report("registry")` 之前）追加：

```gdscript
	# ---- 计划 03a：派系与政体内容表 ----
	var factions := reg.ids("factions")
	a.eq(factions.size(), 17, "派系表 17 条")
	for fid in ["ministry", "auror_office", "wizengamot", "mysteries", "hogwarts",
			"sacred_twenty_eight", "reformist_pureblood", "death_eaters", "order_of_phoenix",
			"gringotts", "diagon_merchants", "daily_prophet", "black_market",
			"common_folk", "international_confederation", "continental_pureblood", "muggle_world"]:
		a.is_true(reg.has("factions", str(fid)), "派系 %s 存在" % str(fid))
	a.eq(reg.ids("governments").size(), 4, "政体表 4 条")

	# 枚举与引用完整性（后续 WorldFactions.validate_content 也要做同样的事，这里是内容表自检）
	var kinds := ["ministry", "institution", "pureblood", "school", "commerce", "media",
		"resistance", "dark", "foreign", "society"]
	var insts := ["law_enforcement", "auror_office", "wizengamot", "mysteries",
		"hogwarts", "gringotts", "daily_prophet", "international"]
	for fid in factions:
		var e := reg.entry("factions", str(fid))
		a.is_true(kinds.has(str(e.get("kind", ""))), "%s: kind 合法" % fid)
		a.is_true(["legal", "shadow", "outlaw"].has(str(e.get("legal_status", ""))), "%s: legal_status 合法" % fid)
		a.is_true(["public", "semi", "secret"].has(str(e.get("secrecy", ""))), "%s: secrecy 合法" % fid)
		a.between(float(e.get("base_power", -1.0)), 0.0, 1.0, "%s: base_power 在 0..1" % fid)
		a.is_true(not str(e.get("agenda", "")).is_empty(), "%s: 有 agenda" % fid)
		for inst in (e.get("institutions", []) as Array):
			a.is_true(insts.has(str(inst)), "%s: 机构 %s 合法" % [fid, str(inst)])
		for other in (e.get("rivals", []) as Array):
			a.is_true(reg.has("factions", str(other)), "%s: rival %s 存在" % [fid, str(other)])
		for other in (e.get("allies", []) as Array):
			a.is_true(reg.has("factions", str(other)), "%s: ally %s 存在" % [fid, str(other)])
		var overrides = e.get("era_overrides", {})
		if typeof(overrides) == TYPE_DICTIONARY:
			for era_id in (overrides as Dictionary).keys():
				a.is_true(reg.has("eras", str(era_id)), "%s: era_overrides 的 %s 是真时代" % [fid, str(era_id)])

	# 校验器必须抓到坏派系内容
	var bad := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"factions": [{"id": "x", "label": "坏派系", "kind": "bogus", "legal_status": "legal",
			"secrecy": "public", "base_power": 0.5}],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	var bad_joined := " | ".join(bad.validate())
	a.is_true(bad_joined.contains("kind 非法"), "坏 kind 必须报错")
	a.is_true(bad_joined.contains("缺少数据表"), "缺失数据表仍需报错")
	var bad_power := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"factions": [{"id": "x", "label": "坏派系", "kind": "dark", "legal_status": "legal",
			"secrecy": "public", "base_power": 1.5}],
		"governments": [{"id": "g", "label": "政体", "summary": "说明"}],
	})
	a.is_true(" | ".join(bad_power.validate()).contains("base_power 超值域"), "base_power 越界必须报错")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[registry\]|总计"`
Expected: `[registry] 断言=... 失败=N`（N > 0），缺失 `factions`/`governments` 表报「缺少数据表」。

- [ ] **Step 3: 实现**

新建 `src/rules/factions.gd`（**本任务只放常量，函数在 Task 2 加**）：

```gdscript
class_name WorldFactions
extends RefCounted

# 机构 id 枚举：顺序即势力面板的展示顺序（第六十五章）。代码只硬编码 id，中文标签进 data/factions.json 的 institutions。
const INSTITUTIONS: Array[String] = ["law_enforcement", "auror_office", "wizengamot", "mysteries",
	"hogwarts", "gringotts", "daily_prophet", "international"]

# 派系类别枚举（第十二章权力四角 + 第六/二十六章）
const KINDS: Array[String] = ["ministry", "institution", "pureblood", "school", "commerce",
	"media", "resistance", "dark", "foreign", "society"]
const LEGAL_STATUS: Array[String] = ["legal", "shadow", "outlaw"]
const SECRECY: Array[String] = ["public", "semi", "secret"]

# kind → 权力四角（第十二章）。不在表里的 kind（resistance/dark/foreign/society）不进四角，
# 它们通过 control 与政体判定体现影响力。
const CORNERS: Dictionary = {
	"ministry": ["ministry", "institution"],
	"pureblood": ["pureblood"],
	"hogwarts": ["school"],
	"commerce": ["commerce", "media"],
}

const MINISTRY_ID := "ministry"
const RESISTANCE_ID := "order_of_phoenix"

# 状态键（都存在既有容器里：tension 进 world.flags，政体进 world.flags，派系状态进 world.factions）
const TENSION_FLAG := "social_tension"
const GOVERNMENT_FLAG := "government_type"
```

新建 `data/factions.json`（17 条，**逐字段照下面的表填**；`aliases` 用于第 Task 9 的关键词识别；`agenda` 是一句中文目标，供叙事与提示词使用）：

| id | label | kind | legal_status | secrecy | institutions | base_power | rivals | allies | era_overrides（只给这 6 个派系） |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `ministry` | 魔法部 | ministry | legal | public | law_enforcement | 0.75 | death_eaters | auror_office, wizengamot, international_confederation | witch_hunts 0.30；hogwarts_founding 0.20；grindelwald 0.65；first_wizarding_war 0.55；second_wizarding_war 0.45 |
| `auror_office` | 傲罗指挥部 | institution | legal | public | auror_office | 0.60 | death_eaters | ministry | — |
| `wizengamot` | 威森加摩 | institution | legal | public | wizengamot | 0.58 | death_eaters | ministry, sacred_twenty_eight | — |
| `mysteries` | 神秘事务司 | institution | legal | semi | mysteries | 0.40 | death_eaters | ministry | — |
| `hogwarts` | 霍格沃茨 | school | legal | public | hogwarts | 0.65 | death_eaters | order_of_phoenix, common_folk | hogwarts_founding 0.80；witch_hunts 0.40 |
| `sacred_twenty_eight` | 神圣二十八族 | pureblood | legal | semi | wizengamot | 0.55 | reformist_pureblood, common_folk | wizengamot, continental_pureblood | second_wizarding_war 0.60 |
| `reformist_pureblood` | 改革派纯血 | pureblood | legal | public | （空数组） | 0.35 | sacred_twenty_eight | common_folk, hogwarts | — |
| `death_eaters` | 食死徒 | dark | outlaw | secret | law_enforcement, wizengamot | 0.05 | ministry, auror_office, order_of_phoenix, hogwarts | （空数组） | hogwarts_founding 0.0；witch_hunts 0.0；grindelwald 0.05；first_wizarding_war 0.35；second_wizarding_war 0.45；reconstruction 0.10 |
| `order_of_phoenix` | 凤凰社 | resistance | shadow | secret | （空数组） | 0.10 | death_eaters | hogwarts, reformist_pureblood | hogwarts_founding 0.0；witch_hunts 0.0；grindelwald 0.15；first_wizarding_war 0.25；second_wizarding_war 0.30；reconstruction 0.15 |
| `gringotts` | 古灵阁 | commerce | legal | public | gringotts | 0.60 | （空数组） | （空数组） | — |
| `diagon_merchants` | 对角巷商会 | commerce | legal | public | （空数组） | 0.35 | black_market | gringotts | — |
| `daily_prophet` | 预言家日报 | media | legal | public | daily_prophet | 0.45 | （空数组） | ministry | — |
| `black_market` | 翻倒巷黑市 | commerce | outlaw | semi | （空数组） | 0.25 | auror_office | death_eaters | — |
| `common_folk` | 普通巫师大众 | society | legal | public | （空数组） | 0.45 | （空数组） | hogwarts, reformist_pureblood | — |
| `international_confederation` | 国际巫师联合会 | foreign | legal | public | international | 0.55 | continental_pureblood | ministry | witch_hunts 0.35；hogwarts_founding 0.25；grindelwald 0.60 |
| `continental_pureblood` | 欧陆纯血网络 | foreign | legal | semi | （空数组） | 0.40 | international_confederation | sacred_twenty_eight | — |
| `muggle_world` | 麻瓜世界 | foreign | legal | public | （空数组） | 0.30 | （空数组） | common_folk | witch_hunts 0.55；grindelwald 0.45；second_wizarding_war 0.45 |

两条**完整示例**（其余按上表照填，`domains` 从 `["law","administration","education","economy","media","secrecy_enforcement","warfare","intelligence"]` 里按语义各取 1–3 个）：

```json
{
  "id": "ministry",
  "label": "魔法部",
  "kind": "ministry",
  "aliases": ["魔法部", "部里", "部长"],
  "legal_status": "legal",
  "secrecy": "public",
  "domains": ["law", "administration", "secrecy_enforcement"],
  "agenda": "维持保密法与巫师社会秩序，压住战争、丑闻与恐慌",
  "base_power": 0.75,
  "rivals": ["death_eaters"],
  "allies": ["auror_office", "wizengamot", "international_confederation"],
  "institutions": ["law_enforcement"],
  "era_overrides": {
    "witch_hunts": {"base_power": 0.30},
    "hogwarts_founding": {"base_power": 0.20},
    "grindelwald": {"base_power": 0.65},
    "first_wizarding_war": {"base_power": 0.55},
    "second_wizarding_war": {"base_power": 0.45}
  }
}
```

```json
{
  "id": "death_eaters",
  "label": "食死徒",
  "kind": "dark",
  "aliases": ["食死徒", "黑魔标记", "神秘人", "那个人"],
  "legal_status": "outlaw",
  "secrecy": "secret",
  "domains": ["warfare", "intelligence", "law"],
  "agenda": "以恐怖与纯血主义清洗魔法社会，把法律变成压迫工具",
  "base_power": 0.05,
  "rivals": ["ministry", "auror_office", "order_of_phoenix", "hogwarts"],
  "allies": [],
  "institutions": ["law_enforcement", "wizengamot"],
  "era_overrides": {
    "hogwarts_founding": {"base_power": 0.0},
    "witch_hunts": {"base_power": 0.0},
    "grindelwald": {"base_power": 0.05},
    "first_wizarding_war": {"base_power": 0.35},
    "second_wizarding_war": {"base_power": 0.45},
    "reconstruction": {"base_power": 0.10}
  }
}
```

新建 `data/governments.json`（`canon_line` 是 `哈利·波特·魔法纪元.md` 的行号）：

```json
[
  {"id": "ministry_bureaucracy", "label": "魔法部官僚制", "canon_line": 160,
   "summary": "部长、司长、办公室主任、傲罗指挥部、威森加摩；法律与行政结合。优点是组织稳定，缺点是官僚主义、腐败、低效与政治妥协。"},
  {"id": "pureblood_oligarchy", "label": "纯血寡头制", "canon_line": 162,
   "summary": "古老家族通过财富、联姻、威森加摩席位和魔法部游说控制决策；纯血家族之间既有合作也有斗争。"},
  {"id": "death_eater_dictatorship", "label": "食死徒独裁", "canon_line": 164,
   "summary": "黑巫师通过恐怖、夺魂咒与纯血主义清洗夺取政权；法律成为压迫工具，反对者被投入阿兹卡班或消失。"},
  {"id": "order_resistance", "label": "凤凰社抵抗组织", "canon_line": 166,
   "summary": "不是合法政府，而是由不同出身、不同立场巫师组成的秘密抵抗网络；以信任、情报和牺牲维持运作，战争时期可能成为影子政府。"}
]
```

修改 `src/core/registry.gd`：

1) `TABLE_FILES` 增加两行（放在 `"eras"` 之后，顺序不影响行为）：

```gdscript
	"factions": "factions.json",
	"governments": "governments.json",
```

2) 把 `validate()` 里的「每条都要有 label」逻辑替换为按表校验：

```gdscript
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
	if table_name == "governments":
		if str(e.get("summary", "")).is_empty():
			errors.append("%s: 缺少 summary" % where)
	return errors
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | tail -20`
Expected: `[registry] 断言=... 失败=0`，`全部通过。`，`EXIT=0`。

- [ ] **Step 5: 提交**

```bash
git add data/factions.json data/governments.json src/rules/factions.gd src/rules/factions.gd.uid src/core/registry.gd tests/registry_test.gd
git commit -m "feat(data): 派系与政体内容表 + Registry 注册与字段校验（计划 03a Task 1）"
```

---

