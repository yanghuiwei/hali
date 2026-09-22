# 计划 03c · 社会与法律 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现本计划。步骤用 `- [ ]` 复选框跟踪。
> Spec：`docs/superpowers/specs/2026-09-22-hp-magic-era-03c-society-law-design.md`（已产出，2026-09-22，**待人类评审**）。
> 分支：`plan-03c-society-law`（从 `main`@`2078f33`）。计划日期：2026-09-22。

**Goal:** 把「社会身份与法律后果」从一个只写不读的 flag（`illegal_affiliation`）变成有闭环的系统：家族（姓氏/祖宅/财富/声望/秘密）→ 协会（会员/会费/行业准入）→ 法律（罪行/发现/审判/刑罚）→ 傲罗行动与非法施法后果。让 03a 的政治控制权与 03b 的经济产生**法律层面**的后果。

**Architecture:** 新增 `src/rules/law.gd`（`class_name Law`，静态函数，纯规则层）承载审判与刑罚；家族与协会各建一个规则模块（`src/rules/families.gd` / `src/rules/associations.gd`）。状态存在**新增的** `world.families` 与 `world.law` 两个字典（**不升 `save_version`**）；`tick()` 只**追加**一个阶段（`Law.evolve`），既有步骤语义与顺序不动；4 个新 op 走既有 `StateOps` 唯一入口；面板只读（**替换【家族】行的硬编码占位**）。

**Tech Stack:** Godot 4.7.2 stable（非 .NET）、纯 GDScript、无第三方依赖、不联网；测试入口 `bash tools/test.sh`（4 步：导入 → 单测 → 默认冒烟 → 调试镜像冒烟）。

## Global Constraints

以下约束对**每个任务**都生效，不再逐条重复：

- 引擎固定 **Godot 4.7.2 stable / Windows 64-bit / 非 .NET**；只写 GDScript；不引入第三方插件、外部素材、网络依赖。
- **内容一律进 `data/*.json`**，代码不硬编码内容（家族名、协会名、罪行名都是内容）。代码里只允许硬编码**枚举与实体 id**。
- **数值是内容，演算是代码**：`wealth_galleons`/`fee_galleons`/`fine_*`/`sentence_*` 进 `data/`；
  `HEAT_*` / `INHERITANCE_TAX` 等**演化参数**进 `Law` 常量（与 03b 的 `ERA_MULT` 同款理由）。
- `to_dict()` 只放 JSON 原生类型，且整体过 `JsonUtil.normalize()`（否则 `{"n":493} != {"n":493.0}`，存读档往返断言必挂）。
- **新增测试套件必须把路径追加到 `tests/run_tests.gd` 的 `SUITES`**（`run_tests.gd:6`），否则不会被执行。
- **新脚本连 `.gd.uid` 一起 `git add`**（Godot 4.4+ 用 `.uid` 锁定脚本标识）。
- **新增内容表必须同时改 `src/core/registry.gd` 的 `TABLE_FILES`**（`:4-26`），否则 `load_default()` 不加载（**静默失败**）。
- **提交前必须有绿灯**：`bash tools/test.sh` 必须 `EXIT=0`，报告里贴原始输出（含每套件断言数）。
- 正典优先：`哈利·波特·魔法纪元.md` 与本计划冲突时**改计划**，并在报告里写明依据行号。
- 随机数一律走 `RngService` 命名流，禁止 `randf()`/`randi()` 裸调用。
- **对 03a/03b 只读**：不得修改 `data/factions.json`（除 §Task 10 明确授权的补校验）、
  `data/goods.json`、`data/industries.json`、`src/rules/factions.gd` 的既有逻辑、`src/rules/economy.gd`。
  若发现必须改，**先改 spec 文本**（03a 铁律），单独提交。
- **`illegal_affiliation` 的语义变更必须在 `state_ops.gd` 那行加注释写明契约**（Task 6）。
- 不要并发跑两个 headless 实例（会争 `.godot` 缓存）；卡住时 `tasklist | grep -i godot` + `taskkill //PID <PID> //F`。
- **合并分支时不要 `git checkout <目标分支>`**（2026-09-22 事故，`HANDOFF §4#24`）：
  用 `git branch -f <目标> <来源>` 推进指针，先验 `git merge-base --is-ancestor`。
