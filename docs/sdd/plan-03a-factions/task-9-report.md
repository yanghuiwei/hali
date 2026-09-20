# Task 9 报告 · 离线替身的派系动作接线

**状态**：DONE（绿灯）
**提交**：`a36faab`
**任务**：计划 03a Task 9 —— `ScriptedGameMaster` 关键词 → 派系 op（加入/退出/支持/反对），让 LLM 不可用时的降级路径不丢派系玩法。
**日期**：2026-09-20 ｜ 分支 `plan-03-factions`

---

## ① 提交哈希

`a36faab`

> 流程顺序：按仓库铁律「**先写报告文件再返回**」，本报告先落盘、随后一次提交（无追加提交），哈希已回填。

## ② 改动文件清单

| 文件 | 改动 | 是否在 brief 列出 |
| --- | --- | --- |
| `src/gm/scripted_game_master.gd` | +47：四个关键词组常量、`_detect_faction()`、`act()` 里的派系分支 | ✅ brief 列出 |
| `tests/gm_test.gd` | +95：Task 9 的 31 条断言（追加在 `return a.report("gm")` 之前，既有断言一条未改） | ✅ brief 列出 |
| `data/factions.json` | ±1：`black_market.aliases` 删掉裸地点名「翻倒巷」（保留「翻倒巷黑市」「黑市」） | ⚠️ **brief 未列**，但**控制器在开工指令里点名要求**（见 §⑦-3） |

`git diff --stat`：`3 files changed, 143 insertions(+), 1 deletion(-)`

**实现要点**
- 常量：`FACTION_JOIN = ["加入","投靠","效力","做事","入伙"]`（**按控制器修正**，原 brief 的「为…做事」含 U+2026 省略号，是死关键词）、`FACTION_LEAVE`、`FACTION_SUPPORT`、`FACTION_OPPOSE` 照 brief。
- `_detect_faction(world, text)`：只遍历 `WorldFactions.visible_faction_ids(world)`（即 `revealed == true`），逐条比 `label` 与 `aliases` 的子串；命中即返回该 id，否则返回 `""`。
- `act()` 里的插入位置：**施法分支之后、`TRAIN_KEYWORDS` 分支之前**；四个动作按 `LEAVE → JOIN → SUPPORT → OPPOSE` 顺序判定；只有「命中已揭示派系**且**命中关键词」才 `return`，否则**继续走原分支**。
- 旁白用 `world.registry.entry("factions", id)["label"]`（内容表取词，不硬编码）。

## ③ 测试原始输出（`bash tools/test.sh`）

**绿步（最终）**：`/tmp/t9-green-final.log`，逐字 `EXIT=0`

```
[harness] 断言=8 失败=0
[registry] 断言=244 失败=0
[money] 断言=18 失败=0
[magic_level] 断言=48 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=180 失败=0
[creation] 断言=176 失败=0
[spell] 断言=229 失败=0
[gm] 断言=102 失败=0
[panel] 断言=102 失败=0
[selfcheck] 断言=32 失败=0
[save] 断言=112 失败=0
[async_probe] 断言=2 失败=0
[llm] 断言=88 失败=0
[prompt] 断言=34 失败=0
[debug_mirror] 断言=23 失败=0
[factions] 断言=193 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
全部通过。
```

`EXIT=0`（逐字核对）。`SCRIPT ERROR` **2 条 = 基线 2 条**（与 `task-1-baseline.log` 逐字同位：`save` 的两个畸形载荷负例；本任务新增 0 条噪音）。`[probe] 断言=1 失败=1` 是断言库的自检哨兵（故意失败、不在 `SUITES` 内）。

**红步**：`/tmp/t9-red.log`，`EXIT=1`，`总计失败=1，失败套件=1`

```
SCRIPT ERROR: Invalid call. Nonexistent function '_detect_faction' in base 'RefCounted (ScriptedGameMaster)'.
套件未正常结束（未调用 report，运行期错误？）: res://tests/gm_test.gd
```

