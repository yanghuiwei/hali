# Task 9 审查记录

审查者：reviewer subagent（只读）　模型：deepseek-flash　范围：463a73d..d9135ab

## 结论
- 规格符合：✅
- 裁定：**Approved with findings**
- 关键数字：Critical=0，Important=0，Minor=6

## 证据

**提交与范围（`git show --stat d9135ab`）**
```
d9135ab feat(ui): 第六十二至六十五章面板与第七十二章强制自检  (parent 463a73d, merge-base ancestor: YES)
 src/rules/self_check.gd       |  94 +++++++++++++++++-
 src/ui/panel_formatter.gd     | 141 +++++++++++++++++++++++++++++++
 src/ui/panel_formatter.gd.uid |   1 +
 tests/panel_test.gd           |  88 +++++++++++++++++
 tests/panel_test.gd.uid       |   1 +
 tests/run_tests.gd            |   2 +
 tests/selfcheck_test.gd       |  69 ++++++++++++++++
 tests/selfcheck_test.gd.uid   |   1 +
 8 files changed, 395 insertions(+), 2 deletions(-)
```
`git diff --name-only 463a73d..d9135ab` 恰为上列 8 个文件，无 Task 9 范围外文件。

**逐字照抄核验（自计划提取代码块与成品逐行 diff）**
- `tests/panel_test.gd`：**IDENTICAL**
- `tests/selfcheck_test.gd`：**IDENTICAL**
- `src/rules/self_check.gd`：**IDENTICAL**（`AUDIT_INTERVAL := 15`、`is_audit_turn(turn){turn>0 and turn%15==0}`、`snapshot`、`ooc_report`、`report = snapshot + "\n" + ooc_report` 全一致；Task 8 最小桩的 `report` 被替换）
- `src/ui/panel_formatter.gd`：仅 1 处新增
```
39a40
> 	lines.append("【姓名】%s" % p.name_text)
```
- `tests/run_tests.gd`：仅 `+2` 行，在 `"res://tests/gm_test.gd",` 之后追加 `panel_test.gd` / `selfcheck_test.gd`，顺序与计划一致，无其它改动。

**`.uid` 卫生（强制裁定）**
```
d9135ab:src/ui/panel_formatter.gd.uid = uid://dig5cgefejgyf   (新增，入库)
d9135ab:tests/panel_test.gd.uid      = uid://bm14ubmby2x2p   (新增，入库)
d9135ab:tests/selfcheck_test.gd.uid  = uid://bcraqgb57ydit   (新增，入库)
463a73d/d9135ab:src/rules/self_check.gd.uid = uid://7hw8htetmt7e (未变，未入 diff — 与报告一致)
```
三条新脚本 `.uid` 均随提交入库；`self_check.gd.uid`、`run_tests.gd.uid` 已在库。

**接口签名（对计划 Interfaces）**：`PanelFormatter` 六方法 `player_panel/magic_panel/relation_panel/power_panel/status_line/events_block` 类型化签名一致；`SelfCheck` 五项一致。

**独立跑测（`bash tools/test.sh`，单实例，本次复跑原始行）**
```
[probe] 断言=1 失败=1
[gm] 断言=38 失败=0
[panel] 断言=65 失败=0
[selfcheck] 断言=26 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```
（`[probe]` 为断言库故意失败探针，不在 `SUITES`。）`gm` 38 条仍通过 → `TurnEngine.submit` 第 15 回合 `SelfCheck.report` 仍含「剧情快照」「人设OOC自检报告」两段标题（`src/core/turn_engine.gd:48-50`），`is_audit_turn` 语义未被改动。

**自检四项独立复核（逐条对源）**
| 检查 | 触发路径 | 命中测试 | 结论 |
|---|---|---|---|
| 人物行为偏离设定 | `npcs[*].ooc_violation==true` (`self_check.gd:57-62`) | w5 | ✅ 真命中 |
| 魔法规则被破坏 | `flags.illegal_cast_count>0` (`:65-68`) | w2=2 | ✅ |
| 历史时间线错误 | `clock.year < era_start_year`（modern=1991）(`:71-81`) | w3=1900 | ✅ |
| 玩家信息被提前泄露 | `known_facts[..]=="system"` 或空 (`:85-91`) | w4 | ✅ |
| 干净世界 | 四项均 "通过" | w 基线 | ✅ |

`report` = `snapshot + "\n" + ooc_report`；`snapshot` 七项齐全（当前时间/地点/玩家状态/关键NPC状态/当前进行中事件/已发生重大事件/世界变量）；世界变量按 key 排序、`%.2f`。`data/eras.json` 全部 `world_vars` 为数值，`float()` 无运行期风险。

**工作区**：`git status --porcelain` 仅 `?? docs/sdd/plan-01-core-foundation/review-463a73d..d9135ab.diff`（controller 事后生成的审查包，非本次提交内容）；提交时干净。审查包头部与提交列表/统计一致。