- 每完成一个任务：实现 → 自跑绿灯 → **先写报告文件再返回** → 只读 reviewer 审 diff →
  台账 `docs/sdd/plan-03c-society-law/progress.md` → 把报告/审查复制进 `docs/sdd/plan-03c-society-law/` 与代码同一次提交。

## 数值定版（spec §4 实算结果，**照抄，不要自创**）

```gdscript
# ---- Law：法律风险（spec §4.6）----
const HEAT_SAFE := 2              # <= 此值不起诉
const HEAT_CERTAIN := 10          # >= 此值必定起诉
const HEAT_DECAY := 1             # 每月自然冷却
const HEAT_GAIN_SMUGGLE := 1      # 走私（折进 heat 的系数）
const HEAT_GAIN_ILLEGAL_CAST := 2 # 非法施法（每次）
const HEAT_GAIN_OUTLAW_JOIN := 3  # 加入非法组织（一次性）

# ---- Law：继承（spec §4.7）----
const INHERITANCE_TAX := 0.30     # 遗产税
const DEFAULT_HEIRS := 4          # 无遗嘱时的法定继承人份数
const WILL_LONGEST_SHARE := 0.50  # 有遗嘱指定长子时，长子的份额

# ---- Law：罚金换净化（spec §5.10）----
const FINE_TO_HEAT := 1           # 1 加隆 = 1 点 heat
const MAX_FINE_PAY := 25000       # 单笔罚金上限（纳特）≈ 50 加隆

# ---- 司法偏见的特权出身（spec §5.5，实测 id）----
const PRIVILEGED_IDENTITIES: Array[String] = ["noble_pureblood", "ministry_official",
	"auror_family", "professor_family", "goblin_contract", "st_mungo_family"]
```

```
# 起诉概率（spec §4.6）
trial_chance(heat) = 0.0                        if heat <= HEAT_SAFE
                   = 1.0                        if heat >= HEAT_CERTAIN
                   = (heat - SAFE) / (CERTAIN - SAFE)   otherwise

# 家族财富档（spec §4.1）—— 单位：中位巫师家庭年收入（168 加隆）
没落 0–0.5   ⇒     0–    83 加隆
小康 0.5–3   ⇒    83–   503 加隆
殷实 3–20    ⇒   503–  3359 加隆
豪富 20–100  ⇒  3359– 16795 加隆
巨富 100–300 ⇒ 16795– 50385 加隆

# 继承（spec §5.7）
可分额 = wealth_galleons × (1 - INHERITANCE_TAX)
玩家份额 = 可分额 × (WILL_LONGEST_SHARE 若被指定继承人，否则 1.0 / DEFAULT_HEIRS)

# 判决（spec §4.5）
severity 1: 罚 1–5 加隆,   刑 0 月,    不可剥夺魔杖
severity 2: 罚 5–15 加隆,  刑 0 月,    不可剥夺
severity 3: 罚 10–25 加隆, 刑 1–3 月,  不可剥夺
severity 4: 罚 50–150 加隆,刑 12–60 月,可剥夺
severity 5: 罚 200–500 加隆,刑 60–240 月,可剥夺 + 阿兹卡班
```

**L1–L6 验收契约（每个法律任务都要自检）**：
- **L1**：`heat <= HEAT_SAFE` 时**起诉概率恒为 0**（构造用例：heat=2 跑 100 次不立案）
- **L2**：`heat >= HEAT_CERTAIN` 时**必定立案**（heat=10 跑 1 次就立案）
- **L3**：**先衰减后判定** —— 构造 heat=3、停手 3 个月，断言第 3 月 `heat == 0` 且**始终未立案**
- **L4**：**判决金额单调** —— severity 越高，罚金与刑期都严格递增（spec §4.5 表逐档断言）
- **L5**：**继承稀释** —— 巨富家族（50385）4 份均分 + 30% 税 ⇒ 断言玩家恰好得 **8817 加隆**
- **L6**：`world.law` / `world.families` 的 `initialize()` **只补缺键、绝不覆盖**（塞自定义值后调 initialize 必须不变）

> ⚠️ **L1/L2/L3 必须用 `RngService` 的确定性流**（`world.game_seed` 推导），
> 否则「跑 100 次」这类断言不可复现。照 `economy_test` 的做法。

---

