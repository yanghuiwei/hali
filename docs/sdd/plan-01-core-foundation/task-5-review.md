# Task 5 审查记录（第一轮完整审查 + 修复轮 1 + 修复轮 2 scoped 复审）

> controller 从三个独立 reviewer subagent 的输出原样转存（模型均为 deepseek-flash）。
> 第一轮范围 `dcf25e1..23e67cd`；修复轮 1 `23e67cd..f9038ca`；修复轮 2 `f9038ca..24d5d43`。

---

# 第一轮完整审查

# Task 5 审查记录

审查者：reviewer（独立只读子代理）　模型：deepseek-flash　范围：dcf25e1..23e67cd

## 结论
- 规格符合：✅
- 裁定：**Approved with findings**
- 关键数字：Critical=0，Important=4，Minor=9

审查方式：只读（read / 只读 bash + `bash tools/test.sh`）；未修改任何文件、未做任何 git 写操作。测试后 `git status --porcelain` 为空，工作区干净。

## 证据

### 1) diff 摘要（`git diff --stat dcf25e1..23e67cd`，共 12 文件 +339/−16）
```
data/locations.json                | 23 +   (A)
data/rumors.json                   | 18 +   (A)
docs/.../2026-09-18-...-foundation.md | 32 ± (M, 仅 rumors 代码块 16 行加 label)
src/core/registry.gd               |  2 +   (M, TABLE_FILES 追加 locations/rumors)
src/core/rng_service.gd            | 46 +   (A)  + .uid
src/model/world_state.gd           |102 +   (M, add_fact 之后追加 tick 段)
tests/clock_test.gd                | 50 +   (A)  + .uid
tests/run_tests.gd                 |  2 +   (M, SUITES 追加两套件)
tests/world_tick_test.gd           | 77 +   (A)  + .uid
```
`git show --name-status 23e67cd` 与上表完全一致；`git status` 干净；无越界文件（见发现表末与“对计划修正的裁定”）。

### 2) 逐字一致性（用脚本提取计划 Task 5 各代码块与仓库文件做规范化比对）
```
clock_test.gd:        IDENTICAL (50 lines)
world_tick_test.gd:   IDENTICAL (77 lines)
rng_service.gd:       IDENTICAL (46 lines)
registry TABLE_FILES: IDENTICAL (11 lines)
world_state tick chunk: IDENTICAL (101 lines)
locs equal(plan vs data): True
rumors equal minus label: True ; plan rumor has label keys: True
labels: count=16 unique=16 nonempty=True ; ids unique=True n=16
key order: 全部为 (id,label,category,text,weight,major,min_year,zones,requires_flags)，label 位于索引 1
```
即 `RngService`、`WorldState.tick()` 全段、两个测试、`TABLE_FILES`、`locations.json` 与计划逐字一致；`rumors.json` 相对计划仅多 `label`。

### 3) label 修正的独立核对
- `src/core/registry.gd:76-78`：`if str(e.get("label","")).is_empty(): errors.append("%s/%s: 缺少 label")` —— 确实强制 label。
- `tests/registry_test.gd:55-56`：`no_label := Registry.from_tables({"eras":[{"id":"a"}]})` → 断言 `validate()` 含 `"缺少 label"`。
- 16 条 label 非空、唯一、位置正确；与 `task-5-brief.md` 的 16 行对照表**逐字相符**（脚本比对 16/16 True）。
- 除 label 外无夹带：locations 与计划完全相同；rumors 去掉 label 后与计划（修正前语义）完全相同；无额外/缺失字段、无顺序改动、无 id 改动。

### 4) 数据侧独立核对（python 读取 data/*.json）
```
道 16 条 rumor zones 全部非空；london_muggle 只出现在 daily_life
4 条 major 的 zones 均不含 london_muggle（azkaban/ministry/knockturn/gringotts/diagon/hogwarts/hogsmeade）
requires_flags 非空仅 ministry_internal: ["ministry_access"]
grep ministry_access src tests → 仅 data/rumors.json 出现；src 中唯一 flags 写入是 flags["last_major_turn"]
locations=21 项，danger_label ∈ {安全区,低危险区,中等危险区,高危险区,极度危险区}
```
### 5) `bash tools/test.sh` 原始关键行（本次单实例复跑）
```
== 2/3 单元测试 ==
[probe] 故意失败: 期望 <2>，实际 <1>
[probe] 断言=1 失败=1        ← harness 自检“断言库能捕获失败”，其失败数不计入总计（run_tests 取 a.report("harness")=0）
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=15 失败=0
[magic_level] 断言=22 失败=0
[model] 断言=49 失败=0
[clock] 断言=28 失败=0
[world_tick] 断言=101 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```
交叉校验：world_tick 101 = 1(validate)+2(表项数)+4(danger_label)+1(12月=1年)+24×3(is Array + 2×has_key，说明 24 次 tick 每次都有事件)+1(turn)+1(log)+7(world_vars)+1(major_count)+10(确定性)+1(leaked)。数字自洽，未出现断言被跳过。

### 6) 逻辑独立复核（代码+数据推演，非仅依赖测试）
- 确定性：`registry.ids("rumors")` 返回已排序 `PackedStringArray`（registry.gd:52-57）；drift 噪声按键命名流 `drift_<key>` 抽取，因此 `world_vars.keys()` 的插入顺序**不影响**结果；`JsonUtil.normalize` 重建 Dictionary 时按 `keys()` 顺序写入，JSON.stringify/parse 保序 → create 与 from_dict 两条路径顺序一致。同 seed 同输入 → tick 输出可复现（w0/w1 测试亦通过）。
- clamp/发散：`clampf(...,0.0,1.0)` 每键每月都执行；噪声 ∈ [−0.02,0.02)，AR(1) 系数 0.95 → 有界且不发散；输入全为有限数，无 NaN 来源。
- `chance(p=0)` 必假、`chance(p=1)` 必真（randf()∈[0,1) 与 clampf 语义）；`stream_pick([])`→null（不建流）——与测试一致。
- `state_dict`→`load_state`：先 `rng.seed` 后 `rng.state` 顺序正确（state 赋值覆盖 seed 派生的初始状态），已快照的流可续跑一致（clock_test:43-48 通过）。
- `player.age_months += 1` 与 `clock.advance_month()` 非重复计数：前者是玩家月龄、后者是世界时钟，计划注释明确“玩家与世界同时变老”。

