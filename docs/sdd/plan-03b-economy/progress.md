# 计划 03b · 经济骨架 —— 耐久台账

> 本文件是**唯一权威**：每任务的提交 / 断言数 / 门禁结果 / 审查结论 / findings 处置 / 挂账。
> 与代码同一次提交更新（`NEXT-STEPS.md` §0C 的硬规则）。
> spec：`docs/superpowers/specs/2026-09-21-hp-magic-era-03b-economy-design.md`
> 实现计划：`docs/superpowers/plans/2026-09-21-hp-magic-era-03b-economy.md`（**已产出，待执行**）

---

## Task 0：设计 spec（2026-09-21，控制器直接执行）

- **状态**：spec 已产出并推送（`8453309` + `195c09f`），**待人类评审**
- **产物**：`docs/superpowers/specs/2026-09-21-hp-magic-era-03b-economy-design.md`（14 节）
- **范围来源**：03a spec §14 划定的「03b 经济骨架」边界，未越界（协会/家族/法律后果明确留给 03c）
- **接口冻结**（后续任务不许自行改）：
  - 两张新内容表 `data/goods.json`（§7.1）/ `data/industries.json`（§7.2）的字段集与枚举白名单
  - `WorldState.economy` 的键集与语义（§7.3）；`Economy.price_of()` 是**唯一算价入口**（§7.4）
  - 4 个新 op 的载荷与校验（§7.5）
  - **不新增 `world_vars` 键**、**不升 `save_version`**（沿用 03a D3/E3 的理由）
- **控制器自查（实算，不是推演）**：用 Python 逐值核对 spec 内所有数字，改掉初稿 2 处错误 ——
  ① 债务验收用例 `-1002` 的第三位是**纳特不是西可**（初稿写「16西可」）；
  ② `scarcity_mult` 两侧弹性不对称（繁荣侧仅 10%、危机侧 60%），初稿单档且未标注 ⇒ 补口径 A/B。
  经此把「写表前必须先实算」写成 spec §13.8 的**流程要求**。
  教训同 03a §13.2（0.45 在任何合法状态都不可达）：**spec 里的数值必须实算，不能凭直觉写**。
- **门禁**：`test.sh` **EXIT=0**（21 套件 / 2023 断言 / 失败 0）—— 本任务纯文档，无断言变化
- **待人类裁定 5 条**：K1（`Money` 负值显示是否改「负债 X」）/ K2（月度结算默认发工资）/
  K3（危机通知玩家）/ K4（服务类商品进表）/ **K5（物价曲线口径 A 还是 B）**
  —— **K1 与 K5 需明确点头**，其余已给建议
- **挂账（不阻塞）**：
  - `era_mult` 写在代码常量表而非 `data/`，与「内容进 data」铁律有张力（spec §13.2 已登记理由与退路）
  - 月度结算会让「不行动」不可行（K2）；若实跑发现新手开局即破产，需加开局缓冲
  - 价格量级必须对上正典「普通家庭年收入约数百加仑」（223 行）—— **本计划最可能返工处**（调常数，非推翻设计）
  - 危机阈值 0.35 与 `factions.gd:369` 必须共用一个常量（spec §7.4 第 7 条已写成硬约束）
- **附带（同批完成，非 03b 任务）**：按实际文件核对，修掉 6 处文档漂移（`ac0c664`）——
  HANDOFF §0/§8#72 的 B8 过时描述与自相矛盾、失效的 `NEXT-STEPS` 章节引用、
  §8#72 与真实文件名不符的切片清单、README 的素材缺口与失效链接、台账 B8 节的「5 件/6 件」计数笔误。
  漂移根因：README/HANDOFF 属「只在阶段变化/新踩坑时改」的两类文档，任务级完成不会触发它们被改。

---

## Task 1（前置）：实现计划产出 + 价格定版实算（2026-09-21，控制器直接执行）

- **状态**：实现计划已产出；**spec 的 §7.4 已按实算重写**
- **产物**：
  - `docs/superpowers/plans/2026-09-21-hp-magic-era-03b-economy.md`（12 个任务，格式对齐 03a 计划）
  - spec §7.4 / §7.1 / §13.8 / K5 行的**整段重写**（价格口径换版）
- **执行 spec §13.8 的「先实算后写表」流程，实算发现并修掉 6 处设计缺陷**（脚本在 `%TEMP%\hali_03b_*.py`）：

  | # | 缺陷 | 实算证据 | 修法 |
  | --- | --- | --- | --- |
  | ① | 债务用例 `-1002` 初稿写成「16**西可**」 | `parts=(-2,0,-16)` ⇒ 第三位是 16 纳特 | 改「16纳特」，已在 Task 0 修 |
  | ② | `canon_price` 被直接当 `base_price` | 5 个锚点里 **2 个越界**（上等魔杖 11.54 > 10、顶级疗伤 22.68 > 20） | `canon` 与 `base` **解耦**（C1/C6） |
  | ③ | **`supply_mult` 加重危机侧涨幅** | index=0.16 时 scarcity ×1.408、supply ×1.048 ⇒ 合计 **×1.479** > 区间宽 1.4286 | **`supply` 移出价格公式**（C5），只管可得性 |
  | ④ | 危机线与断供线**同为 0.35** | 留下 `index ∈ (0.35, 0.43]` 的「已越界但仍供货」死区 | 解耦为 `CRISIS_THRESHOLD=0.35` / `SUPPLY_CUTOFF=0.15` |
  | ⑤ | 原契约隐含「全域价必须落在正典区间内」 | **数学上不可能**：魔杖区间宽 1.4286x，乘数摆动必 >1.5x | 改为 C1–C6（危机侧守上沿；繁荣侧允许下探并记录） |
  | ⑥ | 「上等魔杖」复用普通魔杖的 `[7,10]` 窗口 | 该窗口常态可用带仅 `[3451, 3521]`（= 上沿/1.40），容不下第二档 | **删掉「上等魔杖」** |

- **价格定版常数**（实算反推，spec §7.4 常量总表）：
  `NEUTRAL_INDEX=0.5` / `NEUTRAL_ERA_YEAR=1950` / `MIN_SCARCITY=0.75` / `MAX_SCARCITY=1.40` /
  `CRISIS_THRESHOLD=0.35` / `SUPPLY_CUTOFF=0.15` / `MONOPOLY_EXCESS_MULT=2.0`
- **最终产物**：**35 条商品**（25 goods + 10 service）+ **9 条产业**；
  `industry_id` / `produces` 引用**全部实算校验通过**；5 个正典锚点**全域守门通过**（C1/C2/C3 全绿）