## Task 1：家族内容表 `data/families.json` + 校验 + `WorldFamilies.initialize`

**Files:**
- Create: `data/families.json`
- Create: `src/rules/families.gd`（`class_name WorldFamilies`）
- Create: `src/rules/families.gd.uid`
- Modify: `src/core/registry.gd`（`TABLE_FILES` 加一行 + `_validate_entry` 可加分表校验）
- Modify: `src/model/world_state.gd`（加 `var families: Dictionary = {}`）
- Test: `tests/families_test.gd`（新建）+ `tests/run_tests.gd`（`SUITES` 追加）

- [ ] **Step 1: 写 `data/families.json`（8–12 个家族）**

⚠️ **字段名必须对齐既有消费者** `src/ui/panel_formatter.gd:160-170`（spec §3.1）：
`surname` / `seat` / `members` / `war` …（详见 spec §3.1 的面板映射表）。
**不要自创字段名** —— 面板读不到的字段是死字段。

每个家族必填（spec §3.1）：
```jsonc
{
  "id": "malfoy", "label": "马尔福家族", "surname": "马尔福",
  "bloodline_id": "sacred_twenty_eight",   // ⚠️ 实测只有 sacred_twenty_eight / pureblood_cadet 可选
  "faction_id": "sacred_twenty_eight",     // ⚠️ 必须是 factions.json 的真实 id
  "seat": "malfoy_manor",                  // 必须是 locations.json 的真实 id（可空）
  "wealth_tier": "巨富",                   // 枚举（spec §4.1，5 档）
  "wealth_galleons": 48000,                // ⚠️ 必须落在该 tier 区间内
  "prestige": 85,                          // 0..100
  "members": 6,
  "heir_policy": "eldest",                 // 枚举 HEIR_POLICIES
  "wand_legacy": "wand_lore",              // 枚举 MAGIC_TRADITIONS（spec §4.3）
  "secrets": ["dark_arts_legacy"],         // 枚举 SECRETS（spec §4.2）
  "allies": ["greengrass"], "rivals": ["weasley"],
  "era_overrides": {"hogwarts_founding": {"wealth_galleons": 12000}},
  "canon_line": 184
}
```

`HEIR_POLICIES`：`eldest`（长子继承）/ `equal`（均分）/ `designated`（遗嘱指定）/ `none`（无继承规则）。
`MAGIC_TRADITIONS`：`none` / `wand_lore` / `dark_arts` / `healing` / `prophecy` / `metamorphmagus` / `beast_speech`。
`SECRETS`：`dark_arts_legacy` / `hidden_vault` / `chamber` / `ancient_contract` / `old_curse` / `blood_tarnish`。

⚠️ **`era_overrides` 的键必须是 `eras.json` 的 8 个真实 id** 之一
（`hogwarts_founding` / `witch_hunts` / `grindelwald` / `first_wizarding_war` /
`second_wizarding_war` / `reconstruction` / `modern` / `custom`）。

- [ ] **Step 2: 写 `src/rules/families.gd` 的枚举与校验**

照 `factions.gd:36-92` 的 `validate_content(registry) -> PackedStringArray` 风格。校验项（spec §3.1 的 8 条）：
1. `bloodline_id` / `faction_id` / `seat` / `allies` / `rivals` 的引用完整性（`registry.has(...)`）
2. `wealth_tier` 是枚举，且 **`wealth_galleons` 落在该 tier 区间内**（⚠️ 新型校验）
3. `prestige` 在 `0..100`
4. `secrets` 每项在 `SECRETS` 内
5. `allies`/`rivals` **不含自己**
6. `allies` 与 `rivals` **不同时含同一家族`
7. `heir_policy` 在 `HEIR_POLICIES` 内
8. `members >= 0` 且 `wealth_galleons >= 0`

- [ ] **Step 3: 写 `initialize` / `ensure_state` / `state_of`**

照 `Economy.initialize`（`economy.gd:216`）的**只补缺绝不覆盖**契约：
```gdscript
static func initialize(world: WorldState) -> void:
	if world == null or world.registry == null or world.clock == null:
		return                    # ⚠️ clock 为 null 时必须早退（save_test 的毒对象用例）
	for fid in world.registry.ids("families"):
		ensure_state(world, str(fid))

