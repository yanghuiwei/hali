# 计划 03a · 派系与政治骨架 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现本计划。步骤用 `- [ ]` 复选框跟踪。
> Spec：`docs/superpowers/specs/2026-09-20-hp-magic-era-03-factions-design.md`（已通过用户评审，2026-09-20）。
> 分支：`plan-03-factions`（从 `main`@`685af4b`）。计划日期：2026-09-20。

**Goal:** 把「势力」从占位符（空的 `WorldState.factions`、无内容表的 `player.faction_id`、「待定/未知」的势力面板）变成可玩系统：派系内容表 → 机构控制权 → 权力四角 → 政体推导 → 月度演化 → 社会矛盾与政治事件 → 玩家所属/立场/加入 → 势力面板落地 → 信息保护。

**Architecture:** 新增 `src/rules/factions.gd`（`class_name WorldFactions`，静态函数，纯规则层）承载全部派系逻辑；状态存在**已存在的** `WorldState.factions` 字典里（存档格式不变），玩家侧只新增 `PlayerState.standing`；`tick()` 只**追加**一个演化阶段（既有五步语义与顺序不动）；三个新 op 走既有 `StateOps` 唯一入口；面板与提示词只读。

**Tech Stack:** Godot 4.7.2 stable（非 .NET）、纯 GDScript、无第三方依赖、不联网；测试入口 `bash tools/test.sh`（4 步：导入 → 单测 → 默认冒烟 → 调试镜像冒烟）。

## Global Constraints

以下约束对**每个任务**都生效，不再逐条重复：

- 引擎固定 **Godot 4.7.2 stable / Windows 64-bit / 非 .NET**；只写 GDScript；不引入第三方插件、外部素材、网络依赖。
- **内容一律进 `data/*.json`**，代码不硬编码内容（派系名、政体名、事件文案都是内容）。代码里只允许硬编码**枚举与实体 id**（`ministry` 等）。
- `to_dict()` 只放 JSON 原生类型（Dictionary / Array / String / int / float / bool / null），且整体过 `JsonUtil.normalize()`（否则 `{"n":493} != {"n":493.0}`，存读档往返断言必挂）。
- **新增测试套件必须把路径追加到 `tests/run_tests.gd` 的 `SUITES`**，否则不会被执行。
- **新脚本连 `.gd.uid` 一起 `git add`**（Godot 4.4+ 用 `.uid` 锁定脚本标识）。
- **提交前必须有绿灯**：`bash tools/test.sh` 必须 `EXIT=0`，报告里贴原始输出（含每套件断言数）。
- 正典优先：`哈利·波特·魔法纪元.md` 与本计划冲突时**改计划**，并在报告里写明依据行号。
- 随机数一律走 `RngService` 命名流，禁止 `randf()`/`randi()` 裸调用。
- 子代理与主会话同模型：`pi -p --provider deepseek --model deepseek-flash ...`；审查者只读（`pi -p --tools read,bash`）。
- 不要并发跑两个 headless 实例（会争 `.godot` 缓存）；卡住时 `tasklist | grep -i godot` + `taskkill //PID <PID> //F`。
- 每完成一个任务：brief → 实现 → 自跑绿灯 → **先写报告文件再返回** → 只读 reviewer 审 diff → 台账 `docs/sdd/plan-03a-factions/progress.md` → 把 brief/report/review/审查包复制进 `docs/sdd/plan-03a-factions/` 与代码同一次提交。

## 文件结构（先锁边界，再拆任务）

| 文件 | 状态 | 职责 |
| --- | --- | --- |
| `data/factions.json` | 新建（Task 1） | 17 个派系的内容（schema 见 Task 1 Step 3） |
| `data/governments.json` | 新建（Task 1） | 第十一章四大政体（id/label/summary/canon_line） |
| `src/rules/factions.gd` | 新建（Task 1 只放常量；Task 2+ 加函数） | 派系规则层：常量、初始化、控制权、权力四角、政体、演化、揭示 |
| `src/core/registry.gd` | 改（Task 1） | 注册两新表 + 按表校验字段 |
| `src/model/player_state.gd` | 改（Task 3） | `standing` 字段 + 存取 |
| `src/persist/save_codec.gd` | 改（Task 3） | `standing` 类型校验清单 |
| `src/rules/state_ops.gd` | 改（Task 3） | 三个新 op |
| `src/gm/op_guard.gd` | 改（Task 3） | 三个新 op 的净化/钳制 |
| `src/model/world_state.gd` | 改（Task 2 补 `initialize` 调用点；Task 5 加 tick 阶段） | 唯一时间推进入口 |
| `data/rumors.json` | 改（Task 6） | 派系相关传闻 + `weight` 生效所需字段 |
| `src/ui/panel_formatter.gd` | 改（Task 7） | `power_panel()` 重写（第六十五章 + 【已知势力】） |
| `src/gm/prompt_builder.gd` | 改（Task 8） | `state_digest` 加 revealed 派系摘要 |
| `src/gm/scripted_game_master.gd` | 改（Task 9） | 派系关键词 → 新 op（离线替身也要能用） |
| `src/ui/main.gd` | 改（Task 2 内容校验提示、Task 10 UI 韧性） | 主界面 |
| `src/gm/llm_game_master.gd`、`src/gm/providers/openai_compat_provider.gd` | 改（Task 10/11） | 顺手项：降级原因、provider 复用 |
| `src/ui/debug_mirror.gd` | 不改 | 观测通道（B1 已交付） |
| `tests/factions_test.gd` | 新建（Task 2） | 派系规则/演化/政体（必须进 `SUITES`） |
| `tests/registry_test.gd`、`tests/panel_test.gd`、`tests/save_test.gd`、`tests/gm_test.gd`、`tests/llm_test.gd`、`tests/creation_test.gd`、`tests/selfcheck_test.gd` | 改 | 各任务自带断言 |
| `tools/b1_acceptance.gd` | 改（Task 13） | 补派系面板的验收断言 |
| `docs/sdd/plan-03a-factions/` | 新建（Task 13 及每任务追加） | 耐久台账/简报/报告/审查包 |
| `README.md`、`HANDOFF.md`、`NEXT-STEPS.md` | 改（Task 13） | 收尾 |

**依赖方向（单向，禁止反向）：** `data/` → `Registry` → `WorldFactions` → `WorldState.tick()` / `StateOps` / `PanelFormatter` / `PromptBuilder`。`WorldFactions` **不得** `preload` 任何 `src/ui/` 或 `src/gm/` 脚本。

---

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

### Task 2: `WorldFactions` 规则层（初始化 / 机构控制权 / 权力四角 / 政体推导）

**Files:**
- Modify: `src/rules/factions.gd`（加函数）、`src/model/world_state.gd`（`create()`/`from_dict()` 调 `initialize`）、`src/ui/main.gd`（把 `validate_content` 的错误也打进 `push_warning`）
- Test: `tests/factions_test.gd`（新建，必须加进 `SUITES`）、`tests/registry_test.gd`（引用完整性交叉检查）

**Interfaces:**
- Consumes: Task 1 的常量与内容表；`Registry.ids/entry/has`；`WorldState.registry/era_id/clock/factions/flags/world_vars`。
- Produces（后续任务全部依赖这些签名，**不得改名**）：
  - `static func validate_content(registry: Registry) -> PackedStringArray`
  - `static func initialize(world: WorldState) -> void`（幂等）
  - `static func ensure_state(world: WorldState, faction_id: String) -> Dictionary`
  - `static func state_of(world: WorldState, faction_id: String) -> Dictionary`
  - `static func base_power(world: WorldState, faction_id: String) -> float`
  - `static func power_of(world: WorldState, faction_id: String) -> float`
  - `static func power_share(world: WorldState) -> Dictionary`（4 键，和为 1）
  - `static func institution_control(world: WorldState) -> Dictionary`（`{inst: {"value": float, "holder": String}}`）
  - `static func government_type(world: WorldState) -> String`

- [ ] **Step 1: 写失败测试**

新建 `tests/factions_test.gd`：

```gdscript
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

	# 时代覆盖
	var old := make_world("second_wizarding_war")
	WorldFactions.initialize(old)
	a.near(WorldFactions.base_power(old, "ministry"), 0.45, 0.0001, "二战期魔法部 base_power 被覆盖")
	a.near(WorldFactions.base_power(old, "death_eaters"), 0.45, 0.0001, "二战期食死徒 base_power 被覆盖")

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

	return a.report("factions")
```

同时：
1) 在 `tests/run_tests.gd` 的 `SUITES` 末尾追加 `"res://tests/factions_test.gd",`
2) 在 `tests/registry_test.gd` 末尾追加一条与 `WorldFactions` 常量的一致性断言（防两处枚举漂移）：

```gdscript
	# registry 的表内枚举与 WorldFactions 常量必须一致（防两处定义漂移）
	a.eq(insts, WorldFactions.INSTITUTIONS, "机构枚举两处一致")
	a.eq(kinds, WorldFactions.KINDS, "kind 枚举两处一致")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|缺少测试套件|总计"`
Expected: `[factions]` 套件报错（`WorldFactions.initialize` 等未定义 → 套件未调用 `report`，运行器判失败）。

- [ ] **Step 3: 实现**

在 `src/rules/factions.gd` 追加（常量之后）：

```gdscript
# ---------- 内容校验（枚举 + 引用完整性；registry.validate 只管字段与值域，避免反向依赖） ----------

static func validate_content(registry: Registry) -> PackedStringArray:
	var errors := PackedStringArray()
	for fid in registry.ids("factions"):
		var id := str(fid)
		var e := registry.entry("factions", id)
		for inst in (e.get("institutions", []) as Array):
			if not INSTITUTIONS.has(str(inst)):
				errors.append("factions/%s: 机构非法（%s）" % [id, str(inst)])
		for field in ["rivals", "allies"]:
			for other in (e.get(field, []) as Array):
				if not registry.has("factions", str(other)):
					errors.append("factions/%s: %s 引用不存在的派系（%s）" % [id, field, str(other)])
		var overrides = e.get("era_overrides", {})
		if typeof(overrides) == TYPE_DICTIONARY:
			for era_id in (overrides as Dictionary).keys():
				if not registry.has("eras", str(era_id)):
					errors.append("factions/%s: era_overrides 引用不存在的时代（%s）" % [id, str(era_id)])
	return errors

# ---------- 初始化与读取 ----------

# 幂等：只为「还没有状态」的派系建状态；旧存档/已演化的值一律不动。
static func initialize(world: WorldState) -> void:
	if world == null or world.registry == null:
		return
	if typeof(world.factions) != TYPE_DICTIONARY:
		world.factions = {}
	for fid in world.registry.ids("factions"):
		ensure_state(world, str(fid))

static func entry_of(world: WorldState, faction_id: String) -> Dictionary:
	return world.registry.entry("factions", faction_id)

static func base_power(world: WorldState, faction_id: String) -> float:
	var entry := entry_of(world, faction_id)
	var p := float(entry.get("base_power", 0.0))
	var overrides = entry.get("era_overrides", {})
	if typeof(overrides) == TYPE_DICTIONARY and (overrides as Dictionary).has(world.era_id):
		var o = (overrides as Dictionary)[world.era_id]
		if typeof(o) == TYPE_DICTIONARY and (o as Dictionary).has("base_power"):
			p = float((o as Dictionary)["base_power"])
	return clampf(p, 0.0, 1.0)

static func ensure_state(world: WorldState, faction_id: String) -> Dictionary:
	if typeof(world.factions) != TYPE_DICTIONARY:
		world.factions = {}
	var existing = world.factions.get(faction_id, null)
	if typeof(existing) == TYPE_DICTIONARY:
		return existing
	var entry := entry_of(world, faction_id)
	if entry.is_empty():
		return {}
	var power := base_power(world, faction_id)
	var control := {}
	for inst in (entry.get("institutions", []) as Array):
		control[str(inst)] = power
	var st := {
		"power": power,
		"control": control,
		"stance_to_player": 0,
		"revealed": str(entry.get("secrecy", "public")) == "public",
		"last_change_turn": world.clock.turn,
		"notes": [],
	}
	world.factions[faction_id] = st
	return st

static func state_of(world: WorldState, faction_id: String) -> Dictionary:
	if typeof(world.factions) != TYPE_DICTIONARY:
		return {}
	var st = world.factions.get(faction_id, null)
	return st if typeof(st) == TYPE_DICTIONARY else {}

static func power_of(world: WorldState, faction_id: String) -> float:
	return clampf(float(state_of(world, faction_id).get("power", 0.0)), 0.0, 1.0)

# ---------- 权力四角（第十二章） ----------

static func power_share(world: WorldState) -> Dictionary:
	var totals := {"ministry": 0.0, "pureblood": 0.0, "hogwarts": 0.0, "commerce": 0.0}
	for fid in world.registry.ids("factions"):
		var kind := str(entry_of(world, str(fid)).get("kind", ""))
		for corner in CORNERS.keys():
			if (CORNERS[corner] as Array).has(kind):
				totals[corner] = float(totals[corner]) + power_of(world, str(fid))
	var sum := 0.0
	for key in totals.keys():
		sum += float(totals[key])
	if sum <= 0.0:
		return {"ministry": 0.25, "pureblood": 0.25, "hogwarts": 0.25, "commerce": 0.25}
	var out := {}
	for key in totals.keys():
		out[key] = float(totals[key]) / sum
	return out

# ---------- 机构控制权（第二十六章） ----------

static func institution_control(world: WorldState) -> Dictionary:
	var out := {}
	for inst in INSTITUTIONS:
		out[inst] = {"value": 0.0, "holder": ""}
	for fid in world.registry.ids("factions"):
		var id := str(fid)
		var control = state_of(world, id).get("control", {})
		if typeof(control) != TYPE_DICTIONARY:
			continue
		for inst in (control as Dictionary).keys():
			if not out.has(str(inst)):
				continue
			var value := clampf(float((control as Dictionary)[inst]), 0.0, 1.0)
			var current: Dictionary = out[str(inst)]
			var better := value > float(current["value"])
			if is_equal_approx(value, float(current["value"])):
				better = power_of(world, id) > power_of(world, str(current["holder"]))
			if better:
				out[str(inst)] = {"value": value, "holder": id}
	return out

# ---------- 政体推导（第十一章 + 第十二章） ----------

static func government_type(world: WorldState) -> String:
	var ic := institution_control(world)
	var law := float((ic["law_enforcement"] as Dictionary)["value"])
	var wiz := float((ic["wizengamot"] as Dictionary)["value"])
	# 1) 凤凰社抵抗：战争压力高 + 抵抗组织强于魔法部（第十一章第 4 条）
	if float(world.world_vars.get("war_pressure", 0.0)) >= 0.6 \
			and power_of(world, RESISTANCE_ID) > power_of(world, MINISTRY_ID):
		return "order_resistance"
	# 2) 食死徒独裁：黑暗势力掌握执法与司法（第十一章第 3 条）
	var dark_sum := 0.0
	var dark_count := 0
	for fid in world.registry.ids("factions"):
		var id := str(fid)
		if str(entry_of(world, id).get("kind", "")) != "dark":
			continue
		var control: Dictionary = state_of(world, id).get("control", {})
		for inst in ["law_enforcement", "wizengamot"]:
			dark_sum += clampf(float(control.get(inst, law if inst == "law_enforcement" else wiz)), 0.0, 1.0)
			dark_count += 1
	if dark_count > 0 and (dark_sum / float(dark_count)) >= 0.6:
		return "death_eater_dictatorship"
	# 3) 纯血寡头：纯血权重高 + 魔法部弱（第十一章第 2 条）
	if float(power_share(world).get("pureblood", 0.0)) >= 0.28 and power_of(world, MINISTRY_ID) < 0.5:
		return "pureblood_oligarchy"
	# 4) 默认：官僚制（第十一章第 1 条）
	return "ministry_bureaucracy"
```

