# 计划 03c · 社会与法律（Society & Law）设计 spec

- **状态**：设计期（2026-09-22 起草）
- **边界来源**：`docs/superpowers/specs/2026-09-20-hp-magic-era-03-factions-design.md` §14
- **上游移交**：`docs/superpowers/specs/2026-09-21-hp-magic-era-03b-economy-design.md` §13 第 7 条 + §14
- **正典**：`哈利·波特·魔法纪元.md` 第十三章（家族，182 行）、第十四章（傲罗/凤凰社，190 行）、
  第十九章（协会，227 行）、第三十五章（法律，418 行）、第三十八章（家庭与家族，443 行）
- **前置**：03a（派系政治）与 03b（经济骨架）**均已完成并合入 `main`**

---

## 1. 范围界定

### 1.1 本计划做什么（四块）

| # | 模块 | 正典依据 | 新增内容表 |
| --- | --- | --- | --- |
| ① | **纯血家族完整制度** | 第十三章 182–188；第三十八章 443–451 | `data/families.json` |
| ② | **协会体系** | 第十九章 227–235 | `data/associations.json` |
| ③ | **法律与审判** | 第三十五章 418–424 | `data/crimes.json`、`data/penalties.json` |
| ④ | **傲罗行动与非法施法后果** | 第十四章 190–194；第三十九章 453–461 | （复用 03a `factions.json` 的 `auror_office`，不新增表） |

### 1.2 本计划不做什么（明确排除，避免范围蔓延）

- **不做家常系统**（父母/配偶/子女的日常交互、婚姻撮合、育儿）—— 正典第三十八章虽涉及，
  但那是**家庭生命周期模拟**，属 06（多世代传承）。本计划只做**家族**（姓氏/财产/声望/秘密）这一层。
- **不做 NPC 自主**（NPC 加入协会、NPC 家族内部斗争）—— 属 05。
- **不做战争系统**（傲罗数量/城堡攻防/武装体系）—— 正典第三十九章，属独立计划。
- **不做遗产跨代传承**（玩家死亡后子嗣续玩）—— 属 06。本计划只在**玩家当前世代内**处理继承事件。
- **不接 UI 布局**（家族面板行/协会界面）—— 本计划只让数据可取，界面留到下一次界面改版。
  ⚠️ 但 `panel_formatter.gd:160-163` 的【家族】行硬编码占位**必须在本计划替换为真实取值**
  （03b spec §14 已明确移交：家族财产/祖宅/财富会填该字段）。

---

## 2. 与既有系统的接口（只读，不改 03a/03b）

### 2.1 读 03a（派系）

| 接口 | 用途 |
| --- | --- |
| `WorldFactions.state_of(world, fid)` | 取派系状态（`power`/`control`/`revealed`） |
| `WorldFactions.institution_control(world)` | 取 `wizengamot` / `auror_office` 的**控制权与持有者** |
| `WorldFactions.visible_faction_ids(world)` | 信息保护门：未揭示派系不可见 |
| `data/factions.json` 的 `legal_status`（legal/shadow/outlaw） | 法律模块的**组织合法性**来源 |

**关键设计点**：威森加摩的**判决倾向**应由 `institution_control(world)["wizengamot"]` 派生 ——
控制权高的一方（如魔法部 vs 纯血）会让判决偏向自己人。这让 03a 的政治博弈**直接产生法律后果**，
而不需要 03c 新造一套政治参数。

### 2.2 读 03b（经济）

| 接口 | 用途 |
| --- | --- |
| `Economy.price_of(world, good_id)` | 计算罚金/会费/家族财富的**现值**（不新造价格口径） |
| `world.economy["smuggling_heat"]` | 走私热度的**唯一来源**（03b 只记不判） |
| `world.player.money_knuts` | 罚金扣款 |
| `Money.from_knuts()` / `formatted()` / `debt_formatted()` | 金额显示（**必须复用，不得另造格式**） |

**⚠️ 03b 的明文禁令**（`state_ops.gd:139` 注释）：03b 的 op「不写 `world.factions` / `player.standing`」。
03c 反过来要**遵守对称禁令**：法律模块**不得改写 `world.economy` 的内部口径**
（如强行清 `prices` 快照），只能通过既有 op（`add_money` 等）或新增 op 影响它。

### 2.3 既有挂账的处置（**本计划必须闭合**）

| 挂账 | 位置 | 本计划的处置 |
| --- | --- | --- |
| `illegal_affiliation` 陈旧化 | `HANDOFF §8` 记账区 | **清除/归一规则见 §5.4** |
| `illegal_cast_count` 只记不判 | `HANDOFF §8#28` | **接入法律风险累积（§5.3）** |
| `illegal_cast_count` 未遂不计 | `HANDOFF §8#28` | **裁定：维持「仅成功计入」**，理由见 §5.3 第 3 条 |
| `Outcome` 被拦截时 `failure_rate=1.0/roll=1.0` 混淆 | `HANDOFF §8#29` | **新增 `rolled: bool`**，展示层以 `blocked` 为唯一判据 |
| `prejudice_level` float 写进 bool 语义 `flags` | `HANDOFF §8#23` | **提升为 `PlayerState` 数值字段**（本计划要读它做司法偏见） |
| 隐藏派系控制权**数值**仍显示 | `HANDOFF §8` 记账区 | **裁定：本计划不动**（属界面信息保护，见 §9 风险 5） |

---

## 3. 数据模型

### 3.1 家族 `data/families.json`（新建）

⚠️ **字段名必须对齐既有消费者**（写 spec 时实测发现，**这是本 spec 最重要的一处实况修正**）：
`src/ui/panel_formatter.gd:160-170` **已经有一套完整的两分支家族行实现**，
它读 `world.player.flags["family"]`，并按 **11 个字段**渲染：

```
surname（姓氏）/ seat（祖宅）/ 财富（取 player.money()）/ members（成员数）/
marriage（婚姻）/ allies（盟友数）/ enemies（敌人数）/ 声望（取 player.reputation）/
secret（家族秘密）/ heir（继承人）/ wand_legacy（魔杖传承）
```

