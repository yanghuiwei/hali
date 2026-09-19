# Tasks 6–7 审查记录

**范围**：`0a86471`（Task6）→ `38589b4`（Task7，当前 HEAD），分支 `plan-02-llm-narrative`，仓库 `E:/Hali`
**依据**：计划 `docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md` 的 `### Task 6/7`（逐字代码）＋ spec `docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md` §8/§11
**审查方式**：只读 + 临时反证（改动已全部 `git checkout` 还原，`git status` 仅剩审查前既有的两个未跟踪 diff 文件）

## 结论

**通过（无阻断项）。** Task 6/7 行为与计划逐字一致，spec §8/§11 的强制规则全部落地；9 项 checklist 全过；反证 3 组均精确命中对应断言（见证据 C）；越界=0；全量测试绿。

## 证据

### A. Task 6 行为（`src/rules/state_ops.gd`）
- **反刷记账在 StateOps 内**：`train_skill`（L25–31）先 `registry.has("skills")` 校验，再 `Progression.gain(world, id, base_gain)` 计算并经 `world.player.add_skill` 写回；`Progression.gain`（`src/rules/progression.gd`）把 `recent_training` 记账写入 `world.flags` 并返回递减后的收益。GM/OpGuard 不直改世界。测试 `[gm]`：首次 `gain==4`、同地点二次 `<4`、`world.flags.has("recent_training")`、未知技能报错 1 条，全部通过（63/0）。
- **`world_gm_rng` 加盐**（L93–96）：`counter = int(world.flags.get("_gm_rng_counter", 0))`；写回 `counter+1`；种子 `game_seed + turn*15485863 + counter*2654435761`。同一 world 连续 3 次调用 → 3 个不同 seed，`[spell]` 的「同回合 roll 不同」通过（229/0）。
- **计数器随存读档往返**（静态路径论证）：`world.flags["_gm_rng_counter"]` → `WorldState.to_dict()` 含 `"flags": flags`（world_state.gd:166）→ `SaveCodec.encode` JSON 序列化；`decode` 的 `_validate_payload` 把 `flags` 列入 dict 白名单（save_codec.gd:16）→ `from_dict` `w.flags = JsonUtil.normalize(...)`（world_state.gd:185），`JsonUtil.normalize` 把整数型 float 归一为 int。`world_gm_rng` 用 `int()` 读回，类型安全。`tick()` 只 `erase("energy_loop_count")`，不重置该键（符合 §11「可不重置」）。
- **既有 `[gm]`/`[spell]` 无回归**：改动前实测 `[gm] 63/0`、`[spell] 229/0`；仅新增断言，无既有断言被改写（diff 确认）。

### B. Task 7 行为（`src/gm/op_guard.gd`）
逐条对照 spec §8 表：

| 规则 | 位置 | 落实 |
| --- | --- | --- |
| ops 上限 20 截断+警告 | L22–24 | ✅ `out.ops.size() >= MAX_OPS` → warning+break；`[llm]` 50 个 set_job → 20 |
| `gain_skill`→`train_skill{base_gain:4}`（忽略 amount） | L28–33 | ✅ 仅当技能存在；未知技能 warning 丢弃 |
| `add_money` 单回合正收益累计钳 1000 | L34–45 | ✅ 局部 `money_gain` 累计；`room<=0` 丢弃+警告；单次超额钳到 1000 |
| `relation_delta` trust/interest/hostility 各 ±20 | L50–60 | ✅ `clampi(..., -20, 20)`；缺 npc_id 丢弃+警告 |
| `set_magic_tier` 相对 ±1，且不出 `[0, LABELS-1]` | L46–49 | ✅ 两级 `clampi` |
| `set_flag`/`set_player_flag` key 非空、`_` 开头拒绝 | L61–66 | ✅ `key.is_empty() or key.begins_with("_")` → 丢弃+警告 |
| `know_fact` fact_id/空 source/`system` 拒绝 | L67–73 | ✅ 三项合并判定 |
| `cast_spell`/`learn_spell`/`set_location`/`set_job` 透传 | L74–75 | ✅ `out.ops.append(raw)` |
| 未知 op 透传给 StateOps | L76–78 | ✅ warning + `append(raw)` |
| 纯函数（只读 world/registry） | 全文件 | ✅ 不改 world（`gworld` 测试前后无变化） |

`[llm]` 39/0 通过；`OpGuard.MAX_*` 常量与 spec 数值一致（20/1000/20）。

### C. 反证（临时改动 → 实测 → 已还原）
1. **§8#33**：`world_gm_rng` 改回旧实现（去掉 counter 三行）。
   结果：`[spell] 同回合多次施法掷骰不同（§8#33）: 期望为真`、`[spell] RNG 计数器随调用递增并持久化: 期望 <3>，实际 <0>`，`[spell] 229 失败=2`，总计失败=2/失败套件=1，EXIT=1。→ 断言有效。
2. **OpGuard `add_money` 钳制**：`add_money` 分支改为 `out.ops.append(raw)`。
   结果：`[llm] add_money 钳到上限: 期望 <1000>，实际 <999999>`、`[llm] 产生警告: 期望为真`，`[llm] 39 失败=2`，EXIT=1。→ 断言有效。
