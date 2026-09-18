# Task 8 审查简报（reviewer）

> 只读审查。可用工具：read、bash（仅只读命令 + `bash tools/test.sh`）。禁止修改文件、禁止 git 写操作。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。

## 审查对象

- 提交：`432adc8 feat(gm): 叙事接口、状态操作、反刷成长与回合引擎`（父 `79d15aa`）；`git show 432adc8`、`git diff 79d15aa..432adc8`
- 计划规格：`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 8`（第 2886–3401 行，Step 1–8）
- 简报（含两处强制修正裁定）：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-8-brief.md`
- 实现者报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-8-report.md`
- 前情：`HANDOFF.md`（§8 第 3 条：ScriptedGameMaster 直接调 cast 的架构偏离仍待人类裁定；§8 第 27 条：per-turn 已裁定）、
  `docs/sdd/plan-01-core-foundation/task-7-review.md`

## 必须核对的点

1. **规格符合性**：`GameMaster`/`GmResult`、`ScriptedGameMaster`、`StateOps.apply` 的 op 集合、`Progression.gain`、
   `TurnEngine.submit`/`acknowledge_audit` 的签名与计划 Interfaces 是否一致；`gm_test.gd` 是否与计划 Step 1 一致（除两处强制修正）。
2. **两处强制修正的正当性**：
   - Progression 测试 `total := g1` 改为 `g1 + g2 + g3`（原写法按公式只得 5，注释期望 23 次总和 8）；
   - 未知行动文本去掉「发呆」（否则命中 `REST_KEYWORDS`）。
   请独立复核逐次推算与关键词判定，确认除这两处外计划与代码**没有**其它差异。
3. **架构契约（重点评估严重度）**：计划的 Interfaces 写明「GM 只描述发生了什么（叙事 + 状态增量），不直接改世界」，
   但 `ScriptedGameMaster.act` 会**直接** `SpellResolver.cast(world, ...)`（改 `world.flags`：能量/时间/非法施法计数）
   并经 `Progression.gain` 写 `world.flags["recent_training"]`。这是 HANDOFF §8 第 3 条的已知偏离（计划内已文档化）。
   请判断：是否有实际后果（重复结算、审计绕过、与 `StateOps` 的 `cast_spell` 双路径不一致）？应本轮修、还是按计划留待人类裁定？
4. **RNG 一致性（重点）**：`StateOps.cast_spell` 用 `world_gm_rng(world)`（= `RngService.new(game_seed + turn*15485863)`，**每次调用新建**），
   而 `ScriptedGameMaster` 用构造时注入的 `rng`，`TurnEngine` 又把自己 `rng.state_dict()` 写回 `world.rng_state`。请判断：
   - 同一回合内多次 `cast_spell` 是否会因 `world_gm_rng` 相同而掷出**同一个** `spell_roll`；
   - `world.rng_state` 是否**没有**覆盖 gm 的随机流 → Task 10 存档读档后叙事随机是否分叉；
   - 这是否与「存读档往返一致 / 同种子确定」的既有不变量冲突。
5. **StateOps 边界**：op 集合与计划 Interfaces 的差异（代码多了 `set_player_flag`、`set_magic_tier`，`relation_delta` 多了 `interest`）；
   非法输入（空 `set_flag` key、`add_money` 非整数、未知魔咒/地点/技能）是否都安全；`know_fact` 对 `source=="system"` 的拒绝是否正确。
6. **Progression 语义**：`WINDOW_TURNS` 的窗口是 `<=`（是否 off-by-one）；`recent_training` 的键与增长是否有状态膨胀；
   「只计算并记账、不修改技能」的契约是否被 `ScriptedGameMaster` 的调用方式破坏（同一收益是否会被应用两次）。
7. **TurnEngine 流程**：死亡/自检挂起时是否正确**不推进时间**；`submit` 是否统一经 `WorldState.tick()` 推进回合
   （Task 7 裁定的 per-turn 语义要求如此）；`deltas_applied` 与 `op_errors` 的语义是否会误导调用方；自检触发时机（turn 15）是否正确。
8. **测试强度**：指出空转/弱断言（例如 `cast_result.narration.contains("照明咒") or narration.length() > 0`、
   自检只查标题、`unknown.tags.has("idle")` 的构造、`op_errors` 内容未断言等），以及未覆盖的负例。
9. **越界**：是否改动/新建了 Task 8 范围外的文件（`self_check.gd` 是最小桩，属计划安排，不算越界）。

## 必须自己跑一次

`bash tools/test.sh`（单实例），确认 `[gm] 断言=38 失败=0`、`==== 总计失败=0，失败套件=0 ====`、
`ALL TESTS PASSED`、`全部通过。`、退出码 0。原始关键行写进记录。

## 输出格式（直接返回文本；controller 转存为 task-8-review.md）

```markdown
# Task 8 审查记录

审查者：<reviewer subagent>　模型：deepseek-flash　范围：79d15aa..432adc8

## 结论
- 规格符合：✅ / ❌
- 裁定：**Approved** / **Approved with findings** / **Rejected**
- 关键数字：Critical=n，Important=n，Minor=n

## 证据
<diff 摘要、测试原始输出关键行、独立复核>

## 发现
| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|

## 对两处强制修正的裁定
<是否唯一正确、有无夹带>

## 未验证/存疑
```

严重度：Critical=数据损坏/崩溃/规格实质违背；Important=明确缺陷但影响可控或有绕行；Minor=风格/测试强度/文档。