修改 `src/model/world_state.gd`：

1) `create()` 的 `return w` 之前插入：

```gdscript
	WorldFactions.initialize(w)
```

2) `from_dict()` 的 `return w` 之前插入：

```gdscript
	# 老存档（无 factions 或只有部分）在此补齐；幂等，不覆盖已存档的值（设计 §9.3/§9.5）
	WorldFactions.initialize(w)
```

修改 `src/ui/main.gd` 的 `_ready()`：

```gdscript
	var errors := registry.validate()
	errors.append_array(WorldFactions.validate_content(registry))
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[registry\]|^\[save\]|总计|全部通过"`
Expected: `[factions] 断言=... 失败=0`；其余套件失败=0；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/rules/factions.gd src/model/world_state.gd src/ui/main.gd tests/factions_test.gd tests/factions_test.gd.uid tests/registry_test.gd tests/run_tests.gd
git commit -m "feat(factions): WorldFactions 规则层（初始化/控制权/权力四角/政体推导）（计划 03a Task 2）"
```

---

### Task 3: 玩家派系接口（`standing` + 三个 op + OpGuard + 存档校验）

**Files:**
- Modify: `src/model/player_state.gd`、`src/rules/state_ops.gd`、`src/gm/op_guard.gd`、`src/persist/save_codec.gd`
- Test: `tests/factions_test.gd`（追加）、`tests/save_test.gd`（追加）、`tests/gm_test.gd`（追加）、`tests/llm_test.gd`（追加）

**Interfaces:**
- Consumes: Task 2 的 `WorldFactions.state_of` / `initialize`；既有 `StateOps.apply(world, ops) -> PackedStringArray`。
- Produces:
  - `PlayerState.standing: Dictionary`（`faction_id -> int(-100..100)`）
  - `PlayerState.standing_of(faction_id: String) -> int`
  - `PlayerState.add_standing(faction_id: String, delta: int) -> int`（返回钳制后的新值）
  - op `join_faction` / `leave_faction` / `faction_standing_delta`（载荷见 spec §7.3）
  - `OpGuard.MAX_STANDING_DELTA := 20`
  - `world.flags["illegal_affiliation"]`（加入 outlaw 派系时写入派系 id）

- [ ] **Step 1: 写失败测试**

`tests/factions_test.gd` 的 `run()` 末尾（`return a.report` 之前）追加：

```gdscript
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
```

并在 `tests/save_test.gd` 的 `run()` 末尾（`return a.report("save")` 之前）追加：

```gdscript
	# ---- 计划 03a：standing 与 factions 必须往返一致 ----
	w.player.faction_id = "ministry"
	w.player.add_standing("ministry", 42)
	w.flags["government_type"] = "ministry_bureaucracy"
	var f_text := SaveCodec.encode(w)
	var f_back := SaveCodec.decode(f_text, reg)
	a.is_true(bool(f_back["ok"]), "含 standing 的存档可解码")
	var f_world: WorldState = f_back["world"]
	a.eq(f_world.player.faction_id, "ministry", "faction_id 往返一致")
	a.eq(f_world.player.standing_of("ministry"), 42, "standing 往返一致")
	a.eq(f_world.flags.get("government_type", ""), "ministry_bureaucracy", "政体缓存往返一致")
	a.eq(f_world.factions.size(), 17, "factions 往返一致（17 条）")
```

在 `tests/gm_test.gd` 的 `run()` 末尾（`return a.report("gm")` 之前）追加：

```gdscript
	# ---- 计划 03a：派系 op 的守卫与端到端 ----
	var fe := StateOps.apply(w, [{"op": "join_faction", "faction_id": "nope"}])
	a.is_true(" | ".join(fe).contains("未知派系"), "join_faction 未知 id 被拒")
	a.eq(w.player.faction_id, "", "被拒的加入不写状态")
	var fe2 := StateOps.apply(w, [{"op": "join_faction", "faction_id": "death_eaters"}])
	a.is_true(" | ".join(fe2).contains("未揭示"), "未揭示的派系不能加入（第四十三/五十七章）")
	var fe3 := StateOps.apply(w, [{"op": "join_faction", "faction_id": "ministry"}])
	a.eq(fe3.size(), 0, "加入公开派系无错误")
	a.eq(w.player.faction_id, "ministry", "所属写入")
	var fe4 := StateOps.apply(w, [{"op": "faction_standing_delta", "faction_id": "ministry", "delta": 5}])
	a.eq(fe4.size(), 0, "立场调整无错误")
	a.eq(w.player.standing_of("ministry"), 5, "立场累加")
	a.is_true(int(WorldFactions.state_of(w, "ministry").get("stance_to_player", 0)) > 0, "派系态度反向变化")
```

在 `tests/llm_test.gd` 的 OpGuard 用例区（`var gres := OpGuard.sanitize_detailed(gworld, [...])` 之后）追加：

```gdscript
	# ---- 计划 03a：OpGuard 只允许 LLM 动 membership/standing，不允许任何 set_faction_* ----
	var fguard := OpGuard.sanitize_detailed(gworld, [
		{"op": "join_faction", "faction_id": "ministry"},
		{"op": "faction_standing_delta", "faction_id": "ministry", "delta": 999},
		{"op": "set_faction_power", "faction_id": "ministry", "power": 1.0},
	])
	a.eq(fguard.ops[0]["op"], "join_faction", "join_faction 进入净化结果")
	a.eq(int(fguard.ops[1]["delta"]), OpGuard.MAX_STANDING_DELTA, "standing 增量被钳到上限")
	var faction_kinds := ""
	for o in fguard.ops:
		faction_kinds += str(o.get("op", "")) + ","
	a.is_true(faction_kinds.contains("set_faction_power"), "未知 set_faction_* 透传给 StateOps 拒绝，不静默丢弃")
	a.is_true(" | ".join(StateOps.apply(gworld, fguard.ops)).contains("未知操作"),
		"StateOps 最终拒绝 set_faction_power")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[save\]|^\[llm\]|总计"`
Expected: 上述断言出现失败（`join_faction` 未知 → `StateOps` 报「未知操作」）。

- [ ] **Step 3: 实现**

`src/model/player_state.gd`：

1) 字段区（`var faction_id: String = ""` 之后）加：

```gdscript
var standing: Dictionary = {}      # 计划 03a：faction_id -> 玩家立场/声望 -100..100
```

2) `to_dict()` 里 `"relations": relations, "faction_id": faction_id,` 改为：

```gdscript
		"relations": relations, "faction_id": faction_id, "standing": standing,
```

3) `from_dict()` 里 `p.faction_id = str(d.get("faction_id", ""))` 之后加：

```gdscript
	p.standing = JsonUtil.normalize(d.get("standing", {}))
```

4) 新方法（放在 `faction_id` 相关逻辑附近，例如 `knows_spell` 之前）：

```gdscript
const STANDING_MIN := -100
const STANDING_MAX := 100

func standing_of(faction_id: String) -> int:
	return clampi(int(standing.get(faction_id, 0)), STANDING_MIN, STANDING_MAX)

func add_standing(faction_id: String, delta: int) -> int:
	var value := clampi(standing_of(faction_id) + delta, STANDING_MIN, STANDING_MAX)
	standing[faction_id] = value
	return value
```

`src/rules/state_ops.gd`：在 `match op:` 里（`"relation_delta"` 之后）加三个分支：

```gdscript
			"join_faction":
				var join_id := str(raw.get("faction_id", ""))
				if not world.registry.has("factions", join_id):
					errors.append("未知派系: %s" % join_id)
				elif not WorldFactions.visible_faction_ids(world).has(join_id):
					errors.append("该派系尚未揭示，无法加入: %s" % join_id)
				else:
					world.player.faction_id = join_id
					if str(world.registry.entry("factions", join_id).get("legal_status", "legal")) == "outlaw":
						world.flags["illegal_affiliation"] = join_id
						errors.append("警告：加入非法组织（%s），法律后果留待后续结算" % join_id)
			"leave_faction":
				world.player.faction_id = ""
			"faction_standing_delta":
				var standing_id := str(raw.get("faction_id", ""))
				if not world.registry.has("factions", standing_id):
					errors.append("未知派系: %s" % standing_id)
				else:
					var raw_delta = raw.get("delta", 0)
					var delta := int(raw_delta) if (typeof(raw_delta) == TYPE_INT or typeof(raw_delta) == TYPE_FLOAT) else 0
					world.player.add_standing(standing_id, delta)
					var fstate := WorldFactions.ensure_state(world, standing_id)
					if not fstate.is_empty():
						fstate["stance_to_player"] = clampi(int(fstate.get("stance_to_player", 0)) + delta / 2, -100, 100)
```

`join_faction` 依赖 `WorldFactions.visible_faction_ids()`——**本任务直接把它实现成最终版**（Task 6 只在此基础上加 `reveal()`，不得重写它）：

```gdscript
# 信息保护（第四十三/五十七章）：只有 revealed 的派系对玩家可见。
static func visible_faction_ids(world: WorldState) -> PackedStringArray:
	var out := PackedStringArray()
	for fid in world.registry.ids("factions"):
		if bool(state_of(world, str(fid)).get("revealed", false)):
			out.append(str(fid))
	return out
```

`src/gm/op_guard.gd`：加常量与分支：

```gdscript
const MAX_STANDING_DELTA := 20
```

在 `match op:` 的 `"relation_delta"` 分支之后加：

