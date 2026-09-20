# Task 2 报告 · `WorldFactions` 规则层（初始化 / 机构控制权 / 权力四角 / 政体推导）

> 计划：`docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md` Task 2｜分支 `plan-03-factions`
> Base（派发前 HEAD）：`eacb773`（Task 1 提交）
> **提交哈希：`19654f0`**（7 文件，+405；`docs/` 未触碰 —— 裁定文本由人类单独提交在 `dabefab`）
> 当前状态：实现全部完成、**全绿**。`bash tools/test.sh` → **`EXIT=0`**、`总计失败=0，失败套件=0`、`ALL TESTS PASSED`、`[factions] 断言=43 失败=0`。
> 中途发现的 plan 内部矛盾（寡头制阈值 0.45 不可达）经人类裁定 **A** 修正为 **0.28**，规格与计划文本已由人类在 `dabefab` 同步（spec §7.4/§13.2、计划 Task 2/5）；本任务代码随之改一处常量。详见末节「裁定与执行结果」。

---

## ① 任务与状态

| 项 | 值 |
| --- | --- |
| 任务 | 计划 03a Task 2：`WorldFactions` 规则层 + 接到 `WorldState.create()/from_dict()` 与主场景内容自检 |
| 提交 | **`19654f0`**（2026-09-20） |
| 测试结论 | **EXIT=0**；19 套件（18 个真实套件 + 1 个自检探针）失败=0；`[factions]`=43 / `[registry]`=212 / `[save]`=97 / `[llm]`=84 全绿 |
| 流程 | Step 1 写失败测试 → Step 2 跑出红（已留证）→ Step 3 实现 → Step 4 跑绿（除待裁定一条）→ Step 5 提交（按人类裁定 A 改阈值后提交） |

## ② 改动 / 新建文件

| 文件 | 变更 |
| --- | --- |
| `src/rules/factions.gd` | +`DOMAINS` 白名单常量；+10 个静态函数：`validate_content` / `initialize` / `entry_of` / `base_power` / `ensure_state` / `state_of` / `power_of` / `power_share` / `institution_control` / `government_type`（**Task 1 的 9 个常量一字未动**） |
| `src/model/world_state.gd` | `create()` 与 `from_dict()` 各在 `return w` 前加一行 `WorldFactions.initialize(w)` |
| `src/ui/main.gd` | `_ready()` 加一行 `errors.append_array(WorldFactions.validate_content(registry))`（紧跟 `registry.validate()`） |
| `tests/factions_test.gd` | 新建（43 断言），`.gd.uid` 已由引擎生成 |
| `tests/registry_test.gd` | 末尾 +2 条「两处枚举一致」护栏断言（210→212） |
| `tests/run_tests.gd` | `SUITES` 末尾追加 `"res://tests/factions_test.gd"` |

未触碰任何 brief 未列出的文件（详见 ⑧）。

## ③ 原始输出

**Step 2（红，TDD 证据）** —— `bash tools/test.sh` → `EXIT=1`：

```text
套件无法实例化（语法错误？）: res://tests/factions_test.gd
==== 总计失败=1，失败套件=1 ====
测试失败：单测=1 冒烟=0 镜像=0
```
（另有 44 处 `Parse Error: Static function "…" not found in base "WorldFactions".` —— 正是本任务要实现的函数，证明先有测试后有实现。）

**Step 4（中间态：绿除待裁定一条；保留作为矛盾证据）** —— `bash tools/test.sh` → `EXIT=1`：

```text
[registry] 断言=212 失败=0
[save] 断言=97 失败=0
[llm] 断言=84 失败=0
[factions] 纯血权重高 + 魔法部弱 → 寡头制: 期望 <pureblood_oligarchy>，实际 <ministry_bureaucracy>
[factions] 断言=43 失败=1
==== 总计失败=1，失败套件=1 ====
测试失败：单测=1 冒烟=0 镜像=0
```

其余 16 个套件逐条 `失败=0`（同一轮的原始明细，除 `[probe]` 是断言库自检探针、故意失败、不计入）：

```text
[probe] 断言=1 失败=1（自检探针，故意失败，不算失败）
[harness] 8  [registry] 212  [money] 18  [magic_level] 48  [model] 49  [clock] 47
[world_tick] 104  [creation] 176  [spell] 229  [gm] 63  [panel] 71  [selfcheck] 32
[save] 97  [async_probe] 2  [llm] 84  [prompt] 13  [debug_mirror] 23
```
（因存在 1 条失败，运行器按设计**不**打印 `ALL TESTS PASSED`，只打印 `==== 总计失败=1，失败套件=1 ====`。）