- **实算关键中间值（供后续任务复用，勿重算）**：
  - 普通魔杖 base 3451 ⇒ 常态 7.00 加隆；危机峰值 4831（**守 4930 上沿**）；繁荣谷值 3106
  - 优质疗伤 base 2465 ⇒ 常态 5.00 加隆；危机峰值 3451（守 9860）
  - 顶级疗伤 base 6162 ⇒ 常态 12.50 加隆（正典区间中点）；危机峰值 8627（守 9860）
  - 光轮扫帚 base 49300 ⇒ 常态 100 加隆；危机峰值 69020（守 147900）
  - 家庭月支出模型：房租 4437 + 食物 240 + 车票 493 + 医疗 986 + 杂项 1109 ≈ **7265 纳特/月**
    ⇒ 年支出 ≈ 174 加隆，**落在正典「数百加隆」量级内**；从业者月薪应 ≥ 7300 纳特
- **门禁**：`bash tools/test.sh` **EXIT=0**（21 套件 / 2023 断言 / 失败 0）—— 本任务纯文档，无断言变化
- **评审状态**：K1–K5 五条裁定**已按建议默认**写进计划（K1 接受「负债 X」；K5 用口径 A）；
  两条**仍可回退**，回退只需改 spec §7.4 常数 + 计划 Task 3 的断言串，不动结构
- **挂账（不阻塞，已写入计划）**：
  - `era_mult` 在代码常量表（非 `data/`）—— spec §13 风险 2 已登记理由与退路
  - 月度结算量级（spec §13 风险 4）是本计划**最可能返工处**：Task 5 Step 3 要求实现后**必须实算一次月收支平衡点**
  - 路费用 category 常量近似（无地点距离数据，spec §13 风险 7），靠 `OpGuard` 上限约束套利
  - 危机阈值 0.35 的**单源**要求已写成 Global Constraint：`factions.gd:369` 必须改为引用 `Economy.CRISIS_THRESHOLD`

- **下一步**：拉分支 `plan-03b-economy` 开工 Task 1（内容表 + Registry 校验）

---

## Task 1：内容表 `goods` / `industries` + Registry 注册与字段校验（2026-09-21）

- **分支**：`plan-03b-economy`（从 `main`@`c0fa1c9`）
- **状态**：✅ 完成（含一处 spec/计划修正，见下）
- **变更文件**：
  | 文件 | 动作 |
  | --- | --- |
  | `data/industries.json` | 新建（9 条） |
  | `data/goods.json` | 新建（35 条，含新字段 `canon_price_hi_knuts`） |
  | `src/rules/economy.gd`(+`.uid`) | 新建（本任务只放常量骨架） |
  | `src/core/registry.gd` | `TABLE_FILES` 注册两表 + `_validate_goods` / `_validate_industry` |
  | `tests/registry_test.gd` | 追加 03b 断言块（约 300 条） |
  | `docs/superpowers/specs/...03b-economy-design.md` | §7.1 加字段 / §7.4 C3+C6 / §13.8 缺陷⑦ |
  | `docs/superpowers/plans/...03b-economy.md` | 字段契约 / 价格表 / Task 1 Step 4 校验规则 / 测试块 |

- **⚠️ 施工中暴露并修掉的第 7 处设计缺陷（⑦，人类裁定选 A 方案）**：
  - **现象**：按计划原文的校验带 `[canon_lo, roundi(canon_lo × MAX_SCARCITY / MIN_SCARCITY)]`
    跑出 `potion_healing_premium` 越界（base 6162 > 上界 4601）。
  - **根因**：该推导式隐含假设「**一条商品 = 一个 canon 窗口，且 base 就落在下沿**」。
    `potion_healing_premium` 与 `potion_healing` **共享同一个 canon 区间**（正典只给
    「优质疗伤药剂 5–20 加隆」一个区间），但 base 取该区间**上段**（12.50 加隆 = 6162）。
  - **关键判断**：这不是「数据写错了」——顶级疗伤危机峰价 8627 **< canon_hi 9860**，
    **C3 契约实际是满足的**；错的是「上界由下沿反推」这个做法本身。
  - **修法（人类裁定 A）**：新增 `canon_price_hi_knuts` 字段**直接存正典区间上沿**；
    `Registry.validate()` 改为两条一起查：①`base ∈ [canon_lo, canon_hi]`（C6）
    ②`roundi(base × MAX_SCARCITY) <= canon_hi`（C3 本体）。
  - **正典锚点区间表**（spec §7.1 定版）：
    `wand_standard` [3451, 4930] · `potion_healing` [2465, 9860] ·
    `potion_healing_premium` [2465, 9860]（共享）· `broom_nimbus` [49300, 147900]
  - **元教训（已写进 spec §13.8）**：缺陷 ②～⑦ 同一形态 ——
    **用「推导式」代替「正典里本来就写明的量」**。凡正典**直接给出**的数字就该**存字段**，
    推导式只在正典确实没给、且隐含前提**写下来并验证过**时才用。

- **精确价格表（实算复现验证，35 条全部自检通过）**：

  | 商品 | base | canon_lo | canon_hi | 危机峰 `roundi(base×1.40)` | 守 |
  | --- | --- | --- | --- | --- | --- |
  | wand_standard | 3451 | 3451 | 4930 | 4831 | ✅ |
  | potion_healing | 2465 | 2465 | 9860 | 3451 | ✅ |
  | potion_healing_premium | 6162 | 2465 | 9860 | 8627 | ✅ |
  | broom_nimbus | 49300 | 49300 | 147900 | 69020 | ✅ |

- **门禁（四道全过）**：
  | 门 | 结果 |
  | --- | --- |
  | `bash tools/test.sh` | **EXIT=0**，22 套件 / **2073 断言** / 失败 0（`registry` 从 2023 前的基线涨到 **522 断言**） |
  | `stderr` 噪声 | `^SCRIPT ERROR` = **2**、`^ERROR:` = **7** —— 与基线一致 |
  | `timeout 300 bash tools/b1_acceptance.sh` | **EXIT=0**，151 断言 / 失败 0，`llm_settings.json` 与 `saves/slot1.json` **逐字还原** |
  | 工作区 + 进程 | 仅 `.workbuddy/` 未跟踪；`tasklist \| grep -i godot` = **0** |
- **Registry 校验（本任务新增，机器保障）**：
  - `goods`：`category ∈ [_GOODS_CATEGORIES]`（字面量，与 `Economy.CATEGORIES` 由测试钉死一致）、
    `kind ∈ [_GOODS_KINDS]`、`base > 0`、`canon_lo >= 0`、`unit` 非空、
    `kind == "goods"` ⇒ `industry_id ∈ industries`、锚点条目 ⇒ `canon_line > 0` 且 `canon_price_hi > 0`、
    **C6+C3 两条带校验**
  - `industries`：`base_output ∈ [0,1]`、`monopoly` 是 bool、`produces` 每条 ∈ goods
  - 坏内容反证：9 条负向断言（坏 category / 坏 kind / 坏 industry 引用 / 越带 / 危机峰越界 /
    缺 canon_line / 缺 canon_hi / 坏 produces / 越界 base_output）**全部被拦**；
    外加 1 条**正向**断言「共享区间的 premium 档不被误判」
- **循环依赖风险已排除**：`registry.gd` 用**字面量**白名单（不 preload `Economy`），
  与 03a 对 `_KINDS` / `_INSTITUTIONS` 的既有做法一致；
  两处枚举一致性由 `a.eq(cats, Economy.CATEGORIES, ...)` / `a.eq(goods_kinds, Economy.KINDS, ...)` 钉死
