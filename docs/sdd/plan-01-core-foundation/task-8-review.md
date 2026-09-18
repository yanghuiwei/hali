# Task 8 审查记录

审查者：reviewer subagent　模型：deepseek-flash　范围：79d15aa..432adc8

## 结论
- 规格符合：✅
- 裁定：**Approved with findings**
- 关键数字：Critical=0，Important=3，Minor=5

## 证据

**diff 摘要**（`git show --name-status 432adc8`，父 79d15aa，16 个文件，+424/-2）
```
M  docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md  (2+/-2，仅两行)
A  src/core/turn_engine.gd (+ .uid)        52+
A  src/gm/game_master.gd (+ .uid)          15+
A  src/gm/scripted_game_master.gd (+ .uid) 102+
A  src/rules/progression.gd (+ .uid)       27+
A  src/rules/self_check.gd (+ .uid)        10+
A  src/rules/state_ops.gd (+ .uid)         69+
A  tests/gm_test.gd (+ .uid)               139+
M  tests/run_tests.gd                      (1+，SUITES 在 spell_test 后追加 gm_test)
```
- 工作区干净（`git status --short` 空）；`*.gd.uid` 7 个全部随提交、全局唯一（`uniq -d` 无输出）。
- 无范围外文件；`self_check.gd` 是计划明写的任务 8 最小桩（HANDOFF §8#1），不算越界。
- `tests/run_tests.gd` 与计划 Step 2 的 sed 追加位置一致（`spell_test.gd` 之后）；`SUITES` 只加 1 行。

**逐字核对（关键方法：用 `git show 79d15aa:<plan>` 抽取*原始*计划代码块，规避本提交同时改了计划文档造成的假一致）**
```
BLOCK 1 vs tests/gm_test.gd       → 仅 2 行不同（即两处强制修正，见下）
BLOCK 2 vs src/rules/progression.gd          → IDENTICAL
BLOCK 3 vs src/rules/state_ops.gd            → IDENTICAL
BLOCK 4 vs src/gm/game_master.gd             → IDENTICAL
BLOCK 5 vs src/gm/scripted_game_master.gd    → IDENTICAL
BLOCK 6 vs src/core/turn_engine.gd           → IDENTICAL
BLOCK 7 vs src/rules/self_check.gd           → IDENTICAL
```
计划文档 `git diff 79d15aa..432adc8 -- ...md` 恰为 g1+g2+g3 与「发呆」两行，无其它改动。
签名核对（计划 Interfaces 2896–2912 ↔ 代码）：`GameMaster`/`GmResult` 四字段、`act` 基类返回「未接入」、`ScriptedGameMaster._init(rng)`、`StateOps.apply -> PackedStringArray`、`Progression.gain`、`TurnEngine._init/submit/acknowledge_audit` 与返回字典六键**全部一致**。

**独立复核 `bash tools/test.sh`（单实例，原始关键行）**
```
[gm] 断言=38 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```

**逐次推算复核（强制修正 1）**：`w3.clock.turn` 恒为 0（`make_world` 后从未 tick），窗口 `0-entry<=12` 永不淘汰，故
call1 repeats=0→4、call2 repeats=1→2、call3 repeats=2→int(4/3)=1、call4 repeats=3→1、call5 起 repeats≥4→int(4/5)=0；
23 次和 = 4+2+1+1 = 8。原 `total := g1` 再跑 20 次（call4..23）得 4+1=5 ≠ 8，必红；改 `g1+g2+g3` 得 7+1=8。**确认修正必要且唯一正确。**

**关键词判定复核（强制修正 2）**：「我对着墙发呆并思考宇宙的尽头」含 REST_KEYWORDS 的「发呆」，且检查顺序 cast→train→work→social→rest→idle 使其在 rest 分支返回，`tags.has("idle")` 必红。新文本「我对着墙思考宇宙的尽头」不含 TRAIN/WORK/SOCIAL/REST/CAST 任一关键词，也不含 32 个 spell label 任一（labels 为「照明咒…治疗咒」），落 idle。**确认修正必要且唯一正确。**

