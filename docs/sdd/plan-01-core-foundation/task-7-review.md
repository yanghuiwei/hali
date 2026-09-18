# Task 7 审查记录（第一轮完整审查 + 修复轮 1 + 修复轮 2 scoped 复审）

> controller 从三个独立 reviewer subagent 的输出原样转存（模型均为 deepseek-flash）。
> 第一轮范围 `9899229..f323b55`；修复轮 1 `f323b55..3499881`；修复轮 2 `3499881..d52ebda`。

---

# 第一轮完整审查

# Task 7 审查记录

审查者：reviewer subagent　模型：deepseek-flash　范围：9899229..f323b55

## 结论
- 规格符合：✅
- 裁定：**Approved with findings**
- 关键数字：Critical=0，Important=2，Minor=4

## 证据

**diff 摘要**（`git show --name-status f323b55`，父 9899229，8 个文件、+304/-1）
```
A  data/spells.json                                   (34+)
M  docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md  (2+/-1，仅一行)
M  src/core/registry.gd                               (1+)
A  src/rules/spell_resolver.gd                        (130+)
A  src/rules/spell_resolver.gd.uid
M  tests/run_tests.gd                                 (1+)
A  tests/spell_test.gd                                (135+)
A  tests/spell_test.gd.uid
```
- `registry.gd` 仅在 `TABLE_FILES` 末尾追加 `"spells": "spells.json",`；`run_tests.gd` 仅在 `creation_test.gd` 后追加 `spell_test.gd`。两处均为纯追加。
- 两个 `.uid` 均已提交且全局唯一（`uniq -d` 无输出）。
- 工作区干净（`git status --short` 空），提交中无范围外文件。

**逐字核对（用 `git show 9899229:<plan>` 抽取原始计划代码块与实现 diff，规避实现同步改了计划文档造成的假一致）**
- 计划 Step 1 测试块（旧计划 2508–2642）↔ `tests/spell_test.gd`：**IDENTICAL**
- 计划 Step 3 JSON（旧计划 2660–2693）↔ `data/spells.json`：**IDENTICAL**（32 条；无重复 id；label 全非空；`side_effects` 全非空；guard 全在 `GUARDS` 内；forbidden=8 ≥6）
- 计划 Step 4 实现（旧计划 2701–2830）↔ `src/rules/spell_resolver.gd`：**仅 1 行不同**
```
< return _blocked_outcome("复制咒无法复制%s级资源：世界资源必须有成本、有产出、有消耗" % target_rarity, guard_ids)
> return _blocked_outcome("复制咒无法复制稀有资源（%s）：世界资源必须有成本、有产出、有消耗" % target_rarity, guard_ids)
```
- 计划文档 diff（`git diff 9899229..f323b55 -- ...md`）恰为同一行的同义替换，无其它改动。
- `Outcome` 字段/`GUARDS`/`cast`/`modifiers_from` 签名与计划 Interfaces 完全一致。
- commit message 采用简报强制修正后的 `feat(spell): …`（计划 Step 6 写的是 `feat(rules): …`，简报优先，判定正确）。

**独立复核 `bash tools/test.sh`（单实例，原始关键行）**
```
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=15 失败=0
[magic_level] 断言=22 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=176 失败=0
[spell] 断言=212 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```
四项硬指标（`[spell] 212/0`、`总计失败=0，失败套件=0`、`ALL TESTS PASSED`、`全部通过。`+EXIT=0）全部复现。

**失败率构成独立验算**（`MagicLevel.effective_rate` + `aptitude_delta + difficulty`，clamp [0.005,0.95]）
- ADULT base=(0.02+0.05)/2=0.035，normal Δ=0，lumos difficulty=0 → 0.035 ∈ [0.02,0.05] ✅
- 六项满值：0.035 + 6×0.15 = 0.935 ∈ [0.92,0.95] ✅
- 所有非拦截咒语在 `min_tier` 处 rate 均落在 [0.005,0.95]；`difficulty` 无法突破该 clamp。

**守卫静态复核**：`forbidden_lifetime` 无条件 return，horcrux(需 MYTH) 与 inferi 均必拦，符合「终身禁忌」；`unforgivable`/`restricted_mind_magic` 仅置 `legal_risk`，符合第二十五章；被拦截路径经 `_blocked_outcome` 提前 return，**不消耗 RNG**（`rng.stream_float` 在 return 之后），同种子序列仍确定；`spell_roll` 与 `spell_side_effect` 为独立命名流，副作用选择稳定。

## 发现
| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|
| 1 | Important | `src/rules/spell_resolver.gd:17,74` | `RARE_RARITIES = ["rare","legendary","史诗","传奇","神话"]` 混用中英，却**唯独缺「稀有」**。调用方若传中文 `"稀有"`，`RARE_RARITIES.has("稀有")==false`，复制咒**不被拦截**，反复制守卫被静默绕过；同时本提交新文案写的是「复制**稀有**资源」，词表与文案自相矛盾。 | Interfaces 规定 `target_rarity ∈ common/rare/legendary`，故现有数据源（`wand_cores.json` 用 `"common"/"rare"`）暂不触发；但词表主动接纳了 3 个中文项却漏掉最直接的 `"稀有"`，属自洽性缺陷，且是反漏洞守卫。 | 补齐 `"稀有"`（并考虑加 `"传说"`），或按规格**删掉全部中文项**；建议加负例测试 `{"target_rarity":"稀有"}` 期望 blocked。 |
| 2 | Important | `src/rules/spell_resolver.gd:18,82-83,117-118` | `energy_loop_count` 为**终身累计**计数、**永不衰减/重置**，且 `no_unlimited_energy` 挂在 `lumos`/`wingardium_leviosa` 上。玩家一生中第 4 次成功施放「照明咒」起，最基础咒语被**永久封禁**；计划（含 Task 8 计划）中无任何重置点。语义上把「禁止低阶咒语无限叠加」实现成了「禁止累计施放 3 次」。 | 旧计划 2818 与 Task 8 计划 2935–2942 均无 reset；`WorldState.tick()` 不清 `flags`。`grep` 全计划无 `energy_loop_count` 重置语句。 | 明确 per-turn/scene 语义：在回合或场景边界重置，或改为「同回合内叠加计数」；`time_rewind_count`（:19,119-120）同类终身 cap=1 建议一并明确是否为终身一次性。属计划层决定，需 controller 裁定。 |
| 3 | Minor | `src/rules/spell_resolver.gd:121-122` | `illegal_cast_count` **仅在 `o.success` 时自增**。非法施法失败（如阿瓦达失败）不留任何记录，法律风险台账少计「未遂」。 | 自增位于 `if o.success:` 块内；守卫本身按意图置 `legal_risk` 却因失败被丢弃。Task 8 计划 3797 会读取该计数。 | 将 `legal_risk` 的记账移到成功分支之外（无论成败均计一次），或显式文档化「仅记成功」。 |
| 4 | Minor | `src/rules/spell_resolver.gd:25-26,39-45` | 被拦截 `Outcome` 沿用默认 `failure_rate=1.0`、`roll=1.0`、`success=false`。数值自洽（`1.0 > 1.0` 为假），但 `failure_rate=1.0` 语义上是「必定失败」，与被拦截（未掷骰）不是同一回事，Task 8 若直接展示「失败率 100%」会误导。 | `_blocked_outcome` 不改这三个字段；调用方无法区分「掷骰必败」与「未进入掷骰」。 | 让 `blocked=true` 成为 Task 8 的唯一判据并文档化，或拦截时置 `failure_rate=0.0`/加 `rolled: bool` 字段。 |
| 5 | Minor | `tests/spell_test.gd` 全文 | 测试强度不足与覆盖缺口：①无 `portkey` 缺批准被拦的用例（`requires_ministry_approval` 零覆盖）；②无 `legilimens`/`confundo` 的 `legal_risk` 断言（只测了 `imperio`）；③从不验证 `energy_loop_count`/`time_rewind_count` **成功时自增**（手动置 flags 绕过）与 `last_serious_mishap_turn`；④`time_turner` 首测只查 `blocked==false`，把「未被拦截」当「允许」；⑤`modifiers_from_test` 只断言 `combat_stress==0.5>0`，**未断言未知键被丢弃**；⑥确定性用例以相同代码跑两遍，属弱等价；⑦无 `"稀有"` 绕过负例。 | `a.is_true(m.get("combat_stress",0.0) > 0.0, "未知条件被忽略")` 名不副实；`for i in 10: seq_a…seq_b…` 同源重复。 | 补上述负例与自增/重置断言；把「忽略未知键」改成 `a.is_false(m.has("不存在的因素"))`。 |
| 6 | Minor | `src/rules/spell_resolver.gd:107`（配合 `data/spells.json` difficulty 0.02–0.30） | `difficulty` 被直接加到失败率上，其量级（0.02–0.30）与整个等级区间带宽同阶，实际是**绝对偏移**而非「相对难度」：如 `time_turner`(MASTER base 0.0125)+0.30=0.3125，远超大师级 [0.005,0.02] 区间。结果仍在 clamp 内，无越界，但文档表述与效果不符。 | `aptitude_delta + float(spell.difficulty)` 一次性传入 `effective_rate`；实测 time_turner 0.3125、avada 0.2350。 | 若为有意设计，在计划/注释注明「difficulty 为绝对失败率偏移」；否则改为区间内插值或缩放。 |

