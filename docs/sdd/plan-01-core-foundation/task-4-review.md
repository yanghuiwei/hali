# Task 4 审查记录（第一轮完整审查 + 修复轮 scoped 复审）

> 由 controller 从两个独立 reviewer subagent 的输出原样转存（模型均为 deepseek-flash）。
> 第一轮范围 `eccc871..2e3deb8`；修复轮范围 `2e3deb8..8264ef9`。

---

# Task 4 审查记录

审查者：reviewer subagent（独立只读）　模型：deepseek-flash　范围：eccc871..2e3deb8

## 结论
- 规格符合：✅（字段/方法/测试逐字符合计划 Step 1–5；计划 Interfaces 段本身与 Step 代码有 3 处内部不一致，实现按 Step 代码，见发现 #5）
- 裁定：**Approved with findings**
- 关键数字：Critical=0，Important=2，Minor=6

## 证据

**提交与范围**
- `git log --oneline -1` = `2e3deb8 feat(model): 时钟、玩家与世界状态模型`；`git status --short` 审查期间始终为空。
- `git diff --stat eccc871..2e3deb8`：12 files changed, 356 insertions(+), 2 deletions(-)。
- 改动清单（全部在 Task 4 范围内）：`docs/.../2026-09-18-hp-magic-era-01-core-foundation.md`(M)、`src/core/game_clock.gd`(+.uid)、`src/core/json_util.gd`(+.uid)、`src/model/player_state.gd`(+.uid)、`src/model/world_state.gd`(+.uid)、`tests/model_test.gd`(+.uid)、`tests/run_tests.gd`(M)。**无越界文件**（未触碰 `data/`、`src/rules/`、`project.godot`，未新建 `src/gm|persist|ui`）。

**逐字核验（read-only diff，计划代码块 vs 提交文件）**
- `tests/model_test.gd` ≡ 计划 1024–1118 行（Step 1）；`src/core/game_clock.gd` ≡ 计划 1136–1168；`src/core/json_util.gd` ≡ 计划 1176–1199；`src/model/player_state.gd` ≡ 计划 1207–1321；`src/model/world_state.gd` ≡ 计划 1331–1410。除被裁定的魔杖价两行外**零差异，无夹带**。
- `tests/run_tests.gd`：`SUITES` 在 `magic_level_test.gd` 后追加 `"res://tests/model_test.gd"` ✅。
- 5 个 `.gd.uid` 与源码同提交；测试后 `git status` 仍干净（uid 稳定）。

**必须自己跑的测试（仓库根，单实例）**
```
== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/3 单元测试 ==
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=15 失败=0
[magic_level] 断言=22 失败=0
[model] 断言=46 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```
- 独立复核断言数：`grep -cE "a\.(eq|ne|is_true|is_false|has_key…)\(" tests/model_test.gd` = **46**，与 `[model] 断言=46` 吻合。
- 未发现空转断言（详见发现 #6：仅 1 条偏弱）。

**往返/规范化静态核验**
- `PlayerState.to_dict()`（player_state.gd:73–82）与 `WorldState.to_dict()`（world_state.gd:50–60）均整体包 `JsonUtil.normalize()` ✅。
- `from_dict()` 对 `personality/wand/skills/magic/relations/flags/known_facts`（player_state.gd:97–113）与 `npcs/factions/locations/history/pending/world_vars/log/flags/rng_state`（world_state.gd:71–79）逐个 `normalize` ✅。
- `WorldState.to_dict()` 不含 `registry` ✅（测试 #45 验证）；`from_dict(d, registry_)` 重新挂载 ✅（测试 #43 验证）。
- 世界状态可整体 `JSON.stringify` 成功 ✅（测试 #46）。

