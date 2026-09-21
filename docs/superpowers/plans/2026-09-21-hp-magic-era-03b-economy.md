# 计划 03b · 经济骨架 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现本计划。步骤用 `- [ ]` 复选框跟踪。
> Spec：`docs/superpowers/specs/2026-09-21-hp-magic-era-03b-economy-design.md`（已通过用户评审，2026-09-21）。
> 分支：`plan-03b-economy`（从 `main`@`dfce590`）。计划日期：2026-09-21。

**Goal:** 把「钱」从孤零零的整数变成会流动、有摩擦、可经营的经济系统：商品与价格表 → 玩家收入/支出流（月度结算）→ 古灵阁（存款/利息/汇率）→ 贸易价差与走私 → 经济危机连锁 → 债务显示 → 面板与经济指标接线。

**Architecture:** 新增 `src/rules/economy.gd`（`class_name Economy`，静态函数，纯规则层）承载全部经济逻辑；状态存在**新增的** `WorldState.economy` 字典（存档格式不升版本）；`tick()` 只**追加**两个阶段（`evolve` + `monthly_settlement`），既有 7 步语义与顺序不动；4 个新 op 走既有 `StateOps` 唯一入口；面板与提示词只读。**`Economy` 对 03a 的 `economy_index` 只读挂接**（不写 `factions`）。

**Tech Stack:** Godot 4.7.2 stable（非 .NET）、纯 GDScript、无第三方依赖、不联网；测试入口 `bash tools/test.sh`（4 步：导入 → 单测 → 默认冒烟 → 调试镜像冒烟）。

## Global Constraints

以下约束对**每个任务**都生效，不再逐条重复：

- 引擎固定 **Godot 4.7.2 stable / Windows 64-bit / 非 .NET**；只写 GDScript；不引入第三方插件、外部素材、网络依赖。
- **内容一律进 `data/*.json`**，代码不硬编码内容（商品名、产业名、单位量词都是内容）。代码里只允许硬编码**枚举与实体 id**（`wand_standard` 等）。
- **价格是内容，演算是代码**：`base_price_knuts` 进 `data/goods.json`；`era_mult`/`scarcity_mult`/`local_mult` 的**系数**进 `Economy` 常量（属演化参数，非玩家可见文本）。
- `to_dict()` 只放 JSON 原生类型（Dictionary / Array / String / int / float / bool / null），且整体过 `JsonUtil.normalize()`（否则 `{"n":493} != {"n":493.0}`，存读档往返断言必挂）。
- **新增测试套件必须把路径追加到 `tests/run_tests.gd` 的 `SUITES`**，否则不会被执行。
- **新脚本连 `.gd.uid` 一起 `git add`**（Godot 4.4+ 用 `.uid` 锁定脚本标识）。
- **提交前必须有绿灯**：`bash tools/test.sh` 必须 `EXIT=0`，报告里贴原始输出（含每套件断言数）。
- 正典优先：`哈利·波特·魔法纪元.md` 与本计划冲突时**改计划**，并在报告里写明依据行号。
- 随机数一律走 `RngService` 命名流，禁止 `randf()`/`randi()` 裸调用。
- **`Economy.CRISIS_THRESHOLD` 必须只有一个来源**：`factions.gd:369` 的既有硬编码 `0.35` 必须改为引用它（或两侧都留「与 `Economy.CRISIS_THRESHOLD` 同步」注释）。**不得出现第二个硬编码 0.35**。
- **`supply` 不进价格公式**（spec §7.4 C5）—— 只决定 `available()` 与断供。
- 子代理与主会话同模型：`pi -p --provider deepseek --model deepseek-flash ...`；审查者只读（`pi -p --tools read,bash`）。
- 不要并发跑两个 headless 实例（会争 `.godot` 缓存）；卡住时 `tasklist | grep -i godot` + `taskkill //PID <PID> //F`。
- 每完成一个任务：brief → 实现 → 自跑绿灯 → **先写报告文件再返回** → 只读 reviewer 审 diff → 台账 `docs/sdd/plan-03b-economy/progress.md` → 把 brief/report/review/审查包复制进 `docs/sdd/plan-03b-economy/` 与代码同一次提交。

## 价格定版（spec §7.4 实算结果，**照抄，不要自创**）

```gdscript
const NEUTRAL_INDEX         := 0.5    # canon 常态价的定义基准
const NEUTRAL_ERA_YEAR      := 1950   # canon 价位语境的时代（era_mult == 1.0）
const MIN_SCARCITY          := 0.75   # 繁荣侧地板
const MAX_SCARCITY          := 1.40   # 危机侧天花板（由魔杖区间 1.4286x 反推）
const CRISIS_THRESHOLD      := 0.35   # 危机态（与 factions.gd:369 共用）
const SUPPLY_CUTOFF         := 0.15   # 断供线（与危机线解耦）
const MONOPOLY_EXCESS_MULT  := 2.0    # 垄断行业涨价侧超额部分加倍
const LOCAL_MULT            := {"产地": 0.85, "常规": 1.0, "偏远": 1.2, "黑市": 1.35}
# 缺省 1.0（缺省必须安全）

const ERA_MULT := [
	{y_max: 1000, mult: 0.35}, {y_max: 1691, mult: 0.55}, {y_max: 1945, mult: 0.85},
	{y_max: 1980, mult: 1.00}, {y_max: 1998, mult: 1.15}, {y_max: 99999, mult: 1.10},
]
```

```
price = roundi( base_price_knuts × era_mult × scarcity_mult × local_mult )
raw_scarcity = index >= 0.5 ? 1.0 - (index-0.5)*0.2 : 1.0 + (0.5-index)*1.2
if monopoly and raw_scarcity > 1.0: raw_scarcity = 1.0 + (raw_scarcity-1.0)*2.0
scarcity_mult = clampf(raw_scarcity, MIN_SCARCITY, MAX_SCARCITY)
```

**C1–C6 验收契约（每个价格任务都要自检）**：
- C1 常态（`index=0.5`/**`era_mult == 1.0` 的时代**/`local=1.0`）价 == `base_price_knuts`
  > ⚠️ **不是 `modern`！**（2026-09-21 Task 2 施工澄清）`modern`（2010）落 `1.10` 档，
  > 把 `modern` 当定义点会让危机峰价被时代系数顶出 `canon_hi`（3451×1.10×1.40 = **5315 > 4930**）。
  > `NEUTRAL_ERA_YEAR = 1950` 与 `ERA_MULT` 的中性档（`y ≤ 1980`，实际命中 `first_wizarding_war` 1970）一致。
- C2 对 `economy_index` 单调不增
- C3 危机侧最大值 `<= canon_hi`
- C4 繁荣侧可低于 `canon_lo`（记录不阻断）
- C5 `supply` 不进价格
- C6 `canon_price_knuts` = 区间下沿；`base_price_knuts` = 常态价；**二者不强制相等**

## 文件结构（先锁边界，再拆任务）

| 文件 | 状态 | 职责 |
| --- | --- | --- |
| `data/goods.json` | 新建（Task 1） | 商品与服务 **35 条**（25 goods + 10 service），schema 见 spec §7.1 |
| `data/industries.json` | 新建（Task 1） | 9 大产业，含 `produces`/`base_output`/`monopoly` |
| `src/rules/economy.gd` | 新建（Task 1 只放常量；Task 2+ 加函数） | `class_name Economy`：算价 / 可得性 / 结算 / 危机 / 汇率 / 利率 / 贸易 / 走私 |
| `src/core/registry.gd` | 改（Task 1） | `TABLE_FILES` 注册两表 + `validate()` 字段与引用校验 |
| `src/model/world_state.gd` | 改（Task 2 加字段与 `initialize`；Task 6 加 tick 阶段） | 唯一时间推进入口 |
| `src/model/money.gd` | 改（Task 3） | `is_debt()` / `debt_formatted()` / `formatted()` 负值分支 |
| `src/rules/state_ops.gd` | 改（Task 4） | 4 个新 op |
| `src/gm/op_guard.gd` | 改（Task 4） | 4 个新 op 的金额钳制 |
| `src/persist/save_codec.gd` | 改（Task 2） | `economy` 进字典字段白名单（**不升 `save_version`**） |
| `src/rules/factions.gd` | 改（Task 2，**只改常量引用**） | `:369` 的 `0.35` 改引 `Economy.CRISIS_THRESHOLD` |
| `src/ui/panel_formatter.gd` | 改（Task 7） | 【财富】含存款 + 新增【经济】行 |
| `src/gm/prompt_builder.gd` | 改（Task 8） | `state_digest` 加经济摘要（只给已揭示信息） |
| `src/gm/scripted_game_master.gd` | 改（Task 9） | 经济关键词 → 新 op（离线替身也要能用） |
| `data/rumors.json` | 改（Task 10） | 经济类传闻（物价飞涨/古灵阁挤兑/黑市繁荣） |
| `tests/economy_test.gd` | 新建（Task 2） | 价格/可得性/结算/危机/古灵阁/贸易/确定性（**必须进 `SUITES`**） |
| `tests/money_test.gd`、`tests/panel_test.gd`、`tests/save_test.gd`、`tests/registry_test.gd`、`tests/gm_test.gd`、`tests/llm_test.gd` | 改 | 各任务自带断言 |
| `tools/b1_acceptance.gd` | 改（Task 11） | 经济可观测契约 |
| `docs/sdd/plan-03b-economy/` | 新建（Task 12 及每任务追加） | 耐久台账/简报/报告/审查包 |
| `README.md`、`HANDOFF.md`、`NEXT-STEPS.md` | 改（Task 12） | 收尾 |

**依赖方向（单向，禁止反向）：** `data/` → `Registry` → `Economy` → `WorldState.tick()` / `StateOps` / `PanelFormatter` / `PromptBuilder`。`Economy` **不得** `preload` 任何 `src/ui/` 或 `src/gm/` 脚本，**不得**写 `world.factions` / `player.standing`。

---

### Task 1: 内容表 `goods` / `industries` + Registry 注册与字段校验