但 **`flags["family"]` 全仓库无写入方** ⇒ 永远走 `is_empty()` 分支，
玩家只会看到「姓氏：无家族（家族制度属计划 03c）」。
⇒ **本计划的落点就是给它一个真实来源**。字段命名**以这个既有契约为准**（不另造）。

正典第十三章 184–188 + 第三十八章 451 给出家族拥有：
「姓氏、祖宅、财富、魔杖传承、家族魔法、政治盟友、声望、藏书、契约、人际关系、仇敌、家族秘密」。

```jsonc
{
  "id": "malfoy",
  "label": "马尔福家族",
  "surname": "马尔福",                     // ← 面板取的 surname
  "bloodline_id": "sacred_twenty_eight",   // 引用 bloodlines.json
  "faction_id": "sacred_twenty_eight",     // 引用 factions.json
  "seat": "malfoy_manor",                  // ← 面板取的 seat（引用 locations.json，可空）
  "wealth_tier": "巨富",                   // 枚举（§4.1）
  "wealth_galleons": 48000,                // 金库现值（加隆）
  "prestige": 85,                          // 家族声望 0..100（独立于 player.reputation）
  "members": 6,                            // ← 面板取的 members（成员数）
  "heir_policy": "eldest",                 // 继承规则（§5.7）
  "wand_legacy": "wand_lore",              // ← 面板取的 wand_legacy（家族魔杖传承，§4.3 枚举）
  "secrets": ["dark_arts_legacy"],         // 家族秘密（§4.2）；面板只显示玩家已知的那一条
  "allies": ["greengrass"],                // 家族盟友（引用本表 id）
  "rivals": ["weasley"],                   // 家族仇敌（引用本表 id）
  "era_overrides": {"hogwarts_founding": {"wealth_galleons": 12000}},
  "canon_line": 184
}
```

⚠️ **`era_overrides` 的键必须是 `eras.json` 的真实 id**（实测 8 个：
`hogwarts_founding` / `witch_hunts` / `grindelwald` / `first_wizarding_war` /
`second_wizarding_war` / `reconstruction` / `modern` / `custom`）。
起草时我曾写成 `"founding"` —— **这是错的**（实际 id 是 `hogwarts_founding`）。
⇒ 校验器必须查 `registry.has("eras", key)`（照 `factions.gd:63-65` 的做法）。

⚠️ **`bloodline_id` 的可选范围很窄**（实测 `bloodlines.json` 只有 12 条，其中**纯血档只有 2 个**：
`sacred_twenty_eight`（神圣二十八族）/ `pureblood_cadet`（纯血旁支））。
⇒ 家族表的 `bloodline_id` **只能取这两者之一**（或日后扩充 `bloodlines.json`）。
**本计划不扩充 `bloodlines.json`**（那是内容扩展，会动 03a 已定版的表）。

**面板字段的映射规则**（实施时必须照此接线）：

| 面板显示 | 取值来源 |
| --- | --- |
| 姓氏 | `family.surname` |
| 祖宅 | `family.seat` → 经 `Registry` 查 `locations` 得中文标签 |
| 财富 | **`family.wealth_galleons`**（⚠️ 不是 `player.money()` —— 见下） |
| 成员 | `family.members` |
| 婚姻 | 玩家实测（本计划不实现婚姻系统 ⇒ 维持「未婚」或按 `player` 状态派生的自然值） |
| 盟友 / 敌人 | `family.allies.size()` / `family.rivals.size()` |
| 声望 | **`family.prestige`**（⚠️ 不是 `player.reputation` —— 见下） |
| 家族秘密 | 只显示 `family.known_secrets` 里玩家**已知**的（信息保护，第四十三/五十七章） |
| 继承人 | `family.heir` 或「未定」 |
| 魔杖传承 | `family.wand_legacy` 的中文标签 |

⚠️ **两处既有实现的语义要改**（当前实现有缺陷）：
1. **财富**当前取 `world.player.money().formatted()` —— 那是**玩家口袋**，不是**家族财富**。
   玩家可以穷得叮当响却出身巨富家族。⇒ 必须改取 `family.wealth_galleons`
   （**这正是 03b spec §14 移交的「家族财产/祖宅会填该字段」**）。
2. **声望**当前取 `world.player.reputation` —— 那是**玩家**声望。⇒ 改取 `family.prestige`
   （§5.2 已裁定两者独立）。

> ⇒ 这两处修改会让**现有的面板断言变化**（若已有断言钉住旧取值）。
> 实施时先查 `tests/panel_test.gd` 是否覆盖该行；有则按新语义改断言（**并写明理由**）。

**校验要求**（照 `factions.gd:validate_content` 的风格）：
1. `bloodline_id` / `faction_id` / `seat` / `allies` / `rivals` 的引用完整性（`registry.has(...)`）。
2. `wealth_tier` 是枚举，且 `wealth_galleons` **必须落在该 tier 的区间内**（见 §4.1 表）——
   ⚠️ 这是**新出现的一致性约束**，03a/03b 都没有「字段值必须落在另一字段定义的区间」这类校验。
3. `prestige` 在 `0..100`。
4. `secrets` 每项在 `SECRETS` 枚举内。
5. `allies`/`rivals` **不得包含自己**（自引用）。
6. `allies` 与 `rivals` **不得同时包含同一家族**（同时是盟友和仇敌是内容错误）。
7. `heir_policy` 在 `HEIR_POLICIES` 枚举内。
8. `members >= 0`；`wealth_galleons >= 0`。

> ⚠️ **第 5、6 条是新类型的校验**（关系自反性/互斥性）。03a 的 `rivals`/`allies` **没有**这两条校验
> （见 §9 风险 6）—— 本计划在**自己的表**上做对，并**顺手给 `factions.json` 也补上**
> （已实测：既有 17 条**全部干净**，属零风险纯增量）。

### 3.2 协会 `data/associations.json`（新建）

