# Task 4 实现报告 · `WorldFactions.evolve()`（实力/控制权演化 + 政体刷新）+ 6 条审查 Minor 收口

> **修复轮 1（审查 Rejected 后）：提交 `3223509`** —— I1 / M1 / M2 / M3 / M5 已处理，见 §⑩。
> 当前顶端：`3223509`；`bash tools/test.sh` → `EXIT=0`；`[factions]` **115** 断言 / 0 失败；其余 17 套件不变。

## ① 任务与提交

| 项 | 值 |
| --- | --- |
| 任务 | 计划 03a Task 4（brief：`.superpowers/sdd/2026-09-20-hp-magic-era-03-factions/task-4-brief.md`） |
| BASE（开始前顶端） | `5525525`（控制器 docs 提交：spec §7.4 裁定 (a)） |
| 实现提交 | **`ee335b1`** `feat(factions): 派系实力/控制权演化与政体刷新（计划 03a Task 4）` |
| 证据补强提交 | **`dd81fa2`** `test(factions): 确定性证据补强——factions 字典整字段对比（96 字段，17 派系）` |
| 提交后顶端 | `dd81fa2`；`git status --short` 为空 |
| 环境 | Windows + Git Bash；Godot 4.7.2 stable；分支 `plan-03-factions` |

## ② 改动文件清单

`git show --stat ee335b1`：

```
 src/rules/factions.gd  | 107 ++++++++++++++++++++++++++---
 tests/factions_test.gd | 180 +++++++++++++++++++++++++++++++++++++++++++++++++
 2 files changed, 277 insertions(+), 10 deletions(-)
```

`git show --stat dd81fa2`：`tests/factions_test.gd | 10 ++++++++++`

**只碰了 brief 允许的两个文件。**（破坏实验期间临时改过 `src/rules/state_ops.gd` 与 `tests/factions_test.gd`，均已逐字还原，见 ⑥。）

## ③ `bash tools/test.sh` 原始输出

```
== 1/4 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/4 单元测试 ==
[probe] 断言=1 失败=1          ← 断言库自检探针，故意失败，不在 SUITES 里
[harness] 断言=8 失败=0
[registry] 断言=212 失败=0
[money] 断言=18 失败=0
[magic_level] 断言=48 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=176 失败=0
[spell] 断言=229 失败=0
[gm] 断言=71 失败=0
[panel] 断言=71 失败=0
[selfcheck] 断言=32 失败=0
…（此处为 save_test 刻意负例的 stderr 噪音，本文件第 19/28 行，与基线逐字一致）…
[save] 断言=107 失败=0
[async_probe] 断言=2 失败=0
…（此处为 llm_test 刻意负例的 stderr 噪音）…
[llm] 断言=88 失败=0
[prompt] 断言=13 失败=0
[debug_mirror] 断言=23 失败=0
[factions] 断言=111 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/4 主场景冒烟（默认配置：必须与未加调试镜像时逐字一致） ==
main scene ready, godot=4.7.2-stable (official)
== 4/4 调试镜像冒烟（HALI_DEBUG_LOG=1，B1 人工验收的观测通道） ==
main scene ready, godot=4.7.2-stable (official)
[HALI] PROBE-APPEND-MARK
[HALI] [状态行] PROBE-STATUS-MARK
[HALI] [输入框] editable=false
[HALI] [按钮] 整排 禁用
全部通过。
EXIT=0
```

（完整日志：`task-4-test-green.log`，119 行；`EXIT=0` 是脚本最后一行逐字输出。）
**stderr 噪音**：`SCRIPT ERROR` **2 条 = 基线 2 条**（`task-1-baseline.log`），本次新增 0 条。

**红步（Step 2）**：`task-4-test-red.log`

```
套件无法实例化（语法错误？）: res://tests/factions_test.gd
==== 总计失败=1，失败套件=1 ====
测试失败：单测=1 冒烟=0 镜像=0     （EXIT=1）
缺失符号：Static function "evolve()" ×4 / "structure_pull()" ×6 / "apply_rival_pressure()" ×1
```

## ④ `[factions]` 断言数前后对比（M1：修复轮 1 已改正账目）