## 发现

| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|
| 1 | Important | src/model/world_state.gd:86-123 | `major_ready` 在循环外只算一次，同月最多抽 2 条（`rumor_count=2`），两条都可能是 major 且都通过 `major_gate` → 同一月落地 2 起重大事件（间隔 0 月），实质违背 `MAJOR_EVENT_GAP`「至少相隔 12 个月」。计划原文即如此，非实现偏离 | 代码推演；ministry_of_magic 候选 5 条含 2 major：epic 风格下 P≈8.1e-4/月（240 月约 18%），mixed≈6.7e-5/月（240 月约 1.6%） | 每次 pick 前重算 `major_ready`，或命中 major 后 `break`；并在测试中断言相邻 major 的 turn 差 ≥12 |
| 2 | Important | data/rumors.json（全表）+ Interfaces vs src/model/world_state.gd:113-116 | `weight` 在数据与接口契约中都存在，但 `tick()` 用 `stream_pick` 均匀抽取，`grep -rn weight src tests` 零引用 → 声明的稀有度旋钮完全失效（daily_life=20 与 major=1 权重等价） | grep 全仓无引用；计划 Step 6 同样未用（计划级缺口，非实现偏离） | 二选一并落到计划：实现加权抽取；或从契约中删除 `weight`，明确稀有度由 `major_gate` 负责（当前 major 仍稀少，故影响可控） |
| 3 | Important | src/model/world_state.gd:20,162,182；src/core/rng_service.gd:31-45 | `rng_state` 是死字段：`to_dict/from_dict` 读写它，但没有任何地方写入；`RngService.state_dict()/load_state()` 在 src 中零调用（仅 clock_test 使用）。Interfaces 承诺的「存档可恢复随机流」在 WorldState 层未落地。当前 tick 靠 `game_seed + turn*7919` 重新派生种子，**碰巧**仍是确定性的 | grep：`state_dict`/`load_state` 仅 tests/clock_test.gd；`rng_state` 仅 to_dict/from_dict | 要么把 `rng_state` 真正接入存档（tick 复用长驻 RngService），要么删除该字段并把计划改成“派生式确定性”并加注释 |
| 4 | Important | src/core/rng_service.gd:40-45 | `load_state()` 只恢复 `_streams`，**不恢复 `seed_value`**；存档后首次访问“快照里没有的新命名流”时，会用对象自身的 `seed_value`（默认 0）而非原始种子 → 违反「存档可恢复随机流」契约。单测用 `RngService.new(42)` 恰好同 seed，掩盖了该缺陷 | 代码：`seed_value` 未被 `state_dict` 记录也未被 `load_state` 赋值；测试构造参数与原始 seed 相同 | `state_dict` 记录 `seed_value`，`load_state` 一并恢复；补一条“载入后首次新建流”的测试 |
| 5 | Minor | tests/world_tick_test.gd:47-54 | `major_count <= 20` **恒真空转**：w2 复用 `p.location_id = "london_muggle"`，而 4 条 major 的 zones 均不含 london_muggle，candidates 恒无 major → 计数恒 0。该断言对“双闸门”零验证 | 数据核对（见证据 4）；240 次 tick 内无任何断言 | w2 改到 `diagon_alley` 或 `ministry_of_magic`，并断言 major 计数落在合理区间**且**相邻 major 间隔 ≥12 月 |
| 6 | Minor | tests/world_tick_test.gd:67-75 | 信息保护断言**恒真空转**：`PlayerState.new_default()` 的 `location_id=""`，16 条 rumor 的 zones 全非空 → candidates 恒空 → 永不产生事件。另外 `tick()` 完全不读 `bloodline_id/house_id`（测试设了却无效），且 `ministry_access` 在 src 中无人授予 → 「魔法部内幕」在本任务中不可达 | 代码 + 数据核对；`grep ministry_access src` 仅 data | 把 w3 的 location 设为 `ministry_of_magic`，断言“有事件但 category≠魔法部内幕”，并做带/不带 flag 的对照；身份门控（血统/学院）应显式排入后续任务或删掉误导性测试名 |
| 7 | Minor | tests/world_tick_test.gd:25 | `var rng := RngService.new(w.game_seed)` 声明后从未使用（死变量，仅告警不报错） | grep 该文件仅此一处 `rng` | 删除 |
| 8 | Minor | src/model/world_state.gd:147-148 | 裁剪只作用于 `log`，`history` 无上限且随 `to_dict` 入存档，与注释“避免存档无限膨胀”部分不符；另外 `log` 内条目 schema 不一致（rumor 事件含 category/major/turn，`mundane` 条目只有 turn/kind/text） | 代码；`log` 与 `history` 都在 to_dict 中 | 同步限制 history（或按 kind 分类存），并统一 log 条目结构（缺 category/major 时给默认值） |
| 9 | Minor | src/core/rng_service.gd:13 | `rng.seed = hash("%d|%s" % [seed_value, name])`：Godot `String::hash()` 为 32 位 → 有效熵仅 2^32；长局中每回合新建 2 个 RngService、约 12 次 hash/月，600 月约 0.6%、2400 月约 8.5% 概率出现跨流/跨 seed 生日碰撞（后果是随机序列相关，不损坏存档）。分隔符本身无结构歧义 | 代码；位宽未实测（见“未验证”） | 用 64 位混合（如 `hash(name)` 与 seed 做 64 位混洗/异或拼接）降低碰撞率 |
| 10 | Minor | src/model/world_state.gd:113-121 | 两次 `stream_pick("pick_0"/"pick_1", candidates)` 相互独立，第二次可能抽到与第一次**同一条** rumor → 同一传闻在同月重复进 events/log | 代码 | 第二次 pick 排除已选条目（或去重后 append） |
| 11 | Minor | src/model/world_state.gd:144 | `player.age_months += 1` 无条件执行（不判 `player.alive`），且与 `clock` 各自推进：直接调 `advance_months(12)` 后跑 24 次 tick，clock 走 36 月而月龄只 +24（测试即此情形） | 代码 + world_tick_test:34-41 | 明确“唯一时间推进入口”（把 age 推进并入 clock 结算），或至少加 `alive` 判断并注释二者关系 |
| 12 | Minor | tests/clock_test.gd:48；tests/world_tick_test.gd:32 | 空转断言：`a.eq(JSON.stringify(snapshot).length() > 0, true, ...)`、`a.is_true(events is Array, ...)`（后者编译期恒真，循环 24 次贡献 24 个无信息断言） | 代码 | 换成有区分度的断言（如 snapshot 含 seed/state 键且 state≠seed 派生初值；events 元素 schema 校验） |
| 13 | Minor | tests/world_tick_test.gd（整体）/ model_test.gd | 缺 WorldState 级“存档续跑”测试：没有 `tick → to_dict → JSON → from_dict → tick` 与不中断 tick 的逐事件对比。现有 w0/w1 只验证两个新世界一致，`state_dict/load_state` 只在 RngService 隔离层验证 | 代码；brief 第 3/5 点 | 增加 24 个月后存档、读档、再跑 12 个月的事件序列相等断言 |