## 发现
| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|
| 1 | Minor | `src/ui/panel_formatter.gd:106-116` | 第六十五章「国际」与「麻瓜关系」同映射到 `muggle_relations`；连同 HANDOFF §8#7 已登记的 法律执行→`war_pressure`、傲罗/稳定度→`ministry_stability`、威森加摩/腐败度→`corruption`，共 7 标签压到 4 变量。「国际↔麻瓜关系」这组重复未被 §8#7 覆盖 | 正典 `哈利·波特·魔法纪元.md:664` 要 10 个独立标签，但 `world_vars` 仅 7 键 | 纯显示，无新误映射（逐字照抄计划）；建议把 §8#7 登记扩为「7 标签→4 变量」或后续补 `international_relations` 等键 |
| 2 | Minor | `src/rules/self_check.gd:57-62` | 第七十二章第 1 项「人物行为偏离设定」在 `src/`、`data/` 全库无写入者（`grep ooc_violation` 仅命中 self_check 与测试）；生产路径恒为「通过」，检查空转 | 全库 grep | 计划级；由叙事层/未来任务显式写 `ooc_violation`，或在计划注明该字段为人工/AI 标注项 |
| 3 | Minor | `tests/panel_test.gd` / `tests/selfcheck_test.gd` | 负例与弱断言：`events_block` 空数组未测；`_top_skill`/`_skills_line` 空技能未测；`_label` 未知/空 id 回退未测；`relation_panel` 空关系分支未测；非哑炮空魔杖回退「未拥有」未测；`snapshot` 空 npcs/pending/history 分支未测；`ooc_report` 的「空来源泄露」与「canon 锚点年份超前」分支未测；`is_audit_turn` 未测负数；哑炮分支只断言 2 个子串 | 逐条比对代码分支 | 按 §8#8 模式批量补测（同型缺口会复制到 Task 10+） |
| 4 | Minor | `src/ui/panel_formatter.gd:43,121` | `Money` 负值显示「0加隆 -2西可 -16纳特」经 `player_panel`/`power_panel` 暴露到 UI。不崩溃，但 HANDOFF §8#5 的「未定义」形态自此可达 | `src/model/money.gd:36-42` `parts()` 返回 `[-0,-2,-16]` | 裁定债务显示格式（如「负债 X 加隆」）或在 Money 层定义 |
| 5 | Minor | `panel_formatter.gd:93,118`；`self_check.gd:48` | 类型化赋值/转换脆性：`var rel: Dictionary = p.relations[npc_id]`、`var family: Dictionary = flags.get("family", {})` 在值为 `null`/非 Dictionary 时运行期报错；`float(world_vars[key])` 在非数值时抛错。仅畸形/手改状态可触发，与 §8#9 同类 | 稀疏赋值路径 | 加 `typeof` 回退，或明确「状态只由 `to_dict()` 产出」 |
| 6 | Minor | `src/rules/self_check.gd:71-81` | 时间线详情 `timeline_detail` 在「年份早于锚点」与「canon 事实超前」同时成立时被后者覆盖，只报最后一条异常原因 | 代码顺序 | 用 Array 累积多条理由（不影响 yes/no 判定） |

## 对「姓名」唯一偏离的裁定

**结论：批准，是当前约束下唯一正确且最小的修正；无夹带。**

1. **确为计划内部矛盾（独立复核成立）**：计划 Step 1 `panel_test.gd` 断言 `panel.contains("张三")`（标签「姓名」），而计划 Step 4 `player_panel()` 的 9 行输出（时间/年龄/血统、身份/所在地/职业、财富/家庭、社会地位/魔法能力/战斗能力、魔药/技能、声望/重要关系/所属势力、当前目标）**没有任何字段引用 `name_text`**；其余数据源（registry label、location、job 等）均不含「张三」。逐字照抄必红（实现者报告的红色 `[panel] 姓名: 期望为真` 与我们的静态复核一致）。正典 `哈利·波特·魔法纪元.md:635-646` 第六十二章清单同样无姓名字段。故矛盾真实存在且起源于计划。
2. **最小性**：仅 `+1` 行、插在标题之后，未改动任何既有输出行，未改动任何断言（`tests/*` 与计划逐字 IDENTICAL），其余实现逐字照抄。可观察输出只新增 `【姓名】张三`。
3. **是否夹带**：否。该行直接服务唯一失败断言；`.uid` 补充由简报强制裁定；无额外重构、无调试输出（`grep TODO/print/push_error` 为空）。
4. **与正典一致性**：第六十二章是「面板格式清单」，并非封闭白名单；`status_line()`（计划原文）本就输出 `name_text`，姓名已在 UI 词汇表内，故新增姓名字段不构成对正典的实质违背。
5. **替代方案比较**：备选是删掉测试中的 `contains("张三")`（改测试迁就实现）。在「测试即契约、不得弱化断言」的既有约定下，删断言会降低覆盖面且仍偏离计划原文；新增字段是附加性的、不改语义，且实现者已按简报要求书面披露。因此本方案优于改测试。
6. **残留计划债（非本提交缺陷）**：计划 Step 4 与正典第六十二章仍未含姓名字段，建议 controller/人类在计划层补 `【姓名】` 字段（或明确删该断言），以免后续任务按不同版本再分叉。此项不计入 findings，仅登记。

## 未验证/存疑
- 未运行真实叙事长跑验证第七十二章「每 15 轮强制自检」在实战存档下的输出可读性；仅以 `gm_test`（第 15 回合两段标题）与单测覆盖。
- `ooc_violation` 预期由何层写入（GM 脚本？人工标注？未来 Task 10/11？）无源码证据，无法判定检查 #1 的最终有效性（见发现 #2）。
- `docs/sdd/plan-01-core-foundation/` 下耐久副本（台账/工件/HANDOFF）是否已同步本次工件，不在本审查只读范围内核验。
- 未对 `custom` 时代（`era_start_year` 由玩家指定，见 §8#12）下 `ooc_report` 时间线分支做端到端验证；仅静态确认 `era_start_year>0` 守卫存在。
