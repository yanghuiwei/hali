# 计划 03b · 经济骨架 设计（Spec）

> 状态：**待用户评审**
> 日期：2026-09-21
> 依据：计划 01（核心模拟地基）/ 02（LLM 叙事引擎）/ 03a（派系与政治骨架，含 03a-P 表现层与 B8）均已完成并合入 `main`（`24482bc`）。
> 范围拆解：用户已于 2026-09-20 裁定「派系与政治经济」过大，拆为 **03a 政治与派系骨架 → 03b 经济骨架（本 spec）→ 03c 社会与法律**。边界定义见 `docs/superpowers/specs/2026-09-20-hp-magic-era-03-factions-design.md` §14。
> 目标读者：零上下文的实现者。实现计划见后续 `docs/superpowers/plans/2026-09-21-hp-magic-era-03b-economy.md`（由 writing-plans 产出）。

---

## 1. 目标

把「钱」从**一个孤零零的整数**变成**会流动、有摩擦、可经营**的经济系统。当前状态（均为实读源码确认，非推测）：

| 现状 | 位置 | 问题 |
| --- | --- | --- |
| `money_knuts: int`，唯一变更入口是 `add_money` | `src/model/player_state.gd:22`、`src/rules/state_ops.gd:13-18` | 钱只能由 LLM/替身随手给，没有**来源**（工资/经营/存款利息）也没有**去处**（物价/房租/学费） |
| 物价**完全不存在** | `data/` 下无任何商品/价格表 | 同一件东西在 990 年和 2010 年、在伦敦与霍格莫德是同一个价 |
| 魔杖/魔药价格写在正典但没进表 | `哈利·波特·魔法纪元.md:223` | 只有测试里硬编码过一个数（`task-4-review.md`），不能参与经济演化 |
| `economy_index` 是个**纯标量** | `src/model/world_state.gd:67` | 它只被 `factions.gd` 拿来算 tension/政体（`factions.gd:248/348/369`），**与玩家一分钱关系都没有** —— 世界穷不穷不影响玩家的物价 |
| 无古灵阁、无利息、无汇率 | —— | 正典第十八章「不同国家有不同货币，汇率由古灵阁及国际巫师联合会协调」无落点 |
| `Money` 负值显示未定义 | `src/model/money.gd:29-42`，`§8#5` | `parts()` 返回 `[-g,-s,-k]`，`formatted()` → `"0加隆 -2西可 -16纳特"`；**已被面板输出到 UI**（`panel_formatter.gd:43/128/131`） |

本计划交付：**商品与价格表 → 玩家收入/支出流 → 古灵阁（存款/利息/汇率）→ 贸易价差与走私 → 经济危机连锁 → 债务显示 → 面板与经济指标接线**。

一切数值变化仍走既有骨架：随机走 `RngService` 命名流、状态变更走 `StateOps`、持久化走 `to_dict()/from_dict()`；**不新增第二套状态机**，不给 LLM 直达通道。

## 2. 非目标（本计划刻意不做）

- **协会体系与行业规则**（第十九章 8 个协会的会长/分部/会员制）：属 **03c**。本计划只让「产业」有产出，不建协会。
- **纯血家族财产与继承**（第十三章家谱、祖宅、遗产）：属 **03c**。面板【家族】行的「财富/祖宅」字段在 03c 才会真正取值。
- **法律后果**（走私被抓 → 威森加摩开庭 / 罚金 / 阿兹卡班）：属 **03c**。本计划只记录 `flags["smuggling_heat"]` 计数与 `illegal` 标记，**不做判决**（与 03a 的 `flags["illegal_affiliation"]` 同款处理）。
- **NPC 经济行为**（NPC 会开店/破产/交易）：属 **05**。本计划只让世界的 `economy_index` 影响价格，不模拟 NPC 账本。
- **货币兑换的完整多币种体系**：只做**一种外币**（用于正典第十八章「汇率」有落点）+ 古灵阁兑换接口；不做 10 国货币。
- **不做经济 UI 面板的重新设计**：面板只**新增**经济相关行（见 §7.6），不改既有 3 行结构与创建界面。
- **不引入新的异步/网络**：纯离线，价格表是 `data/*.json`。
- **不修 `Money` 的存储格式**（仍是 `money_knuts: int`）—— 只补**负值语义**（§7.5）。存档 `save_version` 不变（仍 1），除非 §7.5 裁定为「需要额外字段」。

## 3. 已确认决策

| 编号 | 决策 | 理由 / 备注 |
| --- | --- | --- |
| **E1** | 新增内容表 `data/goods.json`：商品/服务（**含服务**：房租、学费、车票、治疗费、解咒服务）。字段见 §7.1。规模 **28–40 条**，覆盖正典第十七章 9 大产业 + 第十八章 5 个价位锚点 + 第十六章资源。 | 铁律：内容进 `data/`。价格是内容，**演算是代码**。 |
| **E2** | 新增内容表 `data/industries.json`：产业（魔药/魔杖/扫帚/出版/魁地奇/神奇生物养殖/魔法考古/解咒/金融共 9 条，照正典第十七章），字段见 §7.2。每条产业声明它 `produces`（引用 `goods.json` 的 id）与 `inputs`。 | 正典第十七章明列这 9 个产业；`produces/inputs` 是「经济危机如何传导到物价」的载体。 |
| **E3** | **`economy_index` 保留为世界标量，但它成为价格的唯一总开关**：`price(good, world) = base_price × era_multiplier × scarcity_multiplier(economy_index) × supply_multiplier(产业产出) × local_multiplier(location)`（口径见 §7.4）。**不再新增 `world_vars` 键**（沿用 03a D3 的理由：零 `eras.json` 改动、零存档迁移）。 | 现状是「世界穷不穷与玩家无关」，这是本计划要修的核心断链。用已有的 `economy_index` 当总开关，比新增 5 个变量便宜且语义清楚。 |
| **E4** | 玩家收入走**两个通道**：① `ops`（LLM/替身给，既有 `add_money`，保持不变）；② **规则层结算**：`Economy.monthly_settlement(world)` 在 `tick()` 里按「玩家职业 + 所在地 + 世界景气」自动结算**工资/经营收入/生活开销/存款利息**。②是新增的主路径。 | 现状是「不打工就没钱，打工全靠 LLM 心情给数」。月度结算是「世界始终向前推进」的必要条件，且它是**确定性的**（可测）。 |
| **E5** | 新增 `WorldState.economy: Dictionary`（不入 `world_vars`，结构见 §7.3）：`{gringotts_balance, gringotts_interest_rate, foreign_rate, prices, smuggling_heat, last_settlement_turn}`。**`economy` 必须加入 `SaveCodec` 的字典字段白名单**（与 03a 的 `factions` 同款）。 | 存款、汇率、当前物价快照都要持久化。放 `economy` 而非塞进 `flags`（`flags` 是 bool/杂项语义，塞结构化数据会让 `JsonUtil.normalize` 的往返测试变模糊）。 |
| **E6** | **古灵阁**：存款 `deposit_money` / 取款 `withdraw_money` / 查余额三件事。余额**生息**（月息 `gringotts_interest_rate`，默认 0.002），利息在月度结算里加。汇率 `foreign_rate` 由 tick 按月小幅波动，`exchange_money` op 按当时汇率换（有**买卖价差**，见 §7.5）。 | 正典第十八章「古灵阁金融」「汇率由古灵阁协调」。存款生息给「攒钱」一个正反馈，也是通胀/危机的缓冲垫。 |
| **E7** | **贸易价差与走私**：同一商品在不同 `location` 有不同的 `local_multiplier`（产地便宜、销地贵）；`trade_money` op 允许玩家**低买高卖**，利润 = 价差 − 路费（路费按两地距离系数）。走私 = 交易 `illegal:true` 的商品（正典第十八章「走私魔法生物、跨国倒卖稀有材料」），只记 `smuggling_heat` 与 `flags["illegal_trade"]`，**后果留 03c**。 | 正典第十八章把「开魔药店/经营书店/制作扫帚/古灵阁解咒员/购药/走私/跨国倒卖」列为玩家可做的事。价差是「贸易」有意义的必要条件（否则所有的钱等价）。 |
| **E8** | **经济危机连锁**：`economy_index` 跌破阈值（默认 ≤0.35）时进入**危机态**：① 物价乘数上抬（`scarcity_multiplier` 走 §7.4 曲线）；② 部分商品**断供**（`supply` 归零 ⇒ `available=false`）；③ 触发一次「金融危机」事件（正典第四十六章世界级事件之一，**03a 的 `events` 通道已有此事件类型，本计划只让它是经济驱动的**）；④ 存款**利息下调**、走私**利润率上升**（黑市繁荣，正典第十六章）。 | 正典第十六章：「资源短缺可能导致魔药涨价、魔杖供应危机、医疗能力下降、黑市繁荣，甚至爆发争夺资源的冲突」—— 这四件事本计划都要有可观测落点。 |
| **E9** | `Money` 负值语义落地（修 `§8#5`）：新增 `Money.is_debt()` 与 `Money.debt_formatted()` → **`"负债 2加隆 16纳特"`**（⚠️ 第三位是**纳特**：1002 = 2×493 + 16）；`formatted()` 对负值**改为**输出该债务形态（**这是行为变更**，见 §13 风险 1，需你点头）。同时 `parts()` 保持现状（返回带负号的 `[-g,-s,-k]`）以不破坏既有断言。 | `§8#5` 挂账原文：「债务场景会显示负值西可/纳特」。当前 UI 已经在输出 `"0加隆 -2西可 -16纳特"`。**「负债 X」是中文语境下的自然读法**，且不引入新状态。 |
| **E10** | 顺手项（`NEXT-STEPS §C` 与 `HANDOFF §8` 里「经济/债务必碰」的）：`§8#5`（Money 负值，E9）。**其余顺手项不塞进本计划** —— 存档格式 v2（`§8#9/#19/#26/#49/#71`）单独立项，因为它与 03b 的 `economy` 字段**必须一起做迁移**，故本计划只在 `SaveCodec` 里加白名单，**不升 `save_version`**。 | 03a 的先例：顺手项只在「顺手且不占主线」时才做。存档 v2 一旦开动就是一个独立批次。 |
| **E11** | 面板：`player_panel` 的【财富】行增加**存款**显示（有余额时 `（含古灵阁 X加隆）`）；新增一行 **【经济】**：`景气 0.61 ｜ 存款利率 0.20% ｜ 外币汇率 1.03 ｜ 本月收支 +12纳特`。`power_panel` 的「财政」指标**保持不变**（仍来自 `economy_index`，见 `panel_formatter.gd:116`）。 | 「世界景气」与「我的钱」必须能在同一屏里对上，「我对经济做了什么」才有反馈。 |
| **E12** | LLM 侧只**增**两个 op（`deposit_money` / `withdraw_money`），`exchange_money` / `trade_money` 也开放给 LLM；**绝不允许** LLM 直接改 `economy_index`、`gringotts_interest_rate`、`prices`、`smuggling_heat`（无此类 op，沿用「未知 op 一律拒绝」）。`OpGuard` 需钳制金额上限。 | 与 03a 的 D4/OpGuard 策略一致：LLM 动玩家侧，不动世界经济。 |