越界检查：本提交改动文件全部落在 Task 5 计划文件清单内（含简报授权的计划文档同步修正与三个 `.gd.uid`），未触碰 `data/` 其它 7 张表、`src/rules/`、`money.gd/player_state.gd/game_clock.gd/json_util.gd`、`HANDOFF.md`、`README.md`。✅

## 对计划修正的裁定

**判定：修正正当、唯一合理、无夹带。**

1. **契约确实强制 label**：`Registry.validate()`（registry.gd:76-78）对每张表每个条目做 `str(e.get("label","")).is_empty()` 检查并追加 `"<表>/<id>: 缺少 label"`；`tests/registry_test.gd:55-56` 明确断言“缺 label 必须报错”。若按计划原样写入无 label 的 rumors，`world_tick_test` 的 `a.eq(reg.validate().size(), 0)` 必红，且这是真实数据缺陷，不能靠放宽 `validate()` 掩盖（那会破坏 Task 2 已建立的完整性契约并让既有断言失效）。因此“给数据补 label”是唯一不破坏既有契约的修法。
2. **同步修改计划原文正确**：仅改数据会让计划与代码分叉，误导后续任务；提交里计划代码块 16 行同步补 `label`，脚本比对确认计划与 `data/rumors.json` 现已**完全等价**（label 之外零差异）。
3. **label 内容合规**：16 条齐备、唯一、非空，插在 `"id"` 之后（索引 1），与简报对照表逐字一致；语义为简短中文标题，与 `text/category` 相符，无重复 id。
4. **无夹带**：`data/locations.json` 与计划逐字相同；`rumors.json` 除 label 外字段/顺序/取值/条目数（16）完全不变；改动文件清单与简报 `git add` 清单一致；无额外脚本、无格式化噪声、无 `.godot` 或缓存文件入库。

## 未验证/存疑

- `hash()` 的位宽未做实测（结论基于 Godot `String::hash()` 返回 uint32 的公开语义）；若实际为 64 位，发现 #9 应降级为“提示”。
- 发现 #1（同月双 major）未做端到端复现（需另写探针脚本，受只读约束），仅由候选集概率与代码路径推演；建议 controller 在裁定后用一次临时探针或新测试确认。
- `clock_test` 的续跑断言无法区分“`state` 随抽取推进”与“`state` 恒定”：两者在该测试下都会通过（引擎语义上 state 会推进，故只列存疑，不计为发现）。
- JSON → float → `JsonUtil.normalize` 对 `world_vars` 浮点的位级往返（精度）未断言；理论影响仅限于 world_vars 末位、不会改变事件序列（事件种子由 `game_seed+turn` 派生，不依赖 world_vars）。`rng_state` 若日后接入，其 64 位 `seed/state` 的 JSON 往返精度亦建议补一条断言。
- 计划文档级缺口（`weight` 未用、`rng_state` 未接线、同月双 major）与实现代码逐字一致，**属计划自身需修订**；本次实现严格遵循简报“逐字照抄、不要自由发挥”，故这些不计为实现的规格违背，但建议在 Task 6 之前先对计划做一次小幅修正裁定。
- `[probe] 断言=1 失败=1` 是 harness 有意自检（`probe.report()` 返回值被 harness 自身断言），不计入总计失败；已确认与 Task 5 无关。

---

# 修复轮 1 scoped 复审

# Task 5 修复轮 scoped 复审

复审者：reviewer（独立只读子代理）　模型：deepseek-flash　范围：23e67cd..f9038ca

