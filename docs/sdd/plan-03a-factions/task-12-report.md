# Task 12 报告 —— 哑炮学院（`§8#69`）+ 创建界面姓名/性别（`§8#70`）+ 内容旋钮生效（`§8#16/#21`）

| 项 | 值 |
| --- | --- |
| 分支 | `plan-03-factions` |
| BASE | `d5a56d8` |
| 提交 | **`973eea8`**（8 files, +207/-20） |
| 绿基线（开工前实测） | `bash tools/test.sh` → EXIT=0；18 套件 **1746** 断言失败 0；`SCRIPT ERROR` 2 条 |
| 交付后（实测） | `bash tools/test.sh` → EXIT=0；18 套件 **1760** 断言失败 0；`SCRIPT ERROR` **仍 2 条**；`timeout 300 bash tools/b1_acceptance.sh` → EXIT=0；**112** 断言 / 0 失败 |
| 破坏实验 | 7 组（D1/D2a/D2b/D2c/D3a/D3b/D4），每组精准变红、`cp`+`md5` 逐字还原、无残留 godot 进程 |
| 是否 push | **否**（按 brief：控制器统一推送） |

---

## ⚠️ 修复轮 1 更正声明（2026-09-20，按审查 Minor #5）

> **首轮报告的自述有一处不精确，在此更正，不偷偷改掉不留痕（与 Task 6 的做法一致）。**
>
> 首轮报告的「工程卫生核对」与 §4 的措辞读起来像是「**一条既有断言都没动**」。**这不准确**。准确表述是：
>
> - ✅ **没有任何既有断言被放宽 / 删除 / 改期望值**（这一点成立，审查也确认了）；
> - ⚠️ 但**确实改了两处既有内容**，而且是**必要**的：
>   1. `tools/b1_acceptance.gd` 的 `_dropdown_count(node) == 7` → **`== 8`**。这是**新增一个 OptionButton 的必然连带**：
>      不断言计数就错。它不是「放宽」，而是「同步事实」（D2c 破坏实验证明这条计数断言对「下拉真的在界面上」有判别力）。
>   2. `tools/b1_acceptance.gd` 的 `_part2_squib_start()` 里**两条 `note()` 观察项被 `check()` 断言取代**
>      （`§8#69` 的 `house_id` 由「观察」改为「断言 `== "none"`」；`§8#70` 的性别由「观察未定」改为「断言 `== "男"`」）。
>      这是**加强**而非放宽，但确实是「改了既有行」。
> - 此外还**新增**了 `[HALI] [创建界面] gender …` 镜像行（镜子通道要能观测到性别）与 `_dropdown_count` 的检查列表加 `"gender"`。
>
> 首轮报告 §5「声明性偏离」的 #7 与 #7（镜像循环）本来就记了这两件事，但 §4 与卫生核对里的**笼统措辞与其矛盾**，以本条为准。
> 修复轮 1 的完整交付见文末「修复轮 1」小节。

---

## 1. 改动文件与行数（`git show --stat`）

```
 data/wand_cores.json            | 12 +++----     （每条加数值 weight：common=6 / rare=1；rarity 保留）
 src/core/rng_service.gd         | 24 ++++++++++++++  （新增 stream_pick_weighted）
 src/model/world_state.gd        |  3 +-          （tick 的传闻抽取改用加权）
 src/rules/character_creation.gd | 24 ++++++++++---  （哑炮 house_id=none + generate_wand 加权）
 src/ui/main.gd                  | 28 +++++++++++--   （姓名默认空 + 性别下拉 + 读下拉真实值）
 tests/creation_test.gd          | 69 +++++++++++++++++++++++++++++++++++++++++
 tests/world_tick_test.gd        | 50 +++++++++++++++++++++++++++++
 tools/b1_acceptance.gd          | 17 +++++++---
 8 files changed, 207 insertions(+), 20 deletions(-)
```

---

## 2. 绿步原始输出（提交后冻结代码，`/tmp/t12-final-test.log`）