## 对计划修正的裁定

**修正唯一且正确，无夹带。**
- 原计划 `_blocked_outcome("复制咒无法复制%s级资源…" % target_rarity)` 在 `target_rarity="rare"` 时产出「…复制rare级资源…」，与测试 `blocked_reason.contains("稀有")` 必然冲突；该红灯可由计划文本直接推出，属计划自身缺陷，不是实现者失误。
- 用 `git show 9899229:<plan>` 抽取**原始**计划与实现逐字对比：差异**恰为这一行**，且计划文档 diff 也**恰为同一行的同义替换**（`2 +1/-1`），未借机改动 `data/spells.json`、测试、守卫逻辑或其它任何内容。`spell_test.gd`/`spells.json` 与旧计划完全一致，`spell_resolver.gd` 与旧计划仅此一行不同。
- commit message 从计划 Step 6 的 `feat(rules):` 改为简报强制的 `feat(spell):`，符合「简报优先」。
- 裁定：**接受**。唯一遗留是 finding #1——新文案用「稀有」而 `RARE_RARITIES` 不识别「稀有」，属词表问题而非文案问题，不影响本次修正本身的正确性。

## 未验证/存疑
- 审查为**只读**，未新建任何探针脚本，故 finding #1（中文 `"稀有"` 绕过）与 #2（计数器终身累计）系**静态阅读 + 计划交叉验证**结论，未以运行态复现；如 controller 需要运行证据，应另派 worker 以最小用例验证（不得由本 reviewer 写文件）。
- Task 8 尚未实现，finding #4（被拦截 `Outcome` 字段对调用方的误导）与 `illegal_cast_count` 的下游后果**无法端到端验证**，仅为接口风险提示。
- 「被拦截路径不消耗 RNG」已确认：同一 `RngService` 复用时会因是否拦截而改变后续采样次数。当前所有测试均以新 `RngService` 调用，未暴露此交互；不构成缺陷（同输入仍确定），但 Task 8 若跨多个 `cast` 复用单一 RngService，其随机序列将随拦截结果分叉——建议 Task 8 显式确认这是可接受语义。
- `Registry.validate()` 确实只校验表非空与非空 `label`（不校验 `min_tier`/`guards`/`side_effects`），报告所述属实；本次数据完整性全由 `spell_test.gd` 逐条覆盖，无缺口。

---

# 修复轮 1 scoped 复审

# Task 7 修复轮 scoped 复审

复审者：reviewer subagent　模型：deepseek-flash　范围：f323b55..3499881

## 结论
- Important #1：**ADDRESSED**（所报缺陷「词表缺中文『稀有』」已补齐，回归断言非空转，反证可复现；但「守卫不可被任何字符串绕过」这一更强标准下仍存变体缺口，已单列为残留 R1）
- 新增断言非空转：**是**（4 条断言逐条做了变异测试，均可被对应对实现改动打红）
- 有无新问题/夹带：**无夹带、无本修复轮引入的新缺陷**。但独立验证中发现 1 项**既有**加固缺口 R1（精确匹配 + fail-open 可绕过），及 2 项本轮新增内容的小缺口 R2/R3，见残留表
- 总评：**通过**

## 证据

### 1. diff 逐行核对（`git diff f323b55..3499881`，父提交确为 f323b55）
- `git show --name-status 3499881`：**仅 3 个 M 文件，无新增/删除、无 `.uid`、无越界**
```
M docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
M src/rules/spell_resolver.gd
M tests/spell_test.gd
```
- `git diff --check f323b55..3499881` → 干净（无空白错误）。
- 内容恰为声称的 1–3 项，**逐条对得上，无夹带**：
  - `spell_resolver.gd:17`：`RARE_RARITIES` 由 5 项 → `["rare","legendary","稀有","史诗","传奇","神话","传说"]`（+`稀有`+`传说`），**该文件仅此 1 行改动**（`git diff --stat` = `2 +-`）。
  - `tests/spell_test.gd`：+3/+6/+1 行，恰好 4 个新断言（47–49 `rare_cn`、90–94 portkey 两条、109 未知键），故 `212 → 216` 的 `+4` 算术自洽。
  - 计划 `.md`：`12 +++++++++++-` = 11 增 1 删，且 4 个 hunk 与代码改动**一一对应**（2554–2556 / 2597–2602 / 2616 / 2727），无第五处改动。
- 工作区复核：`git status --short` 空；沙箱仅建于 `/tmp` 且已删除，仓库内零残留。

### 2. 逐字一致（计划 Step 1 / Step 4 ↔ 代码）
用行号抽块后直接 `diff`（规避「实现顺带改计划文档」造成的假一致）：

```
$ diff <(sed -n '2508,2652p' <plan>) tests/spell_test.gd            → IDENTICAL
$ diff <(sed -n '2711,2840p' <plan>) src/rules/spell_resolver.gd    → IDENTICAL
```
计划 `Step 1`（测试块 2508–2652）与 `Step 4`（实现块 2711–2840）与代码**逐字一致**，claim #3 成立。

### 3. 独立跑测（单实例，`bash tools/test.sh`，正确捕获退出码）
```
[spell] 断言=216 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
REAL_EXIT=0
```
四项硬指标全部复现；`[creation] 176`、`[world_tick] 104` 等其余套件无回归。