**Files:**
- Create: `data/goods.json`、`data/industries.json`、`src/rules/economy.gd`（本任务只放常量）
- Modify: `src/core/registry.gd`（`TABLE_FILES` + `validate()`）
- Test: `tests/registry_test.gd`

**Interfaces:**
- Consumes: 无（本任务是最底层内容）。
- Produces:
  - 表名 `"goods"` / `"industries"`，可用 `Registry.ids(...)` / `Registry.entry(...)` / `Registry.has(...)` 访问。
  - `Economy.CATEGORIES: Array[String]`（10 个：`wand/potion/material/broom/book/food/service/creature/artifact/illegal`，**顺序即面板展示顺序**）
  - `Economy.KINDS: Array[String]` := `["goods", "service"]`
  - 上表 §价格定版 的全部常量。
  - 商品条目字段契约：`id, label, category, kind, canon_price_knuts, canon_price_hi_knuts, canon_line, base_price_knuts, industry_id, illegal, supply_critical, unit`
  - 产业条目字段契约：`id, label, canon_line, produces, base_output, monopoly`

- [ ] **Step 1: 写失败测试**

在 `tests/registry_test.gd` 的 `run()` 末尾（`return a.report("registry")` 之前）追加：

```gdscript
	# ---- 计划 03b：商品与产业内容表 ----
	var goods := reg.ids("goods")
	a.eq(goods.size(), 35, "商品表 35 条")
	var cats := ["wand", "potion", "material", "broom", "book", "food",
		"service", "creature", "artifact", "illegal"]
	var kinds := ["goods", "service"]
	var n_service := 0
	var n_anchor := 0
	for gid in goods:
		var e := reg.entry("goods", str(gid))
		a.is_true(cats.has(str(e.get("category", ""))), "%s: category 合法" % gid)
		a.is_true(kinds.has(str(e.get("kind", ""))), "%s: kind 合法" % gid)
		a.is_true(int(e.get("base_price_knuts", 0)) > 0, "%s: base_price > 0" % gid)
		a.is_true(int(e.get("canon_price_knuts", 0)) >= 0, "%s: canon_price >= 0" % gid)
		a.is_true(not str(e.get("unit", "")).is_empty(), "%s: 有 unit" % gid)
		var iid := str(e.get("industry_id", ""))
		if str(e.get("kind", "")) == "service":
			n_service += 1
		else:
			a.is_true(reg.has("industries", iid), "%s: industry_id %s 存在" % [gid, iid])
		if int(e.get("canon_price_knuts", 0)) > 0:
			n_anchor += 1
			a.eq(int(e.get("canon_line", 0)), 223, "%s: 锚点商品 canon_line=223" % gid)
	a.eq(n_service, 10, "服务类 10 条")
	a.eq(n_anchor, 4, "正典锚点商品 4 条")

	# 正典锚点必须与正典原文数值一致（钉死，防改价时忘了正典）
	a.eq(int(reg.entry("goods", "wand_standard")["canon_price_knuts"]), 3451, "普通魔杖 canon 7 加隆")
	a.eq(int(reg.entry("goods", "potion_healing")["canon_price_knuts"]), 2465, "优质疗伤 canon 5 加隆")
	a.eq(int(reg.entry("goods", "broom_nimbus")["canon_price_knuts"]), 49300, "光轮 canon 100 加隆")

	var inds := reg.ids("industries")
	a.eq(inds.size(), 9, "产业表 9 条")
	for iid2 in ["potion_brewing", "wandmaking", "broommaking", "publishing", "quidditch",
			"creature_breeding", "archaeology", "curse_breaking", "finance"]:
		a.is_true(reg.has("industries", str(iid2)), "产业 %s 存在" % str(iid2))
	for iid3 in inds:
		var e3 := reg.entry("industries", str(iid3))
		a.between(float(e3.get("base_output", -1.0)), 0.0, 1.0, "%s: base_output 在 0..1" % iid3)
		for p in (e3.get("produces", []) as Array):
			a.is_true(reg.has("goods", str(p)), "%s: produces %s 存在" % [iid3, str(p)])

	# 校验器必须抓到坏商品内容
	var bad_goods := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "x", "label": "坏商品", "category": "bogus", "kind": "goods",
			"base_price_knuts": 10, "industry_id": "", "unit": "个"}],
		"industries": [{"id": "i", "label": "产业", "produces": [], "base_output": 0.5}],
	})
	a.is_false(bad_goods.validate().is_empty(), "坏 category 被抓到")

	# 引用不存在的 industry 也要被抓到
	var bad_ref := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "y", "label": "孤儿商品", "category": "wand", "kind": "goods",
			"base_price_knuts": 10, "industry_id": "nonexistent", "unit": "根"}],
		"industries": [{"id": "i", "label": "产业", "produces": [], "base_output": 0.5}],
	})
	a.is_false(bad_ref.validate().is_empty(), "坏 industry_id 引用被抓到")

	# base_price 落到正典合理带之外要被抓到（C3/C6：base 不得使危机价突破 canon_hi）
	var bad_band := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "z", "label": "价格离谱", "category": "wand", "kind": "goods",
			"canon_price_knuts": 3451, "canon_price_hi_knuts": 4930, "canon_line": 223,
			"base_price_knuts": 999999, "industry_id": "i", "unit": "根"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["z"], "base_output": 0.7}],
	})
	a.is_true(" | ".join(bad_band.validate()).contains("超出正典合理带"),
		"base_price 超出正典合理带被抓到")

	# base 在 canon 区间内、但危机峰价突破 canon_hi —— 也必须被抓到（这才是 C3 的本体）
	var bad_peak := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "z2", "label": "危机越界", "category": "wand", "kind": "goods",
			"canon_price_knuts": 3451, "canon_price_hi_knuts": 4930, "canon_line": 223,
			"base_price_knuts": 4900, "industry_id": "i", "unit": "根"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["z2"], "base_output": 0.7}],
	})
	a.is_true(" | ".join(bad_peak.validate()).contains("危机峰价突破正典上沿"),
		"危机峰价突破 canon_hi 被抓到")

	# 锚点商品缺 canon_line / canon_price_hi 也要被抓到
	var bad_line := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "w", "label": "缺行号", "category": "wand", "kind": "goods",
			"canon_price_knuts": 3451, "canon_price_hi_knuts": 4930, "canon_line": 0,
			"base_price_knuts": 3451, "industry_id": "i", "unit": "根"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["w"], "base_output": 0.7}],
	})
	a.is_true(" | ".join(bad_line.validate()).contains("canon_line"),
		"锚点商品缺 canon_line 被抓到")

	var bad_hi := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "w2", "label": "缺上沿", "category": "wand", "kind": "goods",
			"canon_price_knuts": 3451, "canon_price_hi_knuts": 0, "canon_line": 223,
			"base_price_knuts": 3451, "industry_id": "i", "unit": "根"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["w2"], "base_output": 0.7}],
	})
	a.is_true(" | ".join(bad_hi.validate()).contains("canon_price_hi_knuts"),
		"锚点商品缺 canon_price_hi 被抓到")

	# 顶级疗伤药剂（共享 canon 区间、base 取上段）必须**不被**误判 —— 这是补 canon_price_hi 字段的原因
	var premium_ok := Registry.from_tables({
		"eras": [{"id": "a", "label": "甲"}],
		"goods": [{"id": "p", "label": "顶级", "category": "potion", "kind": "goods",
			"canon_price_knuts": 2465, "canon_price_hi_knuts": 9860, "canon_line": 223,
			"base_price_knuts": 6162, "industry_id": "i", "unit": "瓶"}],
		"industries": [{"id": "i", "label": "产业", "produces": ["p"], "base_output": 0.75}],
	})
	a.is_false(" | ".join(premium_ok.validate()).contains("goods/p"),
		"共享 canon 区间取上段的条目不被误判（p）")
```

> ⚠️ 上面的 `Registry.from_tables(...)` / `validate()` / `is_false` 用法**必须照抄 `tests/registry_test.gd` 里 03a 已用的同款 API**（Task 1 开工前先读该文件确认签名，不要凭记忆写）。

- [ ] **Step 2: 跑测试确认红**

```bash
cd /e/Hali
bash tools/test.sh 2>&1 | grep -A5 "registry"
```
期望：`registry` 套件失败（`goods` 表不存在 ⇒ `reg.ids("goods").size() == 0 != 35`）。

- [ ] **Step 3: 写内容表**

把下面两份 JSON **原样写入**（数值已由 Python 实算脚本验证通过 C1–C6，见 spec §13 风险 8）。

`data/industries.json`：

```json
[
  {"id":"potion_brewing","label":"魔药酿造","canon_line":211,"base_output":0.75,"monopoly":false,
   "produces":["potion_healing","potion_healing_premium","potion_common","illegal_potion"]},
  {"id":"wandmaking","label":"魔杖制造","canon_line":211,"base_output":0.70,"monopoly":true,
   "produces":["wand_standard","wand_elder","mat_wand_wood","mat_wand_core"]},
  {"id":"broommaking","label":"扫帚制造","canon_line":211,"base_output":0.65,"monopoly":false,
   "produces":["broom_nimbus","broom_standard"]},
  {"id":"publishing","label":"出版","canon_line":211,"base_output":0.85,"monopoly":false,
   "produces":["book_standard","book_rare","food_butterbeer","food_pumpkin_pastry"]},
  {"id":"quidditch","label":"魁地奇","canon_line":211,"base_output":0.80,"monopoly":false,
   "produces":["svc_quidditch_ticket"]},
  {"id":"creature_breeding","label":"神奇生物养殖","canon_line":211,"base_output":0.60,"monopoly":false,
   "produces":["mat_herb","mat_dragon_blood","mat_phoenix_tear","mat_unicorn_hair","creature_owl","creature_pygmy_puff","illegal_creature"]},
  {"id":"archaeology","label":"魔法考古","canon_line":211,"base_output":0.45,"monopoly":false,
   "produces":["mat_ore","illegal_relic"]},
  {"id":"curse_breaking","label":"解咒","canon_line":211,"base_output":0.55,"monopoly":false,
   "produces":["artifact_ring","artifact_detector"]},
  {"id":"finance","label":"金融","canon_line":211,"base_output":0.90,"monopoly":true,
   "produces":["svc_gringotts_fee","svc_bank_vault"]}
]
```