| 阶段 | `[factions]` 断言 | 失败 |
| --- | --- | --- |
| Task 3 顶端（BASE `5525525`） | 60 | 0 |
| Task 4 首轮（`ee335b1` + `dd81fa2`） | 111 | 0 |
| **修复轮 1（`3223509`）** | **115** | 0 |

**首轮 +51 的逐项账目（审查者逐条数过，替代首版误算）：**

| 块 | 断言数 |
| --- | --- |
| 演化段（17 派系确定性 + 政体缓存 2 + 结构拉力 3 + brief 压制对 2 + 可判别压制 2 + 单对精确幅度 2 + 逐字段 2） | 30 |
| Minor 1（规则 2 回退语义） | 2 |
| Minor 2（null-clock 硬化） | 5 |
| Minor 3（三个数组守卫） | 5 |
| Minor 4（era_overrides 红例） | 1 |
| Minor 5（改换语义钉住） | 5 |
| Minor 6（delta/2 截断） | 3 |
| **合计** | **51** |

> ⚠️ **M1 认领**：首版报告写「演化段 25 条 / Minor 收口 26 条」，但括号内分项之和分别是 28 / 21，账目不平。真实构成如上表（60 + 51 = 111 ✓，与首轮绿灯的 `断言=111` 吻合）。

**修复轮 1 的增量（+4）**：

| 变更 | 断言增量 |
| --- | --- |
| I1 新增「非对称敌对声明」回归用例 | +2 |
| M2 逐字段：`compared/expected` 互证 2 条 → 真逐字段 3 条 | +1 |
| M3 `evolve()` 早退断言（裸世界 + 半残世界） | +2 |
| M5 删除与 seed 挂钩的「< 起点」断言 | −1 |
| **合计** | **+4**（111 + 4 = **115** ✓ 与修复轮绿灯吻合） |

## ⑤ 六条 Minor 收口：哪条断言钉住它 + 该断言能失败的证据

| # | Minor | 钉住它的断言（`tests/factions_test.gd`） | 「能失败」的证据（破坏实验日志） |
| --- | --- | --- | --- |
| 1 | 规则 2 缺失键回退语义 | `黑暗势力未声明任何机构 → 不得判独裁（缺失键按 0 计）`、`该格局回落为官僚制` | **S5**（把 `control.get(inst, 0.0)` 换回「全局归并持有值」旧语义）→ `fix1-s5.log`：`期望为假`、`该格局回落为官僚制: 期望 <ministry_bureaucracy>，实际 <death_eater_dictatorship>`（2 红） |
| 2 | null-clock 硬化补断言 | `裸世界（无 registry/clock）不被写入派系状态`、`registry 齐但 clock 为 null：仍不补齐（不读 clock.turn）`、`clock 为 null 时 ensure_state 仍能建出状态`、`clock 为 null 时 last_change_turn 兜底为 0` | **S3**（去掉 `initialize` 的 `world.clock == null` 守卫）→ `fix1-s3.log`：`registry 齐但 clock 为 null：仍不补齐（不读 clock.turn）: 期望 <0>，实际 <17>`（1 红，干净失败不崩）。注：`裸世界` 那条在 S3 下仍绿，因为 `registry == null` 检查在它之前短路——两条断言分别对应两道守卫 |
| 3 | `institutions`/`rivals`/`allies` 数组守卫 | `字符串型 institutions … 抓到（不崩）`、`字典型 rivals … 抓到（不崩）`、`数值型 allies … 抓到（不崩）`、`缺失 institutions … 抓到`、`缺失 rivals … 抓到` | **S4a**（去掉 institutions 守卫）→ `fix1-s4a.log`：`Invalid cast: could not convert value to 'Array'` + `总计失败=1`（套件中止）；**S4b**（去掉共享 `elif typeof(e[field]) != TYPE_ARRAY` 守卫）→ `fix1-s4b.log`：同样 cast 崩溃 ×2 → 证明该守卫对 `rivals` 承重；**S4c**（同 S4b + 临时把 rivals 夹具改为合法数组，逼套房走到 allies 夹具）→ `fix1-s4c.log`：同样 cast 崩溃 → 证明同一守卫对 `allies` 承重 |
| 4 | `era_overrides` 引用不存在时代补红例 | `era_overrides 引用不存在的时代被 validate_content 抓到` | **S2**（把该检查改成 `if false and …`）→ `fix1-s2.log`：`期望为真`（1 红） |
| 5 | `join_faction` 直接改换语义钉住 | `直接改换无错误（不需要先 leave）`、`直接改换覆盖所属`、`改换不移除原派系立场` | **S2b**（在 `join_faction` 覆盖 `faction_id` 前 `standing.erase(旧派系)`）→ `fix1-s2b.log`：`改换不移除原派系立场: 期望 <30>，实际 <0>`（1 红，干净失败） |
| 6 | `delta / 2` 向零截断钉住 | `玩家立场为 -5（原值）`、`派系态度为 -2：delta/2 向零截断（既定语义）` | **S2**（把 `+ delta / 2` 改成 `+ -delta / 2`）→ `fix1-s2.log`：`派系态度为 -2：delta/2 向零截断（既定语义）: 期望 <-2>，实际 <2>`（1 红） |

