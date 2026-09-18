# Task 5 修复轮 · scoped 复审简报（reviewer）

> 只读复审。禁止修改文件、禁止 git 写操作。工具：read、bash（只读 + `bash tools/test.sh`）。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。
> 第一轮完整审查见 `.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-5-reviewer.log`
> （结论：Critical=0 / Important=4 / Minor=9）。

## 修复提交

- 修复轮：`f9038ca fix(world): major 同月去重 + RngService 存档恢复 seed_value + 消除空转测试`
- 原始实现：`23e67cd`
- 查看：`git show f9038ca`、`git diff 23e67cd..f9038ca`

## controller 声称本轮处置的内容（请逐条核实真伪）

1. **第一轮 Important #1（同月双 major）**：`src/model/world_state.gd` `tick()` 在 `if is_major: add_fact(...)` 后加 `break`，
   使同月最多落地一起重大事件，结构上保证相邻 major 间隔 ≥ `MAJOR_EVENT_GAP`（12 个月）。
2. **第一轮 Important #4（`load_state` 不恢复 `seed_value`）**：`src/core/rng_service.gd` 的
   `state_dict()` 现在返回 `{"seed_value": <int>, "streams": {name: {seed, state}}}`；`load_state()` 先恢复 `seed_value`，
   使恢复后**新建**的命名流沿用原 seed（而不是构造时的 seed）。
3. **第一轮 Minor #5/#6/#7（空转测试与死变量）**：
   - `tests/world_tick_test.gd`：删除死变量 `var rng := RngService.new(w.game_seed)`；
   - major 测试把 `w2.player.location_id` 设为 `ministry_of_magic`（让 major 真正进入候选集），
     新增「至少出现一次 major」与「相邻 major 最小间隔 ≥ 12」两条断言；
   - 信息保护测试把 `w3.player.location_id` 设为 `ministry_of_magic`，新增 `events_seen > 0` 断言；
   - `tests/clock_test.gd`：新增「恢复后新流沿用原 seed」断言（`RngService.new(0).load_state(snapshot)` 对比 `RngService.new(42)`）。
4. **计划同步**：计划 Task 5 的 Step 1（两个测试）、Step 3（`RngService`）、Step 6（`tick()` 的 `break`）已改为与代码逐字一致。
5. **反证（controller 执行）**：
   - 把 `state_dict/load_state` 临时改回旧 schema → `[clock] 恢复后新流沿用原 seed: 期望 <528154>，实际 <475519>`，`[clock] 失败=1`，EXIT=1，随后还原；
   - **诚实披露**：把 `tick()` 的 `break` 临时删除后，当前 seed（w2 用 1234）**没有**触发 `min_gap < 12`，即该断言在当前种子下**未**实际捕获同月双 major；
     `break` 的正确性来自代码结构而非该测试。请评估这是否可接受，以及是否需要在后续任务中补一条能强制触发双 major 的确定性用例。

## 请你完成

1. `git diff 23e67cd..f9038ca` 逐行核对是否只含上述内容、无夹带、无越界文件。
2. 判断修复 #1 是否**结构上正确**：`break` 位置是否能保证同月至多一起 major；是否存在其它绕过 `MAJOR_EVENT_GAP` 的路径
   （例如 `major_ready` 在循环外只算一次是否仍会被同月 break 覆盖；连续多月是否会累积）。
3. 判断修复 #4 是否**正确且向后兼容**：新 schema 下 `load_state` 对旧 schema（无 `seed_value`/`streams` 键）会怎样；
   `state_dict → JSON.stringify → parse_string → load_state` 端到端是否仍一致。
4. 判断测试去空转是否**真的不再空转**：`major_count >= 1` 与 `events_seen > 0` 在当前 seed 下是否成立、是否稳定（确定性）；
   `min_gap >= 12` 在 `break` 修复后是否恒真。
5. 自己跑一次 `bash tools/test.sh`（单实例），确认 `[clock] 断言=29 失败=0`、`[world_tick] 断言=104 失败=0`、
   `总计失败=0`、`ALL TESTS PASSED`、退出码 0。
6. 复核计划 Step 1/3/6 与代码是否逐字一致。
7. 明确第一轮哪些 finding 本轮**未处置**（预期：Important #2 `weight` 未用、Important #3 `rng_state` 死字段、Minor #8–#13），
   并给出严重度是否随本轮变化。

## 输出格式

```markdown
# Task 5 修复轮 scoped 复审

复审者：<reviewer subagent>　模型：deepseek-flash　范围：23e67cd..f9038ca

## 结论
- 第一轮 Important #1：#1 ADDRESSED / PARTIAL / NOT ADDRESSED
- 第一轮 Important #4：ADDRESSED / PARTIAL / NOT ADDRESSED
- Minor #5/#6/#7：已消除空转 / 仍有空转
- 有无新问题/夹带：有（列出）/ 无
- 总评：**通过** / **不通过（需再修）**

## 证据
<diff 观察、测试原始输出关键行、对 break/seed_value 的独立推演或沙箱验证>

## 残留发现（含第一轮未处置项）
| # | 严重度 | 位置 | 问题 | 建议 |
|---|--------|------|------|------|

## 未验证/存疑
```

若发现 Critical，请给出最小复现。
