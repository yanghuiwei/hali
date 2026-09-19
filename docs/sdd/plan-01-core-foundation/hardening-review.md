# 计划 01 收尾加固批次 审查记录

审查者：独立审查者（reviewer subagent，只读）　模型：deepseek-flash　范围：e72e54d..e094a52

## 结论
- 行为正确性：✅（4 个 op 的硬化均只在非法输入时报错、不写入；合法输入与改前一致，旧断言全绿）
- 测试可判别性：✅（反证如下；但存在 1 处 Important 假绿缺口与 1 处 Minor 空转残留）
- 运行器哨兵：✅（`report_calls` 跨套件共享有效；中止性错误被计为失败。非中止错误不触发，属其声明的窄契约范围，见 Finding 2）
- 裁定：**Approved with findings**
- 关键数字：Critical=0，Important=1，Minor=4

## 证据

**A. 基线/收尾全绿（自跑 `bash tools/test.sh`，临时改动全部还原后）**
```
[money]18  [magic_level]41  [gm]56  [panel]71  [selfcheck]32  [save]96  各失败=0
... 13 套件全部 失败=0；==== 总计失败=0，失败套件=0 ====；ALL TESTS PASSED
== 3/3 主场景冒烟 ==  main scene ready, godot=4.7.2-stable (official)
全部通过。   EXIT=0
```
断言数与简报要求逐项吻合（money 18 / magic_level 41 / gm 56 / panel 71 / selfcheck 32 / save 96）。

**B. 行为正确性（静态 + 旧断言佐证）**
- `add_money` 用 `typeof in {TYPE_INT,TYPE_FLOAT}` 守卫并在 `else` 写入（`state_ops.gd:13-19`）；`set_flag`(31-36)/`set_player_flag`(37-42)/`relation_delta`(62-72) 均 `if/else`；`know_fact`(43-54) 为 `elif` 链，仅最终 `else` 写入。非法路径无任何赋值。
- 唯一生产者 `ScriptedGameMaster` 传 int（`scripted_game_master.gd:81` `income := 30 + int(...)*2 + int(...)`），`know_fact` 传非空 `fact_id`/来源（`:89`），无回归；`gm_test` 第 13 行「加钱生效」及打工加钱断言仍绿。

**C. 测试可判别性（逐条反证，均为临时改动后已还原）**
| 反证 | 结果 |
|---|---|
| `state_ops.gd` 删 `set_flag` 空 key 守卫（`if flag_key.is_empty():`→`if false:`） | `[gm] 期望<5>实际<4>` + `空 flag key 未写入`，gm 失败=2；总计失败=2；EXIT=1 → **可判别** |
| `magic_level.gd` clamp 常量 `0.95`→`0.90` | `[magic_level]` 失败=1（`高失败率被钳到 0.95`）+ `[spell]` 失败=1（六项满值上界）；EXIT=1 → **可判别** |
| `money.gd` 负值分段符号改为 `[-g, s, k]` | `[money]` 失败=3（分段/格式/往返）；EXIT=1 → 负值断言是精确 `eq`，**未被容差掩盖** |
| 运行器哨兵：`gm_test.run()` 注入真中止错误 `var arr: Array=[]; var v=arr[0]` | `套件未正常结束（未调用 report，运行期错误？）: res://tests/gm_test.gd`；总计失败=1、失败套件=1；EXIT=1 → **哨兵有效** |
| `tools/test.sh` 临时删除 `main scene ready` 标记 | 单测=0、冒烟=1、EXIT=1，且 `/tmp/tmp.*` 无泄漏 → grep 兜底有效 |
| `GODOT=/tmp/fakegodot.sh`（冒烟打印标记但 exit 7） | `冒烟=7`、EXIT=1 → `PIPESTATUS[0]` 在 `set -uo pipefail` 下取值正确 |
| **反证失败（假绿）**：`set_player_flag` 改为「报错且仍写入」 | `[gm] 56 失败=0`，EXIT=0 → 见 Finding 1 |

**D. 哨兵机制细节**
- `TestAssert.report_calls` 为 `static var`（`tests/assert.gd:5`），实测跨套件共享（若非共享则 13 套件会全部被判 null，基线未出现）。
- 13 个套件均在成功路径 `return a.report(...)`（`harness_test` 调 report 两次，仍 >0）。
- 注意：`var boom: int = "x"`（简报建议写法）被**既有** `script.can_instantiate()` 路径拦下（打印「套件无法实例化」），并非新哨兵；用 `arr[0]` 越界才能走到新哨兵分支。

**E. `main.gd`**
- `command_edit` 在 `_build_ui()`（`_ready` 内）创建，按钮回调只可能在之后触发，`grab_focus` 无 null 风险；与 `_on_start_pressed:195` 语义一致（`play_box.visible=true` 后聚焦）。
- `grep _turn_count` 全仓 0 命中；diff 仅删除声明与 `+=1`，无遗漏引用。

**F. 越界/夹带**
- `git diff --name-only e72e54d..e094a52` = **恰好 11 个文件**，无 `src/model/`、`src/core/turn_engine.gd`、`src/persist/`、`project.godot`、`README.md`、docs/。
- 审查包 `review-e72e54d..e094a52.diff` 的 `== diff ==` 段与 `git diff` 逐字节一致；统计 11 文件。
- 全部临时改动已还原，`git status --short` 仅剩预存在的未跟踪审查包。