> 上表所有破坏实验已在**修复轮 1 最终代码**（`3223509`）上重跑，日志前缀 `fix1-`；每个实验恢复后均以 md5 校验三个文件逐字一致、`grep -c SABOTAGE` = 0。

**Minor 6 的语义说明（按任务要求写明）**：设计文字写的是 `delta // 2`，而 GDScript 的整数除法是**向零截断**（`-5 / 2 == -2`，不是 `-3`）；当前实现与断言都按向零截断钉住，**留给后续任务统一**（若要改成 floor 语义，需同时改 `state_ops.gd` 与断言）。

## ⑥ 反证实验（含 brief 指定的那一条）

### 6.1 brief 指定的反证：注释掉 `evolve()` 里的 `apply_rival_pressure(world)`

（修复轮 1 重跑，`fix1-s1.log`；被注释的调用与恢复见 §⑩.4）

```
[factions] 压制把败者按到下限，不会归零（与 seed 无关）: 期望 0.050000 ± 0.000100，实际 0.064318
[factions] 断言=115 失败=1
==== 总计失败=1，失败套件=1 ====
```

恢复后重跑（绿色）见 §⑩.6，`总计失败=0`。注：M5（§⑩.5）把原先那条「可判别：回归本会把败者拉高，压制把它压回起点以下」**删掉了**（它与 seed 挂钩、余量仅 0.0043），改由「被压到 `SUPPRESS_FLOOR`」这一条承担反证职责——它同样是「只在真压制存在时才绿」的断言，实测值 0.064318 与纯回归手算值逐位吻合。

### 6.2 ⚠️ 必须上报的偏差：brief 原有的「敌对压制」用例**没有判别力**

按 brief 原样抄的那两条（「敌对强者压制弱者」「压制有下限，不会归零」，setup 为 `ministry=0.95 / death_eaters=0.60`、默认 modern 世界变量）**在被注释掉压制后仍然全绿**，即它无法区分「只回归」与「回归＋压制」：

- 实测现代世界 `structure_pull(ministry) = +0.01`、`structure_pull(death_eaters) = +0.06` → death_eaters 目标值 = 0.11，仅回归一项就把它从 0.60 拉低到 `0.60 + (0.11-0.60)*0.04 = 0.5804`，再叠加命名流噪音 `n_death = -0.011282`（`RngService.new(12345)` 的 `faction_death_eaters` 流，实测）= **0.569118 < 0.60** → 「压制后 < 压制前」在两种实现下都成立。
- 这正是 brief Step 4 那条反证想要暴露的问题：它**不可能**变红，若照抄就会得到一份「反证通过」的假证据。