`data/goods.json`：**35 条**，逐条字段见下面这张表（`base_price_knuts` 已实算，直接抄；`canon_price_knuts=0` 表示推演值）。

> ⚠️ **`canon_price_hi_knuts` 是 2026-09-21 Task 1 施工时补的字段**（spec §7.1 同步更新）：
> 原设计用 `canon_lo × MAX_SCARCITY / MIN_SCARCITY` 反推上界，会把 `potion_healing_premium`
> （与 `potion_healing` 共享 canon 区间、base 取上段）误判为越界。上界改为**直接存正典区间上沿**。
> 只有 4 条带 canon 价位的条目有非零值，其余一律 `0`。

| id | label | category | kind | industry_id | base_price_knuts | canon_price_knuts | canon_price_hi_knuts | canon_line | illegal | supply_critical | unit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| wand_standard | 普通魔杖 | wand | goods | wandmaking | 3451 | 3451 | 4930 | 223 | false | true | 根 |
| potion_healing | 优质疗伤药剂 | potion | goods | potion_brewing | 2465 | 2465 | 9860 | 223 | false | true | 瓶 |
| potion_healing_premium | 顶级疗伤药剂 | potion | goods | potion_brewing | 6162 | 2465 | 9860 | 223 | false | true | 瓶 |
| broom_nimbus | 光轮扫帚 | broom | goods | broommaking | 49300 | 49300 | 147900 | 223 | false | false | 把 |
| wand_elder | 接骨木魔杖 | wand | goods | wandmaking | 22185 | 0 | 0 | 0 | false | false | 根 |
| potion_common | 常用药剂 | potion | goods | potion_brewing | 986 | 0 | 0 | 0 | false | false | 瓶 |
| mat_herb | 草药 | material | goods | creature_breeding | 2 | 0 | 0 | 0 | false | false | 份 |
| mat_dragon_blood | 龙血 | material | goods | creature_breeding | 5916 | 0 | 0 | 0 | false | true | 品脱 |
| mat_phoenix_tear | 凤凰眼泪 | material | goods | creature_breeding | 11832 | 0 | 0 | 0 | false | true | 滴 |
| mat_unicorn_hair | 独角兽尾毛 | material | goods | creature_breeding | 3944 | 0 | 0 | 0 | false | true | 束 |
| mat_wand_wood | 魔杖木材 | material | goods | wandmaking | 986 | 0 | 0 | 0 | false | false | 块 |
| mat_wand_core | 魔杖杖芯 | material | goods | wandmaking | 1479 | 0 | 0 | 0 | false | false | 条 |
| mat_ore | 魔法矿石 | material | goods | archaeology | 493 | 0 | 0 | 0 | false | false | 块 |
| broom_standard | 普通扫帚 | broom | goods | broommaking | 5916 | 0 | 0 | 0 | false | false | 把 |
| book_standard | 标准咒语书 | book | goods | publishing | 493 | 0 | 0 | 0 | false | false | 本 |
| book_rare | 古籍 | book | goods | publishing | 9860 | 0 | 0 | 0 | false | false | 本 |
| food_butterbeer | 黄油啤酒 | food | goods | publishing | 2 | 0 | 0 | 0 | false | false | 杯 |
| food_pumpkin_pastry | 南瓜馅饼 | food | goods | publishing | 1 | 0 | 0 | 0 | false | false | 个 |
| creature_owl | 猫头鹰 | creature | goods | creature_breeding | 3944 | 0 | 0 | 0 | false | false | 只 |
| creature_pygmy_puff | 侏儒蒲绒绒 | creature | goods | creature_breeding | 986 | 0 | 0 | 0 | false | false | 只 |
| artifact_ring | 附魔戒指 | artifact | goods | curse_breaking | 5916 | 0 | 0 | 0 | false | false | 枚 |
| artifact_detector | 探测仪 | artifact | goods | curse_breaking | 3451 | 0 | 0 | 0 | false | false | 台 |
| illegal_creature | 禁售神奇生物 | illegal | goods | creature_breeding | 14790 | 0 | 0 | 0 | true | false | 只 |
| illegal_relic | 黑市文物 | illegal | goods | archaeology | 9860 | 0 | 0 | 0 | true | false | 件 |
| illegal_potion | 违禁药剂 | illegal | goods | potion_brewing | 4930 | 0 | 0 | 0 | true | false | 瓶 |
| svc_rent | 房租（月） | service | service | （空串） | 4437 | 0 | 0 | 0 | false | false | 月 |
| svc_tuition | 学费（学期） | service | service | （空串） | 8874 | 0 | 0 | 0 | false | false | 学期 |
| svc_train_ticket | 火车票 | service | service | （空串） | 493 | 0 | 0 | 0 | false | false | 张 |
| svc_healing | 治疗费 | service | service | （空串） | 986 | 0 | 0 | 0 | false | false | 次 |
| svc_curse_break | 解咒服务 | service | service | （空串） | 4437 | 0 | 0 | 0 | false | false | 次 |
| svc_owl_post | 猫头鹰邮政 | service | service | （空串） | 17 | 0 | 0 | 0 | false | false | 封 |
| svc_apparition_license | 幻影移形考试费 | service | service | （空串） | 5423 | 0 | 0 | 0 | false | false | 次 |
| svc_quidditch_ticket | 魁地奇球票 | service | service | quidditch | 986 | 0 | 0 | 0 | false | false | 张 |
| svc_gringotts_fee | 古灵阁手续费 | service | service | finance | 493 | 0 | 0 | 0 | false | false | 次 |
| svc_bank_vault | 金库年费 | service | service | finance | 986 | 0 | 0 | 0 | false | false | 年 |

> **服务类没有 `inputs`**（`kind == "service"` ⇒ 不参与断供、不参与 `supply`）；`industry_id` 为空串对服务合法。
> **`potion_healing_premium` 的 `canon_price_knuts` 也是 2465**（正典只给了「优质疗伤药剂 5–20 加隆」一个区间，顶级档是该区间的上段，故 canon 锚点同为下沿）。
> **`wand_elder`（接骨木）与 `broom_standard`（普通扫帚）等凡 `canon_price_knuts == 0` 的都是推演值** —— 其 `base_price_knuts` 由「常态设计价」反解、经实算复现验证。

- [ ] **Step 4: 写 `src/rules/economy.gd` 的常量骨架**

```gdscript
class_name Economy
extends RefCounted

## 计划 03b · 经济规则层（静态函数，纯规则，不依赖 UI/GM）
## 数值口径见 spec §7.4，全部经 Python 实算脚本验证（C1–C6）。

const NEUTRAL_INDEX := 0.5
const NEUTRAL_ERA_YEAR := 1950
const MIN_SCARCITY := 0.75
const MAX_SCARCITY := 1.40
const CRISIS_THRESHOLD := 0.35
const SUPPLY_CUTOFF := 0.15
const MONOPOLY_EXCESS_MULT := 2.0
const LOCAL_MULT := {"产地": 0.85, "常规": 1.0, "偏远": 1.2, "黑市": 1.35}
const LOCAL_MULT_DEFAULT := 1.0

const CATEGORIES: Array[String] = ["wand", "potion", "material", "broom", "book",
	"food", "service", "creature", "artifact", "illegal"]
const KINDS: Array[String] = ["goods", "service"]

## 路费（纳特/件，按 category；服务无路费）。spec §7.5 trade_money。
const TRADE_HAUL_KNUTS := {
	"service": 0, "food": 2, "material": 5, "book": 10, "potion": 20,
	"wand": 30, "artifact": 50, "broom": 60, "creature": 80, "illegal": 120,
}

const FOREIGN_SPREAD := 0.02   # 外币买卖价差（spec §7.5 exchange_money）
const INTEREST_RATE := 0.002          # 古灵阁月息（常态）
const INTEREST_RATE_CRISIS := 0.0012  # 危机期利率（spec §7.4 第 7 条）
const SMUGGLING_PROFIT_MULT_CRISIS := 1.5
```

同时把 `goods` / `industries` 加进 `src/core/registry.gd` 的 `TABLE_FILES`（**照抄既有条目的写法**），并在 `validate()` 里加两表的字段与引用校验：

- `goods`：`category ∈ Economy.CATEGORIES`、`kind ∈ Economy.KINDS`、`base_price_knuts > 0`、
  `canon_price_knuts >= 0`、`unit` 非空、`kind == "goods"` 时 `industry_id` 必须存在于 `industries`、
  `canon_price_knuts > 0` 时 `canon_line > 0`、`canon_price_hi_knuts > 0`，
  且**两条一起查**：① `base_price_knuts ∈ [canon_price_knuts, canon_price_hi_knuts]`；
  ② `roundi(base_price_knuts × MAX_SCARCITY) <= canon_price_hi_knuts`（C3）。
  ⚠️ **上界必须来自 `canon_price_hi_knuts` 字段本身**，不得用 `canon_lo × MAX_SCARCITY / MIN_SCARCITY` 反推
  —— 该推导式假设「一条商品 = 一个 canon 窗口且 base 就在下沿」，被 `potion_healing_premium` 打破
  （2026-09-21 Task 1 施工实况；详见 spec §7.1）。
- `industries`：`base_output ∈ [0,1]`、`produces` 每条必须存在于 `goods`、`monopoly` 是 bool。

> ⚠️ **不要在 Task 1 就引用 `Economy.CATEGORIES` 常量若 `registry.gd` 会因此产生循环 preload**
> （`Registry` ← `Economy` 是反向依赖）。若有循环风险，就把白名单**字面量**写在 `registry.gd` 里，
> 并在两侧注释「与 `Economy.CATEGORIES` 必须同步」。**先跑一次 `tools/test.sh` 确认没有循环加载错误**。