```
[probe] 断言=1 失败=1                     ← 断言库自检探针，故意失败，不计入失败套件
[harness] 断言=8 失败=0        [registry] 断言=244 失败=0
[money] 断言=18 失败=0         [magic_level] 断言=48 失败=0
[model] 断言=49 失败=0         [clock] 断言=47 失败=0
[world_tick] 断言=186 失败=0   [creation] 断言=184 失败=0
[spell] 断言=229 失败=0        [gm] 断言=128 失败=0
[panel] 断言=102 失败=0        [selfcheck] 断言=32 失败=0
[save] 断言=112 失败=0         [async_probe] 断言=2 失败=0
[llm] 断言=106 失败=0          [prompt] 断言=38 失败=0
[debug_mirror] 断言=23 失败=0  [factions] 断言=204 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/4 主场景冒烟 ==  main scene ready, godot=4.7.2-stable (official)
== 4/4 调试镜像冒烟 ==  全部通过。
[HALI] [创建界面] house_id 选项数=6 当前=gryffindor
[HALI] [创建界面] gender 选项数=3 当前=男        ← §8#70 新增，镜像里可见
test.sh EXIT=0
```
（`SCRIPT ERROR` 2 条 = 基线 2 条，逐字同位：`save` 的坏档负例。）

`timeout 300 bash tools/b1_acceptance.sh`（`/tmp/t12-final-b1.log`）：

```
  B1 自动验收：断言 108 条，失败 0 条
  [观察] 观察（§8#69）：哑炮 house_id = none（已按正典第七章/第二十四章修正为 none）
  [观察] 观察（§8#70）：性别取自创建界面下拉 =「男」
  B1 自动验收最终：断言 112 条，失败 0 条
B1 自动验收：全部通过。
b1 EXIT=0
```

---

## 3. 红步原始输出

### 3.1 Step 2（先写测试、未实现时）

```
SCRIPT ERROR: Invalid call. Nonexistent function 'stream_pick_weighted' in base 'RefCounted (RngService)'.
套件未正常结束（未调用 report，运行期错误？）: res://tests/world_tick_test.gd
套件未正常结束（未调用 report，运行期错误？）: res://tests/creation_test.gd
==== 总计失败=2，失败套件=2 ====
```
（与计划 Step 2 的预期一致：`stream_pick_weighted` 未定义 ⇒ 两个套件中止。）

### 3.2 破坏实验七组（全部按预期精准变红；每组后 `md5sum -c` = `OK`）

| 组 | 破坏内容 | 实际红条 |
| --- | --- | --- |
| **D1** | 哑炮分支改回 `p.house_id = assign_house(...)` | `[creation] 哑炮不进霍格沃茨：显式指定 gryffindor 也必须被覆盖为 none: 期望 <none>，实际 <gryffindor>` ｜ 断言=184 失败=**1** |
| **D2a** | `name_edit.text = ""` → `"无名者"` | `[FAIL] 姓名框默认为空（不再预填「无名者」）` ｜ B1 112 断言 失败=**1** |
| **D2b** | `_on_start_pressed` 把性别写回硬编码 `"未定"` | `[FAIL] 性别取自创建界面下拉（world.player.gender=男）` ｜ 失败=**1** |
| **D2c** | 性别下拉不 `add_child` 进 `creation_box` | `[FAIL] 创建界面有 8 个下拉框（…实际 7）` ｜ 失败=**1** |
| **D3a** | 杖芯权重键改回 `"rarity"`（字符串） | `[creation] generate_wand 的稀有杖芯远低于均匀占比（400 支里 196 支；均匀时≈200，加权时≈57）` ｜ 失败=**1** |
| **D3b** | `wand_cores.json` 三条 common 的 `weight` 6→1（等价均匀） | `[creation] 常见杖芯显著多于稀有杖芯…实际 common=1499 rare=1501` + `generate_wand…400 支里 202 支` ｜ 失败=**2** |
| **D4** | 传闻抽取回到 `month_rng.stream_pick(...)` | `[world_tick] E2E：weight=0 的传闻 40 回合内一次都不该被抽中…期望 <0>，实际 <29>` ｜ 失败=**1** |