**处置（未改任何生产代码；修复轮 1 又加强了后两条）**：
1. brief 原有的两条断言**原样保留**（不删、不弱化）；
2. **另加**一个「可判别」用例：把 `war_pressure`/`corruption` 提到 1.0（抬高黑暗势力目标值到 0.45），败者起点设为 **0.06**（高于 `SUPPRESS_FLOOR`）。⚠️ **修复轮 1（M5）**：该用例原来还有一条「`power < 起点`」断言，但其判别余量只有 0.0043（需 `noise > -0.0156`）→ 换 seed / 改 `EVOLVE_NOISE` 会退化成恒真，已**删除**；只保留与 seed 无关的「被压到 `SUPPRESS_FLOOR`」断言（death_eaters 在真实内容表里同时是 4 对的败者，累计压制 ≈ 0.06 ≫ 噪音带宽 ±0.02）。反证下该断言仍变红（实测 0.064318）；
3. 再加一个**单对精确幅度**用例：用「只有两个派系、互为 rivals」的最小夹具隔离开 `apply_rival_pressure`，断言跌幅恰好 `SUPPRESS_RATE × 0.35 = 0.0105`、胜者恰好 `+0.00525`（1e-4 容差）。**为什么要最小夹具**：在 17 派系真实内容表上该函数会处理**全部 11 对**（`death_eaters` 同时与 `ministry`/`auror_office`/`order_of_phoenix`/`hogwarts` 交手），net 跌幅等于多对叠加（实测 0.004752 ≠ 单对 0.0105），直接断言单对幅度会假红；
4. **修复轮 1（I1）**：另加「非对称敌对声明」回归用例——真实内容里 `black_market` 单方声明 `auror_office`，旧去重规则把它整对丢弃（详见 §⑩.1）。

### 6.3 其余破坏实验一览（全部逐字还原）

| 实验 | 破坏内容 | 结果（日志均为修复轮 1 重跑） |
| --- | --- | --- |
| S1（brief 指定） | 注释掉 `evolve` 里的压制调用 | `fix1-s1.log`：1 红 `压制把败者按到下限，不会归零（与 seed 无关）: 期望 0.050000 ± 0.000100，实际 0.064318` |
| S2 | `era_overrides` 时代检查失效 + `delta/2` 取反 | `fix1-s2.log`：4 红 / 2 套件：`[factions] era_overrides 引用不存在的时代…`、`[factions] 派系态度为 -2…实际 <2>`，另有 2 条**同一破坏的连带红**：`[gm] 派系态度反向变化`、`[factions] 玩家立场反向影响派系对玩家的态度` |
| S2b | 改换派系时丢掉原派系立场 | `fix1-s2b.log`：1 红 `改换不移除原派系立场: 期望 <30>，实际 <0>` |
| S3 | 去掉 `initialize` 的 null-clock 守卫 | `fix1-s3.log`：1 红 `registry 齐但 clock 为 null…: 期望 <0>，实际 <17>` |
| S4a/b/c | 依次去掉 institutions / 共享(rivals,allies) 守卫 | `fix1-s4a/b/c.log`：均 `Invalid cast: could not convert value to 'Array'` → 套件中止（红） |
| S5 | 规则 2 回退到旧语义 | `fix1-s5.log`：2 红 `不得判独裁…期望为假`、`该回落为官僚制…实际 <death_eater_dictatorship>` |

**恢复证据**：每个实验结束后对 `src/rules/factions.gd` / `src/rules/state_ops.gd` / `tests/factions_test.gd` 做 md5 比对，**三个文件全部 OK**；`grep -c SABOTAGE` 在三个文件中均为 **0**；`git status --short` 只剩本任务的两个目标文件（提交后为空）。

## ⑦ 确定性证据（M2：修复轮 1 已改为真逐字段遍历）

`tests/factions_test.gd` 的演化段：

1. **逐派系 power 对比**：同 seed（`12345`）两个世界各演化 3 回合，17 个派系逐一 `a.near(..., 1e-7)` 全部相等；
2. **真逐字段遍历**（替代原先的 `compared_fields` vs `expected_fields` 同源算术互证）：遍历 17 派系的**实际键集**（`power`/`control`/`revealed`/`stance_to_player`/`last_change_turn`/`notes`），用类型严格的 `!=` 逐键比较并把差异收集进 `mismatches`：
   - `a.eq(compared_fields, 102, "逐字段对比实际遍历 102 个字段（17 派系 × 6 键）")`；
   - `a.eq(mismatches.size(), 0, "同 seed 双世界逐字段全等（差异字段：%s）")`；
   - 另保留 `JSON.stringify(e1.factions) == JSON.stringify(e2.factions)` 作冗余护栏（它捕获逐键漏比/新增键）。
   这样 `compared_fields` 是**观测值**（实际遍历了多少键）而非同源恒等式，且差异报告能直接指出是哪个 `派系.键` 不同。

随机源：`RngService.new(world.game_seed + world.clock.turn * 31337)`，每派系一条命名流 `faction_<id>`；`apply_rival_pressure` 无随机（按 id 排序去重，逐对确定）。全过程无 `randf()`/`randi()` 裸调用。