- [ ] **Step 5: 跑测试确认绿**

```bash
bash tools/test.sh
```
期望：`EXIT=0`，`registry` 套件断言数比 03a 增加约 200+，失败 0。

- [ ] **Step 6: 提交**

```bash
git add data/goods.json data/industries.json src/rules/economy.gd src/rules/economy.gd.uid src/core/registry.gd tests/registry_test.gd
git commit -m "feat(03b): 商品与产业内容表 + Economy 常量骨架 + Registry 校验"
```

---

### Task 2: `Economy` 算价核心 + `WorldState.economy` 字段 + 存档白名单 + 危机常量单源

**Files:**
- Modify: `src/rules/economy.gd`（加函数）、`src/model/world_state.gd`（字段/`create`/`from_dict`）、`src/persist/save_codec.gd`、`src/rules/factions.gd`（**只改 `:369` 的常量引用**）
- Test: `tests/economy_test.gd`（新建，**必须进 `SUITES`**）、`tests/save_test.gd`

**Interfaces:**
- Consumes: Task 1 的两张表与常量。
- Produces:
  - `static func price_of(world: WorldState, good_id: String) -> int`
  - `static func price_factors(world: WorldState, good_id: String) -> Dictionary`
    → `{"base": int, "era_mult": float, "scarcity_mult": float, "local_mult": float}`（**无 `supply_mult`**，C5）
  - `static func era_mult_for(world: WorldState) -> float`
  - `static func scarcity_mult_for(world: WorldState, industry_id: String) -> float`
  - `static func local_mult_for(world: WorldState, good_id: String) -> float`
  - `static func is_crisis(world: WorldState) -> bool`
  - `static func available(world: WorldState, good_id: String) -> bool`
  - `static func effective_output(world: WorldState, industry_id: String) -> float`
  - `static func initialize(world: WorldState) -> void`
  - `WorldState.economy: Dictionary`（结构见 spec §7.3）

- [ ] **Step 1: 写失败测试**

新建 `tests/economy_test.gd`，**照抄既有套件的骨架**（`tests/factions_test.gd` 的 `extends` / `run()` / `Assert` 用法），并**立即把 `"tests/economy_test.gd"` 追加进 `tests/run_tests.gd` 的 `SUITES`**（否则不执行）。核心断言：

```gdscript
	# ---- C1：常态价 == base_price_knuts ----
	var w := _make_world(1950, 0.5)     # era 取「era_mult == 1.0 的中性时代」, economy_index=0.5
	for gid in ["wand_standard", "potion_healing", "broom_nimbus", "svc_rent"]:
		var e := Registry.entry("goods", gid)
		a.eq(Economy.price_of(w, gid), int(e["base_price_knuts"]),
			"C1 常态价 == base: %s" % gid)

	# ---- C2：单调不增（1000 点扫描）----
	var prev := 1 << 30
	for i in range(1001):
		var idx := float(i) / 1000.0
		w.vars["economy_index"] = idx
		var p := Economy.price_of(w, "wand_standard")
		if p > 0:
			a.is_true(p <= prev, "C2 单调不增 @idx=%.3f (%d <= %d)" % [idx, p, prev])
			prev = p

	# ---- C3：危机侧不突破 canon 上沿 ----
	for gid2 in ["wand_standard", "potion_healing"]:
		var e2 := Registry.entry("goods", gid2)
		var hi := 0
		for i in range(151, 1001):
			w.vars["economy_index"] = float(i) / 1000.0
			hi = maxi(hi, Economy.price_of(w, gid2))
		# canon_hi 由「锚点区间」推出：wand_standard 上沿 = 10 加隆
		a.is_true(hi <= 4930, "C3 危机侧 <= canon_hi: %s (%d)" % [gid2, hi])

	# ---- C5：supply 不进价格（反证实验的正面断言）----
	# 把某产业 base_output 从 0.7 改成 0.1，价格必须**一模一样**
	w.vars["economy_index"] = 0.8
	var p_before := Economy.price_of(w, "wand_standard")
	_mutate_industry_base_output("wandmaking", 0.1)
	a.eq(Economy.price_of(w, "wand_standard"), p_before, "C5 改 base_output 不影响价格")
	_mutate_industry_base_output("wandmaking", 0.7)

	# ---- 断供线与危机线必须不同 ----
	a.is_true(Economy.SUPPLY_CUTOFF < Economy.CRISIS_THRESHOLD, "断供线低于危机线")
	w.vars["economy_index"] = 0.20   # 危机中但有货
	a.is_true(Economy.is_crisis(w), "0.20 处于危机")
	a.is_true(Economy.available(w, "wand_standard"), "0.20 仍可供货")
	w.vars["economy_index"] = 0.10   # 断供
	a.is_true(not Economy.available(w, "wand_standard"), "0.10 断供")
	a.eq(Economy.price_of(w, "wand_standard"), 0, "断供时 price_of == 0")

	# ---- 垄断行业涨幅更大，但仍守上沿 ----
	w.vars["economy_index"] = 0.30
	a.is_true(Economy.price_of(w, "wand_elder") > 0, "垄断行业可定价")
	# 比较同 base 的垄断/非垄断（用 price_factors 的 scarcity_mult）
	a.is_true(Economy.scarcity_mult_for(w, "wandmaking") >= Economy.scarcity_mult_for(w, "publishing"),
		"垄断行业 scarcity_mult 不低于非垄断")

	# ---- 缺 location 标签时 local_mult == 1.0（缺省安全）----
	a.eq(Economy.local_mult_for(w, "wand_standard"), 1.0, "缺省 local_mult == 1.0")

	# ---- 存档往返：economy 必须活下来 ----
	var blob := world_to_dict(w)
	var w2 := world_from_dict(blob)
	a.eq(w2.economy.size(), w.economy.size(), "economy 往返键数一致")
	a.eq(int(w2.economy["gringotts_balance"]), int(w.economy["gringotts_balance"]), "存款往返一致")

	# ---- 老存档补齐（无 economy）----
	var legacy := world_to_dict(_make_world(1950, 0.5))
	legacy["economy"] = null
	var w3 := world_from_dict(legacy)
	a.is_true(not w3.economy.is_empty(), "老存档读档后补齐 economy")
	a.is_true(int(w3.economy["gringotts_interest_rate"]) > 0, "补齐了利率默认值")
```

> ⚠️ **`_make_world(...)` 的第一个参数是「时代 id」，不是年份** —— 实现时要挑一个
> `era_mult == 1.0` 的时代（按 `ERA_MULT` 表是 `first_wizarding_war`，start_year 1970；
> 其 `world_vars.economy_index` 默认 0.5，与 `NEUTRAL_INDEX` 一致），否则 C1 必挂。

> ⚠️ `_make_world(...)` / `world_to_dict(...)` / `_mutate_industry_base_output(...)` 是**测试内的辅助函数**，按 `tests/factions_test.gd` 里造 world 的既有写法实现（先读该文件）。**不要**在实现前猜 Registry 的 API。

- [ ] **Step 2: 跑测试确认红**

```bash
bash tools/test.sh 2>&1 | grep -A8 "economy"
```
期望：`economy` 套件失败（`Economy.price_of` 尚不存在 / 解析错误）。

- [ ] **Step 3: 实现算价函数**

```gdscript
static func era_mult_for(world: WorldState) -> float:
	var eras := world.registry.entry("eras", world.era_id)
	var y := int(eras.get("start_year", NEUTRAL_ERA_YEAR))
	if y <= 1000:
		return 0.35
	if y <= 1691:
		return 0.55
	if y <= 1945:
		return 0.85
	if y <= 1980:
		return 1.00
	if y <= 1998:
		return 1.15
	return 1.10


static func scarcity_mult_for(world: WorldState, industry_id: String) -> float:
	var idx := float(world.world_vars.get("economy_index", NEUTRAL_INDEX))
	var raw := 1.0 - (idx - NEUTRAL_INDEX) * 0.2 if idx >= NEUTRAL_INDEX \
		else 1.0 + (NEUTRAL_INDEX - idx) * 1.2
	# 垄断行业：涨价侧的超额部分加倍（spec §7.4 第 5 条）
	if raw > 1.0 and _is_monopoly(world, industry_id):
		raw = 1.0 + (raw - 1.0) * MONOPOLY_EXCESS_MULT
	return clampf(raw, MIN_SCARCITY, MAX_SCARCITY)


static func local_mult_for(world: WorldState, good_id: String) -> float:
	# 缺省必须安全：未知/未标记的地点一律平价（spec §7.4 第 4 条）
	# ⚠️ 实况修正（2026-09-21，缺陷⑧）：**不得**读 `world_vars["location_tag"]` ——
	#    该键全仓库无写入方（生产路径永远走缺省），且 world_vars 在玩家换地点时不变，
	#    导致 E7「产地买、销地卖」在实现上不可能。改按 locations.json 的 zone 推导。
	var loc := world.registry.entry("locations", world.player.location_id)
	var tag := str(_LOCAL_ZONE_TAG.get(str(loc.get("zone", "")), ""))
	return float(LOCAL_MULT.get(tag, LOCAL_MULT_DEFAULT))

const _LOCAL_ZONE_TAG := {
	"wild": "产地", "forbidden": "产地",
	"wizarding": "常规", "school": "常规",
	"muggle": "偏远",
}


static func price_factors(world: WorldState, good_id: String) -> Dictionary:
	var e := world.registry.entry("goods", good_id)
	var iid := str(e.get("industry_id", ""))
	return {
		"base": int(e.get("base_price_knuts", 0)),
		"era_mult": era_mult_for(world),
		"scarcity_mult": scarcity_mult_for(world, iid),
		"local_mult": local_mult_for(world, good_id),
	}


static func price_of(world: WorldState, good_id: String) -> int:
	if not available(world, good_id):
		return 0
	var f := price_factors(world, good_id)
	var raw := float(f["base"]) * float(f["era_mult"]) * float(f["scarcity_mult"]) * float(f["local_mult"])
	return maxi(1, roundi(raw))
```