**Step 4（终态：裁定 A 把阈值改成 0.28 后复跑）** —— `bash tools/test.sh` → **`EXIT=0`**：

```text
[factions] 断言=43 失败=0
[registry] 断言=212 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
全部通过。
```

同一轮 19 套件明细（`[probe]` 是断言库自检探针，故意失败、不计入）：

```text
[harness] 8  [registry] 212  [money] 18  [magic_level] 48  [model] 49  [clock] 47
[world_tick] 104  [creation] 176  [spell] 229  [gm] 63  [panel] 71  [selfcheck] 32
[save] 97  [async_probe] 2  [llm] 84  [prompt] 13  [debug_mirror] 23  [factions] 43
```
第 3/4 步主场景冒烟与第 4/4 步调试镜像冒烟均通过；全仓 `SCRIPT ERROR` **2 条**（与 `task-1-baseline.log` 逐字一致，非本任务引入）。

第 3/4 步主场景冒烟与第 4/4 步调试镜像冒烟均通过（`main scene ready` + 未设置 `HALI_DEBUG_LOG` 时输出里无任何 `[HALI]` 行，反向断言通过）。

**实现过程中修掉的一个真问题（新噪音）**：

```text
修前：SCRIPT ERROR: Invalid access to property or key 'turn' on a base object of type 'Nil'.  × 17
      帧：ensure_state (factions.gd:117) ← initialize (factions.gd:89) ← from_dict (world_state.gd:189) ← decode ← save_test.gd:79
修后：0 条
```
根因：`save_test.gd:79` 的「畸形载荷」负例会让 `GameClock.from_dict` 报错并把 `w.clock` 留成 `null`（该报错本身是**既有**行为，基线里就有 1 条），我的 `from_dict → initialize` 接线撞上它，每声明一个派系就往 stderr 喷一条。修法：`initialize()` 在 `world.clock == null` 时直接返回 + `ensure_state()` 里 `last_change_turn` 用 `world.clock.turn if world.clock != null else 0`。修复后全仓 `SCRIPT ERROR` 总数回到基线水平（2 条，与 `task-1-baseline.log` 逐字同位同文）。

## ④ 断言数前后对比

| 套件 | 派发前（eacb773） | 本任务后 | 差值 |
| --- | --- | --- | --- |
| `[factions]` | 套件不存在 | **43**（失败 1） | +43 |
| `[registry]` | 210 | **212** | +2（枚举一致性护栏） |
| `[save]` | 97 | 97 | 0（但新增的 `from_dict` 接线被它覆盖到，见 ⑥） |
| 全仓总计 | 0 失败 | 1 失败（仅待裁定项） | — |

## ⑤ 四条内容校验 Minor 收口的证据（Task 1 审查 #2/#3/#4 的收口）

`validate_content()` 新增 6 类检查：`domains` 白名单、`aliases` 非空数组且元素非空白、`base_power` 类型、`era_overrides` 必须存在且为 Dictionary、`institutions` 枚举、`rivals/allies` 引用存在。

**探针实测（一次性脚本，未入库）**：六种坏内容各自命中断言要找的文案；真实内容 0 错误：

```text
[MINOR-PROBE] bad_domains          -> hits=true | factions/x: domain 非法（不存在的领域）
[MINOR-PROBE] blank_alias          -> hits=true | factions/x: alias 为空（第 1 项）
[MINOR-PROBE] empty_aliases        -> hits=true | factions/x: aliases 为空
[MINOR-PROBE] string_base_power    -> hits=true | factions/x: base_power 类型非法（0.5）
[MINOR-PROBE] missing_era_overrides-> hits=true | factions/x: era_overrides 缺失
[MINOR-PROBE] list_era_overrides   -> hits=true | factions/x: era_overrides 必须是 Dictionary
[MINOR-PROBE] real_content_errors=0
```

**反证实验（证明断言非恒真）**：把 `if not DOMAINS.has(...)` 临时改成 `if false and not DOMAINS.has(...)` → 复跑：

```text
[factions] 坏 domains 被 validate_content 抓到: 期望为真      ← 断言真的会红
[factions] 断言=43 失败=2
```
随后从备份原样恢复，`diff` 为空（`RESTORED-IDENTICAL`，全文件无残留 `if false and`）。

**两处枚举护栏**（Task 1 审查 #5）：`tests/registry_test.gd` 末尾新增
`a.eq(insts, WorldFactions.INSTITUTIONS, "机构枚举两处一致")` 与 `a.eq(kinds, WorldFactions.KINDS, "kind 枚举两处一致")`，本任务后 `[registry]` 212 断言全绿 → 两处枚举当前逐字一致。实测结论：Godot 4.7.2 下无类型 `Array` 与 `Array[String]` 用 `==` 可逐元素比较为真（若把 `KINDS` 里任一元素改掉，这两条会红）。