### 请你裁定（4 条）

| 编号 | 问题 | 我的建议 |
| --- | --- | --- |
| **K1** | `formatted()` 对负值改成输出「负债 X加隆 Y西可」（E9）是**行为变更**，会让 `money_test` 与面板输出的既有断言需要同步改。接受吗？ | **接受**。现输出 `"0加隆 -2西可 -16纳特"` 是明确的 bug 形态（`§8#5` 原文承认「未定义」）；「负债」是中文自然读法。替代方案是新增 `debt_formatted()` 而 `formatted()` 保持原样，但那等于**让 UI 继续错下去**。 |
| **K2** | 月度结算（E4②）默认**给玩家发工资**（按职业），这会让「不行动也能活下去」成为默认。接受吗？ | **接受，但要有门槛**：只对有 `job` 且成年（`age_months >= 17×12`）的玩家结算；无业者只有**支出**没有收入（会真的变穷）。正典第十五章「普通巫师的一日只是上班」，故「上班有钱」是正典基线；「不工作会饿」才是模拟器的意义。 |
| **K3** | 经济危机（E8）触发时是否要**通知玩家**（写 `events` + 面板提示），还是静默调价？ | **要通知**。静默调价会让玩家觉得「系统在坑我」；正典第四十六章把「金融危机」列为世界级事件，本计划让它走既有 `events` 通道（与 03a 政治事件同款）。 |
| **K4** | `data/goods.json` 的规模（28–40 条）与「服务类商品也进表」接受吗？ | **接受**。服务（房租/学费/车票/治疗/解咒）是玩家支出的大头，不进表则「生活开销」无从算起。数量取「9 大产业 × 2–4 条 + 生活服务 8–10 条」的最小集。 |
| **K5** | `scarcity_mult` 的**繁荣侧弹性**（§7.4 第 2 条的口径 A 还是 B）？ | **建议口径 A（默认）**：危机侧陡、繁荣侧缓更贴近现实，且不让「攒钱」变得无意义。若你希望「好时代明显便宜」，选 B。**实算已确认：两套都通过 C1–C6 全域守门**（常态同 7.00 加隆，仅繁荣侧不同：A 极盛时 6.30、B 极盛时 5.25）。<br>⚠️ **原 spec 的口径 A/B 数值表（8.89/8.09 加隆等）已作废** —— 那版用了错误的公式（canon 当 base 且无封顶），实算发现会突破正典上沿。现表见 §7.4 第 2 条。 |

## 4. 正典依据（行号指 `哈利·波特·魔法纪元.md`）

| 行 | 章节 | 本计划用到什么 |
| --- | --- | --- |
| 196 | 第十五章 普通巫师社会 | 职业清单（商人/魔药师/记者/治疗师/店员/酒吧老板/扫帚修理工/猫头鹰驯养师/魁地奇球员）⇒ `job → 工资`映射；「上班」是正典基线（K2） |
| 203 | 第十六章 魔法农业与资源 | 资源清单（魔药材料/草药/神奇生物产物/魔杖木材/矿石/龙血/凤凰眼泪/独角兽尾毛）⇒ `goods.json` 的原材料条；**短缺的四种后果**（涨价/断供/医疗下降/黑市/冲突）⇒ E8 四条可观测落点 |
| 209 | 第十七章 经济系统 | 9 大产业 ⇒ `industries.json`；高价值资源 ⇒ 高价商品；「魔法物品不能无限生产」⇒ `supply` 上限；魔杖家族垄断 ⇒ `monopoly` 标记 |
| 219 | 第十八章 货币与贸易系统 | 1加隆=17西可=493纳特（**已实现**，`money.gd:4-6`）；**5 个价位锚点**（普通家庭年收入约数百加隆 / 普通魔杖 7–10 加隆 / 优质疗伤药剂 5–20 加隆 / 光轮扫帚数十至数百加隆 / 隐形衣无法用加隆衡量）⇒ `goods.json` 的 `canon_price` 与校准依据；7 项玩家可做贸易 ⇒ E7 的 op 集合；汇率 ⇒ E6 |
| 227 | 第十九章 协会体系 | **不实现**（属 03c）；只让产业的 `produces` 与协会无关联 |
| 527 | 第四十六章 世界级事件 | 「金融危机」是既有事件类型之一 ⇒ E8③ 复用该通道 |
| 531 | 第四十七章 月度世界演化 | `monthly_settlement` 作为 `tick()` 新阶段的合法性 |
| 668 | 第六十五章 魔法部/学院/家族面板 | 【家族】行的「财富/祖宅」字段存在但**本计划不填**（属 03c）；【财富】行本计划扩展（E11） |
| 688 | 第六十八章 防过度热闹 | 经济事件的概率门与 `MAJOR_EVENT_GAP`（复用 03a 机制，不新开配额） |

## 5. 架构

```
WorldState.tick()  （唯一的世界时间推进入口）
  ├─ (既有) ① world_vars 回归/扰动          ← economy_index 在这里演化（本计划让它真的驱动价格）
  ├─ (既有) ② 传闻事件
  ├─ (既有) ③ 派系传闻揭示
  ├─ (既有) ④ WorldFactions.evolve()
  ├─ (新增) ⑤ Economy.evolve(world)         ← 见 §9：物价快照 / 汇率 / 利率 / 危机态 / 走私热度
  ├─ (新增) ⑥ Economy.monthly_settlement(world) → 玩家工资·开销·利息（确定性，无随机）
  ├─ (既有) ⑦ 生活基线
  ├─ (既有) ⑧ 年龄
  └─ (既有) ⑨ 日志裁剪                       ← 必须排在新阶段之后（裁剪要能裁到新事件）

玩家侧            （既有）StateOps.apply(ops)  ← 唯一变更入口
  └─ (新增 op) deposit_money / withdraw_money / exchange_money / trade_money

查询层            （新增）Economy.price_of(world, good_id) / Economy.affordable(world, good_id)
呈现              （既有）PanelFormatter.player_panel（加【经济】行）· PromptBuilder.state_digest（加经济摘要）
```