```gdscript
			"join_faction", "leave_faction":
				if op == "join_faction":
					var fid := str(raw.get("faction_id", ""))
					if fid.is_empty():
						out.warnings.append("忽略缺 faction_id 的 join_faction")
						continue
					out.ops.append({"op": "join_faction", "faction_id": fid})
				else:
					out.ops.append({"op": "leave_faction"})
			"faction_standing_delta":
				var sid := str(raw.get("faction_id", ""))
				if sid.is_empty():
					out.warnings.append("忽略缺 faction_id 的 faction_standing_delta")
					continue
				out.ops.append({"op": "faction_standing_delta", "faction_id": sid,
					"delta": clampi(_to_int(raw.get("delta", 0)), -MAX_STANDING_DELTA, MAX_STANDING_DELTA)})
```

`src/persist/save_codec.gd`：`_validate_payload` 里，`player` 的嵌套校验新增一项（放在既有 `dict_fields` 检查之后）：

```gdscript
	# 计划 03a：player.standing 必须是对象（faction_id -> 整数）
	if parsed.has("player") and typeof(parsed["player"]) == TYPE_DICTIONARY:
		var p: Dictionary = parsed["player"]
		if p.has("standing") and typeof(p["standing"]) != TYPE_DICTIONARY:
			return "存档载荷字段类型错误：player.standing 应为对象"
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[save\]|^\[gm\]|^\[llm\]|总计|全部通过"`
Expected: 全部 `失败=0`，`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/model/player_state.gd src/rules/state_ops.gd src/gm/op_guard.gd src/persist/save_codec.gd src/rules/factions.gd tests/factions_test.gd tests/save_test.gd tests/gm_test.gd tests/llm_test.gd
git commit -m "feat(factions): 玩家所属/立场与加入退出 op + 守卫与存档校验（计划 03a Task 3）"
```

---

### Task 4: `WorldFactions.evolve()` —— 实力/控制权演化 + 政体刷新

**Files:**
- Modify: `src/rules/factions.gd`
- Test: `tests/factions_test.gd`

**Interfaces:**
- Consumes: Task 2 的 `initialize/ensure_state/state_of/power_of/base_power/power_share/institution_control/government_type`；`RngService`。
- Produces:
  - `static func evolve(world: WorldState) -> Array`（本任务恒返回空数组；Task 5 让它产出事件）
  - 常量 `EVOLVE_REGRESSION := 0.04`、`EVOLVE_NOISE := 0.02`、`SUPPRESS_RATE := 0.03`、`SUPPRESS_FLOOR := 0.05`
  - `static func structure_pull(world: WorldState, faction_id: String) -> float`、`static func apply_rival_pressure(world: WorldState) -> void`
  - 副作用：更新 `world.factions[*].power` / `.control[*]` / `.last_change_turn`，写 `world.flags[GOVERNMENT_FLAG]`

- [ ] **Step 1: 写失败测试**

在 `tests/factions_test.gd` 的 `run()` 末尾（`return a.report("factions")` 之前）追加：

```gdscript
	# ---- 演化：确定性、结构拉力、政体缓存（Task 4） ----
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

	# 敌对压制：强的一方压低弱的一方，但不会归零
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
```

> 上面那条非对称回归用例是 **Task 4 审查 I1 的回归护栏**：旧实现（`oid <= id`）下它是唯一会红的断言。

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|总计"`
Expected: 失败（`evolve`/`structure_pull` 未定义 → 套件未 report）。

- [ ] **Step 3: 实现**

在 `src/rules/factions.gd` 追加：

```gdscript
# ---------- 月度演化（第十二/四十六/四十七/四十九章） ----------

const EVOLVE_REGRESSION := 0.04   # 每月向「目标实力」回归的比例
const EVOLVE_NOISE := 0.02        # ±0.02 扰动
const SUPPRESS_RATE := 0.03       # 敌对压制：每月按实力差比例削弱败者
const SUPPRESS_FLOOR := 0.05      # 弱者的实力下限

# 结构性拉力：世界变量如何推动某类派系（正典第十二/十七/四十九章的定性关系）
static func structure_pull(world: WorldState, faction_id: String) -> float:
	var kind := str(entry_of(world, faction_id).get("kind", ""))
	var v := world.world_vars
	match kind:
		"ministry":
			return float(v.get("ministry_stability", 0.5)) * 0.10 - float(v.get("corruption", 0.3)) * 0.20
		"institution":
			return float(v.get("ministry_stability", 0.5)) * 0.05
		"pureblood":
			return float(v.get("pureblood_influence", 0.3)) * 0.15
		"dark":
			return float(v.get("war_pressure", 0.2)) * 0.30 + float(v.get("corruption", 0.3)) * 0.10
		"resistance":
			return float(v.get("war_pressure", 0.2)) * 0.25
		"commerce", "media":
			return (float(v.get("economy_index", 0.6)) - 0.5) * 0.20
		"foreign":
			return float(v.get("muggle_relations", 0.5)) * 0.10
		"school":
			return float(v.get("secrecy_integrity", 0.8)) * 0.10
		_:
			return 0.0

# 敌对压制：对每一对 rivals 只处理一次（**无向对**语义，与哪一方声明无关），强者压低弱者、自己小幅获益。
# 注意：内容表的 `rivals` 是**非对称**的（黑市视傲罗为敌，傲罗的主要敌人却是食死徒），
# 因此去重必须按「无向对键」——用 `oid <= id` 会把「只有字典序较大的一方声明」的敌对对静默丢弃
# （实测 11 个已声明敌对对中有 5 个被丢，见 Task 4 审查 I1）。
static func apply_rival_pressure(world: WorldState) -> void:
	var seen: Dictionary = {}
	for fid in world.registry.ids("factions"):
		var id := str(fid)
		var rivals_raw = entry_of(world, id).get("rivals", [])
		if typeof(rivals_raw) != TYPE_ARRAY:
			continue
		for other in (rivals_raw as Array):
			var oid := str(other)
			if oid.is_empty() or oid == id:
				continue
			var pair_key := id + "|" + oid if id < oid else oid + "|" + id
			if seen.has(pair_key):
				continue
			seen[pair_key] = true
			var pa := power_of(world, id)
			var pb := power_of(world, oid)
			if is_equal_approx(pa, pb):
				continue
			var winner := id if pa > pb else oid
			var loser := oid if pa > pb else id
			var gap := absf(pa - pb)
			var loser_state := ensure_state(world, loser)
			if not loser_state.is_empty():
				var floor := maxf(SUPPRESS_FLOOR, base_power(world, loser) * 0.25)
				loser_state["power"] = clampf(float(loser_state["power"]) - SUPPRESS_RATE * gap, floor, 1.0)
			var winner_state := ensure_state(world, winner)
			if not winner_state.is_empty():
				winner_state["power"] = clampf(float(winner_state["power"]) + SUPPRESS_RATE * gap * 0.5, 0.0, 1.0)

# 单回合演化：就地更新 world.factions / world.flags，返回事件数组（结构与 tick 的 events 一致）
static func evolve(world: WorldState) -> Array:
	# 与 initialize() 同口径的早退：裸世界/半残世界（registry 或 clock 为 null）直接返回空数组，
	# 否则下一行读 world.clock.turn 会 nil 访问（Task 4 审查 M3 的收口；Task 5 接线时务必保留）。
	if world == null or world.registry == null or world.clock == null:
		return []
	initialize(world)
	var rng := RngService.new(world.game_seed + world.clock.turn * 31337)
	for fid in world.registry.ids("factions"):
		var id := str(fid)
		var st := ensure_state(world, id)
		if st.is_empty():
			continue
		var target := clampf(base_power(world, id) + structure_pull(world, id), 0.0, 1.0)
		var current := clampf(float(st.get("power", target)), 0.0, 1.0)
		var noise := rng.stream_float("faction_%s" % id) * (EVOLVE_NOISE * 2.0) - EVOLVE_NOISE
		var next := clampf(current + (target - current) * EVOLVE_REGRESSION + noise, 0.0, 1.0)
		if not is_equal_approx(next, current):
			st["last_change_turn"] = world.clock.turn
		st["power"] = next
		var control: Dictionary = st.get("control", {})
		for inst in control.keys():
			control[inst] = clampf(float(control[inst]) + (next - float(control[inst])) * 0.5, 0.0, 1.0)
	apply_rival_pressure(world)
	world.flags[GOVERNMENT_FLAG] = government_type(world)
	return []
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|总计|全部通过"`
Expected: `[factions] 断言=... 失败=0`；`全部通过。`

**反证实验（spec §9.4 要求，必须贴进报告）**：把 `apply_rival_pressure()` 的调用在 `evolve()` 里注释掉，重跑。⚠️ **注意（2026-09-20 Task 4 实跑发现）**：本步骤原先只要求「『敌对强者压制弱者』那条断言必须变红」——**那条断言没有判别力**，注释掉压制后它照样绿。原因是现代世界里 `structure_pull(death_eaters) = +0.06` 使它的目标值只有 0.11，单靠「向目标回归」就把 0.60 拉到 0.5691（已低于起点），噪音也帮不上忙。因此在实现时必须**另加两条有判别力的用例**（见 Step 1 的「可判别压制」与「单对精确幅度」两条）：
- 「可判别压制」用例把 `war_pressure`/`corruption` 提到 1.0（把败者目标值抬到 0.45）、败者起点设为 **0.06**（高于下限 0.05）→ 纯回归会把它**拉高**到 0.0756±noise，只有真压制才能压回起点以下并压到下限；
- 「单对精确幅度」用例用**最小夹具**（只有两个派系互为 rivals）断言跌幅恰为 `SUPPRESS_RATE × gap`；在 17 派系真实内容表上多对叠加会改变净跌幅（实测 0.004752 ≠ 单对 0.0105），故必须隔离。
反证时这两条必须变红；恢复后重跑变绿；两段原始输出都贴进报告，否则视为假绿。**另**：`oid <= id` 的去重缺陷（审查 I1）由 Step 1 的「非对称敌对声明」用例看护——它也必须能在旧实现下变红。

- [ ] **Step 5: 提交**

```bash
git add src/rules/factions.gd tests/factions_test.gd
git commit -m "feat(factions): 派系实力/控制权演化与政体刷新（计划 03a Task 4）"
```

---

### Task 5: 社会矛盾 `tension` + 政治事件 + `tick()` 接线

**Files:**
- Create: `data/political_events.json`
- Modify: `src/core/registry.gd`、`src/rules/factions.gd`、`src/model/world_state.gd`
- Test: `tests/factions_test.gd`、`tests/registry_test.gd`、`tests/world_tick_test.gd`

**Interfaces:**
- Consumes: Task 4 的 `evolve()`；既有 `WorldState.MAJOR_EVENT_GAP`、`world.flags["last_major_turn"]`、`world.add_fact()`。
- Produces:
  - 表名 `"political_events"`（字段 `id,label,category,condition,text,major`）
  - `static func compute_tension(world: WorldState) -> float`（0..1，纯函数）
  - `static func tension_of(world: WorldState) -> float`（读 `flags[TENSION_FLAG]`，缺省现算）
  - `static func event_condition_met(world: WorldState, condition: String) -> bool`
  - `static func pick_political_event(world: WorldState) -> Dictionary`
  - `static func apply_rumor_reveals(world: WorldState, events: Array) -> void`（本任务先给空实现，Task 6 填实）
  - 常量 `TENSION_THRESHOLD := 0.55`
  - `evolve()` 现在返回事件数组（元素含 `kind="faction"`、`category`、`text`、`major`、`turn`、`event_id`）

- [ ] **Step 1: 写失败测试**

在 `tests/factions_test.gd` 末尾追加：

```gdscript
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

	WorldFactions.initialize(angry)
	a.is_true(WorldFactions.event_condition_met(angry, "economic_slump"), "经济萧条条件成立")
	a.is_false(WorldFactions.event_condition_met(calm, "economic_slump"), "经济好时不成立")
	a.is_true(WorldFactions.event_condition_met(angry, "oligarchy_pressure"), "寡头压力条件成立")
	a.is_false(WorldFactions.event_condition_met(calm, "oligarchy_pressure"), "无寡头压力时不成立")
	a.is_false(WorldFactions.event_condition_met(angry, "不存在的条件"), "未知条件恒不成立")

	var pev := WorldFactions.pick_political_event(angry)
	a.is_true(not pev.is_empty(), "紧张局势下能选出政治事件")
	a.is_true(angry.registry.has("political_events", str(pev.get("event_id", ""))), "事件 id 来自内容表")
	a.is_true(not str(pev.get("text", "")).is_empty(), "事件有文案")
	a.eq(int(angry.flags.get("last_major_turn", -1)), angry.clock.turn, "事件占用本月重大事件配额")
	a.is_true(WorldFactions.pick_political_event(angry).is_empty(), "同一回合不再重复触发（MAJOR_EVENT_GAP）")

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
```

在 `tests/registry_test.gd` 的派系段追加：

```gdscript
	a.eq(reg.ids("political_events").size(), 5, "政治事件表 5 条")
	for eid in reg.ids("political_events"):
		var pe := reg.entry("political_events", str(eid))
		a.is_true(not str(pe.get("text", "")).is_empty(), "政治事件 %s 有文案" % str(eid))
		a.is_true(["politics", "economy", "law"].has(str(pe.get("category", ""))), "政治事件 %s category 合法" % str(eid))
```

