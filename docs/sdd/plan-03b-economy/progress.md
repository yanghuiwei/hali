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
- [x] Task 3: `Money` 负值语义（`is_debt` / `debt_formatted` / `formatted` 分支）
- [ ] Task 4: 4 个新 op（存/取/汇/贸）+ OpGuard 钳制
- [ ] Task 4: 4 个新 op + OpGuard
- [ ] Task 5: 月度结算（工资 / 开销 / 利息）
- [ ] Task 6: `tick()` 接线（`evolve` + `monthly_settlement` + 危机边沿）
- [ ] Task 7: 面板【财富】含存款 + 新增【经济】行
- [ ] Task 8: `state_digest` 经济摘要（信息保护）
- [ ] Task 9: 离线替身接线（关键词 → 经济 op）
- [ ] Task 10: 经济类传闻内容
- [ ] Task 11: B1 经济可观测契约
- [ ] Task 12: 收尾（全绿 / 台账 / 文档 / 合入 `main`）