## 结论
- 第一轮 Important #1（同月双 major）：**ADDRESSED**（结构上正确；但测试对其无判别力，见 N2）
- 第一轮 Important #4（`load_state` 不恢复 `seed_value`）：**ADDRESSED**（新 schema 正确；旧 schema 静默失效，见 N3；JSON 端到端另有 N1）
- Minor #5/#6/#7（空转测试与死变量）：**#5、#7 已消除空转；#6 部分消除**（`events_seen > 0` 已激活，但 `is_false(leaked)` 仍是恒真）
- 有无新问题/夹带：**无夹带**；**有新问题**（N1 Important，N2/N3/N4 Minor）
- 总评：**通过**（修复项本身成立、无 Critical；N1 属既有隐患且当前无生产调用路径，建议排入后续任务而非拦下本轮）

## 证据

### 1) diff 逐行核对（`git diff 23e67cd..f9038ca`）
```
M docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
M src/core/rng_service.gd      (+13/−? )
M src/model/world_state.gd     (+1)
M tests/clock_test.gd          (+5)
M tests/world_tick_test.gd     (+14/−?)
```
- 5 个文件，全部在 Task 5 计划清单内；无 `.uid`、无 `data/`、无越界文件、无格式化噪声。
- 计划文档 6 个 hunk 全部落在 Task 5 的四个代码块（clock 测试、world_tick 测试、`RngService`、`tick()`）+1 行注释，无其它计划改动。
- 计划↔代码逐字比对（脚本提取围栏代码块做规范化比较）：
  - `tests/clock_test.gd` 与计划块：`equal: True`
  - `tests/world_tick_test.gd` 与计划块：`equal: True`
  - `src/core/rng_service.gd` 与计划块：`equal: True`
  - `const VARS_REGRESSION … tick() 结束` 与计划块（102 行）：`equal: True`
- 结论：改动内容与 controller 声称的 5 条一一对应，**无夹带**。

### 2) 修复 #1 的结构正确性（独立推演 + 沙箱反证）
- 代码路径唯一：`grep` 全仓，`events.append` 中带 `major` 的只有 `world_state.gd:113-135` 一处；`add_fact("major")` 在 src 中唯一调用点即该处（另一处是 `model_test.gd` 的手工调用）。**不存在第二条落地 major 的路径**。
- `break` 位于 `add_fact(...)` 之后、`flags["last_major_turn"] = clock.turn` 之后；同月第二轮循环不可达 → 同月至多 1 起 major。
- `major_ready` 在循环外只算一次确实会“过期”，但该过期只在“当月已落地 major 后还要再抽一轮”时才被用到，而 `break` 恰好切断了这一轮 → 被覆盖。
- 跨月无累积：major 落地后 11 个月内 `major_ready=false`，major 模板在候选集构建阶段就被剔除；种子 312（沙箱实测）出现 `min_gap=12`，即下界被真实触及。
- 沙箱反证（把 `break` 删掉的临时副本，非仓库文件）：
```
=== FIXED (with break) ===           === NOBREAK ===
SEED 38  count=6 min_gap=20 multi=[]  SEED 38  count=7 min_gap=0 multi=[[54,2]]
SEED 169 count=5 min_gap=13 multi=[]  SEED 169 count=6 min_gap=0 multi=[[187,2]]
SEED 312 count=6 min_gap=12 multi=[]  SEED 312 count=7 min_gap=0 multi=[[27,2]]
SEED 713 count=2 min_gap=214 multi=[] SEED 713 count=3 min_gap=0 multi=[[9,2]]
SEED 906 count=6 min_gap=20 multi=[]  SEED 906 count=7 min_gap=0 multi=[[5,2]]
SEED 1234 count=2 min_gap=82 multi=[] SEED 1234 count=2 min_gap=82 multi=[]
```
  即：删除 `break` 会真出现同月双 major（min_gap=0），而当前测试种子 1234 **恰好不触发** → controller 的“诚实披露”属实（`min_gap` 断言在此种子下无法捕获该回归）。

### 3) 修复 #4 的正确性与兼容性
- 新 schema（沙箱实测）：
```
PROBE snap_seed_value_type=2 streams_keys=["world"]
PROBE new_stream_via_json=528154 expected=528154      # 恢复后新流沿用原 seed
E r9_seed0_newstream=475519  seed42_newstream=528154  # 反证：不恢复 seed_value 则退回构造 seed
```
  与 controller 给出的反证数值完全一致 → `clock_test` 新增断言**有判别力**。
- 旧 schema（无 `seed_value`/`streams`）实测：
```
PROBE old_schema seed_value=0 streams=[]
PROBE old_schema next=362731 fresh0=362731 fresh1=729198
```
  → 不报错、静默**什么都不恢复**（`seed_value` 保持对象原值、流全丢）。属向后不兼容，但当前无历史存档（`RngService` 本任务才建、`WorldState.rng_state` 从未写入），实际影响低。
- `state_dict → JSON.stringify → parse_string → load_state` 端到端**不一致**（沙箱实测）：
```
JSON total_batches=41 stream_value_mismatch=82 seq_mismatch=41
JSON examples=[k, name, seed_raw, seed_parsed, state_raw, state_parsed]
  [0,"world",2883209391,2883209391,3013343639311151445,3013343639311151104]
```
  `rng.state` 为 int64，`JSON.parse_string` 一律转 double（>2^53）→ 每次 500 抽内序列必分叉（41/41）。`seed`（32 位）与 `seed_value`（小整数）通常无损，但 `seed_value` 极大时也失真（实测 `12345678901234567 → 12345678901234568`）。
- `load_state` 是**合并而非替换**：预置流 `stale` 在恢复后仍存在（`streams_after_load=["stale","world"]`）。