### 4. 新增断言非空转（沙箱变异测试，`/tmp/hali-sbx` = HEAD 副本，跑完已删）
| 变异 | 预期 | 实测失败行 | 退出 |
|---|---|---|---|
| M1 `RARE_RARITIES` 移除 `"稀有"` | 打红 `rare_cn` | `[spell] 中文「稀有」也必须被反复制守卫拦截: 期望为真`　`失败=1` | 1 |
| M2 `requires_ministry_approval` 改 `if false` | 打红「无批准拦截」 | `[spell] 无魔法部批准不得使用门钥匙: 期望为真`　`失败=1` | 1 |
| M3 `requires_ministry_approval` 改 `if true` | 打红「有批准放行」 | `[spell] 有批准后可使用门钥匙: 期望为假`　`失败=1` | 1 |
| M4 `modifiers_from` 泄漏未知键 | 打红未知键断言 | `[spell] 未知条件键被丢弃: 期望为假`　`失败=1` | 1 |
| M5 `RARE_RARITIES` 移除 `"传说"` | —— | **无任何失败**（216/0） | 0 |

- M1 **逐字复现** claim #4 的反证（`失败=1`、EXIT=1，随后还原），controller 的反证属实。
- M2+M4 证明 portkey 两条构成完整的「无批准→拦截 / 有批准→放行」双向覆盖，**不是**只测单向。运行态探针进一步给出原因与守卫来源：
```
no-approval  blocked=true  ok=false reason=缺少魔法部批准 guards=["requires_ministry_approval"]
approved     blocked=false ok=true  reason=            failure_rate=0.0925
```
  （portkey 仅挂 `requires_ministry_approval`，master 等级 ≥ ADULT，故 `blocked` 只可能来自批准守卫，断言无假阳风险。）
- M4 同时证明新断言`a.is_false(...has("不存在的因素"))`相对旧的弱断言 `combat_stress>0` 是**真实属性断言**；探针输出 `keys=[6 个 MODIFIER_KEYS] has_unknown=false combat_stress=0.5`。
- M5 暴露 R2：新增的 `"传说"` **无任何断言覆盖**，删掉不报警。

### 5. 独立判断：修法是否充分（brief 问题 2）
运行态枚举 `geminio` 的 `target_rarity`（沙箱）：

| 输入 | 被拦截 | 说明 |
|---|---|---|
| `rare` / `legendary` / `稀有` / `史诗` / `传奇` / `神话` / `传说` | ✅ 全部 true | 词表内 7 项均生效，文案为「复制咒无法复制稀有资源（稀有）」 |
| `傳說` / `傳奇` / `史詩` / `神話` | ❌ false | 繁体变体绕过 |
| `Rare` / `RARE` | ❌ false | 大小写绕过 |
| `rare ` / `稀有 ` | ❌ false | 尾随空白绕过 |
| `uncommon` / `epic` / `mythic` / `绝品` / `SSR` / `""` | ❌ false | **非词表值一律放行（fail-open）** |
| `common` / `普通` | ❌ false | 符合预期 |

结论：`RARE_RARITIES.has()` 是 `Array[String]` 的**精确、大小写/空白敏感**匹配，且策略是「非稀有即放行」的 **denylist**。
- 对**所报缺陷**（中文「稀有」）**充分**：已拦截、有非空转回归、反证可复现。
- 对「**该守卫不可被绕过**」**不充分**：上述变体全部实测绕过（R1）。
- `common` 一侧是否需要白名单：**缺失键默认 `common`（`conditions.get("target_rarity","common")`）是合理的**（未指定目标不应被拦）；但「键存在却无法识别」时 fail-open 对反漏洞守卫偏危险，建议改为「显式 allowlist + 未知值按策略（拒绝/归一后判定）」。
- 契约缓解项：计划 Interfaces（2499 行）声明 `target_rarity ∈ common/rare/legendary`，规范化入参本应落在该枚举内；故 R1 的现实触发面取决于 Task 8 的 `conditions` 由谁生成（LLM 叙述词较可能产出中文/大小写变体）。

### 6. 未处置 Important #2 的判断（brief 问题 6）
- 现状复核属实：`energy_loop_count` **只在成功时自增**（`spell_resolver.gd:118`），**全代码与全计划无任何重置/衰减点**（`grep` 仅命中测试置数），且是**全局单计数器**，仅 `lumos`/`wingardium_leviosa` 挂 `no_unlimited_energy`（`data/spells.json` 2 条）→ 累计第 4 次成功施放任一基础咒后**终身**被拦。
- 关键点：**Task 8 计划本身把该语义固化**——计划 2949–2952 连施 5 次后断言 `energy_loop_count <= 3`，并在置 3 后断言被拦（narration 含「上限」）。因此这不是「Task 8 会顺手修」的问题。
- 我的判断：**可以留到 Task 7 收尾之后，但必须由 Human 在 Task 8 实施前裁定**（per-life / per-scene / per-turn 语义），并在同一裁定中**同步修改计划 2949–2952**；否则 Task 8 落地会把它变成不可逆的产品语义。Task 7 收尾前不必改（无回归、无规格违反，属计划层决定）。

## 残留发现（含第一轮未处置项）
| # | 严重度 | 位置 | 问题 | 留到哪个任务 / 需要什么裁定 |
|---|--------|------|------|------------------------------|
| 第一轮 #1 | ~~Important~~ | `src/rules/spell_resolver.gd:17` | 词表缺中文「稀有」导致静默绕过；同时文案与词表矛盾 | **✅ 本轮关闭**（补 `稀有`+`传说`，回归非空转，反证复现） |
| 第一轮 #2 | Important | `spell_resolver.gd:18,83,118`；`data/spells.json`（lumos/wingardium） | `energy_loop_count` 终身累计、无重置点，第 4 次成功施放基础咒即永久封禁 | 留到 **Task 8 实施前由 Human 裁定**（per-turn/scene/life）；若改语义须同步计划 **2949–2952** |
| R1（新发现，既有） | Important | `spell_resolver.gd:17,74,78,84` | 精确匹配 + fail-open denylist：繁体（`傳說`/`傳奇`/`史詩`/`神話`）、大小写（`Rare`）、空白（`稀有 `）、任意未知稀有度（`uncommon`/`epic`/`绝品`）**实测均可绕过**反复制守卫 | 留到 **Task 8 前裁定**：至少在守卫入口 `strip_edges().to_lower()` 归一，并明确未知值策略（拒绝 / 显式 allowlist）；若 Human 判定「按契约枚举 common/rare/legendary 即足够」，则降为文档说明 |
| 第一轮 #3 | Minor | `spell_resolver.gd:121-122` | `illegal_cast_count` 仅成功时自增，「未遂」不计入法律风险台账 | 留到 **Task 8**（该任务计划 3807 行读取此计数）；需裁定「仅记成功」是否可接受 |
| 第一轮 #4 | Minor | `spell_resolver.gd:25-26,39-45` | 被拦截 `Outcome` 沿用 `failure_rate=1.0`，与「未进入掷骰」语义混淆 | 留到 **Task 8 展示层**；需裁定以 `blocked` 为唯一判据或补 `rolled: bool` |
| 第一轮 #5 | Minor | `tests/spell_test.gd` | 剩余测试缺口：`legilimens`/`confundo` 的 `legal_risk`、计数器「成功时自增」、`last_serious_mishap_turn`、`time_turner` 把「未拦截」当「允许」、确定性用例弱等价；且新增 portkey 两条**只断言 `blocked`、未断言 `reason` 含「批准」** | 留到 **Task 8** 测试加固；portkey 建议补 `blocked_reason` 断言 |
| 第一轮 #6 | Minor | `spell_resolver.gd`（difficulty `data/spells.json` 0.02–0.30） | `difficulty` 实为**绝对失败率偏移**而非「相对难度」，文档表述与效果不符 | 留到 **Human/计划注释裁定**（有意设计则注明，否则改插值/缩放） |
| R2（新发现） | Minor | `spell_resolver.gd:17`（⟷ `tests/spell_test.gd:47-49`） | 本轮新增的 `"传说"` **零覆盖**（M5：删除后仍 216/0） | 留到 **Task 8** 补一条负例，或删除该未使用项 |
| R3（新发现） | Minor | 计划 `2499`（⟷ 实现 `:17`、测试 `:48`） | Interfaces 仍声明 `target_rarity`（`common`/`rare`/`legendary`），而实现/测试已接纳中文别名，接口文档未同步（实现为超集，不违规） | 留到 **计划维护/人类**：注明「枚举非穷尽，允许中文别名」或收窄测试到契约值 |