正典第十九章 229 行给出 8 个协会，231 行给「会长、分部、行业规则、会员、资源、政治立场」。

```jsonc
{
  "id": "apothecaries_guild",
  "label": "魔药师协会",
  "industry_id": "potion_brewing",      // 引用 industries.json（03b）⇒ 行业准入的落点
  "faction_id": "commerce_bloc",        // 引用 factions.json（政治立场）
  "fee_galleons": 5,                    // 入会费/年会费（加隆）
  "standing_required": 0,               // 加入所需的最低派系立场
  "required_skills": {"potion": 30},    // 入会技能门槛（引用 skills.json）
  "benefits": {"price_discount": 0.10}, // 会员权益（见 §4.5）
  "legal_status": "legal",              // 与 factions.json 同枚举
  "canon_line": 229
}
```

**协会 ↔ 产业挂接**：03b spec §14 明确移交「协会的行业准入」。落点：
`industry_id` 指向 03b 的 `data/industries.json`。未加入协会时，**该产业的自营活动受限**
（本计划的口径见 §5.6）。

### 3.3 罪行与刑罚 `data/crimes.json` + `data/penalties.json`（新建）

```jsonc
// crimes.json
{
  "id": "unlicensed_magic",
  "label": "未成年校外施法",           // 正典 424 行
  "severity": 1,                        // 1..5，见 §4.6
  "heat_gain": 1,                       // 违法时累加的法律风险（§5.3）
  "detect_base": 0.10,                  // 基础发现率（乘修正，见 §5.5）
  "min_age_months": 0,
  "max_age_months": 203,                // 仅未成年适用（17 岁 = 204 月）
  "canon_line": 424
}
```

```jsonc
// penalties.json —— severity → 刑罚档
{
  "severity": 3,
  "fine_min_galleons": 10,
  "fine_max_galleons": 25,
  "sentence_min_months": 1,             // 0 = 不判监禁
  "sentence_max_months": 3,
  "can_revoke_wand": false,             // 是否可剥夺魔杖（正典 第三十五章：剥夺魔杖）
  "azkaban": false                      // 是否阿兹卡班级（重罪）
}
```

⚠️ **为什么罪行与刑罚分两张表**：03a 的教训是「枚举散落多处」。
`severity` 是**唯一连接键**，罪行只说自己的严重度，刑罚档只说该严重度怎么判 ——
两者**各自独立可调**，且校验器能钉死「每个 severity 1..5 都有且只有一个刑罚档」。

---

## 4. 枚举与数值定版

> 全部数值经 Python 实算（§7），**不要自创**。

### 4.1 `WEALTH_TIERS`（家族财富档）

以「中位巫师家庭年收入」为单位定义。锚点：**中位年收入 = 168 加隆**（03b 实测：月薪 6900 纳特 × 12 ÷ 493）。

| tier | 年收入倍数 | 加隆区间 | 实算含义 |
| --- | --- | --- | --- |
| `没落` | 0 – 0.5 | 0 – 83 | 家道中落，接近平民 |
| `小康` | 0.5 – 3 | 83 – 503 | 普通殷实家庭 |
| `殷实` | 3 – 20 | 503 – 3359 | 上层中产 / 小家族 |
| `豪富` | 20 – 100 | 3359 – 16795 | 有名望的纯血家族 |
| `巨富` | 100 – 300 | 16795 – 50385 | 马尔福/布莱克级 |

⚠️ **实算发现（设计期缺陷 ①）**：初稿的「豪富 5000–50000 加隆」是**拍数**，
换算成生活月数是「平民 380–3806 个月支出」。作为**家族底蕴**尚可，
但**玩家直接继承该数即经济崩坏**（见 §5.7 继承稀释）。
改以「年收入倍数」定义后，巨富上限收敛到 **50385 加隆**（300 年收入）。

### 4.2 `SECRETS`（家族秘密）

正典第十三章 188 行列出「黑魔法传承、地下金库、密室、契约、古老诅咒、血脉污点」：

```gdscript
const SECRETS: Array[String] = ["dark_arts_legacy", "hidden_vault", "chamber",
	"ancient_contract", "old_curse", "blood_tarnish"]
```

### 4.3 `MAGIC_TRADITIONS`（家族魔法传承）

正典第十三章 184 行「魔杖传承、家族魔法」。枚举：
`none` / `wand_lore` / `dark_arts` / `healing` / `prophecy` / `metamorphmagus` / `beast_speech`。

### 4.4 `BENEFITS`（协会权益）

正典第十九章 231 行「资源、行业规则」。本计划落的权益（**全部可数值化**）：

| 键 | 含义 | 取值范围 |
| --- | --- | --- |
| `price_discount` | 所属行业商品的进货折扣 | 0.0 – 0.25 |
| `wage_bonus` | 行业相关职业的工资加成 | 0.0 – 0.30 |
| `access` | 解锁的行业活动（字符串枚举，可空） | 内容驱动 |

### 4.5 `SEVERITY`（罪刑严重度 1–5）

| severity | 档位名 | 典型罪行 | 罚金（加隆） | 刑期（月） | 可剥夺魔杖 |
| --- | --- | --- | --- | --- | --- |
| 1 | 轻微违规 | 未成年校外施法、乱扔粪弹 | 1 – 5 | 0 | 否 |
| 2 | 轻罪 | 无照经营、妨碍执法 | 5 – 15 | 0 | 否 |
| 3 | 普通罪行 | 走私、非法交易受管控物品 | 10 – 25 | 1 – 3 | 否 |
| 4 | 重罪 | 不可饶恕咒（未致死）、严重黑魔法 | 50 – 150 | 12 – 60 | **是** |
| 5 | 极重罪 | 谋杀、魂器、大规模黑魔法 | 200 – 500 | 60 – 240 | **是** + 阿兹卡班 |

**实算依据**（§7.2）：
- 罚金必须与**月薪（6900 纳特 = 14.0 加隆）**同量级。severity 3 的 10–25 加隆 =
  **0.71–1.79 倍月薪**（肉痛但可承受）；severity 5 的 200–500 加隆 = **14–36 倍月薪**
  （破产级，符合正典「重罪毁一生」）。