## 发现
| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|
| 1 | Important | `src/model/world_state.gd:33` vs `:76` | **create 与 from_dict 对 `world_vars` 的类型处理不对称**：`create` 用 `duplicate(true)` 原样保留 JSON 解析出的 float（如 `0.0`/`1.0`），`from_dict` 却 `normalize` 成 int。导致「新建存档」与「读档」得到的内存对象类型漂移 | `data/eras.json`：`hogwarts_founding.secrecy_integrity=0.0`、`witch_hunts.secrecy_integrity=1.0` 为整数值 float；`first_wizarding_war` 恰好 7 项全为非整数（0.8/0.4/…），故现有测试查不出 | 计划级修正：`create` 也对 `world_vars` 走 `JsonUtil.normalize()`；或在计划里注明 create 允许 float |
| 2 | Important（推断） | `player_state.gd:97–113`；`world_state.gd:69–70` | 存档字段为**显式 `null`/非容器**时，`normalize(null)→null` 直接赋给类型化 `Dictionary/Array` 变量、或传给 `Dictionary` 形参，按 GDScript 类型化赋值语义会运行期报错（`Trying to assign Nil to Dictionary`）。from_dict 是外部存档边界，健壮性缺口 | 代码路径：`p.wand = normalize(d.get("wand", {}))`、`GameClock.from_dict(d.get("clock", {}))`；`to_dict` 自身不会产出 null，故正常往返安全，仅畸形/手改存档触发 | 加一层 `typeof` 校验/回退；或明确「存档只由 to_dict 产出，不做防御」并在计划中写明 |
| 3 | Minor | `src/model/player_state.gd:96` | 键名拼写 `d.get("political_leading_id", d.get("political_leaning_id",""))`。**当前无 bug**（to_dict 写正确键，回退命中；往返测试通过），但主键名拼错，且若存档同时含两键会优先取错键 | 计划 Step 4 原文即如此，worker 按简报「逐字照抄」保留（报告已披露） | 计划级修正为正确键名（或加注释说明是兼容别名） |
| 4 | Minor | `src/core/json_util.gd:6–23` | normalize 的契约边界未覆盖三类：①非有限 float（`is_finite` 为假时原样返回，无法 JSON 往返）；②≥2^53 的整数值 float 故意保留为 float（大整数存档 int→float 漂移）；③Dictionary **键**不做归一（int 键经 JSON 变字符串键 → 漂移） | 代码 `if is_finite(f) and f == floor(f) and absf(f) < 9007199254740992.0`；`out[key]=…` 未处理 key | 在计划/注释里明确这三条限制；当前游戏数值均有限且 |值| 远小于 2^53、键均为 String，暂无实际影响 |
| 5 | Minor | `world_state.gd:21`；`player_state.gd:30`；`json_util.gd:6` | 计划 **Interfaces 段**与自身 Step 代码不一致：`era_start_year` 字段、`PlayerState.new_default()` 方法、`JsonUtil.normalize` 的 `-> Variant` 返回标注，都不在 Interfaces 里/与 Interfaces 不同。实现遵从 Step 代码（符合简报「逐字照抄」），但报告「无功能增减」措辞因此不够准确 | 计划 1000–1020 行 Interfaces vs 1176/1242/1351 行 Step 代码 | 同步 Interfaces 段落，消除计划内部歧义 |
| 6 | Minor | `tests/model_test.gd:57,86,93` | 测试强度缺口：①「完全往返」是 `from_dict(to_dict())`，**未经过 `JSON.stringify/parse_string`** 端到端；且两侧 to_dict 都 normalize，即使 from_dict 漏归一某字段也会被输出端掩盖（检不出内存内类型漂移）；②`JSON.stringify(d).length()>0` 偏弱；③未覆盖 normalize 的 INF/大整数/键类型、`custom` 时代 null `start_year`、`advance_months(负数)` | 测试代码；严重度 Minor（核心机制已由 `{"n":493}` 的 raw JSON 断言单独证明，非空转） | 追加一条整档 JSON 往返断言 + 上述边界用例 |
| 7 | Minor | `world_state.gd:30–32` | `custom` 时代 `start_year` 为 null 时静默回退 1991，且月份固定 9；`create()` 签名无处接收玩家指定年份——与 `eras.json` 中 custom「由玩家指定年份」的语义不符 | `data/eras.json` custom `start_year:null`；计划 Step 5 原文即如此（计划级缺口） | 在计划层面把「玩家年份」纳入 create/后续任务参数；当前行为至少不崩溃、可预测 |
| 8 | Minor | `game_clock.gd:25,9` | `advance_months(负数)` 静默 no-op（`maxi(n,0)`），无报错也无文档；`from_dict` 缺省 `month=1` 与类默认 `month=9` 不一致（易误用） | 计划 Step 3 原文；测试只覆盖正数 | 计划级：负数显式拒绝或文档化；统一缺省月 |