## 未验证/存疑
- 本复审为**只读**；所有运行证据来自 `/tmp/hali-sbx`（`git archive HEAD` 副本，已删除）与 `bash tools/test.sh`，**仓库内零改动**（`git status --short` 空）。
- R1 的**现实触发面**未能量化：仓库现有数据源（`data/wand_cores.json`）只用 `common`/`rare`，计划内暂无 `target_rarity` 的中文调用方；真实泄漏风险取决于 Task 8 `cast_spell` 的 `conditions` 提供方（尚未实现，无法端到端验证）。
- Task 8/9/10 尚未实现，第一轮 #3/#4 的下游后果与 #5 的补测效果**无法端到端验证**，仅为接口/计划层提示。
- 本轮未复检第一轮已确认的「拦截路径不消耗 RNG / 跨 `cast` 复用同一 `RngService` 会分叉」交互（非本轮范围）。
- 未验证计划 Task 8～11 全量文本，仅按需 grep 了 `energy_loop_count`/`illegal_cast_count`/`target_rarity` 相关行。

---

# 修复轮 2 scoped 复审

# Task 7 修复轮 2 scoped 复审

复审者：reviewer subagent　模型：deepseek-flash　范围：3499881..d52ebda

## 结论
- **R1：ADDRESSED**（精确匹配 + fail-open denylist 已改为「归一化 + fail-closed 普通白名单」；中文繁体/大小写/空白/任意未知值全部实测被拦，独立枚举无任何残余绕过路径；`common`/`普通`/`常见` 与归一化变体放行，缺键默认仍放行，无误伤合法契约调用）
- **新增断言非空转：是**（沙箱变异：`M-A` 去掉归一化 → 打红「 Common 」正例；`M-B` 退回 denylist → 打红 3 条变体负例；`M-C` 完全退回修复前状态 → 5 条变体负例全红）
- **有无新问题/夹带：无夹带**（仅 3 个 M 文件、`--check` 干净、无越界文件）；**无阻塞性新问题**，但独立验证新发现 2 项 Minor 观察（R4 `常见` 零覆盖、R5 全角空白/全角拉丁被过度拦截）
- **总评：通过**

## 证据

### 1. diff 逐行核对（`git diff 3499881..d52ebda`）
- 提交父节点 `git rev-parse d52ebda^` = `349988145eaec3a9b9faeed460ae779ddf694e5b`（即 3499881），范围正确。
- `git show --name-status d52ebda` 与 `--numstat`：
```
M docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md   11 +  4 -
M src/rules/spell_resolver.gd                                            5 +  3 -
M tests/spell_test.gd                                                    5 +  0 -
```
  仅 3 个 M 文件，无新增/删除、无 `.uid`、无越界；`git diff --check 3499881..d52ebda` 干净（无空白错误）。
- 内容**恰好**是声称的 1–3 项，无第五处改动：
  - `spell_resolver.gd`：`RARE_RARITIES`(+7 项 denylist) → `COMMON_RARITIES = ["common","普通","常见"]`（+2 行注释）；`target_rarity` 加 `.strip_edges().to_lower()`；守卫 `if RARE_RARITIES.has(...)` → `if not COMMON_RARITIES.has(...)`。
  - `tests/spell_test.gd`：+5 行，即 `for rarity in ["Rare","稀有 ","傳說","uncommon","epic"]`（5 断言）+ `普通` 正例 + `" Common "` 正例 = **+7**，`216 → 223` 算术自洽（其余套件计数与上一轮一致：creation 176、world_tick 104…）。
  - 计划 `.md`：Interfaces 2499 一行 + Step 1 测试块 + Step 4 实现块（含 const/归一化/守卫）。

### 2. 计划 ↔ 代码逐字一致（规避「实现顺带改计划」的假一致）
```
$ diff <(sed -n '2508,2657p' <plan>) tests/spell_test.gd          → IDENTICAL
$ diff <(sed -n '2716,2847p' <plan>) src/rules/spell_resolver.gd  → IDENTICAL
```
- 计划 Step 1（代码块 2508–2657）与 Step 4（代码块 2716–2847）与代码**逐字一致**；`COMMON_RARITIES` 在计划 2732–2734、实现 `:16-19`；`target_rarity` 归一在计划 2787、实现 `:72`；守卫 `not COMMON_RARITIES.has` 在计划 2791、实现 `:76`。
- Interfaces 2499 语义一致：`target_rarity: String`（`common`/`rare`/`legendary`；比较前先 strip_edges + 小写归一，未在普通白名单内的值一律按稀有处理）——与实现策略（归一化 + 非白名单即稀有）逐点对应。

### 3. 独立跑测（单实例，`bash tools/test.sh`；仓库 `plan-01-core-foundation`）
```
[spell] 断言=223 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
REAL_EXIT=0
```
四项硬指标全部复现；`[creation] 176`、`[world_tick] 104` 等其余套件无回归。

### 4. 独立判断 fail-closed 修法（运行态枚举，`/tmp/hali-sbx` = `git archive HEAD` 副本，跑完已删）
`geminio` × `target_rarity`（`MagicLevel.ADULT`）：

| 输入 | 结果 | 判定 |
|---|---|---|
| `common` / `普通` / `常见` / `" Common "` / `COMMON` / `Common` / `" common\t"` | ALLOWED | ✅ 白名单 + 归一正确放行 |
| **缺键（`{}`）** | ALLOWED，reason 空 | ✅ 默认 `common` 不被误伤 |
| `rare` / `legendary` / `稀有` / `史诗` / `传奇` / `神话` / `传说` | BLOCKED | ✅ |
| `Rare` / `RARE` / `稀有 ` / `稀有\t` | BLOCKED | ✅ 大小写/ASCII 空白归一 |
| `傳說` / `傳奇` / `史詩` / `神話` | BLOCKED | ✅ 繁体不再绕过 |
| `uncommon` / `epic` / `mythic` / `绝品` / `SSR` / `""` / `" "` / `未知` | BLOCKED | ✅ 任意未知值一律按稀有（fail-closed） |
| `ｃｏｍｍｏｎ` / `ＣＯＭＭＯＮ` / `"　common　"` / `"common　"` / `"　普通"` | **BLOCKED** | ⚠️ 过度拦截（R5，安全方向，非绕过） |