- 刑期：巫师寿命约 150 年。60 个月（5 年）= 人生的 3.3%，240 个月（20 年）= 13% ——
  **重罪该有分量**，但不会一判就废档。

### 4.6 法律风险常量（§5.3 用）

```gdscript
const HEAT_SAFE := 2          # 低于等于此值不起诉
const HEAT_CERTAIN := 10      # 达到此值必定起诉
const HEAT_DECAY := 1         # 每月自然冷却
const HEAT_GAIN_SMUGGLE := 1  # 走私（03b 的 smuggling_heat 迁移进来，见 §5.3 第 1 条）
const HEAT_GAIN_ILLEGAL_CAST := 2
const HEAT_GAIN_OUTLAW_JOIN := 3
```

起诉概率：`heat <= HEAT_SAFE` ⇒ 0；`heat >= HEAT_CERTAIN` ⇒ 1；否则 `(heat - SAFE) / (CERTAIN - SAFE)`。

⚠️ **实算发现（设计期缺陷 ②）**：初稿**只有累积没有衰减**，实算显示
「从 heat=3 起每月 +1 ⇒ 第 8 月必定被抓，且无任何翻身手段」。
这不是「严格」而是**不可玩**（玩家一旦沾违法就注定毁灭，且中间无法补救）。
加 `HEAT_DECAY = 1` 后：**单次违法（+3）在 3 个月内自然冷却到 0**，
「一次小错不该毁档」成立（§7.1 实算表）。

### 4.7 继承稀释常量（§5.7 用）

```gdscript
const INHERITANCE_TAX := 0.30        # 遗产税（魔法部征收）
const DEFAULT_HEIRS := 4             # 无遗嘱时的法定继承人份数
const WILL_LONGEST_SHARE := 0.50     # 有遗嘱指定长子时，长子的份额上限
```

⚠️ **实算依据**（§7.4）：巨富家族 50385 加隆，4 子均分 + 30% 税 ⇒ 玩家得 **8817 加隆**
= 平民 **54 年**生活费。⇒「出身富贵」仍是**巨大优势**，但非无限。这解决了缺陷 ①。

---

## 5. 规则口径（关键裁定）

### 5.1 家族状态容器

新增 `world.families`（与 `world.factions` / `world.economy` 并列）：

```gdscript
world.families = {
  "malfoy": {
    "wealth_galleons": 48000,      // 可变（遗传/破产）
    "prestige": 85,                // 可变
    "known_secrets": [],           // 玩家已知的秘密（信息保护）
    "discovered": false,           // 玩家是否知晓该家族存在
    "player_relation": 0,          // -100..100（玩家与本家族的关系）
    "last_change_turn": 0
  }
}
```

**初始化铁律（照 `Economy.initialize` 的教训）**：`initialize()` **只补缺键，绝不覆盖既有值**。
03b 的 `initialize` 曾有「覆盖 `prices`」的隐患，注释里明确写了「只补缺，绝不覆盖」。
本计划同款，且**必须有断言钉死**（往 `world.families` 塞一个自定义值，调 `initialize` 后必须不变）。

### 5.2 家族声望与玩家声望的关系

正典 451 行「家族拥有声望」，`PlayerState.reputation`（:23）是全局声望 —— **两者独立，不合并**。
理由：玩家可以是「家族受尊敬但本人是败家子」或反之。**03a spec §13 第 4 条**
（`standing` vs `reputation` 未处理）在此**部分回应**：家族声望是**第三个**独立维度，
本计划**明确不合并**，并记为可回退的裁定（§9 风险 7）。

### 5.3 法律风险累积（`illegal_heat`）

**统一入口**：新增 `world.law`：

```gdscript
world.law = {
  "heat": 0,                    // 法律风险暴露度（0..，无硬上限但 >=CERTAIN 必被抓）
  "open_case": "",              // 当前未结案件 id（空 = 无）
  "last_trial_turn": -1,        // 上次开庭回合
  "convictions": [],            // 定罪记录（{crime_id, turn, penalty}）
  "wand_revoked": false,        // 魔杖是否被剥夺（§5.9）
  "sentence_until_turn": -1     // 刑期结束回合（-1 = 未服刑）
}
```

**三条裁定**：

1. **`smuggling_heat` 与 `law.heat` 的关系**：03b 的 `world.economy["smuggling_heat"]` 是
   **走私专属计数**（03b 只记不判）。本计划**不迁移它**，而是在 `Law.tick()` 时
   **把它折进 `law.heat`**（`heat += smuggling_heat_gain × 本月新增走私次数`）。
   ⇒ 保持 03b 的数据不动（**不回改已完成计划的语义**），03c 只**新增读取与消费方**。
   ⚠️ 这需要 03b 在 `_record_trade_side_effects` 里的计数**能区分「本月新增」与「累计」**。
   **实况核对**（写 spec 时已查）：`state_ops.gd:293` 是**累计**递增，无月度分桶。
   ⇒ 口径改为：**`Law.tick()` 读累计值，与自己上次读到的值做差**，差值为本月新增。
   存 `law["_smuggle_seen"]`（下划线前缀，与 `flags` 的 `_` 约定一致，`OpGuard` 会拒 LLM 写）。

2. **起诉判定在每月 tick**（`WorldState.tick()` 的既有编排里插一段）：
   ```
   Law.evolve(world)   # ① 先衰减：heat = max(0, heat - HEAT_DECAY)
                       # ② 折入上月新增走私
                       # ③ 再判定：p = trial_chance(heat)；命中则开案
   ```
   ⚠️ **「先衰减后判定」是有意选择**（不是先判定后衰减）：这让「停手一个月」立刻有效，
   玩家的**补救行为可预期**。若反过来，玩家「停止违法后仍要吃一次起诉判定」，
   反馈延迟一个回合、体感不公平。**这个顺序必须有断言钉死**（构造 heat=3、停手，
   断言第 3 个月 heat=0 且不起诉）。