**两组额外结论（对后续读者有用）：**

1. **D1 复现了计划原稿「无判别力」的实证**：破坏后 `[creation]` 只有 **1** 条红——即我新增的「显式指定 gryffindor」那条；
   计划原稿那条（`house_id: "system"`）**仍然绿**。这就是它为什么不能作为 §8#69 的回归护栏。
2. **D3a 说明 helper 层分布断言不足以证明接线**：把 `generate_wand` 的键名改回 `"rarity"` 时，
   `stream_pick_weighted` 的分布断言**全绿**（它直接传 `"weight"`，测的是 helper），只有我新增的
   **端到端**断言（400 支里 196 支稀有 ≈ 均匀）抓住。⇒ 端到端那条承重，不是冗余。

---

## 4. 断言数前后对比（逐套件）

| 套件 | 改前 | 改后 | 差 |
| --- | --- | --- | --- |
| `[creation]` | 176 | **184** | +8（§8#69 三条 + §8#21 三条，含端到端） |
| `[world_tick]` | 180 | **186** | +6（§8#16 helper 三条 + 端到端三条） |
| 其余 16 套件 | — | 不变 | 0 |
| **18 套件合计** | **1746** | **1760** | **+14** |
| `B1 探针` | 105 | **112** | +7 |
| `SCRIPT ERROR` | 2 | **2** | 0（不许变，已核） |

**预期值一次没改**（⚠️ 请连同页首「修复轮 1 更正声明」一并读：本句只针对「因 RNG 变化而要改期望值」，
**不等于**“一条既有断言都没动”——`b1_acceptance.gd` 的 `_dropdown_count 7→8` 与两条 `note()→check()` 是**必要**改动）：
`stream_pick` → `stream_pick_weighted` 只改变 `wand_wood` / `wand_core` / `pick_%d`
三个**具名流各自**的消耗方式（每个具名流是独立 RNG），既有断言（确定性、结构、内容表引用）不依赖具体抽中哪一条
⇒ 无一条旧断言因 RNG 变化变红，**没有出现「内容变了要改期望值」的情形**。这一点与 brief §2.5 的预警不同，
如实报告：**预警的连带影响在本仓库没有兑现**（因为具名流互相独立 + 既有断言不钉具体抽中值）。
---

## 5. 声明性偏离（与计划文本不一致处 + 依据）

