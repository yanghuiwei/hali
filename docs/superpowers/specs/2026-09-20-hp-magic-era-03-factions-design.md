# 计划 03a · 派系与政治骨架 设计（Spec）

> 状态：**待用户评审**
> 日期：2026-09-20
> 依据：计划 01（核心模拟地基）与计划 02（LLM 叙事引擎）均已完成并合入 `main`（`685af4b`）；`GameMaster`/`StateOps`/`WorldState`/`TurnEngine`/`SelfCheck`/存读档/B1 自动验收均已就位。
> 范围拆解：用户已于 2026-09-20 裁定「派系与政治经济」过大，拆为 **03a 政治与派系骨架（本 spec）→ 03b 经济骨架 → 03c 社会与法律**。本 spec 只做 03a。
> 目标读者：零上下文的实现者。实现计划见后续 `docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md`（由 writing-plans 产出）。

---

## 1. 目标

把「势力」从**占位符**变成**可玩、可演化、可调查**的系统：

- 当前 `WorldState.factions` 是**空字典**（全仓无写入者），`PlayerState.faction_id` 是**无内容表的裸字符串**，`power_panel` 10 个指标里 6 个恒为「待定/未知」，且 7 个标签被硬映射到 4 个 `world_vars`（`HANDOFF §8#7`）。
- 本计划交付：**派系实体（内容表）→ 机构控制权 → 权力四角 → 政体推导 → 月度演化 → 社会矛盾与政治事件 → 玩家所属/立场/加入 → 势力面板落地 → 信息保护（不剧透）**。
- 一切数值变化仍走既有骨架：随机走 `RngService` 命名流、状态变更走 `StateOps`、持久化走 `WorldState.to_dict()`；**不新增第二套状态机**，不给 LLM 直达通道。

## 2. 非目标（本计划刻意不做）

- **经济**（物价/工资/产业/古灵阁/贸易/走私/危机）：属 03b。本计划只在面板与事件文案里**引用**既有 `Money` 与 `economy_index`，不新增经济规则。
- **完整家族系统**（家谱、继承、联姻、家族魔法、家族内部斗争）：属 03c（正典第十三章）。本计划只把「纯血家族」作为**派系的一个 `kind`**（有 power/控制权/立场），不做家谱。
- **协会体系**（第十九章 8 个协会的会长/分部/行业规则）：属 03c。
- **法律与审判**（威森加摩开庭、阿兹卡班刑期、剥夺魔杖）：属 03c。本计划只让「威森加摩」作为一个机构的**控制权**存在。
- **NPC 自主系统**（第四十二章：NPC 会升迁/被捕/背叛）：属 05。本计划只在 NPC 字典上留一个 `faction_id` 字段与接口，不做 NPC 生命周期。
- **多世代/世界记忆**（第六十六/六十七章）：属 06。
- 不做派系外交的**交互式谈判 UI**；玩家行为通过既有两条通道表达（自然语言命令 → ops；未来 UI 按钮）。
- 不修改 `TurnEngine`/`GameMaster`/`LlmGameMaster` 的契约（只在 `OpGuard` 白名单与 `StateOps` 增加新 op）。
- **不新增 `world_vars` 键**（理由见 §3 D3）：零 `data/eras.json` 改动、零存档迁移。

## 3. 已确认决策