## ⑥ `initialize()` 幂等 + create/from_dict 双路径补齐的证据

| 断言 | 覆盖点 |
| --- | --- |
| `初始化后 17 个派系都有状态` | 全量补齐 |
| `initialize 幂等（不覆盖已有值）` | 手工把 `ministry.power` 改成 0.10 → 再 `initialize` → 仍是 0.10 |
| `部分状态的世界补齐到 17 条` + `已存在的条目不被覆盖（部分状态）` | `factions` 只剩 1 条（power=0.42）→ 补齐到 17 条且那条仍是 0.42 |
| `create() 路径自动补齐（不需要外部调 initialize）` | `WorldState.create()` 未显式调 `initialize` 也已 17 条 |
| `from_dict() 路径自动补齐` + `读档后派系实力与存档一致` | `SaveCodec` 往返：条数 17、`ministry.power` 仍 0.75 |
| `factions 为空的老存档仍可解码` + `老存档读档后被补齐到 17 条` | 把 `w.factions = {}` 再编码（模拟老存档）→ `ok=true` 且补齐到 17 |
| `initialize` 对畸形载荷的 null-clock 防护 | 见 ③：`save_test.gd:79` 的负例路径新增 0 条 stderr |

**平局与空态**（机构控制权归并的边界）：
- `控制权最高的派系成为 holder` / `holder 的值取最大值`（`death_eaters.control.law_enforcement=0.90` → holder=death_eaters）
- `控制权持平取 power 更高者`（`wizengamot` 与 `sacred_twenty_eight` 都 0.70 → holder=`wizengamot`）
- `机构控制权返回全部 8 个机构键` / `无派系声明时 value 全为 0.0` / `holder 全为空串`
- `国际机构 holder` = `international_confederation`

**四种政体用例**：官僚制（默认）/ 寡头制（**待裁定**）/ 独裁（黑暗势力掌握司法）/ 凤凰社抵抗（战争压力 0.8 + 抵抗组织 0.95 > 魔法部）——后两条与官僚制一条均绿；另加一条「四个政体 id 都在 `governments` 内容表里」。

## ⑦ 未验证项 / 残余

1. ~~`pureblood_oligarchy` 分支不可达~~ **已闭合（裁定 A，阈值 0.45→0.28）**：构造用例 0.3010 ≥ 0.28 命中、默认现代 0.1627 不命中，该分支现由绿断言覆盖。阈值仍属「首版拍数」（spec §13.2），实跑几局后可能还要按体感再调。
2. `governments` 内容表的 `canon_line`/`summary` 不进任何校验（Task 1 审查已接受）。
3. `power_share()` 只算四角成员；`dark/resistance/foreign/society` 类派系不进四角（设计如此，spec D5/D3），其力量只体现在 `control` 与政体判定。
4. `institution_control()` 的 `value` 是「单派系最大值」而非加权和，故两家各 0.5 与一家 0.5 结果相同（spec §7.2 明确取最大值 + 平局取 power 高者）。
5. 未做 `WorldState.game_seed` 的 int64 字符串化（`§8#19`，属存档 v2，不在本任务）。
6. `aliases` 目前只被校验，还没有消费者（Task 9 才用它做关键词识别）；Task 1 审查 Minor #1 的 `black_market.aliases` 含裸地点名「翻倒巷」问题仍挂着，留给 Task 9 裁定。
7. 全仓仍有 2 条 `SCRIPT ERROR`（`save_test` 的坏档负例 + 解析层负例），与基线逐字一致，非本任务引入。

## ⑧ 是否触碰 brief 未列出的文件

**否。** 改动仅限 brief 列出的 6 个文件（`src/rules/factions.gd`、`src/model/world_state.gd`、`src/ui/main.gd`、`tests/factions_test.gd`、`tests/registry_test.gd`、`tests/run_tests.gd`）。`src/rules/factions.gd` 里新增的 `DOMAINS` 常量是控制器裁定要求的 Minor 收口项，不是自主扩张；`tests/factions_test.gd.uid` 是引擎 `--import` 自动生成、按项目铁律入库。

---

## 裁定与执行结果：`pureblood_oligarchy` 阈值 0.45 → 0.28（人类裁定 A，2026-09-20）

**这不是实现缺陷，是 plan 内部矛盾**：计划同时要求