## 对计划修正的裁定
**判定：修正正当、唯一（在裁定范围内）、无夹带。**

- **(a) 正典支持**：`哈利·波特·魔法纪元.md:223` 逐字为「一个普通巫师家庭年收入：约数百加隆。**一根普通魔杖：7‑10加隆。**…」，其上一级标题（第 219 行）即「## 第十八章·货币与贸易系统」，故代码注释「正典第十八章…7‑10 加隆」的行号与文字引用**准确**。
- **(b) 算术自洽**：`Money.KNUTS_PER_GALLEON=493`（src/model/money.gd:6）；`7×493=3451`；`4930−3451=1479`；`1479/493=3` 余 0 → `"3加隆 0西可 0纳特"`（已独立手算并对照 `parts()` 逻辑）✅。
- **(c) 两处一致且无夹带**：`git diff eccc871..2e3deb8` 在计划文档中**只有这一个 hunk**（删 2 行、加 1 注释 + 2 行代码）；`docs` 中旧文本「买魔杖后剩 9 加隆 / subtract(493)」已**无残留**（grep 全库确认）；计划 Step 1 代码块与 `tests/model_test.gd` 逐字 diff 为空。原写法其实算内自洽（4930−493=4437=9×493），问题只在「1 加隆」违背正典，故必须同时改扣款与期望两行——本次正是如此。
- 补充：正典给出的是一**区间** 7–10，单靠正典不能唯一推出 7；取 7 是 controller 在 `task-4-brief.md` 中明文裁定的「价格下限」，且 `HANDOFF.md` §8 第 2 条要求开 Task 4 前必须统一此矛盾。因此该值是**裁定唯一、正典合法**，注释引用无误。

## 未验证/存疑
1. 发现 #2 的崩溃行为为**基于 GDScript 类型化赋值语义的推断**，未实测（只读审查，不写临时脚本、不并发起第二个 Godot 实例）；`from_dict` 接收畸形 `null` 是唯一触发路径，正常 `to_dict→JSON→from_dict` 不触发。
2. 实现者报告中的**红灯阶段原始输出**（Step 2）无法在只读条件下复现验证（复现需回退代码）；仅绿阶段由我独立重跑并逐字一致。
3. `JsonUtil.normalize` 对 INF/NaN 经 `JSON.stringify` 的 Godot 具体行为（输出 `null` 还是非法 token）未实测，故 #4①仅表述为「无法保证往返」。
4. `world_vars` 类型漂移（#1）当前**未被任何断言或下游代码消费**，其实际危害需在该字段进入比较/规则计算后（Task 5 tick 等）再确认。
5. 报告称「计划文档第 1059–1060 行」（diff 实际落在 1059–1060）与简报所称「1060–1061 行」有 1 行编号差，属行号口径差异，内容一致，不影响裁定。

---

# Task 4 修复轮 scoped 复审

复审者：reviewer subagent　模型：deepseek-flash　范围：2e3deb8..8264ef9

## 结论
- 第一轮 Important #1：**ADDRESSED**
- Minor #3：**ADDRESSED**（对 `to_dict()` 产出的存档行为等价；未破坏任何真实旧键兼容，因该拼写键从未被任何版本写入过）
- 有无新问题/夹带：**无夹带**（diff 恰好 4 文件、5 项）；发现 1 项文档留档缺口 + 若干范围外遗留（详见残留发现），无新代码缺陷
- 总评：**通过**