| 编号 | 决策 | 理由 / 备注 |
| --- | --- | --- |
| **D1** | 新增内容表 `data/factions.json`（新表，必须注册进 `Registry.TABLE_FILES`），字段见 §7.1。覆盖正典第六章九大支柱里的政治主体：魔法部（含法律执行司/傲罗指挥部/威森加摩/神秘事务司四个**机构**）、霍格沃茨、纯血家族（3–4 个代表）、古灵阁与商业、《预言家日报》、凤凰社、食死徒/黑暗势力、国际巫师联合会。规模 14–18 个，`era_overrides` 表达时代差异。 | 铁律：内容进 `data/`，代码不硬编码内容。数量取「够用且能讲清权力四角」的最小集合；正典第十三章的具体家族名不进表（属 03c），只有代表性的 3–4 个纯血家族派系。 |
| **D2** | 新增内容表 `data/governments.json`（第十一章四大政体：官僚制 / 纯血寡头制 / 食死徒独裁 / 凤凰社抵抗）。**政体名与说明是内容，判定规则是代码**。 | 政体要在叙事与面板里出现中文名，按铁律必须进 data。 |
| **D3** | **`world_vars` 保持 7 键不变**；第六十五章面板的「机构级」指标（法律执行 / 傲罗 / 威森加摩 / 国际）改为**从派系的机构控制权派生**，标量级指标（财政 / 稳定度 / 腐败度 / 纯血影响 / 麻瓜关系）继续来自 `world_vars`。**这修掉 `§8#7`。** | 7 标签→4 变量之所以是 bug，根源是「机构」被硬塞进「世界标量」。机构控制权本来就该是实体属性（第十二章权力四角 + 第二十六章魔法部体系）。保持 7 键 ⇒ 8 个时代的 `data/eras.json` 与所有旧存档都不需要迁移。 |
| **D4** | `WorldState.factions` 正式启用，结构：`factions[faction_id] = {"power": float(0..1), "control": {机构id: float(0..1)}, "stance_to_player": int(-100..100), "revealed": bool, "last_change_turn": int, "notes": [String]}`（见 §7.2）。**字段已在存档白名单里**（`src/persist/save_codec.gd` 的 `dict_fields` 已含 `factions`），因此存档格式**不变**。 | 占位符变实；避免动存档格式（`§8#9/#19/#26/#49` 的存档 v2 议题不塞进本计划）。 |
| **D5** | 派系实力分两层：`power`（对外总体实力 0..1）与 `control`（对具体`机构`的控制权 0..1）。`power_share()` 给出**权力四角**（魔法部/纯血家族/霍格沃茨/商业）的归一化权重；`government_type()` 由「魔法部实力 + 战争压力 + 抵抗组织实力（+ 黑暗势力对执法/司法的机构控制权）」推导（口径见 §7.4 勘误），结果缓存进 `world.flags["government_type"]`（tick 刷新，叙事与面板只读缓存）。 | 第十二章「不同时期权重不同」= 归一化权重随 tick 演化；第十一章四政体是**格局的函数**，不该是独立状态。缓存进 flags 是为了「叙事读到的是本回合的真实政体」且随存档一致。 |
| **D6** | 玩家侧：`PlayerState.faction_id` 保留为主所属（可为空）；新增 `PlayerState.standing: Dictionary`（`faction_id -> int(-100..100)`，含义：支持/反对的立场强度）。新增三个 op：`join_faction` / `leave_faction` / `faction_standing_delta`（见 §7.3）。 | 正典第五十章「可以支持凤凰社、加入食死徒、反对魔法部」= standing（支持/反对）+ membership（加入）两件事。`standing` 需加入 `PlayerState.to_dict/from_dict` **与** `SaveCodec` 的类型校验清单（见 §11）。 |
| **D7** | 信息保护（第四十三/五十七章）：派系有 `revealed` 位。**未 revealed 的派系不进玩家可见文本**（面板显示为「未知势力」，事件文案只给来源与传闻口吻）。揭示途径：`know_fact`（既有 op，必须带非 `system` 来源）或 tick 产出的事件把 `revealed` 置真。 | 第五十七章明令「玩家不能自动知道哪个 NPC 是食死徒」；既有 `SelfCheck` 已有「世界信息保护」检查项，本决策让它有真实数据可查。 |
| **D8** | 演化在 `WorldState.tick()` 内**追加阶段**，不改既有阶段语义（世界变量回归 / 传闻事件 / 生活基线 / 年龄 / 日志裁剪全部保持原样与原来顺序）。新增阶段一律用 `RngService.new(game_seed + clock.turn * <素数>)` + 命名流，保证同 seed 可复现。 | 第四十七章月度演化 + 计划 01 的确定性铁律。新阶段的插入位置见 §9。 |
| **D9** | 社会矛盾与政治事件：由 `corruption` / `pureblood_influence` / `muggle_relations` / `war_pressure` 与派系 `power` 差推出 `tension`（0..1），越过阈值才可能触发**改革运动 / 政变 / 越狱 / 金融危机 / 镇压**等事件；事件走既有 `events` + `log` + `add_fact("major")` 通道，并继续受 `MAJOR_EVENT_GAP` 与概率门约束（第六十八章防过度热闹）。 | 复用既有通道 = 面板/叙事/存档三处零改动就可见；不新建事件系统。 |
| **D10** | 面板：`PanelFormatter.power_panel()` 重写，保持正典第六十五章的**三行**结构（魔法部状态 / 霍格沃茨 / 家族），**新增一行【已知势力】**（列 revealed 派系的 power、玩家立场、所属标记）。字体/文案沿用现有风格（`%.2f` 数值 + 中文标签）。 | 「已知势力」一行超出第六十五章字面，但符合第四十三章（信息由身份/地点/人脉决定）与第五十章（玩家可以支持/反对/加入）。**这是一处需要你点头的扩展。** |
| **D11** | 顺手项（`NEXT-STEPS §C` 裁定「不单开批次，留给计划 03」）：`§8#61`（降级原因进 `op_errors`，1 行）、`§8#64`（测试可判别性 3 条）、`§8#65`（契约文档 + 鸭子类型判定）、`§8#58`（UI 等待期超时/取消）、`§8#62`（UI 提交失败恢复：唯一出口）、`§8#63`（provider 泄漏 `HTTPRequest` + `timeout` 只生效一次）、`§8#69`（哑炮却有学院）、`§8#70`（创建界面姓名/性别）、`§8#16`/`§8#21`（`rumors.weight` / `wand_cores.rarity` 声明未生效）。 | 前 8 条用户已裁定随 03 处理；`#16/#21` 由计划 02 spec §15 与本 spec 一起收口（加权抽取是 10 行规则层改动 + 测试）。这些**不占主线任务**，作为独立小任务排在主线之后。 |
| **D12** | 玩家成为派系成员/领袖的路径：本计划只做**成员**（`faction_id` + `standing`），**不做领袖/夺权**（正典第四十九章「阶层流动」与「革命系统」留给后续，本计划只把 `tension` 与改革运动事件做出来）。 | YAGNI：夺权需要 NPC 组织度、选举/政变流程、法律后果（属 03c），先让「支持/反对/加入」跑通。 |