static func ensure_state(world: WorldState, family_id: String) -> Dictionary:
	# 已有字典就直接返回（幂等）；否则按表建 {wealth_galleons, prestige,
	#   known_secrets: [], discovered: false, player_relation: 0, last_change_turn}
```

- [ ] **Step 4: 接线**

`world_state.gd` 加 `var families: Dictionary = {}`（`to_dict`/`from_dict` 都要过 `JsonUtil.normalize`）。
在 `WorldState.create` 与 `tick` 的初始化路径调用 `WorldFamilies.initialize(world)`。

- [ ] **Step 5: 门禁 + 提交**

```bash
bash tools/test.sh    # EXIT=0
git add data/families.json src/rules/families.gd src/rules/families.gd.uid \
        src/core/registry.gd src/model/world_state.gd \
        tests/families_test.gd tests/families_test.gd.uid tests/run_tests.gd
git commit -m "feat(03c): 家族内容表 + 校验 + WorldFamilies.initialize"
git push
```

**测试要求**（`tests/families_test.gd`）：
- 内容校验：`validate_content(reg)` 为 0 条；再用 `Registry.from_tables({...})` 造**坏表**
  逐条断言 8 类错误都被捕获（照 `factions_test.gd:22-96` 的做法）
- **L6 断言**：塞 `world.families["malfoy"]["prestige"] = 99` ⇒ 调 `initialize` ⇒ 断言仍是 99
- `wealth_galleons` 越界用例（如 `wealth_tier: "巨富"` 但 `wealth_galleons: 100`）必须报错

---

## Task 2：协会内容表 `data/associations.json` + 校验

**Files:**
- Create: `data/associations.json`、`src/rules/associations.gd` + `.uid`
- Modify: `src/core/registry.gd`（`TABLE_FILES`）、`src/model/world_state.gd`（`var associations: Dictionary = {}`）
- Test: `tests/associations_test.gd` + `tests/run_tests.gd`

- [ ] **Step 1: 写 `data/associations.json`（8 个协会）**

正典第十九章 229 行给出全部 8 个：魔药师协会 / 治疗师协会 / 魁地奇联盟 / 魔杖匠行会 /
反黑魔法联盟 / 作家协会 / 神奇生物保护协会 / 家养小精灵权益促进会。

```jsonc
{
  "id": "apothecaries_guild", "label": "魔药师协会",
  "industry_id": "potion_brewing",     // ⚠️ 必须是 industries.json 的 9 个真实 id 之一
  "faction_id": "commerce_bloc",       // 必须是 factions.json 的真实 id
  "fee_galleons": 5,                   // 入会/年会费
  "standing_required": 0,              // 所需最低派系立场
  "required_skills": {"potions": 30},  // ⚠️ 键必须是 skills.json 的 19 个真实 id 之一
  "benefits": {"price_discount": 0.10},
  "legal_status": "legal",
  "canon_line": 229
}
```

⚠️ **行业 id 实测 9 个**：`potion_brewing` / `wandmaking` / `broommaking` / `publishing` /
`quidditch` / `creature_breeding` / `archaeology` / `curse_breaking` / `finance`。
⚠️ **技能 id 实测 19 个**（含 `potions` / `healing` / `wand_lore` / `quidditch` / `black_market`）。

`benefits` 的键（spec §4.4）：`price_discount`（0–0.25）/ `wage_bonus`（0–0.30）/ `access`（字符串，可空）。

- [ ] **Step 2: 校验**（照 Task 1 风格）

1. `industry_id` / `faction_id` 引用完整性
2. `required_skills` 的键都在 `skills.json`
3. `fee_galleons >= 0`；`benefits` 的数值型键在合法区间
4. `legal_status` 在 `WorldFactions.LEGAL_STATUS` 内（**复用 03a 的枚举，不另造**）

- [ ] **Step 3: `initialize` / `state_of` / 会员查询**

`world.associations[aid] = {"member": false, "joined_turn": -1, "dues_paid_turn": -1}`。
⚠️ 同样**只补缺绝不覆盖**。

- [ ] **Step 4: 门禁 + 提交**（同 Task 1 的命令模式，替换文件名）

---

## Task 3：罪行与刑罚内容表 + 校验

**Files:**
- Create: `data/crimes.json`、`data/penalties.json`
- Modify: `src/core/registry.gd`（`TABLE_FILES` 两行）
- Test: `tests/law_content_test.gd` + `tests/run_tests.gd`

- [ ] **Step 1: 写 `data/crimes.json`**

```jsonc
{
  "id": "unlicensed_magic", "label": "未成年校外施法",
  "severity": 1, "heat_gain": 1, "detect_base": 0.10,
  "min_age_months": 0, "max_age_months": 203,   // 17 岁 = 204 月（正典 424 行）
  "canon_line": 424
}
```

覆盖的正典依据：未成年校外施法（424 行）、走私（03b 移交）、非法交易受管控物品、
不可饶恕咒、谋杀、魂器（255/259 行）等。**至少 8 条**，`severity` 覆盖 1..5。

- [ ] **Step 2: 写 `data/penalties.json`**（severity 1..5，各一条，照 spec §4.5 表）

- [ ] **Step 3: 校验（**关键的跨表校验**）**

1. `severity` 在 `1..5`
2. **`penalties.json` 里每个 severity 1..5 有且只有一条**（⚠️ 这是本计划的核心一致性约束）
3. `heat_gain >= 0`；`detect_base` 在 `0..1`
4. `fine_min <= fine_max`；`sentence_min <= sentence_max`
5. `can_revoke_wand` / `azkaban` 是 bool；且 **`azkaban == true` 只允许 severity 5**
6. 罪行名 `label` 非空，`id` 唯一（`registry.validate` 已有）

- [ ] **Step 4: 门禁 + 提交**

**测试要点**：删掉 `penalties.json` 里 severity=3 那条 ⇒ 断言校验器报「severity 3 缺刑罚档」。

---

## Task 4：`Law` 模块骨架（`world.law` + 常量 + `initialize`）

**Files:**
- Create: `src/rules/law.gd` + `.uid`
- Modify: `src/model/world_state.gd`（`var law: Dictionary = {}`）
- Test: `tests/law_test.gd` + `tests/run_tests.gd`

- [ ] **Step 1: 写常量区**（照本文档「数值定版」段，**照抄**）

- [ ] **Step 2: `initialize` / `ensure_state`**

```gdscript
world.law = {
  "heat": 0, "open_case": "", "last_trial_turn": -1,
  "convictions": [], "wand_revoked": false, "sentence_until_turn": -1,
  "_smuggle_seen": 0,          # 下划线前缀：OpGuard 会拒 LLM 写（见 Task 9）
}
```

⚠️ **只补缺绝不覆盖**（L6）。⚠️ `clock == null` 时早退。

- [ ] **Step 3: 纯函数 `trial_chance(heat)`**（照「数值定版」段公式）

- [ ] **Step 4: 门禁 + 提交**

---

## Task 5：`Law.evolve`（衰减 → 折走私 → 判定开案）

**Files:**
- Modify: `src/rules/law.gd`、`src/model/world_state.gd`（`tick()` 追加调用）
- Test: `tests/law_test.gd`

- [ ] **Step 1: 写 `evolve(world) -> void`**

**三步顺序不可换**（spec §5.3 第 2 条）：
```gdscript
# ① 先衰减（给玩家退路：停手一个月立刻有效）
heat = maxi(0, heat - HEAT_DECAY)
# ② 折入上月新增走私（读 03b 的累计值做差，见 Step 2）
# ③ 再判定（用衰减后的值算概率）
```

- [ ] **Step 2: 走私的自我差分**（spec §5.3 第 1 条）

⚠️ **实况核对**：`state_ops.gd:293` 的 `smuggling_heat` 是**累计**递增，**没有月度分桶**。
⇒ 口径：读累计值 `cur`，与 `law["_smuggle_seen"]` 做差得本月新增，然后更新 `_smuggle_seen = cur`。
```gdscript
var cur := int(world.economy.get("smuggling_heat", 0))
var delta := maxi(0, cur - int(law.get("_smuggle_seen", 0)))
law["_smuggle_seen"] = cur
heat += delta * HEAT_GAIN_SMUGGLE
```
⚠️ **`maxi(0, ...)` 不能省**：读档后若 `_smuggle_seen` 缺失（旧档）会是 0，差值为全量 —— 这是可接受的
一次性补偿；但**负差值**（`smuggling_heat` 被外部清空）必须钳到 0，否则 heat 会倒退。

- [ ] **Step 3: 折入非法施法与非法隶属**

- 非法施法：`illegal_cast_count` 同样**累计** ⇒ 同样用自我差分（`law["_cast_seen"]`），
  乘 `HEAT_GAIN_ILLEGAL_CAST`。
- 非法隶属：`world.flags["illegal_affiliation"]` 非空 ⇒ 一次性 `+ HEAT_GAIN_OUTLAW_JOIN`
  （用 `law["_outlaw_seen"]` 记已计入的 faction_id，**换派系才再计**）。

- [ ] **Step 4: 开案**

`heat >= HEAT_SAFE` 且按 `trial_chance` 命中 ⇒ 写 `law["open_case"]`（罪行 id）。
⚠️ **已有未结案件时不重复开案**（`open_case` 非空就跳过）。

- [ ] **Step 5: 接线 `WorldState.tick()`**

在既有编排里**追加**一个阶段（`Economy.monthly_settlement` 之后，日志裁剪之前）。
⚠️ **既有步骤的顺序与语义一律不动**（03a/03b 铁律）。

- [ ] **Step 6: 门禁 + 提交**

**测试要点（L1/L2/L3 全覆盖）**：
- L1：heat=2 ⇒ 起诉概率 0
- L2：heat=10 ⇒ 必立案
- **L3（最关键）**：构造 heat=3、连跑 3 个月 `evolve` ⇒ 断言第 3 月 `heat == 0` 且 `open_case` 始终为 `""`
- 反向控制：把「先衰减后判定」改成「先判定后衰减」⇒ 断言 **L3 恰好变红**

---

## Task 6：`illegal_affiliation` 三态归一（**闭合挂账**）

**Files:**
- Modify: `src/rules/state_ops.gd`（`leave_faction` 分支 + 注释）
- Test: `tests/law_test.gd` 或 `tests/gm_test.gd`

- [ ] **Step 1: 在 `leave_faction` 的写状态分支加清除**

```gdscript
else:
	world.player.faction_id = ""
	# 契约（spec §5.4）：illegal_affiliation 是**状态描述**（"当前有非法隶属"），
	# 不是历史痕迹。退出派系即清除 —— 唯一的写入端（join_faction）与这里对称。
	# 若将来需要"曾有非法隶属"的记录，那是 law.convictions 的职责，不复用此 flag。
	world.flags.erase("illegal_affiliation")