在 `tests/world_tick_test.gd` 的 `run()` 末尾（`return a.report("world_tick")` 之前）追加：

```gdscript
	# ---- 计划 03a：新增演化阶段不得破坏 tick 的既有语义 ----
	var pre_reg := Registry.load_default()
	var pre_w := WorldState.create("modern", PlayerState.new_default(), 4242, pre_reg)
	var age_before := pre_w.player.age_months
	var turn_before := pre_w.clock.turn
	pre_w.tick()
	a.eq(pre_w.player.age_months, age_before + 1, "年龄仍每回合 +1")
	a.eq(pre_w.clock.turn, turn_before + 1, "回合仍每回合 +1")
	a.is_true(pre_w.log.size() <= 200, "日志仍被裁剪到 200 条以内")
	a.is_true(pre_w.flags.has(WorldFactions.GOVERNMENT_FLAG), "政体缓存已写入")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[registry\]|^\[world_tick\]|总计"`
Expected: 失败（`compute_tension` 等未定义；`political_events` 表缺失）。

- [ ] **Step 3: 实现**

新建 `data/political_events.json`：

```json
[
  {"id": "reform_movement", "label": "改革运动", "category": "politics", "condition": "oligarchy_pressure", "major": true,
   "text": "《预言家日报》称，一批麻瓜出身巫师与改革派纯血联名要求威森加摩改革席位分配；纯血家族则指责有人「借改革之名夺权」。"},
  {"id": "coup_attempt", "label": "政变", "category": "politics", "condition": "lawlessness", "major": true,
   "text": "魔法部内部传出消息：有人试图用夺魂咒控制关键部门的司长。政变没有成功，但没人说得清到底是谁在动手。"},
  {"id": "prison_break", "label": "阿兹卡班越狱", "category": "law", "condition": "war_exhaustion", "major": true,
   "text": "阿兹卡班发生越狱。摄魂怪失职的说法在巫师之间流传，魔法部只承认「正在统计失踪人数」。"},
  {"id": "financial_crisis", "label": "古灵阁金融危机", "category": "economy", "condition": "economic_slump", "major": true,
   "text": "古灵阁收紧兑付，几家老店开始只收加隆不收西可。《预言家日报》称之为「技术性调整」，对角巷的店主们管它叫挤兑。"},
  {"id": "crackdown", "label": "魔法部镇压", "category": "law", "condition": "lawlessness", "major": true,
   "text": "魔法部宣布一批「保密法违规」的紧急逮捕令。被抓的人里有走私犯，也有只是说了几句难听话的普通巫师。"}
]
```

`src/core/registry.gd`：`TABLE_FILES` 增加 `"political_events": "political_events.json",`（放在 `"rumors"` 之后）。`_validate_entry` 增加分支：

```gdscript
	if table_name == "political_events":
		if not ["politics", "economy", "law"].has(str(e.get("category", ""))):
			errors.append("%s: category 非法" % where)
		if str(e.get("text", "")).is_empty():
			errors.append("%s: 缺少 text" % where)
		if str(e.get("condition", "")).is_empty():
			errors.append("%s: 缺少 condition" % where)
```

`src/rules/factions.gd`：把 `evolve()` 的 `return []` 替换为（**含末尾的数值量化**，理由见下方 ⚠️）：

```gdscript
	world.flags[GOVERNMENT_FLAG] = government_type(world)
	world.flags[TENSION_FLAG] = compute_tension(world)
	var events: Array = []
	var picked := pick_political_event(world)
	if not picked.is_empty():
		events.append(picked)
	quantize_state(world)
	return events
```

⚠️ **数值量化（2026-09-20 Task 5 实跑新增，控制器已并入计划）**：接上演化后，`[save]` 的既有不变量
`a.eq(w3r.to_dict(), w3.to_dict(), "读档后重建引擎续跑：世界状态一致")` 会变红 —— 根因**不是** key 顺序，
而是 **1 ULP**（`0.21739610501640022` 存盘文本逐字正确、解析回来变 `0.21739610501640025`，差 `-2.78e-17`），
即计划 02 登记的 `§8#50`（`full_precision` 不保证 double 逐位往返）被回归+噪声产生的连续长尾浮点**新触发**。
若不管它，「存档往返逐字一致」这条计划 01 的设计不变量就实际失效。因此本计划要求：

```gdscript
const QUANTIZE_DECIMALS := 4        # 玩法精度：面板只显示 2 位小数；4 位远超需求

# 幂等量化：把长尾浮点压到 4 位小数，保证存档文本短且 JSON 往返稳定（§8#50 的触发面收窄）。
static func quantize(value: float) -> float:
	var factor := pow(10.0, QUANTIZE_DECIMALS)
	return roundf(value * factor) / factor

static func quantize_state(world: WorldState) -> void:
	for fid in world.factions.keys():
		var st = world.factions[fid]
		if typeof(st) != TYPE_DICTIONARY:
			continue
		if (st as Dictionary).has("power"):
			(st as Dictionary)["power"] = quantize(float((st as Dictionary)["power"]))
		var control = (st as Dictionary).get("control", {})
		if typeof(control) == TYPE_DICTIONARY:
			for inst in (control as Dictionary).keys():
				(control as Dictionary)[inst] = quantize(float((control as Dictionary)[inst]))
	if world.flags.has(TENSION_FLAG):
		world.flags[TENSION_FLAG] = quantize(float(world.flags[TENSION_FLAG]))
```

**注意**：这只是**收窄** `§8#50` 的触发面，**不是**修掉它 —— 存档 v2（float 字符串化 / 定点编码）仍登记为独立议题（见
`HANDOFF §8#50`）。量化只用于「写入持久化的游戏数值」，不得用于中间计算（`power_share` 等仍按量化后的值计算，
因为那是持久状态本身）。`quantize_state()` 必须幂等（对已量化的值再量化不得改变它），且**不得**用量化掩盖随机性或
舍入方向（`roundf` 是确定性的）。

并追加：

```gdscript
# ---------- 社会矛盾与政治事件（第四十六/四十九/六十八章） ----------

const TENSION_THRESHOLD := 0.55

# 社会矛盾：腐败、纯血垄断、保密法紧张、战争、经济衰退、四角失衡共同累积（正典第四十九章）
static func compute_tension(world: WorldState) -> float:
	var v := world.world_vars
	var corruption := float(v.get("corruption", 0.3))
	var pureblood := float(v.get("pureblood_influence", 0.3))
	var muggle := float(v.get("muggle_relations", 0.5))
	var war := float(v.get("war_pressure", 0.2))
	var economy := float(v.get("economy_index", 0.6))
	var secrecy := float(v.get("secrecy_integrity", 0.8))
	var raw := corruption * 0.25 + pureblood * 0.20 + (1.0 - muggle) * 0.15 \
		+ war * 0.20 + (1.0 - economy) * 0.15 + (1.0 - secrecy) * 0.05
	var share := power_share(world)
	var top := 0.0
	for key in share.keys():
		top = maxf(top, float(share[key]))
	raw += clampf((top - 0.25) * 0.5, 0.0, 0.25)
	return clampf(raw, 0.0, 1.0)

static func tension_of(world: WorldState) -> float:
	if world.flags.has(TENSION_FLAG):
		return clampf(float(world.flags[TENSION_FLAG]), 0.0, 1.0)
	return compute_tension(world)

# 事件条件：代码判定，文案在 data/political_events.json（内容进 data）
static func event_condition_met(world: WorldState, condition: String) -> bool:
	var v := world.world_vars
	match condition:
		"economic_slump":
			return float(v.get("economy_index", 0.6)) <= 0.35
		"oligarchy_pressure":
			return float(power_share(world).get("pureblood", 0.0)) >= 0.26 \
				or float(v.get("pureblood_influence", 0.3)) >= 0.65
		"lawlessness":
			return float(v.get("corruption", 0.3)) >= 0.65 \
				or government_type(world) == "death_eater_dictatorship"
		"war_exhaustion":
			return float(v.get("war_pressure", 0.2)) >= 0.65
		"secrecy_crisis":
			return float(v.get("secrecy_integrity", 0.8)) <= 0.30
		_:
			return false

# 选举本月政治事件：必须同时满足「tension 过阈」「条件成立」「重大事件配额可用」（第六十八章）。
# ⚠️ 名字像查询，但**有副作用**：命中时写 `world.history`（`add_fact("major", …)`）并占用 `last_major_turn`
# 配额。目前只有 `evolve()` 内部调用（由 `tick()` 统一把事件追加进 `events`/`log`），顺序一致；
# 但**不要**在面板预览、UI 提示等地方调用它（会静默烧掉配额）。Task 5 审查 Minor 1 已登记。
static func pick_political_event(world: WorldState) -> Dictionary:
	if tension_of(world) < TENSION_THRESHOLD:
		return {}
	var last_major := int(world.flags.get("last_major_turn", -WorldState.MAJOR_EVENT_GAP))
	if world.clock.turn - last_major < WorldState.MAJOR_EVENT_GAP:
		return {}
	var candidates: Array = []
	for eid in world.registry.ids("political_events"):
		var entry := world.registry.entry("political_events", str(eid))
		if event_condition_met(world, str(entry.get("condition", ""))):
			candidates.append(entry)
	if candidates.is_empty():
		return {}
	var rng := RngService.new(world.game_seed + world.clock.turn * 524287)
	var picked: Dictionary = rng.stream_pick("political_event", candidates)
	if picked.is_empty():
		return {}
	world.flags["last_major_turn"] = world.clock.turn
	var ev := {
		"kind": "faction",
		"category": str(picked.get("category", "politics")),
		"text": str(picked.get("text", "")),
		"major": bool(picked.get("major", true)),
		"turn": world.clock.turn,
		"event_id": str(picked.get("id", "")),
	}
	world.add_fact("major", str(picked.get("text", "")))
	return ev

# Task 6 填实：把传闻事件里指向的派系标记为已揭示
static func apply_rumor_reveals(world: WorldState, _events: Array) -> void:
	pass
```

`src/model/world_state.gd` 的 `tick()`：在既有「2) 本月区级动态」代码块**之后**、「3) 生活基线」**之前**插入两段，并把后面三步的注释序号改为 5/6/7：

```gdscript
	# 3) 计划 03a：传闻揭示（第四十三/五十七章）——玩家通过传闻获知秘密派系
	WorldFactions.apply_rumor_reveals(self, events)

	# 4) 计划 03a：派系与政治演化（第十二/四十六/四十七/四十九章）
	for political_event in WorldFactions.evolve(self):
		events.append(political_event)
		log.append(political_event)
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[registry\]|^\[world_tick\]|总计|全部通过"`
Expected: 全部 `失败=0`；`全部通过。`

> ⚠️ **这段代码要插进 `WorldState.tick()` 内部**，那里**没有** `world` 这个局部变量（成员即 `self`）。
> 原稿写 `WorldFactions.apply_rumor_reveals(world, events)` / `WorldFactions.evolve(world)` 会直接
> `Identifier "world" not declared in the current scope` 编译失败（Task 5 实跑踩到，已改为 `self`）。
> 同时**必须**给传闻事件字典补 `"rumor_id": str(picked.get("id", ""))`（Task 6 的传闻揭示依赖它）。

- [ ] **Step 5: 提交**

```bash
git add data/political_events.json src/core/registry.gd src/rules/factions.gd src/model/world_state.gd tests/factions_test.gd tests/registry_test.gd tests/world_tick_test.gd
git commit -m "feat(factions): 社会矛盾与政治事件 + tick 演化接线（计划 03a Task 5）"
```

---

### Task 6: 信息保护 —— `reveal()` + 传闻揭示 + 派系传闻内容

**Files:**
- Modify: `src/rules/factions.gd`、`data/rumors.json`、`src/core/registry.gd`
- Test: `tests/factions_test.gd`、`tests/registry_test.gd`

**Interfaces:**
- Consumes: Task 3 的 `visible_faction_ids()`；既有 `world.add_fact(kind, text)`；Task 5 的 `apply_rumor_reveals` 预置位。
- Produces:
  - `static func reveal(world: WorldState, faction_id: String, source: String) -> bool`
  - `apply_rumor_reveals()` 填实（读 `ev["rumor_id"]` → `rumors` 表的 `reveals_faction` → `reveal()`）
  - `data/rumors.json` 新增可选字段 `reveals_faction`（至少 4 条）

- [ ] **Step 1: 写失败测试**

`tests/factions_test.gd` 末尾追加：

```gdscript
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

	# 传闻揭示：只有带 reveals_faction 的传闻才揭示
	WorldFactions.apply_rumor_reveals(rw, [{"rumor_id": "不存在的传闻", "category": "政治", "text": "x"}])
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
```