- **挂账（不阻塞）**：
  - `broom_nimbus` 的 canon 上沿 147900（= 300 加隆）是**「数十至数百加隆」的具体化**，
    正典原文是模糊量词 —— spec §7.1 已写明「将来收紧先改表再改 json」
  - `_SCARCITY_MAX = 1.40` 在 `registry.gd` 与 `Economy.MAX_SCARCITY` **各写一份字面量**
    （同上，registry 不能反向依赖 Economy）；目前**没有测试钉死这两个数一致**，
    留待 Task 2 在 `economy_test.gd` 加一条（已在计划 Task 2 范围内）

- **下一步**：Task 2（`Economy` 算价核心 + `WorldState.economy` + 存档白名单 + 危机常量单源）

---

## Task 2：`Economy` 算价核心 + `WorldState.economy` + 存档白名单 + 危机常量单源（2026-09-21）

- **状态**：✅ 完成（含 2 处口径修正 + 3 处实况修正）
- **变更文件**：
  | 文件 | 动作 |
  | --- | --- |
  | `src/rules/economy.gd` | 加算价核心（`era_mult_for`/`scarcity_mult_for`/`local_mult_for`/`available`/`is_crisis`/`effective_output`/`price_factors`/`price_of`）+ `initialize`/`_snapshot_prices`/`snapshot_price` |
  | `src/model/world_state.gd` | 加 `economy` 字段；`create`/`from_dict` 调 `Economy.initialize`；`to_dict` 输出 |
  | `src/persist/save_codec.gd` | `economy` 进字典字段白名单（**未升 `save_version`**） |
  | `src/rules/factions.gd` | `:369` 的 `0.35` 字面量 → `Economy.CRISIS_THRESHOLD`（**只改这一处**） |
  | `tests/economy_test.gd`(+`.uid`) | 新建，**906 断言** |
  | `tests/run_tests.gd` | `SUITES` 追加 `economy_test.gd`（22 套件） |
  | spec / 计划 | C1 定义点修正、三处实况修正 |

- **⚠️ 口径修正 A（人类裁定）：C1 的定义点是「中性时代」，不是 `modern`**
  - 现象：`modern`(2010) 的 `era_mult = 1.10`，导致 C1 全线偏 ×1.10，且
    `wand_standard` 危机峰 `3451 × 1.10 × 1.40 = **5315 > 4930**`（**越了 canon 上沿**）。
  - 根因：C1 初稿把「常态」与「`modern` 时代」错误划了等号。
    `ERA_MULT` 表里中性档是 `y ≤ 1980`（实际命中 `first_wizarding_war` 1970 = **1.00**），
    `modern` 落 `1.10`；而 `NEUTRAL_ERA_YEAR = 1950` 锚的是 canon 223 行的价位语境。
  - 修法：C1 改为 `era_mult == 1.0` 的时代；`base_price_knuts` 语义明确为
    「**常态 + 中性时代**的价」。35 条 base **一个数没改**。`modern` 时代物价 = `base × 1.10`
    是**有意设计**（现代巫师社会物价高于 1950 年代），已写进 spec。
  - 附带：断言里正面钉死「`modern` = 1.10 **非中性**」「战后回落 `modern(1.10) < 二次战争(1.15)`」

- **⚠️ 三条实况修正（计划原文有误，已同步改计划）**
  | # | 计划原文 | 实况 |
  | --- | --- | --- |
  | 1 | `Registry.entry("eras", ...)` | `entry()`/`ids()` 是**实例方法**，静态直呼 → Parse Error。必须走 **`world.registry`** |
  | 2 | `world.vars.get(...)` | 字段名是 **`world.world_vars`**；写 `world.vars` → 运行期 `Invalid access` |
  | 3 | `_industry_monopoly(industry_id)` | 因第 1 条，签名必须是 `_is_monopoly(world, industry_id)` |

- **🐛 施工中修掉的真 bug（1 个，非文档问题）**
  - **`economy.prices` 快照被 `initialize()` 误重算** —— `from_dict` 拿到的 `world_vars`
    已过 `JsonUtil.normalize()`（浮点尾差），重算出的价与存盘时**逐字不同**
    （实测 `wand_standard` 3644 → 3646），打破 `save_test` 的
    「读档后重建引擎续跑：世界状态一致」断言。
  - 修法：`initialize()` 只补**缺失**的 `prices`；快照唯一刷新点是**世界推进**（Task 6 `evolve()`）。
  - **`from_dict` 扛不住 `economy = null`** —— 类型化字段 `Dictionary` 赋 `Nil` 直接运行期报错。
    修法：非字典一律回落 `{}`。（这两条都是「生产值/异常存档路径」类，正向断言测不出来）

- **✅ 反证实验（Task 2 Step 7，spec §9 第 3 条，必做项）**
  | 实验 | 注入 | 实测结果 | 判定 |
  | --- | --- | --- | --- |
  | ① 取消 `scarcity_mult` 封顶 | `return raw` | `C3 全域价 <= canon_hi: wand_standard (**6342** <= 4930)` 变红 + 「垄断倍率守 MAX_SCARCITY」变红 | ✅ **C3 有判别力** |
  | ② 把 `supply` 乘回价格 | `raw *= effective_output(...)` | C1 全线腰斩（`wand_standard 3451 → **1812**`）+ **C2 单调性也破**（`1948 → 1946 → 1948 → 1951` 出现回升） | ✅ **C5 有判别力**，且实证了 spec 的理由 |
  - ② 的意外收获：`effective_output` 依赖 `economy_index`，乘进去后引入**方向相反的第二项**，
    连**单调性**都破坏 —— 这是对 spec §7.4 C5「`supply` 语义与 `economy_index` 重复且方向冲突」
    的**实测证据**（不只是纸面推理）。两段原始输出已存档待贴报告。
  - 恢复代码后复跑：**全绿**（`economy` 906/0，总计 0 失败）。

- **门禁（四道全过）**：
  | 门 | 结果 |
  | --- | --- |
  | `bash tools/test.sh` | **EXIT=0**，**22 套件 / 2864 断言** / 失败 0（`economy` = **906** 新套件） |
  | `stderr` 噪声 | `^SCRIPT ERROR` = **2**、`^ERROR:` = **7** —— 与基线一致 |
  | `timeout 300 bash tools/b1_acceptance.sh` | **EXIT=0**，151 断言 / 失败 0，配置**逐字还原** |
  | 工作区 + 进程 | 仅 `.workbuddy/` 未跟踪；godot 进程 **0** |

- **挂账（不阻塞）**：
  - `registry.gd` 的 `_SCARCITY_MAX = 1.40` 与 `Economy.MAX_SCARCITY` 两个字面量**尚无一致性断言** ——
    Task 2 已在 `economy_test.gd` 里加了 `CATEGORIES`/`KINDS` 的两处一致断言，但**没加这个数的**，
    留到 Task 11/12 一并补齐（或本轮补）
  - K1（`Money` 负值形态）与 K5（`scarcity_mult` 口径 A）仍为**默认接受、可回退**
  - `world_vars.economy_index` 是 03a 的字段，03b **只读**；`Economy` 不写 `factions`/`standing`（已遵守）