结论：
- **充分性成立**：策略由「非稀有即放行」翻转为「非普通白名单即拦」，加上 `strip_edges().to_lower()` 归一后，**不存在任何字符串变体绕过路径**——任何未显式列入白名单的值（含空串、`null`→`str()`、非字符串类型）都被拦截。触发面收窄为 `geminio`（`data/spells.json:32` 是**唯一**挂 `no_rare_resource_duplication` 的魔咒）。
- **不误伤**：契约值 `common`（含大小写/ASCII 空白变体）与中文 `普通`/`常见` 放行；缺键默认 `common` 放行（未指定目标不应被拦），符合「守卫只针对显式指定稀有目标」。
- `to_lower()` 行为：对**全角拉丁字母**做全角↔全角的大小写映射（`ＣＯＭＭＯＮ`→`ｃｏｍｍｏｎ`），但**不做宽度折叠**（不还原为 ASCII），对中文/繁体做逐码位小写映射（无变化）。`strip_edges()` **不覆盖全角空格 U+3000**（`"　common　"` 保留全角空白 → 被拦）。二者共同构成 R5 的过度拦截，而非安全缺口。

### 5. 新增断言非空转（沙箱变异测试）
| 变异 | 预期 | 实测 | 退出 |
|---|---|---|---|
| **M-A** 去掉 `.strip_edges().to_lower()`（保留 fail-closed 白名单） | 正例应红 | `[spell] 归一化后 Common 视为普通物品: 期望为假`　`失败=1` | 1 |
| **M-B** 保留归一化，守卫退回 denylist | 变体负例应红 | `稀有度变体 傳說 / uncommon / epic 必须被拦截`　`失败=3` | 1 |
| **M-C** 退回原始 denylist + 无归一化（修复前状态） | 5 变体全红 | `稀有度变体 Rare / 稀有  / 傳說 / uncommon / epic`　`失败=5` | 1 |
| **M-D** 白名单删除 `"常见"` | —— | **无任何失败（223/0）** → `常见` 零覆盖（新 R4） | 0 |
| **M-E** 白名单删除 `"普通"` | 正例应红 | `[spell] 中文「普通」视为普通物品: 期望为假`　`失败=1` | 1 |

- **M-A 逐字复现** brief claim #4 的反证（`归一化后 Common 视为普通物品: 期望为假`、`失败=1`、EXIT=1，随后还原）——controller 的反证属实，且证明 `" Common "` 正例**正是**捕获「去掉归一化」回归的那条断言（其余 4 条变体负例在无归一化时仍绿，因为 fail-closed 依然拦截）。
- **M-B/M-C 证明**变体负例确实能捕获「退回 denylist」的回归（`傳說`/`uncommon`/`epic` 是 denylist 下必漏的三个）。
- 所有变异后 `diff /tmp/orig_resolver.gd src/rules/spell_resolver.gd` 还原确认，仓库内零改动。

### 6. 残留清单复核
- **Important #2（`energy_loop_count` 终身累计）**：现状**未变**。`spell_resolver.gd:85,120` 只在**成功时自增**，`grep energy_loop_count` 全代码/数据**无任何重置点**（仅测试置数）；仍是全局单计数器，仅 `lumos`/`wingardium_leviosa` 挂 `no_unlimited_energy`。Task 8 计划（现 2956–2958，因本轮 +7 行由上一轮 2949–2952 平移）连施 5 次后断言 `<= 3` 并置 3 断言被拦，**继续把该语义固化**。故与上一轮判断一致：必须在 **Task 8 实施前由 Human 裁定** per-turn/per-scene/per-life，并同步修改计划 2956–2958，否则不可逆。
- 第一轮 Minor #3/#4/#5/#6 均**未处置且未受影响**，仍有效（见下表）。
- 第一轮 R2（`传说` 零覆盖）**未被本轮覆盖**——本轮只加了 `傳說`（繁体）负例，`传说`（简体）仅在现有 `rare_cn` 之外无独立断言；但 fail-closed 下它必然被拦，且 M-C 证明整体策略有覆盖，风险已降。第一轮 R3（Interfaces 未注明中文别名）**基本关闭**：2499 现含「普通白名单」语义，与实现一致。

## 残留发现（含第一轮未处置项）
| # | 严重度 | 位置 | 问题 | 留到哪个任务 / 需要什么裁定 |
|---|--------|------|------|------------------------------|
| R1（上一轮提出） | ~~Important~~ | `spell_resolver.gd:19,72,76` | 精确匹配 + fail-open denylist 可被大小写/空白/繁体/未知值绕过 | **✅ 本轮关闭**：归一化 + fail-closed 白名单，独立枚举 0 绕过，回归断言非空转（M-A/B/C） |
| 第一轮 #2 | Important | `spell_resolver.gd:85,120`；`data/spells.json`(lumos/wingardium)；计划 2956–2958 | `energy_loop_count` 终身累计、无重置点，第 4 次成功施放基础咒即永久封禁；Task 8 计划固化该语义 | 留到 **Task 8 实施前由 Human 裁定**（per-turn/scene/life）；若改语义须同步计划 **2956–2958** |
| R4（本轮新发现） | Minor | `spell_resolver.gd:19`（⟷ `tests/spell_test.gd:51-54`） | 白名单 `"常见"` **零断言覆盖**（M-D：删除后仍 223/0），与上一轮 R2 同类 | 留到 **Task 8** 补一条 `常见` 正例，或删除该未使用项 |
| R5（本轮新发现） | Minor | `spell_resolver.gd:72` | `strip_edges()` 不覆盖全角空格 U+3000、`to_lower()` 不做全角↔ASCII 宽度折叠 → `"　common　"`/`ｃｏｍｍｏｎ` 被过度拦截（安全方向，无绕过）。属契约外输入，但若 Task 8 的 LLM/叙述层可能产出全角字符，会误拦合法复制 | 留到 **Task 8/计划**：裁定「契约只接受 ASCII 枚举 + 中文别名」则记为已知边界；否则在归一化前加 Unicode 宽度/全角空白折叠 |
| R2（上一轮） | Minor | `spell_resolver.gd:19`（⟷ `tests/spell_test.gd`） | 简体 `"传说"` 无独立断言（繁体 `傳說` 已覆盖；fail-closed 下必拦，风险下降） | 留到 **Task 8** 测试加固，与 R4 合并补一条参数化负例 |
| 第一轮 #3 | Minor | `spell_resolver.gd:123-124`（计划 2839） | `illegal_cast_count` 仅成功时自增，「未遂」不计入法律风险台账 | 留到 **Task 8**（计划 3814 读取该计数）；需裁定「仅记成功」是否可接受 |
| 第一轮 #4 | Minor | `spell_resolver.gd:27-28,41-47` | 被拦截 `Outcome` 沿用 `failure_rate=1.0`，与「未进入掷骰」语义混淆 | 留到 **Task 8 展示层**；需裁定以 `blocked` 为唯一判据或补 `rolled: bool` |
| 第一轮 #5 | Minor | `tests/spell_test.gd` | 剩余缺口：`legilimens`/`confundo` 的 `legal_risk`、计数器「成功时自增」、`last_serious_mishap_turn`、`time_turner` 把「未拦截」当「允许」、确定性用例弱等价；portkey 两条只断言 `blocked` 未断言 reason | 留到 **Task 8** 测试加固 |
| 第一轮 #6 | Minor | `spell_resolver.gd`（difficulty `data/spells.json` 0.02–0.30） | `difficulty` 实为绝对失败率偏移而非「相对难度」，文档表述与效果不符 | 留到 **Human/计划注释裁定** |
| 第一轮 R3 | ~~Minor~~ | 计划 2499 | Interfaces 未同步中文别名 | **✅ 基本关闭**：2499 已加「普通白名单/未在白名单一律按稀有」说明，语义与实现一致 |