### 4) 测试去空转的实效（`bash tools/test.sh` 单实例复跑）
```
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=15 失败=0
[magic_level] 断言=22 失败=0
[model] 断言=49 失败=0
[clock] 断言=29 失败=0
[world_tick] 断言=104 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```
- 断言数自洽：`clock 28→29`（+1 = r9）；`world_tick 101→104`（+3 = `major_count>=1` / `min_gap>=12` / `events_seen>0`）。
- 被断言覆盖的**真实取值**（沙箱读取同一 seed/配置）：
```
PROBE major_count=2 min_gap=82 major_turns=[67,149] multimonth=[]
PROBE events_seen=27 categories={神奇生物:14, 国际:6, 魔法部动态:6, 战争:1}
```
  → `major_count>=1` 与 `events_seen>0` 在当前 seed 下**成立且确定**（派生自固定 seed），`min_gap=82≥12` 恒真。
- 但 `is_false(leaked)` 仍为恒真：`ministry_internal` 的 `requires_flags=["ministry_access"]` 在 src 中无人授予（`grep` 仅 data 出现），该类目从未进入候选集（40 个月类别分布实测无“魔法部内幕”）→ 该保护断言不可证伪。
- `min_gap>=12` 对修复 #1 **无判别力**：见第 2 节反证；且实测 `min_gap=82` 远离阈值，即使有轻微间隔回归也未必报警。

### 5) 计划同步
Step 1（两个测试）、Step 3（`RngService`）、Step 6（`tick()` 含 `break`）三处代码块与仓库文件**逐字相等**（脚本比对 `equal: True`），计划 diff 无其它内容。

### 6) 只读约束自证
所有写入（探针脚本、`break` 删除副本、Godot 导入缓存）都在 `/tmp/hali_probe`、`/tmp/hali_nobreak` 两个副本内；仓库 `git status --porcelain` 运行前后均为空，HEAD 始终 `f9038ca`，未做任何 git 写操作。

## 残留发现（含第一轮未处置项）
| # | 严重度 | 位置 | 问题 | 建议 |
|---|--------|------|------|------|
| N1 | Important | `src/core/rng_service.gd:31-47`；`tests/clock_test.gd:52` | `state_dict → JSON.stringify → parse_string → load_state` 端到端不一致：`rng.state` 为 int64，JSON 解析成 double 后精度丢失（实测 41/41 批次后续序列分叉）；`clock_test` 只断言 `JSON.stringify(...).length()>0`，未做往返，掩盖了该缺陷。属**既有**隐患（非本轮引入），但正是 #4 声称的“存档可恢复随机流”契约的实际落地形态 | 把 `seed/state` 以十进制字符串（或高低 32 位两个字段）入档，`load_state` 解析回 int64；补 `state_dict→JSON→parse→load_state→序列一致` 的端到端断言。若 `rng_state` 正式接线（残留 #3），此项升级为 Critical |
| N2 | Minor | `tests/world_tick_test.gd:49-60` | `min_gap>=12` 对 #1 无判别力：seed 1234 下删掉 `break` 输出完全相同（`count=2,min_gap=82`）。沙箱扫描 1..2000 找到 13 个会触发同月双 major 的种子（`min_gap=0`），如 38/169/312/713/906 | 把 w2 的 seed 由 `1234` 改为 `38` 或 `906`（修后 `min_gap=20`，删 `break` 则 `0`），该断言即可真正锁死 #1；或直接构造确定性双 major 用例 |
| N3 | Minor | `src/core/rng_service.gd:41-47` | 旧 schema 静默失效（不报错、`streams` 全丢）；`load_state` 合并而非替换（残留 `stale` 流）；`RngService` 无 schema 版本号；`seed_value` 超 2^53 时 JSON 往返失真 | 加版本字段或对旧扁平 schema 做兼容分支/显式告警；恢复语义明确为“替换”；`seed_value` 一并字符串化 |
| N4 | Minor | `tests/world_tick_test.gd:73-84` | `is_false(leaked)` 仍恒真：`ministry_access` 全仓无人授予，`ministry_internal` 永不在候选集；`events_seen>0` 只证明“有事件”，不证明“该泄露却没泄露” | 做带 flag 的阳性对照（先 `flags["ministry_access"]=true` 断言会命中，再移除断言不命中），或删除误导性断言并显式排入身份/权限门控任务 |
| R2 | Important | `data/rumors.json` 全体 + `src/model/world_state.gd:113-116` | 第一轮 #2 未处置：`weight` 声明但 `stream_pick` 均匀抽取，稀有度旋钮仍失效 | 实现加权抽取，或删字段并在契约中说明由 `major_gate` 负责稀有度 |
| R3 | Important | `src/model/world_state.gd:20,163,183` | 第一轮 #3 未处置：`rng_state` 仍是死字段，`state_dict/load_state` 在 src 中零调用；「存档可恢复随机流」在 `WorldState` 层未落地。与 N1 叠加后，一旦接线就会暴露序列分叉 | 二选一：接入长驻 `RngService` 并连同 N1 一起修；或删除字段、计划改述为“派生式确定性”并加注释 |
| R8 | Minor | `src/model/world_state.gd:147-148` | 未处置：`history` 无上限、`log` 条目 schema 不一致 | 同 #8 建议 |
| R9 | Minor | `src/core/rng_service.gd:13` | 未处置：`String::hash()` 32 位，跨流/跨 seed 生日碰撞风险 | 改 64 位混合 |
| R10 | Minor | `src/model/world_state.gd:113-121` | 未处置：同月两次 pick 可命中同一 rumor，重复入 events/log（`break` 只挡第二条 major） | 第二次 pick 排除已选条目 |
| R11 | Minor | `src/model/world_state.gd:144` | 未处置：`age_months` 无条件推进、与 `clock` 各自计时 | 统一时间推进入口或加 `alive` 判断 |
| R12 | Minor→建议升 Important | `tests/clock_test.gd:52`；`tests/world_tick_test.gd:32` | 未处置：`JSON.stringify(snapshot).length()>0` 与 `events is Array` 是空转断言；其中前者正是 N1 未被发现的原因 | 换成有区分度的往返/结构断言 |
| R13 | Minor | `tests/world_tick_test.gd`（整体） | 未处置：仍无 `tick→to_dict→JSON→from_dict→tick` 的 WorldState 级存档续跑对比 | 补该测试；它同时能兜住 N1/R3 |