- **下一步**：Task 3（`Money` 负值语义）

---

## Task 3：`Money` 负值语义（2026-09-21）

- **状态**：✅ 完成（HANDOFF §8#5 裁定落地）
- **变更文件**：`src/model/money.gd`（加 `is_debt` / `debt_formatted`，`formatted` 加负值分支）、
  `tests/money_test.gd`（18 → **35 断言**）
- **契约**：
  - `parts()` / `to_dict()` **一字未改**（负值仍是 `[-g,-s,-k]`，第三位是纳特）
  - `formatted()` 非负分支**逐字保持原输出**（三位全写，含 0）
  - `formatted()` 负值 → `debt_formatted()`：`负债 2加隆 16纳特`
  - `debt_formatted()` **省略 0 值单位**（`-493` → 「负债 1加隆」，不带「0西可 0纳特」尾巴）
- **实算钉死的期望值**（不是照抄「看起来对」的串）：`-1002` → `负债 2加隆 16纳特`；
  `-17` → `负债 1西可`；`-5` → `负债 5纳特`；`-493` → `负债 1加隆`；
  `-510` → `负债 1加隆 1西可`；`-511` → 三位齐全；`-50` → `负债 2西可 16纳特`
- **额外钉死**：`-493` 的债务串**不含** `0西可`（防有人给债务形态也加「写满三位」）；
  正典量级两条（`-3451` → 7加隆 / `-49300` → 100加隆）
- **`panel_test` 结论**：面板既有 102 条断言**无需改动** —— 说明 03a 的面板测试里
  没有负值形态的断言（spec Task 3 Step 4 预设的「要同步改」实际未发生）
- **门禁**：`test.sh` **EXIT=0**（22 套件 / **2881 断言** / 0 失败；`money` 35/0）
- **下一步**：Task 4（4 个新 op + OpGuard 钳制）

---

## Task 4：4 个经济 op（存 / 取 / 汇 / 贸）+ OpGuard 钳制（2026-09-21）

- **状态**：✅ 完成（**开工前撞到一个口径空洞，见「缺陷⑧」，已按铁律先改 spec 文本**）
- **变更文件**：
  | 文件 | 变更 |
  | --- | --- |
  | `src/rules/economy.gd` | `local_mult_for` **改口径**（`world_vars.location_tag` → `locations.zone`）；新增 `local_tag_for` / `local_mult_at` / `price_factors_at` / `price_at`；`initialize` 加 `player == null` 早退；补 `foreign_held` 键 |
  | `src/rules/state_ops.gd` | +171 行：`_apply_deposit/_apply_withdraw/_apply_exchange/_apply_trade` 四段 + `_record_trade_side_effects` + `_payload_int` |
  | `src/gm/op_guard.gd` | +88 行：`MAX_BANK_MOVE` / `MAX_TRADE_QTY` / **`MAX_TRADE_VALUE`** / `_ECONOMY_FORBIDDEN`；`sanitize_op`（单条入口，带 `.ok`）；4 个经济 op 的钳制分支 |
  | `tests/gm_test.gd` | 405 → **615** 行；+210 行、**+182 断言**（总 183） |
  | `tests/llm_test.gd` | +47 行、+56 断言（总 116） |
  | `tests/economy_test.gd` | `make_world` 默认地点 `london_muggle` → `diagon_alley`；local_mult 段整体重写（死路径断言 → zone 推导 + 缺省安全 + `price_at`） |
  | `docs/.../03b-economy-design.md` | §7.4 第 4 条 / §7.5 四条 op / §11 测试策略 / §13 风险 7+8 |
  | `docs/.../03b-economy.md`(plan) | Task 2 `local_mult_for` 修正 + Task 4 实况修正块 |

### 缺陷⑧（本任务开工前发现，两个独立问题捆在一起）

| # | 问题 | 证据 | 处置 |
| --- | --- | --- | --- |
| ⑧a | **`local_mult` 的来源不存在** | `local_mult_for` 读 `world_vars["location_tag"]`，`grep` 全仓库只有 `economy.gd` 自身、`economy_test` 的手动注入、plan 文本 —— **没有任何生产写入方** ⇒ 永远走缺省 1.0。更致命：`world_vars` 在玩家换地点时**不变** ⇒ E7「产地买、销地卖」**在实现上不可能** | 改按 `locations.json` 的 `zone` 推导（wild/forbidden→产地 0.85、wizarding/school→常规 1.0、muggle→偏远 1.2；未知→缺省 1.0） |
| ⑧b | **`MAX_TRADE_QTY=100` 是件数不是金额，防不住套利** | 实算（产区 0.85 → 偏远 1.2，扣两次路费）：`broom_nimbus` 净利 **17 135 纳特/件**，`qty=100` ⇒ 单笔 **1 713 500 纳特 = 3 476 加隆 ≈ 11.6 倍「普通家庭年收入数百加隆」**（正典 223 行）。spec §13 风险 7 原文写「靠 OpGuard 的金额上限与同回合不可重复交易约束」——**该约束无效** | 新增**货值闸门** `MAX_TRADE_VALUE := 5000`（按 `base_price_knuts × qty`）；**放弃**「同回合不可重复交易」（缺回合级记账） |

**货值闸门实算效果**（`qty_max = floor(5000 / base)`）：

| 商品 | `base` | `qty` 上限 | 单笔净利 | 折合加隆 |
| --- | ---: | ---: | ---: | ---: |
| `svc_owl_post` | 17 | 100（件数上限先到） | 600 | 1.2 |
| `potion_common` | 986 | 5 | ~1 525 | ~3.1 |
| `wand_standard` | 3 451 | 1 | 1 148 | 2.3 |
| `broom_nimbus` | 49 300 | **0 ⇒ 拒绝** | — | — |

⇒ 高价耐用品天然不可搬运，跑量只发生在低价快消品。量级回到正典区间。

### 实况修正（plan 文本与实况不符，三处）

| # | plan 原文 | 实况 | 处置 |
| --- | --- | --- | --- |
| 1 | `OpGuard.sanitize_op({"op": ...})` **单条**入口 | 只有 `sanitize` / `sanitize_detailed`，**无** `sanitize_op` | 新增 `sanitize_op(world, raw) -> Result`（薄封装）；`Result` 加 `ok` 字段（`sanitize_detailed` 不填，默认 true 以不扰动既有调用方） |
| 2 | `local_mult_for(_world, _good_id)` 未指明地点来源 | 见缺陷⑧a | 改按 `zone` 推导；签名加 `_good_id` 缺省值 |
| 3 | 「同回合不可重复同类交易」 | 无回合级记账机制 | 放弃，由双闸（件数 + 货值）替代 |

### 真实 bug（写测试过程中抓到，2 个）

