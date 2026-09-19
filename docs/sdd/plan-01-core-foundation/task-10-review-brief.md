# Task 10 审查简报（reviewer）

> 只读审查。可用工具：read、bash（仅只读命令 + `bash tools/test.sh`）。禁止修改文件、禁止 git 写操作。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。

## 审查对象

- 提交：`dbd93d2 feat(persist): 第七十一章存档编解码与存槽`（父 `04b0ce7`）；
  `git show dbd93d2`、`git diff 04b0ce7..dbd93d2`；审查包：`docs/sdd/plan-01-core-foundation/review-04b0ce7..dbd93d2.diff`
- 计划规格：`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 10`（第 3881–4153 行，Step 1–6）
- 简报（含两条强制裁定：`.uid`、端到端块）：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-10-brief.md`
- 实现者报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-10-report.md`
- 正典：`哈利·波特·魔法纪元.md` 第七十一章（约第 704 行）
- 前情：`HANDOFF.md` §8（#9 / #17 / #19 / #20 / #26 / #34）、`docs/sdd/plan-01-core-foundation/task-9-review.md`

## 必须核对的点

1. **规格符合性**：`SaveCodec`（`HEADER`/`SAVE_VERSION`/`checksum`/`encode`/`decode` 返回 `{"ok","error","world"}`）
   与 `SaveStore`（`slot_path`/`save`/`load_slot`/`list_slots`/`delete_slot`）的签名与计划 Interfaces 是否一致；
   `tests/save_test.gd` 是否与计划 Step 1 一致（除简报裁定的两处修正）；`tests/run_tests.gd` 是否只追加一条套件。
2. **两处偏离的裁定（重点）**：
   - `JSON.stringify(world.to_dict(), "", true, true)` 开启 `full_precision`。请独立复核：默认精度是否真的会使
     `w3r.to_dict() == w3.to_dict()` 失败（可写临时脚本，审完删除）；开启后是否只影响数值精度、不改字段结构/键序/校验和逻辑；
    是否给 `game_seed`（int）或 `checksum` 带来副作用；是否属于「最小修正」。
   - 随机流对比块由 off-by-20 改为「先存 `expected_draws` 再对比」。请复核原写法是否必然失败（两个 RNG 同状态却比较不同下标），
     以及修正后断言文字/条数/容差是否保持不变。
   - 两处是否都已同步进计划原文，且**没有**其它未披露的偏离（逐字核验 `SaveCodec`/`SaveStore`/`save_test.gd` 其余部分）。
3. **`decode` 的失败契约**：计划声称「所有失败路径都返回 `ok=false` 且 `world=null`，绝不崩溃」。
   请逐条验证：内容过短 / 缺标题 / 版本不符（头部） / 缺校验和行 / 缺 `payload:` 标记 / 校验和不符 / 载荷非法 JSON /
   载荷版本不符。特别评估：**校验和正确但字段结构畸形的载荷**（例如手工构造 `"player": null`、
   `"clock": 123`、`"world_vars": []`）是否会让 `WorldState.from_dict` 运行期抛错 → 违反「绝不崩溃」
   （对应 HANDOFF §8#9 / #26）。若有，请给严重度与建议，并说明是否需要本轮修。
4. **`SaveStore` 路径与 IO**：`slot_path` 的路径净化（`/`、`\`、`:`、空串、`..` 是否会逃逸出 `base_dir`）；
   `make_dir_recursive_absolute` 对 `user://` 的行为；`list_slots` 只认 `.json` 且排序；`delete_slot` 缺失返回 false；
   `load_slot` 缺失槽返回 `ok=false` 且带 `world=null`。有无目录遍历/覆盖风险。
5. **端到端不变量的强度**：简报强制补充的 `submit → encode → decode → 重建 TurnEngine → submit` 对比，
   是否真的能抓住「叙事 RNG 未入档」这一 §8#34 缺陷（可做反证：临时删掉 `TurnEngine.submit` 里
   `world.rng_state = rng.state_dict()`，看该断言是否变红，再还原；若不方便，做静态论证）。
   `TurnEngine._init` 的 `rng.load_state(world.rng_state)` 是否覆盖 GM 持有的同一个 rng 对象。
6. **`full_precision` 与既有断言**：篡改测试 `text.replace('"game_seed":20260918', ...)` 在 `full_precision=true` 下是否仍命中；
   开放精度后存档体积/可读性是否可接受。
7. **测试强度**：指出空转/弱断言、未覆盖的负例（如 `checksum` 对空串、`decode` 对 `checksum:` 行但不是 hex、
   多行 payload、`slot` 名净化、`list_slots` 空目录、`save` 返回路径、`delete` 缺失槽等）。
8. **越界与卫生**：是否改动 Task 10 范围外文件（`WorldState`/`RngService` 序列化是否被改？按简报第 1 条不应改）；
   三个新 `.gd.uid` 是否入库；工作区提交后是否干净；诊断脚本是否残留。

## 必须自己跑一次

`bash tools/test.sh`（单实例），确认 `[save] 断言=47 失败=0`、`==== 总计失败=0，失败套件=0 ====`、
`ALL TESTS PASSED`、`全部通过。`、退出码 0。原始关键行写进记录。

## 输出格式（直接返回文本；controller 转存为 task-10-review.md）

```markdown
# Task 10 审查记录

审查者：<reviewer subagent>　模型：deepseek-flash　范围：04b0ce7..dbd93d2

## 结论
- 规格符合：✅ / ❌
- 裁定：**Approved** / **Approved with findings** / **Rejected**
- 关键数字：Critical=n，Important=n，Minor=n

## 证据
<diff 摘要、测试原始输出关键行、独立复核（含反证）>

## 发现
| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|

## 对两处偏离的裁定
<full_precision 与 off-by-20 修正：是否唯一正确、是否最小、有无夹带>

## 未验证/存疑
```

严重度：Critical=数据损坏/崩溃/规格实质违背；Important=明确缺陷但影响可控或有绕行；Minor=风格/测试强度/文档。