## 发现
| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|---|---|---|---|---|
| 1 | Important | tests/gm_test.gd:55-64；src/rules/state_ops.gd:13-19,37-42,62-72 | 「非法输入不写入状态」只被证明了一半：仅 `set_flag`（`:63` 断言 `flags.has("")==false`）与 `know_fact`（r2/r3）有「未写入」断言；`set_player_flag`/`add_money`/`relation_delta` 只断言错误计数，未断言状态未变。反证：把 `set_player_flag` 改成「append 错误但仍 `flags[key]=value`」，错误数仍 5，gm_test **56/0 全绿、EXIT=0**，回归可静默通过。§8#37 明确要求「报错且不写入」。 | 反证 F（见证据 C 最后一行） | 补 3 条：`is_false(w.player.flags.has(""))`、非法 `add_money` 后 `money_knuts` 不变、`relation_delta` 空 npc_id 后 `relations.has("")==false`（与 `set_flag` 对称）。 |
| 2 | Minor | tests/magic_level_test.gd:30-31 | `for i in LABELS.size(): eq(index_of_label(LABELS[i]), i)` 对「标签文本」是自反式空转：它只能查重复项，查不出某档文本写错或调换。`label_of` 文本仅在 SQUIB/PRE_SCHOOL/MYTH 有精确断言，`index_of_label("N.E.W.T水平")` 仅钉住 NEWT，即 **10 档只钉住 4 档**（FIRST_YEAR/OWL/ADULT/EXPERT/MASTER/LEGEND 的文本无判别力）。§8#8 的「LABELS 只断言 3/10」未真正关闭。 | 静态：`grep 'label_of\|LABELS\['` 仅上述 4 处；其余 6 个文本串在 tests/ 无 `label_of` 断言 | 对 10 档逐条 `eq(label_of(i), "<期望文本>")`（或 table-driven），替代/补充 round-trip 循环。 |
| 3 | Minor | tests/run_tests.gd:58-67 | 哨兵只覆盖**中止性**运行期错误。反证：动态格式串 `var f := "%r"; print(f % "x")` 产生非中止运行期错误，`[gm] 失败=0`、`总计失败=0`、**EXIT=0**，同时 stderr 有 `ERROR: String formatting error`。即整体测试入口仍无法把该类错误判失败。（这是哨兵「未调用 report」窄契约之外的固有边界，非本次引入；基线中 save_test 的负例本就会打印 `SCRIPT ERROR`，所以不能简单 grep stderr。） | 反证 D | 可选后续：run_tests 统计「每套件 checks 数」或显式期望值；或对 stderr 做白名单式扫描（排除 save_test 已知负例），否则在注释中明确该边界。 |
| 4 | Minor | tools/test.sh:25-33 | `mktemp` 后无 `trap ... EXIT`；若脚本在冒烟期间被 Ctrl-C/中断，`$smoke_log` 会残留在临时目录（正常路径 `rm -f` 已验证无泄漏）。 | 代码静态 + 正常路径实测 `ls /tmp/tmp.*` 为 0 | 加 `trap 'rm -f "$smoke_log"' EXIT`，或改用 `mktemp`-with-trap 惯用法。 |
| 5 | Minor | tests/save_test.gd:113；§8#40/#43 残余 | (a) 断言名「非十六进制校验和被拒」实为普通校验和不匹配（`checksum:` 后加 `zz`，字符串比对失败），实现并无 hex 解析，命名夸大覆盖面；(b) §8#40 的「第 14 回合 `audit` 为空」与 §8#43 的「哑炮分支仅 2 子串」本次未补；§8#37 的「`relation_delta` 增量无上下限」仍未处理（本次按简报只加了空 npc_id）。 | diff 对照 HANDOFF §8#37/#40/#43 | 改名为「校验和不匹配被拒」；残余项按需并入下批或在 HANDOFF 标注为未关闭。 |

## 未验证/存疑
- **人工 GUI 验收（§8#55）**：`grab_focus` 的实际焦点效果、创建/读档/自检挂起流程的可见行为，headless 无法验证；本次只做静态论证（`command_edit` 必存在、调用时机与既有语义一致）+ 场景可加载冒烟。留待人类按计划 Step 6 实跑。
- **`panel_test` 的 `player_panel(w_empty).contains("未知")`**：空玩家的 `_top_skill` 也会返回「未知」，该断言对「政治倾向回退」不是唯一判别（可能为弱断言），但结论方向正确，未单独列 Finding。
- Brief 中「控制器实测 `var boom: int = "x"` → 总计失败=1、EXIT=1」：我复现到相同数字，但走的是 `can_instantiate()` 预检路径而非新哨兵；新哨兵本身另用 `arr[0]` 越界证明有效。此为验证方法学澄清，非代码缺陷。
- 未在本次修改任何被测源码/测试/脚本；全部反证改动已还原（`git diff` 为空，`git status` 仅剩预存在的审查包未跟踪文件），临时脚本与备份已删除。