| # | 症状 | 根因 | 修法 |
| --- | --- | --- | --- |
| **B1** | `save_test` 的 6 个畸形载荷共引发 **35 条 `SCRIPT ERROR: Invalid access to property or key 'location_id' on a base object of type 'Nil'`**（噪音门禁从 2 飙到 37） | `SaveCodec.decode` 在**类型校验失败之前**也会走一遍 `WorldState.from_dict`，此时 `player` 可能是 Nil ⇒ `Economy.initialize` → `_snapshot_prices` → `price_of` → `local_mult_for` 读 `player.location_id` 崩 | `initialize` 与 `local_mult_for` 各加 `player == null` 早退（**双层防御**：前者是语义正确，后者是类型安全） |
| **B2** | `economy_test` 906 条断言**全红**（C1 整体偏 1.2 倍） | `make_world` 默认地点是 `london_muggle`（`zone == "muggle"`）⇒ 新口径下 `local_mult == 1.2` | 默认地点改 `diagon_alley`（`zone == "wizarding"`）；与「C1 的中性时代」是**同一种错误的第三次现身**——定义点必须落在所有因子都等于 1 的那一点 |

### 我自己的测试 bug（3 个，如实记录）

| # | 症状 | 原因 |
| --- | --- | --- |
| t1 | `llm_test`：`trade_money qty 钳到 MAX_TRADE_QTY` 期望 100 实得 5 / 10 | 夹具用了 `potion_common`(986) / `mat_ore`(493) —— **高价商品会先被货值闸门拦下**，测到的是货值闸门而不是件数上限（两条闸互相遮蔽）。改用 `svc_owl_post`(17)，全表只有它能同时满足「货值容许 ≥100」 |
| t2 | `gm_test`：`sell 收到的加隆` 期望 49201 实得 49104 | 我把公式写成 `held × rate`，漏了 `sell` 也要**再打一次折**（`× (1 - 价差)`）—— 「买卖往返必亏」正是价差的作用 |
| t3 | `gm_test`：走私 3 条全红 | 夹具用 `illegal_relic`(9860)，货值闸门把 qty 钳到 0 ⇒ 被拒。改用 `illegal_potion`(4930, `qty_max=1`)——全表三个 illegal 商品里唯一可交易的那个 |

### `local_mult` 口径变更的**契约影响：零**

- C1–C3 的扫描基准是 `local_mult == 1.0` 的常规地点（对角巷/霍格沃茨），`price_of` 在此处**逐字不变**
- `economy` 套件 **906 → 917 断言全绿**（新增 11 条 zone 推导 + 缺省安全 + `price_at`）
- 但**这是「改了就对」而不是「没改」的证据**：新增断言**含反向判别**——换地点后价格必须真的变（原实现在此处必然不变）

### 门禁（四道全过）

| 门 | 结果 |
| --- | --- |
| `bash tools/test.sh` | **EXIT=0**，22 套件 / **3301 断言** / 失败 1（`probe` 故意失败）；`gm` **183**、`llm` **116**、`economy` **917** |
| `stderr` 噪声 | `^SCRIPT ERROR` = **2**、`^ERROR:` = **7** —— **与基线逐字一致**（修 B1 前是 37） |
| `timeout 300 bash tools/b1_acceptance.sh` | **EXIT=0**，151 断言 / 失败 0，配置逐字还原 |
| 工作区 + 进程 | 8 个已跟踪文件修改、`.workbuddy/` 未跟踪；godot 进程 **0** |

### 挂账（不阻塞）

- `registry.gd` 的 `_SCARCITY_MAX = 1.40` 与 `Economy.MAX_SCARCITY` 仍**无一致性断言**（同 Task 2 挂账，留 Task 11/12）
- `Max_TRADE_VALUE` 是否需要在 b1 契约里被观测（Task 11 定）
- K1（`Money` 负值形态）与 K5（`scarcity_mult` 口径 A）仍为**默认接受、可回退**

---

## Task 5：月度结算（工资 / 开销 / 利息）+ `data/jobs.json` + 食物价修正

**状态：完成**（2026-09-21）

### 交付内容

| 文件 | 变更 |
| --- | --- |
| `data/jobs.json` | **新增**（第 3 张内容表）：正典 198 行 9 类城市巫师职业 + 月薪，全部 `canon_line: 198` |
| `data/goods.json` | 缺陷⑨：`food_butterbeer` `2→34`、`food_pumpkin_pastry` `1→34`，两行 `industry_id` `publishing→""` |
| `src/core/registry.gd` | `TABLE_FILES` 注册 `jobs`；新增 `_validate_job`（量级锚点 + `canon_line` 守卫）；`_validate_goods` 对**空 `industry_id` 放行**（缺陷⑨ 的连带修正） |
| `src/rules/economy.gd` | 新常量 `ADULT_MONTHS=204` / `FOOD_UNITS_PER_MONTH=60` / `UNKNOWN_WAGE_KNUTS=4930`；`monthly_settlement()`；`_wage_for()`（三级匹配） |
| `tests/economy_test.gd` | +84 断言（⑱–㉙ + 未成年契约 + 成年边界 + 多回合） |
| `tests/registry_test.gd` | +11 断言（jobs 表 + 空 industry_id 放行 + 两条坏职业负例） |
| `docs/superpowers/specs/...03b-economy-design.md` | §7.6 补章 + 缺陷⑪/⑫ 修正 + §4 行号 196→198 + §6 加 `jobs.json` + §13 缺陷表 ⑦→⑫（共 **13** 处） |
| `docs/superpowers/plans/...03b-economy.md` | Task 5「实况修正 2」+ Step 3 代码样本 + 薪资锚点note 重写 + Step 4 提交命令 |

### 缺陷表（本任务新发现 3 个：⑨ / ⑩+⑩b / ⑪ / ⑫）

| # | 缺陷 | 证据 | 修法 |
| --- | --- | --- | --- |
| **⑨** | **食物价量级错**：`food_butterbeer=2 纳特`、`food_pumpkin_pastry=1 纳特`，`industry_id` 错填 `publishing` | `1 纳特 ≈ 0.002 加隆` ⇒ 南瓜馅饼比月房租 4437 便宜 4437 倍；「南瓜饼归出版社」 | 改 `34` 纳特/份 + `industry_id=""`；月支出回到 **6477**（与 plan 既有实算自洽）。取 34 而非 58 的理由见 spec §7.6 |
| **⑩** | **职业表不存在**：plan 写「若已在 `data/jobs.json` 就复用（先查）」，`_wage_for` 无表可依 | 查了 `data/` 22 个文件，**无 jobs**；`player.job` 是自由字符串 | 新建 `data/jobs.json`（正典 198 行 9 类）+ 注册 + 校验 |
| **⑩b** | 正典行号偏移：spec §4 写「196 ⇒ 职业清单」 | 实际正文在 **198** | 修正引用表；`jobs.json` 各行 `canon_line=198` |
| **⑪** | **工资上沿口径自相矛盾**：§7.6 断言「其余 8 条**全部**在 `[2958, 7395]` 内」 | 实算 `healer=8874=18加隆`、`pub_owner=7888=16加隆`，**两条越出 7395**（越界 3 条不是 1 条） | **不改数值改断言**：下沿 2958 硬约束；上沿放宽至 `9860` 且**仅 `quidditch_pro` 可达**；量级自洽改判「中位年收入落在数百加隆」（中位 6900×12 = **168 加隆** ✔）。元教训：15 加隆不是正典数字，是倒推的软参考 |
| **⑫** | **未成年是否照收生活费未定义**：K2 只说工资门槛，§7.6 开销行只说「房租+食物×60」 | 照收 ⇒ 11 岁开局到 17 岁前累计 **−946 加隆**（≈普通家庭 6 年收入）；正典 424 行未成年不得在校外用魔法、563 行 17 岁前属「学徒」 | **用户拍板读法 B：未成年整月跳过**（收支皆 0，仅推进 `last_settlement_turn`）。「未成年无开销」升为**契约**（显式断言防回退） |