3. **未遂不计**（回应 `§8#28`）：`spell_resolver.gd:125` 只在**成功**时自增
   `illegal_cast_count`。**裁定：维持**。理由：法律上是「已实施」，未遂的施法**没有产生事实**，
   且正典未给「未遂加重」依据。**但要在 spec/HANDOFF 写明这是裁定而非疏漏**，
   并在 `Law.evolve` 里**只读 `illegal_cast_count`**（不新增未遂计数）。

### 5.4 `illegal_affiliation` 陈旧化（**必须闭合的挂账**）

现状（`state_ops.gd:87-89`）：加入 `outlaw` 派系时写 `world.flags["illegal_affiliation"]`，
**`leave_faction`（:90-96）不清除**。⇒ 玩家退出非法组织后，该标记永久滞留。

**裁定：三态归一**（把 bool 语义的 flag 升级为可判定的状态）：

| 情形 | 处置 |
| --- | --- |
| 玩家在非法派系中 | `world.flags["illegal_affiliation"] = <faction_id>`（**保持现状，不改写入端**） |
| 玩家退出该派系 | **清除**该 flag（在 `leave_faction` 的写状态分支里加一行 `world.flags.erase("illegal_affiliation")`） |
| 玩家切换到另一个非法派系 | 覆盖为新 id（现状已如此） |

**为什么在 `leave_faction` 里改**（而不是在 `Law.evolve` 里扫）：
`leave_faction` 是**唯一**能导致「不再是成员」的入口，在这里清除**与写入端对称**、
无需扫描、无时序问题。在 `Law.evolve` 里扫需要**每回合**遍历派系表并比对
`player.faction_id`，既慢又引入「谁先跑」的顺序依赖。

⚠️ **顺带修正语义**：`illegal_affiliation` 这个名字是**状态描述**（「当前有非法隶属」），
但现实现让它变成**历史痕迹**。清除后**语义与名字一致**。若将来需要「曾有非法隶属」的记录，
那是**定罪记录**的职责（`law.convictions`），不该复用这个 flag。
⇒ 在 `state_ops.gd` 该行加注释写明**契约**，并在 `HANDOFF §8` 把该挂账标注闭合。

### 5.5 发现率与司法偏见

**发现率** = `crime.detect_base` × 修正系数：

| 修正项 | 取值 | 依据 | 写入方核对 |
| --- | --- | --- | --- |
| 时代 | 用 03b `Economy.ERA_MULT` 的档位（早期执法弱） | 不新造口径 | ✅ `world.era_start_year` 有写入方 |
| 威森加摩控制权 | `1.0 + control × 0.5`（控制权越高，执法越有效） | 03a `institution_control` | ✅ 03a 已实现 |
| 地点 zone | `wild`/`forbidden` ⇒ ×0.5；`muggle` ⇒ ×0.8；其余 ×1.0 | 复用 `locations.json` 的 `zone`（21 条，5 类） | ✅ 内容表存在 |
| **玩家声望** | ~~`reputation > 50` ⇒ ×0.7；`< -50` ⇒ ×1.3~~ | — | ❌ **无写入方，见下** |

⚠️ **实况修正（设计期缺陷 ③，2026-09-22 写 spec 时实测）**：
`player.reputation` **全仓库没有任何写入方** —— `grep` 结果只有
`player_state.gd:23`（声明）+ 3 处**读取**（`prompt_builder.gd:92`、`panel_formatter.gd:47/163`）。
⇒ 它的值**永远是 0**，拿它当发现率修正的输入会造出**永远走缺省分支的死代码**
（**与 03b 缺陷⑧ `world_vars["location_tag"]` 完全同款**）。

**处置（二选一，本 spec 选 A）**：

- **A（采用）**：**去掉「玩家声望修正」这一项**。发现率只用前 3 项（时代 / 威森加摩控制权 / zone）。
  理由：正典第三十五章 422 行说「玩家的**身份**影响司法」，而**身份**在本项目里
  由 `birth_identity_id` / `bloodline_id` / `house_id` / `faction_id` 承载（都有写入方），
  **不需要**一个从未被赋值的 `reputation`。且「名人易被盯」这个机制**没有正典依据**。
- **B（不采用）**：给 `reputation` 补写入方（如 03c 起在定罪/立功时增减）。
  理由：这是**修一个 01/02 期遗留的空字段**，属独立议题；塞进 03c 会扩大范围。
  ⇒ 记为**挂账**（§9 风险 9），不在本计划处理。

**司法偏见**（正典 422 行「玩家的身份影响司法」）：
判决倾向 = `wizengamot` 控制权持有者的 `kind` 与**玩家身份字段**的关系。具体：

| 玩家身份 | 条件 | 效果 |
| --- | --- | --- |
| 血统偏见 | `player.flags["prejudice_level"]`（**§2.3 要提升为数值字段**） | 纯血法官席前**加重**量刑：`fine × (1.0 + prejudice)` |
| 出身地位 | `player.birth_identity_id` ∈ `PRIVILEGED_IDENTITIES` = `["noble_pureblood", "ministry_official", "auror_family", "professor_family", "goblin_contract", "st_mungo_family"]` | 量刑 **×0.7** |
| 派系立场 | `player.standing_of(wizengamot_holder) < -50` | 量刑 **×1.3** |
| 非法隶属 | `world.flags["illegal_affiliation"]` 非空 | 量刑 **×1.5**（§5.4 归一后仍是可靠判据） |

⇒ **四项输入全部有写入方**（`prejudice_level` 由 `character_creation.gd:246` 写、
`birth_identity_id` 由创建流程写、`standing` 由 03a 的 op 写、`illegal_affiliation` 由 `state_ops.gd:88` 写）。

### 5.6 协会行业准入

未加入协会时：
- 该协会 `industry_id` 对应的商品，**进货折扣不生效**（`price_discount` 只是会员权益）。
- `access` 中列出的活动**不可执行**（新增 op 检查）。
- **不禁售** —— 正典没有「非会员不得交易」的规则，本计划不制造无依据的限制。