### 请你裁定（4 条，可以在评审时一次性回答）

| 编号 | 问题 | 我的建议 |
| --- | --- | --- |
| Q1 | 派系表要不要包含**国际**实体（国际巫师联合会、外国魔法部）？ | **要**（1–2 个即可，用 `era_overrides` 与 `kind:"foreign"` 表达）。否则正典第六/八/二十六章的「国际」维度没有落点，面板「国际」指标只能造假。 |
| Q2 | 面板新增【已知势力】一行，接受吗？ | **接受**（见 D10）。 |
| Q3 | 玩家能「加入」的派系是否要限制作恶类（食死徒）？ | **不限制**，但加入 `legality:"outlaw"` 派系要产生**代价**（法律风险计数 + 关系恶化；具体后果按 03c 裁定，本计划只记录 `flags["illegal_affiliation"]`）。正典第五十章明确允许「加入食死徒」。 |
| Q4 | 是否要在本计划就把 `world.factions` 暴露给 LLM 提示词（`PromptBuilder.state_digest`）？ | **要**，但只暴露 revealed 部分 + 权力四角权重（防止 LLM 剧透未揭示派系，第四十三/五十七章）。 |

## 4. 正典依据（行号指 `哈利·波特·魔法纪元.md`）

| 行 | 章节 | 本计划用到什么 |
| --- | --- | --- |
| 93 | 第六章 九大文明支柱 | 派系表覆盖第 2/3/5/7/8 根（魔法部 / 纯血家族 / 商业 / 黑暗势力 / 国际） |
| 158 | 第十一章 政体系统（四大主流政体） | `governments.json` 四个政体 + 判定规则 |
| 172 | 第十二章 权力四角 | 魔法部 / 纯血家族 / 霍格沃茨 / 古灵阁与商业的权重 |
| 182 | 第十三章 纯血家族制度 | 纯血家族作为派系 `kind:"pureblood"`（家谱留 03c） |
| 190 | 第十四章 傲罗与凤凰社系统 | 傲罗指挥部/凤凰社两个势力，`legality` 区分 |
| 209 / 219 / 227 | 第十七/十八/十九章 经济·货币·协会 | 本计划只引用（面板财政指标、事件文案），规则留 03b/03c |
| 329 | 第二十六章 魔法部体系 | 四个机构（法律执行司 / 傲罗指挥部 / 威森加摩 / 神秘事务司）作为 `control` 键 |
| 483 | 第四十二章 NPC 自主系统 | 只在 NPC 字典留 `faction_id` 接口 |
| 495 | 第四十三章 信息系统 | 「来源 + 可信度」：事件只给来源；派系 `revealed` |
| 527 | 第四十六章 世界级事件 | 政变 / 越狱 / 金融危机 / 霍格沃茨沦陷 的触发条件 |
| 531 | 第四十七章 月度世界演化 | tick 新阶段的合法性 |
| 541 | 第四十九章 社会阶层与流动 | `tension` 与改革运动（领袖/夺权留后续） |
| 553 | 第五十章 玩家人生目标 | 「支持 / 反对 / 加入」= `standing` + `faction_id` |
| 601 | 第五十七章 世界信息保护 | 未揭示派系不得进玩家可见文本 |
| 668 | 第六十五章 魔法部/学院/家族面板 | 面板字段清单（10 指标 + 三行结构） |
| 688 | 第六十八章 防过度热闹协议 | 事件概率门 + `MAJOR_EVENT_GAP` |