| # | 计划原文 | 实现/测试实际做法 | 依据 |
| --- | --- | --- | --- |
| 1 | 测试片段 `"personality": ["好奇"]` | 改为 `["好奇", "固执", "怕黑"]` | **实测**：`validate_choices` 要求 ≥3 个性格关键词；1 项 ⇒ `errors=1`、`player==null` ⇒ 下一条 `squib_res.player.house_id` 是**空引用访问**，会把整个 `[creation]` 套件**中止**（红得不干净）。探针实测输出见下 |
| 2 | 测试片段 `"house_id": "system"` + `a.eq(..., "none")` | 改为 `"house_id": "gryffindor"` 作**判别**断言，另保留一条 `system` 的**非回归**断言 | **实测**：`house_id="system"` 时 `assign_house` 早在 `magic_aptitude=false` 上返回 `"none"`（本文件 `:154` 既有断言「哑炮不判学院」已如此）⇒ 计划原稿那条**改前改后都绿**。计划 Step 2 自己期望的红是「哑炮 `house_id=gryffindor`」，指向的正是**显式指定学院**这条路径（= 创建界面 house 下拉默认 gryffindor = B1 实测路径）。D1 破坏实验证实：只有新那条能红 |
| 3 | 新增两条断言（helper 层分布）作为 `§8#21` 的验收 | 另加一条**端到端**断言：`generate_wand` 400 支的稀有杖芯占比 < 120 | 计划 D3 期望「杖芯改回 `rarity` → 分布断言红」，但 helper 层断言直接传 `"weight"`，**抓不到 `generate_wand` 用错键名**（D3a 实测：helper 全绿、只有端到端红）。不加这条，D3 就是假的 |
| 4 | 只有 helper 层 `[world_tick]` 断言 | 另加一条**端到端**断言：夹具把 `rumors` 换成「`weight=1` 在前、`weight=0` 在后」同 zone 两条，40 回合内 `weight=0` 一次都不许被抽中 | 同上：计划 D4 期望「传闻回到 `stream_pick` → `[world_tick]` 的权重断言红」，但 helper 层断言不碰 `tick()` ⇒ 不加这条 D4 无从变红（D4 实测：刚好 1 条红，就是这条） |
| 5 | `var none: Array = [...]`（变量名 `none`） | 改名 `t12_all_zero` | 纯可读性；`t12_` 前缀同时避免与同文件既有同名变量冲突（本套件已有 `squib` / `squib_house` 等） |
| 6 | `"gender": str(gender_dropdown.get_item_metadata(gender_dropdown.selected))` | 照写（先试了同文件既有的 `_selected("gender")`，最终**改回计划原文**） | `_selected()` 依赖 `dropdowns` 注册表，会把「性别读取」耦合到注册表；计划原文读成员变量更稳（D2c 那类实验下不会连带崩）。同时仍把 `gender_dropdown` 登记进 `dropdowns["gender"]`，以满足计划里 b1 的 `_select(node, "gender", "男")` 与镜像循环 |
| 7 | 计划未提 | `tools/b1_acceptance.gd` 的 `_dropdown_count(node) == 7` 改为 `== 8`，且镜像循环的 key 列表加 `"gender"` | **必然连带**：新增一个 `OptionButton` ⇒ 该计数断言必红；镜像列表是「界面输入的外部观测通道」，不加上性别就观测不到（D2c 证明该计数断言对「下拉真的在界面上」有判别力） |
| 8 | 计划未提 | `stream_pick_weighted` 的注释里写明「**不要**加 `-> Dictionary` 返回标注」及原因 | 空表返回 `null`；实测「字面 `null` 赋给 `Dictionary`」是解析期错误 |

第 1、2 条的依据（开工前控制器探针 + 本实现者复核，输出原文）：

```
A 计划原文：personality 1 项 + house=system          errors=1 house_id=<player==null>
B 计划原文：personality 1 项 + house=gryffindor      errors=1 house_id=<player==null>
C 修正后：personality 3 项 + house=system           errors=0 house_id=none          ← 改前就绿
D 修正后：personality 3 项 + house=gryffindor       errors=0 house_id=gryffindor    ← 真正的缺陷路径
```

> 这三处（第 1/2 条）**没有改产品语义**：计划 Step 2 自己期望的红就是「哑炮 `house_id=gryffindor`」，
> 我只是让测试真的能红。**未改任何 `docs/`**（按 brief：计划/台账由控制器写）。

---

## 6. 未修残余（范围外，仅登记）

1. **`wand_woods.json` 没有 `weight` 字段**（见 §7）。木材永远等价均匀——若将来要「橡木比紫杉常见」，
   需要给该表加 `weight`（**纯内容改动，零代码**，因为调用处已经在传 `"weight"`）。
2. **`stream_pick_weighted` 的 `roll == 0.0` 边界**：若首条权重为 0 且 `randf()` 恰返回 `0.0`，
   `roll <= acc(0.0)` 成立 ⇒ 会抽中权重 0 的条目。概率约 2^-32，且**真实内容里首条权重不为 0**
   （`rumors.json` 权重 1–20、`wand_cores.json` 6/1），故未加特判（加特判会让「全零回退均匀」的分支更绕）。
   若将来有「权重 0 且排在首位」的表，此处会成为一个可观测的偏差。
3. **§8#70 未做的部分**：姓名框现在默认空 ⇒ 玩家不改名直接点「开始人生」会看到
   `创建失败：name_text 不得为空`。这是**有意**的（逼玩家起名），但**创建失败文案没有引导性提示**
   （不会说「请填写姓名」）。属 UX 细项，未改（范围外）。