依赖方向：`src/rules/economy.gd` 只读 `world` + `registry`，把变化**经返回值交给 `tick()` 写回**（或由 tick 直接写 `world.economy`，口径见 §7.3 的约定）；**不反向依赖 UI/GM**。

### 5.1 与 03a 的接线（已冻结的部分不许动）

03a 已经把 `economy_index` 接进了派系层（`factions.gd:248` 用它算 tension 的基线、`:348` 经济危机进政治事件、`:369` 危机的判据）。**本计划必须保持这三处的语义**：`economy_index` 仍是 0..1 的标量，本计划只是**给它加一个下游消费者（价格）**，不改变它自身的演化规则（仍在 `world_state.gd:81-86` 向 era 基线回归 + 扰动）。

⇒ 这是一条**只读挂接**，不是重构。若实现时发现必须改 `factions.gd`，**先改 spec 文本**（03a 的铁律：计划与实跑冲突时先改计划）。

## 6. 文件结构

| 文件 | 状态 | 职责 |
| --- | --- | --- |
| `data/goods.json` | 新增 | 商品与服务（§7.1 schema），**35 条**（已实算定版：25 goods + 10 service） |
| `data/industries.json` | 新增 | 9 大产业（§7.2 schema），含 `produces`/`inputs` |
| `src/core/registry.gd` | 修改 | `TABLE_FILES` 注册 `goods` / `industries`；`validate()` 增加两表校验（引用合法性、枚举、价格 > 0） |
| `src/rules/economy.gd` | 新增（`class_name Economy`） | 价格计算、月度结算、危机态、汇率/利率、古灵阁、贸易价差、走私热度 |
| `src/model/world_state.gd` | 修改 | 新增 `economy: Dictionary` 字段；`create()` 初始化；`from_dict()` 补齐（幂等）；`tick()` 追加两个阶段 |
| `src/model/money.gd` | 修改 | `is_debt()` / `debt_formatted()`；`formatted()` 负值分支（E9/K1） |
| `src/rules/state_ops.gd` | 修改 | 4 个新 op（`deposit_money`/`withdraw_money`/`exchange_money`/`trade_money`） |
| `src/gm/op_guard.gd` | 修改 | 4 个新 op 的金额钳制（`MAX_BANK_MOVE` 等常量）；**不允许**任何改世界经济的载荷 |
| `src/ui/panel_formatter.gd` | 修改 | `player_panel` 加【经济】行 + 【财富】含存款；负值走债务形态 |
| `src/gm/prompt_builder.gd` | 修改 | `state_digest` 增加经济摘要（景气 + 玩家存款 + 主要物价 2–3 条） |
| `src/persist/save_codec.gd` | 修改 | `economy` 加入字典字段白名单（**不升 `save_version`**） |
| `data/rumors.json` | 修改 | 追加经济类传闻（物价飞涨/古灵阁挤兑/黑市繁荣），带 `zones`/`min_year`/`requires_flags` |
| `tests/economy_test.gd` | 新增 | 价格/结算/危机/古灵阁/贸易/确定性（**必须加进 `run_tests.gd` 的 `SUITES`**） |
| `tests/money_test.gd` | 修改 | 负值形态（E9）+ 既有断言的同步 |
| `tests/panel_test.gd` | 修改 | 【经济】行 + 债务显示 |
| `tests/save_test.gd` | 修改 | `economy` 往返一致 + 老存档补齐 |
| `tests/registry_test.gd` | 修改 | 两张新表的校验 |
| `tests/gm_test.gd` / `tests/llm_test.gd` | 修改 | 4 个新 op 的守卫与端到端 |
| `tools/b1_acceptance.gd` | 修改 | 新增「经济可观测契约」清单（存款利息真的到账、物价随景气变化、债务显示） |

## 7. 接口契约

### 7.1 `data/goods.json`（数组）

```json
{
  "id": "wand_standard",
  "label": "普通魔杖",
  "category": "wand",
  "kind": "goods",
  "canon_price_knuts": 3451,
  "canon_price_hi_knuts": 4930,
  "canon_line": 223,
  "base_price_knuts": 3451,
  "industry_id": "wandmaking",
  "inputs": ["wand_wood", "wand_core"],
  "illegal": false,
  "supply_critical": false,
  "unit": "根",
  "notes": "正典 223 行「一根普通魔杖：7‑10加隆」，canon 区间 = [7, 10] 加隆 = [3451, 4930] 纳特"
}
```

- `category` 取值（代码侧白名单）：`wand` / `potion` / `material` / `broom` / `book` / `food` / `service` / `creature` / `artifact` / `illegal`。
- `kind`：`goods` / `service`（服务没有 `inputs`，且不参与 `supply_critical` 断供逻辑）。
- `canon_price_knuts`：**正典锚点**，只有正典明确写了价位的条目才有；`canon_line` 给行号。
  无正典价位的条目 `canon_price_knuts = 0` 且 `canon_line = 0`（表示「价格为推演值」）。
  **语义（2026-09-21 实算后收窄）**：它是一个**价位区间的下沿**（如普通魔杖的 7 加隆），
  不是该商品的精确价。它**只用于对齐正典**，不直接参与算价。
- `canon_price_hi_knuts`：**该正典区间的上沿**（普通魔杖 10 加隆 = 4930）。仅当 `canon_price_knuts > 0` 时有意义，
  非锚点条目写 `0`。**它只有一个用途：给 `Registry.validate()` 提供 C3 的真正上界。**
  ⚠️ 为什么必须单独存一个字段（2026-09-21 实算逼出的修正）：
  原先用 `roundi(canon_price_knuts × MAX_SCARCITY / MIN_SCARCITY)` 当上界推导，隐含假设「**一条商品 = 一个 canon 窗口，且 base 就在下沿**」。
  `potion_healing_premium`（顶级疗伤药剂）打破了这个假设 —— 它与 `potion_healing` **共享同一个 canon 区间**（正典只给了
  「优质疗伤药剂 5–20 加隆」一个区间），但 base 取该区间**上段**（12.50 加隆 = 6162）。用推导式算出上界 4601，
  会把一个 **C3 实际满足**（危机峰 8627 < canon_hi 9860）的条目误判为越界。
  ⇒ 上界必须来自**正典写明的区间上沿本身**，而不是从下沿反推。
- `base_price_knuts`：**实际算价基准 = 常态零售价**（`index=0.5` / **`era_mult == 1.0` 的时代** / `local=1.0` 时的价，见 §7.4 C1）。
  ⚠️ **「常态」不含时代加成**（2026-09-21 Task 2 施工时的口径澄清）：C1 的定义点是**中性时代**，
  **不是 `modern` 时代**。`modern`（2010）的 `era_mult = 1.10`，其物价 = `base × 1.10` ——
  这是**有意的**（现代巫师社会物价高于 1950 年代 canon 语境）。把 `modern` 当定义点会让
  危机峰价被时代系数顶出 `canon_hi`（实算：3451×1.10×1.40 = **5315 > 4930**）。
  ⚠️ **原 spec 要求「有正典锚点的条目必须 `== canon_price_knuts`」，该硬校验已作废**（实算证明二者不是同一个量）；
  `Registry.validate()` 改为：`base_price_knuts > 0`，且**若 `canon_price_knuts > 0` 则 `base_price_knuts` 必须落在
  `[canon_price_knuts, canon_price_hi_knuts]` 内、且 `roundi(base_price_knuts × MAX_SCARCITY) <= canon_price_hi_knuts`**
  （即**「常态价在正典区间内」+「危机峰价不突破正典上沿」**两条一起查，这才是 C3 的机器保障）。
- `industry_id`：**必须**引用 `industries.json` 存在的 id（服务类可空串）。
- `inputs`：**必须**引用本表存在的 id（可为空数组）。
- `illegal`：走私品（`true` ⇒ 交易时走 E7 的走私记账）。
- `supply_critical`：短缺时会**断供**的条目（正典第十六章的四类后果之一）。
- `unit`：中文量词（「根」「瓶」「把」「份」），面板与叙事会拼成「3 根普通魔杖」。