> ⚠️ **三条实况修正（2026-09-21 Task 2 施工时暴露，计划原文有误）**：
> 1. **`Registry.entry()` / `ids()` 是实例方法，不是静态方法** —— `Economy` 是静态函数集合，
>    拿不到 `Registry` 单例，必须走 **`world.registry`**。计划原文的 `Registry.entry("eras", ...)`
>    会直接 Parse Error：`Cannot call non-static function "entry()" on the class "Registry" directly`。
> 2. **世界变量字段名是 `world.world_vars`，不是 `world.vars`** —— 原文写 `world.vars.get(...)`
>    会在运行期报 `Invalid access to property or key 'vars'`。
> 3. **`_is_monopoly` 必须收 `world` 参数**（因为第 1 条）：签名为
>    `static func _is_monopoly(world: WorldState, industry_id: String) -> bool`。

同时实现 `available()`（`supply_critical` 且 `economy_index <= SUPPLY_CUTOFF` ⇒ false）、
`effective_output()`（`clampf(base_output * (0.5 + idx * 0.5), 0, 1)`，保留供面板用）、
`is_crisis()`（`economy_index <= CRISIS_THRESHOLD`）。

- [ ] **Step 4: 加 `WorldState.economy` 字段**

`src/model/world_state.gd`：
- `var economy: Dictionary = {}`
- `create()` 末尾调 `Economy.initialize(self)`
- `from_dict()` 末尾调 `Economy.initialize(self)`（**幂等**：已有键不动）
- `to_dict()` 输出 `economy`（**只放 JSON 原生类型**，整体过 `JsonUtil.normalize()`）

`src/persist/save_codec.gd`：把 `"economy"` 加进字典字段白名单（**照抄 `"factions"` 的写法**）。**不升 `save_version`**。

`Economy.initialize(world)`：
```gdscript
static func initialize(world: WorldState) -> void:
	var e: Dictionary = world.economy
	if not e.has("prices"):
		e["prices"] = {}
	if not e.has("gringotts_balance"):
		e["gringotts_balance"] = 0
	if not e.has("gringotts_interest_rate"):
		e["gringotts_interest_rate"] = INTEREST_RATE
	if not e.has("foreign_rate"):
		e["foreign_rate"] = 1.0
	if not e.has("smuggling_heat"):
		e["smuggling_heat"] = 0
	if not e.has("crisis"):
		e["crisis"] = false
	if not e.has("last_settlement_turn"):
		e["last_settlement_turn"] = 0
	if not e.has("last_month_income"):
		e["last_month_income"] = 0
	if not e.has("last_month_expense"):
		e["last_month_expense"] = 0
	_snapshot_prices(world)
```

- [ ] **Step 5: 危机常量单源 —— 改 `factions.gd:369`**

把 `src/rules/factions.gd` 第 369 行附近的**字面量 `0.35`** 改为 `Economy.CRISIS_THRESHOLD`。
**只改这一个数**，不动 03a 的任何其它语义（spec §5.1：这是一条只读挂接）。

> ⚠️ 若 `factions.gd` preload `Economy` 造成循环加载，**在那一行加注释**：
> `# ⚠️ 0.35 必须与 Economy.CRISIS_THRESHOLD 同步（跨模块引用不便时的降级方案）`，
> 并在 `tests/economy_test.gd` 加一条断言把两个值钉在一起：
> `a.eq(Economy.CRISIS_THRESHOLD, 0.35, "危机阈值与 factions.gd 约定值一致")`。

- [ ] **Step 6: 跑测试确认绿**

```bash
bash tools/test.sh
```
期望：`EXIT=0`，`economy` 套件全部通过，`save` 套件通过。

- [ ] **Step 7: 反证实验（必做，spec §9 第 3 条）**

临时把 `price_of()` 里的 `scarcity_mult` 改成不封顶（`return raw`），跑测试，**期望 C3 断言变红**；然后再把 `supply` 乘回价格公式，**期望 C5 断言变红**。贴两段原始输出到报告，恢复代码后再跑一次确认全绿。

- [ ] **Step 8: 提交**

```bash
git add src/rules/economy.gd src/model/world_state.gd src/persist/save_codec.gd src/rules/factions.gd tests/economy_test.gd tests/economy_test.gd.uid tests/run_tests.gd tests/save_test.gd
git commit -m "feat(03b): Economy 算价核心 + WorldState.economy + 危机常量单源"
```

---

### Task 3: `Money` 负值语义（`is_debt` / `debt_formatted` / `formatted` 分支）

**Files:**
- Modify: `src/model/money.gd`
- Test: `tests/money_test.gd`

**Interfaces:**
- Consumes: 无。
- Produces: `Money.is_debt() -> bool`、`Money.debt_formatted() -> String`、`Money.formatted()` 负值走债务形态；`parts()` **不变**。

- [ ] **Step 1: 写失败测试**（期望值**全部经实算**，不要照抄「看起来对」的串）

```gdscript
	# ---- E9：债务形态（实算：parts() 第三位是**纳特**，不是西可）----
	a.eq(Money.new(-1002).debt_formatted(), "负债 2加隆 16纳特", "-1002")
	a.eq(Money.new(-17).debt_formatted(), "负债 1西可", "-17")
	a.eq(Money.new(-5).debt_formatted(), "负债 5纳特", "-5")
	a.eq(Money.new(-493).debt_formatted(), "负债 1加隆", "-493")
	a.eq(Money.new(-1002).formatted(), "负债 2加隆 16纳特", "formatted 负值走债务形态")
	a.eq(Money.new(0).formatted(), "0加隆 0西可 0纳特", "0 不是负债")
	a.is_false(Money.new(0).is_debt(), "0 不是负债")
	a.is_true(Money.new(-1).is_debt(), "-1 是负债")
	# parts() 保持既有行为（不破坏既有断言）
	var p := Money.new(-1002).parts()
	a.eq(p[0], -2, "parts[0]==-2")
	a.eq(p[1], 0, "parts[1]==0")
	a.eq(p[2], -16, "parts[2]==-16（纳特）")
```

- [ ] **Step 2: 跑测试确认红** —— `bash tools/test.sh 2>&1 | grep -A6 money`

- [ ] **Step 3: 实现**

```gdscript
func is_debt() -> bool:
	return _knuts < 0


func debt_formatted() -> String:
	## 债务形态：「负债 2加隆 16纳特」。
	## ⚠️ parts() 返回 [-g, -s, -k]，第三位是**纳特**不是西可（-1002 = 2×493 + 16）。
	var p := parts()
	var g: int = -p[0]
	var s: int = -p[1]
	var k: int = -p[2]
	var out := "负债"
	# 0 值的高位单位省略；低位单位即使为 0 也省略（-493 只写「1加隆」）
	if g > 0:
		out += " %d加隆" % g
	if s > 0:
		out += " %d西可" % s
	if k > 0:
		out += " %d纳特" % k
	if g == 0 and s == 0 and k == 0:
		return "0加隆 0西可 0纳特"   # 防御：不该走到这里（is_debt 已保证 <0）
	return out


func formatted() -> String:
	if is_debt():
		return debt_formatted()
	return "%d加隆 %d西可 %d纳特" % [_knuts / KNUTS_PER_GALLEON, ...]  # 保留既有非负分支
```

> ⚠️ **非负分支必须保持既有逐字符输出**（把现有实现整段保留，只在最前面插入 `is_debt()` 分支）。
> 这条是「不破坏既有断言」的硬要求；`tests/money_test.gd` 里 03a 已有的断言**一条都不许改**。

- [ ] **Step 4: 同步面板断言**（`tests/panel_test.gd` 里若已有负值形态的断言，改成新形态）

```bash
bash tools/test.sh 2>&1 | grep -B2 -A8 "panel"
```
**只改因 E9 而失效的断言**，其余不动。

- [ ] **Step 5: 跑测试确认绿 + 提交**

```bash
bash tools/test.sh
git add src/model/money.gd tests/money_test.gd tests/panel_test.gd
git commit -m "feat(03b): Money 债务形态（is_debt/debt_formatted/formatted 分支）"
```

---

### Task 4: 4 个新 op（`deposit_money` / `withdraw_money` / `exchange_money` / `trade_money`）+ OpGuard

**Files:**
- Modify: `src/rules/state_ops.gd`、`src/gm/op_guard.gd`
- Test: `tests/gm_test.gd`、`tests/llm_test.gd`、`tests/economy_test.gd`

**Interfaces:**
- Consumes: Task 2 的 `Economy.price_of` / `available`；`WorldState.economy`。
- Produces: 4 个 op；`OpGuard.MAX_BANK_MOVE` / `MAX_TRADE_QTY` / `MAX_TRADE_VALUE` 常量。

> **⚠️ 实况修正（2026-09-21，Task 4 开工前）**：本节原有两处与实况冲突，已按铁律**先改本计划文本**：
> 1. `local_mult` 的**来源不存在**（缺陷⑧）—— 见 Task 2 的 `local_mult_for` 修正（改按 `zone` 推导）。
> 2. **`MAX_TRADE_QTY = 100` 是件数上限，不是金额上限**，防不住高价商品套利：
>    实算「产区 0.85 → 偏远 1.2，扣两次路费」得 `broom_nimbus` 净利 **17 135 纳特/件**，
>    `qty=100` ⇒ 单笔 **1 713 500 纳特 = 3 476 加隆 ≈ 11.6 倍「普通家庭年收入数百加隆」**。
>    ⇒ 新增**货值闸门** `MAX_TRADE_VALUE := 5000`（按 `base_price_knuts × qty` 判），与件数上限**双闸**。
>    加闸后 `qty` 上限：`svc_owl_post` 100（件数先到）/ `potion_common` 5 / `wand_standard` 1 / `broom_nimbus` **0（拒绝）**。
>    即「高价耐用品天然不可搬运，跑量只发生在低价快消品」——量级回到正典区间。
>    同时**放弃**「同回合不可重复同类交易」（缺回合级记账，不值得加状态字段；双闸已足够钳制边际收益）。

