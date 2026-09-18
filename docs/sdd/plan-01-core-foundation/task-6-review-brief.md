# Task 6 审查简报（reviewer）

> 只读审查。可用工具：read、bash（仅只读命令 + `bash tools/test.sh`）。禁止修改文件、禁止 git 写操作。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。

## 审查对象

- 提交：`f3d8a31 feat(creation): 第七十五章启动界面到玩家档案的创建流水线`（父 `d4186c5`）；`git show f3d8a31`、`git diff d4186c5..f3d8a31`
- 计划规格：`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 6`（第 1896–2448 行，Step 1–6）
- 简报（含 controller 对计划的强制修正裁定）：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-6-brief.md`
- 实现者报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-6-report.md`
- 前情：`HANDOFF.md`、`docs/sdd/plan-01-core-foundation/task-5-review.md`（Task 5 的 `weight`/`rng_state` 等发现）

## 必须核对的点

1. **规格符合性**：`CharacterCreation` 的方法签名与计划 Interfaces 是否一致；`data/skills.json` 与四张魔杖表是否与计划一致；
   `registry.gd` 的 `TABLE_FILES` 是否只追加 5 张表；`creation_test.gd` 是否与计划 Step 1 一致。
2. **计划修正的正当性**：计划 `generate_wand` 首行原为 `var wood: Dictionary = rng.stream_pick(...)`，实现者按简报改为
   `var wood: String = str(rng.stream_pick(...))`。请独立核对：`stream_pick` 的返回类型、`Dictionary` 类型化赋值的后果、
   除这一行外计划文档与代码是否**没有**其它差异。
3. **校验覆盖（第七十五章 + 反漏洞）**，重点判断以下是否属缺陷及严重度：
   - `validate_choices` 校验了 era/bloodline/birth_identity/house/sim_style/political_leaning/name/age/personality/life_goal/aptitude/血统-资质自洽/special 的 aptitude_special/玩家自带魔杖的 wood/core/flexibility；
   - **未校验** `birthplace` 是否为合法 `locations` id（但它会被写进 `player.location_id`）；
   - **未校验**玩家自带魔杖的 `length_inches` 是否来自 `wand_lengths` 表（只校验 wood/core/flexibility）；
   - **`aptitude_special` 只在校验 `aptitude_id=="special"` 时才检查**，但 `create()` **无条件**把
     `p.flags[p.aptitude_special]=true`。请判断：`aptitude_id="normal"` + `aptitude_special="parselmouth"` 是否会让玩家
     在**不选特殊资质**的情况下白拿特殊天赋标记（反漏洞不变量），并给出严重度。
4. **`create()` 一致性**：`has_magic` / 哑炮分支 / 魔杖生成 / 随机资质池（排除 `random` 与 `squib`）/ 血统 default_flags /
   aptitude grants / `prejudice_level` 写入 `flags`（float 混入 bool 容器）/ `personality` 是否与 `choices` 共享引用。
5. **学院判定**：`assign_house` 的默认分、血统偏置、性格关键词匹配（`contains` 双向匹配是否过宽）、平票时用 RNG 的确定性。
6. **内容表**：`wand_cores` 的 `rarity` 字段是否被任何代码使用（类似 Task 5 的 `weight`）；`skills` 表 19 项是否覆盖所有
   `bloodlines`/`birth_identities` 的 `skill_bias`（跨表完整性）。
7. **测试强度**：指出空转/弱断言、未覆盖的负例（例如上面的 `aptitude_special` 漏洞、非法 `birthplace`、非法长度）。
8. **越界**：是否改动/新建了 Task 6 范围外的文件。

## 必须自己跑一次

`bash tools/test.sh`（单实例），确认 `[creation] 断言=141 失败=0`、`==== 总计失败=0，失败套件=0 ====`、
`ALL TESTS PASSED`、`全部通过。`、退出码 0。原始关键行写进记录。

## 输出格式（直接返回文本；controller 转存为 task-6-review.md）

```markdown
# Task 6 审查记录

审查者：<reviewer subagent>　模型：deepseek-flash　范围：d4186c5..f3d8a31

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
<wood 修正是否唯一正确、有无夹带>

## 未验证/存疑
```

严重度：Critical=数据损坏/崩溃/规格实质违背；Important=明确缺陷但影响可控或有绕行；Minor=风格/测试强度/文档。