⚠️ **与 03b 的边界**：03b 的 `industries.json` 已有 `monopoly` 概念（`MONOPOLY_EXCESS_MULT`）。
本计划**不修改**行业表，只在协会里**引用** `industry_id` 并读取其字段。

### 5.7 继承事件

触发：家族族长死亡（内容驱动）或玩家成年时的一次「遗产分配」。

```
遗产总额 T = family.wealth_galleons
可分额 = T × (1 - INHERITANCE_TAX)
玩家份额 = 可分额 × share
  share = WILL_LONGEST_SHARE  若玩家是被指定继承人（长子/遗嘱）
        = 1 / DEFAULT_HEIRS   否则（法定均分）
```

⚠️ **实算依据**（§7.4，论证经一次自我修正）：

| 情形 | 玩家所得 | 折合生活费 |
| --- | --- | --- |
| 独子、无遗嘱、无税 | 50385 加隆 | **319.6 年** ← 真要防的是这个 |
| 独子 + 30% 税 | 35270 加隆 | 223.7 年 |
| 4 子均分、无税 | 12596 加隆 | 79.9 年 |
| **4 子均分 + 30% 税（采用）** | **8817 加隆** | **55.9 年** |
| 长子独得 50% + 30% 税 | 17635 加隆 | 111.9 年 |

**两个杠杆作用不同**：**份数是主要的**（独子→4 子 = 除以 4），税是次要的（×0.7）。

**为什么必须稀释**：不是「8817 加隆太大」，而是**不能让玩家跳过积累阶段**。
03b 的核心玩法（存款生息 / 跨国套利 / 经营产业）靠的是**月度收支流**
（月薪 14 加隆、月支出 13.14 加隆）；一次性本金大**不等于**经济玩法失效 ——
8817 加隆能买 979 根普通魔杖，但**改变不了「每月挣 14 加隆」这个基本盘**。
真正会毁掉体验的是**独子继承 319.6 年生活费**：玩家一次继承就再也不需要任何月度收入。

> ⚠️ **起草时的自我修正**：初稿写「不稀释则 50385 加隆 = 1023 年生活费」——
> 这是**错的**（我把总额当年生活费算，且忽略了 4 子均分本身已经在稀释）。
> 实测：独子才 319.6 年，4 子均分只有 79.9 年。
> **教训**：论证「某数值过大」时，必须把**所有已生效的缩放**算进去，
> 不能拿「最坏情形」当「当前情形」。

### 5.8 傲罗行动

**不新建系统**，而是把「傲罗」接为**法律执行的可观测代理**：

- `law.heat >= HEAT_SAFE` 且 `auror_office` 控制权 ≥ 0.5 ⇒ 每月有概率**傲罗上门警告**（叙事事件）。
- `law.heat >= HEAT_CERTAIN` 时，若玩家不在 `wild`/`forbidden` zone ⇒ **必定开庭**（逃不掉）。
- 正典第十四章 192 行「傲罗是政治工具」⇒ 傲罗行动的**积极性**由 `auror_office` 的控制权持有者决定：
  若持有者是 `dark`/`resistance` 类派系，傲罗对玩家的**针对性**下降（`× 0.5`）。

### 5.9 剥夺魔杖

正典第三十五章 420 行列为刑罚之一。
- 判决 `can_revoke_wand = true` 且严重度达 4 时，可判剥夺。
- 实现：`law.wand_revoked = true`，并在**施法路径**（`SpellResolver.cast`）前置检查。
- **不得清空 `player.wand`**（那是玩家财产，且 03b 有魔杖交易）——
  用**独立 flag** 表达「使用权被剥夺」，与「是否持有魔杖」解耦。
- **可恢复**：服刑结束或缴纳赎金后 `wand_revoked = false`（正典未说不可恢复，留出口）。

### 5.10 新增 op（照 03b 的四条铁律）

照 `state_ops.gd` 的经济 op 风格（不部分执行 / 不抛异常 / 不动别的模块）：

| op | 参数 | 语义 |
| --- | --- | --- |
| `join_association` | `association_id` | 校验会费/技能/立场 → 扣费 → 记入 `world.associations` |
| `leave_association` | `association_id` | 退出（**不退费**） |
| `pay_fine` | `knuts` | 交罚金 ⇒ `law.heat -= knuts / 493`（1 加隆 = 1 点 heat） |
| `serve_sentence` | （无） | 服刑：推进到 `sentence_until_turn`，期间玩家不可行动 |

⚠️ **`pay_fine` 的降 heat 比例**（1 加隆 = 1 点）来自实算：罚 25 加隆 = 1.79 倍月薪
⇒ 能把 `heat=10`（必被抓）清零，平民**能承受但肉痛**（§7.3）。
这个「花钱消灾」通道是**缺陷 ② 的第二道补救** —— 除自然衰减外，玩家还能主动花钱。

### 5.11 `OpGuard` 新增闸门

照 03b 的双闸门（`MAX_TRADE_QTY` + `MAX_TRADE_VALUE`）：

```gdscript
const MAX_FINE_PAY := 25000        # 单笔罚金上限（纳特）≈ 50 加隆
const _LAW_FORBIDDEN := [...]      # 黑名单：不得直接写 law.convictions / wand_revoked / sentence_until_turn
```

**为什么 `convictions` / `wand_revoked` / `sentence_until_turn` 必须黑名单**：
这些是**司法产物**，只能由 `Law` 模块的判决逻辑写入。
若 LLM 能直接把它们设为 `[]` / `false`，等于**一键洗白犯罪记录**。

---

## 6. 任务拆分（草案，待计划文档细化）