4. **`assign_house()` 本身没动**：它对哑炮仍返回 `"none"`（`house_id="system"` 时）——
   §8#69 的修正落在 `create()` 的分支结构上。若将来有人绕过 `create()` 直接调 `assign_house`
   并显式传 `house_id="gryffindor"`，仍会拿到 `gryffindor`。既有断言（`creation_test:154`）钉的是 system 路径。
5. **`data/rumors.json` 的权重数值未调**（按 brief §7）。现在 `weight` 真的生效了，
   但「20 条传闻的权重分布是否合理」是平衡性议题，属 `§8#16` 的后续调参，不在本任务。
6. **B2 真机 LLM 路径未验**：本任务只跑离线替身与探针，未跑真机（§8 已裁定暂不做）。

---

## 7. `wand_woods` 的处置选择与理由（brief §2.2 要求二选一并说明）

**选择：照改——木材也走 `stream_pick_weighted(..., "weight")`（保持两处调用形式一致）。**

理由：
1. `wand_woods.json` 没有 `weight` 字段 ⇒ `maxf(float(e.get("weight", 1.0)), 0.0)` 全为 `1.0`
   ⇒ 总权重 = 条目数、每条区间等宽 ⇒ **与均匀抽取在分布上完全等价**（行为不变）。
2. 但**随机流消耗方式变了**（`randf` 取代 `randi_range`）⇒ 同种子下抽中的木材会变。
   实测：**没有任何既有断言因此变红**（具名流互相独立；`wand_wood` 的下游是 `wand_flex` / `wand_length`，
   各走自己的具名流）。所以这个代价在本仓库是零。
3. 一致性收益是实的：将来给木材表加 `weight` 就是纯内容改动，不需要再动代码
   （否则要再改一次 `generate_wand` 并再走一遍审查）。
4. 风险登记：木材表**当前**没有权重字段，所以「传了一个表里不存在的键名 ⇒ 默认 1.0 ⇒ 静默均匀」
   这一模式**与计划原稿的 `rarity` 假修同类**。区别是：这里**已知且有意**（数据里确实没有该字段，
   分布等价），而 `rarity` 那次是**误以为生效**。已在 `rng_service.gd` 的注释里把这条模式写明。

---

## 8. 工程卫生核对

- `git status --porcelain`：提交后**干净**（8 个文件的改动全部入库；无残留 `*.uid` 改写、无 `.import`、未触碰 `assets/`）
- 破坏实验 7 组：全部 `cp` 备份 + `cp` 还原 + `md5sum -c` = `OK`（**未使用** `git checkout -- <file>`）
- 每组实验后 `tasklist | grep -i godot` → 无残留进程
- **未并发**跑两个 headless 实例（每组串行 + 外部 `timeout`）
- **未 push**、**未改 `docs/`**、**未动 `assets/`**

---

# 修复轮 1（2026-09-20，处置审查 Minor #2/#3/#4/#5）

| 项 | 值 |
| --- | --- |
| BASE | `ebd426f`（控制器订正后的计划文本 + 审查 finding 裁定） |
| 提交 | **`ce1594d`**（4 files, +84/-14），**只提交、未 push** |
| 改动范围 | 严格限定在 4 件（F1/F1b/F2/F2b/F3）内，未扩 |
| 绿步（本轮，冻结代码后复跑） | `bash tools/test.sh` → **EXIT=0**；18 套件 **1767** 断言失败 0；`SCRIPT ERROR` **仍 2 条**<br>`timeout 300 bash tools/b1_acceptance.sh` → **EXIT=0**；**112** 断言 / 0 失败 |
| 破坏实验 | D5 / D6 两组（`cp` 备份 + `md5sum -c` 逐字还原、无残留 godot 进程） |
| 既有断言变红？ | **无一变红**（与控制器预判一致：`roll < acc` + 跳过零权重在当前数据下与旧实现行为等价） |

## R1. 改动文件与行数（`git show --stat`）