### 真实 bug（写测试过程中抓到，1 个）

| # | 症状 | 根因 | 修法 |
| --- | --- | --- | --- |
| **B3** | `_validate_goods` 对 `food_*` 报 `industry_id 不存在（）`（内容表校验失败 2 条，`registry_test` 4 红） | 原校验 `if not has("industries", iid)` **对空串也判失败**；而缺陷⑨ 把食物改成「无产业」⇒ 空串成了合法值。`svc_*` 服务行之所以没事，是因为它们走 `kind == "service"` 分支**整个跳过**这段 | `if not iid.is_empty() and not has(...)` —— 空 = 无产业（与服务行同款语义），非空才查引用完整性 |

### 我自己的测试 bug（2 个，如实记录）

| # | 症状 | 原因 |
| --- | --- | --- |
| t4 | `monthly_settlement` 全套件测出**全 0**，一度误判实现坏了 | 幂等门是 `last_settlement_turn == clock.turn`，而**新建世界的 `turn` 与 `last_settlement_turn` 都是 0** ⇒ 不推回合则第一次结算就被门挡掉。真实流程 `tick()` **先** `advance_month()` **再**结算 ⇒ 测试须用 `w.clock.advance_month()` 复现调用序 |
| t5 | 我按 spec 原文字写「未成年无开销」断言，代码却收了 6477 ⇒ 2 红 | 这条红**暴露了缺陷⑫**（spec 未定义），不是测试写错 —— 正是「测试先写、红得有理」的价值 |

### 量级锚点最终口径（缺陷⑪ 修正后）

| 职业 | 纳特 | 加隆 | 判定 |
| --- | ---: | ---: | --- |
| `shop_clerk` | 4 930 | 10.00 | ✔ |
| `journalist` / `owl_keeper` | 5 423 | 11.00 | ✔ |
| `broom_repair` | 5 916 | 12.00 | ✔ |
| `shopkeeper`（**中位**） | 6 900 | 14.00 | ✔ 年收入 **168 加隆**（正典 223 行「数百加隆」） |
| `apothecary` | 7 395 | 15.00 | ✔ |
| `pub_owner` | 7 888 | 16.00 | ✔（自营业主，含经营所得） |
| `healer` | 8 874 | 18.00 | ✔（圣芒戈高技能专业岗） |
| `quidditch_pro` | 9 860 | **20.00** | ✔ 唯一可达上沿（正典 233 行「也是商业」） |

**硬约束**：下沿 `>= 2958`（6 加隆）—— 9 条全满足；上沿 `<= 9860`，且**仅 `quidditch_pro` 可达**（其余 8 条严格 `< 9860`）。

### 门禁（四道全过）

| 门 | 结果 |
| --- | --- |
| `bash tools/test.sh` | **EXIT=0**，23 套件 / **3431 断言**（3301 → +130）/ 失败 1（`probe` 故意失败）；`registry` **568**、`economy` **1001** |
| `stderr` 噪声 | `^SCRIPT ERROR` = **2**、`^ERROR:` = **7** —— **与基线逐字一致** |
| `timeout 300 bash tools/b1_acceptance.sh` | **EXIT=0**，151 断言 / 失败 0，配置逐字还原 |
| 工作区 + 进程 | 7 个已跟踪文件修改 + `data/jobs.json` 新增、`.workbuddy/` 未跟踪；godot 进程 **0** |

### 挂账（不阻塞）

- `registry.gd` 的 `_SCARCITY_MAX = 1.40` 与 `Economy.MAX_SCARCITY` 仍**无一致性断言**（同 Task 2/4 挂账，留 Task 11/12）
- `registry.gd` 的 `_JOB_WAGE_MIN/_MAX`（2958/9860）与 `Economy` 侧无同名常量 ⇒ **暂无漂移风险**，但若 Task 6+ 把锚点搬进 `Economy` 需补一致性断言
- `MAX_TRADE_VALUE`、`monthly_settlement` 是否进 b1 经济可观测契约（Task 11 定）
- K1（`Money` 负值形态）与 K5（`scarcity_mult` 口径 A）仍为**默认接受、可回退**
- 缺陷⑫ 的读法 B 是**用户裁定**，若后续想开「未成年打工」通道需重开 spec 章节

---

## Task 6：`tick()` 接线（`evolve()` + `monthly_settlement()` + 危机边沿）

**状态：完成**（2026-09-21）

### 交付内容

| 文件 | 变更 |
| --- | --- |
| `src/rules/economy.gd` | 新增 `evolve(world) -> Array`、`_crisis_event()`；常量 `CRISIS_EVENT_KIND` / `FOREIGN_RATE_SWING` / `FOREIGN_RATE_MIN` / `FOREIGN_RATE_MAX` |
| `src/model/world_state.gd` | `tick()` 在 ④ `WorldFactions.evolve()` 之后插入 ⑤ `Economy.evolve()` + ⑥ `Economy.monthly_settlement()`；原 ⑤⑥⑦ 顺延为 ⑦⑧⑨ |
| `tests/economy_test.gd` | +40 断言（`_check_evolve`：快照一致性 / 危机边沿 / 汇率确定性 / 结算接线 / 既有阶段未扰动） |
| `docs/superpowers/specs/...03b-economy-design.md` | 新增 §5.2 顺序契约 + §11 第 6 条接线验收 + §13 缺陷 ⑬ + 计数 13→**14** |
| `docs/superpowers/plans/...03b-economy.md` | Task 6 步骤 3 的顺序论断修正（含缺陷⑬ 说明） |

### 与 plan 的两处实况偏差

| # | plan 写法 | 实况 | 处置 |
| --- | --- | --- | --- |
| 1 | `static func evolve(world) -> void` | `tick()` 的 `events` 是**局部数组**，`void` 签名无法把危机事件交出去 | 改 **`-> Array`**（与既有 `WorldFactions.evolve()` 同款约定）；`tick()` 用 `for … in` 并入 `events` + `log` |
| 2 | 测试示例用 `w_c.events.size()`、`_make_world(1950, 0.5)`、`_make_world_seeded(...)`、`w.vars[...]` | `events` 不是字段；无 `_make_world*` 辅助；字段名是 `world_vars` 不是 `vars` | 按实况改用 **`tick()` 返回值** + 既有 `make_world()` / `_pin()` |