`tests/registry_test.gd` 的派系段追加：

```gdscript
	var reveal_count := 0
	for rid in reg.ids("rumors"):
		var re := reg.entry("rumors", str(rid))
		var reveal_target := str(re.get("reveals_faction", ""))
		if not reveal_target.is_empty():
			reveal_count += 1
			a.is_true(reg.has("factions", reveal_target), "传闻 %s 的 reveals_faction 存在（%s）" % [str(rid), reveal_target])
	a.is_true(reveal_count >= 3, "至少 3 条传闻用于揭示派系（实际 %d）" % reveal_count)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[registry\]|总计"`
Expected: 失败（`reveal` 未定义；`reveals_faction` 计数为 0）。

- [ ] **Step 3: 实现**

`src/rules/factions.gd`：把 Task 5 的空实现替换为：

```gdscript
# 传闻揭示（第四十三/五十七章）：内容表里带 reveals_faction 的传闻被玩家听到时，该派系转为已知。
static func apply_rumor_reveals(world: WorldState, events: Array) -> void:
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var rumor_id := str((ev as Dictionary).get("rumor_id", ""))
		if rumor_id.is_empty():
			continue
		var entry := world.registry.entry("rumors", rumor_id)
		var target := str(entry.get("reveals_faction", ""))
		if target.is_empty():
			continue
		reveal(world, target, "传闻：%s" % str((ev as Dictionary).get("category", "街谈巷议")))
```

并追加（放在 `visible_faction_ids()` 附近）：

```gdscript
# 揭示一个派系。约束：来源必须非空且不是 system（与 StateOps.know_fact 同源，第四十三/五十七章）。
# 已揭示时返回 false（幂等），调用方可据此跳过重复叙事。
static func reveal(world: WorldState, faction_id: String, source: String) -> bool:
	# 与 initialize()/evolve() 同口径的早退：reveal() 是对外 API（面板/GM op 会调），
	# 畸形存档可能让 clock 为 null（Task 6 审查 Minor 3 的收口）。
	if world == null or world.registry == null or world.clock == null:
		return false
	var src := source.strip_edges()
	if src.is_empty() or src == "system":
		return false
	if not world.registry.has("factions", faction_id):
		return false
	var st := ensure_state(world, faction_id)
	if st.is_empty() or bool(st.get("revealed", false)):
		return false
	st["revealed"] = true
	# ⚠️ **不写** `last_change_turn`：该字段的语义严格定义为「**power 变更回合**」（Task 4/5 的统一判定所写）。
	# 揭示是另一种变化，由 `revealed` 布尔本身表达；若这里也写该字段，Task 5 的不变量
	# 「`last_change_turn == clock.turn` ⟺ 量化持久值本回合变化」会在「被揭示但当月 power 恰好没变」时变红
	# （Task 6 审查 Minor 1，2026-09-20 控制器裁定：字段语义单一化，不给揭示再记一个回合）。
	world.add_fact("faction_revealed", "你得知了「%s」的存在（来源：%s）。" % [
		str(entry_of(world, faction_id).get("label", faction_id)), src])
	return true
```

`data/rumors.json`：追加 4 条（保留既有条目不动；`zones` 必须是 `data/locations.json` 里真实存在的地点 id；`major` 一律 false，避免抢重大事件配额）：

```json
  {"id": "rumor_malfoy_block", "category": "政治", "text": "听说几个古老姓氏在威森加摩里抱团，把持着席位不肯松手。", "zones": ["diagon_alley", "london_muggle"], "min_year": 0, "major": false, "reveals_faction": "sacred_twenty_eight"},
  {"id": "rumor_marked_ones", "category": "政治", "text": "有人在翻倒巷低声说，那些人又聚起来了，袖口下面有记号。", "zones": ["knockturn_alley", "diagon_alley"], "min_year": 0, "major": false, "reveals_faction": "death_eaters"},
  {"id": "rumor_phoenix_network", "category": "政治", "text": "有人提到一个不挂在魔法部名下的联络网：不问出身，只问你敢不敢站队。", "zones": ["hogsmeade", "london_muggle"], "min_year": 0, "major": false, "reveals_faction": "order_of_phoenix"},
  {"id": "rumor_continental_pureblood", "category": "政治", "text": "《预言家日报》角落里提到欧陆几家的联姻，说那才是真正的权力网络。", "zones": ["diagon_alley", "london_muggle"], "min_year": 0, "major": false, "reveals_faction": "continental_pureblood"}
```

`src/core/registry.gd` 的 `_validate_entry` 增加：

```gdscript
	if table_name == "rumors":
		if e.has("reveals_faction") and typeof(e["reveals_faction"]) != TYPE_STRING:
			errors.append("%s: reveals_faction 必须是字符串" % where)
```

`WorldFactions.validate_content()` 增加引用检查：

```gdscript
	for rid in registry.ids("rumors"):
		var target := str(registry.entry("rumors", str(rid)).get("reveals_faction", ""))
		if not target.is_empty() and not registry.has("factions", target):
			errors.append("rumors/%s: reveals_faction 引用不存在的派系（%s）" % [str(rid), target])
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[registry\]|^\[world_tick\]|总计|全部通过"`
Expected: 全部 `失败=0`；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/rules/factions.gd src/core/registry.gd data/rumors.json tests/factions_test.gd tests/registry_test.gd
git commit -m "feat(factions): 信息保护与传闻揭示（计划 03a Task 6）"
```

---

### Task 7: 势力面板重写（第六十五章）

**Files:**
- Modify: `src/ui/panel_formatter.gd`
- Test: `tests/panel_test.gd`

**Interfaces:**
- Consumes: `WorldFactions.power_share/institution_control/government_type/visible_faction_ids/power_of/state_of`；`world.registry.entry("governments", id)`；`PlayerState.standing_of`。
- Produces: `PanelFormatter.power_panel(world) -> String` 新格式（三行 + 【已知势力】一行）；新增私有 helper `_known_factions_line(world)`、`_institution_holder_label(world, ic, institution_id)`。

- [ ] **Step 1: 写失败测试**

在 `tests/panel_test.gd` 末尾（`return a.report("panel")` 之前）追加：

```gdscript
	# ---- 计划 03a：势力面板（第六十五章 + 【已知势力】） ----
	WorldFactions.initialize(w)
	var power := PanelFormatter.power_panel(w)
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
	a.is_true(power.contains("食死徒") == false, "未揭示的派系不得出现（第四十三/五十七章）")

	WorldFactions.ensure_state(w, "death_eaters")["revealed"] = true
	w.player.faction_id = "ministry"
	w.player.add_standing("ministry", 30)
	var power2 := PanelFormatter.power_panel(w)
	a.is_true(power2.contains("食死徒"), "揭示后出现在面板里")
	a.is_true(power2.contains("立场 +30"), "显示玩家立场")
	a.is_true(power2.contains("[所属]"), "标出玩家所属派系")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[panel\]|总计"`
Expected: 失败（旧格式无「政体：」「【已知势力】」，且旧文本含「待定」）。

- [ ] **Step 3: 实现**

把 `src/ui/panel_formatter.gd` 的 `power_panel()` 整体替换为：

```gdscript
# 第六十五章（计划 03a 重写）：机构级指标来自派系的机构控制权，标量级指标来自 world_vars。
# 信息保护（第四十三/五十七章）：未揭示的派系不出现在任何玩家可见文本里。
static func power_panel(world: WorldState) -> String:
	var vars := world.world_vars
	var ic := WorldFactions.institution_control(world)
	var gov_id := str(world.flags.get(WorldFactions.GOVERNMENT_FLAG, ""))
	if gov_id.is_empty():
		gov_id = WorldFactions.government_type(world)
	var lines: Array[String] = []
	lines.append("《哈利·波特·魔法纪元·势力面板》")
	lines.append("【魔法部状态】政体：%s 部长：%s 法律执行：%.2f（%s） 傲罗：%.2f（%s） 威森加摩：%.2f（%s） 财政：%.2f 国际：%.2f（%s） 稳定度：%.2f 腐败度：%.2f 纯血影响：%.2f 麻瓜关系：%.2f" % [
		_label(world, "governments", gov_id),
		_institution_holder_label(world, ic, "law_enforcement"),
		float((ic["law_enforcement"] as Dictionary)["value"]), _institution_holder_label(world, ic, "law_enforcement"),
		float((ic["auror_office"] as Dictionary)["value"]), _institution_holder_label(world, ic, "auror_office"),
		float((ic["wizengamot"] as Dictionary)["value"]), _institution_holder_label(world, ic, "wizengamot"),
		float(vars.get("economy_index", 0.0)),
		float((ic["international"] as Dictionary)["value"]), _institution_holder_label(world, ic, "international"),
		float(vars.get("ministry_stability", 0.0)), float(vars.get("corruption", 0.0)),
		float(vars.get("pureblood_influence", 0.0)), float(vars.get("muggle_relations", 0.0))])
	lines.append("【霍格沃茨】学院：%s 校方控制：%.2f（%s） 学业：%s 学院杯：仅 NPC 系统（计划 05） 魁地奇：仅 NPC 系统（计划 05） 禁林状况：%s 秘密：未调查 师生关系：%d人" % [
		_label(world, "houses", world.player.house_id),
		float((ic["hogwarts"] as Dictionary)["value"]), _institution_holder_label(world, ic, "hogwarts"),
		_top_skill(world.player, world),
		str(world.flags.get("forbidden_forest_status", "常态")),
		world.player.relations.size()])
	var family: Dictionary = world.player.flags.get("family", {})
	if family.is_empty():
		lines.append("【家族】姓氏：无家族（家族制度属计划 03c） 祖宅：无 财富：%s 成员：0 婚姻：未婚 盟友：0 敌人：0 声望：%d 家族秘密：无 继承人：未定 魔杖传承：无" % [
			world.player.money().formatted(), world.player.reputation])
	else:
		lines.append("【家族】姓氏：%s 祖宅：%s 财富：%s 成员：%d 婚姻：%s 盟友：%d 敌人：%d 声望：%d 家族秘密：%s 继承人：%s 魔杖传承：%s" % [
			str(family.get("surname", "无家族")), str(family.get("seat", "无")),
			world.player.money().formatted(), int(family.get("members", 0)),
			str(family.get("marriage", "未婚")), int(family.get("allies", 0)), int(family.get("enemies", 0)),
			world.player.reputation, str(family.get("secret", "未知")),
			str(family.get("heir", "未定")), str(family.get("wand_legacy", "无"))])
	lines.append(_known_factions_line(world))
	return "\n".join(lines)

# 【已知势力】：只列 revealed 派系，按实力降序；标出玩家所属与立场。
static func _known_factions_line(world: WorldState) -> String:
	var visible := WorldFactions.visible_faction_ids(world)
	if visible.is_empty():
		return "【已知势力】暂无已知势力（魔法世界对你是沉默的）"
	var rows: Array = []
	for fid in visible:
		var id := str(fid)
		rows.append({"id": id, "label": _label(world, "factions", id),
			"power": WorldFactions.power_of(world, id), "standing": world.player.standing_of(id),
			"member": world.player.faction_id == id})
	rows.sort_custom(func(x, y): return float(x["power"]) > float(y["power"]))
	var parts: Array[String] = []
	for row in rows:
		parts.append("%s：%.2f 立场 %+d%s" % [str(row["label"]), float(row["power"]),
			int(row["standing"]), "[所属]" if bool(row["member"]) else ""])
	return "【已知势力】" + " ".join(parts)

static func _institution_holder_label(world: WorldState, ic: Dictionary, institution_id: String) -> String:
	var holder := str((ic[institution_id] as Dictionary).get("holder", ""))
	if holder.is_empty():
		return "无人"
	return _label(world, "factions", holder)
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[panel\]|总计|全部通过"`
Expected: `[panel] 断言=... 失败=0`；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/ui/panel_formatter.gd tests/panel_test.gd
git commit -m "feat(ui): 势力面板重写——机构控制权 + 已知势力（修 §8#7）（计划 03a Task 7）"
```

---

### Task 8: `PromptBuilder.state_digest` 暴露已揭示派系（Q4）

**Files:**
- Modify: `src/gm/prompt_builder.gd`
- Test: `tests/prompt_test.gd`

**Interfaces:**
- Consumes: `WorldFactions.visible_faction_ids/power_of/government_type`；`PlayerState.standing_of/faction_id`。
- Produces: `PromptBuilder.state_digest(world)` 文本新增两行：`政体：<label>` 与 `已知势力：<label>(%.2f,立场%+d,所属) …`（无可见派系时为 `已知势力：无`）。**未揭示派系不得出现**。

- [ ] **Step 1: 写失败测试**

在 `tests/prompt_test.gd` 的 `run()` 末尾（`return a.report("prompt")` 之前）追加：

```gdscript
	# ---- 计划 03a：提示词只暴露已揭示的派系（第四十三/五十七章） ----
	WorldFactions.initialize(w)
	var digest := PromptBuilder.state_digest(w)
	# ⚠️ `state_digest()` 返回 **Dictionary**（计划 02 spec §6.5 的键集合契约），不是文本；
	# `build()` 用 `JSON.stringify(state_digest(world))` 把它塞进 user_prompt，所以新增内容要**加键**。
	# 断言必须用 `.get(..., "")` 读缺失键——用 `digest["government"]` 下标访问会让缺键时抛运行期错误、
	# 整个套件中止（§8#56 陷阱；Task 8 实跑踩到过一次）。
	a.is_true(str(digest.get("government", "")).contains("官僚制"), "摘要含政体（label 取自内容表）")
	a.is_true(not str(digest.get("known_factions", "")).is_empty(), "摘要含已知势力行")
	a.is_true(str(digest.get("known_factions", "")).contains("魔法部"), "摘要含公开派系")
	a.is_false(str(digest.get("known_factions", "")).contains("食死徒"), "摘要不得含未揭示派系（信息保护）")
	WorldFactions.ensure_state(w, "death_eaters")["revealed"] = true
	var digest2 := PromptBuilder.state_digest(w)
	a.is_true(str(digest2.get("known_factions", "")).contains("食死徒"), "揭示后才进入摘要")
	# 提示词契约未破坏：键集合必须是计划 02 的 7 键 + 新增 2 键（多键/少键/改名都算破坏）
	var keys := digest.keys()
	keys.sort()
	a.eq(keys, ["clock", "era", "government", "known_factions", "location", "player",
		"recent_history", "recent_log", "world_vars"], "摘要键集合 = 既有 7 键 + 新增 2 键")
	# 信息保护：user_prompt 全文（不只是 known_factions 行）都不得出现未揭示派系的 label
	var up := PromptBuilder.build(w, "我要去上课").user_prompt
	a.is_false(up.contains("翻倒巷黑市"), "user_prompt 不含未揭示派系（信息保护）")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[prompt\]|总计"`