```
 src/core/rng_service.gd         | 40 ++++++++++++++++++++++++++++++----------
 src/rules/character_creation.gd | 15 +++++++++++----
 tests/creation_test.gd          | 22 ++++++++++++++++++++++
 tests/world_tick_test.gd        | 21 +++++++++++++++++++++
 4 files changed, 84 insertions(+), 14 deletions(-)
```

## R2. F1（Minor #2/#3）—— 契约违反与文档矛盾

按计划新片段重写：拆出 `_weight_of(e, weight_key)` 与 `_pick_by_roll(entries, weight_key, roll)`，
循环内 `if w <= 0.0: continue`，判定 `roll < acc`，兜底改为**最后一个正权重条目**（无正权重则 `null`），
契约注释写全四条（含「非字典条目在加权路径被跳过、但全零回退时可被抽中」这个**有意的不对称**）。

审查指出的两处违反，逐条对上：

| 审查发现 | 旧写法 | 新写法 |
| --- | --- | --- |
| `roll == 0.0` 且**首条**权重为 0 ⇒ 返回权重 0 的条目（违反注释里写的契约①） | `if roll <= acc` | `if roll < acc` + `if w <= 0.0: continue` |
| 浮点累加落空时的兜底可能返回零权重条目 | `return entries[entries.size() - 1]` | `return last_positive`（只可能是正权重条目；全无则 `null`） |
| 注释声称的契约与实现不一致 | 注释只有两句、未覆盖非字典条目 | 四条契约齐备，不对称那条写明「**不是 bug**」 |

## R3. F1b（本轮关键）—— 把不可测边界变成**可判别**

`_pick_by_roll` 拆出来的目的就是**直接传 roll**：`randf()` 精确返回 `0.0` 的概率 ≈ 2⁻³²，黑盒永远测不出来。

新增 3 条断言（`[world_tick]` 186 → 189），取 id 一律经新增的 `_picked_id()` 安全函数
（`_pick_by_roll` 可能返回 `null`；直接解引用会把「红」的形态变成**套件中止**——与首轮 personality 那条同源）：

```gdscript
	a.eq(_picked_id(RngService._pick_by_roll([{"id": "z", "weight": 0.0}, {"id": "o", "weight": 1.0}], "weight", 0.0)),
		"o", "roll=0.0 时不得返回前导的零权重条目（旧写法会返回 z）")
	a.eq(_picked_id(RngService._pick_by_roll([{"id": "o", "weight": 5.0}, {"id": "z", "weight": 0.0}], "weight", 999.0)),
		"o", "roll 超出总权重时，兜底不得落在零权重条目上")
	a.eq(_picked_id(RngService._pick_by_roll(["裸字符串", {"id": "o", "weight": 1.0}], "weight", 0.0)),
		"o", "加权路径跳过非字典条目（不会被它占掉区间）")
```

**没有**写「抽 2000 次看 0 权重没出现」那类**恒绿**的假断言（那种在被测数据下永远绿，不是判别器）。

## R4. F2（Minor #4）+ F2b —— `generate_wand` 去掉有类型接收

- 两处改为无类型接收 + `if x == null: return {}`；`world_state.gd:118` **未动**（那里的有类型接收被
  `if not candidates.is_empty():` 守卫，空表回退不可达 —— 按计划与审查 Minor #4 的裁定）。
- **F2b 夹具构造成功**（`Registry.from_tables()` 可接受 `wand_woods = []`；`Registry.validate()` 会把它判成
  「数据表为空」，但 `generate_wand` 不调 `validate`，所以夹具可达）。加了 3 条前置 + 1 条功能契约：

```gdscript
	a.is_true(not (f2b_tables["wand_woods"] as Array).is_empty(), "F2b 前置：默认木材表非空（不是拿一个正好为空的夹具冒充）")
	f2b_tables["wand_woods"] = []
	var f2b_reg := Registry.from_tables(f2b_tables)
	a.is_true(f2b_reg.ids("wand_woods").is_empty(), "F2b 前置：夹具里的木材表确实是空的")
	a.is_true(f2b_reg.ids("wand_cores").size() >= 6, "F2b 前置：其余表未被夹具误伤（杖芯表仍在）")
	a.eq(CharacterCreation.generate_wand(RngService.new(1), f2b_reg), {}, "木材表为空时 generate_wand 返回空魔杖（不返回半成品、不中断）")
```

