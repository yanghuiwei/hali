# Task 6 报告 · 信息保护（`reveal()` + 传闻揭示 + 派系传闻内容）

- **任务**：计划 03a Task 6（brief：`.superpowers/sdd/2026-09-20-hp-magic-era-03-factions/task-6-brief.md`）
- **提交**：`51a3455`（首轮）+ `537bd68`（修复轮 1，父提交 `51a3455`）；修复轮前的控制器计划提交 `28d3a4d`
- **状态**：DONE（含修复轮 1）

> ⚠️ **更正（首轮报告失实，2026-09-20 修复轮 1）**：首轮 §1 与提交信息都声称「顺手改 1 处错字（过**阀**→过**阈**）」，但**实际上只改对了 2/3 处，第三处（`factions.gd:383`）被我误写成了另一个错字「过**隘**」**（关隘的隘）。这是事实性错误陈述，本任务的门禁结论（审查）一度建立在这些自述之上，已由审查者标为 Important（I1）。修复轮已把该处真正改成「过**阈**」，并额外修掉 `tests/factions_test.gd:497` 的同类残留「死**阀**值」→「死**阈**值」。全仓 `grep -rn "过隘\|过阀\|死阀" src/ tests/` 现为零命中。

---

## 1. 改动 / 新建文件清单

| 文件 | 状态 | 内容 |
| --- | --- | --- |
| `src/rules/factions.gd` | 修改 +36/-4 | 新增 `reveal()`；把 `apply_rumor_reveals()` 的 `pass` 空实现填实；`validate_content()` 增加 `reveals_faction` 引用检查；错字修正见下方 ⚠️ **更正** |
| `src/core/registry.gd` | 修改 +3 | `_validate_entry` 增加 `rumors` 分支：`reveals_faction` 必须是字符串 |
| `data/rumors.json` | 修改 +5/-1 | 追加 4 条派系传闻（`reveals_faction`）；**未新建文件**、既有 16 条一字未改（只给第 16 条补了一个行尾逗号） |
| `tests/factions_test.gd` | 修改 +87 | 信息保护/揭示 12 条（brief）+ 来源可追溯 2 条 + 无效事件 2 条 + 端到端 8 条 |
| `tests/registry_test.gd` | 修改 +23 | brief 的 `reveals_faction` 引用/计数 5 条 + 坏类型/坏引用 2 条 |
| `tests/world_tick_test.gd` | 修改 +2/-2 | 仅错字（过阀→过阈，纯注释文字） |

无新建脚本 ⇒ 无新 `.gd.uid`；`git status --short` 提交后为空。

## 2. 测试原始输出

### 2.1 红步（实现前，`task-6-test-red.log`）

```
[registry] 至少 3 条传闻用于揭示派系（实际 0）: 期望为真
[registry] rumors 表坏类型的 reveals_faction 必须报错: 期望为真
[registry] validate_content 必须拦下 reveals_faction 的坏引用: 期望为真
[registry] 断言=240 失败=3
...
SCRIPT ERROR: Parse Error: Static function "reveal()" not found in base "WorldFactions".
   at: GDScript::reload (res://tests/factions_test.gd:656)
   （同样的 parse error 在 657 / 659 / 660 / 664 行）
==== 总计失败=4，失败套件=2 ====
```

`[factions]` 套件因 5 处 `reveal()` 未定义而**无法加载**（运行器判失败，符合仓库 `SUITE` 哨兵机制）；`[registry]` 的 3 条失败是「内容与校验尚未落地」。红是"缺实现"而不是"测试写错"。

### 2.2 绿步（`bash tools/test.sh`，原始输出摘要；完整日志 `task-6-test-green.log`）

```
== 1/4 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/4 单元测试 ==
[probe] 故意失败: 期望 <2>，实际 <1>          ← 断言库自检探针，故意失败
[probe] 断言=1 失败=1                          ← 同上，probe 不计入 SUITES
[harness] 断言=8 失败=0
[registry] 断言=244 失败=0
[money] 断言=18 失败=0
[magic_level] 断言=48 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=154 失败=0
[creation] 断言=176 失败=0
[spell] 断言=229 失败=0
[gm] 断言=71 失败=0
[panel] 断言=71 失败=0
[selfcheck] 断言=32 失败=0
[save] 断言=107 失败=0
[async_probe] 断言=2 失败=0
[llm] 断言=88 失败=0
[prompt] 断言=13 失败=0
[debug_mirror] 断言=23 失败=0
[factions] 断言=184 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/4 主场景冒烟（默认配置：必须与未加调试镜像时逐字一致） ==
main scene ready, godot=4.7.2-stable (official)
== 4/4 调试镜像冒烟（HALI_DEBUG_LOG=1，B1 人工验收的观测通道） ==
[HALI] 调试镜像已启用：界面文本将镜像到 stdout（user://logs/*.log）；内容表问题 0 条
...
全部通过。
```