严重度变化小结：R2、R3 维持 Important（未处置）；R3 因 N1 存在而风险上升；R12 建议由 Minor 升为 Important（其空转掩盖了 N1）；R8–R11、R13 维持 Minor。无降级项。

## 未验证/存疑
- Critical：**无**（故无最小复现）。
- N1 的修复可行性未实测（“int64 转字符串入档”只是建议方案，未在沙箱验证其与 `JsonUtil.normalize`/`WorldState.to_dict` 的配合）。
- `world_tick_test` 的 `major_count<=20` 上界在本轮 seed 下取值为 2，未被压到边界；结构上 240 个月的最大值恰为 20（turn 1,13,…,229），因此该断言是紧的，但本轮未构造边界样例验证。
- 种子扫描仅覆盖 seed 1..2000、单一配置（`second_wizarding_war` + `ministry_of_magic` + 未知风格回退 `mixed`）；其它位置/风格/时代下的同月双 major 触发率未度量。
- `PROBE json_roundtrip_next` 单次抽样曾“恰好相等”，说明精度丢失并不总在首抽暴露；N1 的“必分叉”结论基于 41 批次 × 500 抽的实测，非形式化证明。
- 沙箱副本与仓库在同一 Godot 4.7.2 版本下运行；`.godot` 导入缓存由 `--import` 重建，行为与 `tools/test.sh` 一致（正式测试输出与预期行完全吻合）。

---

# 修复轮 2 scoped 复审

# Task 5 修复轮 2 scoped 复审

复审者：reviewer（独立只读子代理）　模型：deepseek-flash　范围：f9038ca..24d5d43

## 结论
- **N1：ADDRESSED**。`seed_value` / 每条流的 `seed` / `state` 三类全部为十进制字符串入档；`int64` 经 JSON 字符串端到端精确往返（500 抽 0 不一致、5 万抽后 state 位级相等）；`_streams.clear()` 的「替换」语义正确，多流恢复/幂等/新流派生均实测通过；`JsonUtil.normalize` 不会把字符串数字还原成数字。仅残留「旧 schema 静默不恢复 / 无 schema 版本号」等既有 Minor（见 N3），以及同类路径 `game_seed` 未覆盖（新增 N5，Minor）。
- **N2：ADDRESSED**。独立复核确定：种子 38 + 删 `break` → `[world_tick] 失败=1`（`实际最小间隔=0`）；种子 1234 + 删 `break` → 仍全绿（证明换种子确有必要）；修后种子 38 实测 `min_gap=20`（阈值 12，余量 8）。
- **R12：已消除空转**（指 brief 列出的两处）。`clock_test` 用 20 次续抽 + 真 JSON 往返替换 `JSON.stringify(...).length()>0`；用 f9038ca 的旧 int 实现回放该测试 → `[clock] 断言=47 失败=19`。`world_tick` 的 `events is Array` 换成 `w.clock.turn == 13 + i`，非空转。（`world_tick` 的信息保护断言仍恒真，但那属上一轮 **N4**，不计入 R12。）
- **有无新问题/夹带**：**无夹带**（4 个文件、diff 与声称的 4 项一一对应、无空白噪声、无越界文件）；**无阻断性新问题**；新增 1 条 Minor 观察（N5：`WorldState.game_seed` 仍为裸 int，同类 int64 经 JSON 丢失路径残留）。
- **总评：通过**。

## 证据

### 1) diff 逐行核对：只含声称的 4 项、无夹带
```
git diff f9038ca..24d5d43 --numstat
18	13	docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
8	6	src/core/rng_service.gd
8	5	tests/clock_test.gd
2	2	tests/world_tick_test.gd
```
- 4 个文件全部在 Task 5 计划 `Files:` 清单内；**无 `.uid`、无 `data/`、无新增文件、无越界**。
- `git diff --check f9038ca..24d5d43` 无输出；`git diff -w --stat` 与 `git diff --stat` 完全相同 → 无纯空白/格式化噪声。
- hunk ↔ 声称项映射：plan 文档 3 个 hunk（clock 块 / world_tick 块 / rng_service 块）＝第 4 项「计划同步」；`rng_service.gd` 的字符串化 + `_streams.clear()`＋注释＝N1（clear 已在简报中披露）；`clock_test.gd` 的 20 抽 + JSON 往返 + 删 length 断言＝R12/N1；`world_tick_test.gd` 的 `turn` 断言 + seed `1234→38`＝R12/N2。**无第 5 项改动**。
- 只读自证：复审前后 `git status --porcelain` 均为空，HEAD 始终 `24d5d43c2d8838ca110e28abcc17895d8c7db5eb`；未做任何 git 写操作；仓库外改动全部在 `/tmp/hali_probe`。

### 2) 计划 Step 1/3（及 Step 6）与代码逐字一致
脚本按围栏行号抽取计划代码块与仓库文件做 `==` 比较（剥离尾空行）：
```
tests/clock_test.gd:            plan_lines=58 repo_lines=58 equal=True
tests/world_tick_test.gd:       plan_lines=87 repo_lines=87 equal=True
src/core/rng_service.gd:        plan_lines=51 repo_lines=51 equal=True
world_state.gd tick() 块(102 行): contained_in_repo=True
```