### 缺陷⑬（本任务新发现，**最有价值的一条**）

**顺序契约的理由写错了，且据此写的断言是空转的。**

- **原说法**（spec §5/§8 + plan）：「`evolve` 必须在 `settlement` 之前，**否则结算用的是上月价**」。
- **实测**：`price_of()` 是**活算**（每次从 `world_vars` 重算），**从不读快照**；`monthly_settlement` 走 `price_of` ⇒ **顺序对结果无影响**。
- **反向控制**：我把两阶段顺序**对调**，`economy` 套件 **1037 断言仍然全绿** ⇒ 那条顺序断言是**装饰品**。
- **修正**：顺序仍不可换，但**真正的理由是另一个** —— `_snapshot_prices` 产出的快照是**面板（Task 7）/ `PromptBuilder`（Task 8）**读的「本月价目表」（`snapshot_price()` 快照优先、缺失才回落活算）。`evolve` 在前，保证「**面板看到的价**」与「**结算用的价**」**同源同月**。
- **断言改为**：「快照逐条 == 当回合 `price_of`」（35 条商品全比对）。

### 反向控制验证（本任务新引入的做法，3 组）

| # | 故意破坏 | 期望 | 实测 |
| --- | --- | --- | --- |
| RC1 | 对调 `evolve` / `settlement` 顺序 | 旧断言应红 | ❌ **全绿** ⇒ 证明原断言空转（这就是缺陷⑬ 的发现方式） |
| RC2 | 注释掉 `_snapshot_prices` | 快照一致性断言应红 | ✅ **5 条红**，含核心契约「快照逐条 == price_of」（`期望 <0>，实际 <35>`） |
| RC3 | 把 `if now and not was` 改成 `if now`（边沿→电平） | 「危机中不重复写事件」应红 | ✅ **恰好 1 条红**，且正是该条 |

⇒ **新契约（快照一致性 + 危机边沿）都经反向控制确认「有牙齿」**，不是空转断言。
**做法已沉淀**：写「顺序/边沿/幂等」这类不可见不变量时，**必须反向控制一次**（故意改错、看是否恰好那几条变红）。

### 门禁（四道全过）

| 门 | 结果 |
| --- | --- |
| `bash tools/test.sh` | **EXIT=0**，23 套件 / **3471 断言**（3431 → +40）/ 失败 1（`probe` 故意失败）；`economy` **1041** |
| `stderr` 噪声 | `^SCRIPT ERROR` = **2**、`^ERROR:` = **7** —— 与基线逐字一致 |
| `timeout 300 bash tools/b1_acceptance.sh` | **EXIT=0**，151 断言 / 失败 0，配置逐字还原 |
| 工作区 + 进程 | 5 文件修改、`.workbuddy/` 未跟踪；godot 进程 **0** |

### 挂账（不阻塞）

- 时段 ⑤ 在 `tick()` 的插入位置已定，但**快照的消费者（面板/PromptBuilder）尚未接线**（Task 7/8）⇒ 缺陷⑬ 的「同源同月」契约目前只有测试在守，Task 7/8 落地后应补一条**跨模块**断言
- `registry.gd` 的 `_SCARCITY_MAX = 1.40` 与 `Economy.MAX_SCARCITY` 仍无一致性断言（Task 11/12）
- K1 / K5 仍为默认接受、可回退

- [x] Task 3: `Money` 负值语义（`is_debt` / `debt_formatted` / `formatted` 分支）
- [x] Task 4: 4 个新 op（存/取/汇/贸）+ OpGuard 钳制 + 缺陷⑧（local_mult 口径 + 货值闸门）
- [x] Task 5: 月度结算（工资 / 开销 / 利息）+ `jobs` 表 + 缺陷⑨⑩⑪⑫
- [x] Task 6: `tick()` 接线（`evolve` + `monthly_settlement` + 危机边沿）+ 缺陷⑬
- [x] Task 7: 面板【财富】含存款 + 新增【经济】行
- [x] Task 8: `state_digest` 经济摘要（信息保护）
- [ ] Task 9: 离线替身接线（关键词 → 经济 op）
- [ ] Task 10: 经济类传闻内容
- [ ] Task 11: B1 经济可观测契约
- [ ] Task 12: 收尾（全绿 / 台账 / 文档 / 合入 `main`）

---

## Task 7：面板 —— 【财富】含存款 + 新增【经济】行

**状态：完成**（2026-09-21）

### 交付内容

| 文件 | 变更 |
| --- | --- |
| `src/ui/panel_formatter.gd` | 抽出 `_wealth_line(world)` / `_economy_line(world)` 两个静态函数；`player_panel()` 的【财富】行改为调 `_wealth_line()`，其后**插入【经济】行** |
| `tests/panel_test.gd` | +11 断言（存款括号两向 / 经济行四段 / 负号路径 / 零收支特判 / 债务形态） |

### 实现契约

- **【财富】**：`"【财富】%s" % Money.from_knuts(p.money_knuts).formatted()`；
  `gringotts_balance != 0` 时追加 `（含古灵阁 %s）` —— **余额为 0 不追加**（避免开局多一个恒 0 括号）。
- **【经济】**：`景气 %.2f ｜ 存款月息 %.2f%% ｜ 汇率 %.2f ｜ 本月 %s`；
  月息 = `gringotts_interest_rate * 100`（0.002 → `0.20%`）；汇率两位小数。
- **本月净收支**：`net = last_month_income - last_month_expense`；
  `>0` 带 `+`、`<0` 带 `-`（**先取负再格式化**）、`==0` 写「无收支」。
  ⚠️ 负值分支**不得**直接把负数交给 `Money.formatted()` —— Task 3 之后它会输出「负债 X」，
  与「本月 -X」语义重复（spec §7.6）。已用 `is_false(contains("负债"))` 钉死。
- `power_panel()` 的「财政」指标**保持不变**（仍读 `economy_index`，`panel_formatter.gd:116` 原行号）。

### 与 plan 的三处实况偏差（照抄示例会编译失败）

| # | plan 原文 | 实况 | 处置 |
| --- | --- | --- | --- |
| 1 | 示例用 `Money.new(balance)` / `Money.new(net)` | **`Money` 没有接收参数的构造**（无 `_init`），`Money.new(int)` 直接 Parse Error | 改用 **`Money.from_knuts(n)`** |
| 2 | 期望 `"本月 +1西可"`（假定 0 值单位省略） | `Money.formatted()` **三位全写（含 0）**；「0 单位省略」是 `debt_formatted()` 的行为 | 断言改为 `"本月 +0加隆 1西可 12纳特"`（29 纳特） |
| 3 | 测试片段用 `_panel(w)` 辅助函数 | `tests/panel_test.gd` **没有** `_panel`；既有风格是直接 `PanelFormatter.player_panel(w)` | 按实况写法 |

