# Task 7 审查简报（reviewer）

> 只读审查。可用工具：read、bash（仅只读命令 + `bash tools/test.sh`）。禁止修改文件、禁止 git 写操作。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。

## 审查对象

- 提交：`f323b55 feat(spell): 魔咒解析器与第五十五条反漏洞守卫`（父 `9899229`）；`git show f323b55`、`git diff 9899229..f323b55`
- 计划规格：`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 7`（第 2481–2857 行，Step 1–6）
- 简报（含 controller 对计划的强制修正裁定）：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-7-brief.md`
- 实现者报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-7-report.md`
- 前情：`HANDOFF.md`、`docs/sdd/plan-01-core-foundation/task-6-review.md`

## 必须核对的点

1. **规格符合性**：`SpellResolver` 的 `GUARDS`/`Outcome`/`cast`/`modifiers_from` 签名与计划 Interfaces 是否一致；
   `data/spells.json`（32 条）是否与计划 Step 3 逐字一致；`registry.gd` 只追加 `spells`；`spell_test.gd` 与计划 Step 1 一致。
2. **计划修正的正当性**：计划原拦截文案 `"复制咒无法复制%s级资源…" % target_rarity` 在 `target_rarity="rare"` 时不含「稀有」，
   与测试 `blocked_reason.contains("稀有")` 冲突。实现者改为 `"复制咒无法复制稀有资源（%s）：…"`，计划原文同步。
   请独立核对：除这一行外计划与代码是否**没有**其它差异。
3. **守卫语义与反漏洞**，重点判断以下是否属缺陷及严重度：
   - `RARE_RARITIES = ["rare","legendary","史诗","传奇","神话"]` —— 若调用方传中文 **`"稀有"`**，是否**不被拦截**（绕过反复制守卫）？
     `data/wand_cores.json` 的 `rarity` 用的是 `"common"/"rare"`，而 `data/` 其它字段用中文；这个稀有度词表是否自洽？
   - `forbidden_lifetime` 无条件拦截（`horcrux` 需要 MYTH 才走到守卫，否则先被等级拦截）——是否符合「魂器永远禁止」的意图？
   - `unforgivable` / `restricted_mind_magic` 只置 `legal_risk` 不拦截——是否符合第二十五章「可被使用但留法律风险」？
   - `no_time_rewind` / `no_unlimited_energy` 的计数只在**成功**时自增、且永不衰减/重置：是否存在可利用的绕过或状态膨胀？
   - `illegal_cast_count` 是否只在成功时自增（失败时非法施法的记录缺失是否可接受）？
   - 被拦截的 `Outcome`：`failure_rate=1.0`、`roll=1.0`、`success=false` 是否合理、会不会误导调用方（Task 8）。
4. **失败率构成**：等级区间（`MagicLevel.effective_rate`）+ 环境因素 + `aptitude.failure_delta` + `spell.difficulty`，clamp 到 `[0.005,0.95]`；
   测试期望「熟练成年 + lumos(difficulty 0) → 0.02–0.05」「六项满值 → 0.92–0.95」是否与实现自洽；`difficulty` 是否可能把结果推到不合理区间。
5. **确定性**：同种子同条件结果一致；被拦截路径是否消耗 RNG（会不会让后续随机序列分叉）；`stream_pick` 对副作用的选择是否稳定。
6. **测试强度**：指出空转/弱断言、未覆盖的负例（例如中文 `"稀有"` 绕过、非法施法失败不计次、`portkey` 无批准被拦截、`legilimens`/`confundo` 的 `legal_risk` 等）。
7. **越界**：是否改动/新建了 Task 7 范围外的文件。

## 必须自己跑一次

`bash tools/test.sh`（单实例），确认 `[spell] 断言=212 失败=0`、`==== 总计失败=0，失败套件=0 ====`、
`ALL TESTS PASSED`、`全部通过。`、退出码 0。原始关键行写进记录。

## 输出格式（直接返回文本；controller 转存为 task-7-review.md）

```markdown
# Task 7 审查记录

审查者：<reviewer subagent>　模型：deepseek-flash　范围：9899229..f323b55

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
<「稀有」文案修正是否唯一正确、有无夹带>

## 未验证/存疑
```

严重度：Critical=数据损坏/崩溃/规格实质违背；Important=明确缺陷但影响可控或有绕行；Minor=风格/测试强度/文档。