**校准要求（必须遵守）**：`canon_price_knuts` / `canon_price_hi_knuts` 必须能对上正典第十八章 5 个锚点 —— 普通魔杖 7–10 加隆、优质疗伤药剂 5–20 加隆、光轮扫帚数十至数百加隆、普通家庭年收入约数百加隆、隐形衣**不进表**（正典明说「无法用加隆衡量」⇒ 进表会把「不可定价」变成「可定价」，违背正典）。

**正典锚点区间表（定版，4 条带 canon 价位）**：

| 商品 id | canon 区间（加隆） | `canon_price_knuts` | `canon_price_hi_knuts` | `canon_line` |
| --- | --- | --- | --- | --- |
| `wand_standard` | 7 – 10 | 3451 | **4930** | 223 |
| `potion_healing` | 5 – 20 | 2465 | **9860** | 223 |
| `potion_healing_premium` | 5 – 20（同上，取上段） | 2465 | **9860** | 223 |
| `broom_nimbus` | 数十 – 数百 | 49300 | **147900** | 223 |

> ⚠️ `broom_nimbus` 的「数十至数百加隆」在正典里是模糊量词，本表取 **100–300 加隆**作为可校验的具体化区间
> （下沿取实算定的 100 加隆，上沿按 3 倍取 300 加隆 —— 与「数百」的语义一致，且给 C3 留出合理余量）。
> 若将来要收紧，**先改这张表再改 `goods.json`**。

### 7.2 `data/industries.json`（数组）

```json
{
  "id": "wandmaking",
  "label": "魔杖制造",
  "canon_line": 211,
  "produces": ["wand_standard", "wand_elder"],
  "inputs": ["wand_wood", "wand_core"],
  "base_output": 0.7,
  "monopoly": true,
  "agenda": "奥利凡德、格里戈维奇等家族世代垄断部分市场"
}
```

- 9 条固定：`potion_brewing` / `wandmaking` / `broommaking` / `publishing` / `quidditch` / `creature_breeding` / `archaeology` / `curse_breaking` / `finance`（正典第十七章逐条对应，`canon_line: 211`）。
- `produces` / `inputs`：**必须**引用 `goods.json` 存在的 id（`Registry.validate()` 校验；空数组合法）。
- `base_output`：0..1，行业基础产出率（被 `economy_index` 调节，见 §7.4）。
- `monopoly`：正典「家族世代垄断部分市场」⇒ `true` 的行业在危机时**涨价幅度更大**（垄断者转嫁成本，§7.4）。
- `agenda`：一句中文说明（面板/叙事可用）。

### 7.3 `WorldState.economy`（新字段，D/E5）

```gdscript
var economy: Dictionary = {}
# {
#   "prices": {"wand_standard": 3451, ...},          # 本月物价快照（纳特，int）——由 tick 刷新，读价格走 Economy.price_of()
#   "gringotts_balance": 0,                          # 玩家存款（纳特）
#   "gringotts_interest_rate": 0.002,                # 月息
#   "foreign_rate": 1.0,                             # 外币/加隆（1.0 = 平价）
#   "smuggling_heat": 0,                             # 走私热度（0..10，只记不判）
#   "crisis": false,                                 # 是否处于危机态
#   "last_settlement_turn": 0,                       # 幂等标记：防止同回合重复结算
#   "last_month_income": 0, "last_month_expense": 0  # 供面板显示（纳特）
# }
```

**约定**：
- `prices` 是**快照**（tick 算一次），不是真值源；`Economy.price_of()` 是**唯一入口**（它先查快照，缺则现算）。这样面板/叙事/GM 三处读到的价格必然一致。
- `Economy.evolve()` 与 `Economy.monthly_settlement()` **都由 `tick()` 调用**（与 03a 的 `WorldFactions.evolve()` 同款风格：tick 就地写）。`Economy` 内部**所有随机数必须来自 `RngService`**，不得用 `randf()`。
- **`economy` 必须加入 `SaveCodec` 的字典字段白名单**；`create()` 里初始化、`from_dict()` 后**幂等补齐**（已有键不动），口径同 03a §9.5。

### 7.4 价格与危机口径（**本计划的核心契约，不许实现时自创**）

```gdscript
# 引用价（唯一算价入口）
static func price_of(world: WorldState, good_id: String) -> int

# 分解（供测试与面板解释）
static func price_factors(world: WorldState, good_id: String) -> Dictionary
# → {"base": int, "era_mult": float, "scarcity_mult": float, "supply_mult": float, "local_mult": float}
```

1. **`era_mult`**：时代系数。按 `registry.entry("eras", era_id).start_year` 分档：
   `<=1000 → 0.35` / `1001..1691 → 0.55` / `1692..1945 → 0.85` / `1946..1980 → 1.0` / `1981..1998 → 1.15`（战时通胀）/ `>=1999 → 1.1`。
   写在 `Economy` 的**常量表**里（不是 `eras.json`，避免动 8 个时代的内容表；若评审希望可配置，改 spec 再挪进 `data/`）。
> ⚠️ **本节已于 2026-09-21 按「先实算后写表」流程整体重算并改写**（原第 2/3 条经实算发现**三处设计缺陷**，见 §13 风险 8）。下面每一条都是**实算验证过**的口径，实现时**照抄常数、不要自创**。

**算价公式（定版）**：

```
price = round( base_price_knuts × era_mult × scarcity_mult × local_mult )
```

**`supply` 不进价格公式**（这是实算逼出的关键修正，见 §13 风险 8 缺陷③）。

1. **`era_mult`**：时代系数。按 `registry.entry("eras", era_id).start_year` 分档：
   `<=1000 → 0.35` / `1001..1691 → 0.55` / `1692..1945 → 0.85` / `1946..1980 → 1.0` / `1981..1998 → 1.15`（战时通胀）/ `>=1999 → 1.1`。
   写在 `Economy` 的**常量表**里（不是 `eras.json`，避免动 8 个时代的内容表；若评审希望可配置，改 spec 再挪进 `data/`）。
   **实算验证**：普通魔杖常态 7.00 加隆 → ancient 2.45 / founding 3.85 / reform 5.95 / wartime 8.05 加隆，单调合理。
2. **`scarcity_mult`**：由 `economy_index` 推（**单调递减**，景气越低物价越高），**双侧封顶**：
   ```gdscript
   const NEUTRAL_INDEX    := 0.5   # canon_price 的定义基准
   const MIN_SCARCITY     := 0.75  # 繁荣侧地板
   const MAX_SCARCITY     := 1.40  # 危机侧天花板

   # 原始曲线（两侧弹性不对称，这是有意的）
   raw = index >= NEUTRAL_INDEX ? 1.0 - (index - 0.5) * 0.2 : 1.0 + (0.5 - index) * 1.2
   # 垄断加成的「超额部分」加倍（只在涨价侧）
   if monopoly and raw > 1.0: raw = 1.0 + (raw - 1.0) * MONOPOLY_EXCESS_MULT   # 2.0
   # 双侧封顶
   scarcity_mult = clampf(raw, MIN_SCARCITY, MAX_SCARCITY)
   ```
   - **为什么必须双侧封顶**：正典魔杖区间 `[7,10]` 只有 **1.4286x** 宽。若 scarcity 不封顶，危机侧
     `raw` 可到 1.60、繁荣侧到 0.80，摆动 **2.0x** > 1.4286x ⇒ **数学上不存在任何 base 能让全域价格落在区间内**
     （实算已证：1001 个采样点里必然越界）。封顶到 `[0.75, 1.40]`（摆动 1.87x）后仍偏宽，
     故验收契约**不再要求「繁荣侧不得低于下沿」**（见第 3 条 C4）。
   - **两侧弹性不对称（0.2 / 1.2）保留**：危机涨幅是繁荣降幅的 6 倍，符合现实方向。
   - **实算对照**（普通魔杖 base 3451，modern，local=1.0）：
     | index | 场景 | 口径 A 价 | 口径 B 价 |
     | --- | --- | --- | --- |
     | 0.16 | 危机·刚脱离断供 | 9.80 加隆 | 9.80 加隆 |
     | 0.35 | 危机门限 | 9.52 加隆 | 9.52 加隆 |
     | 0.50 | **常态（canon 定义点）** | **7.00 加隆** | **7.00 加隆** |
     | 0.70 | 景气偏好 | 6.72 加隆 | 6.16 加隆 |
     | 1.00 | 极盛 | 6.30 加隆 | 5.25 加隆 |
   - 口径 B 仍保留为 **K5 的可选项**（繁荣侧更便宜，弹性 0.6）。**两套都通过全域守门**（危机侧守上沿）。