Expected: 失败（摘要无「政体：」「已知势力：」）。

- [ ] **Step 3: 实现**

在 `src/gm/prompt_builder.gd` 的 `state_digest()` 末尾（`return` 之前）追加：

```gdscript
	# 计划 03a：政治格局（只给已揭示的派系——未揭示的绝不进提示词，第四十三/五十七章）
	# ⚠️ `state_digest()` 返回 Dictionary，`build()` 会 `JSON.stringify` 它 → 这里**加两个键**（不是 append 文本行）。
	var gov_id := str(world.flags.get(WorldFactions.GOVERNMENT_FLAG, ""))
	if gov_id.is_empty():
		gov_id = WorldFactions.government_type(world)
	out["government"] = str(world.registry.entry("governments", gov_id).get("label", gov_id))
	var faction_parts: Array[String] = []
	for fid in WorldFactions.visible_faction_ids(world):
		var id := str(fid)
		faction_parts.append("%s(%.2f,立场%+d%s)" % [
			str(world.registry.entry("factions", id).get("label", id)),
			WorldFactions.power_of(world, id),
			world.player.standing_of(id),
			",所属" if world.player.faction_id == id else ""])
	out["known_factions"] = "无" if faction_parts.is_empty() else " ".join(faction_parts)
	return out
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[prompt\]|^\[llm\]|总计|全部通过"`
Expected: 全部 `失败=0`；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/gm/prompt_builder.gd tests/prompt_test.gd
git commit -m "feat(gm): 提示词摘要暴露已揭示派系与政体（计划 03a Task 8）"
```

> ### ⚠️ Task 8 实跑教训（2026-09-20，控制器据实修正计划）
> 1. **`state_digest()` 是 Dictionary 不是文本**：原稿的 `lines.append("政体：…")` 与 `digest.contains("政体：")` 都是照「文本摘要」写的，实际契约是键集合（`build()` 把整份 JSON 塞进 `user_prompt`）。已改成**加键** `government` / `known_factions`，断言用 `.get(..., "")`（下标访问缺键会中止整个套件，属 `§8#56` 陷阱）。
> 2. **必须加一条键集合断言**（既有 7 键 + 新增 2 键，多/少/改名都算破坏）——这是「提示词契约未被重构」的唯一硬证据。
> 3. **信息保护断言要扫全文**（`user_prompt` 整体），不能只查 `known_factions` 那一行。
> 4. **「神圣二十八族」是公开血统 label**（`data/bloodlines.json`，建角即可见），它会出现在 `system_prompt` 的 `content_index.bloodlines` 里 —— 那是**既有内容**，不是派系泄漏。断言要写成「显式豁免 + 理由」而不是把词从断言里删掉：豁免它作为**血统名**的存在，同时断言它作为**未揭示派系**不得进 `known_factions`。
> 5. **面板/探针里的期望值要现读 `institution_control()`**，不要硬编码 `base_power`（实跑：探针跑了 4 回合后 `auror_office` 的控制权已从 0.60 漂到 **0.62**，硬编码会假红）。

---

### Task 9: 玩家动作接线（离线替身的关键词 → 派系 op）

**Files:**
- Modify: `src/gm/scripted_game_master.gd`
- Test: `tests/gm_test.gd`

**Interfaces:**
- Consumes: `WorldFactions.visible_faction_ids`；Task 3 的三个 op。
- Produces: `ScriptedGameMaster._detect_faction(world, text) -> String`；四个关键词组常量 `FACTION_JOIN/FACTION_LEAVE/FACTION_SUPPORT/FACTION_OPPOSE`。
- 语义：只有**已揭示**派系才能被说出（未揭示的就当玩家不知道）；识别到派系且命中关键词才产出 op，否则**不提前 return**（继续走原有的练习/打工/社交/休息/施法分支）。

- [ ] **Step 1: 写失败测试**

在 `tests/gm_test.gd` 的 `run()` 末尾（`return a.report("gm")` 之前）追加：

```gdscript
	# ---- 计划 03a：离线替身也支持派系动作（Task 9） ----
	var sw := make_world()
	WorldFactions.initialize(sw)
	var sg := ScriptedGameMaster.new(RngService.new(7))

	var join_res := sg.act(sw, "我要加入魔法部")
	var joined := false
	for d in join_res.deltas:
		if str(d.get("op", "")) == "join_faction" and str(d.get("faction_id", "")) == "ministry":
			joined = true
	a.is_true(joined, "关键词「加入魔法部」产出 join_faction")
	StateOps.apply(sw, join_res.deltas)
	a.eq(sw.player.faction_id, "ministry", "端到端：所属写入")

	var support_res := sg.act(sw, "我公开支持魔法部")
	var standing_op := false
	for d in support_res.deltas:
		if str(d.get("op", "")) == "faction_standing_delta":
			standing_op = true
	a.is_true(standing_op, "关键词「支持」产出 faction_standing_delta")
	var oppose_res := sg.act(sw, "我要抗议魔法部")
	var negative := false
	for d in oppose_res.deltas:
		if str(d.get("op", "")) == "faction_standing_delta" and int(d.get("delta", 0)) < 0:
			negative = true
	a.is_true(negative, "关键词「抗议」产出负向立场")

	# 未揭示的派系：玩家说“加入食死徒”不应该凭空产出 op（第四十三/五十七章）
	var hidden_res := sg.act(sw, "我要加入食死徒")
	a.eq(hidden_res.deltas.size(), 0, "未揭示派系的动作不产出任何 op")

	# 不抢原有分支：普通动作仍走原语义
	var work_res := sg.act(sw, "我去对角巷打工赚钱")
	a.eq(str(work_res.tags[0]), "work", "派系分支不影响打工识别")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[gm\]|总计"`
Expected: 失败（「加入魔法部」目前落到 idle，`deltas` 为空）。

- [ ] **Step 3: 实现**

在 `src/gm/scripted_game_master.gd` 的常量区加：

```gdscript
const FACTION_JOIN: Array[String] = ["加入", "投靠", "效力", "为…做事", "入伙"]
const FACTION_LEAVE: Array[String] = ["退出", "脱离", "叛出", "不再属于"]
const FACTION_SUPPORT: Array[String] = ["支持", "拥护", "声援", "捐款", "赞助"]
const FACTION_OPPOSE: Array[String] = ["反对", "抗议", "抨击", "揭露", "抵制"]
```

加方法：

```gdscript
# 计划 03a：识别玩家嘴里提到的“已揭示”派系（label 或 aliases）。未揭示的一律识别为空。
func _detect_faction(world: WorldState, text: String) -> String:
	for fid in WorldFactions.visible_faction_ids(world):
		var id := str(fid)
		var entry := world.registry.entry("factions", id)
		var label := str(entry.get("label", ""))
		if not label.is_empty() and text.contains(label):
			return id
		for alias in (entry.get("aliases", []) as Array):
			if not str(alias).is_empty() and text.contains(str(alias)):
				return id
	return ""
```

在 `act()` 里（施法分支之后、`TRAIN_KEYWORDS` 分支之前）插入：

```gdscript
	# 计划 03a：派系动作（第五十章「可以支持凤凰社、加入食死徒、反对魔法部」）
	var faction_id := _detect_faction(world, text)
	if not faction_id.is_empty():
		var faction_label := str(world.registry.entry("factions", faction_id).get("label", faction_id))
		if _contains_any(text, FACTION_LEAVE):
			r.tags.append("faction")
			r.deltas.append({"op": "leave_faction"})
			r.narration = "你与%s断了关系。名字从名单上划掉，代价还看不出来。" % faction_label
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
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[gm\]|^\[factions\]|总计|全部通过"`
Expected: 全部 `失败=0`；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/gm/scripted_game_master.gd tests/gm_test.gd
git commit -m "feat(gm): 离线替身支持加入/退出/支持/反对派系（计划 03a Task 9）"
```

---

### Task 10: 顺手项 A —— UI 等待期看门狗（`§8#58`）、提交失败恢复（`§8#62`）、provider 复用与 timeout（`§8#63`）

**Files:**
- Modify: `src/ui/main.gd`、`src/gm/providers/openai_compat_provider.gd`
- Test: `tests/llm_test.gd`（provider 部分）、`tools/b1_acceptance.gd`（UI 看门狗部分）

**Interfaces:**
- Produces（provider）：
  - `OpenAiCompatProvider.ensure_http(timeout_ms: int) -> HTTPRequest`（懒建一次，之后复用）
  - `OpenAiCompatProvider.http_timeout_sec() -> float`
  - `OpenAiCompatProvider.dispose() -> void`（释放 `HTTPRequest` 节点）
  - `static OpenAiCompatProvider.mask(text: String, api_key: String) -> String`（脱敏，`complete()` 与测试共用）
- Produces（UI）：
  - `main.gd` 新字段 `var turn_timeout_sec: float = 180.0`（可被环境变量 `HALI_TURN_TIMEOUT_SEC` 覆盖）
  - `main.gd` 新方法 `_run_turn(text)`、`_render_turn_result(result)`、`_turn_state` 字典
  - 行为：等待期置灰；**无论 `await` 链是否抛错**，最多 `turn_timeout_sec` 秒后一定恢复输入与按钮，并提示已恢复

- [ ] **Step 1: 写失败测试**

在 `tests/llm_test.gd` 的 provider 段追加：

```gdscript
	# ---- 计划 03a（§8#63）：HTTPRequest 复用、timeout 每请求更新、dispose 不泄漏 ----
	var host := Node.new()
	Engine.get_main_loop().root.add_child(host)
	var prov := OpenAiCompatProvider.new(host, "https://example.invalid/v1", "m", "k")
	prov.ensure_http(30000)
	a.eq(host.get_child_count(), 1, "懒建一个 HTTPRequest")
	prov.ensure_http(60000)
	a.eq(host.get_child_count(), 1, "第二次不重复建（不泄漏）")
	a.near(prov.http_timeout_sec(), 60.0, 0.001, "timeout 每次请求都更新（不再只生效一次）")
	prov.dispose()
	await Engine.get_main_loop().process_frame
	a.eq(host.get_child_count(), 0, "dispose 释放节点")

	# ---- 计划 03a（§8#64③）：错误串脱敏的负向断言 ----
	var masked := OpenAiCompatProvider.mask("HTTP 401（boom sk-secret end）", "sk-secret")
	a.is_false(masked.contains("sk-secret"), "脱敏后不含 api_key")
	a.is_true(masked.contains("***"), "脱敏后出现掩码")
	a.eq(OpenAiCompatProvider.mask("nothing", ""), "nothing", "空 key 不替换")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[llm\]|总计"`
Expected: 失败（`ensure_http`/`dispose`/`mask` 未定义）。

- [ ] **Step 3: 实现**

`src/gm/providers/openai_compat_provider.gd`：