```

- [ ] **Step 2: 在 `join_faction` 的写入行加契约注释**（指向 spec §5.4）

- [ ] **Step 3: 门禁 + 提交**

**测试要点**：加入 outlaw 派系 ⇒ flag 置位；退出 ⇒ **flag 被清除**；
切换 outlaw 派系 ⇒ flag 变成新 id。

---

## Task 7：判决与刑罚（罚金 / 刑期 / 剥夺魔杖）

**Files:**
- Modify: `src/rules/law.gd`
- Test: `tests/law_test.gd`

- [ ] **Step 1: 写 `judge(world, crime_id) -> Dictionary`**

按 `severity` 查 `penalties.json`，在 `fine_min..fine_max` / `sentence_min..sentence_max`
区间内用 `RngService` 命名流取值（`rng.stream_int("law_penalty_fine")`）。
⚠️ **区间取值必须走命名流**，否则不可复现。

- [ ] **Step 2: 司法偏见修正**（spec §5.5 四项，**全部用有写入方的字段**）

```gdscript
var mult := 1.0
mult *= 1.0 + float(player.flags.get("prejudice_level", 0.0))   # ⚠️ Task 11 会提升为字段
if Law.PRIVILEGED_IDENTITIES.has(player.birth_identity_id): mult *= 0.7
if player.standing_of(wizengamot_holder) < -50: mult *= 1.3
if not str(world.flags.get("illegal_affiliation", "")).is_empty(): mult *= 1.5
fine = int(round(fine * mult))
```
⚠️ `wizengamot_holder` 取 `WorldFactions.institution_control(world)["wizengamot"]["holder"]`
（**只读 03a**）。holder 为空串时该修正项跳过。

- [ ] **Step 3: 剥夺魔杖**

`can_revoke_wand && severity >= 4` ⇒ 可判 `law["wand_revoked"] = true`。
⚠️ **不得清空 `player.wand`**（那是玩家财产，03b 有魔杖交易）——
用**独立 flag** 表达「使用权被剥夺」，与「是否持有」解耦（spec §5.9）。

- [ ] **Step 4: 定罪记录**

```gdscript
law["convictions"].append({"crime_id": crime_id, "turn": world.clock.turn,
	"fine_knuts": fine_knuts, "sentence_months": months})