3. **正典符合性验收契约（C1–C6，定版）** —— 这是「价格算对了没有」的判据：
   - **C1（硬）**：**常态**（`index=0.5`, **`era_mult == 1.0` 的时代**, `local=1.0`）价 **== `base_price_knuts`**
     （因 `index=0.5` 时 `scarcity_mult=1.0`、`era_mult=1.0`、`local_mult=1.0`）。
     ⇒ 这也让 `goods.json` 的 `base_price_knuts` 有了**可读的语义**：它就是「常态零售价」。
   - **C2（硬）**：价格对 `economy_index` **单调不增**（景气降 ⇒ 价不降，不许反号）。实算已验证 1001 点全单调。
   - **C3（硬）**：**危机侧上限** = 正典区间上沿 `canon_price_hi_knuts`。最低景气且未断供时价 `<= canon_price_hi_knuts`。
     实算：普通魔杖危机最大值 **4831 <= 4930 ✔**。
     ⚠️ **上界来源（2026-09-21 修正）**：`canon_price_hi_knuts` **必须直接来自正典写明的区间上沿**，
     不得用 `canon_price_knuts × MAX_SCARCITY / MIN_SCARCITY` 反推（该推导式隐含「一条商品 = 一个窗口且 base 就在下沿」，
     被 `potion_healing_premium` 打破；详见 §7.1 `canon_price_hi_knuts` 条目）。
   - **C4（软，记录不阻断）**：繁荣侧允许低于正典下沿（「便宜」不违反「7–10 加隆」的叙述语境——
     正典说的是**常见成交范围**，不是「任何状态不得低于 7」）。幅度受 `MIN_SCARCITY` 限制，且**测试里必须打印实际落点**。
     实算：普通魔杖繁荣侧最低 3106 纳特（6.30 加隆），低于下沿 345。
   - **C5（硬）**：`supply` **不进价格公式**，只决定**可得性**（断供 / 限购）。
     理由：`supply_mult` 在危机侧会**推高**价格（产出低 ⇒ 1.5-），与 `scarcity_mult` 叠加后总乘数达 **1.479x**，
     超出魔杖区间 1.4286x 的容忍 ⇒ 必然越界；且它表达的语义（产出少 ⇒ 贵）与 `economy_index` **重复**。
   - **C6（硬）**：`canon_price_knuts` / `canon_price_hi_knuts` 的语义 = **该商品所属正典区间的下沿 / 上沿**；
     `base_price_knuts` = 常态零售价。`base` 与 `canon_lo` **不再强制相等**（原 spec §7.1 的「必须 `==`」硬校验**作废**）。
     `Registry.validate()` 的机器保障 = **两条一起查**：
     ① `base ∈ [canon_lo, canon_hi]`（常态价落在正典区间内）；
     ② `roundi(base × MAX_SCARCITY) <= canon_hi`（危机峰价不突破正典上沿，这就是 C3）。
3. **`supply`（不进价格，只决定可得性）**：
   `effective_output = clamp(base_output × (0.5 + economy_index × 0.5), 0, 1)`（保留，供 `available()`/面板用）。
   `supply_critical == true` 且 `economy_index <= SUPPLY_CUTOFF` ⇒ **断供**（`price_of()` 返回 `0`，`available()` 返回 `false`）。
4. **`local_mult`**：地点系数。**按 `locations.json` 的 `zone` 推导**（2026-09-21 修正，见下方口径说明）：
   | `zone` | `local_mult` | 语义 |
   | --- | --- | --- |
   | `wild` / `forbidden` | `0.85` | 产区（禁林/密室/金库地下/阿兹卡班 —— 原料与违禁品的一手来源） |
   | `wizarding` / `school` | `1.0` | 常规市场（对角巷/霍格莫德/魔法部/古灵阁/各校） |
   | `muggle` | `1.2` | 偏远（麻瓜世界 —— 魔法商品是进口品，贵） |
   | 未知 / `location_id` 为空 / 地点的 `zone` 缺字段 | `1.0` | **缺省必须安全**：未标记的地点一律平价，不得因缺字段变成 0 倍价 |
   常量仍为 `LOCAL_MULT {"产地":0.85,"常规":1.0,"偏远":1.2,"黑市":1.35}`，`zone → 档位` 的映射写在 `Economy._LOCAL_ZONE_TAG`（`{"wild":"产地","forbidden":"产地","wizarding":"常规","school":"常规","muggle":"偏远"}`）。
   - ⚠️ **为什么改口径**：原 spec 写「按地点的 `kind`/标签给」，但 `data/locations.json` 的 21 个地点**只有 `zone`，没有任何价区标签**；
     且 `local_mult_for` 当时读的是 `world_vars["location_tag"]` —— 该键**全仓库没有任何地方写入**，
     等于永远走缺省 1.0（`grep location_tag` 只命中 `economy.gd` 自身、`economy_test` 的手动注入与本 plan）。
     更致命的是 `world_vars` 在玩家换地点时**不变**，所以「产地买、销地卖」这条 E7 的核心玩法**在实现上不可能**。
     改按 `player.location_id → zone` 推导后，地点一改，价格立刻跟着变。
   - ⚠️ **`黑市` 档（1.35）本任务暂不启用**（没有地点带该 tag）；它留给 03c 的翻倒巷黑市 / `visible_faction_ids` 揭示路径。
     黑市商品的**可见性**保护另见 §10 第 1 条。
   - **对 C1–C3 的影响：无**。验收契约的扫描基准是「`local_mult == 1.0` 的常规地点」，
     `price_of()` 在常规地点（如 `diagon_alley` / `hogwarts`）算出的价与修正前**逐字相同**。
5. **`monopoly`** 加成：该产业 `monopoly == true` 时，`scarcity_mult` 的**超额部分（>1.0 那一段）加倍**（垄断者转嫁成本）。即 `scarcity_mult = 1.0 + (raw - 1.0) × 2.0` 当 `raw > 1.0`。⚠️ **加倍后再过 `[MIN_SCARCITY, MAX_SCARCITY]` 封顶**（否则垄断行业会突破 C3）。
   **实算**：index=0.30 时普通魔杖 非垄断 5445 / 垄断 6499 纳特（+19.4%），封顶生效后仍守上沿。
6. **取整**：所有价格 `roundi()` 到整数纳特；结果 **≥ 1**（不允许出现 0 价商品，除非断供）。
7. **危机态**（E8）：`crisis = economy_index <= CRISIS_THRESHOLD`。进入时（**沿**：只在 false→true 的**边沿**触发一次）：
   - 写一条 `events` 条目（`kind: "economic_crisis"`，带来源口吻，第四十三章）；
   - `add_fact("major", ...)`；
   - `gringotts_interest_rate` **下调**（默认 0.002 → 0.0012）；
   - 走私品**利润率上升**（`smuggling_profit_mult` 1.0 → 1.5）。
   退出危机（true→false）时利率回升，但不写事件（避免「危机结束」也刷屏）。
   - ⚠️ **两个阈值必须解耦，且各自只有一个来源**（实算逼出的修正）：
     | 常量 | 值 | 语义 | 谁用 |
     | --- | --- | --- | --- |
     | `Economy.CRISIS_THRESHOLD` | `0.35` | **世界进入经济危机**（写事件/降利率/涨走私利润） | `Economy` + **`factions.gd:369` 必须改为引用它** |
     | `Economy.SUPPLY_CUTOFF` | `0.15` | **`supply_critical` 商品断供** | 仅 `Economy` |
     原 spec 把两者都写 0.35，实算发现那样会留下 `index ∈ (0.35, 0.43]` 的「已越界但仍供货」死区，
     且断供与危机是**两件不同的事**（危机可以有货，只是贵）。解耦后 `[0.16, 0.35]` 成为
     「**已危机、仍有货、价格顶到上限**」——这是经济上最有趣的状态。
   - **不得各自硬编码 `0.35`** —— 将来调阈值时漏改一处，会出现「物价已断供但派系层认为没危机」这类**静默不一致**。
     这是 03a `§4 第 18 条`（helper 断言不足以保证调用处传对）的同族风险在**常量**上的形态。