| Task | 内容 | 关键门禁 |
| --- | --- | --- |
| 0 | 本 spec 定稿 + 实算 | 数值全部实算通过 |
| 1 | `families.json` + 校验 + `WorldFamilies.initialize` | 幂等断言（不覆盖既有值） |
| 2 | `associations.json` + 校验 | 引用完整性（`industry_id` 必须存在） |
| 3 | `crimes.json` + `penalties.json` + 校验 | severity 1..5 全覆盖且唯一 |
| 4 | `Law` 模块骨架（`world.law` + `initialize` + 常量） | 存档往返 |
| 5 | `Law.evolve`（衰减 → 折走私 → 判定开案） | **顺序断言**（先衰减后判定） |
| 6 | `illegal_affiliation` 三态归一 + 闭合挂账 | `leave_faction` 清除断言 |
| 7 | 判决与刑罚（罚金/刑期/剥夺魔杖） | severity→penalty 全覆盖 |
| 8 | 继承事件（稀释） | 实算数值断言 |
| 9 | 4 个新 op + `OpGuard` 闸门 | 黑名单拒绝断言 |
| 10 | 面板【家族】行真实取值（替换硬编码占位） | 端到端（`panel_test`） |
| 11 | `Outcome.rolled` + 展示层以 `blocked` 为唯一判据 | 回应 `§8#29` |
| 12 | 收尾（全绿 / 台账 / 文档 / B1 复跑 / 合入 `main`） | 4 道门禁 |

---

## 7. 设计期实算（Python，一次性脚本）

### 7.1 heat 衰减（缺陷 ②）

```
方案 A：每月 decay=1 + 每次违法 +1
  违法 1 次后停手：第1月 heat=1 p=0.000 → 第2月 heat=0 p=0.000 → …
  ⇒ 单次违法立刻可得清净 ✔
有衰减：从 heat=3 起每月 +1
  第1月 h=3 p=0.125 未抓 0.875
  第3月 h=5 p=0.375 未抓 0.410
  第8月 h=10 p=1.000 未抓 0.000
```
⇒ **有衰减时「持续违法」仍会在第 8 月被抓**（惩罚持续性），
但**停手即可脱身**（给玩家退路）。两者兼顾。

### 7.2 罚金与月薪的比值

```
月薪 6900 纳特 = 14.00 加隆；月支出 6477 纳特 = 13.14 加隆
罚 1 加隆  = 月薪 0.07 倍
罚 5 加隆  = 月薪 0.36 倍
罚 10 加隆 = 月薪 0.71 倍
罚 25 加隆 = 月薪 1.79 倍
罚 50 加隆 = 月薪 3.57 倍
罚 100加隆 = 月薪 7.14 倍
```
⇒ severity 1–3 落在 0.07–1.79 倍月薪（可承受），severity 4–5 落在 3.5–36 倍（破产级）。

### 7.3 pay_fine 降 heat

```
罚 5 加隆（月薪 0.36）→ heat -5
罚 10 加隆（月薪 0.71）→ heat -10
罚 25 加隆（月薪 1.79）→ heat -25
```
⇒ 25 加隆能把 `heat=10`（必被抓）清零，平民肉痛但可行 ✔

### 7.4 继承稀释（缺陷 ①）

```
巨富家族总额 50385 加隆 = 319.6 年生活费（月支出 6477 纳特 = 13.14 加隆）

  独子、无遗嘱、无税        ⇒ 50385.0 加隆 = 319.6 年   ← 真正的风险点
  独子 + 30% 税             ⇒ 35269.5 加隆 = 223.7 年
  4 子均分、无税            ⇒ 12596.2 加隆 =  79.9 年
  4 子均分 + 30% 税（采用）  ⇒  8817.4 加隆 =  55.9 年
  长子独得 50% + 30% 税      ⇒ 17634.8 加隆 = 111.9 年

校验「会不会毁掉 03b」：
  继承 8817 加隆 可买 979 根普通魔杖（9 加隆/根）—— 一次性购买力极强
  但 03b 玩法靠月度流：月薪 14 加隆 / 月支出 13.14 加隆
  ⇒ 一次性本金改不了月度收支基本盘 ⇒ 玩法仍成立 ✔
```

⇒ 采用 **30% 税 + 4 份均分**，玩家得 8817 加隆（55.9 年生活费）：
「出身富贵」仍是巨大优势（等于平民半辈子收入），但**不会让玩家跳过积累阶段** ✔

### 7.5 刑期占人生比例

```
巫师寿命 ~150 年
  1 月  = 0.06%
  3 月  = 0.17%
  12 月 = 0.67%
  60 月 = 3.33%
  240 月= 13.3%
```
⇒ 重罪 20 年刑期有分量但非废档 ✔

---

## 8. 元教训（**给后续计划通用**）

### 8.1 「锚点单位混用」在本 spec 设计期**再次发生**（第三次）

起草 §4.1 时我把「中位年收入 82800」当**加隆**用（实际是**纳特**），
算出的「没落 0–41400 加隆」错了 **493 倍**。

这与 03b §13 缺陷⑨（食物价按「西可数」填成「纳特数」）、
03b Task 7（`Money` 断言手算错误）是**同一形态**。
⇒ **凡涉及 加隆/西可/纳特 的数值，实算脚本里必须显式写出单位换算并打印中间量**，
不要用「裸数字」推进计算。本 spec §7 的脚本已照此修正。

### 8.2 「只有累积没有衰减」是设计期必须检查的动态平衡

缺陷 ② 的形态：**单调累积的量必然在有限步内触发上限**。
凡设计「累积型风险/资源」（heat / 债务 / 疲劳 / 声望），
**必须实算「停手后多久恢复」**，否则等于设计了一个不可逆的死亡螺旋。

### 8.3 「来源参数必须验证写入方存在」（沿用 03b 缺陷⑧）—— **本 spec 靠它抓到 2 个真问题**

写本 spec 时**主动核对**了每个引用参数的写入方，抓到两处：

1. **`smuggling_heat` 是累计而非月度分桶**（§5.3 第 1 条）：
   若照抄「本月新增走私次数」的想当然口径，会造出**永远读到 0 的死路径**。
   实测 `state_ops.gd:293` 是累计递增 ⇒ 改为「读累计 + 自我差分」。
2. **`player.reputation` 无任何写入方**（§5.5 缺陷 ③）：
   拿它当发现率输入 = 死代码。已从设计中**删掉该修正项**。

