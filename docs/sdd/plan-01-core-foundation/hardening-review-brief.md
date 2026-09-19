# 计划 01 收尾加固批次 审查简报（reviewer）

> 只读审查。可用工具：read、bash（仅只读命令 + `bash tools/test.sh`）。禁止修改文件、禁止 git 写操作。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。这是一个**计划外加固批次**（计划 01 已完成后，控制器按 HANDOFF §8 收尾）。

## 审查对象

- 提交：`e094a52 test+fix(hardening): StateOps 输入硬化、测试强度补强、运行器静默假绿哨兵、UI 焦点收尾`（父 `e72e54d`）
- 审查包：`docs/sdd/plan-01-core-foundation/review-e72e54d..e094a52.diff`
- 背景：`HANDOFF.md §8`（#8 测试强度、#37 StateOps 输入硬化、#40 gm_test 空转断言、#51 UI 焦点、#53 冒烟假绿、#54 `_turn_count` 死变量）
- 不改动文件清单承诺：仅上列 11 个文件；不得改 `src/model/`、`src/core/turn_engine.gd`、`src/persist/`、`project.godot`、`README.md`、计划文档。

## 变更概览

1. `src/rules/state_ops.gd`：`add_money` 非数字报错；`set_flag`/`set_player_flag` 空 key 报错；`know_fact` 空 `fact_id` 报错；`relation_delta` 空 `npc_id` 报错。（§8#37）
2. `tests/*`：补强（§8#8/#40）：magic_level 全 10 档 BANDS/LABELS + 真越界 clamp；money 负值现状；gm 补 `op_errors` 内容、`know_fact`/`set_flag`/`set_player_flag`/`set_magic_tier`/`relation_delta` 负例与正例、非字典条、打工加钱、施法旁白、月份推进、被拒提交不推进回合；panel 空/边界；selfcheck 负回合/空世界/canon 超前；save 槽路径净化/缺失目录/非 hex 校验和/覆盖保存。
3. `tests/assert.gd` + `tests/run_tests.gd`：新增 `TestAssert.report_calls` 静态计数，运行器用它检测「套件中途报错、未调用 `report()`」的静默假绿。
4. `src/ui/main.gd`：`_on_load` 成功后 `command_edit.grab_focus()`；删除死变量 `_turn_count`。
5. `tools/test.sh`：冒烟改为 `tee` 捕获输出并 `grep -q "main scene ready"`，未命中即判失败（§8#53）。

## 必须核对

1. **行为正确性**：`StateOps` 四个 op 的硬化是否只在非法输入时报错、且**不写入**任何状态；合法输入行为与改动前一致（用 `gm_test` 的旧断言仍绿佐证）。
   `set_flag`/`set_player_flag` 空 key、`know_fact` 空 `fact_id`、`add_money` 非数字、`relation_delta` 空 `npc_id` 是否真的被拒绝。
   注意 `add_money` 现在接受 `TYPE_INT`/`TYPE_FLOAT`；`ScriptedGameMaster` 传的是 int，确认无回归。
2. **测试是否真的可判别（重点，逐类反证）**：
   - 新增断言在「把被测代码改坏」时是否变红。至少反证 1–2 条：例如删掉 `StateOps` 某条空 key 守卫 → `gm_test` 是否失败；改 `magic_level` 的 clamp 常量 → 是否失败。
   - `money_test` 的负值断言是否锁定了当前实现（不是被 `eq` 的宽容掩盖）。
3. **运行器哨兵（重点）**：`TestAssert.report_calls` 机制是否正确（静态变量跨脚本共享；`report()` 一定在成功路径被调用）。
   反证：在某个套件 `run()` 中制造一次真正的**中止性**错误（如 `var boom: int = "x"`），确认运行器把该套件计为失败（控制器实测：`总计失败=1`、EXIT=1）。
   注意区分：字符串 `%r` 这类**非中止**格式错误不会触发哨兵（执行会继续），这是预期还是漏洞？请说明。
4. **`tools/test.sh` 的 `tee`/`PIPESTATUS`**：在 `set -uo pipefail` 下取值是否正确；`mktemp`/`rm` 是否有泄漏；`grep` 未命中是否真的让脚本最终 exit 1（可临时用 `GODOT` 指向假命令或注释 `main scene ready` 验证，若不便则静态论证）。
5. **`main.gd`**：`grab_focus` 调用时机是否安全（`command_edit` 必存在？语义与 `_on_start_pressed` 一致）；删除 `_turn_count` 是否有遗漏引用。
6. **冒烟/全量仍绿**：自跑 `bash tools/test.sh`，确认 13 套件失败=0（含新增断言数：money 18 / magic_level 41 / gm 56 / panel 71 / selfcheck 32 / save 96）、3/3 出现 `main scene ready`、`全部通过。`、退出码 0。
7. **越界/夹带**：`git diff --name-only e72e54d..e094a52` 是否仅 11 个文件；是否有计划外行为改变（除了上述 5 组）；工作区是否干净。

## 输出格式（直接返回文本；controller 转存为 hardening-review.md）

```markdown
# 计划 01 收尾加固批次 审查记录

审查者：<reviewer subagent>　模型：deepseek-flash　范围：e72e54d..e094a52

## 结论
- 行为正确性：✅ / ❌
- 测试可判别性：✅ / ❌（列出反证结果）
- 运行器哨兵：✅ / ❌
- 裁定：**Approved** / **Approved with findings** / **Rejected**
- 关键数字：Critical=n，Important=n，Minor=n

## 证据
## 发现
| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
## 未验证/存疑
```