**逐字 `EXIT=0`**（`echo "EXIT=$?"` 输出 `EXIT=0`）。
`SCRIPT ERROR` 条数 = **2**，与基线（`task-1-baseline.log`）**完全一致**：两条都是 `save_test.gd:80` 打头的既有畸形载荷负例（`player_state.gd:109` 的 `personality` 类型错 + `game_clock.gd:10` 的 `int` 构造错），本次新增 **0** 条。主场景冒烟与镜像冒烟也全过（`main scene ready` + 15 行 `[HALI]` 预期标记）。

### 2.3 断言数前后对比

| 套件 | 实现前 | 实现后 | Δ | 来源 |
| --- | --- | --- | --- | --- |
| `[factions]` | 160 | **184** | +24 | brief 12（十项约束 + 传闻有效 + 传闻揭示）+ 来源可追溯 2 + 无效事件 2 + 端到端 8 |
| `[registry]` | 237 | **244** | +7 | brief 5（4 条 reveals 引用 + 计数≥3）+ 坏类型 1 + 坏引用 1 |
| `[world_tick]` | 154 | 154 | 0 | 本任务只改了两处注释错字 |
| 其余 15 套件 | — | — | 0 | 未触碰 |

## 3. `reveal()` 四条约束的断言与"能失败的证据"

| 约束 | 断言（`tests/factions_test.gd`） | 能失败的证据 |
| --- | --- | --- |
| ① 空来源 / `system` 来源拒绝 | `reveal(rw,"death_eaters","") == false`；`reveal(rw,"death_eaters","system") == false`；且**被拒后 `revealed` 仍为 false** | **D1**（去掉 `or src == "system"`）→ 4 条红：`system 来源不能揭示` / `被拒的揭示不写状态` / `合法来源可以揭示` / `揭示记录里带来源` |
| ② 未知派系拒绝 | `reveal(rw,"不存在的派系","破釜酒吧传闻") == false` | 由 ② 的 `registry.has("factions", …)` 守卫覆盖；D1 日志同时证明守卫链可失败（同一函数的相邻分支均能变红） |
| ③ 幂等（已揭示返回 false） | `reveal(...)` 第二次 `== false`；**并且** E2E 里第二次 `tick()` 后 `faction_revealed` 记录数仍为 1 | **D2**（去掉 `or bool(st.get("revealed", false))`）→ 2 条红：`重复揭示返回 false（幂等）`、`E2E：第二次 tick 走幂等路径，不重复写揭示记录（期望 <1>，实际 <2>）` |
| ④ 成功时写 `revealed`/`last_change_turn`/fact（带来源） | `revealed == true`、进入 `visible_faction_ids()`、`history` 有 `faction_revealed` 且文案含来源「破釜酒吧传闻」与 label「食死徒」 | D1 的 `揭示记录里带来源` 红 + D3 的 `E2E：第一次 tick 写一条揭示记录（期望 <1>，实际 <0>）` 红 |

**传闻揭示路径**（`apply_rumor_reveals` 填实）另有两组破坏实验：

- **D3**（把 `apply_rumor_reveals` 还原成 `pass`）→ 5 条红：`被抽中的传闻揭示对应派系（continental_pureblood）`、`E2E：tick 后该派系进入可见列表`、`E2E：第一次 tick 写一条揭示记录`、`E2E：第二次 tick …`、`E2E：已揭示后仍可见`。
- **D4**（删掉 `registry.gd` 的 rumors 类型校验）→ 1 条红：`rumors 表坏类型的 reveals_faction 必须报错`。
- **D5**（删掉 `validate_content` 的引用检查）→ 1 条红：`validate_content 必须拦下 reveals_faction 的坏引用`。

每组实验后都**逐字还原**并做 md5 校验：`md5sum -c task-6-md5-orig.txt` → `src/rules/factions.gd: OK` / `src/core/registry.gd: OK`；最终提交前的工作区 `git diff` 只含本任务的 6 个文件。

## 4. 端到端证据（确定性，不依赖"随机抽中"）

**难点**：`tick()` 的传闻阶段是概率抽取，直接"多跑几回合等它命中"不是确定性证据。
**做法**：用 `Registry.from_tables()` 造一份**除 `rumors` 表外全量复制默认内容表**的注册表，把 `rumors` 替换成**只留 `rumor_marked_ones` 一条**（该条 `reveals_faction = "death_eaters"`），玩家 `location_id = "knockturn_alley"`（落在它的 `zones` 内）⇒ 候选集恒为这一条，每次 `tick()` 必然处理它。这样"真实传闻被 tick 抽中"从概率事件变成确定事件，同时仍然走**真实的** `tick → events → apply_rumor_reveals → reveal` 链路（不是直接调 `reveal()`）。