## 发现
| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|
| 1 | Important | src/rules/state_ops.gd:57-58,68 | `world_gm_rng` 每次调用都 `RngService.new(game_seed + turn*15485863)`；同一回合（turn 在 `tick()` 前不变）内**所有** `cast_spell` 掷出**同一个** `spell_roll`，失败时 `spell_side_effect` 也相同 → 重复施法与不同咒语结果完全相关 | `RngService.stream()` 用 `hash("%d\|%s" % [seed,name])` 派生流，同种子 RNG 序列确定；`TurnEngine.submit` 先 `gm.act`/`apply` 后 `world.tick()` | 由引擎持有并注入单个 RNG，或在派生种子里混入 op 序号/盐；属计划级缺陷（代码逐字照抄），本轮不修，登记给计划 02/Task 10 |
| 2 | Important | src/core/turn_engine.gd:46（+ gm_test.gd:137） | 存档写的是 `TurnEngine.rng` 的 `state_dict()`，而该 RNG **全文从未掷过任何随机数**；真正影响叙事的 `ScriptedGameMaster.rng`（work/social/spell_roll）**未入档**。计划 Task 11 读档用 `ScriptedGameMaster.new(RngService.new(world.game_seed + 1))` 重建 → 每次读档叙事随机流**从头再来**（同一「打工」收益恒定、社交掷骰重放），破坏「存档往返一致」不变量并可 save-scum | turn_engine.gd 无任何 `stream_*` 调用；state_ops 的 `world_gm_rng` 是纯派生（可复现）不构成补偿；HANDOFF §8#17 已把 `rng_state` 记为死字段 | 让 `TurnEngine` 持有唯一 RNG 并注入给 GM，再持久化它；或明确改述为「派生式确定性」并删除 `rng_state`。测试 `w8.rng_state.size() > 0` 对此**零覆盖**，Task 10 必须补 `submit→to_dict→JSON→from_dict→重建引擎→submit` 对比 |
| 3 | Important | src/gm/scripted_game_master.gd:57,66 | 架构契约：GM 直接改世界（`SpellResolver.cast` 写 energy_loop_count/time_rewind_count/illegal_cast_count/last_serious_mishap_turn，`Progression.gain` 写 recent_training），绕过 StateOps。后果：(a) 这些副作用**不出现在 `deltas_applied`**，与第七十二章「所有变更经 StateOps 便于审计」相悖；(b) 被守卫拦截的施法只有内部 `blocked`，既无 `op_errors` 也无状态痕迹，调用方无法区分「拒绝」与「正常」；(c) `last_cast_success/last_cast_narration` 只有 StateOps 路径会写，而生产路径永远是 GM 直调 → 这两个 flag 在真实玩法中恒为陈旧/未设；(d) 不会重复结算仅因当前 GM「自觉」不发 `cast_spell` delta，契约层面无强制 | 计划 Interfaces 2905「实现者只描述发生了什么…不直接改世界」；state_ops.gd:59-60；HANDOFF §8#3 | **本轮不修**：计划内已文档化，实现逐字照抄，修它会同时改计划 Step 5，按简报留待人类裁定；但请把 (b)(c)(d) 三条新后果补进 §8#3（原文只提到「直接改世界」），并在计划 02 决定「GM 只发 delta、StateOps 回传旁白」 |
| 4 | Minor | src/core/turn_engine.gd:40 | `deltas_applied` 实际是**请求的 delta**：被 StateOps 拒绝的 op（未知技能/魔咒/地点）也在其中，字段名误导调用方（Task 10/11 若据此做审计或存档会过报） | state_ops.gd 对未知 id 只 `errors.append` 不应用 | 改名 `deltas_requested`，或按 `op_errors` 过滤后再回填 |
| 5 | Minor | src/rules/state_ops.gd:28-56 | 输入硬化缺口：`set_flag`/`set_player_flag` 空 key 静默写入 `flags[""]`；`know_fact` 空 `fact_id` 静默写 `known_facts[""]`；`add_money` 非数值（字符串/缺失）静默变 0 且不报错；`relation_delta` 不校验 `npc_id` 是否在 registry、三个增量无上下限。均不崩、不越权写非法 id（未知技能/魔咒/地点都正确报错） | 逐行走查 + 现有测试未覆盖 | 空 key/空 fact_id/未知 npc 记 `errors`；`add_money` 非数值记错误；补负例测试。`know_fact` 对 `source=="system"` 的拒绝**正确**（第四十三章/第五十七章），但无测试 |
| 6 | Minor | src/rules/progression.gd:4,15,18 | 窗口 `turn - entry <= WINDOW_TURNS` 是闭区间，实际保留最近 **13** 个回合偏移（0..12），与「12 回合内」的读法差一；`gain==0` 也追加记录，同一回合（turn 不变）反复调用可无界累积；键从不 GC（换地点即新建键）。另注 `set_location` 免费，两地点轮换可把惩罚减半（反刷可绕行，属计划「换环境重新计算」语义的副作用） | 逐行走查；无边界测试 | 明确区间语义（改 `<` 或注释写明闭区间）并补 turn=12/13 边界断言；同一 (skill,key,turn) 去重；绕行问题列入人类/平衡批次 |
| 7 | Minor | tests/gm_test.gd:50,81,92,103,137 等 | 弱/空转断言与负例缺口（详见下） | 见下 | 见下 |
| 8 | Minor | 计划 2896-2912 ↔ 代码 | Interfaces 文档与 Step 代码不一致：少列 `set_player_flag`、`set_magic_tier`，`relation_delta` 少列 `interest`；`GmResult.audit_required` 无任何消费者，`tags` 也**未出现在 `submit` 返回字典**（调用方拿不到 cast/train 分类） | 与 HANDOFF #11 同类（文档级） | 同步 Interfaces 文本；决定 `tags` 是否要透出给 UI |