## ⑧ 未验证项 / 残余

1. **`structure_pull` 只有 3 个分支有断言**：`ministry` / `dark` / `resistance` 各一条；`institution` / `pureblood` / `commerce`+`media` / `foreign` / `school` 与 `_`（未知 kind → 0.0）**无独立断言**（被确定性整体断言间接覆盖，但单项系数没钉住）。
2. **机构控制权的「滞后跟随」系数 0.5 没有被单独断言**（`control[inst] += (power - control[inst]) * 0.5`）：仅由「整体逐字段确定性 + 政体缓存」间接覆盖；若后续调整该系数，不会立刻有断言变红。
3. **`last_change_turn` 的「相等时不更新」分支未测**（`is_equal_approx(next, current)` 为真时不写），也未断言它记录的是当前 `turn`。
4. **`evolve()` 恒返回空数组**：事件通道（返回结构、`major`、`add_fact`）属 Task 5，本次只断言返回可迭代且不抛错（通过「按返回值循环」间接覆盖）。
5. **长期漂移未测**：只测了 3 回合；17 派系在极端 `world_vars` 下多回合是否收敛/震荡（例如 `SUPPRESS_FLOOR` 与 `base_power*0.25` 双下限是否互相咬住）未观察 → 留给 Task 5 接入 `tick()` 后实跑观察。
6. **`notes` 字段从未写入**（结构里保留但无生产者）→ Task 5/6 的叙事侧可能要用，当前为空数组。
7. 未验证「多对敌对的处理顺序」是否会影响期望的玩法观感（顺序按 id 字典序，不是按实力）；这是确定性换来的代价，需在实跑后判断是否要改成「按实力排序处理」。

## ⑨ 是否触碰未列出的文件

**否。** 提交只含 `src/rules/factions.gd` 与 `tests/factions_test.gd`。（破坏实验期间临时改过 `src/rules/state_ops.gd` 与 `tests/factions_test.gd`，均逐字还原并通过 md5 校验，见 ⑥.3。）

---

## ⑩ 修复轮 1：I1 / M1 / M2 / M3 / M5（提交 `3223509`）

### ⑩.1 I1（Important）——`rivals` 非对称声明被静默丢弃

**缺陷**：`apply_rival_pressure()` 的 `if oid <= id: continue` 会把「只有字典序较大的一方声明敌对」的对整对丢掉。我用一次性脚本在真实内容表上独立复算（`fix1-pairs.log`，脚本临时文件已删除、未入库）：

```
新实现（无向对键）seen 键数 = 11
   kept     auror_office|black_market   ← 旧实现会丢
   kept     auror_office|death_eaters
   kept     black_market|diagon_merchants   ← 旧实现会丢
   kept     common_folk|sacred_twenty_eight   ← 旧实现会丢
   kept     continental_pureblood|international_confederation
   kept     death_eaters|hogwarts
   kept     death_eaters|ministry
   kept     death_eaters|mysteries   ← 旧实现会丢
   kept     death_eaters|order_of_phoenix
   kept     death_eaters|wizengamot   ← 旧实现会丢
   kept     reformist_pureblood|sacred_twenty_eight
旧实现（oid <= id）处理的对数 = 6
旧实现静默丢弃的对数 = 5
```

与控制器点名的 5 对逐一吻合（`black_market↔auror_office`、`diagon_merchants↔black_market`、`wizengamot↔death_eaters`、`mysteries↔death_eaters`、`sacred_twenty_eight↔common_folk`）→ 黑市过去完全不受压制。

**改法**（照计划 `6c35c26` 的权威文本）：无向对键 `pair_key = id|oid`（按字典序拼接）+ `seen` 去重；同时补 `rivals` 非数组 → `continue`、`oid.is_empty() or oid == id` → 跳过（M4 的运行时类型守卫也在此落地，控制器已裁定无需另改）。

**回归护栏（新增两条断言）**：`非对称敌对声明（black_market 单方声明 auror_office）也必须被处理`、`非对称敌对的胜者也获得收益`。

**改前红 / 改后绿**（同一份新测试，只换实现）：

```
改前（旧 `oid <= id` 去重，fix1-red-asym.log）：
[factions] 非对称敌对声明（black_market 单方声明 auror_office）也必须被处理: 期望为真
[factions] 断言=113 失败=1
==== 总计失败=1，失败套件=1 ====

改后（无向对键，fix1-green.log）：
[factions] 断言=115 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
```