> ⚠️ **诚实登记（重要）**：上面最后那条**不是**「有类型接收 vs 无类型接收」的判别器。
> GDScript 在中止时返回返回类型的默认值 ⇒ 两种写法在该路径上**都**返回 `{}` ⇒ 断言两种情况都绿。
> **D6 破坏实验实测证实**：套件 **0 红 / EXIT=0**，唯一的判别通道是外部的 **`SCRIPT ERROR` 条数 2 → 3**。
> 这与台账里 Task 4 N1 / Task 6 M3 / Task 10 I1 同族（「机制成立、套件内不可判别」）。
> ⇒ **建议保留“`SCRIPT ERROR` == 基线 2 条”作为每轮必查的门禁**；只靠单测无法守住这条契约。
> （我没有为了「让它能红」去人为制造一条断言：做不到就是做不到，写一条恒绿断言假装覆盖更糟。）

## R5. F3（Minor #5）—— 报告措辞更正

已在报告**页首**加「修复轮 1 更正声明」，并把 §4 的笼统措辞改精确：准确表述是
**没有任何既有断言被放宽 / 删除 / 改期望值**，但 `_dropdown_count 7→8`（新增 OptionButton 的必然连带）
与两条 `note()`→`check()`（§8#69/#70 由观察变断言）是**确实改了既有行**、且是**必要/加强**的改动。
未覆盖首轮任何内容，首轮的红/绿步原始输出全部保留。

## R6. 绿步原始输出（本轮，`/tmp/t12-fix1-final.log`）

```
[probe] 断言=1 失败=1                     ← 断言库自检探针，故意失败，不计入失败套件
[harness] 断言=8 失败=0        [registry] 断言=244 失败=0
[money] 断言=18 失败=0         [magic_level] 断言=48 失败=0
[model] 断言=49 失败=0         [clock] 断言=47 失败=0
[world_tick] 断言=189 失败=0   [creation] 断言=188 失败=0
[spell] 断言=229 失败=0        [gm] 断言=128 失败=0
[panel] 断言=102 失败=0        [selfcheck] 断言=32 失败=0
[save] 断言=112 失败=0         [async_probe] 断言=2 失败=0
[llm] 断言=106 失败=0          [prompt] 断言=38 失败=0
[debug_mirror] 断言=23 失败=0  [factions] 断言=204 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
全部通过。
SCRIPT ERROR 条数 = 2（= 基线，逐字同位）
test.sh EXIT=0
```

```
  B1 自动验收：断言 108 条，失败 0 条
  B1 自动验收最终：断言 112 条，失败 0 条
B1 自动验收：全部通过。
b1 EXIT=0
```

## R7. 破坏实验 D5 / D6 原始输出

### D5 — `_pick_by_roll` 改回 `roll <= acc` 且不跳过零权重

```
[world_tick] roll=0.0 时不得返回前导的零权重条目（旧写法会返回 z）: 期望 <o>，实际 <z>
[world_tick] roll 超出总权重时，兜底不得落在零权重条目上: 期望 <o>，实际 <z>
[world_tick] 断言=189 失败=2
==== 总计失败=2，失败套件=1 ====
D5 EXIT=1
还原校验: src/core/rng_service.gd: OK
```

**红数 = 2**（恰好就是 F1b 那两条；`[world_tick]` 其余 187 条与其他套件全不动）。
⇒ 证实审查的发现 ①（`roll <= acc` 确实会返回零权重条目）与发现 ②（兜底确实会落在零权重条目上），
并证实新断言是这条边界的**真判别器**（不是恒绿）。

### D6 — `generate_wand` 改回有类型接收（配合 F2b 的空表夹具）