## 5. 架构

```
WorldState.tick()  （唯一的世界时间推进入口）
  ├─ (既有) world_vars 向时代基线回归 + 扰动
  ├─ (既有) 传闻筛选（zones / min_year / requires_flags / major gate）
  ├─ (既有) 生活基线 + 年龄 + 日志裁剪
  └─ (新增) WorldFactions.evolve(world)        ← 新增阶段，见 §9
         ├─ ① 派系 power/control 演化（受 world_vars 与 rivals/allies/agenda 影响）
         ├─ ② power_share() → 权力四角权重
         ├─ ③ tension 累计（社会矛盾）
         ├─ ④ 阈值事件（改革运动/政变/越狱/金融危机/镇压）→ events + log + add_fact
         ├─ ⑤ government_type() 推导 → world.flags["government_type"]
         └─ ⑥ 揭示（revealed）判定（第四十三/五十七章）

玩家侧            （既有）StateOps.apply(ops)  ← 唯一变更入口
  └─ (新增 op) join_faction / leave_faction / faction_standing_delta

呈现              （既有）PanelFormatter.power_panel()（重写）· PromptBuilder.state_digest（加 revealed 派系）
```

依赖方向：`src/rules/factions.gd` 只读 `world` + `registry`，**只通过返回值**把变化交给 `tick()` 写回（或由 tick 直接写 `world.factions`，见 §7.2 的约定）；不反向依赖 UI/GM。

## 6. 文件结构

| 文件 | 状态 | 职责 |
| --- | --- | --- |
| `data/factions.json` | 新增 | 派系内容（§7.1 schema） |
| `data/governments.json` | 新增 | 四大政体的 id/label/说明/判定倾向（§7.4 schema） |
| `data/rumors.json` | 修改 | 追加派系相关传闻（带 `zones`/`requires_flags`/`min_year`/`major`），并让 `weight` 真正生效（`§8#16`） |
| `data/wand_cores.json` | 修改 | 让 `rarity` 真正生效（`§8#21`） |
| `src/core/registry.gd` | 修改 | `TABLE_FILES` 注册 `factions` / `governments`；`validate()` 增加两表的字段/引用校验 |
| `src/rules/factions.gd` | 新增（`class_name WorldFactions`） | 派系初始化、机构控制权模型、`power_share()`、`government_type()`、`evolve()`、`reveal()` 查询 |
| `src/model/player_state.gd` | 修改 | `standing` 字段 + `to_dict/from_dict` |
| `src/model/world_state.gd` | 修改 | `tick()` 追加演化阶段；`create()` 里初始化派系 |
| `src/rules/state_ops.gd` | 修改 | 三个新 op（`join_faction`/`leave_faction`/`faction_standing_delta`） |
| `src/gm/op_guard.gd` | 修改 | 新 op 的白名单/钳制（LLM 只能动 `standing` 与 membership，**不能**动 `power/control/revealed`） |
| `src/ui/panel_formatter.gd` | 修改 | `power_panel()` 重写（第六十五章 10 指标 + 【已知势力】） |
| `src/gm/prompt_builder.gd` | 修改 | `state_digest` 增加 revealed 派系摘要（Q4） |
| `src/persist/save_codec.gd` | 修改 | `standing` 的类型校验清单（不改存档格式/版本） |
| `tests/factions_test.gd` | 新增 | 派系规则/演化/政体推导（必须加进 `run_tests.gd` 的 `SUITES`） |
| `tests/panel_test.gd` | 修改 | 势力面板新字段断言 |
| `tests/save_test.gd` | 修改 | `standing` + `factions` 往返一致 |
| `tests/llm_test.gd` / `tests/gm_test.gd` | 修改 | 新 op 的守卫与端到端 |
| `src/ui/main.gd` | 可能修改 | 仅当「加入派系」需要按钮时（默认不加按钮，走自然语言命令） |

## 7. 接口契约

### 7.1 `data/factions.json`（数组）

