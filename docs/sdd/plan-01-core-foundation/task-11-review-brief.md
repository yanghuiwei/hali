# Task 11 审查简报（reviewer）

> 只读审查。可用工具：read、bash（仅只读命令 + `bash tools/test.sh` + `./Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit-after 5`）。
> 禁止修改文件、禁止 git 写操作。仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。

## 审查对象

- 提交：`70ad341 feat(ui): 主界面、创建流程与运行说明`（父 `16ba34b`）；
  `git show 70ad341`、`git diff 16ba34b..70ad341`；审查包：`docs/sdd/plan-01-core-foundation/review-16ba34b..70ad341.diff`
- 计划规格：`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 11`（约第 4193–4640 行，Step 1–8）
- 简报（含 4 条强制裁定）：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-11-brief.md`
- 实现者报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-11-report.md`
- 前情：`HANDOFF.md` §8#34（叙事 RNG 必须入档）、Task 10 的 `task-10-review.md` / `task-10-rereview2.md`

## 必须核对的点

1. **路径统一（强制裁定 1）**：`src/ui/main.tscn` + `src/ui/main.gd` 是否存在；
   `project.godot` 是否为 `run/main_scene="res://src/ui/main.tscn"`；`tools/test.sh` 冒烟检查是否为 `$ROOT/src/ui/main.tscn`；
   全仓（`README.md`、计划、源码）是否还有会导致「冒烟永远跳过 / 主场景指向不存在场景」的残留 `ui/main.tscn` 写法。
2. **共享 RNG（强制裁定 2，重点）**：`src/ui/main.gd` 的 `_on_start_pressed` 与 `_on_load` 是否都写成
   `TurnEngine.new(world, ScriptedGameMaster.new(rng), rng)`（同一 `rng` 实例，GM 与引擎共享）。
   静态论证：若两者不共享，读档后叙事随机流是否正确；说明为什么共享能保 §8#34（对照组：Task 10 的 `tests/save_test.gd` 端到端块）。
3. **主界面逻辑正确性（重点）**：对照 `CharacterCreation.create`（`Result.player/errors`）、`WorldState.create`、
   `TurnEngine.new/submit/acknowledge_audit`、`ScriptedGameMaster`、`PanelFormatter`、`SelfCheck`、`SaveCodec`/`SaveStore`
   的真实签名，检查 `src/ui/main.gd` 有无 API 误用/类型错误/空引用：
   - `_selected()` 读取 OptionButton metadata；`registry.ids/entry` 的返回类型；
   - `_on_start_pressed` 的 `choices` 键是否满足 `validate_choices`（尤其 `birthplace`、`personality`、`age_years`）；
   - 创建失败时错误写到 `log_view` 但 `play_box` 可能仍隐藏（错误不可见）——是否为真实缺陷；
   - `_on_load` 的 `ok=false` 分支是否安全、`world` 是否可能为 null；
   - `result["op_errors"] as PackedStringArray`、`result["events"]`、`result["audit"]` 的取用是否与 `TurnEngine.submit` 返回结构一致；
   - 第七十二章挂起（`awaiting_audit_ack`）在 UI 层是否有对应提示与再输入防护。
4. **冒烟真的执行了吗（重点）**：自己跑 `bash tools/test.sh`，确认 3/3 段出现
   `Godot Engine v4.7.2...` + `main scene ready, godot=4.7.2-stable (official)`（而不是「跳过」），
   13 个套件 `失败=0`，`全部通过。`，退出码 0。
5. **README 收尾（强制裁定 4）**：是否保留进度表/HANDOFF/台账链接/目录约定/设计不变量，仅做增量收尾（11 任务全 ✅、
   「计划 01 已完成」、运行/目录/存档/不变量与最终代码一致），而非被计划 Step 7 的短版整篇覆盖。
6. **`.uid` 与卫生**：`src/ui/main.gd.uid` 是否入库；提交后工作区是否干净；是否误改范围外文件（`src/rules/`、`src/core/` 等）。
7. **计划同步**：强制定 1 的三处路径 + 强制定 2 的两处共享 RNG + Step 7 措辞 + Step 8 的 `.uid` 是否都已同步；
   有无其它未披露偏离。
8. **人工验收（不可自动化）**：计划 Step 6 的 8 项 GUI 验收无法在 headless 下完成。报告是否明确标注「待人类执行」；
   请列出仍**未被任何自动化覆盖**的关键路径（点击按钮、创建流程表单、存档/读档按钮、第 15 回合挂起交互），作为残余风险。

## 输出格式（直接返回文本；controller 转存为 task-11-review.md）

```markdown
# Task 11 审查记录

审查者：<reviewer subagent>　模型：deepseek-flash　范围：16ba34b..70ad341

## 结论
- 规格符合：✅ / ❌
- 裁定：**Approved** / **Approved with findings** / **Rejected**
- 关键数字：Critical=n，Important=n，Minor=n

## 证据
<diff 摘要、冒烟原始关键行、独立复核/反证>

## 发现
| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|

## 对 4 条强制裁定的裁定
<路径统一 / 共享 RNG / .uid / README 增量收尾：是否落实、有无夹带>

## 未验证/存疑（含人工 GUI 验收缺口）
```

严重度：Critical=数据损坏/崩溃/规格实质违背；Important=明确缺陷但影响可控或有绕行；Minor=风格/测试强度/文档。