law["open_case"] = ""
law["last_trial_turn"] = world.clock.turn
law["sentence_until_turn"] = world.clock.turn + months   # 0 则等于当前回合（未服刑）
```

- [ ] **Step 5: 门禁 + 提交**

**测试要点**：L4（罚金/刑期随 severity 严格递增）+ 偏见四因子各自的构造用例 +
「`wand_revoked` 为 true 时 `player.wand` 仍非空」。

---

## Task 8：继承事件（稀释）

**Files:**
- Modify: `src/rules/law.gd`（或新建 `src/rules/inheritance.gd`）
- Test: `tests/law_test.gd`

- [ ] **Step 1: 写 `settle_inheritance(world, family_id, designated: bool) -> Dictionary`**

```gdscript
var gross := float(family_state.get("wealth_galleons", 0.0))
var distributable := gross * (1.0 - INHERITANCE_TAX)
var share := WILL_LONGEST_SHARE if designated else 1.0 / float(DEFAULT_HEIRS)
var got := int(round(distributable * share))
```

⚠️ **稀释的理由要写进注释**（spec §5.7）：不是「平衡」，而是**不能让玩家跳过积累阶段**
（03b 玩法靠月度收支流；独子继承 319.6 年生活费会让玩家再也不需要月度收入）。

- [ ] **Step 2: 接线（内容驱动，不自动触发）**

本计划**不做**自动触发（族长的死亡是叙事事件）。提供函数 + 一个 op（或经 `Law` 被 GM 调用）。
⚠️ **留出接口但不强行接线** —— 正典没给「何时继承」的规则，硬编一个触发点是无依据的。

- [ ] **Step 3: 门禁 + 提交**

**测试要点**：**L5 断言** —— 巨富（50385）4 份均分 + 30% 税 ⇒ **恰好 8817 加隆**；
被指定继承人 ⇒ 17635 加隆。⚠️ 用整数算术，**不手算进位**（03b 教训）。

---

## Task 9：4 个新 op + `OpGuard` 闸门

**Files:**
- Modify: `src/rules/state_ops.gd`、`src/gm/op_guard.gd`
- Test: `tests/gm_test.gd` 或 `tests/law_test.gd`

- [ ] **Step 1: 写 4 个 op**（照 `state_ops.gd:150-286` 的经济 op 风格）

铁律：**不部分执行** / **不抛异常** / **不动别的模块**。

| op | 参数 | 校验 |
| --- | --- | --- |
| `join_association` | `association_id` | 会费够 / 技能达标 / 立场达标 / 未入会 |
| `leave_association` | `association_id` | 已是会员（**不退费**） |
| `pay_fine` | `knuts` | `<= MAX_FINE_PAY` / 现金够 / 有 `open_case` |
| `serve_sentence` | （无） | 有未服刑判决 |

`pay_fine` 的降 heat：`heat = maxi(0, heat - int(knuts / 493) * FINE_TO_HEAT)`。

- [ ] **Step 2: `OpGuard` 黑名单**（spec §5.11）

```gdscript
const MAX_FINE_PAY := 25000
# 司法产物：只能由 Law 的判决逻辑写。若 LLM 能直接改，等于一键洗白犯罪记录。
const _LAW_FORBIDDEN: Array[String] = ["convictions", "wand_revoked",
	"sentence_until_turn", "open_case", "last_trial_turn"]