- [ ] **Step 1: 写失败测试**

```gdscript
	# ---- deposit_money ----
	a.is_true(_apply(w, {"op":"deposit_money","knuts":100}, player_with(500)) == "", "正常存入")
	var pl := player_with(50)
	var err := _apply(w, {"op":"deposit_money","knuts":100}, pl)
	a.is_true(not err.is_empty(), "超出现金被拒")
	a.eq(int(pl.money_knuts), 50, "被拒时不扣钱（不部分执行）")
	a.eq(int(w.economy["gringotts_balance"]), 0, "被拒时余额不变")

	# ---- withdraw_money ----
	# 余额不足被拒且不部分执行

	# ---- exchange_money ----
	# buy / sell 方向、价差 2%、flag 记账

	# ---- trade_money ----
	# 断供商品被拒；illegal 商品 smuggling_heat += 1 且 flags["illegal_trade"] 置位
	# 路费真的被扣（利润 = 价差 - 路费）

	# ---- OpGuard：未知经济 op 一律拒绝 ----
	a.is_true(not OpGuard.sanitize_op({"op":"set_economy_index","value":0.9}).ok, "LLM 不能改世界经济")
	a.is_true(not OpGuard.sanitize_op({"op":"set_gringotts_balance","knuts":9}).ok, "LLM 不能直接改余额")
```

- [ ] **Step 2: 跑测试确认红**

- [ ] **Step 3: 实现 4 个 op**

按 `src/rules/state_ops.gd` 里既有 op 的**同款写法**（返回 `errors: Array[String]`，不抛异常，**不部分执行**）。
关键校验：

| op | 校验 | 成功副作用 |
| --- | --- | --- |
| `deposit_money` | `knuts > 0`、`knuts <= OpGuard.MAX_BANK_MOVE`、`player.money_knuts >= knuts` | 现金减、`economy.gringotts_balance` 增 |
| `withdraw_money` | `knuts > 0`、`knuts <= MAX_BANK_MOVE`、`economy.gringotts_balance >= knuts` | 反向 |
| `exchange_money` | `knuts > 0`、`knuts <= MAX_BANK_MOVE`、`direction ∈ {buy, sell}`、现金/外币余额足 | 按 `foreign_rate × (1 ∓ FOREIGN_SPREAD)` 换算；余额存 `economy.foreign_held` |
| `trade_money` | `good_id` 存在、`qty ∈ [1, MAX_TRADE_QTY]`、**`base_price_knuts × qty <= MAX_TRADE_VALUE`**、`Economy.available()` 为真、`mode ∈ {buy, sell}`、**两地 `local_mult` 必须不同**、现金足（买）/有货（卖） | 买价 = `price_of(origin) × qty` + 路费 `TRADE_HAUL_KNUTS[category] × qty`；卖价 = `price_of(dest) × qty`；`illegal` ⇒ `smuggling_heat += 1`、`flags["illegal_trade"] = true` |

`OpGuard` 加：`MAX_BANK_MOVE := 100000`、`MAX_TRADE_QTY := 100`、`MAX_TRADE_VALUE := 5000`，
并对 4 个 op 做金额/数量钳制（**照抄既有 op 的钳制写法**）。

> **`trade_money` 的跨地语义**：`origin_location_id`（买价所在地，缺省 = 玩家当前地点）与
> `location_id`（卖价所在地，缺省 = 玩家当前地点）。两者**必须不同** —— 相同就没有价差，
> 不是贸易而是就地买卖（应被拒绝并给出明确错误串）。
> `mode == "buy"` 在 `origin` 买（付 `price_of(origin)` + 路费），`mode == "sell"` 在 `location_id` 卖（收 `price_of(location_id)`）。

> ⚠️ **`Economy` 不得写 `world.factions` / `player.standing`**（spec §10 第 2 条）。走私热度的**法律后果**属 03c，本任务**只记不判**。

- [ ] **Step 4: 跑测试确认绿 + 提交**

```bash
bash tools/test.sh
git add src/rules/state_ops.gd src/gm/op_guard.gd tests/gm_test.gd tests/llm_test.gd tests/economy_test.gd
git commit -m "feat(03b): 4 个经济 op（存/取/汇/贸）+ OpGuard 钳制"
```

---

### Task 5: 月度结算 `Economy.monthly_settlement()` + 工资/开销/利息

**Files:**
- Modify: `src/rules/economy.gd`、`src/core/registry.gd`（注册 `jobs` 表）
- New: `data/jobs.json`
- Modify (内容表修正): `data/goods.json`（缺陷⑨ 食物价 + `industry_id`）
- Test: `tests/economy_test.gd`、`tests/registry_test.gd`

**Interfaces:**
- Produces: `static func monthly_settlement(world: WorldState) -> Dictionary`
  → `{"income": int, "expense": int, "interest": int}`；写回 `economy.last_month_income/expense`、`last_settlement_turn`。

> **⚠️ 实况修正（2026-09-21，Task 5 开工前）**：本节原有两处硬前提**根本不存在**，已按铁律先改本计划文本 + spec §7.6：
> 1. **缺陷⑩：`data/jobs.json` 不存在** —— 本节结尾写「职业名到 id 的映射若已在 `data/jobs.json` 就复用（**先查**，不要新造表）」。
>    **查了：没有**（`data/` 只有 22 个文件，无 jobs）。且 `player.job` 是**自由字符串**（`gm_test` 塞「魔药学徒」、`economy_test` 塞「auror」）。
>    ⇒ 必须新建 `data/jobs.json`（正典 **198** 行 9 类城市巫师职业；注意 spec §4 原引用写 196，实际正文在 **198**）。
> 2. **缺陷⑨：食物价量级错** —— `food_pumpkin_pastry = 1 纳特`、`food_butterbeer = 2 纳特`
>    （1 纳特 ≈ 0.002 加隆 ⇒ 南瓜馅饼比月房租 4437 便宜 4437 倍），且 `industry_id` 错填 `publishing`（南瓜饼归出版社）。
>    是本节「§③ 食物开销」的必经路径。按本节自己的口径实算：**月支出只有 4497，而本节预期 6900**。
>    ⇒ 修正为 `34` 纳特/份 + `industry_id = ""`，月支出回到 **6477**（与本节预期自洽）。
>    **旁证**：本节作者做那次实算时用的食物价是对的，写进 `goods.json` 时错了。
> 3. **`ADULT_MONTHS` 与 `UNKNOWN_WAGE_KNUTS` 是本任务要新定的常量**（`204` / `4930`），见 spec §7.6。

> **⚠️ 实况修正 2（2026-09-21，Task 5 施工中，写测试时暴露）**：又发现两处口径错误，同样先改 spec 再改代码：
> 4. **缺陷⑪：工资上沿口径自相矛盾** —— 本节结尾硬约束原写「其余 8 条**全部**在 `[2958, 7395]` 内」。
>    实算：`healer = 8874 = 18.00 加隆`、`pub_owner = 7888 = 16.00 加隆`，**两条越出 7395**；越界数 **3 条**不是 1 条。
>    ⇒ **不改薪资数值，改断言口径**：下沿 `2958`（6 加隆）保持硬约束（9 条全满足）；上沿放宽到 `9860` 且**只有 `quidditch_pro` 可达**（其余 8 条严格 `< 9860`）。
>    量级自洽的真判据改为「**中位年收入落在数百加隆**」：中位 6900 × 12 = **168 加隆** ✔（正典 223 行）。
>    元教训：`15 加隆` 不是正典数字，是从「年收入数百加隆 ÷ 12」倒推的**软参考**，不能拿来当硬断言。
> 5. **缺陷⑫：未成年是否照收生活费未定义** —— K2 只说了「工资门槛」，§7.6 开销行只说「房租 + 食物×60」，**两处都没说未成年**。
>    实算：若照收 ⇒ 11 岁开局到 17 岁前累计欠 **−946 加隆**（≈普通家庭 6 年收入）；正典 424 行未成年不得在校外使用魔法、563 行 17 岁前属「学徒」阶段。
>    ⇒ **裁定读法 B（用户 2026-09-21 拍板）：未成年整月跳过**（收支皆 0，仅推进 `last_settlement_turn`）。
>    「未成年无开销」升为**契约**（测试显式断言，防止将来被改回「照收」）。

> **⚠️ 测试写法提醒（实测踩到）**：幂等门是 `last_settlement_turn == clock.turn`，而**新建世界的 `turn` 与 `last_settlement_turn` 都是 0**
> ⇒ 不推回合的话第一次结算就被门挡掉（我一开始全测出 0，误以为实现坏了）。
> 真实流程里 `tick()` **先** `advance_month()`（turn 0→1）**再**结算，测试须用 `w.clock.advance_month()` 复现这一调用序。

- [ ] **Step 1: 写失败测试**

```gdscript
	# ---- 幂等：同回合调两次只结算一次 ----
	w.clock.turn = 5
	var r1 := Economy.monthly_settlement(w)
	var bal1 := int(w.economy["gringotts_balance"])
	var r2 := Economy.monthly_settlement(w)
	a.eq(int(w.economy["gringotts_balance"]), bal1, "同回合二次调用不改余额")
	a.eq(r2["income"], 0, "二次调用不发钱")

	# ---- 无业者净收 < 0（必须）----
	var w_jobless := _make_world(1950, 0.5)
	w_jobless.player.job = ""
	w_jobless.clock.turn = 1
	var rj := Economy.monthly_settlement(w_jobless)
	a.is_true(rj["income"] - rj["expense"] < 0, "无业者净支出为负")

	# ---- 有业者：收入按职业；成年门槛 ----
	# 未成年（age_months < 17*12）不结算工资
	w_jobless.player.job = "auror"
	w_jobless.player.age_months = 17 * 12
	w_jobless.clock.turn = 2
	a.is_true(Economy.monthly_settlement(w_jobless)["income"] > 0, "成年从业者有工资")

	# ---- 存款利息真的到账 ----
	w.economy["gringotts_balance"] = 100000
	w.clock.turn = 9
	var before := 100000
	Economy.monthly_settlement(w)
	a.is_true(int(w.economy["gringotts_balance"]) > before, "利息到账")
```