1. 规则 `power_share()["pureblood"] >= 0.45`（且 `power_of("ministry") < 0.5`）才判寡头制；
2. 「寡头制」构造用例只把两派纯血拉到 `0.9`、把魔法部压到 `0.30`，就断言必须命中。

**量化表（探针实测，未入库）**：

| 格局 | ministry | pureblood | hogwarts | commerce | 判定 | 阈值 0.45 |
| --- | --- | --- | --- | --- | --- | --- |
| 简报构造用例（纯血 0.9/0.9、魔法部 0.30） | 0.3144 | **0.3010** | 0.1087 | 0.2759 | `ministry_bureaucracy` | 差 0.149 |
| 理论上限（两派纯血都 1.0，其余 base_power） | 0.3514 | **0.3017** | 0.0980 | 0.2489 | `ministry_bureaucracy` | 差 0.148 |
| 默认现代格局（必须**不**触发） | 0.4213 | 0.1627 | 0.1175 | 0.2984 | `ministry_bureaucracy` | ✓ 符合预期 |

> 三行都是同一轮探针的实测输出（`[MAX-PROBE] ... sum=1.0000`），且**三种格局全部判成 `ministry_bureaucracy`** —— 即 0.45 阈值下这一分支在任何合法状态都打不开。根因：`power_share()` 是**四角**归一化，而魔法部角含 4 个机构（0.75+0.60+0.58+0.40）、商业角含 4 个、霍格沃茨 1 个，任何单角现实上限约 1/3；纯血只有 2 个派系（power ≤ 1.0），改内容表也救不回来（两派拉满也只有 0.3017）。

**四个选项与成本对比**：

| 选项 | 改什么 | 成本 | 影响 |
| --- | --- | --- | --- |
| **A（我推荐 → 已采纳）** | `government_type()` 阈值 `0.45 → 0.28` | 1 个常量 + 注释依据 | 保 spec「占比」语义与第十二章权力四角；构造用例 0.3010 命中、默认 0.1627 不命中；**测试一字不改**；余量 0.02 |
| A2 | 阈值 `0.45 → 0.30` | 1 个常量 | 最贴计划字面，但构造用例余量仅 0.0010（内容表一动即翻），脆 |
| B | 规则不动，扩写构造用例：额外压低霍格沃茨/商业两角 ~10 个派系的 power，才够爬到 0.45+ | 测试 3 行 → ~10 行 | 规则零改动；但用例离「纯血权重高」的真实玩法更远，且以后复现这套格局要手工摆 10 个数 |
| C | 换判定信号：`sum(pureblood power) >= 1.6 and power_of("ministry") < 0.5`（绝对实力语义） | 重写规则 + 注释 + spec §7.4 措辞同步 | 可达（构造用例 1.8 命中、默认 0.90 不命中）、更易读；但与 spec 现有措辞偏离最大 |

### 裁定与执行

**裁定（人类，2026-09-20）：A** —— 阈值 `0.45 → 0.28`。理由：`power_share()` 是四角归一化、单角现实上限约 1/3，`0.45` 是 spec §7.4 里按「占比」写下的**算错的数**；A 是恢复 spec 原意的修法，**不是语义变更**。简报里那条构造用例**一字未改**。

**人类先改文本（`dabefab`，只动 2 个 docs 文件、不碰代码）**：
- spec §7.4 门限 `0.45 → 0.28`；spec §13.2 新增勘误段（含本报告实测数据 0.3010 / 0.3017 / 0.1627）
- 计划 Task 5 里同样不可达的 `oligarchy_pressure` 死分支 `0.40 → 0.26`（保留 `or pureblood_influence >= 0.65`）
- 计划 Task 2 的规则代码同步为 `0.28`

**我改的一处代码**（`src/rules/factions.gd`，仅此一处；其余代码/测试零改动）：

```gdscript
	# 3) 纯血寡头：纯血权重高 + 魔法部弱（第十一章第 2 条）
	# 阈值 0.28：四角归一化下单角现实上限约 1/3（构造用例 0.3010、理论上限 0.3017、默认 0.1627）；原稿 0.45 不可达，见 spec §13.2 勘误（人类裁定 A，2026-09-20）。
	if float(power_share(world).get("pureblood", 0.0)) >= 0.28 and power_of(world, MINISTRY_ID) < 0.5:
		return "pureblood_oligarchy"
```

**复跑（裁定后终态）**：`bash tools/test.sh` → **`EXIT=0`**

```text
[factions] 断言=43 失败=0
[registry] 断言=212 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
全部通过。
```

**提交**：`19654f0`（`git add` 只加 Task 2 的 7 个路径，未用 `-A`、未碰 `docs/`；`git show --stat` 确认 7 files / +405）。
