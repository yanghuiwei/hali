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
| **E9** | `Money` 负值语义落地（修 `§8#5`）：新增 `Money.is_debt()` 与 `Money.debt_formatted()` → **`"负债 2加隆 16西可"`**；`formatted()` 对负值**改为**输出该债务形态（**这是行为变更**，见 §13 风险 1，需你点头）。同时 `parts()` 保持现状（返回带负号的 `[-g,-s,-k]`）以不破坏既有断言。 | `§8#5` 挂账原文：「债务场景会显示负值西可/纳特」。当前 UI 已经在输出 `"0加隆 -2西可 -16纳特"`。**「负债 X」是中文语境下的自然读法**，且不引入新状态。 |
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
| **K5** | `scarcity_mult` 的**繁荣侧弹性**（§7.4 第 2 条的口径 A 还是 B）？ | **建议口径 A（默认）**：危机侧陡、繁荣侧缓更贴近现实，且不让「攒钱」变得无意义。若你希望「好时代明显便宜」，选 B（现代魔杖 8.09 vs 8.89 加隆）。**两套都符合正典 7–10 加隆**。 |

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
| `data/goods.json` | 新增 | 商品与服务（§7.1 schema），28–40 条 |
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
  "canon_line": 223,
  "base_price_knuts": 3451,
  "industry_id": "wandmaking",
  "inputs": ["wand_wood", "wand_core"],
  "illegal": false,
  "supply_critical": false,
  "unit": "根",
  "notes": "正典 223 行「一根普通魔杖：7‑10加隆」，测试取价格下限 7 加隆 = 3451 纳特（task-4-review 裁定）"
}
```

- `category` 取值（代码侧白名单）：`wand` / `potion` / `material` / `broom` / `book` / `food` / `service` / `creature` / `artifact` / `illegal`。
- `kind`：`goods` / `service`（服务没有 `inputs`，且不参与 `supply_critical` 断供逻辑）。
- `canon_price_knuts`：**正典锚点**，只有正典明确写了价位的条目才有；`canon_line` 给行号。
  无正典价位的条目 `canon_price_knuts = 0` 且 `canon_line = 0`（表示「价格为推演值」）。
- `base_price_knuts`：**实际算价基准**。有正典锚点的条目必须 `== canon_price_knuts`（`Registry.validate()` 硬校验，防止改价时忘了正典）。
- `industry_id`：**必须**引用 `industries.json` 存在的 id（服务类可空串）。
- `inputs`：**必须**引用本表存在的 id（可为空数组）。
- `illegal`：走私品（`true` ⇒ 交易时走 E7 的走私记账）。
- `supply_critical`：短缺时会**断供**的条目（正典第十六章的四类后果之一）。
- `unit`：中文量词（「根」「瓶」「把」「份」），面板与叙事会拼成「3 根普通魔杖」。

**校准要求（必须遵守）**：`canon_price_knuts` 必须能对上正典第十八章 5 个锚点 —— 普通魔杖 7–10 加隆、优质疗伤药剂 5–20 加隆、光轮扫帚数十至数百加隆、普通家庭年收入约数百加隆、隐形衣**不进表**（正典明说「无法用加隆衡量」⇒ 进表会把「不可定价」变成「可定价」，违背正典）。

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
2. **`scarcity_mult`**：由 `economy_index` 推（**单调递减**，景气越低物价越高）。**注意两侧弹性不对称，这是有意的**——「景气好」对物价的压低远不如「景气坏」对物价的推高明显（现实里也是这个方向：危机是陡的，繁荣是缓的）。
   - **口径 A（recommended，默认）**：
     `index >= 0.5 → 1.0 - (index - 0.5) × 0.2`（景气 1.0 时 = **0.90**）
     `index < 0.5 → 1.0 + (0.5 - index) × 1.2`（景气 0.0 时 = **1.60**）
   - **口径 B（对称版，若你希望「好时代真的便宜」）**：
     `index >= 0.5 → 1.0 - (index - 0.5) × 0.6`（景气 1.0 时 = **0.70**）
     `index < 0.5 → 1.0 + (0.5 - index) × 1.2`（景气 0.0 时 = **1.60**）
   - 两口径在 `index = 0.5` 处都连续（两侧都是 1.000）。
   - **实算对照**（`modern` 时代 `economy_index=0.7`、`base_output=0.7`、`era_mult=1.1`、普通魔杖 base 3451 纳特）：
     | index | 场景 | 口径 A 价 | 口径 B 价 |
     | --- | --- | --- | --- |
     | 0.70 | modern 默认 | 8.89 加隆 | **8.09 加隆** |
     | 0.50 | 中立 | 9.53 加隆 | 9.53 加隆 |
     | 0.35 | 危机门限 | 11.48 加隆 | 11.48 加隆 |
     | 0.20 | 深度危机 | 13.51 加隆 | 13.51 加隆 |
   - ⚠️ **这是本 spec 最需要你拍板的数值决策**：口径 A 下「繁荣期」只便宜 7%（相对中立），玩家几乎感觉不到景气好；
     口径 B 下便宜 15%，感受明显。**两套都落在正典 7–10 加隆区间内**（现代 8.09–8.89 加隆），故不影响正典符合性。
   - 初稿只写了 A 且未标注不对称性，**经实算发现后补**（见 §13 风险 8）。
3. **`supply_mult`**：由该商品所属产业的 `base_output` 与 `economy_index` 共同决定：
   `effective_output = clamp(base_output × (0.5 + economy_index × 0.5), 0, 1)`，`supply_mult = 1.5 - effective_output × 0.5`（产出满 → 1.0，产出零 → 1.5）。
   `supply_critical == true` 且 `economy_index <= 0.35` ⇒ **断供**（`price_of()` 返回 `0`，`available()` 返回 `false`）—— 对应正典「魔杖供应危机」「医疗能力下降」。
4. **`local_mult`**：地点系数。按地点的 `kind`/标签给（产地 0.85 / 常规 1.0 / 偏远 1.2 / 黑市 1.35）。地点标签缺省时用 1.0（**缺省必须安全**：未标记的地点一律平价，不得因缺字段变成 0 倍价）。
5. **`monopoly`** 加成：该产业 `monopoly == true` 时，`scarcity_mult` 的**超额部分（>1.0 那一段）加倍**（垄断者转嫁成本）。即 `scarcity_mult = 1.0 + (raw - 1.0) × 2.0` 当 `raw > 1.0`。
6. **取整**：所有价格 `roundi()` 到整数纳特；结果 **≥ 1**（不允许出现 0 价商品，除非断供）。
7. **危机态**（E8）：`crisis = economy_index <= 0.35`。进入时（**沿**：只在 false→true 的**边沿**触发一次）：
   - 写一条 `events` 条目（`kind: "economic_crisis"`，带来源口吻，第四十三章）；
   - `add_fact("major", ...)`；
   - `gringotts_interest_rate` **下调**（默认 0.002 → 0.0012）；
   - 走私品**利润率上升**（`smuggling_profit_mult` 1.0 → 1.5）。
   退出危机（true→false）时利率回升，但不写事件（避免「危机结束」也刷屏）。
   - ⚠️ **阈值必须只有一个来源**：`0.35` 这个数在仓库里已有两处用途 —— 本 spec 第 3 条的「断供」与第 7 条的「危机态」，
     以及 **`factions.gd:369`（03a 已合入）的既有危机判据**。三者**必须共用同一个常量**
     （`Economy.CRISIS_THRESHOLD := 0.35`，且 `factions.gd` 改为引用它；若跨模块引用不便，则在两处都写明「与 `Economy.CRISIS_THRESHOLD` 必须同步」）。
     **不得各自硬编码一个 0.35** —— 将来调阈值时漏改一处，就会出现「物价已断供但派系层认为没危机」这类**静默不一致**。
     这是 03a `§4 第 18 条`（helper 断言不足以保证调用处传对）的同族风险在**常量**上的形态。
8. **确定性**：以上全部是 `world` 的**纯函数**（无随机），因此 `price_of()` 可以在测试里逐字段断言。唯一带随机的是 `foreign_rate` 的月度波动（走 `RngService` 命名流 `economy_foreign_rate`）。

### 7.5 新增 ops（`StateOps`）与 `Money` 负值

| op | 载荷 | 语义与校验 |
| --- | --- | --- |
| `deposit_money` | `{"op":"deposit_money","knuts":int}` | 校验：金额 > 0、`player.money_knuts >= 金额`（**不许透支存钱**）。成功：现金减、`economy.gringotts_balance` 增。 |
| `withdraw_money` | `{"op":"withdraw_money","knuts":int}` | 校验：金额 > 0、`economy.gringotts_balance >= 金额`。成功：反向。余额不足时 `errors.append`（**不部分执行**）。 |
| `exchange_money` | `{"op":"exchange_money","knuts":int,"direction":"buy"\|"sell"}` | 按 `foreign_rate` 与**买卖价差**（默认 2%）换算。`buy` = 用加隆买外币（玩家现金减少、记 `flags["foreign_currency"]` 纳特等值）；`sell` 反向。校验金额 > 0。 |
| `trade_money` | `{"op":"trade_money","good_id":str,"qty":int,"mode":"buy"\|"sell"}` | 校验：`good_id` 存在、`qty > 0`、商品 `available()`（断供不可交易）。价格用 `price_of()` × qty + 路费（`trade_haul`，按 category 常量）。`illegal:true` ⇒ `smuggling_heat += 1` 并写 `flags["illegal_trade"]`。**不做法律后果**（03c）。 |

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
| `tests/economy_test.gd`（新） | 新增 | ① 两表引用合法（`industry_id`/`inputs`/`produces`）；② 有正典锚点的商品 `base_price_knuts == canon_price_knuts`；③ `price_of()` 对 `economy_index` **单调**（景气降 ⇒ 价不降）；④ 危机阈值边界（0.35 两侧、`<=` 与 `>` 各一例）；⑤ `supply_critical` 商品在危机中断供（`price_of()==0` 且 `available()==false`）；⑥ `monopoly` 行业涨价幅度大于非垄断（同景气下对比）；⑦ 月度结算幂等（同回合两次只发一次钱）；⑧ 工资/开销**符号**正确（有业者净收 ≥ 0 检查不是必须有，但「无业者净收 < 0」必须有）；⑨ 古灵阁：存入后现金减余额增、超额存入被拒、超额取款被拒且**不部分执行**；⑩ `foreign_rate` 确定性（同 seed 双世界相等）；⑪ 贸易价差：产地买、销地卖**真的赚钱**（扣路费后仍为正）；⑫ 走私：`illegal` 商品交易后 `smuggling_heat` 增、`flags["illegal_trade"]` 置位；⑬ **缺 location 标签时 `local_mult == 1.0`**（缺省安全） |
| `tests/money_test.gd` | 修改 | E9 债务形态（`-1002 → "负债 2加隆 16西可"`、`-5 → "负债 5西可"`、`-12 → "负债 12纳特"`、`-0 → 非负分支`）；`parts()` 现行为**保持不变**（这是「不破坏既有断言」的证据） |
| `tests/panel_test.gd` | 修改 | 【经济】行存在且数值来自 `economy`；【财富】含存款（无存款时**不出现**该括号）；债务走债务形态；未揭示黑市商品不出现 |
| `tests/save_test.gd` | 修改 | 「存 2 回合 + 存款 + 交易 → encode/decode → 重建引擎 → 继续 tick」与原时间线逐字段一致；老存档（无 `economy`）补齐后 `ok=true` |
| `tests/registry_test.gd` | 修改 | 两表注册 + `validate()` 对坏引用/坏枚举/负价格报错；`base_price != canon_price` 报错 |
| `tests/gm_test.gd` / `llm_test.gd` | 修改 | 4 个新 op 的守卫（金额上限钳制、余额不足拒绝、断供商品拒绝、`OpGuard` 对未知经济 op 一律拒绝） |
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
7. **`trade_money` 的「路费」用 category 常量**（不是真实距离）：本计划没有地点距离数据。若 03b 要做真实距离，需要给 `data/locations.json` 加坐标 —— **本计划不做**，用常量近似（风险：玩家可能找到「无限套利」路径，靠 `OpGuard` 的金额上限与「同回合不可重复同类交易」约束）。
8. **本 spec 的数值经 Python 实算核对，改掉了初稿两处错误**（教训同 03a §13.2「0.45 在任何合法状态都不可达」）：
   - ① 债务验收用例 `-1002` 初稿写成「16**西可**」，实算是 `parts=(-2,0,-16)` ⇒ 第三位是**16纳特**、西可为 0。单位写错会让实现者照抄出一个错误的测试期望。
   - ② `scarcity_mult` 初稿只有一档且**未标注两侧弹性不对称**（繁荣侧仅 10% 弹性、危机侧 60%），实算才发现「景气好」几乎不影响物价。补成口径 A/B 供裁定（K5）。
   - **流程要求**：03b 的实现计划（writing-plans 产出）在写任何 `data/*.json` 的具体价格前，**必须先把 `canon_price_knuts` 与 §7.4 的算价公式实算一遍**（用 Python 或 Godot 一次性脚本），确认落在正典 5 个锚点内，再写进表。**不要先写表再验算。**

## 14. 后续计划边界

- **03c 社会与法律**：纯血家族完整制度（第十三章，含**家族财产/祖宅/继承** ⇒ 会填 `panel_formatter` 的【家族】财富字段）、协会体系（第十九章，含**行业规则/会员费** ⇒ 会与本计划的 `industries.json` 挂接）、法律与审判（第三十五章：威森加摩开庭/阿兹卡班/剥夺魔杖）、傲罗行动与非法施法后果（`§8#28/#29`）、**走私与非法施法的法律后果**（本计划只记 `smuggling_heat`）。
- **04** 神奇生物生态与区域危险度（本计划的 `creature` 类商品是它的输入）；**05** NPC 自主与信息可信度（NPC 经济行为）；**06** 多世代传承与世界记忆（**遗产**，与 03c 的继承一起）。
- **独立小计划**（与主线无关，随时可插）：**存档格式 v2**（`§8#9/#19/#26/#49/#71`，含 `economy` 的一次性迁移）、设置界面（含 `§8#63` 的 provider 复用）、流式输出、长期记忆。
- **03b 有意推到 03c 的**：走私的法律后果 · 协会的行业准入 · 家族财产。⇒ 03c 开工前先读本文件 §14 与 §13 第 7 条。
