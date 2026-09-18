# Task 5 修复轮 2 · scoped 复审简报（reviewer）

> 只读复审。禁止修改文件、禁止 git 写操作。工具：read、bash（只读 + `bash tools/test.sh`）。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。
> 上一轮（修复轮 1）复审见 `.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-5-rereviewer.log`
> （总评通过；提出 N1 Important 等）。

## 修复提交

- 修复轮 2：`24d5d43 fix(rng): 存档 seed/state 字符串化防 JSON 精度丢失 + 测试改用可判别种子`
- 上一修复轮：`f9038ca`
- 查看：`git show 24d5d43`、`git diff f9038ca..24d5d43`

## controller 声称本轮处置的内容（请逐条核实）

1. **N1（`rng.state` int64 经 JSON 丢精度）**：`src/core/rng_service.gd` 的 `state_dict()` 现在把 `seed`/`state`/`seed_value`
   一律以十进制**字符串**入档；`load_state()` 用 `int(str(...))` 解析回来。并加了 `_streams.clear()`，把恢复语义明确为「替换」。
2. **N2（`min_gap>=12` 对 #1 无判别力）**：`tests/world_tick_test.gd` 的 `w2` 种子由 `1234` 改为 `38`（据上一轮扫描，该种子在无 `break` 时会出现同月双 major）。
3. **R12 部分（空转断言）**：`tests/clock_test.gd` 的存档恢复断言由「单次续抽 + `JSON.stringify(...).length()>0`」改为
   **20 次续抽逐一比对**，且恢复路径真正经过 `JSON.stringify → parse_string`；`tests/world_tick_test.gd` 把
   `events is Array`（编译期恒真）换成 `w.clock.turn == 13 + i`。
4. 计划 Step 1/3 已同步为与代码逐字一致。

## controller 的反证（请在只读条件下独立复核或给出等价推演）

- **N2**：把 `tick()` 的 `break` 临时删除 → `[world_tick] 相邻 major 事件至少相隔 12 个月（实际最小间隔=0）: 期望为真`，`[world_tick] 失败=1`，EXIT=1（种子 38 生效）。
- **N1**：把 `state_dict/load_state` 临时改回原始 int（不字符串化）→ `[clock] 经 JSON 往返后第 1..N 次抽取一致` 大量失败。
  两处临时改动均已还原；最终 `bash tools/test.sh` 绿（`[clock] 断言=47 失败=0`、`[world_tick] 断言=104 失败=0`）。

## 请你完成

1. `git diff f9038ca..24d5d43` 逐行核对是否只含上述 4 项、无夹带、无越界文件。
2. 独立判断 `state_dict/load_state` 的字符串化是否**正确且完整**：
   - `seed`/`state`/`seed_value` 三类是否都已字符串化；`int(str(...))` 对缺失键、旧 schema、非字符串值的行为；
   - `_streams.clear()` 是否引入新问题（例如同时恢复多个流、或恢复后再 `stream()` 新建流）；
   - 是否仍存在 int64 经 JSON 的其它丢失路径（如 `state_dict` 返回值被 `JsonUtil.normalize` 处理时会不会把字符串数字还原成 int 或 float）。
3. 独立判断 `clock_test` 的 20 次续抽是否**真的能捕获** int64 精度丢失（可推演或沙箱验证，勿在仓库内留改动）。
4. 自己跑一次 `bash tools/test.sh`（单实例），确认 `[clock] 断言=47 失败=0`、`[world_tick] 断言=104 失败=0`、
   `总计失败=0`、`ALL TESTS PASSED`、退出码 0。
5. 复核计划 Step 1/3 与代码逐字一致。
6. 列出仍未处置的上一轮发现（预期：R2 `weight` 未用、R3 `rng_state` 死字段、N3 旧 schema/版本号、N4 泄露断言仍恒真、R8/R9/R10/R11/R13），并给出最终严重度与「是否可留到后续任务」的判断。

## 输出格式

```markdown
# Task 5 修复轮 2 scoped 复审

复审者：<reviewer subagent>　模型：deepseek-flash　范围：f9038ca..24d5d43

## 结论
- N1：ADDRESSED / PARTIAL / NOT ADDRESSED
- N2：ADDRESSED / PARTIAL / NOT ADDRESSED
- R12：已消除空转 / 仍有空转
- 有无新问题/夹带：有（列出）/ 无
- 总评：**通过** / **不通过（需再修）**

## 证据
<diff 观察、测试原始输出关键行、对字符串化与 20 次续抽的独立推演/沙箱验证>

## 残留发现（含前两轮未处置项）
| # | 严重度 | 位置 | 问题 | 是否可留到后续任务 |
|---|--------|------|------|--------------------|

## 未验证/存疑
```