8. **确定性**：以上全部是 `world` 的**纯函数**（无随机），因此 `price_of()` 可以在测试里逐字段断言。唯一带随机的是 `foreign_rate` 的月度波动（走 `RngService` 命名流 `economy_foreign_rate`）。

**§7.4 常量总表（实算定版，实现时照抄）**：

| 常量 | 值 | 说明 |
| --- | --- | --- |
| `NEUTRAL_INDEX` | `0.5` | canon 常态价的定义基准（此时 `scarcity_mult == 1.0`） |
| `NEUTRAL_ERA_YEAR` | `1950` | canon 价位语境的时代；**这就是 C1 的中性时代**（`era_mult == 1.0`）<br>⚠️ 注意 `modern`（2010）落 `1.10` 档，**不是中性时代** —— 实算时按 `ERA_MULT` 表，中性档是 `y ≤ 1980`（实际命中 `first_wizarding_war` 1970） |
| `MIN_SCARCITY` | `0.75` | 繁荣侧地板 |
| `MAX_SCARCITY` | `1.40` | 危机侧天花板（由魔杖区间 1.4286x 反推，留 2.9% 余量） |
| `CRISIS_THRESHOLD` | `0.35` | 危机态（**与 `factions.gd:369` 共用**） |
| `SUPPLY_CUTOFF` | `0.15` | 断供线（**与危机线解耦**） |
| `MONOPOLY_EXCESS_MULT` | `2.0` | 垄断行业涨价侧超额部分加倍 |
| `LOCAL_MULT` | `{产地:0.85, 常规:1.0, 偏远:1.2, 黑市:1.35}` | 缺省 **1.0** |
| `TRADE_HAUL_KNUTS` | 见 §7.5 | 路费（按 category） |

### 7.5 新增 ops（`StateOps`）与 `Money` 负值

| op | 载荷 | 语义与校验 |
| --- | --- | --- |
| `deposit_money` | `{"op":"deposit_money","knuts":int}` | 校验：金额 > 0、金额 ≤ `OpGuard.MAX_BANK_MOVE`、`player.money_knuts >= 金额`（**不许透支存钱**）。成功：现金减、`economy.gringotts_balance` 增。 |
| `withdraw_money` | `{"op":"withdraw_money","knuts":int}` | 校验：金额 > 0、金额 ≤ `OpGuard.MAX_BANK_MOVE`、`economy.gringotts_balance >= 金额`。成功：反向。余额不足时 `errors.append`（**不部分执行**）。 |
| `exchange_money` | `{"op":"exchange_money","knuts":int,"direction":"buy"\|"sell"}` | 按 `foreign_rate` 与**买卖价差**（默认 2%）换算。`buy` = 用加隆买外币（现金减、外币增）；`sell` 反向。校验金额 > 0、`direction ∈ {buy,sell}`、`knuts ≤ OpGuard.MAX_BANK_MOVE`。汇率与余额存在 `economy.foreign_rate` / `economy.foreign_held`。 |
| `trade_money` | `{"op":"trade_money","good_id":str,"qty":int,"mode":"buy"\|"sell","origin_location_id":str?,"location_id":str?}` | 校验：`good_id` 存在、`qty ∈ [1, OpGuard.MAX_TRADE_QTY]`、`Economy.available()`（断供不可交易）、`mode ∈ {buy,sell}`、**两地 `local_mult` 必须不同**（否则不是贸易）、**货值 ≤ `OpGuard.MAX_TRADE_VALUE`**（见下）。买价取 `origin_location_id` 的价、卖价取 `location_id` 的价（**两者缺省 = 玩家当前地点**，此时两地相同 ⇒ 被上面的「必须不同」拒绝）。买入加路费 `TRADE_HAUL_KNUTS[category] × qty`。`category == "illegal"` ⇒ `smuggling_heat += 1` 并写 `flags["illegal_trade"]`。**不做法律后果**（03c）。 |

**⚠️ `trade_money` 的「货值上限」（2026-09-21 新增，这是本 op 唯一的防套利闸门）**：

单笔交易的**基础货值** `base_price_knuts × qty`（**不含**任何倍数、不含路费）必须 `<= OpGuard.MAX_TRADE_VALUE`（`5000` 纳特）。
实现放在 `StateOps` 侧（`OpGuard` 沿用既有的「按载荷推 qty 上限」钳制风格）。

- **为什么必须加**：原 spec §13 风险 7 写「靠 `OpGuard` 的金额上限与『同回合不可重复同类交易』约束」防无限套利 ——
  但 `MAX_TRADE_QTY := 100` **是件数上限，不是金额上限**，对高价商品形同虚设。实算（产地 0.85 → 偏远 1.2，扣两次路费）：

  | 商品 | category | 净利/件 | `qty=100` 单笔净利 | 折合加隆 | 相对「普通家庭年收入数百加隆」 |
  | --- | --- | ---: | ---: | ---: | --- |
  | `svc_owl_post` | service | 6 | 600 | 1.2 | 合理 |
  | `potion_common` | potion | 305 | 30 500 | 62 | 偏高但可接受 |
  | `wand_standard` | wand | 1 148 | 114 800 | 233 | 已等同一年收入 |
  | `broom_nimbus` | broom | 17 135 | **1 713 500** | **3 476** | **11.6 倍年收入 / 一轮** |

  加 `MAX_TRADE_VALUE = 5000` 后（`qty_max = floor(5000 / base)`）：

  | 商品 | `base` | `qty` 上限 | 单笔净利 | 折合加隆 |
  | --- | ---: | ---: | ---: | ---: |
  | `svc_owl_post` | 17 | 100（件数上限先到） | 600 | 1.2 |
  | `potion_common` | 986 | **5** | ~1 525 | ~3.1 |
  | `wand_standard` | 3 451 | **1** | 1 148 | 2.3 |
  | `broom_nimbus` | 49 300 | **0** ⇒ 拒绝 | — | — |

  ⇒ 高价耐用品**天然不可搬运**（符合现实：没人背包里倒腾 100 把飞天扫帚），跑量贸易只发生在低价快消品上。量级回到正典区间。
- ⚠️ **不做「同回合不可重复交易」**（与 spec 正文不一致的说明）：`data` 层没有会话/回合级记账，且
  `recent_training` 那种写 `world.flags` 的做法需要新增状态字段。**判定：`MAX_TRADE_VALUE` + `MAX_TRADE_QTY` 两道闸已足够**，
  重复交易的边际收益受这两个上限钳制，不构成套利。若实跑发现仍可刷，由 03c 加回合级记账。

**`Money`（`src/model/money.gd`）**：

```gdscript
func is_debt() -> bool                     # _knuts < 0
func debt_formatted() -> String            # "负债 2加隆 16西可"（0 值部分省略）
func formatted() -> String                 # 负值 → 走 debt_formatted() 的形态；非负 → 现状 "G加隆 S西可 K纳特"
```

- `parts()` **不变**（仍返回 `[-g,-s,-k]`）⇒ 既有 `parts()` 断言不破。
- `debt_formatted()` 的 0 值省略规则（**单位必须算准**：`parts()` 返回的第三位是**纳特**，不是西可）：
  - `-1002` → `parts=(-2, 0, -16)` → **`"负债 2加隆 16纳特"`**（1002 = 2×493 + 16，余 16 < 17 ⇒ 是 16 纳特、0 西可）
  - `-5` → `parts=(0, 0, -5)` → `"负债 5纳特"`
  - `-17` → `parts=(0, -1, 0)` → `"负债 1西可"`
  - `-493` → `parts=(-1, 0, 0)` → `"负债 1加隆"`
  - `-0`（即 0）→ **不算负债**，`formatted()` 走非负分支 `"0加隆 0西可 0纳特"`
  - 省略规则：值为 0 的**高**单位省略（`-5` 不写「0加隆 0西可」）；**低位单位即使为 0 也省略**（`-493` 不写「1加隆 0西可 0纳特」⇒ 写「1加隆」）
- ⚠️ **本节的验收用例经 Python 实算核对**（`parts()` 逐值验证，见提交说明）；初稿曾把 `-1002` 写成「16西可」，**单位错误**，已修正为「16纳特」。实现时**必须以实算为准**，不要照抄「看起来对」的串。

### 7.6 面板与经济摘要（E11）

`player_panel` 【财富】行（有存款时）：

