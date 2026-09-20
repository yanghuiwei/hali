# Task 3 审查记录 · 19654f0..f6bc495

> 审查者：只读 `reviewer`（deepseek-flash，run ebcd6551）｜审查包：`review-19654f0..f6bc495.diff`（1 commit / 9 files / +157-1）
> 结论：**Spec ✅ 符合；Task quality = Approved**；Critical 0 / Important 0 / Minor 6（1 条 plan-mandated）
> 控制器核对（2026-09-20，`task-3-test-verify.log` + `task-3-test-red.log`）：绿步重跑 **EXIT=0**、`[factions] 60 失败=0`、`[save] 107 失败=0`、`[gm] 71 失败=0`、`[llm] 88 失败=0`、`总计失败=0，失败套件=0`、`全部通过。`；`SCRIPT ERROR` **2 条 = 基线 2 条**；红步日志存在且 `总计失败=4，失败套件=4`（3 条 `Nonexistent function/member` + 1 条 `Invalid access to property`，逐条对应缺失 API）；`git status` 干净。

## Spec Compliance（逐条）

1. `PlayerState` ✅ —— `standing: Dictionary`（`:28`）、`STANDING_MIN/MAX`、`standing_of()`、`add_standing()`（`:73-78`，返回钳制后新值）、`to_dict()` 增键（`:91`）、`from_dict()` 过 `JsonUtil.normalize`（`:120`），与 brief 逐字一致。
2. `StateOps` 三 op ✅ —— 插在 `relation_delta` 与 `set_magic_tier` 之间（`:79-104`）；三条文案逐字一致（`未知派系: %s`、`该派系尚未揭示，无法加入: %s`、`警告：加入非法组织（%s），法律后果留待后续结算`）；outlaw **先写状态再追加警告**（非 rollback）；`leave_faction` 只清 `faction_id` 不碰 `standing`；`delta` 用内联 `typeof`（未新增公共工具）；`stance_to_player += delta / 2` 钳 ±100。
3. `factions.gd` 只新增 `visible_faction_ids()` ✅（`:139-146`），**无 `reveal()`**（Task 6 专属）；注释显式提示 `PackedStringArray == Array` 是解析期错误，调用处（`state_ops.gd:83`）用 `.has()`。
4. `OpGuard` ✅ —— `MAX_STANDING_DELTA := 20`（`:7`）；两分支组（`:71-77`、`:79-85`）；缺 `faction_id` 只警告 + `continue`；`_:` 分支未动 → 未知 `set_faction_*` 仍**透传**给 StateOps 拒绝。
5. `save_codec.gd` ✅ —— 只加 `player.standing` 嵌套类型检查（`:29-33`），`SAVE_VERSION` 与其他分支未动。
6. 测试位置与覆盖 ✅ —— 四处新增断言均在各自 `return a.report(...)` 之前；新增断点数 17+8+4+10 = 39，与报告的 Δ 表逐套件吻合；outlaw 留痕、双层 delta 钳制、往返（`faction_id`/`standing 42`/`government_type`/`factions.size()==17`）均覆盖。

**点名风险复核（4/4 不成立）**：① 既有 `model_test`/`save_test` 断言无「player 键数固定」类，深比较两侧同源 → 未破坏；② 揭示顺序正确（未揭示加入断言在 `"revealed" = true` **之前**执行）；③ `save_codec` 类型检查不误伤（`p.has("standing")` 前置 → 老存档与 `{}` 放行，只有非字典被拒）；④ `OpGuard` 新增分支未改变既有 op 索引（`llm_test` 的 `gres.ops[0..3]`/`size()==5` 不受影响）。

## Strengths

- 实现与 brief Step 3 近乎逐字（含文案与常量），无夹带设计外改动；9 个文件全在允许范围。
- 守卫**可辨**：`" | ".join(errs).contains("未揭示")` 的文案全仓仅 `state_ops.gd:83` 一处 → 该断言确实由 reveal 守卫拦下，而非「未知派系」分支碰巧命中。
- `visible_faction_ids()` 直接落最终版并注释版本陷阱，为 Task 6 留干净接缝。
- 存档**可加性兼容**：`standing` 新增键 + `p.has(...)` 前置 ⇒ 老存档/`{}` 放行、`SAVE_VERSION` 未动。
- `save_test.gd` 的两处超 brief 补强属**合理测试补强**（在 brief 列出的文件内、不涉生产代码、且理由断言 `error.contains("standing")` 有区分度，能排除「碰巧被别的分支拒了」）。

## Issues

### Critical / Important
无。

### Minor（6）

1. **`illegal_affiliation` 会陈旧化** —— `state_ops.gd:86-88` 与 `:90-91`：先入 `death_eaters` → `leave` → 再入 `ministry`，`flags["illegal_affiliation"]` 仍指 `death_eaters`。当前**无读取端**，brief 也只要求「加入 outlaw 时写入」。**处置：留 03c 明确清除/归一规则**（登记，勿让下游面板把合法所属标成非法）。
2. **`join_faction` 改换语义无断言** —— `:90-91`：直接改换（不先 `leave`）被静默采用，`standing` 保留。**处置：并入 Task 4 补一条断言固化语义**（不改代码）。
3. **`delta / 2` 向零截断（plan-mandated）** —— `:104`：`-5/2 = -2` 而非 `-3`，与设计文字「`delta//2`」有 1 点不对称。**处置：并入 Task 4 补负向奇数边界断言钉住截断（语义不改）**。
4. **`faction_standing_delta` 不鉴别 NaN/Inf** —— `op_guard.gd:78-85`：`1e400` → 极端值被 `clampi` 收口，无实际危害。**处置：仅登记**。
5. **`llm_test.gd:117-121` 弱断言** —— 把 `ops[i]["op"]` 拼字符串再 `contains(...)`，可判别性弱于精确索引断言。**处置：并入 Task 11（§8#64 测试可判别性批次）收紧**。
6. **嵌套校验只保护 `standing` 一个字段** —— 其他 player 字段的嵌套负例仍走 `from_dict` 类型化赋值并产生 `SCRIPT ERROR`（既有噪音，非本次引入）。**处置：登记；是否推广属既有缺口（存档 v2 议题）**。

**报告口径核对**：报告 §7 七条未验证项经审查者逐条在源码复核——**全部成立**（`:98` 非数值 delta→0；整数除法截断；StateOps 不钳 delta；`standing`/`illegal_affiliation` 无读取端；缺 id 警告分支无断言；`leave` 幂等分支无断言；只覆盖正向边界）。