## 未验证/存疑
- 本复审为**只读**：所有运行证据来自 `bash tools/test.sh` 与 `/tmp/hali-sbx`（`git archive HEAD` 副本 + 变异，已删除）；结束复核 `git status --short` 为空、`git diff --stat HEAD` 为空，仓库零改动。
- R5 的**现实触发面**未量化：仓库现有数据源 `data/wand_cores.json` 仅用 `common`/`rare`，且 `geminio` 是唯一挂该守卫的魔咒；真实泄漏/误拦取决于 Task 8 `conditions` 提供方（尚未实现），无法端到端验证。
- 全角空白/宽度折叠行为基于 Godot 4.7.2 实测（`"　common　"` BLOCKED、`ＣＯＭＭＯＮ`→`ｃｏｍｍｏｎ`），未穷举所有 Unicode 空白码位（如 U+200B 零宽空格），但方向一致：只会过度拦截，不会绕过。
- 未复检第一轮已确认的「拦截路径不消耗 RNG / 跨 `cast` 复用同一 `RngService` 会分叉」交互（非本轮范围）。
- Task 8–11 尚未实现，第一轮 #3/#4 的下游后果与 #5 的补测效果**无法端到端验证**，仅为接口/计划层提示。

---

# 裁定实现 scoped 复审（per-turn / 终身一次性，提交 a0bc1d3）

# 裁定实现 scoped 复审（per-turn / 终身一次性）

复审者：reviewer subagent（独立只读复审）　模型：deepseek-flash　范围：7379152..a0bc1d3

## 结论
- per-turn（energy）：**ADDRESSED**
- 终身一次性（time rewind）：**ADDRESSED**（无回归）
- Task 8 计划兼容：**是**
- 有无新问题/夹带：**有（列出）** —— 无夹带、无功能回归；仅 2 处文档级问题（注释误引条款、台账文档漂移），另 2 条信息级提示。见残留表。
- 总评：**通过**

## 证据

### 1. diff 逐行核对（`git diff --numstat 7379152..a0bc1d3`）
```
11  0  docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
3   0  src/model/world_state.gd
2   0  src/rules/spell_resolver.gd
6   0  tests/spell_test.gd
```
- 父提交确认：`a0bc1d3^ = 73791523b8279b324077c75936e80315e2ede404`；`HEAD = a0bc1d3`；分支 `plan-01-core-foundation`；工作区干净（`git status --porcelain` 空、`git diff --stat HEAD` 空）。
- 内容与 controller 声称 1–4 项**完全对应**，纯新增 0 删除：
  1. `world_state.gd tick()` 在 `clock.advance_month()` 后新增 2 行注释 + `flags.erase("energy_loop_count")`；**不含** `time_rewind_count`。✓
  2. `spell_resolver.gd` 两个守卫分支各 +1 行注释，`if`/`return`/常量**逐字未改**（diff 中无逻辑行）。✓
  3. `spell_test.gd` 新增 4 条断言（`eq`/`eq`/`is_false`/`is_true`）。✓
  4. 计划同步 Task 5 `tick()`、Task 7 守卫块、Task 7 测试块（+11 行）。✓
- 无越界文件、无新增文件、无 mode 变更、无 HANDOFF/progress 夹带。
- **`time_rewind_count` 无任何重置路径**：全 `src/` grep 只有 `spell_resolver.gd:124` 的 `+1` 自增与 `:83` 的读取；`world_state.gd:76` 只擦 `energy_loop_count`；`from_dict`（`world_state.gd:185`）原样载入 flags；`create()` 不写 flags。✓

### 2. 独立语义验证（沙箱 `/tmp/hali-ruling-probe`，`git archive a0bc1d3` 副本 + 探针脚本，已删除；仓库零改动）
```
A cast#0 before=0 success=true  blocked=false after=1
A cast#1 before=1 success=true  blocked=false after=2
A cast#2 before=2 success=true  blocked=false after=3
A cast#3 before=3 success=false blocked=true  after=3
A RESULT max_count=3 (<=3? true) first_block_at=3 (count==3 before? true)
A narration=（低阶咒语叠加已达上限，无法继续累积能量）
B pre-tick  count=3 blocked=true
B post-tick has_key=false count=0          # erase 后键消失，get(...,0) 兜底
B post-tick lumos blocked=false            # 新回合可重新施放
C after 3 ticks time_rewind_count=1 time_turner blocked=true
D 5连施后 count=3 (<=3? true)              # Task 8 同回合场景仿真
D 置3后 blocked=true narration=（低阶咒语叠加已达上限，无法继续累积能量）
E from_dict count=3 (保留? true)           # 载档不误重置
```
- 同回合累计 1→2→3，第 4 次（`count==3`）被拦，上限恒 ≤3；仅成功时自增，拦截分支不消耗计数（拦截后仍为 3）。
- `tick()` 后键**被擦除**（`has_key=false`）而非置 0；守卫 `flags.get(...,0)` 兜底 → 0，无隐患、无类型漂移（增量用 `int(...)+1`，读用 `int(...)`）。
- `from_dict` 原样保留计数，不构成错误重置路径（同回合存档读档延续计数，跨回合需 `tick()` 归零 → 与 per-turn 定义自洽）。
- `time_turner` 在 `master`(MASTER) 等级下 min_tier=大师级 恰好满足 → 拦截**确实来自 `no_time_rewind`**，非等级 gate 造成的空转；`lumos` min_tier=麻瓜出身未入学，等级充分。

### 3. 4 条新断言非空转（沙箱变异测试，每轮独立 `git archive`，跑完删除）
| 变异 | 期望 | 实测 | 退出 |
|---|---|---|---|
| **M0** 删除 `flags.erase("energy_loop_count")` | 2 条红 | `[spell] tick 后叠加计数归零（per-turn）: 期望 <0>，实际 <3>`　`[spell] 新回合可重新施放基础咒: 期望为假`　`失败=2` | 1 |
| **M1** 拦截分支错误自增 energy | #1 红 | `[spell] 拦截后叠加计数仍为 3: 期望 <3>，实际 <4>`　`失败=1` | 1 |
| **M2** `tick()` 过度重置（连 `time_rewind_count` 一起擦） | #4 红 | `[spell] 时间回溯终身一次性：跨回合仍被拦截: 期望为真`　`失败=1` | 1 |
- **M0 逐字复现了 controller 的反证（claim #5）**：两条消息、`失败=2`、`EXIT=1` 与声称完全一致，属实测属实。
- M1/M2 证明第 1 条与第 4 条断言各自捕获一类真实回归（拦截路径误自增 / 过度重置），非空转伴跑。
- 消息格式核对 `tests/assert.gd:10,25`：`"%s: 期望 <%s>，实际 <%s>"`、`"%s: 期望为假"`、`"%s: 期望为真"`，与反证文本一致。