断言链（8 条，全绿）：

```
E2E 前置：食死徒初始不可见
tick 处理了带 reveals_faction 的传闻（最小 rumors 表 ⇒ 确定）
E2E：tick 后该派系进入可见列表
E2E：第一次 tick 写一条揭示记录
E2E：第二次 tick 走幂等路径，不重复写揭示记录
E2E：已揭示后仍可见
```

D2/D3 证明这条链路真的承重：把幂等判断或 `apply_rumor_reveals` 破坏掉，上面的 E2E 断言立刻变红。

## 5. 未验证项 / 残余

1. **未验证「同一回合多个揭示」的组合**：夹具里 `rumors` 只有一条，未覆盖同回合两个带 `reveals_faction` 的传闻（各自揭示不同派系）时的 `history` 条数。逻辑上 `reveal()` 幂等且按事件循环，风险低。
2. **未验证跨存档**：`revealed` 存在 `world.factions[*]`（本就在存档白名单里），本任务未新增往返断言；`[save]` 的既有往返（107 断言）覆盖 `factions` 整体一致，但没有专门断言"读档后仍可见"。建议 Task 7/8 依托面板/提示词断言时顺带覆盖。
3. **`min_year: 0` 的语义**：4 条新传闻在所有时代都可被听到（`tick()` 里 `clock.year < min_year` 才过滤）。这是 brief 的明确取值，但意味着"1991 年的年轻人也能听到欧陆联姻传闻"——正典上没有冲突，登记备查。
4. **`weight` 目前仍未生效**：新条目带 `weight`（与既有 16 条同形），但抽取仍是均匀的 `stream_pick`；按计划这是 Task 12（`§8#16`）的范围，本任务**没有**提前实现。
5. **揭示不可逆**：一旦 `revealed = true` 就没有"重新遗忘"的通道。若 03b/03c 需要"传闻被证伪"或"记忆模糊"（第六十七章），要另加机制。登记为设计缺口。
6. **`rumor_id` 依赖**：`apply_rumor_reveals` 依赖 `tick()` 在传闻事件里写 `rumor_id`（Task 5 落的）。若将来有人改传闻事件字典结构，这里会静默不揭示（不会报错）。已在函数注释里写明依赖，但没有断言"每个传闻事件都带 rumor_id"——建议 Task 8（提示词）或 Task 13 收尾时补一条结构性断言。
7. **`data/rumors.json` 的字段风格**：新 4 条比 brief 原文多了 `weight` 与 `requires_flags` 两个字段，目的是与既有 16 条**同形**（既有条目全部含这两个键，`requires_flags` 为空数组表示无前置）。这是我主动做的**声明性偏离**，语义与 brief 一致（`major=false`、`min_year=0`、zones 原样）。

## 6. 是否触碰 brief 未列出的文件

**否。** 提交只含 brief 列出的 6 个文件（`src/rules/factions.gd`、`src/core/registry.gd`、`data/rumors.json`、`tests/factions_test.gd`、`tests/registry_test.gd`、`tests/world_tick_test.gd`）；`tests/world_tick_test.gd` 的两行改动是控制器明确要求的错字修正（纯注释文字，不改逻辑）。`data/rumors.json` 的 4 条内容按 brief 原样落盘（四个 `zones` 地点 id 经控制器核实存在于 `data/locations.json`，无需替换）。

---

# 修复轮 1（2026-09-20，提交 `537bd68`）

改动文件：`src/rules/factions.gd`、`tests/factions_test.gd`、`data/rumors.json`（3 files, +35/-6）；`registry.gd` / `registry_test.gd` / `world_tick_test.gd` 本轮未动。

## I1 错字与失实陈述

- `src/rules/factions.gd:383`：「过**隘**」→「过**阈**」✓（首轮只改对 2/3，见页首更正声明）。
- 额外：`tests/factions_test.gd:497`「死**阀**值」→「死**阈**值」（同类剩留，不在点名三处内）。
- 全仓校验：`grep -rn "过隘\|过阀\|死阀" src/ tests/` → **零命中**；三处正确写法现分别为 `factions.gd:383`、`world_tick_test.gd:121/131`、`factions_test.gd:497`。

## M1 `reveal()` 不再写 `last_change_turn`（字段语义单一化）