```
SCRIPT ERROR: Trying to assign value of type 'Nil' to a variable of type 'Dictionary'.
   at: generate_wand (res://src/rules/character_creation.gd:112)
[creation] 断言=188 失败=0
==== 总计失败=0，失败套件=0 ====
D6 EXIT=0
SCRIPT ERROR 条数 = 3        ← 基线 2 + 本次 1
还原校验: src/rules/character_creation.gd: OK
```

**套件内红数 = 0（EXIT=0！）**，**唯一判别通道 = `SCRIPT ERROR` 2 → 3**。
⇒ 同时证实了控制器/审查的类型论断：错误是**运行期** `Trying to assign value of type 'Nil' to a
variable of type 'Dictionary'`，且会**中止所在函数**（不中止套件）。
⚠️ 这正是「只跑单测会假绿」的实例，故 §R4 的建议是**保留 SCRIPT ERROR 基线条数门禁**。

## R8. 逐套件断言数（首轮 → 本轮）

| 套件 | 首轮 | 本轮 | 差 | 说明 |
| --- | --- | --- | --- | --- |
| `[world_tick]` | 186 | **189** | +3 | F1b 三条契约/边界断言（含 `roll=0.0` 判别器） |
| `[creation]` | 184 | **188** | +4 | F2b：3 条前置 + 1 条功能契约 |
| 其余 16 套件 | 不变 | 不变 | 0 | — |
| **18 套件合计** | **1760** | **1767** | **+7** | |
| `B1 探针` | 112 | 112 | 0 | 本轮未动 b1 |
| `SCRIPT ERROR` | 2 | **2** | 0 | 不许变，已核（含 D6 反证） |

## R9. 方案选择与理由

1. **F1 按计划新片段逐字实现**（含拆函数、`roll < acc`、兜底取正权重、四条契约注释）。
   唯一自主决定：**兜底在「完全没有正权重条目」时返回 `null`**（计划片段即如此），
   而不是回退 `stream_pick` —— `_pick_by_roll` 只负责「按 roll 落区间」，回退语义留在
   `stream_pick_weighted`（总权重为 0 时早已提前回退），职责单一。
2. **F1b 用 `_pick_by_roll` 直接传 roll**，并额外加了「兜底不得落在零权重条目」与「加权路径跳过非字典条目」
   两条——它们是同一个契约面的另外两个可判别点，成本各 1 行；**没有**写抽 N 次的假判别器。
3. **F2b 的 4 条断言如实标注为「功能契约，不是机制判别器」**（见 §R4 的诚实登记），
   没有为了让破坏实验「好看」而制造一条不可能红的断言。
4. **未动 `world_state.gd:118`**（计划与审查 Minor #4 明确要求；那里有 `if not candidates.is_empty():` 守卫）。
5. **未顺带做任何范围外的事**：`wand_woods` 权重、`rumors.json` 调参、读档路径 `house_id` 归一化
   （计划已裁定归「存档格式 v2」批次）、UI 失败文案等，一律未动。

## R10. 剩余未修项（与本轮关系）

- **F2 的机制在本仓库内不可判别**（§R4）⇒ 依赖外部 `SCRIPT ERROR` 基线条数门禁；
  本轮已把它写进代码注释与报告，避免后来者以为 `a.eq(..., {})` 守住了这条契约。
- 首轮报告 §6 的 6 条残余**全部仍然成立**（未修，均属范围外）：`wand_woods` 无权重字段、
  `roll==0.0` 边界（**本轮已从“无断言”升级为“有可判别断言”**，语义修订见下）、姓名失败文案、
  `assign_house` 未被绕过的调用点、`rumors.json` 调参、真机 LLM。
  - 其中「`roll==0.0` 边界」这条**已收口**：新实现下 `roll == 0.0` 只会返回**首个正权重**条目，
    且 `_pick_by_roll` 有直接传 roll 的判别断言 ⇒ 首轮那条「未加特判」的残余**不再适用**。
- 读档路径的 `§8#69`（旧存档 `squib` + `gryffindor`）按计划「Task 12 范围声明」**不在本任务**，归存档格式 v2。