### 4. 计划逐字一致（程序化比对，剥离尾部空行后 `==`）
| 计划位置 | 对应文件 | 结果 |
|---|---|---|
| 计划 1770–1876 代码块（含 Task 5 `tick()`） | `src/model/world_state.gd`（自 `VARS_REGRESSION` 起整段） | **EQUAL**（84 vs 85 行，差异仅文件尾换行） |
| 计划 2510–2667 代码块 | `tests/spell_test.gd`（全文件 156 行） | **EQUAL** |
| 计划 2724–2859 代码块 | `src/rules/spell_resolver.gd`（全文件 134 行） | **EQUAL** |

### 5. `bash tools/test.sh`（仓库内，单实例，退出码 0）
```
[world_tick] 断言=104 失败=0
[spell]      断言=227 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```
`[spell] 断言=227` 与声称 223→227（+4）一致；`[probe] 失败=1` 为 harness 故意失败探针，不计入总计。运行后 `git status --porcelain` 仍为空（仅生成 gitignore 的 `.godot/` 缓存）。

### 6. Task 8 计划兼容性（计划 2965–2970）
```
var w2 := make_world(5)
for i in 5: StateOps.apply(w2, [{"op":"cast_spell","spell_id":"lumos","conditions":{}}])
a.is_true(int(w2.flags.get("energy_loop_count",0)) <= 3, "低阶咒语叠加计数不超过上限")
w2.flags["energy_loop_count"] = 3
StateOps.apply(w2, [{"op":"cast_spell","spell_id":"lumos","conditions":{}}])
a.is_true(str(w2.flags.get("last_cast_narration","")).contains("上限"), ...)
```
- 5 次施法之间**无 `tick()`**；per-turn 重置不会触发 → 计数按「成功 1/2/3，其后被拦」封顶 3，`<=3` 恒真；探针 D 以 `SpellResolver` 直连仿真复现 `count=3` 与拦截文案含「上限」。**兼容：是。**
- 数据核对：`data/spells.json` 仅 `lumos`/`wingardium_leviosa` 挂 `no_unlimited_energy`（共享同一全局 flag），`time_turner` 挂 `no_time_rewind` 且 `forbidden=true`；`data/rumors.json` 的 `requires_flags` 仅 `ministry_access`/空，`tick()` 擦除 energy 键不会影响传闻筛选。

## 残留发现
| # | 严重度 | 位置 | 问题 | 建议 |
|---|--------|------|------|------|
| N1 | Minor（文档） | `src/model/world_state.gd:74`（⟷ 计划 1795） | 新增注释写「**第七十五条**裁定」，但设计文档 `哈利·波特·魔法纪元.md` 第七十五章是「正式启动界面」，与本守卫无关；正确出处为**第五十五章·魔法体系漏洞保护**（及第五十四章·现实性保护协议）/ HANDOFF §8#27。全仓库「第七十五条」仅此 2 处，属本次新增的误引 | 改为「第五十五条·魔法体系漏洞保护」或直接引用「HANDOFF §8 第 27 条」；计划同处一并改 |
| N2 | Minor（台账漂移） | `HANDOFF.md:10,176,236`；`docs/sdd/plan-01-core-foundation/progress.md:200,207` | 裁定已落地实现，但台账仍把 §8#27 记为「Task 8 开工前必须裁定」的**未决闸门**（第 10/176 行明示「先取得裁定再动 Task 8」），实现与台账不一致，后续 agent 可能重复阻塞 | 在 HANDOFF §8#27 与 progress.md 记录裁定结论（energy=per-turn、rewind=终身一次性）与实现 commit `a0bc1d3`，关闭该闸门 |
| N3 | Minor（信息级） | `src/model/world_state.gd:71-76` | per-turn 契约绑定在 `WorldState.tick()`：若 Task 8 回合引擎直接 `clock.advance_months()`/`advance_month()` 而不走 `tick()`，计数不会重置（`clock.advance_months` 在 `tests/model_test.gd`、`tests/world_tick_test.gd` 已被直接调用） | Task 8 实施时保证回合推进统一经 `WorldState.tick()`；必要时在该处加注释/断言 |
| N4 | Minor（覆盖） | `tests/world_tick_test.gd`（⟷ `tests/spell_test.gd:74-79`） | 新增的 tick 重置行为仅由 spell_test 通过手动 `master.tick()` 间接覆盖，world_tick_test 无 `energy_loop_count` 断言；另一 `no_unlimited_energy` 魔咒 `wingardium_leviosa` 未参与重置断言（共享同一 flag，风险低） | Task 8 测试加固时补一条 world_tick 层断言与 `wingardium_leviosa` 同 flag 用例 |

## 未验证/存疑
- **Task 8 `StateOps` 尚未实现**，无法端到端跑其计划测试；兼容性结论基于计划代码块（中间无 `tick()`）与探针 D 的 `SpellResolver` 直连仿真，未验证 `StateOps.apply(cast_spell)` 内部是否引入额外 `tick()`/时钟推进。
- **存档跨回合边界**未端到端验证：存档只存 flags，不存「本回合已成功施法次数」的时间戳。行为为：回合中途存档→读档→继续施法沿用计数（探针 E），读档后调用 `tick()` 则归零。自洽，但若 Human 期望「读档即视为新回合」需另行裁定；本轮未列为缺陷。
- `flags.erase` 使键**不存在**（而非 0），本次核对无任何代码使用 `flags.has("energy_loop_count")` 或直接下标读取，故无现状隐患；未来 Task 8+ 若新增「遍历 flags 展示」类消费方需注意缺失键语义（信息级，未验证）。
- 未穷举仓库外/未来写入 `world.flags` 的第三方路径（当前 `src/` 全量 grep 仅 `spell_resolver.gd:122,124,126,133` 与 `world_state.gd:126` 写入，已逐条核对）。
- 严格只读：未执行任何 git 写操作与仓库文件修改；三个沙箱（`/tmp/hali-ruling-probe`、`/tmp/hali-ruling-sbx`、`/tmp/hali-ruling-mut`）跑完已删除，仓库 `git status --porcelain` 空、`git diff --stat HEAD` 空。（`/tmp/hali_cmp`、`/tmp/hali_nobreak`、`/tmp/hali_probe` 为前几轮复审遗留，非本轮产物，未触碰。）

---

# 裁定实现修复 scoped 复审（N1/N2 关闭确认，提交 153487c）

# 裁定实现修复 scoped 复审

复审者：reviewer subagent（独立只读复审）　模型：deepseek-flash　范围：a0bc1d3..153487c

## 结论
- N1：**CLOSED**
- N2：**CLOSED**
- 无逻辑改动：**是**
- 总评：**通过**

## 证据