```
+ 新增 op 的参数钳制（`MAX_FINE_PAY`）。

- [ ] **Step 3: 门禁 + 提交**

**测试要点**：每个 op 的成功路径 + 至少 2 个失败路径；
**黑名单拒绝断言**（构造 LLM ops 试图写 `wand_revoked` ⇒ 被拒）。

---

## Task 10：面板【家族】行真实取值（**替换硬编码占位**）

**Files:**
- Modify: `src/ui/panel_formatter.gd:160-170`
- Modify: `src/rules/factions.gd`（**补 `allies`/`rivals` 的自反与互斥校验**，spec §9 风险 6）
- Test: `tests/panel_test.gd`

- [ ] **Step 1: 把家族行接到 `world.families`**

⚠️ **两处语义必须改**（spec §3.1）：
1. **财富**：从 `world.player.money()` ⇒ 改为 `family.wealth_galleons`
   （玩家口袋 ≠ 家族财富）
2. **声望**：从 `world.player.reputation` ⇒ 改为 `family.prestige`
   （§5.2 已裁定两者独立；且 `player.reputation` 恒为 0，见 spec 缺陷 ③）

⚠️ **先查 `tests/panel_test.gd` 是否已有断言钉住旧取值** —— 有则按新语义改断言 **并写明理由**。

- [ ] **Step 2: 补 `factions.json` 的自反/互斥校验**（Task 1 的同款两条）

✅ **已实测零风险**（spec §9 风险 6）：既有 17 条数据 0 自引用 / 0 互斥 / 0 悬空。

- [ ] **Step 3: 门禁 + 提交**

---

## Task 11：`Outcome.rolled` + `prejudice_level` 提升为字段

**Files:**
- Modify: `src/rules/spell_resolver.gd`（`Outcome` 加 `rolled: bool`）
- Modify: `src/model/player_state.gd`（`prejudice_level` 提升为 float 字段 + `from_dict` 兜底迁移）
- Modify: `src/ui/`（展示层以 `blocked` 为唯一判据）
- Test: `tests/spell_test.gd`、`tests/model_test.gd`

- [ ] **Step 1: `Outcome` 加 `rolled: bool`**（回应 `§8#29`）