⇒ **这一步不能省**。它是 03b 缺陷⑧ 的元教训第一次**在设计期**（而非施工期）生效 ——
成本从「施工时发现重写」降到「写 spec 时改一段」。**建议后续所有计划照做：
spec 定稿前，对每个引用的外部参数跑一次 `grep` 确认写入方。**

### 8.4 「先查既有消费者，再定新表字段」（本 spec 的新教训）

起草 `families.json` 时我自创了一套字段（`wealth_tier`/`prestige`/`secrets`/`magic_tradition`），
写到最后核对 `panel_formatter.gd:160-170` 才发现：**面板家族行早已有一套完整的 11 字段契约**
（`surname`/`seat`/`members`/`marriage`/`allies`/`enemies`/`secret`/`heir`/`wand_legacy`…），
且**已经写好两分支渲染**，只是 `flags["family"]` 无写入方所以从未生效。

⇒ **教训**：新建 `data/*.json` 前，必须 `grep` 该主题的**既有读取方**。
若已有消费者，**字段名以消费者为准**（消费者是已审查、已写测试的既有契约）。
自创字段会导致「表建好了、面板读不到」的静默失效 —— 与 `HANDOFF §4` 第 20 条
（表现层清单不许出现字面点号键）是**同一类**问题：**内容与消费者不匹配时静默不生效**。

### 8.5 「数值定版必须回答『它让别的系统还有意义吗』」

缺陷 ① 的关键不是「50000 加隆太大」，而是**「玩家继承它之后，03b 的存款/贸易/套利会不会失去意义」**。
⇒ 给一个模块定数值时，要检查它**对已完成模块的玩法**是否造成毁灭性影响。
这条在 03b §13 第 4 条（锚点量级自洽）基础上更进一步：**不只自洽，还要与相邻模块的玩法共存**。

⚠️ **且论证时必须算准「当前情形」而不是「最坏情形」**（见 §5.7 的自我修正）：
我初稿用「未稀释的总额」论证必要性，夸大了 3.2 倍。
**论证数值风险的正确姿势**：把**所有已生效的缩放**（份数/税/时代系数）先乘进去，
得到玩家**实际会拿到**的数，再拿它跟相邻系统的量级比。

---

## 9. 风险与未决

1. **家族数量**：本计划假设 8–12 个家族（正典明确提到的 + 可推断的）。
   数量改 `data/families.json` 即可，代码不受影响（枚举校验只覆盖 `wealth_tier`/`secrets` 集）。
2. **`HEAT_SAFE=2` / `HEAT_CERTAIN=10` 是首版拍数**，需实跑观察是否过严/过松。
   调整只改常量（且断言集中在 `law_test`），不动结构。
3. **遗产税 30% 是裁定**，正典未给税率。若实跑觉得过重/过轻，改 `INHERITANCE_TAX` 即可。
4. **`pay_fine` 降 heat 比例（1 加隆 = 1 点）是裁定**：正典未说罚金能消除嫌疑。
   若评审认为不合理，退路是**删掉该通道**（只保留自然衰减），代价是「被盯上后只能等」。
5. **隐藏派系的控制权数值仍显示**（`HANDOFF §8` 记账区）：**本计划不动**。
   理由：那是**界面信息保护**问题（03a-P 的 `revealed` 已管住「身份」），
   改它要动 `panel_formatter` 的信息过滤层，与本计划的「社会与法律」主题无关。
   若评审要求一并处理，应作为**独立小任务**（属界面改版）。
6. **`factions.json` 缺 `allies`/`rivals` 的自反与互斥校验**（03a 遗留）：
   本计划在 §3.1 为自己的表加了这两条校验，并顺手给 `factions.json` 补。
   ✅ **已实测（2026-09-22，写 spec 时即验证，不留到实施）**：对既有 17 条派系跑检查 ⇒
   自引用 **0** 条 / 既盟友又仇敌 **0** 条 / 悬空引用 **0** 条。
   ⇒ **补校验是纯增量改动，不会打破任何既有数据**。风险评估从「可能报错」降为**无风险**。
7. **家族声望是否应与玩家声望合并**：本计划裁定**不合并**（§5.2）。
   这条与 03a spec §13 第 4 条（`standing` vs `reputation`）相关，
   **若评审给出统一方案，本计划的 `prestige` 要跟着调整**。
8. **`prejudice_level` 提升为数值字段**会动 `PlayerState` 的 schema ⇒ **存档兼容**要注意。
   缓解：`from_dict` 保留从 `flags` 迁移的**兜底读法**（旧档里若 `flags` 有该键，读进新字段）。
9. **`player.reputation` 无写入方**（设计期缺陷 ③ 发现，**01/02 期遗留**）：
   它永远是 0，面板【声望】行与 PromptBuilder 都在显示一个恒为 0 的值。
   **本计划不修**（§5.5 已把它的使用去掉）—— 补写入方是**独立议题**，
   且要先裁定「什么行为该加声望」（属玩法设计，不属本计划范围）。
   ⇒ 记入 `HANDOFF §8` 的记账区。

---

## 10. 后续计划边界

- **04** 神奇生物生态与区域危险度（03b 的 `creature` 类商品是它的输入）。
- **05** NPC 自主与信息可信度（本计划的 `families`/`associations` 是 NPC 归属的载体；
  `HANDOFF §8` 的 `npc.faction_id` 接口在这里接上）。
- **06** 多世代传承与世界记忆（本计划的**继承**是它的前身；跨代续玩、家族兴衰史属它）。
- **独立小计划**：存档格式 v2（`§8#9/#19/#26/#49/#71`）、设置界面（`§8#63`）、流式输出。
- **本计划有意推给后续的**：
  - 家族家谱（世代树）⇒ 06（需要跨代数据）
  - NPC 家族内部斗争 ⇒ 05（需要 NPC 自主）
  - 战争与城堡攻防 ⇒ 独立计划（正典第三十九章）
  - 6 件未接 UI 切片（`panel_bg` 等）⇒ 下一次界面改版