## 证据

### 1. diff 逐行核对（无夹带、无越界）
`git diff --name-status 2e3deb8..8264ef9` 恰好 4 个文件，全部在 Task 4 范围内：

```
M  docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
M  src/model/player_state.gd
M  src/model/world_state.gd
M  tests/model_test.gd
```

`git show --stat 8264ef9` = 4 files changed, 28 insertions(+), 4 deletions(-)，与 `git diff --stat` 一致。逐行读 diff，内容**恰好**为 controller 声称的 5 项，无第 6 项改动、无注释外多余代码、未触碰 `data/`、`src/core/`、`src/rules/`、`project.godot`、`HANDOFF.md`：

| 声称项 | diff 落点 | 核对 |
|---|---|---|
| #1 world_vars 对称 | `world_state.gd:34` `duplicate(true)` → `JsonUtil.normalize((...).duplicate(true))` | ✅ 仅此一行 + 一行注释 |
| #2 新断言 | `model_test.gd` +11 行：`p3`/`w3`/`we2` 三条 `a.eq` | ✅ 恰好 3 条 |
| #3 键名 | `player_state.gd:96` → `str(d.get("political_leaning_id", ""))` | ✅ 仅此一行 |
| #4 计划同步 | 计划文档 3 个 hunk，与代码改动逐字同文 | ✅ 见第 6 节 |
| #5 反证 | 非 diff 内容 | 见第 5 节（独立复现） |

### 2. 修复 #1 正确且充分（独立验证，非仅推演）
`JsonUtil.normalize` 对 `TYPE_DICTIONARY` 递归重建新 dict，对「有限且 `f == floor(f)` 且 `absf(f) < 2^53`」的 float 返回 `int`。`from_dict` 侧原本就 `normalize`，故修改后两侧同型。

我在**沙箱副本**（`/tmp/hali_cf`，从仓库 `cp` 出来的独立目录，未改动仓库任何文件）中对 `data/eras.json` 全 8 个时代逐一实测 `create` vs `JSON.stringify→parse_string→from_dict`：

```
hogwarts_founding sym=true  kinds={... "secrecy_integrity": 2}   # int
witch_hunts       sym=true  kinds={... "secrecy_integrity": 2}   # int
grindelwald / first_wizarding_war / ... / custom  sym=true       # 其余键均为 float(3)
BAD_SYM=0
registry_after_mutation=1.0 typeof=3
```

- 8/8 时代 `create().world_vars` 与 `from_dict` 的 `world_vars` **类型严格深比较相等**（含 `secrecy_integrity` 为整数值 float 的两个时代：`hogwarts_founding 0.0`、`witch_hunts 1.0`）。
- 无新问题：`normalize` 新建 dict（含嵌套），`wa.world_vars["secrecy_integrity"]=0` 后 registry 原条目仍为 `1.0`（typeof float），「注册表只读、世界变量独立演化」的意图**未被破坏**，隔离性甚至强于原 `duplicate(true)`（嵌套层也被重建，不与 registry 共享任何引用）。
- 一处需计划层知晓的残留不对称（非本轮引入）：registry 原值仍是 float `1.0`，而 `world_vars` 内为 int `1`。若未来代码直接拿 `era()["world_vars"]` 与状态内 `world_vars` 比较，会因 Godot 字典类型严格比较而不等（见残留发现 #4）。

### 3. Minor #3 行为等价性
- 对 `to_dict()` 产出的存档：`to_dict()` 只写正确键 `"political_leaning_id"`（`player_state.gd:75`），删掉拼错键回退后取值路径**逐字等价**；`p3` 端到端断言与既有 `p2` 断言全绿。
- 旧键兼容：`git log -S "political_leading_id" -- src tests data` 仅命中 `2e3deb8`（引入该读取表达式）与 `8264ef9`（删除它）——**从未有任何提交通过 `to_dict()` 写出该键**；`SAVE_VERSION=1`、仓库无任何存档文件、persist 层尚未实现，故不存在真实旧档。沙箱实测：`from_dict({"political_leading_id":"x"})` 现在得 `""`（旧表达式得 `"x"`），`from_dict({"political_leading_id":"x","political_leaning_id":"y"})` 现在得 `"y"`（旧表达式会错误地取 `"x"`）。即：改动仅在「外来/手改 dict 携带拼错键」时改变行为，且是**修掉取错键的缺陷**，不是回归。