### 1. diff 范围核对（`git diff --name-status/--numstat a0bc1d3..153487c`）
```
M HANDOFF.md                                   |  9 +-   (4 处改：§0 状态、Task 表 8 行、§6 前提、§8#27)
M README.md                                    |  2 +-   (Task 8 行去掉「先裁定能量叠加语义」)
M docs/sdd/plan-01-core-foundation/progress.md |  9 +    (新增裁定关闭记录)
M docs/sdd/plan-01-core-foundation/task-7-review.md | 110 +  (追加上一轮裁定复审记录，纯新增)
A docs/sdd/plan-01-core-foundation/task-7-ruling-review-brief.md | 61 +  (上一轮复审简报工件)
M docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md | 2 +-  (仅 1795 行注释，与实现镜像)
M src/model/world_state.gd                     | 2 +-   (1+/1−，仅第 74 行注释)
```
- **代码面唯一改动**：`git diff a0bc1d3..153487c -- src tests tools` 只输出 `world_state.gd:74` 一行注释替换；`tests/`、`tools/`、`data/` **零改动**（`--numstat -- tests` 为空）。
- `flags.erase("energy_loop_count")` 及其上下文（`clock.advance_month()` 后、`time_rewind_count` 不重置）与 `a0bc1d3` **逐字一致**，未随注释一起被触碰。
- 无新增/删除代码行、无 mode 变更、无越界文件；`progress.md`、`task-7-review.md`、简报为文档/审查工件。
- 仓库镜像一致性：`docs/sdd/plan-01-core-foundation/` 与 gitignore 工作区 `.superpowers/sdd/2026-09-18-.../` 的 `task-7-review.md`、`task-7-ruling-review-brief.md` md5 完全相同（`cab9f5c0…` / `1fb6a23f…`），无分叉。

### 2. N1 关闭证据
```
$ grep -rn "第七十五条" src tests docs/superpowers    →  无命中（exit=1）
$ grep -rn "七十五|第75条|75 条" src tests docs/superpowers HANDOFF.md README.md
  src/rules/character_creation.gd:200  # 哑炮：无魔法、无魔杖（第七十五章）        ← 正当引用
  tests/creation_test.gd:81 / tests/registry_test.gd:14 / 计划 79,454,606,621,1919,2011,2427,2479,4290  ← 均为「第七十五章启动界面」正当引用
```
- 注释已改为（`src/model/world_state.gd:74`，计划 1795 同步）：
  `# per-turn 语义（第五十五条·魔法体系漏洞保护 / HANDOFF §8 第 27 条裁定）：低阶咒语叠加计数每回合（月）重置；`
- **引用正确性独立核实**：设计文档 `哈利·波特·魔法纪元.md:589` = `## 第五十五章·魔法体系漏洞保护`，正文即「必须防止：低阶咒语无限叠加变成无限能量…时间转换器无限回溯」；`:755` = `## 第七十五章·正式启动界面`。旧注释确属误引，新引用精确。
- 仅存残留命中位于**复审工件自身对 finding 的引述**（`docs/sdd/.../task-7-review.md:417`、`progress.md:220`、本轮简报），符合 brief 的排除口径。

### 3. N2 关闭证据
```
HANDOFF.md:10   …第 8 节第 27 条闸门（energy_loop_count/time_rewind_count 生命周期）**已由 Human 裁定并落地**（per-turn / 终身一次性，提交 a0bc1d3）…
HANDOFF.md:150  | 8 | 叙事接口 + 状态操作 + 反刷成长 + 回合引擎 | ⬜ 下一步 | — |
HANDOFF.md:176  > ✅ 第 8 节第 27 条的闸门…已由 Human 裁定并落地（per-turn / 终身一次性，a0bc1d3）。
HANDOFF.md:235  27. ~~（Task 7 Important）~~ **已裁定并落地（Human，提交 a0bc1d3）**：per-turn 语义 + tick() erase…time_rewind_count 终身一次性…
README.md:27    | 8 | 叙事接口 + 状态操作 + 反刷成长 + 回合引擎 | 下一步 |
$ grep -rn "先裁定|开工前必须裁定|必须先裁定|未决" HANDOFF.md README.md   →  无与 §8#27 相关命中
```
- §8#27 四处（`§0 一句话状态` / Task 表 / `§6 下一步` / `§8` 条目本体）均已转为「已裁定并落地」，并附裁定内容、实现 commit、断言增量（223→227）、以及 N3 约束；`§8` 原条目标题加删除线 + 原子项保留可追溯。README Task 8 行不再要求先裁定。

### 4. 测试复跑（仓库内，只读，退出码 0）
```
[world_tick] 断言=104 失败=0
[spell]      断言=227 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
全部通过。
EXIT=0
```
- `[spell] 227/0` 与台账声称的 223→227 一致；`[probe] 失败=1` 为 harness 故意失败探针，不计入总计。注释改动未改变任何结果。
- 运行后 `git status --porcelain --untracked-files=all` 为空、`git diff --stat HEAD` 为空；本轮**未做任何文件修改、未做任何 git 写操作**。

## 残留发现
| # | 严重度 | 位置 | 问题 | 建议 |
|---|--------|------|------|------|
| N3 | Minor（设计约束，**不阻塞**） | `src/model/world_state.gd:71-76`；HANDOFF:235 | per-turn 契约只在 `WorldState.tick()` 内兑现。若 Task 8 回合引擎绕过 `tick()` 直接 `clock.advance_month(s)`（`clock.advance_months` 在 `tests/model_test.gd:27`、`tests/world_tick_test.gd:27` 已被直接调用），计数不会重置，且**失败是静默的**（无报错、无返回差异），仅凭散文约束易被后续 worker 忽略 | **处置：接受为已记录的约束，不重开**。Task 8 落地时：(a) 将所有回合推进收敛到 `WorldState.tick()`（HANDOFF:235 已写明「勿直接 advance_month」）；(b) 补一条端到端断言「经回合引擎推进一回合后 `energy_loop_count` 归零/`lumos` 可重施」，把契约从文档升级为可执行测试；(c) 可选在 `clock.advance_month/advance_months` 文档注释标注「仅 `WorldState.tick()` 应调用」 |
| N4 | Minor（测试覆盖缺口，**不阻塞**） | `tests/world_tick_test.gd`（无 `energy_loop_count` 断言）；`tests/spell_test.gd:73-82` | 本轮重置行为只有 spell_test 通过手动 `master.tick()` 间接覆盖，**world_tick 层零断言**（层与行为的归属错位）；另一 `no_unlimited_energy` 魔咒 `wingardium_leviosa` 未参与任何叠加/重置断言（全仓库仅 `model_test.gd:47-50` 的 `learn_spell`），共享同一全局 flag 的语义未被独立验证 | **处置：接受为 Minor，顺延至 Task 8 测试加固批次**（Task 8 本就要扩测试）。建议：(a) `tests/world_tick_test.gd` 增 1 条 `tick()` 后 `energy_loop_count` 键不存在/归零断言，把覆盖放到正确层级；(b) `spell_test` 增 1 条 `wingardium_leviosa` 与 `lumos` **共享计数器**的用例（A 咒叠到上限后 B 咒同样被拦），封死「两咒各自计数」的误解 |
| N5 | Trivial（台账表述） | `docs/sdd/plan-01-core-foundation/progress.md:206` | 历史条目仍写 `Task 7: 移交人类批次 / Task 8 前必须裁定`，关闭记录在 8 行后的 `:214`。progress.md 为时序台账，原样保留可接受，但快速扫描者可能停在此行再次误判为未决闸门 | 建议在该行后追加半句「（已裁定，见下 214 行）」，或给标题加删除线；纯文案、无行为影响，可由 Task 8 收尾时一并处理 |

**备注**：以上 N3/N4/N5 均为**非阻塞**项，N1/N2 关闭判定不受其影响；本轮唯一新发现为 N5。