3. **OpGuard 下划线 flag 拒绝**：`key.is_empty() or key.begins_with("_")` → `key.is_empty()`。
   结果：`[llm] 拒绝保留 flag 与 system 来源后剩 5 个 op: 期望 <5>，实际 <6>`、`[llm] 下划线 flag 被拒: 期望为假`、`[llm] 产生警告: 期望为真`，`[llm] 39 失败=3`，EXIT=1。→ 断言有效。
   **还原校验**：`git checkout --` 后 `git diff --stat` 为空，`git status --short` 仅剩 `review-0a86471^..38589b4.diff`、`review-a33a33a..HEAD.diff`（审查前既有未跟踪文件）。

### D. 越界
`git diff --name-only 0a86471^..38589b4` 精确等于白名单 6 个文件：
`src/rules/state_ops.gd`、`src/gm/op_guard.gd`、`src/gm/op_guard.gd.uid`、`tests/gm_test.gd`、`tests/spell_test.gd`、`tests/llm_test.gd`。拆分提交亦正确：`0a86471`=state_ops+gm_test+spell_test，`38589b4`=op_guard(+uid)+llm_test。仓库内 `docs/sdd/plan-02-llm-narrative/review-0a86471^..38589b4.diff` 与 `git diff 0a86471^..38589b4` 逐字节一致（diff 比对通过）。
> 备注：`tests/run_tests.gd` 的 `SUITES` 实际注册 16 个套件；输出另有 `[probe]`（`harness_test` 内部断言库自检）共 17 行报告，故「17 套件」指报告行数，`失败套件=0` 一致。

### E. 全量自跑（还原后最终态）
```
[gm]    断言=63  失败=0
[spell] 断言=229 失败=0
[llm]   断言=39  失败=0
==== 总计失败=0，失败套件=0 ====
main scene ready, godot=4.7.2-stable (official)
全部通过。 EXIT=0
```
与简报预期数值完全一致。

## 发现表

| # | 严重度 | 位置 | 问题 | 说明/建议 |
| --- | --- | --- | --- | --- |
| F1 | Minor（源自计划，非 worker 偏差） | `op_guard.gd:34–45` | spec §8 要求 `add_money` **负值（支出）不设上限但记警告**，实现对负值静默透传、无 warning | 计划 Task 7 代码即如此，worker 逐字照搬。若要与 spec 字面一致，可在 `knuts < 0` 时 `out.warnings.append(...)`；不影响正确性与现有测试 |
| F2 | Minor（源自计划） | `op_guard.gd:46–49` | spec §8 写 `set_magic_tier`「更大变化**丢弃并警告**」，实现为**钳到 ±1**且不发 warning | 行为上仍满足 brief 的 ±1 约束（`[llm]` 通过）；仅「丢弃+警告」语义与 spec 措辞不符。建议 spec 或实现二选一对齐 |
| F3 | Low / 测试覆盖 | `tests/llm_test.gd:73–104` | 多条已实现规则缺专门断言：`know_fact` 空 source、`set_player_flag` 下划线、`learn_spell`/`set_location`/`set_job` 透传、未知技能 warning、`relation_delta` 缺 npc_id 丢弃 | 实现在 `op_guard.gd` 中均存在；建议后续补参数化用例（不阻断本任务） |
| F4 | Low / 测试覆盖 | `tests/save_test.gd` | `_gm_rng_counter` 的存档往返**无专用用例**（`save_test` 的 `make_world()` 未写 `world.flags`，仅空字典往返） | 序列化路径与其他 flags 同构，静态可证；建议补一条「写入 flags→encode→decode→计数一致」用例以锁定 §11 |

## 未验证

1. **专用存读档实验**：未构造写入 `_gm_rng_counter` 的存档实跑 decode（避免落盘新文件）；仅做代码路径论证（`to_dict`/`from_dict`/`_validate_payload`/`JsonUtil.normalize`），结论见 A。F4 是同一缺口的测试侧记录。
2. **OpGuard 对畸形内层类型的鲁棒性**：`GmResponseParser` 只校验 `ops` 是数组，不校验元素字段类型；`op_guard.gd` 对 `knuts`/`tier`/`trust` 等直接 `int(...)`。若 LLM 返回如 `{"op":"add_money","knuts":{}}`，`int(Dictionary)` 很可能抛运行期 `Invalid call. Nonexistent 'int' constructor`（save_test 中 `int(null)` 已出现同类报错），即 OpGuard 对该输入不 fail-closed 而是崩溃。**未实跑确认**（需新增临时用例），故列为未验证；与计划逐字代码一致，属计划层面待加固点。
3. **生产接线**：`OpGuard` 目前仅被 `tests/llm_test.gd` 调用，尚未接入 `LlmGameMaster`/`TurnEngine`（计划 Task 8 范围）；端到端「LLM ops → OpGuard → StateOps」链路行为不在本次审查内。
4. **真机 LLM**：全部用例为离线 `MockLlmProvider`，未验证真实 provider 输出经 OpGuard 的实际表现。
5. **跨回合确定性**：spec §11「同 seed + 同 ops 串结果一致」本文仅论证了计数器持久化路径，未做多回合回放对拍实验。