```
【财富】25加隆 0西可 0纳特（含古灵阁 12加隆 3西可 4纳特） 【家庭】傲罗家庭
```

新增一行（紧跟【财富】行）：

```
【经济】景气 0.61 ｜ 存款月息 0.20% ｜ 汇率 1.03 ｜ 本月 +2西可 7纳特
```

- `本月 +X` = `last_month_income - last_month_expense`，**带符号**（净支出时显示 `本月 -X`，例如 `本月 -2西可 7纳特`）；为 0 时显示 `本月 无收支`。
  **负值恰恰是最该显示的情形**（玩家要考虑是否该去打工），故**不**因负值而隐藏该行。
- `prompt_builder.state_digest` 加一段经济摘要（景气 + 玩家现金/存款 + 2–3 条主要商品价格），**只给已揭示信息**（与 03a Q4 一致：不剧透未揭示内容）。

## 8. 数据流（单回合，含新增阶段）

```text
玩家指令 → TurnEngine.submit_async
  → GameMaster（LLM 或替身）产出 {narration, ops, warnings}
  → StateOps.apply(ops)                 # 4 个新 op 在这里落地
  → WorldState.tick():
       [既有] ① world_vars 回归/扰动       ② 传闻事件   ③ 派系揭示   ④ factions.evolve()
       [新增] ⑤ Economy.evolve()            # 价格快照 / 汇率 / 利率 / 危机边沿 / 走私热度
       [新增] ⑥ Economy.monthly_settlement()# 工资 / 开销 / 存款利息（确定性）
       [既有] ⑦ 生活基线   ⑧ 年龄   ⑨ 日志裁剪
  → PanelFormatter 输出（含【经济】行）
```

顺序理由：`evolve()` 要在 `settlement()` **之前**（本月价格算完再结算开销，否则结算用的是上月价）；
两者都必须在 `world_vars` 回归**之后**（景气是本回合新算出来的）。
`settlement()` 用 `last_settlement_turn` 保证**幂等**（同回合重复调用不重复发钱 —— 防止测试或未来 UI 误调）。

## 9. 确定性与存读档

1. **随机**：`Economy` 内唯一随机是 `foreign_rate` 月度波动，用 `RngService.new(world.game_seed + world.clock.turn * 24593)`，命名流 `economy_foreign_rate`。其余全是纯函数。
   同 seed + 同回合 ⇒ 同结果（`economy_test` 用双世界对比断言）。
2. **存档**：`world.economy` 加入 `SaveCodec` 的字典字段白名单；**`save_version` 保持 1**。
3. **旧档兼容**：`from_dict()` 后若 `world.economy` 为空 → 由 `WorldState.from_dict()` 自己调用 `Economy.initialize(world)` 补齐（幂等）。这样「创建后立刻开面板」与「老存档读档后」两条路径都拿到完整经济状态。
4. **确定性反证要求**：`economy_test` 必须包含至少 1 条「删掉/改错某步 → 断言变红」的反证说明（沿用既有做法：报告里贴反证实验输出）。
5. **幂等验收**：`last_settlement_turn == clock.turn` 时 `monthly_settlement()` 必须**直接返回**（不改任何字段）；测试要有一条「同回合调两次，只结算一次」的断言。

## 10. 信息保护与防作弊

1. **物价不是秘密**，但**黑市价格**（`category == "illegal"` 或 `local_mult` 走黑市档）只在玩家**已进入黑市/已揭示相关派系**时可见（复用 03a 的 `visible_faction_ids()`；未揭示时面板不列该商品）。
2. `Economy` **不得**写 `world.factions` / `player.standing`（跨模块写是 03a 禁止的）；经济对政治的影响**只能**通过 `economy_index` 的既有通道（`factions.gd:248/348/369`）。
3. 玩家现金/存款是**真实状态**，不得被 LLM 直接读改写（LLM 只能发 `deposit_money` 等 op，由 `OpGuard` 钳制）。
4. `smuggling_heat` **只记不判**（后果属 03c），且**不得**在玩家可见文本里以「你已被通缉」这类确定口吻出现（第四十三/五十七章）。
5. `SelfCheck` 既有四项检查不改。

## 11. 测试策略

| 套件 | 新增/修改 | 关键断言 |
| --- | --- | --- |
| `tests/economy_test.gd`（新） | 新增 | ① 两表引用合法（`industry_id`/`inputs`/`produces`）；② **C1**：常态价 `== base_price_knuts`；③ **C2**：`price_of()` 对 `economy_index` **单调不增**（1000 点扫描）；④ **C3**：危机侧最大值 `<= canon_hi`；⑤ **C5**：删掉 `supply` 也不影响价格（反证：把 supply 乘回去，断言必须变红）；⑥ `SUPPLY_CUTOFF`/`CRISIS_THRESHOLD` 边界（`0.15`/`0.35` 两侧各一例，且**两条线必须不同**）；⑦ `supply_critical` 商品在 `<=0.15` 断供（`price_of()==0` 且 `available()==false`）；⑧ `monopoly` 行业涨价幅度大于非垄断（同景气下对比，且**仍守上沿**）；⑨ 月度结算幂等（同回合两次只发一次钱）；⑩ 工资/开销**符号**正确（「无业者净收 < 0」必须有）；⑪ 古灵阁：存入后现金减余额增、超额存入被拒、超额取款被拒且**不部分执行**；⑫ `foreign_rate` 确定性（同 seed 双世界相等）；⑬ 贸易价差：产地 buy、销地 sell，**扣两次路费后仍为正**（⇒ 产区买、常规卖的 15% 价差必须覆盖路费，这是「贸易」有意义的必要条件）；⑭ 走私：`illegal` 商品交易后 `smuggling_heat` 增、`flags["illegal_trade"]` 置位；⑮ **缺 `zone` / 空 `location_id` 时 `local_mult == 1.0`**（缺省安全）；⑯ **`local_mult` 按 `zone` 推导**（`wild→0.85` / `wizarding→1.0` / `muggle→1.2`，且**换地点** `player.location_id` 后价格真的变）；⑰ **货值闸门**：`base × qty > MAX_TRADE_VALUE` 的单笔交易被拒（`broom_nimbus` 即使 `qty=1` 也拒），且**拒绝时不部分执行**（现金与走私热度都不动） |
| `tests/money_test.gd` | 修改 | E9 债务形态（`-1002 → "负债 2加隆 16西可"`、`-5 → "负债 5西可"`、`-12 → "负债 12纳特"`、`-0 → 非负分支`）；`parts()` 现行为**保持不变**（这是「不破坏既有断言」的证据） |
| `tests/panel_test.gd` | 修改 | 【经济】行存在且数值来自 `economy`；【财富】含存款（无存款时**不出现**该括号）；债务走债务形态；未揭示黑市商品不出现 |
| `tests/save_test.gd` | 修改 | 「存 2 回合 + 存款 + 交易 → encode/decode → 重建引擎 → 继续 tick」与原时间线逐字段一致；老存档（无 `economy`）补齐后 `ok=true` |
| `tests/registry_test.gd` | 修改 | 两表注册 + `validate()` 对坏引用/坏枚举/负价格报错；`canon_price > 0` 而 `base_price` 落出合理带时报错（§7.1 新口径） |
| `tests/gm_test.gd` / `llm_test.gd` | 修改 | 4 个新 op 的守卫（金额上限钳制、余额不足拒绝、断供商品拒绝、跨地要求、货值上限拒绝、`OpGuard` 对未知经济 op 一律拒绝） |
| `tools/b1_acceptance.gd` | 修改 | 经济可观测契约：① 存款一个月后余额**真的**多了利息；② 危机态下同一商品价格**真的**变贵；③ 债务显示形态可达（造一个负现金角色） |

**新增套件必须追加到 `tests/run_tests.gd` 的 `SUITES`**（铁律），否则不会被执行。

## 12. 依赖与兼容

- 纯 GDScript + Godot 4.7.2 stable，无新依赖、不联网。
- `TurnEngine` / `GameMaster` / `LlmGameMaster` / UI 异步契约**不变**。
- `world_vars` 键集不变（E3）⇒ `data/eras.json` 不改、旧存档不需迁移。
- `SaveCodec` 字段清单新增 `world.economy`（**不升版本**）。
- 内容表新增 2 个文件 ⇒ `Registry.TABLE_FILES` 必须同步，否则 `load_default()` 静默不加载。
- **`Money.formatted()` 负值行为变更**是本计划唯一的「既有对外行为变更」（K1）。

