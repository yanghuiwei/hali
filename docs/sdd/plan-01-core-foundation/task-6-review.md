# Task 6 审查记录（第一轮完整审查 + 修复轮 1 + 修复轮 2 scoped 复审）

> controller 从三个独立 reviewer subagent 的输出原样转存（模型均为 deepseek-flash）。
> 第一轮范围 `d4186c5..f3d8a31`；修复轮 1 `f3d8a31..2341540`；修复轮 2 `2341540..61ad053`。

---

# 第一轮完整审查

# Task 6 审查记录

审查者：reviewer（独立只读子代理）　模型：deepseek-flash　范围：d4186c5..f3d8a31

## 结论
- 规格符合：✅
- 裁定：**Approved with findings**
- 关键数字：Critical=0，Important=3，Minor=5

审查方式：只读（read + 只读 bash + `bash tools/test.sh` 单实例）。未修改任何文件、未做任何 git 写操作；测试前后 `git status --porcelain` 均为空，HEAD 始终 `f3d8a31`。

## 证据

### 1) diff 摘要（`git diff --stat d4186c5..f3d8a31`）
```
 data/skills.json                                   |  21 ++
 data/wand_cores.json                               |   8 +
 data/wand_flexibilities.json                       |   8 +
 data/wand_lengths.json                             |  15 ++
 data/wand_woods.json                               |  18 +
 .../2026-09-18-hp-magic-era-01-core-foundation.md  |   2 +-
 src/core/registry.gd                               |   5 +
 src/rules/character_creation.gd                    | 224 +++++++++
 src/rules/character_creation.gd.uid                |   1 +
 tests/creation_test.gd                             | 145 +++++
 tests/creation_test.gd.uid                         |   1 +
 tests/run_tests.gd                                 |   1 +
 12 files changed, 448 insertions(+), 1 deletion(-)   ← 与报告完全一致
```
`git diff --name-status` 精确等于 Task 6 简报的文件清单（含两个 `.uid` 与简报授权的计划文档同步修正）；**无越界文件**。
`registry.gd` diff 仅 `TABLE_FILES` 追加 5 行（`skills`/`wand_woods`/`wand_cores`/`wand_flexibilities`/`wand_lengths`），未动其它键。
`tests/run_tests.gd` 仅 `"res://tests/world_tick_test.gd",` 之后追加 `"res://tests/creation_test.gd",`。
计划文档 diff **只有 1 行**（即 `wood` 修正，见末节裁定）。

### 2) 逐字一致性（脚本提取计划 Task 6 各围栏代码块与仓库文件比对）
```
tests/creation_test.gd              vs 计划 Step1 块 : diff 为空 → SAME (145 行)
data/skills.json                    vs 计划块        : SAME (21 行)
data/wand_woods.json                vs 计划块        : SAME (18 行)
data/wand_cores.json                vs 计划块        : SAME (8 行)
data/wand_flexibilities.json        vs 计划块        : SAME (8 行)
data/wand_lengths.json              vs 计划块        : 仅少一行 `// data/wand_lengths.json —— ...` 说明性注释
                                                      （JSON 不允许注释，属必要且无歧义的省略）
