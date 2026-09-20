# Task 9 审查记录 · 8bc42e9..a36faab

> 审查者：只读 `reviewer`（deepseek-flash，run 41dbd54b）｜审查包：`review-8bc42e9..a36faab.diff`（4 commits，其中 3 个是控制器 docs；**只审代码提交 `a36faab` 的 3 文件**）
> 结论：**Spec ✅ 符合；Task quality = Approved**；Critical 0 / **Important 0** / Minor 8 → **无修复轮**
> 控制器核对：`task-9-test-verify.log`（`EXIT=0`、`[gm] 102`、`[registry] 244`、`SCRIPT ERROR` 2 = 基线）；`black_market.aliases` 实测现为 `["翻倒巷黑市","黑市"]`；B1 探针 82/0（上一轮已跑）。

## Spec Compliance（6/6）

1. 四组关键词逐字一致（`scripted_game_master.gd:12-15`），`FACTION_JOIN` = `["加入","投靠","效力","做事","入伙"]`（死关键词已按 `e4c3e59` 修正，且加了注释说明理由）。
2. `_detect_faction()` 只扫 `visible_faction_ids()`（源头 `registry.ids()` → `revealed==true`），比 label 与 aliases，命中返回 id 否则 `""`（`:51-60`）。
3. 分支位置正确（施法 `:71-83` 之后、`TRAIN` `:112` 之前）；四分支各自 `append` 后 `return`；`faction_id` 空或四关键词全不中时**不 return**；旁白取 `registry.entry("factions", id).get("label")`（零硬编码）。
4. 四条点名风险各有可失败断言（`gm_test.gd:279-296` 普通动作 ×10、`:273-277` tie-break、`:266-270` 未揭示 ×4、`:257-263` 泛称「部长」、`:298-307` 黑市别名回归 ×7）。
5. `data/factions.json:211` **只删那一个别名**（diff 内仅 ±1 行，未动别的字段/派系）。
6. 既有 71 条 `[gm]` 断言**零改动**（单 hunk、95 插入 / **0 删除**）；新增计数 31 与 `71→102` 自洽。

## 五条点名风险的结论（审查者逐条自查）

1. **分支顺序 / 不吞普通动作** ✅（`:88` 的 `if` 包住全部四分支，无任何提前 return）。
2. **tie-break 确定** ✅：`registry.gd:66-71` 的 `ids()` 显式 `out.sort()` → 返回 id 字典序首个命中者；审查者按 17 条内容反推确认 `"我支持魔法部和古灵阁"` 的唯一先命中者是 `gringotts`（label「古灵阁」直接命中），`contains` 无顺序歧义。
3. **未揭示** ✅ 且是**双门**：脚本侧只扫 visible（`:52`）+ op 侧 `state_ops.gd:83-84` 也校验 `visible_faction_ids().has()`。
4. **别名歧义** ✅（「部长」→ ministry 是有意；「那个人」在未揭示时不命中）。
5. **降级路径 / tags 语义无回归** ✅：新增 `tags.append("faction")` 只在四分支内；`确认自检` 在 `main.gd:263-268` 被 UI 短路、根本不进 `ScriptedGameMaster`；`save_test`/`llm_test` 用的输入文本不含任何派系 label/alias。

## Strengths（节选）

- 硬条件全中：只扫 visible 集；`return` 语义精确（命中派系**且**命中关键词才 return；四个分支的 `tags/deltas/narration` 全在分支内写，落空时 `r` **零改动** → 与 `idle` 语义天然一致，不存在"先 append 后落空"的脏状态）。
- 数据改动最小且有回归护栏（删别名同时配 7 条断言）。
- 测试钉的是**行为**：`_detect_faction` 内部返回值断言与 `act()` 端到端断言（`StateOps.apply` 后 `player.faction_id`）成对出现。
- 报告诚实：红步"套件中止"主动写明；登记了同句多派系只处理一个、从句语义、朴素子串匹配等残余。

## Issues

### Critical / Important
无。审查者按"测试无判别力属 Important"校准，判定新增断言均有判别力，并从代码侧推出 D-B/D-C/D-D 三组破坏的确切变红路径。

### Minor（8，全部登记 + 归属）

| # | 内容 | 控制器裁定/归属 |
| --- | --- | --- |
| **M1** | `scripted_game_master.gd:58` 的 `(entry.get("aliases", []) as Array)`：内容畸形时 `as Array` 得 `null` → `for ... in null` 运行期错误**中止整个 gm 套件**（Task 4 审查 M4 一族）。启动期 `validate_content` 会报、CI 会红，但 `main.gd:30-34` 只 `push_warning` 不阻断启动 ⇒ 运行期无第二道门 | **并入 Task 10**（2 行守卫） |
| **M2** | `faction` tag 不在 LLM 白名单（`gm_response_parser.gd:5`、`prompt_builder.gd:34` 的 6 词表）⇒ 同一 `GameMaster` 契约出现两套标签词汇（plan-mandated） | **并入 Task 10**：把 `faction` 加进白名单 + 提示词白名单行（各 1 行） |
| **M3** | `leave_faction` 不带目标派系（`scripted_game_master.gd:92` + `state_ops.gd:90-91` 无条件清空）⇒ 复现：「已是 ministry 成员时输入『我要退出古灵阁』」→ 旁白说古灵阁、实际清掉 ministry（plan-mandated） | **并入 Task 10**：`{"op":"leave_faction","faction_id":faction_id}`（StateOps 忽略未知键、向前兼容）或仅在 `player.faction_id == faction_id` 时产出该 op |
| **M4** | 「命中派系但四关键词都不中」的回退路径**只有代码级证据、无断言**（5 个普通动作案例都不含派系名） | **并入 Task 11**：补 `"我去魔法部打听消息"` → `tags.has("social")` 且派系 op 计数 0 |
| **M5** | 旁白 label 断言无法区分「查内容表」与「硬编码」（`gm_test.gd:229`） | **并入 Task 11**：用 label 被改名的临时 registry 跑一次 `act()` 证明不硬编码 |
| **M6** | 报告 §⑧ D-A 的「10 条全红」是**过度声明**（注入点在施法分支之后 ⇒ cast 那 2 条应仍绿、5 条"不产出派系 op"也仍绿 ⇒ 实际约 4 条红）。方向成立、反作弊结论不受影响 | 控制器登记更正（不改代码、不返工报告） |
| **M7** | 红步是「套件中止」而非干净失败（因同一提交新增 9 处对**尚不存在**的 `_detect_faction` 的调用）→ 判定**可接受但要登记**：判别力证据由 D-B/D-C/D-D 承担；建议后续任务把「测新 API」的调用与实现分开，保留一次干净失败 | 登记为流程注记（Task 13 写入 HANDOFF §4 踩坑） |
| **M8** | `state_ops.gd:92-102` 的 `faction_standing_delta` **没有 revealed 校验**（`join_faction` 有）；本 diff 不可能触发（识别层已限定 visible），但 LLM/OpGuard 路径对该 op 仍只有提示词层保护 | **并入 Task 11**：给该 op 补 revealed 校验 + 断言 |