### 4. 3 条新断言确非空转
- 断言计数独立复核：`grep -oE "a\.(eq|ne|is_true|is_false|has_key|near|between|fail)\(" tests/model_test.gd | wc -l` = **49**，与 `[model] 断言=49` 吻合（46→49）。
- 关键点：`a.eq` 用 `!=` 深比较，Godot 字典比较对 Variant 值**类型严格**——套件内既有的 `a.ne(JSON.parse_string("{\"n\":493}"), {"n":493}, ...)` 通过即为证明，故 `a.eq(we2.world_vars, we.world_vars, ...)` 能真正区分 `1.0` 与 `1`。
- 反证（**独立复现**，在沙箱副本中执行，非引用 controller 结论）：把 `world_state.gd:34` 改回 `duplicate(true)` 后运行单测：

```
[model] world_vars 类型在 create 与 from_dict 间一致: 期望 <{... "secrecy_integrity": 1.0 }>，实际 <{... "secrecy_integrity": 1 }>
[model] 断言=49 失败=1
==== 总计失败=1，失败套件=1 ====
EXIT_COUNTERFACTUAL=1
```

与 controller 声称的失败文本/退出码一致，说明 `we2` 确实能捕获修复 #1。
- 为什么旧断言查不出：`w.to_dict()` 自身会 `normalize`，故 `from_dict(to_dict())` 类断言被输出端掩盖；`first_wizarding_war` 的 7 项恰好全为非整数（0.8/0.4/0.6/0.7/0.3/0.5/0.8），故必须新增 `witch_hunts` 场景 + 直接比较 `world_vars`（绕过 `to_dict`）。

### 5. 我跑的单实例测试（仓库根，唯一一次 `bash tools/test.sh`）
```
== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/3 单元测试 ==
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=15 失败=0
[magic_level] 断言=22 失败=0
[model] 断言=49 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```
要求的四个判据全部满足。测试前后 `git status --short` 均为空（`.gd.uid` 稳定）。

### 6. 计划文档 3 处逐字一致
用 `sed` 抽出计划代码块与源码 `diff -u`：`tests/model_test.gd`、`src/core/game_clock.gd`、`src/core/json_util.gd`、`src/model/player_state.gd`、`src/model/world_state.gd` **全部 IDENTICAL（零差异）**。即 Step 1（计划 1023–1130 行）、Step 4（1217–1333）、Step 5（1341–1423）与代码逐字一致，且计划 diff 的 3 个 hunk 与源码改动同文。

### 7. 只读性声明
- 仓库内**未修改任何文件、未做任何 git 写操作**（无 commit/stash/checkout/worktree），全程 `git status --short` 为空，`HEAD` 仍为 `8264ef9`，`git stash list` 为空。
- 实测反证在**仓库外沙箱副本** `/tmp/hali_cf` 中进行（`cp` 出 `project.godot/src/tests/data`，用仓库的 Godot 可执行文件 `--path` 指向副本）。命令：
  1. `cp -r project.godot src tests data /tmp/hali_cf/`
  2. `"$Godot" --headless --path "$(cygpath -w /tmp/hali_cf)" --import`
  3. `"$Godot" --headless --path <WIN> --script res://tests/run_tests.gd`（改前 49/0；改沙箱内 `world_state.gd:34` 后失败=1）
  4. 追加 `res://tests/tmp_probe.gd` 做全时代对称性与 registry 隔离验证
  5. **已还原并删除**：`rm -rf /tmp/hali_cf`（已确认不存在），`/tmp` 无残留；仓库 `git status` 仍为空。
  反证全程顺序执行，未并发运行第二个 Godot 实例与 `tools/test.sh` 冲突。