## 13. 风险与未决

1. **`formatted()` 负值变更是对外行为变更**（K1）。影响面：`panel_formatter.gd:43/128/131` 三处输出、`money_test` 既有断言。缓解：`parts()` 不动、新增 `debt_formatted()`、`formatted()` 只在负值分支改。**若你选「不改」，退路是**：`formatted()` 保持原状，面板改用 `debt_formatted()`，代价是「直接调 `formatted()` 的调用方仍拿到 bug 形态」。
2. **时代系数写在代码常量表**（§7.4 第 1 条）与「内容进 data」的铁律有张力。理由：这些是**演化参数**（不是玩家可见文本），且写进 `eras.json` 要动 8 个时代条目的 schema。若评审认为必须进 `data/`，改 spec 后挪进 `data/economy_params.json`（成本约 30 行）。
3. **月度结算会让「不行动」变得不可行**（K2）：无业者净支出、有业者净收入。若实跑发现新手开局即破产，需要给「开局缓冲」（如家庭补贴数月）——**本计划先用裸结算**，实跑后调。
4. **价格数量级必须对得上正典**：`普通家庭年收入约数百加隆`（223 行）是**唯一的量级锚点**。若月度结算后玩家年收入 / 年支出量与「数百加隆」差一个数量级，说明工资或物价系数需要整体校准。**这是本计划最可能返工的地方**（一次调常数，不是推翻设计）。
5. **危机阈值 0.35 是首版拍数**（沿用 `factions.gd:369` 的既有危机判据，保持一致）。实跑后可能要调。
6. **与 03a 的耦合点只读**（§5.1）：若实现时发现必须改 `factions.gd`，**先改 spec 文本**（03a 铁律）。
7. **`trade_money` 的「路费」用 category 常量**（不是真实距离）：本计划没有地点距离数据。若 03b 要做真实距离，需要给 `data/locations.json` 加坐标 —— **本计划不做**，用常量近似。
   **⚠️ 2026-09-21 修正：原写「靠 `OpGuard` 的金额上限与『同回合不可重复同类交易』约束」防套利 ——
   实算证明该约束无效**（`MAX_TRADE_QTY=100` 是件数不是金额，`broom_nimbus` 单笔净利 1 713 500 纳特 = 11.6 倍家庭年收入）。
   现改为**货值闸门 `OpGuard.MAX_TRADE_VALUE = 5000`（纳特，按 `base_price_knuts × qty` 算）+ 件数上限 `MAX_TRADE_QTY = 100` 双闸**，
   并**放弃**「同回合不可重复交易」（缺回合级记账，不值得为它加状态字段；两道闸已足够钳制边际收益）。
   详见 §7.5 `trade_money` 条下方实算表。
8. **`local_mult_for` 原读 `world_vars["location_tag"]` —— 该键全仓库无写入方，是死路径**（2026-09-21 实况修正，属**缺陷⑧**）。
   改按 `locations.json` 的 `zone` 推导（§7.4 第 4 条）。触发点是本计划的 E7「产地买、销地卖」：`world_vars` 在玩家换地点时不变，
   所以原口径下这条玩法**在实现上不可能**，且 `trade_money` 会退化成「同一地点原价买卖」。
   **元教训**（同 §7.1 `canon_price_hi_knuts`、§13 元教训）：**「读一个自己负责写入的键」必须验证写入方真的存在** ——
   只在测试里手动塞一次就能让断言变绿，但生产路径永远走缺省分支。凡「参数**来源**」都必须 `grep` 确认有生产写入方，否则是死代码。
9. **本 spec 的数值经「先实算后写表」全流程重算，共发现并修掉 8 处设计缺陷**（教训同 03a §13.2「0.45 在任何合法状态都不可达」）。
   实算脚本：`C:\Users\yhweix\AppData\Local\Temp\hali_03b_{pricecalc,diag,verdict,v2,v3,v4,v5,gen}.py`
   （一次性工具，不入库；结论已全部写进 §7.4）。
   | # | 缺陷 | 证据 | 修法 |
   | --- | --- | --- | --- |
   | ① | 债务用例 `-1002` 初稿写成「16**西可**」 | `parts=(-2,0,-16)` ⇒ 第三位是 **16纳特** | 改成「负债 2加隆 16纳特」，§7.5 加实算警告 |
   | ② | `canon_price` 被直接当 `base_price` | 上等魔杖 11.54 > 10、顶级疗伤 22.68 > 20（5 个锚点里 2 个越界） | `canon` 与 `base` 解耦，`base` = 常态零售价（C1） |
   | ③ | **`supply_mult` 加重了危机侧涨幅** | index=0.16 时 scarcity ×1.408、supply ×1.048，合计 **×1.479** > 区间宽 1.4286 | **`supply` 移出价格公式**（C5），只管可得性 |
   | ④ | **危机线与断供线同为 0.35** | 留下 `index ∈ (0.35, 0.43]` 的「已越界但仍供货」死区 | 解耦为 `CRISIS_THRESHOLD=0.35` / `SUPPLY_CUTOFF=0.15` |
   | ⑤ | 原验收契约（初稿）隐含「全域价必须落在正典区间内」 | **数学上不可能**：区间宽 1.4286x，而乘数摆动必 >1.5x | 改为 C1–C6（危机侧守上沿、繁荣侧允许下探并记录） |
   | ⑥ | 「上等魔杖」复用普通魔杖的 `[7,10]` 窗口 | 该窗口常态可用带仅 `[3451, 3521]`（= 上沿/1.40），容不下第二档 | **删掉「上等魔杖」**，正典只给了「普通魔杖」一个窗口 |
   | ⑦ | **C3 上界用 `canon_lo × MAX/MIN` 反推**（2026-09-21 Task 1 施工时暴露） | `potion_healing_premium` 与 `potion_healing` **共享 canon 区间**、base 取上段（6162），被公式推出上界 4601 误判越界；实际危机峰 8627 < canon_hi 9860，**C3 是满足的** | 新增 `canon_price_hi_knuts` 字段（**直接存正典区间上沿**），校验改为 ①`base ∈ [lo, hi]` ②`roundi(base × MAX_SCARCITY) <= hi` 两条一起查 |
   - 最终产物：**35 条商品 + 9 条产业**，`industry_id`/`produces` 引用全部实算校验通过，5 个正典锚点全域守门通过。
   - **流程要求（保留）**：将来任何改动 `data/*.json` 价格的动作，**必须先把 `base_price_knuts` 与 §7.4 公式实算一遍**
     （Python 一次性脚本即可），确认 C1–C6 全部通过，再写进表。**不要先写表再验算。**
   - **⑦ 的元教训**：缺陷 ②～⑦ 有一个共同形态 —— **用一个「推导式」代替「正典里本来就写明的量」**。
     凡是正典**直接给出**的数字（区间上沿、价位本身），就该**存字段**，不要让它从别的数字算出来；
     推导式只在正典确实没给、且假设前提被验证过时才用。且推导式的隐含前提**必须在注释里写出来**
     （⑦ 隐含「一条商品 = 一个 canon 窗口且 base 就在下沿」，正是这句话没人写下来才漏掉 premium 档）。

## 14. 后续计划边界

- **03c 社会与法律**：纯血家族完整制度（第十三章，含**家族财产/祖宅/继承** ⇒ 会填 `panel_formatter` 的【家族】财富字段）、协会体系（第十九章，含**行业规则/会员费** ⇒ 会与本计划的 `industries.json` 挂接）、法律与审判（第三十五章：威森加摩开庭/阿兹卡班/剥夺魔杖）、傲罗行动与非法施法后果（`§8#28/#29`）、**走私与非法施法的法律后果**（本计划只记 `smuggling_heat`）。
- **04** 神奇生物生态与区域危险度（本计划的 `creature` 类商品是它的输入）；**05** NPC 自主与信息可信度（NPC 经济行为）；**06** 多世代传承与世界记忆（**遗产**，与 03c 的继承一起）。
- **独立小计划**（与主线无关，随时可插）：**存档格式 v2**（`§8#9/#19/#26/#49/#71`，含 `economy` 的一次性迁移）、设置界面（含 `§8#63` 的 provider 复用）、流式输出、长期记忆。
- **03b 有意推到 03c 的**：走私的法律后果 · 协会的行业准入 · 家族财产。⇒ 03c 开工前先读本文件 §14 与 §13 第 7 条。