**发现 7 明细（测试强度）**
- `gm_test.gd:92` `narration.contains("照明咒") or narration.length() > 0` —— 右操作数恒真，断言**空转**，且未断言施法结局（成功/失败/拦截）。
- `gm_test.gd:81` `money_before` 声明后从未使用；打工只断言 `deltas.size() > 0`（op 被拒也成立），未断言 `money_knuts` 真的增加。
- `gm_test.gd:50` cast 循环只断言 `energy_loop_count <= 3`：结合发现 1，若同名 roll 恒定失败，计数为 0 也满足断言，守卫实际未被验证；应断言计数确实达到上限、且 `last_cast_narration` 出现「上限」。
- 自检只查两个标题字符串，未查内容，也未断言**第 14 回合 `audit` 必须为空**（缺负例）；`turn 30` 复触发无覆盖。
- `op_errors` 只断言 `size()==1/2`，**消息内容**从未断言（Task 11 UI 直接把它展示给玩家）。
- `gm_test.gd:103` `w5.clock.year >= before_year` 恒真（一个月推进不改年），空转；`gm_test.gd:137` 见发现 2。
- 未覆盖负例：`set_flag`/`set_player_flag`/`set_magic_tier`/`relation_delta`、`know_fact` 空 source 与 `source=="system"`、非字典 delta 条目、未知技能、`add_money` 非整数、**blocked 提交不推进回合**（死亡/自检挂起后 `clock.turn` 不变）、基类 `GameMaster.act`、GM 施法是否真的累加 `energy_loop_count`。

**流程正确性复核（简报第 7 点，均为通过）**
- 死亡（turn_engine.gd:25-28）与自检挂起（:32-35）都是提前 `return`，**不推进时间**、不产生事件。
- 回合推进统一经 `world.tick()`（无 `advance_month` 直调），满足 Task 7 裁定的 per-turn 语义（`energy_loop_count` 在 tick 内擦除；GM 施法在 tick 前，同回合内正确累计）。
- 自检时机正确：`turn % 15 == 0`，第 15 次提交后 `turn=15` 触发并把 `awaiting_audit_ack` 落进 `flags`（随存档持久化），下一次 `submit` 被拒，`acknowledge_audit()` 后恢复。

## 对两处强制修正的裁定
两处修正**均为唯一正确的选择，且无夹带**。
1. `total := g1` → `g1 + g2 + g3`：按公式同一地点 23 次总和本就是 4+2+1+1=8，原写法只得 5，属简报所述的测试与公式矛盾，改后与断言注释（及表驱动推算）自洽。计划原文已同步，diff 仅此一行。
2. 未知行动文本去「发呆」：`REST_KEYWORDS` 含「发呆」且 rest 分支先于 idle，原文本必得 `rest` 标签；改后文本经逐一关键词/魔咒 label 比对确认落 idle。`REST_KEYWORDS` 本身未改，计划原文已同步，diff 仅此一行。
3. 独立复核方式：以 `git show 79d15aa:<plan>` 抽取**原始**计划 7 个代码块逐字 diff，除上述两行外**全部 IDENTICAL**（0 处夹带）；计划文档 diff 亦恰为这两行。

## 未验证/存疑
- 发现 1（同回合同掷骰）与发现 2（读档叙事分叉）是**分析性论证**：本审查禁止写文件，Godot 无内联求值入口，无法落一个运行时探针。建议实现侧用一条测试固化：同回合连续两次 `cast_spell` 断言 `last_cast_narration` 序列不同；以及 `submit → to_dict → JSON → from_dict → 重建引擎 → submit` 的叙事/收益一致性对比（与 HANDOFF #20 合并做）。
- 计划 Step 2 的「预期红」未独立复跑（需临时改 `SUITES`，属写操作），仅采信报告中的红输出；本轮只复跑了 Step 7 的绿。
- `w2` cast 循环的真实成功/失败序列未探针确认（依赖 tier5 的失败率与 aptitude），因此「守卫在本测试中真的被触发」仍属未验证。
- `SelfCheck` 是计划明写的最小桩（HANDOFF §8#1），第七十二章自检的实质正确性无法在 Task 8 判定，留待 Task 9。
- 实现者报告的「遇到的问题 / 偏离：无」在「除两处强制修正外逐字照抄」这一范围内**与实测一致**，但未主动登记上述计划级 RNG/架构风险（已由本审查记录补上）。