- 代码：删掉 `st["last_change_turn"] = world.clock.turn`，并加注释说明「该字段的语义严格定义为 **power 变更回合**；揭示由 `revealed` 布尔表达；若这里也写会让 Task 5 的不变量在『被揭示但当月 power 恰好没变』时变红」（与控制器计划 `28d3a4d` 一致）。
- 新断言（哨兵法）：先把 `mysteries`（`secrecy: semi` ⇒ 初始未揭示）的 `last_change_turn` 置为 **4242**，再 `reveal()`，断言仍为 **4242**。
- **能失败的证据（R1）**：把那一行加回 `reveal()` → 恰好 1 条红：
  ```
  [factions] 揭示不改变 last_change_turn（该字段只表达 power 变更回合）: 期望 <4242>，实际 <0>
  [factions] 断言=191 失败=1     ==== 总计失败=1，失败套件=1 ====
  ```

## M2 history 断言判别力

原 `a.is_true(rw.history.size() >= 1, …)` 任何一条 history 都能满足（写错 kind 也绿）。已改为计数 + 内容两条：`a.eq(reveal_records, 1, "揭示写入恰好一条 kind=faction_revealed 的 history（不是「有任意 history」）")` 与 `a.is_true(not reveal_record_text.is_empty(), …)`。

## M3 `reveal()` 空守卫

- 代码：`reveal()` 开头新增 `if world == null or world.registry == null or world.clock == null: return false`（与同文件 `initialize()`/`evolve()` 同口径），并注明它是对外 API（Task 7/8 面板/GM 会用）。
- 新断言 3 条：裸世界（`WorldState.new()`）返回 false；裸世界 + 空来源返回 false；`world = null` 返回 false。
- ⚠️ **能失败的证据不完美，如实登记**：破坏实验 **R2**（删掉该守卫）后**断言全绿**（`[factions] 断言=191 失败=0`）——因为 GDScript 在协程/函数中报错中止时，该调用返回类型默认值 `false`，恰好满足 `is_false(...)`。**真正的判别通道是 stderr 计数**：R2 下 `SCRIPT ERROR` 从基线 2 涨到 **4**（新增 `Nonexistent function 'has' in base 'Nil'` 与 `Invalid access to property 'key registry' … on Nil`，均在 `factions.gd:421`），而绿步恒为 2。这与 Task 4 审查 N1 属同一类（返回类型默认值吞掉中止），也与仓库既有 `§8#56` 同源。
- 计划文本尚未包含这条守卫（控制器只改了 M1 那处）⇒ **存在文档漂移，建议控制器同步计划**（我没动 `docs/`）。

## M5 传闻的时代门槛

| 条目 | min_year | 依据 |
| --- | --- | --- |
| `rumor_marked_ones`（食死徒） | 0 → **1970** | 组织语境属第一次巫师战争前后 |
| `rumor_phoenix_network`（凤凰社） | 0 → **1970** | 同上 |
| `rumor_malfoy_block`（神圣二十八族） | 保持 **0** | 古老家族在任何时代都存在 |
| `rumor_continental_pureblood`（欧陆联姻） | 保持 **0** | 联姻网络在任何时代都存在 |

- **不会改红既有断言的可核对证据**：E2E 夹具用 `WorldState.create("modern", …)`，而 `data/eras.json` 的 `modern.start_year = 2010`（**不是 1991**）⇒ 世界年份 **2010 ≥ 1970** ✓，夹具无需调整。为避免“年份不足 ⇒ 候选集为空 ⇒ 夹具静默空转”这类假绿，E2E 补了一条前置断言：`E2E 前置：世界年份 2010 ≥ 传闻 min_year 1970`。
- **能失败的证据（R3）**：把夹具里 `rumor_marked_ones.min_year` 改成 **3000** → 该前置断言 + E2E 其余 5 条共 **6 条红**（原本会静默空转的情形现在会响亮失败）。

## M6 报告漏登记的偏离

补登记：新 4 条 rumors 除 `weight`/`requires_flags`（§5.7）外，还比 brief 的 JSON 片段多了 **`label`** 字段。这是**必要的正确补齐**（不是可选风格）：`Registry.validate()` 对每张表都要求非空 `label`，缺它会直接报「缺少 label」。

## 修复轮断言数与测试结果

| 套件 | 首轮后 | 修复轮后 | Δ | 来源 |
| --- | --- | --- | --- | --- |
| `[factions]` | 184 | **191** | +7 | M1 2（前置 + 断言）、M3 3、M5 1（年份前置）、M2 净 +1（1 条换成 2 条） |
| `[registry]` / `[world_tick]` / `[save]` | 244 / 154 / 107 | 244 / 154 / 107 | 0 | 本轮未动 |

```
[factions] 断言=191 失败=0
==== 总计失败=0，失败套件=0 ====
全部通过。
EXIT=0（逐字）；SCRIPT ERROR=2（= 基线）
```

**还原纪律**：R1/R2/R3 三组实验后均逐字还原，`md5sum -c task-6-fix1-md5.txt` → `factions.gd: OK` / `factions_test.gd: OK` / `rumors.json: OK`；提交时工作区只含本轮 3 个文件。