1) 把 `complete()` 里建节点的两行换成：

```gdscript
	ensure_http(request.timeout_ms)
```

2) 把 `complete()` 末尾的脱敏改为：

```gdscript
	if not resp.ok:
		resp.error = mask(resp.error, api_key)
```

3) 加方法：

```gdscript
# §8#63：懒建一次并复用；timeout 每次请求都重新设（旧实现只在建节点时设一次）。
func ensure_http(timeout_ms: int) -> HTTPRequest:
	if _http == null:
		_http = HTTPRequest.new()
		if _host != null:
			_host.add_child(_http)
	_http.timeout = maxf(1.0, float(timeout_ms) / 1000.0)
	return _http

func http_timeout_sec() -> float:
	return _http.timeout if _http != null else 0.0

# §8#63：每次「开始人生」/「读档」都会重建 provider，旧 provider 的 HTTPRequest 必须释放。
func dispose() -> void:
	if _http != null:
		if _http.get_parent() != null:
			_http.get_parent().remove_child(_http)
		_http.queue_free()
		_http = null

# 错误串可能回显服务端 body，绝不能带出 api_key（§8#64③）
static func mask(text: String, api_key: String) -> String:
	if api_key.is_empty():
		return text
	return text.replace(api_key, "***")
```

`src/ui/main.gd`：

1) 字段区加：

```gdscript
var turn_timeout_sec: float = 180.0
var _turn_state: Dictionary = {}
var _llm_provider: OpenAiCompatProvider = null
```

2) `_ready()` 里（`_debug_mirror = DebugMirror.from_env()` 之后）加：

```gdscript
	var env_timeout := OS.get_environment("HALI_TURN_TIMEOUT_SEC")
	if not env_timeout.is_empty() and env_timeout.is_valid_float():
		turn_timeout_sec = maxf(0.1, env_timeout.to_float())
```

3) 用下列版本替换整个 `_on_command_submitted()`（原来的叙事/事件/错误/自检渲染搬进 `_render_turn_result()`，**恢复出口只剩一处**）：

```gdscript
func _on_command_submitted(text: String) -> void:
	if world == null:
		return
	# 第七十二章：自检后必须等玩家确认，才允许继续叙事
	if text.strip_edges() == "确认自检":
		if engine != null:
			engine.acknowledge_audit()
		_append("（自检已确认。世界继续向前。）")
		command_edit.text = ""
		return
	_set_input_enabled(false)
	_set_buttons_enabled(false)
	_append(">>> %s" % text)
	_append("（世界正在回应…）")
	# §8#58/#62：把等待变成「有上限的等待」。GDScript 的 await 链一旦在内部抛错，调用方永远不会
	# 被唤醒（无 try/catch），旧实现会把输入框与整排按钮永久留在禁用态。看门狗保证恢复出口一定会走到。
	_turn_state = {"done": false, "result": {}}
	_run_turn(text)
	var deadline := Time.get_ticks_msec() + int(maxf(turn_timeout_sec, 0.1) * 1000.0)
	while not bool(_turn_state.get("done", false)) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not bool(_turn_state.get("done", false)):
		_append("（本回合超过 %.0f 秒仍未返回，已恢复输入。请求可能仍在后台；若反复发生，请检查 LLM 配置或改用本地替身。）" % turn_timeout_sec)
	else:
		_render_turn_result(_turn_state["result"])
	_set_status(PanelFormatter.status_line(world) + " ｜ 回合 %d" % world.clock.turn)
	_set_buttons_enabled(true)
	_set_input_enabled(true)
	command_edit.text = ""

# 单独的协程：它的失败不会阻止 _on_command_submitted 的看门狗循环（§8#62）
func _run_turn(text: String) -> void:
	_turn_state["result"] = await engine.submit_async(text)
	_turn_state["done"] = true

func _render_turn_result(result: Dictionary) -> void:
	_append(str(result["narration"]))
	var events: Array = result["events"]
	if not events.is_empty():
		_append(PanelFormatter.events_block(events))
	for err in (result["op_errors"] as PackedStringArray):
		_append("（系统提示：%s）" % str(err))
	if str(result["audit"]) != "":
		_append(str(result["audit"]))
		_append("（自检完毕。等待你的指令——输入“确认自检”继续。）")
```

4) `_build_gm()` 里在 new provider 之前释放旧的：

```gdscript
func _build_gm() -> GameMaster:
	if _llm_provider != null:
		_llm_provider.dispose()      # §8#63：避免每切一次生命周期泄漏一个 HTTPRequest
		_llm_provider = null
	var settings := LlmSettings.load_from()
	if settings.is_configured():
		_llm_provider = OpenAiCompatProvider.from_settings(self, settings)
		return LlmGameMaster.new(_llm_provider, ScriptedGameMaster.new(rng), settings)
	_set_status(status_label.text + "（未配置 LLM，使用本地叙事替身；配置见 user://llm_settings.json）")
	return ScriptedGameMaster.new(rng)
```

5) 在 `tools/b1_acceptance.gd` 末尾（`_verify_restored()` 之前）加一个盘验区块与一个 hang provider：

```gdscript
# 永不返回的 provider：用于验证等待期看门狗（§8#58/#62）
class HangProvider extends LlmProvider:
	func complete(_request: LlmProvider.LlmRequest) -> LlmProvider.LlmResponse:
		await Engine.get_main_loop().create_timer(3600.0).timeout
		return LlmProvider.LlmResponse.new()
```

```gdscript
func _part11_watchdog(node: Node) -> void:
	part("计划 03a 顺手项 · 等待期看门狗（§8#58/#62）")
	node.set("turn_timeout_sec", 0.4)
	var hang_gm := LlmGameMaster.new(HangProvider.new(), ScriptedGameMaster.new(RngService.new(11)), null)
	node.set("engine", TurnEngine.new(_world(node), hang_gm, node.get("rng")))
	var before := _log_len(node)
	await node.call("_on_command_submitted", "我要练习魔药学")
	var block := _log_of(node).substr(before)
	check(block.contains("已恢复输入"), "超时后给出恢复提示")
	check((node.get("command_edit") as LineEdit).editable, "超时后输入框恢复")
	check(_buttons_all(node, false), "超时后整排按钮恢复")
```

并在 `_initialize()` 的 `await _part9_waiting_gate(restarted)` 之后插入 `await _part11_watchdog(restarted)`。

- [ ] **Step 4: 验证**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[llm\]|总计|全部通过" && bash tools/b1_acceptance.sh 2>&1 | grep -E "看门狗|\[PASS\]|\[FAIL\]|断言" | tail -20`
Expected: `[llm]` 失败=0、`全部通过。`；B1 盘验里看门狗三条均为 `[PASS]`，且总失败数为 0。

- [ ] **Step 5: 提交**

```bash
git add src/ui/main.gd src/gm/providers/openai_compat_provider.gd tests/llm_test.gd tools/b1_acceptance.gd
git commit -m "fix(ui,gm): 等待期看门狗 + 提交恢复唯一出口 + provider 复用（§8#58/#62/#63）（计划 03a Task 10）"
```

---

### Task 11: 顺手项 B —— 降级原因透出（`§8#61`）、测试可判别性（`§8#64`）、契约与鸭子类型（`§8#65`）

**Files:**
- Modify: `src/gm/llm_game_master.gd`、`src/gm/game_master.gd`、`src/core/turn_engine.gd`、`docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md`（标点级同步）
- Test: `tests/llm_test.gd`、`tests/gm_test.gd`

**Interfaces:**
- Produces:
  - `GameMaster.is_async() -> bool`（基类返回 `false`；`LlmGameMaster` 覆写为 `true`）
  - `TurnEngine.submit()` 改用 `if gm.is_async():` 拒绝，并给出**非空** `narration`
  - `LlmGameMaster._fallback()` 把降级原因写进 `warnings`（UI 会打印到 `op_errors`）

- [ ] **Step 1: 写失败测试**

`tests/llm_test.gd` 追加：

```gdscript
	# ---- 计划 03a（§8#61）：降级原因必须透出给调用方 ----
	var fmock := MockLlmProvider.new()
	fmock.errors = ["网络抖动"]
	var fgm := LlmGameMaster.new(fmock, ScriptedGameMaster.new(RngService.new(3)), null)
	var fres: GameMaster.GmResult = await fgm.act(lw, "我要去上课")
	var warned := ""
	for w in fres.warnings:
		warned += str(w) + " | "
	a.is_true(warned.contains("降级"), "降级写进 warnings")
	a.is_true(warned.contains("网络抖动"), "降级原因（原始错误）进 warnings")

	# ---- 计划 03a（§8#64①）：重试请求必须带修复提示（否则把 build_repair 换成 build 也能绿） ----
	var rmock := MockLlmProvider.new()
	rmock.queue = ["不是 JSON", "{\"narration\":\"修好了\",\"ops\":[],\"tags\":[]}"]
	var rgm := LlmGameMaster.new(rmock, null, null)
	var rres: GameMaster.GmResult = await rgm.act(lw, "我要去上课")
	a.eq(rres.narration, "修好了", "二次尝试成功")
	a.eq(rmock.requests.size(), 2, "确实重试了一次")
	a.is_true(str(rmock.requests[1].system_prompt).contains("上一次输出无法解析"), "第二次请求带修复提示")

	# ---- 计划 03a（§8#64②）：无 provider 的降级叙事要断言具体文案 ----
	var no_prov := LlmGameMaster.new(null, null, null)
	var nres: GameMaster.GmResult = await no_prov.act(lw, "我要去上课")
	a.is_true(nres.narration.contains("本地规则结算"), "无 provider 时明确告知用本地规则结算")
	a.is_true(nres.narration.contains("provider 未配置"), "并给出原因")
```

`tests/gm_test.gd` 追加：

```gdscript
	# ---- 计划 03a（§8#65③）：鸭子类型判定 + blocked 非空文案 ----
	a.is_false(ScriptedGameMaster.new(RngService.new(1)).is_async(), "离线替身声明为同步")
	a.is_true(LlmGameMaster.new(null, null, null).is_async(), "LLM 主模块声明为协程")
	var sync_world := make_world()
	var async_engine := TurnEngine.new(sync_world, LlmGameMaster.new(null, null, null), RngService.new(1))
	var blocked_out: Dictionary = async_engine.submit("我要去上课")
	a.is_true(bool(blocked_out["blocked"]), "同步 submit 拒绝协程 GM")
	a.is_true(not str(blocked_out["narration"]).is_empty(), "拒绝时给出非空提示（UI 不会白屏）")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[llm\]|^\[gm\]|总计"`
Expected: 失败（`is_async` 未定义；降级 warnings 为空）。

- [ ] **Step 3: 实现**

`src/gm/game_master.gd`：在 `act()` 声明前后加：

```gdscript
# 计划 03a（§8#65①）：act 可以是同步函数，也可以是含 await 的协程；调用方统一写 await gm.act(...)。
# is_async() 用于 TurnEngine 判定能否走同步 submit()（默认 false，协程实现必须覆写为 true）。
func is_async() -> bool:
	return false
```

`src/gm/llm_game_master.gd`：加

```gdscript
func is_async() -> bool:
	return true
```

并把 `_fallback()` 改为：

```gdscript
func _fallback(world: WorldState, action_text: String, reason: String) -> GmResult:
	last_error = reason
	if fallback == null:
		var r := GmResult.new()
		r.narration = "%s（原因：%s）" % [FALLBACK_NOTE, reason]
		r.warnings.append("LLM 降级：%s" % reason)
		return r
	var r2 := fallback.act(world, action_text)
	r2.narration = "%s %s" % [r2.narration, FALLBACK_NOTE]
	r2.warnings.append("LLM 降级：%s" % reason)
	return r2
```

`src/core/turn_engine.gd`：

```gdscript
	if gm.is_async():
		push_error("submit() 不能驱动协程 GM；请用 submit_async()")
		out["blocked"] = true
		out["narration"] = "本模块需要异步回合（请使用 submit_async 路径）；本回合未结算。"
		return out
```

`docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md`：`_post_submit` 改为 `_resolve`（与代码一致），并在 `### 6.1 GameMaster` 的代码块里补 `is_async()`。

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[llm\]|^\[gm\]|总计|全部通过"`
Expected: 全部 `失败=0`；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/gm/llm_game_master.gd src/gm/game_master.gd src/core/turn_engine.gd docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md tests/llm_test.gd tests/gm_test.gd
git commit -m "fix(gm): 降级原因透出 + is_async 鸭子类型 + 测试可判别性（§8#61/#64/#65）（计划 03a Task 11）"
```

---

### Task 12: 顺手项 C —— 哑炮学院（`§8#69`）、创建界面姓名/性别（`§8#70`）、内容旋钮生效（`§8#16/#21`）