```json
{
  "id": "ministry",
  "label": "魔法部",
  "kind": "ministry",
  "aliases": ["魔法部", "部里"],
  "legal_status": "legal",
  "secrecy": "public",
  "domains": ["law", "administration", "secrecy_enforcement"],
  "agenda": "维持保密法与巫师社会秩序，压住战争与丑闻",
  "base_power": 0.75,
  "rivals": ["death_eaters"],
  "allies": ["auror_office"],
  "institutions": ["law_enforcement", "auror_office", "wizengamot", "mysteries"],
  "era_overrides": {"first_wizarding_war": {"base_power": 0.55}, "second_wizarding_war": {"base_power": 0.45}}
}
```

- `kind` 取值（枚举，代码侧白名单）：`ministry` / `institution` / `pureblood` / `school` / `commerce` / `media` / `resistance` / `dark` / `foreign`。
- `legal_status`：`legal` / `shadow` / `outlaw`（Q3 用它决定加入代价）。
- `secrecy`：`public` / `semi` / `secret`（初始 `revealed` 由它决定：`public` → true，其余 → false）。
- `institutions`：该派系可控制的机构 id 列表；机构 id 是**固定枚举**（代码侧常量，因为面板要按名字取）：
  `law_enforcement`（法律执行）/ `auror_office`（傲罗）/ `wizengamot`（威森加摩）/ `mysteries`（神秘事务司）/ `hogwarts`（霍格沃茨）/ `gringotts`（古灵阁）/ `daily_prophet`（预言家日报）/ `international`（国际）。
- `base_power`：0..1；时代覆盖用它。
- `rivals` / `allies`：**必须**引用本表存在的 id（`Registry.validate()` 校验；空表也要能过）。

### 7.2 `WorldFactions`（`src/rules/factions.gd`，`class_name WorldFactions extends RefCounted`）

```gdscript
const INSTITUTIONS: Array[String] = ["law_enforcement", "auror_office", "wizengamot", "mysteries",
	"hogwarts", "gringotts", "daily_prophet", "international"]

# 初始化：按 era + 玩家身份建立 world.factions（create() 与 from_dict() 后都需要能补齐）
static func initialize(world: WorldState) -> void

# 权力四角：{"ministry": f, "pureblood": f, "hogwarts": f, "commerce": f}（归一化到和为 1）
# kind → 四角的映射（第十二章）：ministry/institution → ministry；pureblood → pureblood；
# school → hogwarts；commerce/media/foreign/resistance/dark → 不进四角（dark 只体现在 control 与政体判定）
static func power_share(world: WorldState) -> Dictionary

# 政体推导：返回 governments.json 的 id（见 §7.4 规则）
static func government_type(world: WorldState) -> String

# 机构控制权：{机构 id: {"value": float(0..1), "holder": 派系 id}}
# 归并规则：value 取各派系在该机构 control 的**最大值**；holder 为取到最大值的派系（平局取 power 高者）。
# 只包含 INSTITUTIONS 里列出的机构键（无任何派系声明该机构的 control 时，value=0.0、holder=""）。
static func institution_control(world: WorldState) -> Dictionary

# 单回合演化：就地更新 world.factions / world.flags / world_vars，返回事件数组（结构与 tick 的 events 一致）
static func evolve(world: WorldState) -> Array

# 信息保护：玩家当前可见的派系 id 列表（revealed == true 且满足 requires）
static func visible_faction_ids(world: WorldState) -> PackedStringArray

# 揭示：把派系标记为已知，并写一条 history（来源由调用方给，禁止空来源）
static func reveal(world: WorldState, faction_id: String, source: String) -> bool
```

`world.factions[faction_id]` 结构（D4）：

```gdscript
{"power": 0.75,                       # 0..1
 "control": {"law_enforcement": 0.6}, # 机构 id -> 0..1（只对 institutions 里列出的键赋值）
 "stance_to_player": 0,               # -100..100（派系怎么看玩家）
 "revealed": true, "last_change_turn": 3, "notes": []}
```

**约定**：`evolve()` 通过返回事件 + 直接写 `world.factions` / `world.flags` 生效（与 `WorldState.tick()` 的既有风格一致：tick 自己就是就地写）；但**所有随机数必须来自 `RngService`**，不得用 `randf()`。

### 7.3 新增 ops（`StateOps`）