被拦截时 `rolled = false`（之前 `failure_rate=1.0/roll=1.0` 与「未进入掷骰」混淆）。

- [ ] **Step 2: `prejudice_level` 提升为 `PlayerState` 数值字段**（回应 `§8#23`）

⚠️ **存档兼容**：`from_dict` 里保留**从 `flags` 迁移的兜底读法**：
```gdscript
p.prejudice_level = float(d.get("prejudice_level", d.get("flags", {}).get("prejudice_level", 0.0)))
```
⚠️ 同时 `character_creation.gd:246` 改为写新字段（**不再写 `flags`**）。
⚠️ **Task 7 的 read 处要跟着改**（`player.flags.get("prejudice_level")` ⇒ `player.prejudice_level`）。

- [ ] **Step 3: 门禁 + 提交**

**测试要点**：旧档（`flags` 里带该键）读进来 ⇒ 新字段有值；新档往返一致。

---

## Task 12：收尾（全绿 / 台账 / 文档 / B1 复跑 / 合入 `main`）

- [ ] **Step 1: 全量回归**
```bash
bash tools/test.sh                          # EXIT=0
timeout 400 bash tools/b1_acceptance.sh     # EXIT=0
```
- [ ] **Step 2: 台账**（`docs/sdd/plan-03c-society-law/progress.md` 追加 Task 12 条目）
- [ ] **Step 3: 文档**
  1. `HANDOFF.md`：§8 把 **`illegal_affiliation` 陈旧化** 标为已闭合；
     `§8#23`（`prejudice_level`）、`§8#28/#29`（非法施法）标为已处置；
     新增 `## 5.7 计划 03c 的关键结论`；§2 测试输出样例按实测更新（新增 `[families]`/`[law]` 等）
  2. `README.md`：进度表加「计划 03c · 社会与法律（已完成）」
  3. `NEXT-STEPS.md`：§A1 标 03c 完成 + §0B 基线数字 + §E 下一步
- [ ] **Step 4: 合入 `main`**（⚠️ **不要 `git checkout main`**，用 `branch -f`）
```bash
git merge-base --is-ancestor main plan-03c-society-law && echo "可 fast-forward"
git push origin plan-03c-society-law
git branch -f main plan-03c-society-law
git push origin main
bash tools/test.sh
```
- [ ] **Step 5: 提交并推送**
```bash
git add docs/sdd/plan-03c-society-law README.md HANDOFF.md NEXT-STEPS.md
git commit -m "docs: 计划 03c 收尾（台账 + README/HANDOFF/NEXT-STEPS）"
git push origin main plan-03c-society-law
```