src/rules/character_creation.gd     vs 计划 Step4 块 : SAME (224 行，含简报强制的 wood 修正)
src/core/registry.gd TABLE_FILES    vs 计划块        : SAME (追加 5 条)
```
`CharacterCreation` 方法签名逐条对照计划 Interfaces：`extends RefCounted` ✅、`class Result{player,errors}` ✅、
`validate_choices(Dictionary,Registry)->PackedStringArray` ✅、`create(...)->Result` ✅、`default_skills_for(...)->Dictionary` ✅、
`generate_wand(...)->Dictionary` ✅、`assign_house(...)->String` ✅；`choices` 键集合与 `wand` 字典 schema 一致。

### 3) 数据表独立核对（python 读 `data/*.json`，非依赖测试）
```
skills=19（唯一、label/category/note 全非空）
bloodline skill_bias 引用键 8 个 ⊂ skills；birth_identity skill_bias 引用键 10 个 ⊂ skills → 跨表完整性成立（零悬空引用）
wand_woods=16  wand_cores=6  wand_flexibilities=6  wand_lengths=13（全部非空 label）
houses 含 system/none；sim_styles/political_leanings/eras 的 choices 默认值均合法
aptitudes=6（special_options 5 项；**所有 aptitudes 的 grants 均为 []**）
```

### 4) `bash tools/test.sh` 原始关键行（本次单实例复跑）
```
[probe] 断言=1 失败=1                    ← 断言库自检探针，不在 SUITES，不计入总计
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=15 失败=0
[magic_level] 断言=22 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=141 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```
四项必须条件（`[creation] 断言=141 失败=0`、`总计失败=0，失败套件=0`、`ALL TESTS PASSED`、`全部通过。`、退出码 0）**全部吻合**。

### 5) 逻辑独立复核要点
- **`has_magic`**：`magic_aptitude(bloodline) and aptitude_id != "squib"`；哑炮血统被 validate 强制 `aptitude_id=="squib"`，有魔法血统选 `squib` 被 validate 拒 → 一致，无静默修正。
- **随机资质池**：排除 `random`/`squib` 后才 `stream_pick`；30 次抽样断言不只是空转（池构造即排除，确定性成立）。
- **确定性**：`registry.ids()` 返回已排序 `PackedStringArray`；`stream_pick` 命名流按 seed 派生；`scores.keys()` 为固定字面量插入序 → 同种子同选择可复现（`to_dict()` 值比较断言真实（若为引用比较该断言必红）。
- **平票 RNG**：`is_equal_approx` 在 1.0+1.5k 这类精确值上等价于 `==`，`tie_break` 顺序确定 → 平票结果确定。
- **`rarity` / `aptitude_special` 消费者**：`grep -rn rarity src tests` → **0 引用**；`grep -rn aptitude_special src` → 仅 `player_state`（读写字段）与 `character_creation` 自身，**无游戏逻辑消费者**（当前）。

## 发现

| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|
| 1 | Important | `src/rules/character_creation.gd:64-71` vs `:209-213` | **反漏洞不变量被绕过**：`aptitude_special` 仅在 `aptitude_id=="special"` 时才校验，但 `create()` **无条件**把 `p.aptitude_special` 与 `p.flags[aptitude_special]=true` 写入。于是 `aptitude_id="normal"` + `aptitude_special="parselmouth"` **通过校验**并白拿特殊天赋标记（`aptitudes` 全表 `grants` 为空，这是该类天赋标记的唯一来源）。更一般地，玩家可借该字段向 `player.flags` **注入任意键**（如 `werewolf`、`veela_heritage`、任意自定义 key） | 代码路径直读；`grep` 确认 `aptitudes[].grants` 均为 `[]`、无其它授予通道；测试仅覆盖 `aptitude_id=="special"` 的合法/非法两例，无负例 | 当 `aptitude_id != "special"` 时要求 `aptitude_special` 为空（否则报 `aptitude_special` 非法），并让 `create()` 仅在 `aptitude_id=="special"` 时写 `p.aptitude_special`/标记；补负例测试 |
| 2 | Important | `character_creation.gd:25-83`（缺失）→ `:164,172` | **`birthplace` 未校验**即被写进 `p.birthplace` 与 `p.location_id`。非法值会让 `WorldState.current_location()`（`world_state.gd:41`）返回 `{}`，并在 `tick()` 的 `zones.has(player.location_id)` 处**静默过滤掉全部带 zones 的传闻**（无回退）。且 `birthplace` 缺省时 `p.birthplace=""` 而 `p.location_id="london_muggle"`，两字段口径不一致 | `world_state.gd:41,93`；create 直读；测试只断言合法值 `"london_muggle"`，无非法值负例 | validate 增加 `registry.has("locations", birthplace)` 与空值检查；或明确拆开 `birthplace`（叙事）与 `location_id`（地点 id）两个键 |
| 3 | Important | `data/wand_cores.json:2-7` + `character_creation.gd:94-103` | **`rarity` 是死字段**：计划 Interfaces 声明「杖芯带 `rarity`」，但 `generate_wand` 对全部 6 种杖芯**均匀** `stream_pick`，`grep -rn rarity src tests` 零引用 → 凤凰羽毛/夜骐尾羽/媚娃头发与独角兽尾毛等概率，稀有度旋钮完全失效（与 Task 5 的 `weight` R2 同类，均为计划级缺口） | 全仓 grep；计划 Interfaces 第 1920 行；计划未指定任何按 rarity 抽取的规则 | 二选一并同步计划：实现按 `rarity` 加权抽取；或明确杖芯均匀、删除/改述 `rarity` |
| 4 | Minor | `character_creation.gd:73-83` | **玩家自带魔杖的 `length_inches` 未校验**（只校验 wood/core/flexibility，`label` 亦不校验/不补全）。计划测试又只验证**生成**魔杖的长度取自 `wand_lengths` → 玩家可传入任意长度（如 100 英寸）且整条「自带魔杖」分支（validate 的 wand 段 + `p.wand = wand_choice`）**零测试覆盖** | 代码直读；`tests/creation_test.gd` 中 `"wand": {}` 恒为空，无 `"wand"` 非空用例 | 校验 `length_inches` 是否落在 `wand_lengths` 的 `inches` 集合（及 `label` 一致性）；补自带魔杖正/负例测试 |
| 5 | Minor | `character_creation.gd:165,48-50,131-137` | 多重小缺陷：(a) `p.personality = choices.get("personality", [])` **与调用方共享数组引用**（后续改 choices 会改玩家状态）；(b) 校验只有 `< 3` 下限，**无上限、无非空校验**，可塞 30 个关键词为某学院堆分；(c) `assign_house` 用**双向** `contains`，过宽——尤其 Godot `String.contains("")` 语义下空串元素会匹配**每一条**关键词，`personality=["","",""]` 可让四院全部暴涨 | 代码直读；`String.contains("")` 为文档语义（本轮受只读约束未跑探针，见「未验证」） | 复制数组（`duplicate(true)`）；要求恰好 3 个且元素非空字符串；关键词匹配改为单向或分词精确匹配 |
| 6 | Minor | `character_creation.gd:213-214` | `flags` 是「存在即真」的标记容器（`world_state.gd:96-99` 按 `has()` 消费），却写入 `float` 的 `prejudice_level`（`flags` 为无类型 `Dictionary`，故不报错），类型混装；且键 `p.flags[p.aptitude_special]` 由玩家输入决定（与发现 #1 同源）。建议把 `prejudice_level` 提为 `PlayerState` 数值字段，`flags` 只留 bool | `player_state.gd:32` 无类型；`character_creation.gd:214` | 新增 `prejudice_level: float` 字段；`flags` 值统一 bool |
| 7 | Minor | `tests/creation_test.gd:79,128,134` | 测试强度/空转：(a) `a.is_true([...4 院].has(sly_house))` 只验「是四院之一」，**测不出血统偏置/性格匹配失效**（应断 `== "slytherin"`）；(b) `"未入学不判学院"` 走的是 `house_id!="system"` 的**提前返回**分支，`magic_aptitude/age<11 → "none"` 这条分支未被覆盖；(c) `squib` 的 `no_magic` 断言**部分空转**（`bloodlines.json` 的 squib `default_flags` 已含 `no_magic`，删掉 create 的显式写入仍会通过）；(d) 缺 #1/#2/#4 的负例断言、无自带魔杖用例、无 `prejudice_level` 断言 | 测试源码 + 数据核对 | 收紧 (a)(b)；用「非哑炮血统 + 缺 flag」的构造区分 (c)；按发现 #1/#2/#4 补负例 |
| 8 | Minor | `character_creation.gd:196-197,210-211` | 冗余/死路径：哑炮分支 `p.job = ""` 与 `new_default()` 相同、`p.flags["no_magic"]=true` 与血统 `default_flags` 重复；`for granted in aptitude.get("grants", [])` 因**所有 aptitudes 的 grants 均为 `[]`** 而恒空转（无内容、无测试） | 数据 + 代码核对 | 删冗余写入；为 `grants` 补内容或在计划中标注「预留」 |

## 对计划修正的裁定

**判定：wood 修正正当、唯一正确、无夹带。**

1. **类型事实核对**：`src/core/rng_service.gd:23-26` 签名为 `stream_pick(name: String, options: Array)`，实现 `return options[stream(name).randi_range(0, options.size() - 1)]` —— 返回的是**被抽中的元素**（此处为木材 id 字符串），返回类型随 `Array` 元素；传入的 `registry.ids("wand_woods").duplicate()` 为 `PackedStringArray`（测试全绿证明其可被 `Array` 形参隐式接收）。因此计划原文 `var wood: Dictionary = rng.stream_pick(...)` 在运行期必然抛
   `Trying to assign value of type 'String' to a variable of type 'Dictionary'`，是**确定性红灯**，属真实计划缺陷而非风格问题。
2. **改法唯一合理**：`var wood: String = str(rng.stream_pick(...))` 与后文 `registry.entry("wand_woods", str(wood))`、`"wood": str(wood)` 类型自洽；`str()` 包裹同时兜住空表 `null` 边界。（严格说 `var wood = ...` 不加类型也能跑，但简报强制的显式 `String + str()` 形式更清晰且不改变语义，无过度修改。）
3. **无夹带**：`git diff d4186c5..f3d8a31 -- <计划文档>` 只有这一个 hunk（第 2298 行）；`git diff d4186c5..f3d8a31 -- src/core/registry.gd tests/run_tests.gd` 只有简报要求的追加；`data/*.json`、`character_creation.gd`、`creation_test.gd` 与计划其他代码块**逐字相同**。除该行外**计划文档与代码无其它差异**（`wand_lengths.json` 仅省略一行 JSON 非法注释）。实现者报告对依据的陈述与代码现状一致。

## 未验证/存疑

- **无 Critical**，故无最小复现。
- 发现 #1、#5 的具体触发未做端到端探针（受只读约束未写临时脚本）：结论来自代码路径直读；#1 的路径无分支歧义，确定成立。#5(c) 依赖「Godot 4 `String.contains("")` 返回 true」这一文档语义，未实测，故降级为 Minor 并标注。
- 发现 #2 的下游后果（`location_id` 非法 → 传闻被静默过滤）由 `world_state.gd:41,93` 推演，未构造非法 `birthplace` 跑 `tick()` 验证。
- 发现 #3 只证明 `rarity` 当前零引用；计划是否原本就打算「均匀抽取、rarity 仅作叙事」未在计划中明说，故按 Interfaces 声明与 Task 5 `weight` 的既有裁定（Important）对等处理，controller 若认定其为叙事字段可降为 Minor。
- 未验证 `validate_choices` 在 `bloodline_id` 非法时 `registry.entry` 返回 `{}` 导致的多余 `magic_aptitude` 默认错误（仅错误文案冗余，不改变「拒绝创建」结论）。
- 未验证 `str(rng.stream_pick(...))` 在 `wand_woods` 为空表时的 `"<null>"` 表现（`Registry.validate()` 已有「数据表为空」约束且测试断言 ≥10，现网不可达）。
- 计划级缺口（#1 校验门控、#2 birthplace、#3 rarity）与实现代码逐字一致，**属计划自身需修订**；本次实现严格遵循简报「逐字照抄」，故不计为实现的规格违背，但建议在 Task 7 之前对计划做一次小幅修正裁定。
- `[probe] 断言=1 失败=1` 是 harness 有意自检，不在 `SUITES`，不计入总计失败；与本次审查无关。

---

# 修复轮 1 scoped 复审

# Task 6 修复轮 scoped 复审

复审者：reviewer（独立只读子代理）　模型：deepseek-flash　范围：f3d8a31..2341540

## 结论
- Important #1：**ADDRESSED**（注入路径两道门均已落地、互不依赖；但有**相邻残留** N1：`random` 掷定为 `special` 时产生「特殊资质无天赋」不一致，见残留表）
- Important #2：**ADDRESSED**（非法/空/缺省 `birthplace` 全部被拒；12 血统全路径零误伤；`p.birthplace == p.location_id` 实测一致）
- Minor #5：**已收窄**（`.duplicate()` 隔离实测成立；空关键词校验覆盖；学院断言精确化 + 哑炮覆盖；残留双向 `contains` 子串过宽与「无上限」未动，属 #5 未要求的范围）
- 有无新问题/夹带：**无夹带**（仅 3 个文件、全部在 Task 6 计划清单内，无 `.uid`/`data/`/越界文件、无格式噪声）；**有新问题**（N1 Important；N2/N3 Minor，均列于残留表）
- 总评：**通过**（三项声明修复均成立且可证伪，无 Critical、无回归；N1 当前无任何消费者、无崩溃/漏洞，建议登记为紧随其后的一行微修，不拦下本轮）

## 证据

### 1) diff 逐行核对（`git diff f3d8a31..2341540`）
```
M docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
M src/rules/character_creation.gd
M tests/creation_test.gd          → 3 files changed, 70 insertions(+), 10 deletions(-)
```
- 计划文档 7 个 hunk（`@@2012/2038/2067` 测试块、`@@2268/2299` validate 块、`@@2397/2438` create 块）**全部落在 Task 6 章节（1896–2480 行）** 的四个围栏代码块内，无其它计划改动。
- `character_creation.gd` 只含 3 个语义块：`birthplace` 校验、`personality` 空关键词校验、`aptitude_special` 的 `elif` 门与 `create()` 的 `special` 门；外加 1 处 `.duplicate()`。与 controller 声称的 #1/#2/#5 一一对应。
- `creation_test.gd` 只含 +5 断言对应内容（漏洞负例 ×2、非法出生地 ×1、空关键词 ×1、哑炮不判学院 ×1）与 `sly_house` 改精确断言；无其它改动。
- 结论：**无夹带、无越界**。

### 2) 计划 Step 1 / Step 4 逐字一致（围栏块抽取 + diff）
```
sed -n '1928,2091p'   计划 → diff vs tests/creation_test.gd            : SAME (164 行)
sed -n '2224,2458p'   计划 → diff vs src/rules/character_creation.gd   : SAME (235 行)
```

### 3) 仓库内 `bash tools/test.sh` 原始关键行（单实例）
```
[probe] 断言=1 失败=1                    ← harness 有意自检，不在 SUITES
[creation] 断言=146 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```
四项必须条件 + 退出码 0 全部吻合；`141 + 5 = 146` 与新增断言数自洽。测试前后 `git status --porcelain` 均为空，HEAD 始终 `2341540`。

### 4) #1 两道门充分性（独立沙箱验证，副本位于 `/tmp/hali_probe.*`，非仓库文件）
- **唯一写 `flags` 的通道**：`grep -rn '\.flags\[' src/` → 仅 5 处：`no_magic`（固定键）、`bloodline.default_flags`（数据白名单）、`aptitude.grants`（当前全表 `[]`）、`aptitude_special`（本轮加门）、`prejudice_level`（固定键）。**任意键注入已无路径。**
- **validate 门实测**（沙箱，seed 1）：
  `normal + aptitude_special="werewolf"` → `errors=["aptitude_special 只有 aptitude_id=special 时才能设置: werewolf"]`，`player==null`
  `random + aptitude_special="parselmouth"` → 同样被拒（`elif` 对 `random` 亦生效），`player==null`
- **合法 special 流程实测**：`special+seer` → `errors=[]`、`aptitude_special="seer"`、`flags.has("seer")==true`；`special+werewolf` → `aptitude_special 非法…`；`special+""` → `aptitude_special 非法: ，允许值 metamorphmagus, parselmouth, seer, transfiguration_talent, occlumency_talent`。行为符合预期。
- **`random` 掷定为 `special` 的残留（N1）**：随机池 `registry.ids("aptitudes")` 仅排除 `random`/`squib`，而 `special` 在表内 → 实测 500 次 `random` 创建中 **122 次落在 `special`（24.4%，如 seed 2000）**，此时 `aptitude_id=="special"` 而 `aptitude_special==""`、`flags` 仅有 `prejudice_level` → 「特殊资质但无天赋」不一致。**这不是注入漏洞**（不写任意键），但 `data/aptitudes.json` 的 note 明示「需指定具体天赋」，且计划 create 分支注释只承诺「不得掷出哑炮」，未处理此情形。
- **`create()` 门是纯纵深防御**（controller 自述，独立复现确认）：
  - Patch A（删 validate `elif` 门）：`[creation] … 非特殊资质携带 aptitude_special 必须被拒绝: 期望为真`、`…校验失败时不产出玩家: 期望为真` → 失败 2，EXIT=1
  - Patch B（删 `birthplace` 校验）：`…非法出生地必须报错: 期望为真` → 失败 1，EXIT=1
  - Patch A+B 合计 3 失败，与 controller 反证记录逐字吻合。
  - Patch C（**只**删 `create()` 的 `if aptitude_id == "special":` 门，保留 validate 门）：`[creation] 断言=146 失败=0` → **无法被现有测试单独证伪**，确认为冗余防御。**评估：可接受**（`create()` 始终自调 `validate_choices`，两门在语义上等价；冗余无副作用，保留即可）。

### 5) #2 birthplace 正确性与误伤
```
birthplace=''            → ["birthplace 非法: "]
birthplace='不存在的出生地' → ["birthplace 非法: 不存在的出生地"]
birthplace='london_muggle'/'hogwarts' → []
缺失 birthplace 键        → ["birthplace 非法: "]      ← 空值/缺省均被拒
全部 12 血统 create 失败数 = 0                          ← 零误伤
hogwarts 路径 p.birthplace == p.location_id == "hogwarts" ← 口径一致
```
`locations` 表 21 个 id 全部为合法值；仓库内除 `character_creation.gd`/`creation_test.gd` 外**无其它调用方**（UI 属 Task 11），无误伤风险。`p.location_id = str(choices.get("birthplace", "london_muggle"))` 中的默认值现为**死代码**（validate 已强制该键存在且合法），但两字段口径已统一，无残留不一致。`grep` 确认 `rarity` 仍 0 引用、`failure_delta` 无生产消费者。

### 6) #3 `.duplicate()` 与空关键词
```
调用方 ch["personality"].append("野心"); ch["personality"][0]="篡改" 后：
  p.personality = ["好奇", "固执", "怕黑"]     ← 未受影响
  p.personality == ch["personality"] → false   ← 引用共享已切断
```
- `Array.duplicate()` 为浅拷贝；元素为 `String`（不可变值）→ 浅拷贝已足够，结论成立。
- 空关键词：`["", "好奇", "固执"]`（size=3，不触发下限错误）→ 仅「personality 关键词不得为空」命中，断言具判别力；`[" ","好奇","固执"]` 亦由 `strip_edges()` 覆盖。
- 附带实测：Godot **4.7.2 中 `"野心".contains("")` 返回 `false`**，故第一轮 #5(c) 的「空串匹配一切」前提**在本引擎版本不成立**；新校验属有效加固而非补漏。残留的双向 `contains` 子串过宽仍存在（实测 `"血统".contains("血") == true`，单字关键词可放大得分），但 #5 未要求改匹配方式，且「无上限（可塞 >3 关键词堆分）」也未动。

## 残留发现（含第一轮未处置项）

| # | 严重度 | 位置 | 问题 | 是否可留到后续任务 |
|---|--------|------|------|--------------------|
| N1（新） | Important | `character_creation.gd:112-121`（随机池）+ `:220-225` | `random` 可掷出 `special`（实测 122/500 ≈ 24.4%，seed 2000），此时 `aptitude_special==""` 且无天赋标记 → 「特殊资质无天赋」不一致；与数据 note「需指定具体天赋」矛盾 | **可留**（当前无任何 `aptitude_special`/`failure_delta` 消费者，无崩溃/漏洞），但**须登记**；建议 Task 7 前一行微修（池中排除 `special`，或随机时同掷 `special_option`）；属计划级缺口（计划注释只排除 squib） |
| 1-3（一轮 Important） | Important | `data/wand_cores.json` + `generate_wand` | `rarity` 死字段：`grep -rn rarity src/ tests/` = **0 引用**，6 种杖芯均匀抽取 | 可留（计划级缺口，与 Task 5 `weight` 同类，待计划裁定） |
| 1-4（一轮 Minor） | Minor | `character_creation.gd:171-172,181` | 自带魔杖 `length_inches` 未校验：实测 `length_inches=100.0` 通过创建（`errors=[]`）；自带魔杖分支仍无测试 | 可留 |
| N2（新） | Minor | `character_creation.gd:186` | `p.wand = wand_choice` 仍共享引用：实测调用方改 `choices["wand"]["wood"]` 后 `p.wand` 同步被改 —— 与 #5(a) 同类，本轮只修了 `personality` | 可留 |
| 1-6（一轮 Minor） | Minor | `character_creation.gd:225` | `prejudice_level`（float）写入「存在即真」的 bool 语义 `flags` | 可留 |
| 1-7b/c（一轮 Minor） | Minor | `tests/creation_test.gd:78-79`、`assign_house` | `no_magic` 断言仍部分空转（`bloodlines.json` 的 squib `default_flags` 已含 `no_magic`）；`age_years<11 → "none"` 分支仍未覆盖（`magic_aptitude==false` 分支已被新哑炮用例覆盖） | 可留 |
| 1-8（一轮 Minor） | Minor | `character_creation.gd:205-206,218-219` | `p.job=""` 与 `new_default()` 相同、`p.flags["no_magic"]=true` 与血统 `default_flags` 重复；`grants` 循环因全表 `grants=[]` 恒空转 | 可留 |
| N3（新） | Minor | `character_creation.gd:181` | `choices.get("birthplace","london_muggle")` 的默认字面量已成死代码（validate 已强制合法非空），易误导后续维护者 | 可留 |
| #5 未完全收窄 | Minor | `assign_house:161-165` | 双向 `contains` 子串过宽（单字关键词如 `"血"` 命中 `"血统"`）；无关键词数量上限。空串向量已由新校验封死 | 可留（#5 报的三项——非空、duplicate、精确断言——均已处置） |

## 未验证/存疑
- **N1 的下游影响未验证**：`failure_delta`（special = -0.10）与 `aptitude_special` 目前均无生产消费者（仅 `player_state` 序列化 + 测试引用），故 N1 的机械后果暂为潜在；未构造「消费 `failure_delta`」的场景。
- **#2 原始危害未端到端复现**：未验证 `WorldState.tick()` 在非法 `location_id` 下静默过滤带 `zones` 的传闻；本轮仅确认非法值现在**无法进入** `player.location_id`，从源头堵住。
- **`create()` special 门**：Patch C 实测 0 失败，确认无法单独证伪；「是否保留冗余门」属风格取舍（本报告评估为可接受，保留无害）。
- **`String.contains("")`**：本版 4.7.2 实测为 `false`，故第一轮 #5(c) 的原始前提在**该版本**不成立；其它引擎版本的语义未验证（不影响结论，因空关键词已被显式拒绝）。
- 沙箱验证使用 `/tmp/hali_probe.*` 的 `src`/`data`/`tests` 副本（含临时反证补丁），**未触碰仓库任何文件**；复核全程 `git status --porcelain` 为空、HEAD 恒为 `2341540`，未执行任何 git 写操作。
- 无 Critical，故无最小复现。

---

# 修复轮 2 scoped 复审

# Task 6 修复轮 2 scoped 复审

复审者：reviewer（独立只读子代理）　模型：deepseek-flash　范围：2341540..61ad053

## 结论
- **N1：ADDRESSED**（随机资质池已排除 `special`；合法 `special` 流程零影响；随机路径不再产出「无天赋的特殊资质」）
- **有无新问题/夹带：无夹带**（仅 3 个文件、4 增 2 删，全部落在 Task 6 计划清单内，无 `.uid`/`data/`/越界文件、无格式噪声）；**有新问题 3 条**（均为 Nit/Minor：注释未同步、硬编码 id 排除、存档载入不重校验，见残留表）
- **总评：通过**（修法正确且充分；新增 30 条断言经独立反证确认**非空转**；测试五项必须条件 + 退出码全部吻合）

## 证据

### 1) diff 逐行核对（`git diff 2341540..61ad053`）
```
docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md | 3 ++-
src/rules/character_creation.gd                                      | 2 +-
tests/creation_test.gd                                               | 1 +
3 files changed, 4 insertions(+), 2 deletions(-)
```
- 恰为 **3 处语义修改**，与 controller 声称一一对应：
  - `tests/creation_test.gd:136`：`+ a.ne(r.player.aptitude_id, "special", "随机资质不得掷出未指定天赋的特殊资质")`
  - `src/rules/character_creation.gd:193`：`- if cid == "random" or cid == "squib":` → `+ ... or cid == "special":`
  - 计划文档 2 个 hunk：`2063`（Step 1 测试块）、`2417`（Step 4 实现块），无第三处文档改动。
- 无新增/删除文件，改动行均为 LF、UTF-8（`cat -A` 行尾为 `$`，无 `^M`）；无隐藏空行/尾随空格改动。
- HEAD 恒为 `61ad05336f68be9e7dee26b501d00bf7ab102c4a`；复审前后 `git status --porcelain` 均为空（测试运行未产生仓库改动，`.godot` 已被忽略）。

### 2) 修法正确性与充分性
- **池内容**：`registry.ids("aptitudes")` = 6 项（`registry_test.gd:18` 断言 6 项），排除 `random/squib/special` 后池 = `[excellent, good, normal]` → `random` 只可能掷出这 3 个。
- **与数据语义一致**：`data/aptitudes.json` 的 `special` note 明示「需指定具体天赋：……」，其 `special_options` 非空且严格校验；`random` 无天赋可选，故排除 `special` 与数据自述一致。附带效果：`special` 的 `failure_delta=-0.10` 不再能通过随机获得，但这是「special 必须显式指定天赋」的必然推论，无规格冲突（计划内亦无「random 可掷出 special」的表述，`grep 随机` 全计划仅 2056/2058/2061/2062/2063/2411/2413/2417 处，全部为排除性描述）。
- **合法 `special` 流程不受影响**：`validate_choices:72-80` 在 `aptitude_id=="special"` 时要求 `aptitude_special ∈ special_options`（5 项），非 `special` 携带 `aptitude_special` 走 `elif` 报错；`create():221-224` 只在 `aptitude_id=="special"` 时写入 `aptitude_special` 与天赋标记。该分支完全未在 diff 中触碰，测试 `tests/creation_test.gd:119-127`（`special+parselmouth` → `errors=0`、`flags.has("parselmouth")`）本轮仍 **失败=0**。原有「非特殊资质注入 `aptitude_special` 必须被拒」用例（`:104-110`）亦仍通过。
- **其它产出「无天赋特殊资质」的路径**：全仓 `grep '"special"'` 仅命中数据表、`validate_choices:72/74`、`create:193/221`、测试 `120/136` —— `aptitude_id` 的唯一生产写入点是 `create():197`，随机分支已被封；非随机分支必经 `validate` 门。**创建路径已无残留路径**。唯一剩余的「不重校验」入口是存档反序列化（`WorldState.from_dict` → `PlayerState.from_dict:93-94`，见残留表 #9），当前无 save/load 调用方。
- **空 `aptitude_special` 不会被当合法**：`aptitude_id=="special"` 且空 → `allowed.has("")` 为假 → 报错；非 `special` 且非空 → 报错；非 `special` 且空 → 唯一合法组合。

### 3) 新增 30 条断言的**非空转**验证（独立沙箱反证，副本在 `/tmp/hali_review_sandbox`，已删除，未触碰仓库）
把 `src/rules/character_creation.gd:193` 还原为旧池（重新纳入 `special`），并在沙箱测试里加计数器后运行：
```
[probe] old-pool special hits=4
[creation] 随机资质不得掷出未指定天赋的特殊资质: 不应等于 <special>   ×4
[creation] 断言=176 失败=4
==== 总计失败=4，失败套件=1 ====
EXIT=1
```
- 与 controller 反证记录**逐字吻合**（4 次重复、失败=4、EXIT=1）→ 该断言对「有无 `special` 入池」具判别力，**非空转**。
- 判据的非空转性同时有统计支撑：旧池 4 项、30 次独立种子，「30 次全不中 `special`」概率 `0.75^30 ≈ 1.8e-4`；实测恰好 4/30 命中。
- 计数自洽：每轮 3 条断言 × 30 轮 = 90 条；新增 1 条/轮 → **+30**，与上一轮日志基线 `146 → 176` 完全一致（146+30=176）。

### 4) 仓库内 `bash tools/test.sh` 单实例原始关键行
```
[probe] 断言=1 失败=1              ← harness 有意自检，不计入 SUITES（既有设计）
[creation] 断言=176 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```
五项必须条件（`[creation] 断言=176 失败=0`、`==== 总计失败=0，失败套件=0 ====`、`ALL TESTS PASSED`、`全部通过。`、退出码 0）**全部吻合**；其余套件（harness 8 / registry 26 / money 15 / magic_level 22 / model 49 / clock 47 / world_tick 104）均失败=0，无回归。

### 5) 计划 Step 1 / Step 4 逐字一致（围栏块抽取 + diff，含 Tab 缩进）
```
diff <(sed -n '2056,2063p' 计划) <(sed -n '129,136p' tests/creation_test.gd)          → STEP1_WINDOW_IDENTICAL
diff <(sed -n '2411,2420p' 计划) <(sed -n '187,196p'  src/rules/character_creation.gd) → STEP4_WINDOW_IDENTICAL
```
计划 2056（`# ---- 随机资质…` 注释）、2061–2063（3 条 `ne`）与测试 129、134–136 完全一致；计划 2411（`# 资质：random …`）、2413–2420（含 2417 的三条件排除）与源码 187、189–196 完全一致（`cat -A` 校验缩进为 Tab）。

## 残留发现

| # | 严重度 | 位置 | 问题 | 是否可留到后续任务 |
|---|--------|------|------|--------------------|
| 1 | Minor | `data/wand_cores.json` + `generate_wand` | `rarity` 死字段：`grep -rn rarity src/ tests/` = **0 引用**（仅数据表内 6 处），杖芯 6 种均匀抽取 | 可留（计划级缺口，与 Task 5 `weight` 同类，待计划裁定） |
| 2 | Minor | `character_creation.gd:102-112` | 自带魔杖只校验 `wood/core/flexibility`，**不校验 `length_inches`**（任意值可通过；上一轮实测 `100.0` → `errors=[]`）；自带魔杖分支仍无测试 | 可留 |
| 3 | Minor | `character_creation.gd:225` | `p.flags["prejudice_level"] = float(...)`：float 值写入「存在即真」语义的 `flags`，与 `no_magic` 等 bool 标记异质 | 可留 |
| 4 | Minor | `tests/creation_test.gd:79` + `data/bloodlines.json`(squib) | `no_magic` 断言**部分空转**：squib 血统 `default_flags` 已含 `no_magic`，即使删掉 `create():205` 的显式写入也仍为真；哑炮血统却用 `magic_aptitude:false` 路径，未覆盖「有魔法血统 + `aptitude_id="squib"`」以外的 `no_magic` 组合 | 可留 |
| 5 | Minor | `character_creation.gd:205-206, 216-219` | 冗余写入：`p.job=""` 与 `new_default()` 同值；`flags["no_magic"]=true` 与血统 `default_flags` 重复；`aptitude.grants` 循环因全表 `grants=[]` 恒空转（当前无消费者） | 可留 |
| 6 | Minor | `character_creation.gd:161-165` | `assign_house` 双向 `contains` 子串过宽（`"血统".contains("血")` 型单字可放大得分），且性格关键词**无数量上限**（可堆分）；空串向量已由第一轮校验封死 | 可留（第一轮 #5 只要求非空/duplicate/精确断言，均已处置） |
| 7（新） | Nit | `character_creation.gd:187`、计划 2411、`tests/creation_test.gd:129` | 本轮改了逻辑但**注释未同步**：三处注释仍只写「不得掷出哑炮」，未提「也不掷 `special`」，后续维护者易误读为遗漏 | 可留（建议随手补一句，不拦本轮） |
| 8（新） | Nit | `character_creation.gd:193` | 三个 id **硬编码**排除；更稳健的数据驱动写法是「`special_options` 非空即不可随机掷定」。同时池非空无守卫（当前 6 项数据下不可达；`stream_pick` 空池返回 `null` → `str(null)` 会写入畸形 id） | 可留（属风格/加固，非缺陷） |
| 9（新） | Minor | `player_state.gd:84-94`、`world_state.gd:166-183` | 存档载入路径**不重跑 `validate_choices`**：手工/save JSON 可携带 `aptitude_id="special"` + `aptitude_special=""`，即「无天赋的特殊资质」仍可经反序列化进入状态（当前尚无 save/load 调用方，且无下游消费者） | 可留，但**须登记**；建议在实现存档（Task 7+）时补一次载入校验 |

## 未验证/存疑
- **`failure_delta` / `aptitude_special` 的下游消费者仍未端到端验证**：全仓 `grep` 确认 `failure_delta` 与 `aptitude_special` 目前无生产消费者（仅序列化 + 测试引用），故 N1 历史后果为潜在性；本轮未构造「消费资质修正」的场景。
- **池空极端情形仅推演、未实测**：`registry.validate()` 只查重复/空 id/label，不强制 `normal/good/excellent` 存在；若未来数据表缺失这三项，池会为空且无报错分支（当前数据固定、`registry_test.gd:18` 断言 6 项，不可达）。
- **反证沙箱**使用 `/tmp/hali_review_sandbox` 的 `src/data/tests/tools/project.godot` 副本（含临时还原补丁与计数器），运行后已整体删除；**未触碰仓库任何文件**，未执行任何 git 写操作（仅 `git status/diff/rev-parse/show` 只读命令）。
- **基线 146 取自上一轮日志**（本轮未重跑旧提交），但 146+30=176 与本轮实测 176、以及每轮 1 条新增断言 × 30 轮完全自洽。
- 无 Critical/Important 残留 → 无最小复现需要；N1 判定为关闭。