⚠️ **与 brief 的预期不同，如实报告**：brief Step 2 写「预期：失败（『加入魔法部』目前落到 idle，`deltas` 为空）」，但实际红步是**套件中止**（`_detect_faction` 尚不存在，直接调用即运行期错误）→ 运行器的 `report_calls` 哨兵把它判成「失败套件=1」，所以红步依然成立且 `EXIT=1`。这是仓库已知模式（`§8#56` 一族：**中止**与**干净失败**要分得清）；此处中止是「测未实现的 API」的固有结果，非测试设计缺陷。真正的干净失败断言在后面（见 §⑤ 的破坏实验）。

**额外证据（对外验收通道未被本任务破坏）**：`bash tools/b1_acceptance.sh` → **断言 82 条 / 失败 0 / EXIT=0**（该探针走的是同一套离线 `ScriptedGameMaster` 路径：练习魔药、对角巷打工、确认自检）。

## ④ 断言数前后对比

| 套件 | 前 | 后 | Δ | 说明 |
| --- | --- | --- | --- | --- |
| `[gm]` | 71 | **102** | **+31** | 全部为本任务新增（构成见下） |
| `[registry]` | 244 | 244 | 0 | 内容表删一个别名不改变断言数（无「别名计数」类断言，已 grep 确认） |
| `[factions]` | 193 | 193 | 0 | 本任务未触碰 `factions.gd` |
| 其余 15 套件 | — | — | 0 | 全部不变 |

新增 31 条构成：加入 4（op / tag / 旁白用 label / 端到端写入）· 退出 2（op / 端到端清空）· 支持 1 · 反对 1 · 泛称「部长」1 · 未揭示 4（`_detect_faction` 空 ×2 / 无 op / 落 idle）· 同句多派系 tie-break 1 · 普通动作不被吞 10（5 种动作 × 「走原分支」+「不产出派系 op」）· 黑市别名回归 7（数据自查 ×3 / 揭示前后裸地名 ×2 / 正式别名与简称 ×2）。

## ⑤ 控制器点名风险（逐条作答）

### 风险 1：分支顺序 / 不得吞掉普通动作 ✅
- 位置：`scripted_game_master.gd` 的 `act()` 中，施法分支之后、`TRAIN_KEYWORDS` 之前；只有 `faction_id` 非空且命中关键词才 `return`。
- **普通动作证据（5 种，各 2 条断言）**：`我去对角巷打工赚钱`→`work`、`我要练习魔药学`→`train`、`我去打听消息`→`social`、`我要休息一下`→`rest`、`我念出 照明咒`→`cast`；并各自断言**不产出任何派系 op**。
- **能失败的证据 D-A**：在派系分支前插入「`_detect_faction` 为空时提前 `return`」→ 上面 10 条 + 既有 5 条旧断言全红（`总计失败>0`）。还原后 md5 与破坏前逐字相同（`5384d9bb…`）。

### 风险 2：多派系同句的 tie-break ✅（确定性，已钉住）
- 规则：按 `visible_faction_ids()`（= `registry.ids("factions")`，**已排序**）遍历，返回**第一个**命中者。
- 断言：`我支持魔法部和古灵阁` → `gringotts`（`gringotts` < `ministry`，字典序），共 1 条。
- **能失败的证据 D-D**：把规则改成「最后一个命中」→ 该断言变红（`期望 <gringotts>，实际 <ministry>`）。
- 主观评价（如实登记）：这条规则**确定但粗糙**——它按 id 序挑派系，与「玩家句子里更强调哪个」无关。真实玩法下（LLM 主路径）由 LLM 产出 ops，降级路径才会遇到；若将来要改进，建议按「别名长度优先」或「派系 power 优先」，并同步改这条断言。

### 风险 3：未揭示派系不得凭空产出 op ✅
- 断言 4 条：`_detect_faction(sw,"我要加入食死徒")==""`、`_detect_faction(sw,"我支持那个人")==""`（隐藏派系的泛称别名同样不命中）、`act(...).deltas.size()==0`、`tags` 落 `idle`。
- **能失败的证据 D-B**：把 `_detect_faction` 的遍历从 `visible_faction_ids()` 换成 `registry.ids("factions")`（忽略揭示）→ 这 4 条全红（`期望 <>，实际 <death_eaters>`；`期望 <0>，实际 <1>`）。