## 残留发现
| # | 严重度 | 位置 | 问题 | 建议 |
|---|--------|------|------|------|
| 1 | Minor（留档） | `.superpowers/sdd/.../task-4-report.md` | 修复轮报告**未更新**：仍写「提交 2e3deb8」「断言=46」「政治倾向键名差异原样保留」，与本轮 8264ef9/49/已修正不符；controller 声称的反证原始输出**在仓库内无留档**（`task-4-rereviewer.log` 为空文件） | 补一节「修复轮」或在报告中登记 8264ef9 的反证命令与输出，保证 claim #5 可追溯 |
| 2 | Minor | `src/model/player_state.gd:96` | 删除拼错键回退后，外来 dict 若只含 `political_leading_id` 会被静默丢弃为 `""`（无警告）。对 `to_dict()` 存档无影响，当前无旧档 | 若日后需要兼容外部/手写档，在计划中显式写明该键已废弃；当前可接受 |
| 3 | Minor（范围外遗留，第一轮 #6 部分未闭合） | `tests/model_test.gd` | 本轮补上了 JSON 端到端与类型一致性，但仍有强度缺口：`JSON.stringify(d).length()>0` 偏弱；`normalize` 的 INF/大整数/字典键类型未覆盖；`custom` 时代 `start_year:null`、`advance_months(负数)` 未覆盖 | 后续任务补边界用例，或明确记录为已知限制 |
| 4 | Minor（本轮修复的副产物，需计划层知晓） | `world_state.gd:34` vs `Registry` 原值 | `world_vars` 内整数值已归一为 int，而 `era()["world_vars"]`（registry 原值）仍为 float `1.0`（实测 typeof=3）。状态内一致性已保证，但「registry 基线」与「状态变量」类型不同；若未来代码直接比较二者会因类型严格比较而不等 | 在计划/注释中约定：比较前一律走 `JsonUtil.normalize`，或统一在 Registry 载入时归一（会影响 `registry_test`，需单独立项） |
| 5 | Important（范围外遗留，第一轮 #2） | `player_state.gd:97–113`、`world_state.gd:69–70` 等 | 存档字段为显式 `null`/非容器时，`normalize(null)→null` 赋给类型化 `Dictionary/Array` 可能运行期报错；本轮未处理（不在简报 5 项内） | 仍建议加 `typeof` 校验/回退，或明确「存档只由 to_dict 产出」 |
| 6 | Minor（范围外遗留，第一轮 #5） | 计划 1000–1020 行 Interfaces 段 | 与 Step 代码仍不一致（缺 `era_start_year`、`new_default()`、`normalize -> Variant` 标注口径） | 同步 Interfaces 段 |

## 未验证/存疑
1. **控制器反证无仓库留档**：`task-4-report.md` 未更新（见残留 #1），故其「改回 duplicate(true) 后 `[model] 失败=1`、退出码 1」的原始输出无法在仓库内核对；但我已在独立沙箱复现出**等价结果与文本**（`期望 …"secrecy_integrity": 1.0 …，实际 …": 1 …`、`断言=49 失败=1`、EXIT=1），故该声称的**实质**成立，仅**留档**缺失。
2. 第一轮 Important #2（畸形 `null` 存档崩溃路径）本轮范围外，仍未实测验证；其触发条件为「外来/手改存档」。
3. `JsonUtil.normalize` 对 INF/NaN 经 `JSON.stringify` 的 Godot 具体行为仍未实测（第一轮存疑 #3 延续）。
4. `world_vars` 归一为 int 对**未来**下游（Task 5 tick、规则计算）是否引入 `typeof` 依赖类问题，当前无消费方，无法验证；建议在 Task 5 落地时留意残留 #4。
5. 本次未核查 `2e3deb8` 之前的历史与 `data/` 内容是否还有其它拼写类键名偏差（超出 scoped 范围）。

未发现 Critical。