### 3) N1 独立验证（沙箱 `/tmp/hali_probe`，Godot 4.7.2 同版本）
类型与往返：
```
A1 seed_value type=4 val=42                      # 4 = TYPE_STRING
A2 stream=world seed_type=4 state_type=4 seed_len=10 state_len=20
A3 原始 rng.seed=2883209391 rng.state=-7708639260699835401   # 63 bit，确为 int64
B1 新实现 mismatch=0/500 first=-1
B2 恢复后 state 精确相等=true
B3 seed_value 类型保持字符串=true
F8 raw_state=-4352708926626745132 → 字符串化同值 → 恢复后同值，精确=true；1000 抽 mismatch=0
JSON.stringify(大 int)={"s":-7708639260699835401} → 回读 type=3 val=-7708639260699834368.0（旧写法丢精度）
JSON.stringify(str)   ={"s":"-7708639260699835401"} → 回读 type=4 精确=true（新写法无损）
```
旧实现对照（int 入档）：
```
C1 旧 dict state type=2 val=-7708639260699835401
C2 JSON 回读 state type=3 val=-7708639260699834368.0
C3 旧实现 mismatch=499/500 first=1
```

`int(str(...))` 容错行为：
```
E1 缺 seed_value 键：保持对象原值 777（不报错）
E2 旧扁平 schema {"seed","state"}：seed_value 保持 555、streams=0 → 静默什么都不恢复（既有 N3）
E3 int(str(float(big))) 与 int(float(big)) 结果相同（均按 double 截断），不会比旧写法更差
E4 str(null)="<null>" → int=0；空串/垃圾串 → 0（静默）
E5 值为 float 的旧条目：state 3013343639311151104（精度已在 JSON 阶段丢失，无法挽回）
int('3.01334363931115e+18')=3  —— 仅当值是科学计数法字符串才会中招；
   实测 Godot 4.7 的 str(float) 在 1e15..1e300 全程输出十进制+".0"（如 3013343639311151616.0），
   而自有写入方只写 int→str（精确十进制），故该边界在现网写入路径不可达
```
`_streams.clear()` 替换语义与多流：
```
F1 恢复前 streams=["stale","world"] → F2 恢复后 ["world"]（stale 被清除，符合“替换”）
F4c 多流同时恢复一致=true streams=["a","b","c","world"]
F5 load 一个无 streams 的 dict → 所有流被清空（替换语义的必然结果，已在简报披露）
F7 二次存档（load→state_dict）逐字段相等=true（幂等）
```
`JsonUtil.normalize` 配合（brief 专项问题）：
```
G1 normalize 后 seed_value/state 仍为 TYPE_STRING，值完全相等（normalize 只动 float/dict/array，字符串原样透传）
G2 normalize 后 load 与直接 load 的首抽一致=true
```
结论：三处 int64 均已字符串化，且字符串形态对 `JsonUtil.normalize` 免疫；新的 on-disk 表示**不再经过任何 int↔float 转换**。

### 4) clock 的 20 次续抽确有判别力
- 200 批次统计（旧实现）：`20 抽捕获失败=196/200；单抽捕获失败=0/200`。
- 直接用 f9038ca 的旧 `rng_service.gd` 回放仓库当前 `clock_test`：
```
[clock] 经 JSON 往返后第 1 次抽取一致: 期望 <447325>，实际 <507853>
...（第 1..15+ 条全部打印差异）
[clock] 断言=47 失败=19
```
→ 20 抽 + 真 JSON 往返把 N1 变成**可证伪**；旧写法必红。

### 5) N2 独立反证（沙箱内删 `break`，仓库未改）
```
seed 38 + 无 break:  [world_tick] 相邻 major 事件至少相隔 12 个月（实际最小间隔=0）: 期望为真
                     [world_tick] 断言=104 失败=1   ==== 总计失败=1，失败套件=1 ====
seed 1234 + 无 break: [world_tick] 断言=104 失败=0   ALL TESTS PASSED   ← 旧种子无判别力，换种子确有必要
修后种子 38（有 break）: major_count=6 min_gap=20 turns=[11,54,75,95,123,176]
对照扫描: 906→gap20, 169→gap13, 312→gap12, 713→gap214, 1234→gap82
```

### 6) 仓库内单实例全量测试（`bash tools/test.sh`）
```
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=15 失败=0
[magic_level] 断言=22 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```
与简报要求逐项吻合。断言数自洽：clock 29→47（+20−2）；world_tick 104 不变（替换非新增）。`[probe]` 是故意的红样例、不在 `run_tests.gd` 的 `SUITES` 内，不污染总计。

### 7) 残留项在 24d5d43 上逐一复核（grep/沙箱）
```
weight：data/rumors.json 16 处；src/ tests/ 中 0 处引用                    → R2 成立
ministry_access：仅 data/rumors.json:3（无任何代码授予）                    → N4 恒真成立
rng_state：仅 world_state.gd:20/163/183（零业务读写）                       → R3 成立
state_dict/load_state：src 中 0 调用，tests 中仅 clock_test                 → R3/N3 成立
history：仅 append（46 行），无裁剪（RECENT_LOG_LIMIT 只作用于 log）         → R8 成立
log：3 种 schema（47 行 {turn,kind,text}／132 行含 category,major／141 行 mundane）→ R8 成立
hash()：type=2 32 位（探测值 177693）                                       → R9 成立
同月重复 rumor：seed 1..199 全部命中（示例 seed=1 turn=3 两条 text 完全相同）→ R10 成立
age_months：world_state.gd:145 无条件 +1                                    → R11 成立
无 WorldState 级 tick→to_dict→JSON→from_dict→tick 对比测试                   → R13 成立
RngService 无 version 字段                                                   → N3 成立
game_seed 往返：20260918 精确；12345678901234567→…568；9007199254740993→…992  → 新增 N5
```