- [ ] **Step 2: 跑测试确认红**

- [ ] **Step 3: 实现**

```gdscript
const ADULT_MONTHS := 204              # 17 × 12；未成年整月跳过（K2 + 缺陷⑫）
const FOOD_UNITS_PER_MONTH := 60       # 简化：两餐/日
const UNKNOWN_WAGE_KNUTS := 4930       # 自由文本职业的保守兜底（店员档，**不是 0**）

static func monthly_settlement(world: WorldState) -> Dictionary:
	var e: Dictionary = world.economy
	# 幂等：同回合不重复结算（**不改任何字段**，spec §9 第 5 条）
	if int(e.get("last_settlement_turn", -1)) == world.clock.turn:
		return {"income": 0, "expense": 0, "interest": 0}

	# 未成年整月跳过（缺陷⑫ 读法 B）：收支皆 0，但照常推进回合标记
	if world.player.age_months < ADULT_MONTHS:
		e["last_month_income"] = 0
		e["last_month_expense"] = 0
		e["last_settlement_turn"] = world.clock.turn
		return {"income": 0, "expense": 0, "interest": 0}

	var income := 0
	var expense := 0

	# ① 工资（成年 + 有职业；正典第十五章「上班」是基线，K2）
	if not str(world.player.job).is_empty():
		income += _wage_for(world, world.player.job)

	# ② 生活开销（房租 + 食物）—— **必须走 price_of**（不写死 base），
	#    否则危机期物价翻倍而开销不变（口径漂移）。
	expense += price_of(world, "svc_rent")
	expense += price_of(world, "food_pumpkin_pastry") * FOOD_UNITS_PER_MONTH

	# ③ 存款利息（负余额不加息）
	var rate := float(e.get("gringotts_interest_rate", INTEREST_RATE))
	var bal := int(e.get("gringotts_balance", 0))
	var interest := 0
	if bal > 0:
		interest = int(floor(float(bal) * rate))
		e["gringotts_balance"] = bal + interest

	world.player.money_knuts += income - expense   # 允许为负 ⇒ Money 负债形态（Task 3 已就绪）
	e["last_month_income"] = income
	e["last_month_expense"] = expense              # **正值**，符号由面板加
	e["last_settlement_turn"] = world.clock.turn
	return {"income": income, "expense": expense, "interest": interest}


## 工资查表：`label` 精确 → `id` 精确 → 包含匹配（自由文本宽容，取最长命中）→ `UNKNOWN_WAGE_KNUTS`。
static func _wage_for(world: WorldState, job: String) -> int:
	# 实现见 src/rules/economy.gd（三级匹配 + 最长命中键，防短标签误伤）
```

> **工资表 `_wage_for(job)`**：按正典 **198** 行（⚠️ 原写「第十五章」未给行号，spec §4 曾误写 196）的 9 类城市巫师职业清单
> （商人/魔药师/记者/治疗师/店员/酒吧老板/扫帚修理工/猫头鹰驯养师/魁地奇球员）建 `data/jobs.json`。
> **量级锚点（spec §13 风险 4）**：普通家庭年收入约数百加隆 ⇒ 月收入下沿 **6 加隆 = 2958 纳特**（**硬约束**，9 条全满足）；
> 上沿放宽到 **9860**（20 加隆），**只有魁地奇球员可达**（正典 233 行「也是商业」），其余 8 条严格 `< 9860`。
> ⚠️ **原写「月收入 6–15 加隆（2958–7395）」是错的**（缺陷⑪）：`healer = 8874 = 18 加隆`、`pub_owner = 7888 = 16 加隆` 越出 7395。
> 量级自洽改判「**中位年收入落在数百加隆**」：中位 6900 × 12 = **168 加隆** ✔。
> **实算（Table 见 spec §7.6）**：月支出 = 房租 4437 + 食物 34×60 = **6477**；中位工资 6900 ⇒ 月净 **+423**；
> 无业者月净 **−6477** ⇒ K2 的「不工作会饿」有牙齿 ✔；未成年月净 **0**（缺陷⑫）。
> **工资率进 `data/jobs.json` 而不是 `Economy` 常量表**：职业 `label` 是**玩家可见文本**（面板【职业】行直接显示），
> 与 `ERA_MULT` 那种纯演化参数不同（spec §13 风险 2 讨论的同款张力，此处按「可见文本进 data」判）。

- [ ] **Step 4: 跑测试确认绿 + 提交**

```bash
bash tools/test.sh
git add src/rules/economy.gd src/core/registry.gd data/jobs.json data/goods.json \
        tests/economy_test.gd tests/registry_test.gd
git commit -m "feat(03b): 月度结算（工资/开销/利息）+ jobs 表 + 食物价修正"
```

---

### Task 6: `tick()` 接线 —— `Economy.evolve()` + `monthly_settlement()` + 危机边沿事件

**Files:**
- Modify: `src/rules/economy.gd`、`src/model/world_state.gd`
- Test: `tests/economy_test.gd`

**Interfaces:**
- Produces: `static func evolve(world: WorldState) -> void`；`tick()` 在 `factions.evolve()` 之后追加两个阶段。

- [ ] **Step 1: 写失败测试**

```gdscript
	# ---- tick 顺序：evolve 必须在 settlement 之前（本月价算完再结算）----
	# 用一个「价格随景气变化」的场景验证结算用的是**本月**价
	# ---- 危机边沿：false->true 写事件，且只写一次 ----
	var w_c := _make_world(1950, 0.5)
	w_c.vars["economy_index"] = 0.30
	var n0 := w_c.events.size()
	w_c.tick()
	a.is_true(w_c.events.size() > n0, "进入危机写事件")
	a.is_true(bool(w_c.economy["crisis"]), "crisis 置位")
	a.is_true(float(w_c.economy["gringotts_interest_rate"]) < Economy.INTEREST_RATE, "危机降息")
	# 已在危机中再 tick 不重复写事件
	var n1 := w_c.events.size()
	w_c.tick()
	a.eq(w_c.events.size(), n1, "危机中不重复写事件")
	# 退出危机不写事件
	w_c.vars["economy_index"] = 0.9
	w_c.tick()
	a.is_false(bool(w_c.economy["crisis"]), "退出危机")
	a.is_true(float(w_c.economy["gringotts_interest_rate"]) >= Economy.INTEREST_RATE, "利率回升")

	# ---- foreign_rate 确定性（同 seed 双世界相等，spec §9 第 1 条）----
	var w_a := _make_world_seeded(1950, 0.5, 12345)
	var w_b := _make_world_seeded(1950, 0.5, 12345)
	for _i in range(6):
		w_a.tick()
		w_b.tick()
	a.eq(float(w_a.economy["foreign_rate"]), float(w_b.economy["foreign_rate"]), "foreign_rate 同 seed 一致")
```

- [ ] **Step 2: 跑测试确认红**

- [ ] **Step 3: 实现 `evolve()` 与接线**

`Economy.evolve(world)` 做四件事：
1. `_snapshot_prices(world)` —— 重算 `economy.prices` 快照（`price_of` 会先查快照）。
2. `foreign_rate` 月度小幅波动 —— `RngService.new(world.game_seed + world.clock.turn * 24593)`，**命名流 `economy_foreign_rate`**，幅度 ±3%，结果 clamp 到 `[0.85, 1.15]`。
3. 危机**边沿**判定：`now = is_crisis(world)`；`false→true` ⇒ 写 `events`（`kind: "economic_crisis"`）+ `add_fact("major", ...)` + 降息 + 涨走私利润；`true→false` ⇒ 利率回升、**不写事件**。
4. `smuggling_heat` **只记不判**（本任务不改它，只保留字段）。

`src/model/world_state.gd` 的 `tick()`：在既有 ④ `WorldFactions.evolve()` 之后、⑦ 生活基线之前插入：

```gdscript
	# ⑤ 经济演化（物价快照 / 汇率 / 危机边沿）
	Economy.evolve(self)
	# ⑥ 月度结算（工资 / 开销 / 利息，确定性）
	Economy.monthly_settlement(self)
```

> ⚠️ **顺序不可换**（spec §8）：`evolve` 必须在 `settlement` 之前，否则结算用的是上月价；
> 两者都必须在 `world_vars` 回归（①）之后，因为景气是本回合新算出来的。
> **既有 ⑦⑧⑨ 的相对顺序一条都不许动**；⑦ 日志裁剪必须仍在最后（要能裁到新事件）。

- [ ] **Step 4: 跑测试确认绿 + 提权**

```bash
bash tools/test.sh
git add src/rules/economy.gd src/model/world_state.gd tests/economy_test.gd
git commit -m "feat(03b): tick 接线（evolve + monthly_settlement + 危机边沿）"
```

---

### Task 7: 面板 —— 【财富】含存款 + 新增【经济】行

**Files:**
- Modify: `src/ui/panel_formatter.gd`
- Test: `tests/panel_test.gd`

**Interfaces:**
- Consumes: `Economy` 只读、`world.economy`、`Money.debt_formatted()`。
- Produces: `player_panel()` 的【财富】行含存款；新增【经济】行。

- [ ] **Step 1: 写失败测试**