⇒ **元教训（与缺陷⑬ 同族）**：plan 的示例代码是**示意**不是**可编译契约**。
后续任务（Task 8~）照抄前**必须先核对真实 API**（`grep` 一下签名），否则会浪费一轮「编译失败 → 定位」。
本任务实测代价：2 轮编译失败 + 1 轮断言值错误。

### 我自己的测试 bug（1 个，如实记录）

| # | 症状 | 原因 |
| --- | --- | --- |
| t6 | 断言 `"含古灵阁 12加隆 3西可 4纳特"` 红 | 我手算 `12*493 + 3*29 + 4` 时把 `3*29+4=91` 纳特当成了「3西可 4纳特」，实际 91 纳特 = **5西可 6纳特**（17 纳特/西可）。教训：**断言里的钱数一律写成裸纳特表达式**（`12 * 493`），不要手算进位 |

### 门禁（四道全过）

| 门 | 结果 |
| --- | --- |
| `bash tools/test.sh` | **EXIT=0**，23 套件 / **3482 断言**（3471 → +11）/ 失败 0；`panel` **113**（102 → +11） |
| `stderr` 噪声 | `^SCRIPT ERROR` = **2**、`^ERROR:` = **7** —— **与基线逐字一致** |
| `timeout 300 bash tools/b1_acceptance.sh` | **EXIT=0**，151 断言 / 失败 0，配置逐字还原 |
| 工作区 + 进程 | 2 个已跟踪文件修改、`.workbuddy/` 未跟踪 |

### 挂账（不阻塞）

- 缺陷⑬ 的「快照同源同月」契约：本任务的面板**读的是活算 `price_of`（或快照优先）**，
  与结算同源 —— **Task 8 落地后应补一条跨模块断言**（面板价 == 结算价，同回合）
- `registry.gd` 的 `_SCARCITY_MAX = 1.40` 与 `Economy.MAX_SCARCITY` 仍无一致性断言（Task 11/12）
- K1（`Money` 负值形态）与 K5（`scarcity_mult` 口径 A）仍为**默认接受、可回退**

- **下一步**：Task 8（`PromptBuilder.state_digest` 经济摘要，信息保护）

---

## Task 8：`state_digest` 经济摘要（信息保护）

**状态：完成**（2026-09-21）

### 交付内容

| 文件 | 变更 |
| --- | --- |
| `src/gm/prompt_builder.gd` | 新增 `_economy_digest(world)` / `_good_label()` / `_first_supply_critical()`；`state_digest()` 加 `economy` 字符串键；常量 `_DIGEST_PRICE_GOODS` |
| `tests/prompt_test.gd` | 38 → **54** 断言（+16）；键集合断言同步为 10 键 |

### 实现契约

- **键形态**：比照 03a 的 `government` / `known_factions` —— 用**一个字符串键** `economy` 承载可读行，
  **不重构既有键集合**（计划 02 spec §6.5 的契约）。
- **格式**：`经济：景气 0.61（平稳）｜ 现金 X ｜ 古灵阁 Y ｜ 主要物价：房租（月）Z、黄油啤酒 W`
- **主要物价**：固定两条（`svc_rent` + `food_butterbeer`）**外加一条** `supply_critical` 商品
  （取内容表内第一条 ⇒ 摘要确定）。
- **信息保护（spec §10 第 1 条）**：`illegal` 商品的**商品名与价格永不进提示词**；
  只在黑市（`black_market`）已揭示时追加「黑市有售」四字。

### ⚠️ 缺陷⑭：我第一版断言是**空转的**（反向控制抓出来）

- **原断言**：`a.is_false(before.contains("禁售神奇生物"))` 等三条 —— 钉的是「商品名不出现」。
- **RC1（拆掉黑市门，无条件加「黑市有售」）**：`prompt` 52 断言 **全绿** ⇒ **证明断言无判别力**。
- **根因**：我的实现**从设计上就不把 illegal 商品名写进摘要**，所以「拆掉黑市门」也测不出商品名。
  断言钉错了对象 —— 那条门真正控制的是**「黑市」二字本身**。
- **修正**：断言改钉 `is_false(before.contains("黑市"))` + `is_true(after.contains("黑市有售"))`。
- **重跑 RC1**：**恰好 1 条红**（「未揭示时摘要不提黑市」）✅ 有判别力。
- **元教训（与 Task 6 缺陷⑬ 同族，第二次现身）**：
  写「信息保护 / 幂等 / 边沿」这类**不可见不变量**的断言时，**必须反向控制一次**；
  否则会出现「断言绿、但拆掉实现也绿」的空转。**本任务实测：第一版就是空转的。**

### 反向控制验证（2 组）

| # | 故意破坏 | 期望 | 实测 |
| --- | --- | --- | --- |
| RC1 | 拆掉黑市揭示门（无条件加提示） | 信息保护断言应红 | ✅ **恰好 1 条红**（修正后） |
| RC2 | 危机态恒为「平稳」（拆掉 `Economy.is_crisis` 判定） | 危机断言应红 | ✅ **恰好 1 条红**（「economy_index 低于阈值时标为危机」） |

### 与 plan 的实况偏差

| # | plan 原文 | 实况 | 处置 |
| --- | --- | --- | --- |
| 1 | 测试片段 `d.contains("经济")` / `d.contains("景气")` | `state_digest()` 返回 **Dictionary**，`contains()` 是 String 方法 → 直接编译失败 | 改用 `str(digest.get("economy",""))` 后比对 |
| 2 | 「房租 + 食物 + 一件 `supply_critical` 商品」 | 实际 goods 表里 `supply_critical` 有 **6 条**，需定**确定性取法**（取表内第一条） | 已按「表内首条」实现，保证摘要确定 |

### 门禁（四道全过）

| 门 | 结果 |
| --- | --- |
| `bash tools/test.sh` | **EXIT=0**，23 套件 / **3484 断言**（3482 → +16，含迁出的 2 处键集合）/ 失败 0；`prompt` **54** |
| `stderr` 噪声 | `^SCRIPT ERROR` = **2**、`^ERROR:` = **7** —— 与基线逐字一致 |
| `timeout 300 bash tools/b1_acceptance.sh` | **EXIT=0**，151 断言 / 失败 0，配置逐字还原 |
| 工作区 + 进程 | 2 文件修改、`.workbuddy/` 未跟踪 |

### 挂账（不阻塞）

- 缺陷⑬ 的「快照同源同月」跨模块断言：本任务摘要用的是**活算 `Economy.price_of`**，
  与结算同源 —— 与面板（Task 7）合计，**两条消费者路径都已覆盖**；跨模块断言可在 Task 12 一并补
- `registry.gd` 的 `_SCARCITY_MAX = 1.40` 与 `Economy.MAX_SCARCITY` 仍无一致性断言（Task 11/12）
- K1 / K5 仍为默认接受、可回退

- **下一步**：Task 9（离线替身接线：关键词 → 经济 op）