| op | 载荷 | 语义与校验 |
| --- | --- | --- |
| `join_faction` | `{"op":"join_faction","faction_id":str}` | 校验：id 存在、`visible`（未揭示的派系不能加入）、玩家无其他所属（或允许改换：先 leave 再 join）。成功：`player.faction_id = id`；若 `legal_status=="outlaw"` 则 `world.flags["illegal_affiliation"] = id` 并给一条 `op_errors` **警告**（不是错误）。 |
| `leave_faction` | `{"op":"leave_faction"}` | 清空 `player.faction_id`（`standing` 保留）。 |
| `faction_standing_delta` | `{"op":"faction_standing_delta","faction_id":str,"delta":int}` | 校验 id 存在；`delta` 由 `OpGuard` 钳到 `[-20, 20]`；结果钳到 `[-100, 100]`。同时反向影响 `faction.stance_to_player`（幅度取 `delta//2`，钳制同上）。 |

`OpGuard`：三个 op **允许**（LLM 可以让玩家支持/反对/加入）但不允许任何能改 `power`/`control`/`revealed` 的载荷（不存在这样的 op，因此只需在 `OpGuard` 里**拒绝**任何 `set_faction_*` 形态的未知 op——沿用既有「未知 op 一律拒绝」策略即可）。

### 7.4 `data/governments.json` 与政体判定

```json
{"id": "ministry_bureaucracy", "label": "魔法部官僚制",
 "summary": "部长、司长、办公室主任、傲罗指挥部、威森加摩；法律与行政结合。",
 "canon_line": 160}
```

判定规则（代码，第十一章 + 第十二章）。**下面第 1/3 条的口径是权威版本**（2026-09-20 人类裁定 (a) 的措辞勘误，见本节末）：

1. `order_resistance`：`world_vars.war_pressure >= 0.6` 且 `power_of("order_of_phoenix") > power_of("ministry")` → **凤凰社抵抗组织**（影子政府）。
2. `death_eater_dictatorship`：`dark` 类派系对 `law_enforcement` + `wizengamot` 的**自身 `control` 均值** `>= 0.6`（未声明该机构时按 0 计）→ **食死徒独裁**。
3. `pureblood_oligarchy`：`pureblood` 类派系 `power_share` 合计 `>= 0.28` 且 `power_of("ministry") < 0.5` → **纯血寡头制**。
4. 否则 `ministry_bureaucracy`。

优先级按 1→4 短路。结果写入 `world.flags["government_type"]`。

### ⚠️ 勘误（2026-09-20，人类裁定 (a)，Task 2 审查 Important 1）

本节原措辞写的是「魔法部**控制权** `< 0.4` / `< 0.5`」，且规则 1 多了一个「凤凰社 power 最高」的条件。**实现口径（= 计划 = brief = 构造用例）用的是「魔法部实力 `power_of("ministry")`」**，理由：

- **规则 1 的两条件版才对应正典**：第十一章第 4 条说凤凰社「战争时期**可能成为影子政府**」，可操作化的判据是「抵抗组织的实力超过魔法部」，而不是「凤凰社在 17 个派系中实力最高」——后者按字面**几乎不可达**（凤凰社 `base_power` 只有 0.10–0.35），与 §13.2 里 0.45 那处属于同一类笔误。
- **「魔法部弱」用实力而非机构控制权**：`control` 是**谁在渗透哪个机构**（可被食死徒抬到 0.7 而魔法部自身实力不变），用它当「魔法部弱」的判据会让政体在「食死徒刚渗透执法司但魔法部仍然强势」时过早滑向寡头制。机构控制权的正确用法是规则 2（独裁：黑暗势力**真的**掌握了执法与司法）。
- 口径经构造用例钉住：寡头制用例（纯血 0.9/0.9、魔法部 power 0.30）命中规则 3；抵抗组织用例（战时 + 抵抗 0.95 > 魔法部 0.75）命中规则 1 并短路。**代码与测试一行未改**，本节措辞已改为权威版本。
- 余量数据（供后续调参）：抵抗格局下纯血占比 = 0.27994（比 0.28 低 6e-5），因规则 1 先短路而无害；寡头格局 0.3010（余量 0.021）。阈值仍属「首版拍数」（§13.2）。
- 规则 2 的「未声明按 0 计」补在 Task 4（Task 2 审查 Minor 1 的收口项）：Task 2 实现曾用「回退到全局归并持有值」，与 `institution_control()` 的「未声明=不参与」语义自相矛盾。

## 8. 数据流（单回合，含新增阶段）

```text
玩家指令 → TurnEngine.submit_async
  → GameMaster（LLM 或替身）产出 {narration, ops, warnings}
  → StateOps.apply(ops)            # 新 op 在这里落地
  → WorldState.tick():
       [既有] ① world_vars 回归/扰动    ② 传闻事件    ③ 生活基线    ④ 年龄    ⑤ 日志裁剪
       [新增] ⑥ WorldFactions.evolve()  → 事件并入本回合 events（与传闻事件同一数组返回给 UI）
  → PanelFormatter 输出（含重写后的势力面板）
```