（改前那次计数是 113，因为 M3 的两条断言当时被临时搞掉、以免崩溃中止掩盖逐条红点，见 ⑩.4。）

### ⑩.2 M1 报告账目

已改，见 §④：换成审查者逐条核过的构成表（60 → +51 = 111）＋ 修复轮增量表（+4 → 115）；首版「标题 25 / 26 与括号内分项和 28 / 21 不平」的问题已认领并删除。

### ⑩.3 M2 自指断言

处置：**改成真逐字段遍历**（不降格为注释）——遍历 17 派的实际键集逐键类型严格比较 + 差异列表 + `JSON.stringify` 冗余护栏；`compared_fields` 现在是**观测值**（`a.eq(compared_fields, 102, …)`）。
理由：逐键断言能直接报出「哪个派系·哪个键不同」，比整体序列化更可诊断；且不再依赖「`1+control.size()+4` 与 `5+institutions.size()` 恰好相等」这种同源恒等式。断言数 2 → 3。

### ⑩.4 M3 `evolve()` 早退

- 实现：`evolve()` 开头加 `if world == null or world.registry == null or world.clock == null: return []`（与 `initialize()` 同数一致）。
- 断言：`裸世界调用 evolve 返回空数组（早退，不崩）`、`registry 齐但 clock 为 null 时 evolve 也早退（不读 clock.turn）`。
- **改前红**（`fix1-red-m3.log`，旧实现紧接着读 `world.clock.turn`）：

```
SCRIPT ERROR: Invalid access to property or key 'turn' on a base object of type 'Nil'.
       [1] run (res://tests/factions_test.gd:387)
SCRIPT ERROR: Invalid access to property or key 'turn' on a base object of type 'Nil'.
       [1] run (res://tests/factions_test.gd:388)
==== 总计失败=1，失败套件=1 ====
```

（两次 nil 访问分别对应 `evolve(naked)` 与 `evolve(half)`；套件因此中止、未调用 `report`。）
- **改后绿**：`[factions] 断言=115 失败=0`（`fix1-green.log`）。

### ⑩.5 M5 种子余量

- **被删断言**：`可判别：回归本会把败者拉高，压制把它压回起点以下`。余量只有 0.0043：纯回归 = 0.0756 + noise，要它 ≥ 起点 0.06 需 `noise > -0.0156`（实测 `n_death = -0.011282` 刚好落在窄带内）→ 换 seed 或调 `EVOLVE_NOISE` 即退化成恒真。
- **保留并依赖的断言**：`压制把败者按到下限，不会归零（与 seed 无关）`。
- **为何它 seed 无关**：`death_eaters` 在真实内容表里同时是 4 对的败者（与 ministry 差 ≈0.86、auror_office ≈0.54、hogwarts ≈0.59、order_of_phoenix ≈0.04），单对压制 = `0.03×gap`，累计 ≈ **0.06**，远超噪音带宽 **±0.02** 与回归步长 ≤ 0.02 → 无论 seed 如何都会落到 `SUPPRESS_FLOOR` 并被 clamp。
- **反证下它仍红**：`fix1-s1.log` → `压制把败者按到下限，不会归零（与 seed 无关）: 期望 0.050000 ± 0.000100，实际 0.064318`（= 纯回归值，与手算逐位吻合）。

### ⑩.6 修复轮 1 验收

```
bash tools/test.sh（fix1-green.log；提交后复核 fix1-postcommit.log）
[factions] 断言=115 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
全部通过。
EXIT=0
```

其余 17 套件断言数不变（harness 8 / registry 212 / money 18 / magic_level 48 / model 49 / clock 47 / world_tick 104 / creation 176 / spell 229 / gm 71 / panel 71 / selfcheck 32 / save 107 / async_probe 2 / llm 88 / prompt 13 / debug_mirror 23），`SCRIPT ERROR` 2 条 = 基线。
提交 `3223509` 只含 `src/rules/factions.gd` 与 `tests/factions_test.gd`（受限 `git add`，未用 `-A`、未碰 `docs/`）；工作区干净；全部破坏实验恢复后 md5 逐字一致、`grep -c SABOTAGE` = 0。
