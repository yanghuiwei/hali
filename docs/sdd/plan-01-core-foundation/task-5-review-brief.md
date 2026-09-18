# Task 5 审查简报（reviewer）

> 只读审查。可用工具：read、bash（仅只读命令 + `bash tools/test.sh`）。禁止修改文件、禁止 git 写操作。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。

## 审查对象

- 提交：`23e67cd feat(world): 确定性随机与月度世界演化`（父 `dcf25e1`）；查看 `git show 23e67cd`、`git diff dcf25e1..23e67cd`
- 计划规格：`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 5`（第 1434–1857 行，Step 1–7）
- 简报（含 controller 对计划的正典/契约修正裁定）：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-5-brief.md`
- 实现者报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-5-report.md`
- 前情：`HANDOFF.md`（第 4 节坑、第 8 节待裁定）、Task 4 审查记录 `docs/sdd/plan-01-core-foundation/task-4-review.md`

## 必须核对的点

1. **规格符合性**：`RngService` 的方法签名、`WorldState.tick()` 与计划 Step 3/6 代码是否逐字一致（除下述修正）；
   `data/locations.json` / `data/rumors.json` 是否与计划一致；`registry.gd` 的 `TABLE_FILES` 是否正确追加。
2. **计划修正的正当性**：计划 `data/rumors.json` 无 `label`，而 `Registry.validate()` 要求每条目有非空 `label`，
   `tests/registry_test.gd` 断言缺 label 必错。实现者为 16 条 rumor 补了短中文 `label` 并同步计划原文。
   请独立核对：(a) `validate()` 的实现是否真的强制 label；(b) 16 条 label 是否齐备且无重复 id；(c) 除加 label 外数据有无夹带改动。
3. **RNG 正确性**：
   - 同 seed 同命名流可复现；不同命名流互不干扰；`hash("%d|%s")` 是否有跨流/跨 seed 碰撞隐患。
   - `state_dict()` / `load_state()` 是否真的能续跑一致（设置 `seed` 后再设 `state` 的顺序是否正确；`state` 是否随 `randi_range` 推进）。
   - `chance(p=0)` 是否必假、`chance(p=1)` 是否必真；`stream_pick([])` 返回 null。
4. **`tick()` 逻辑**：
   - `world_vars` 是否始终 clamp 到 `[0,1]`；向基线回归是否可能在多次 tick 后发散/NaN。
   - `major` 事件双闸门（`MAJOR_EVENT_GAP` + `major_gate`）是否真的满足「重大事件至少相隔 12 个月」——
     注意 `major_ready` 在循环外只算一次、同月最多可能抽 2 条，若同一月抽中两条 major 会发生什么？
   - `requires_flags` 过滤是否真的能阻止低身份获知「魔法部内幕」类信息；`zones` 过滤是否正确。
   - `weight` 字段在数据与 Interfaces 中都存在，但 `tick()` 是否使用了它？（若未使用，属规格缺口还是可接受？）
   - `WorldState.rng_state` 字段是否有任何地方写入/读取？若为死字段，是否有隐患。
   - 日志裁剪 `RECENT_LOG_LIMIT` 是否只裁 `log` 而不裁 `history`，是否符合意图。
   - `player.age_months += 1` 与 `clock.advance_month()` 是否重复/错配。
5. **确定性**：`tick()` 依赖 `registry.ids("rumors")`（已排序）与 `world_vars.keys()` 的迭代顺序；
   后者在 create 与 from_dict 两条路径下是否一致（否则同 seed 存档往返后演化可能不同）。
6. **测试强度**：指出空转或近似空转的断言。已知需重点判断的两处：
   - `major_count <= 20`：w2 复用了 location=`london_muggle` 的 `p`，该地只有非 major 的 `daily_life`，是否意味着该断言恒真？
   - 信息保护：w3 用 `PlayerState.new_default()`（location 为空），是否导致所有 rumor 都被 zones 过滤、断言恒真？
   - `var rng := RngService.new(w.game_seed)` 是否为未使用变量。
7. **越界**：是否改动/新建了 Task 5 范围外的文件。

## 必须自己跑一次

仓库根运行 `bash tools/test.sh`（单实例），确认 `[clock] 断言=28 失败=0`、`[world_tick] 断言=101 失败=0`、
`==== 总计失败=0，失败套件=0 ====`、`ALL TESTS PASSED`、`全部通过。`、退出码 0。原始输出关键行写进记录。

## 输出格式（直接返回文本；controller 转存为 task-5-review.md）

```markdown
# Task 5 审查记录

审查者：<reviewer subagent>　模型：deepseek-flash　范围：dcf25e1..23e67cd

## 结论
- 规格符合：✅ / ❌
- 裁定：**Approved** / **Approved with findings** / **Rejected**
- 关键数字：Critical=n，Important=n，Minor=n

## 证据
<diff 摘要、测试原始输出关键行、独立复核>

## 发现
| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|

## 对计划修正的裁定
<label 修正是否唯一正确、有无夹带>

## 未验证/存疑
```

严重度：Critical=数据损坏/崩溃/规格实质违背；Important=明确缺陷但影响可控或有绕行；Minor=风格/测试强度/文档。