顺序上，**演化排在传闻之后、日志裁剪之前**（裁剪要能裁到新事件）；`events` 的合并顺序 = 传闻在前、派系事件在后。

## 9. 确定性与存读档

1. **随机**：新增阶段使用 `RngService.new(world.game_seed + world.clock.turn * 31337)`，命名流 `faction_<faction_id>` / `tension` / `political_event`。同 seed + 同回合 ⇒ 同结果（`factions_test` 用双世界对比断言）。
2. **存档**：`world.factions` 已在 `save_codec.gd` 的 `dict_fields` 里；`player.standing` 需要补进 `PlayerState.to_dict/from_dict` **与** `SaveCodec._validate_payload` 的字典字段清单。存档 `save_version` **不变**（1）。
3. **旧档兼容**：`from_dict` 后若 `world.factions` 为空（老存档）→ 由 `WorldState.from_dict()` 自己调用 `WorldFactions.initialize(world)` 补齐（见 §9.5，幂等）；`player.standing` 缺失 → 空字典。
4. **确定性反证要求**：`factions_test` 必须包含至少 1 条「删掉某个演化步骤 → 断言变红」的反证说明（沿用既有做法：在报告里贴出反证实验的输出）。
5. **补齐调用点（不得模棱两可）**：`WorldState.create()` 与 `WorldState.from_dict()` 在返回前都调用 `WorldFactions.initialize(world)`（幂等：已有条目一律不动）。这样「创建后立刻开面板」与「老存档读档后」两条路径都拿到完整派系状态，不依赖「必须先 tick 一次」。
6. **社会矛盾存哪**：`tension` 不入 `world_vars`（D3），存 `world.flags["social_tension"]`（float 0..1，`JsonUtil.normalize` 会把它归一为合规类型）；`flags` 本来就在存档里，无需改格式。

## 10. 信息保护与防作弊

1. 玩家可见文本（面板、叙事、事件）**不得**出现 `revealed == false` 的派系 label；未揭示时统一用「未知势力」占位。
2. `WorldFactions.reveal()` 必须带**非空 source**，且 source 不得是 `system`（与 `StateOps.know_fact` 的既有约束一致，第四十三/五十七章）。
3. `tick()` 产出的政治事件文案必须带来源口吻（「《预言家日报》称…」「破釜酒吧传闻…」），不得写成上帝视角事实。
4. `SelfCheck` 既有四项检查不改；本计划**新增**的只是数据，让「世界信息保护」与「人物行为偏离设定」有真实内容可查（后者仍依赖 `ooc_violation`，见 `§8#42`，不在本计划范围）。

## 11. 测试策略

| 套件 | 新增/修改 | 关键断言 |
| --- | --- | --- |
| `tests/factions_test.gd`（新） | 新增 | ① `factions.json` 每条的 `institutions`/`rivals`/`allies` 引用合法；② `initialize()` 后每个派系都有 power/control/revealed；③ 幂等（跑两次不重复）；④ `power_share()` 归一化和为 1；⑤ 四种政体各有一条构造用例（直接摆 power/control 摆出四种格局）；⑥ `evolve()` 确定性（同 seed 双世界逐字段相等）；⑦ `reveal()` 拒绝空来源/`system` 来源；⑧ `tension` 单调性（其它不变时，corruption 越高 tension 不下降）；⑨ `visible_faction_ids()` 不含未揭示派系 |
| `tests/panel_test.gd` | 修改 | 势力面板 10 个指标不再出现「待定/未知」以外的占位错值；未揭示派系不出现；【已知势力】只列 revealed；哑炮/无派系玩家的面板可读 |
| `tests/save_test.gd` | 修改 | 「加入派系 + standing 变化 + 演化 N 回合 → encode/decode → 重建引擎 → 继续 tick」与原时间线逐字段一致；老存档（无 factions/standing）补齐后 `ok=true` |
| `tests/gm_test.gd` / `tests/llm_test.gd` | 修改 | 三个新 op 的守卫（未知 id 拒绝、未揭示派系拒绝加入、`delta` 钳制、outlaw 加入产生警告）、`OpGuard` 对未知 `set_faction_*` 一律拒绝 |
| `tests/registry_test.gd` | 修改 | 新表注册 + `validate()` 对两表的字段校验（缺 `label`、坏引用、坏枚举都要报错） |
| 顺手项套件 | 修改 | `§8#64` 三条可判别性断言（`build_repair` 断言提示词内容、降级叙事断言具体文案、`api_key` 负向断言）；`§8#16/#21` 加权抽取的分布断言（用固定 seed 的多回合统计，阈值放宽到确定可复现） |