### 风险 4：别名歧义 ✅
- `我支持部长` → `ministry` + `delta=5`（1 条断言，这是**有意**行为：`ministry.aliases` 含泛称「部长」）。
- 未揭示侧不命中：`我支持那个人`（`death_eaters` 的泛称别名）在食死徒未揭示时识别为空 —— 因为 `_detect_faction` 只扫可见集（与风险 3 共用断言）。
- 登记：泛称别名（「部长」「那个人」「神秘人」「报纸」「大众」）在对应派系揭示后会**扩大**匹配面；当前内容表下不会误伤既有动作文本（已把仓库里全部玩家输入文本过了一遍：打工/练药/上课/起床/赚一笔/照明咒/对角巷打工均无别名子串）。

## ⑥ 「普通动作不被吞」的证据

见 §⑤ 风险 1：5 种动作 × 2 条断言（`tags` 走原分支 + 0 条派系 op）＝10 条，全绿；破坏实验 D-A 下全红。

## ⑦ 未验证项 / 残余

1. **名词性文本的歧义未验证**：`text.contains(alias)` 是朴素子串匹配。例如玩家说「我最讨厌食死徒」（**反对**语义）→ 不含 `FACTION_OPPOSE` 关键词 → 落到 `idle`（不误判为支持，但也没有"表达立场"的入口）；「凤凰社的联络人支持我」这类从句语义一律按第一个关键字处理。真实玩法由 LLM 主路径承担语义，这里只保证**降级路径确定且不越权**。属可接受范围，登记给 03b/05（信息与语义可信度）。
2. **同句多派系只处理一个**（见风险 2）：`faction_standing_delta` 一次只可能作用于一个派系；不支持「同时支持 A 并反对 B」。登记。
3. **`data/factions.json` 不在 brief 的文件清单里**（控制器点名）：改动是**删一个别名**，属于「恢复 Task 1 实现者自己声明的策略（刻意不收录裸地点名）」。已配 3 条数据自查断言 + 2 条行为断言（揭示前后）。
4. **红步是套件中止而非干净失败**（见 §③ 的 ⚠️）：已在报告显式说明；断言本身的判别力由 §⑤ 的 4 组破坏实验承担。
5. **`_detect_faction` 是内部方法**，测试直接调用（`sg._detect_faction(...)`）。按 GDScript 约定 `_` 只表"内部"，可调用；若将来重命名，这 9 条断言需同步改（已在断言文案里写明用途）。
6. **未验证**：真实 LLM 主路径下「支持/反对/加入」的 ops 是否与 LLM 输出冲突（如 LLM 同时产出相反立场）—— 属 B2/LLM 行为，不在本任务范围。

## ⑧ 破坏实验汇总（4 组，全部还原后 md5 逐字一致）

| 组 | 破坏内容 | 结果 | 命中断言 |
| --- | --- | --- | --- |
| **D-A** | 派系分支前插入「无派系时提前 return」 | 红 | 10 条新增（普通动作）+ 5 条既有（train/work/财富） |
| **D-B** | `_detect_faction` 忽略揭示、扫全部 17 个派系 | 红（4 条） | 未揭示 4 条（`断言=102 失败=4`） |
| **D-C** | `data/factions.json` 把「翻倒巷」加回别名 | 红（2 条） | 数据自查 + 「揭示后裸地名仍不识别」（`断言=102 失败=2`） |
| **D-D** | tie-break 改成「最后一个命中」 | 红（1 条） | 同句多派系取 id 字典序（`期望 <gringotts>，实际 <ministry>`） |

还原校验：`src/gm/scripted_game_master.gd` md5 `5384d9bb28841c9e083c98353d5d28f4`、`data/factions.json` md5 `6237903cfa6c4cb92f15ae774ec271f3`（破坏前后一致）。

## 提交信息

```
feat(gm): 离线替身支持加入/退出/支持/反对派系（计划 03a Task 9）

- FACTION_JOIN/LEAVE/SUPPORT/OPPOSE 四组关键词 + _detect_faction()（只扫已揭示派系）
- act() 在施法之后、TRAIN 之前插入派系分支；未命中时不提前 return（普通动作不受影响）
- data/factions.json：black_market.aliases 删掉裸地点名「翻倒巷」（保留「翻倒巷黑市」「黑市」），
  恢复 Task 1 声明的「不收录裸地点名」策略，避免「去翻倒巷」被误判成派系动作
- tests/gm_test.gd：+31 断言（含 4 组破坏实验的对应断言）
```
