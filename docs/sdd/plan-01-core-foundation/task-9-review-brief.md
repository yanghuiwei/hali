# Task 9 审查简报（reviewer）

> 只读审查。可用工具：read、bash（仅只读命令 + `bash tools/test.sh`）。禁止修改文件、禁止 git 写操作。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。

## 审查对象

- 提交：`d9135ab feat(ui): 第六十二至六十五章面板与第七十二章强制自检`（父 `463a73d`）；
  `git show d9135ab`、`git diff 463a73d..d9135ab`；审查包：`docs/sdd/plan-01-core-foundation/review-463a73d..d9135ab.diff`
- 计划规格：`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 9`（第 3403–3879 行，Step 1–6）
- 简报（含 `.uid` 强制裁定）：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-9-brief.md`
- 实现者报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-9-report.md`
- 正典：`哈利·波特·魔法纪元.md` 第 635–710 行（第六十二章 / 第六十五章 / 第七十二章）
- 前情：`HANDOFF.md`（§8 第 7 条：`power_panel` 把法律执行/傲罗/威森加摩映射到同一批 `world_vars`，纯显示问题；
  §8 第 5 条：`Money` 负值显示未定义，Task 9 落地前面板会暴露该形态）

## 必须核对的点

1. **规格符合性**：`PanelFormatter` 的六个静态方法签名与计划 Interfaces 是否一致；`SelfCheck` 的
   `AUDIT_INTERVAL`/`is_audit_turn`/`snapshot`/`ooc_report`/`report` 是否与计划 Step 4 一致；
   `tests/panel_test.gd`、`tests/selfcheck_test.gd` 是否与计划 Step 1 一致（除下述已声明的姓名修正）；
   `tests/run_tests.gd` 是否只追加两条套件。
2. **唯一偏离的裁定（重点）**：实现者在 `player_panel()` 里新增了一行 `【姓名】%s`。理由：计划 Step 1 的
   `panel_test.gd` 断言 `panel.contains("张三")`，但计划 Step 4 的 `player_panel()` 不输出姓名，逐字照抄必红；
   正典第六十二章面板格式也不含姓名字段。请独立复核：
   - 这是否真的是计划内部（测试 vs 实现）矛盾？
   - 新增一行 `【姓名】` 是否**最小**、是否改变任何既有输出行或断言含义、是否引入夹带？
   - 与正典「第六十二章面板」格式不一致是否是问题（第六十二章是格式清单，并非禁止额外字段）？
   - 是否存在比新增字段更合理的替代（例如改测试断言）？如有，说明理由与影响。
3. **自检正确性**：`ooc_report` 的四项检查是否真的能抓到测试构造的异常（非法施法计数、年份早于 `era_start_year`、
   `known_facts` 来源为 `system`/空、NPC `ooc_violation`）；干净世界是否确实输出「通过」；
   `snapshot` 七项是否齐全；`report = snapshot + "\n" + ooc_report`。指出任何恒真/空转断言或漏检路径。
4. **与既有不变量的一致**：`SelfCheck.report` 被 `TurnEngine.submit` 在第 15 回合调用，`gm_test.gd` 断言
   audit 含两段标题——完整实现是否仍满足；`is_audit_turn` 语义（`turn>0` 且 `%15==0`）是否被改动。
5. **面板健壮性**：`power_panel` 对缺失 `world_vars` / `flags["family"]` 的默认值处理；`_label` 对未知/空 id 的回退；
   `money().formatted()` 在负值时的显示（HANDOFF §8#5 是否会在此暴露而不崩溃）；是否会因类型化赋值运行期报错。
6. **第六十五章节映射问题**：确认 `法律执行/傲罗/威森加摩` 是否仍映射到 `war_pressure/ministry_stability/corruption`
   同一批变量（HANDOFF §8#7 已登记为纯显示问题）——本轮是否新增了别的误映射。
7. **测试强度**：指出空转/弱断言、未覆盖的负例（例如哑炮分支只测两个子串、`events_block` 空数组未测、
   `_top_skill` 空技能未测、`_label` 未知 id 未测等），并按 Minor 记录。
8. **越界与卫生**：是否改动 Task 9 范围外文件；三条新脚本 `.gd.uid` 是否随提交入库；工作区提交后是否干净。

## 必须自己跑一次

`bash tools/test.sh`（单实例），确认 `[panel] 断言=65 失败=0`、`[selfcheck] 断言=26 失败=0`、`[gm] 断言=38 失败=0`、
`==== 总计失败=0，失败套件=0 ====`、`ALL TESTS PASSED`、`全部通过。`、退出码 0。原始关键行写进记录。

## 输出格式（直接返回文本；controller 转存为 task-9-review.md）

```markdown
# Task 9 审查记录

审查者：<reviewer subagent>　模型：deepseek-flash　范围：463a73d..d9135ab

## 结论
- 规格符合：✅ / ❌
- 裁定：**Approved** / **Approved with findings** / **Rejected**
- 关键数字：Critical=n，Important=n，Minor=n

## 证据
<diff 摘要、测试原始输出关键行、独立复核>

## 发现
| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|

## 对「姓名」唯一偏离的裁定
<是否唯一正确、是否最小、有无夹带、是否需改测试或计划>

## 未验证/存疑
```

严重度：Critical=数据损坏/崩溃/规格实质违背；Important=明确缺陷但影响可控或有绕行；Minor=风格/测试强度/文档。