**新增套件必须追加到 `tests/run_tests.gd` 的 `SUITES`**（铁律），否则不会被执行。

## 12. 依赖与兼容

- 纯 GDScript + Godot 4.7.2 stable，无新依赖、不联网。
- `TurnEngine` / `GameMaster` / `LlmGameMaster` / UI 异步契约**不变**。
- `world_vars` 键集不变（D3）⇒ `data/eras.json` 不改、旧存档不需迁移。
- `SaveCodec` 字段清单新增 `player.standing`；`factions` 原本就在清单里。
- 内容表新增 2 个文件 ⇒ `Registry.TABLE_FILES` 必须同步，否则 `load_default()` 不会加载（静默失败）。

## 13. 风险与未决

1. **派系数量与「够用」的边界**：14–18 个是本计划的假设；若评审认为太少/太多，改 `data/factions.json` 即可，代码不受影响（枚举校验只需覆盖 `kind` 集）。
2. **政体判定的阈值（0.6/0.28/0.26）是首版拍数**，需要实跑几局观察是否过于频繁/罕见；`factions_test` 用构造用例钉住逻辑，阈值调整只需改常量。
   - ⚠️ **勘误（2026-09-20，人类裁定 A，实现 Task 2 时发现）**：本节原写「纯血寡头制阈值 `0.45`」与「`oligarchy_pressure` 条件里 `power_share >= 0.40`」，两者都是**算错的数**：`power_share()` 是**四角归一化**，魔法部那一角含 4 个机构、商业角含 4 个、霍格沃茨 1 个，任何单角现实上限约 1/3；纯血只有 2 个派系（power ≤ 1.0），两派拉满也只有 **0.3017**。实测：构造用例 0.3010、默认现代格局 0.1627 → 0.45/0.40 在任何合法状态下都**不可达**（该分支等于死代码）。裁定改为 **0.28**（寡头制门限：构造用例命中、默认不命中，两侧余量足）与 **0.26**（`oligarchy_pressure` 条件，仍保留 `or pureblood_influence >= 0.65` 那条内容驱动的路子）。**这是修正 spec 原意的数值笔误，不是语义变更**：语义仍是「纯血在四角中占比显著抬高 → 寡头制」。
3. **面板把机构指标改为派系派生后，数值语义变了**（原来 `war_pressure` 冒充「法律执行」）。这可能让老玩家觉得「数字变小/变得不稳」，但这是修 bug（`§8#7`）的必要代价。
4. **`standing` 与 `reputation` 的关系**未在本计划处理：`PlayerState.reputation` 是全局声望，`standing` 是逐派系立场。若评审希望统一，应在 03b/03c 一并裁定。
5. **事件频率**：新增政治事件与既有传闻事件共用 `MAJOR_EVENT_GAP`，可能挤掉原有传闻（同月最多一起重大事件）。若实跑发现政治事件过于抢戏，需给两套事件分配各自的配额——本计划先用共享配额，实跑后调整。
6. **`§8#58/#62` 的 UI 韧性修复**会碰 `main.gd` 的提交路径（引入「唯一出口」helper），属本计划唯一有回归风险的非派系改动，必须单独一个任务 + 单独审查。

## 14. 后续计划边界

- **03b 经济骨架**：物价/工资/产业（`data/goods.json`、`data/industries.json`）、古灵阁（存款/利息/汇率）、贸易价差与走私、经济危机连锁、`Money` 债务显示格式（`§8#5`）。本计划的 `economy_index` 与「财政」指标是它的输入/输出接口。
- **03c 社会与法律**：纯血家族完整制度（第十三章）、协会体系（第十九章）、法律与审判（第三十五章：威森加摩开庭/阿兹卡班/剥夺魔杖）、傲罗行动与非法施法后果（`§8#28/#29` 一并处理）。
- **04** 神奇生物生态与区域危险度；**05** NPC 自主与信息可信度（本计划留的 `npc.faction_id` 接口在这里接上）；**06** 多世代传承与世界记忆。
- 小计划（与主线无关，随时可插）：设置界面（含 `§8#63` 的 provider 复用）、`§8#9/#19/#26/#49` 的存档格式 v2、流式输出。