**Files:**
- Modify: `src/rules/character_creation.gd`、`src/ui/main.gd`、`src/core/rng_service.gd`、`src/model/world_state.gd`（传闻加权抽取）
- Test: `tests/creation_test.gd`、`tests/world_tick_test.gd`、`tools/b1_acceptance.gd`

**Interfaces:**
- Produces:
  - 哑炮 `house_id = "none"`（正典第七章/第二十四章：哑炮不进霍格沃茨）
  - 创建界面：姓名框默认为空 + 占位提示；新增「性别」下拉（男 / 女 / 未定），选择值进入 `choices["gender"]`
  - `RngService.stream_pick_weighted(name: String, entries: Array, weight_key: String = "weight")`
  - `WorldState.tick()` 的传闻抽取改用 `stream_pick_weighted(..., "weight")`；`generate_wand` 的杖芯抽取改用 `stream_pick_weighted(..., "rarity")`

- [ ] **Step 1: 写失败测试**

`tests/creation_test.gd` 追加（用该文件既有的建角辅助/世界构造方式）：

```gdscript
	# ---- 计划 03a（§8#69）：哑炮不进霍格沃茨 ----
	var squib_choices := {
		"era_id": "modern", "bloodline_id": "squib", "birth_identity_id": "ordinary_wizard_family",
		"name_text": "测试哑炮", "gender": "未定", "age_years": 11, "birthplace": "london_muggle",
		"family_status": "由系统生成", "aptitude_id": "squib", "aptitude_special": "", "wand": {},
		"house_id": "system", "political_leaning_id": "blood_equality", "personality": ["好奇"],
		"life_goal": "活下去", "sim_style_id": "brutal_realism",
	}
	var squib_res := CharacterCreation.create(squib_choices, reg, RngService.new(5))
	a.eq(squib_res.errors.size(), 0, "哑炮建角无错误")
	a.eq(squib_res.player.house_id, "none", "哑炮不进霍格沃茨（house_id=none）")
	a.is_true(bool(squib_res.player.flags.get("no_magic", false)), "哑炮仍无魔法")

	# 非哑炮：仍然正常分配学院
	var normal_choices := squib_choices.duplicate(true)
	normal_choices["bloodline_id"] = "half_blood"
	normal_choices["aptitude_id"] = "normal"
	var normal_res := CharacterCreation.create(normal_choices, reg, RngService.new(5))
	a.is_true(normal_res.player.house_id != "none", "非哑炮仍会入学")
```

`tests/world_tick_test.gd` 追加：

```gdscript
	# ---- 计划 03a（§8#16）：weight 必须真的生效 ----
	var wrng := RngService.new(99)
	var light: Array = [{"id": "a", "weight": 0.0}, {"id": "b", "weight": 1.0}]
	var picked_b := 0
	for i in 50:
		var picked: Dictionary = wrng.stream_pick_weighted("w_test", light)
		if str(picked.get("id", "")) == "b":
			picked_b += 1
	a.eq(picked_b, 50, "weight=0 的条目永远不会被抽中（50/50 次）")
	var none: Array = [{"id": "a", "weight": 0.0}, {"id": "b", "weight": 0.0}]
	a.is_true(wrng.stream_pick_weighted("w_zero", none) != null, "全零权重回退到均匀抽取，不返回 null")
	a.is_true(wrng.stream_pick_weighted("w_empty", []) == null, "空列表返回 null")
```

`tools/b1_acceptance.gd`：在 `_part2_squib_start()` 里把姓名断言改为「默认不为空但可由玩家修改」并把性别写进盘验；新增两条：

```gdscript
	check((node.get("name_edit") as LineEdit).text.strip_edges() != "无名者", "姓名框不再预填「无名者」")
	check(node.get("gender_dropdown") != null, "创建界面有性别下拉")
```

（`_select(node, "gender", "男")` 后断言 `world.player.gender == "男"` 也一并加上。）

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[creation\]|^\[world_tick\]|总计"`
Expected: 失败（哑炮 `house_id=gryffindor`；`stream_pick_weighted` 未定义）。

- [ ] **Step 3: 实现**

`src/rules/character_creation.gd`：把 `p.house_id = assign_house(choices, rng, registry)` 从公共路径里删掉，改为在哑炮分支与非哑炮分支分别赋值：

```gdscript
	if not has_magic:
		p.magic_tier = MagicLevel.Tier.SQUIB
		p.wand = {}
		p.flags["no_magic"] = true
		p.job = ""
		# §8#69 正典修正（第七章/第二十四章）：哑炮通常被送往麻瓜学校，不进霍格沃茨。
		p.house_id = "none"
	else:
		p.house_id = assign_house(choices, rng, registry)
		...
```

`src/ui/main.gd`：

1) `_show_creation()` 里把姓名框的默认值改掉、并加性别下拉：

```gdscript
	name_edit.text = ""
	name_edit.placeholder_text = "你的名字（例：艾拉·卡文迪什）"
```

```gdscript
	var gender_row := HBoxContainer.new()
	var gender_label := Label.new()
	gender_label.text = "性别"
	gender_label.custom_minimum_size = Vector2(120, 0)
	gender_row.add_child(gender_label)
	gender_dropdown = OptionButton.new()
	for index in ["男", "女", "未定"].size():
		gender_dropdown.add_item(["男", "女", "未定"][index], index)
	gender_dropdown.set_item_metadata(0, "男")
	gender_dropdown.set_item_metadata(1, "女")
	gender_dropdown.set_item_metadata(2, "未定")
	gender_row.add_child(gender_dropdown)
	creation_box.add_child(gender_row)
```

2) 字段区加 `var gender_dropdown: OptionButton = null`，`_show_creation()` 开头把 `gender_dropdown = null` 一并重置（跟着 `dropdowns.clear()`）。

3) `_on_start_pressed()` 里 `"gender": "未定",` 改为：

```gdscript
		"gender": str(gender_dropdown.get_item_metadata(gender_dropdown.selected)),
```

`src/core/rng_service.gd` 加：

```gdscript
# 计划 03a（§8#16/#21）：按权重抽取。权重非正的条目永不被抽中；总权重为 0 时回退到均匀抽取。
func stream_pick_weighted(name: String, entries: Array, weight_key: String = "weight"):
	if entries.is_empty():
		return null
	var total := 0.0
	for e in entries:
		if typeof(e) == TYPE_DICTIONARY:
			total += maxf(float((e as Dictionary).get(weight_key, 1.0)), 0.0)
	if total <= 0.0:
		return stream_pick(name, entries)
	var roll := stream_float(name) * total
	var acc := 0.0
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		acc += maxf(float((e as Dictionary).get(weight_key, 1.0)), 0.0)
		if roll <= acc:
			return e
	return entries[entries.size() - 1]
```

`src/model/world_state.gd` 的 `tick()`：把 `var picked: Dictionary = month_rng.stream_pick("pick_%d" % i, candidates)` 改为：

```gdscript
			var picked: Dictionary = month_rng.stream_pick_weighted("pick_%d" % i, candidates, "weight")
```

并保证事件字典带上 `rumor_id`（供 Task 6 的揭示使用）：在 `var ev := {` 里加 `"rumor_id": str(picked.get("id", "")),`。

`src/rules/character_creation.gd` 的 `generate_wand()`：把杖芯与木材抽取改为加权：

```gdscript
	var wood_entries: Array = []
	for wid in registry.ids("wand_woods"):
		wood_entries.append(registry.entry("wand_woods", str(wid)))
	var wood_entry_pick: Dictionary = rng.stream_pick_weighted("wand_wood", wood_entries, "weight")
	var wood := str(wood_entry_pick.get("id", ""))
	var wood_entry: Dictionary = registry.entry("wand_woods", wood)
	var core_entries: Array = []
	for cid in registry.ids("wand_cores"):
		core_entries.append(registry.entry("wand_cores", str(cid)))
	var core_entry: Dictionary = rng.stream_pick_weighted("wand_core", core_entries, "rarity")
	var core_id := str(core_entry.get("id", ""))
```

> 动手前先跑这两条确认字段名，并把输出贴进报告：
> ```bash
> python -c "import json;print(sorted(json.load(open('data/wand_cores.json',encoding='utf-8'))[0].keys()))"
> python -c "import json;print(sorted(json.load(open('data/wand_woods.json',encoding='utf-8'))[0].keys()))"
> ```
> `wand_cores.json` 必须有 `rarity`；`wand_woods.json` 若无 `weight` 字段，则**保留原均匀抽取不动**（只改杖芯），并在报告里写明「wand_woods 无权重字段，未改」。

- [ ] **Step 4: 验证**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[creation\]|^\[world_tick\]|总计|全部通过" && bash tools/b1_acceptance.sh 2>&1 | grep -E "\[FAIL\]|断言" | tail -5`
Expected: 单测全绿；B1 盘验失败=0（其中骰子学院一项改为断言 `none`）。

- [ ] **Step 5: 提交**

```bash
git add src/rules/character_creation.gd src/ui/main.gd src/core/rng_service.gd src/model/world_state.gd tests/creation_test.gd tests/world_tick_test.gd tools/b1_acceptance.gd
git commit -m "fix(rules,ui): 哑炮不进霍格沃茨 + 创建界面姓名/性别 + 权重/稀有度生效（§8#69/#70/#16/#21）（计划 03a Task 12）"
```

---

### Task 13: 收尾 —— 全绿、台账、文档、B1 复跑、合入 `main`

**Files:**
- Create: `docs/sdd/plan-03a-factions/progress.md`
- Modify: `README.md`、`HANDOFF.md`、`NEXT-STEPS.md`
- Test: 全仓

**Interfaces:**
- Consumes: Task 1–12 的全部产出。
- Produces: 可交接的 `main` 顶端 + 耐久台账。

- [ ] **Step 1: 全量回归**

```bash
cd /e/Hali
bash tools/test.sh                      # 期望 EXIT=0、失败套件=0、4 步全过
bash tools/b1_acceptance.sh             # 期望 断言失败=0、EXIT=0
```

把两段原始输出（含每套件断言数与总计）贴进报告。

- [ ] **Step 2: 写台账 `docs/sdd/plan-03a-factions/progress.md`**

按 `docs/sdd/plan-02-llm-narrative/progress.md` 的格式，逐任务记：brief → worker 提交哈希 → 绿灯断言数（前后对比）→ 审查结论/严重度 → 修复提交 → scoped 复审结论 → 残余。并把每个任务的 `task-N-brief.md` / `task-N-report.md` / `review-<from>..<to>.diff` 一并复制到 `docs/sdd/plan-03a-factions/`，与代码同一次提交。

- [ ] **Step 3: 更新文档**

1) `HANDOFF.md`：§8#7/#16/#21/#58/#61/#62/#63/#64/#65/#69/#70 全部标为**已闭合**（写明提交哈希）；新增一节「计划 03a 的关键结论」（机构控制权模型、政体推导、tension、信息保护、`stream_pick_weighted`）；§2 的测试输出样例与套件数按实测更新（新增 `[factions]`）；§0 一句话状态改为「计划 03a 完成」。
2) `README.md`：进度表加「计划 03a · 派系与政治骨架（已完成）」；「当前进度」列表更新；补一句「游戏内可用自然语言加入/支持/反对派系（例：我要加入魔法部 / 我公开支持凤凰社）」。
3) `NEXT-STEPS.md`：B3 标为 03a 已完成；新增「B4 计划 03b 经济骨架」与「B5 计划 03c 社会与法律」两个待办（边界照 spec §14）。

- [ ] **Step 4: 合入 `main`**

```bash
git checkout main && git merge --no-ff plan-03-factions -m "merge: 计划 03a 派系与政治骨架（Tasks 1–13）"
bash tools/test.sh    # 合入后再跑一次
```

- [ ] **Step 5: 提交并推送**

```bash
git add docs/sdd/plan-03a-factions README.md HANDOFF.md NEXT-STEPS.md
git commit -m "docs: 计划 03a 收尾（台账 + README/HANDOFF/NEXT-STEPS）"
git push origin main
git push origin plan-03-factions
```

---

## 执行交接

计划已落在 `docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md`。两种执行方式：

1. **子代理驱动（推荐）**：每任务派一个新鲜子代理（`pi -p --provider deepseek --model deepseek-flash`），任务间由控制器审阅，迭代快；每任务遵仓库铁律：brief → worker → 自跑绿灯 → **先写报告再返回** → 只读 reviewer 审 `review-<from>..<to>.diff` → 台账。
2. **本会话内联执行**：按 `executing-plans` 批量执行，在检查点停下来给你评审。

> 两个提醒：① Task 10/11/12 都是「顺手项」，可以按你的时间偏好调到派系主线（Task 1–9）之后单独跑；② 每个任务完成后都必须更新 `docs/sdd/plan-03a-factions/progress.md` 并把工件复制进仓库（HANDOFF §7 的耐久副本规则）。