```gdscript
	# ----【财富】含存款（无存款时不出现该括号）----
	w.economy["gringotts_balance"] = 0
	a.is_true(not _panel(w).contains("含古灵阁"), "无存款时不显示括号")
	w.economy["gringotts_balance"] = 12 * 493 + 3 * 29 + 4
	a.is_true(_panel(w).contains("含古灵阁 12加隆 3西可 4纳特"), "有存款时显示")

	# ----【经济】行存在且数值来自 economy ----
	w.vars["economy_index"] = 0.61
	w.economy["gringotts_interest_rate"] = 0.002
	w.economy["foreign_rate"] = 1.03
	w.economy["last_month_income"] = 29
	w.economy["last_month_expense"] = 0
	var p := _panel(w)
	a.is_true(p.contains("【经济】"), "有【经济】行")
	a.is_true(p.contains("景气 0.61"), "景气来自 economy_index")
	a.is_true(p.contains("本月 +1西可"), "本月净收入带符号")

	# ---- 净支出显示为负号，且**不隐藏**该行（spec §7.6）----
	w.economy["last_month_income"] = 0
	w.economy["last_month_expense"] = 5 * 29 + 3
	a.is_true(_panel(w).contains("本月 -5西可 3纳特"), "净支出带负号且可见")

	# ---- 收支为 0 ----
	w.economy["last_month_income"] = 0
	w.economy["last_month_expense"] = 0
	a.is_true(_panel(w).contains("本月 无收支"), "零收支特判")

	# ---- 债务走债务形态（E9）----
	w.player.money_knuts = -1002
	a.is_true(_panel(w).contains("负债 2加隆 16纳特"), "面板债务形态")

	# ---- 未揭示黑市商品不出现（spec §10 第 1 条）----
```

- [ ] **Step 2: 跑测试确认红**

- [ ] **Step 3: 实现**

- 【财富】行：`"【财富】%s" % Money.new(money).formatted()`，有存款时追加
  `"（含古灵阁 %s）" % Money.new(bal).formatted()`（**余额为 0 时不追加**）。
- 紧随其后新增一行：
  `"【经济】景气 %.2f ｜ 存款月息 %.2f%% ｜ 汇率 %.2f ｜ 本月 %s"`。
  - 月息按 `gringotts_interest_rate * 100`（0.002 → `0.20%`，**两位小数**）。
  - 本月：`net = income - expense`；`net > 0` ⇒ `"本月 +%s" % Money.new(net).formatted()`；
    `net < 0` ⇒ `"本月 -%s" % Money.new(-net).formatted()`（**注意取负后再 formatted，否则会出「负债」二字**）；
    `net == 0` ⇒ `"本月 无收支"`。
- `power_panel()` 的「财政」指标**保持不变**（仍来自 `economy_index`，`panel_formatter.gd:116`）。

- [ ] **Step 4: 跑测试确认绿 + 提交**

```bash
bash tools/test.sh
git add src/ui/panel_formatter.gd tests/panel_test.gd
git commit -m "feat(03b): 面板【财富】含存款 + 新增【经济】行"
```

---

### Task 8: `PromptBuilder.state_digest` 经济摘要（只给已揭示信息）

**Files:**
- Modify: `src/gm/prompt_builder.gd`
- Test: `tests/llm_test.gd`（或 `tests/prompt_test.gd`，**先查既有测试文件名**）

- [ ] **Step 1: 写失败测试**

```gdscript
	# ---- 摘要含景气 + 玩家现金/存款 + 2-3 条主要物价 ----
	var d := PromptBuilder.state_digest(w)
	a.is_true(d.contains("经济"), "有经济段")
	a.is_true(d.contains("景气"), "有景气")
	a.is_true(d.contains("古灵阁"), "有存款")
	# 未揭示的黑市商品不得出现在摘要里
	a.is_true(not d.contains("禁售神奇生物"), "未揭示黑市商品不剧透")
```

- [ ] **Step 2-3: 实现**

在 `state_digest` 里追加一段（**只读**）：
`经济：景气 0.61（危机中/平稳）｜ 现金 X ｜ 古灵阁 Y ｜ 主要物价：房租 Z、黄油啤酒 W`。
价格只列 **2–3 条**（房租 + 食物 + 一件 `supply_critical` 商品），且 `category == "illegal"` 的商品
**只在已揭示相关派系时才列**（复用 03a 的 `visible_faction_ids()`）。

- [ ] **Step 4: 跑测试确认绿 + 提交**

```bash
bash tools/test.sh
git add src/gm/prompt_builder.gd tests/llm_test.gd
git commit -m "feat(03b): state_digest 加经济摘要（信息保护）"
```

---

### Task 9: 离线替身接线（关键词 → 经济 op）

**Files:**
- Modify: `src/gm/scripted_game_master.gd`
- Test: `tests/gm_test.gd`

- [ ] **Step 1: 写失败测试**

```gdscript
	# 对「我要把 100 纳特存进古灵阁」期望产出 deposit_money
	# 对「取 50 纳特」期望 withdraw_money
	# 对「买 2 根魔杖」期望 trade_money（good_id == wand_standard, qty == 2）
```

- [ ] **Step 2-3: 实现关键词匹配**（照抄既有 `scripted_game_master.gd` 里派系关键词的同款写法；**只增不改既有分支**）

- [ ] **Step 4: 跑测试确认绿 + 提交** —— `git commit -m "feat(03b): 离线替身支持经济 op"`

---

### Task 10: 经济类传闻内容（`data/rumors.json`）

**Files:**
- Modify: `data/rumors.json`
- Test: `tests/registry_test.gd`（或既有传闻测试）

- [ ] **Step 1-3**: 追加 3 条经济传闻（物价飞涨 / 古灵阁挤兑 / 黑市繁荣），带 `zones` / `min_year` / `requires_flags`
  （**照抄既有传闻条目的字段写法**），并让「物价飞涨」只在 `crisis` 为真时可用。
- [ ] **Step 4**: `bash tools/test.sh` → 绿 → 提交。

---

### Task 11: `tools/b1_acceptance.gd` 经济可观测契约

**Files:**
- Modify: `tools/b1_acceptance.gd`
- Test: 自身

- [ ] **Step 1: 加 3 条验收断言**

1. **存款利息真的到账**：存 100000 纳特 → 跑一个月 → 余额**确实**变大（贴数值）。
2. **危机态下同一商品价格真的变贵**：把 `economy_index` 从 0.7 压到 0.3 → `price_of()` **确实**上升（贴两次数值）。
3. **债务显示形态可达**：造一个负现金角色 → 面板输出含「负债」。

- [ ] **Step 2: 跑 B1**

```bash
timeout 300 bash tools/b1_acceptance.sh
```
期望：`EXIT=0`，断言失败=0，**且 `llm_settings.json` 与 `saves/slot1.json` 被原样还原**（03a 的铁律）。

- [ ] **Step 3: 提交** —— `git commit -m "test(03b): B1 经济可观测契约"`

---

### Task 12: 收尾 —— 全绿、台账、文档、B1 复跑、合入 `main`

**Files:**
- Create: `docs/sdd/plan-03b-economy/progress.md`
- Modify: `README.md`、`HANDOFF.md`、`NEXT-STEPS.md`
- Test: 全仓

- [ ] **Step 1: 全量回归**

```bash
cd /e/Hali
bash tools/test.sh                      # 期望 EXIT=0、失败套件=0、4 步全过、噪声计数 2/7
timeout 300 bash tools/b1_acceptance.sh # 期望 断言失败=0、EXIT=0
tasklist | grep -i godot                # 期望无残留进程
git status --porcelain                  # 期望干净（仅 .workbuddy/ 未跟踪）
```

- [ ] **Step 2: 写台账 `docs/sdd/plan-03b-economy/progress.md`**

按 `docs/sdd/plan-03a-factions/progress.md` 格式逐任务记：brief → worker 提交哈希 → 绿灯断言数（前后对比）
→ 审查结论/严重度 → 修复提交 → scoped 复审 → 残余。并把每个任务的 brief/report/review/审查包复制进该目录，与代码同一次提交。

- [ ] **Step 3: 更新文档**

1. `HANDOFF.md`：`§8#5`（Money 负值）标**已闭合**（写提交哈希）；新增一节「计划 03b 的关键结论」
   （价格定版常数 + C1–C6 契约 + 为何 `supply` 不进价格 + 危机/断供双线解耦 + 为何删掉「上等魔杖」）；
   `§2` 测试输出样例与套件数按实测更新（新增 `[economy]`）。
2. `README.md`：进度表加「计划 03b · 经济骨架（已完成）」；补一句「游戏内可以存钱生息、买卖商品、跨国套利（例：把 100 加隆存进古灵阁 / 买 2 根魔杖）」。
3. `NEXT-STEPS.md`：§A1 标 03b 完成；把 03c 提为下一个待办（边界照 spec §14）；把「6 张未接 UI 切片」（`panel_bg`/`frame_horizontal`/`frame_vertical`/`emblem_ring`/`panel_slot`/`button_close`）挂到**下一个界面改版**待办下。

- [ ] **Step 4: 合入 `main`**

```bash
git checkout main
git merge --no-ff plan-03b-economy -m "merge: 计划 03b 经济骨架（Tasks 1-12）"
bash tools/test.sh    # 合入后再跑一次
```

- [ ] **Step 5: 提交并推送**

```bash
git add docs/sdd/plan-03b-economy README.md HANDOFF.md NEXT-STEPS.md
git commit -m "docs: 计划 03b 收尾（台账 + README/HANDOFF/NEXT-STEPS）"
git push origin main
git push origin plan-03b-economy
```

---

## 执行交接

计划已落在 `docs/superpowers/plans/2026-09-21-hp-magic-era-03b-economy.md`。两种执行方式：

1. **子代理驱动（推荐）**：每任务派一个新鲜子代理（`pi -p --provider deepseek --model deepseek-flash`），任务间由控制器审阅，迭代快；每任务遵仓库铁律：brief → worker → 自跑绿灯 → **先写报告再返回** → 只读 reviewer 审 diff → 台账。
2. **本会话内联执行**：按 `executing-plans` 批量执行，在检查点停下来给你评审。

> 三个提醒：
> ① **Task 1 的数值已由 Python 实算脚本验证过 C1–C6，直接抄，不要自己重算**（重算容易重新引入 spec §13 风险 8 的 6 个坑）。若确实要改价，**先改 spec 再改表**。
> ② **Task 2 Step 7 的反证实验是必做项**（spec §9 第 3 条）—— 不贴反证输出的报告不算完成。
> ③ Task 10/11 是收尾性质的小任务，可以按你的偏好合并进 Task 12 一起跑。