## 残留发现（含前两轮未处置项）
| # | 严重度 | 位置 | 问题 | 是否可留到后续任务 |
|---|--------|------|------|--------------------|
| R2 | Important | `data/rumors.json`（16 条 `weight`）+ `src/model/world_state.gd:113-116` | `weight` 声明但 `stream_pick` 均匀抽取，稀有度旋钮仍失效（且计划本身只定义均匀 `stream_pick`，属计划↔数据不一致） | **可留**：排入「时代/内容平衡」任务；届时二选一（实现加权或删字段） |
| R3 | Important | `src/model/world_state.gd:20,163,183` | `rng_state` 仍是死字段；`state_dict/load_state` 在 src 零调用。「存档可恢复随机流」在 `WorldState` 层未落地；当前 `tick()` 用 `game_seed + turn*104729` 派生子 RNG，**存档不需要持久化流状态**，故字段纯冗余 | **可留**：排入存档系统任务；但接线前必须先定夺「删字段改述为派生式确定性」还是「接入长驻 RngService」，不可带着死字段进入接线 |
| N3 | Minor | `src/core/rng_service.gd:31-48` | 无 schema 版本号；旧扁平 `{seed,state}` schema **静默**什么都不恢复（`streams=0`）；`load_state` 传入畸形/无 `streams` 的 dict 会静默清空已有流；空串/垃圾字符串 → 0 无告警 | **可留**：随存档系统任务加版本号/兼容分支或显式告警 |
| N4 | Minor | `tests/world_tick_test.gd:73-84` | `is_false(leaked)` 仍恒真：`ministry_access` 全仓无人授予，`ministry_internal` 永不入候选集；`events_seen>0` 只证「有事件」 | **可留**：排入身份/权限门控任务时补阳性对照或删除误导断言 |
| R8 | Minor | `src/model/world_state.gd:12,46,147-148` | `history` 无上限；`log` 三种 schema 混用 | **可留**（长局存档膨胀风险，非本任务） |
| R9 | Minor | `src/core/rng_service.gd:13` | `String::hash()` 32 位，跨流/跨 seed 存在生日碰撞风险（实测 type=2） | **可留**；建议在概率敏感内容上线前改 64 位混合 |
| R10 | Minor | `src/model/world_state.gd:113-121` | 同月两次 pick 可命中同一 rumor 重复入 events/log（实测 seed 1..199 全部出现；`break` 只挡第二条 major） | **可留**（体验瑕疵，非确定性缺陷） |
| R11 | Minor | `src/model/world_state.gd:145` | `age_months` 无条件推进，与 `clock` 各自计时 | **可留**：随生死/年龄系统统一时间入口 |
| R13 | Minor | `tests/world_tick_test.gd`（整体） | 仍无 `tick→to_dict→JSON→from_dict→tick` 的 WorldState 级存档续跑对比 | **可留**；建议与存档系统任务同批补齐（同时兜住 R3/N5） |
| N5（本轮新增观察） | Minor | `src/model/world_state.gd:161,170` | 同类 int64 经 JSON 丢失路径残留：`game_seed` 未字符串化，>2^53 时往返失真（实测 `12345678901234567→…568`、`9007199254740993→…992`）。因 `tick()` 用它派生子 RNG，失真会让读档后世界演化静默分叉 | **可留**，但必须与 R3/N3 同批在存档系统任务内解决（`RngService` 已字符串化、`game_seed` 未做，属同类不对称） |

严重度变化小结：**N1 解除**（原 Important）、**N2 解除**（原 Minor）；R12 的两处空转已消除（上一轮「建议升 Important」的理由随之消失，回落到无此问题）。R2/R3 维持 Important，R8–R11/R13 维持 Minor，N3/N4 维持 Minor；新增 N5 Minor。**无 Critical。**

## 未验证/存疑
- **无 Critical**，故无最小复现。
- 20 抽判别的覆盖率是 196/200（旧实现）；存在约 2% 批次在 20 抽内偶然重合。对固定种子 42 实测为必红（失败=19），但这是**实测**而非形式化证明——若未来更换 `r7` 的种子/抽取次数，判别力需重测。
- `int(str(...))` 对「科学计数法字符串」会静默得到错误小值（`int("3.01334363931115e+18")=3`）。当前写入方只写 `int→str`（精确十进制），且 Godot 4.7 的 `str(float)` 在 1e15..1e300 全程输出十进制+".0"，故现网路径不可达；但若第三方手改存档写入 `1e18` 形式字符串，会静默走偏——未做防护（归入 N3）。
- `_streams.clear()` 的「替换」语义只在「`load_state` 总是收到完整 `state_dict()`」这一前提下正确；当前调用点仅 `clock_test`，无生产调用方。若未来出现「部分恢复」需求，需重新设计（已披露，不算新缺陷）。
- 旧 schema（含扁平 `{seed,state}`、以及旧 int 型 streams）的**真实存档样本不存在**（`RngService` 本任务才建、`rng_state` 从未写入），故旧存档兼容性只能靠构造样本推演，未能对真实历史文件验证。
- `game_seed` 的失真阈值实测仅 3 个样例（2^53 附近）；`to_dict→JSON→from_dict` 之后世界演化是否**必然**分叉未逐序列比对（仅验证 `game_seed` 数值不等）。
- 种子扫描与重复 rumor 扫描均在 `second_wizarding_war`/`modern` + `ministry_of_magic`/`london_muggle` 单一配置下进行，其它位置/风格/时代的 `min_gap` 与重复率未度量。
- 全部沙箱验证在 `/tmp/hali_probe` 的仓库副本内完成（同 Godot 4.7.2、`--import` 重建缓存），行为与 `tools/test.sh` 一致；仓库 `git status --porcelain` 在复审前后均为空。
