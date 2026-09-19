# Task 4 报告：`GmResponseParser`

## 结果
完成。按计划 Task 4 逐字落地：

- 先写失败测试（Step 1）：在 `tests/llm_test.gd` 的 `return a.report("llm")` 之前逐字追加 `# ---- GmResponseParser ----` 用例块（10 条断言）。
- 红（Step 2）：`Identifier "GmResponseParser" not declared in the current scope.`（连带 6 条类型推断错误）、`套件无法实例化（语法错误？）: res://tests/llm_test.gd`、`总计失败=1，失败套件=1`、EXIT=1。
- 实现（Step 3）：新建 `src/gm/gm_response_parser.gd`（计划代码块逐字落盘，逐字核对 tab 缩进）。
- 绿（Step 4）：`[llm] 断言=26 失败=0`、`总计失败=0，失败套件=0`、`ALL TESTS PASSED`、`main scene ready`、`全部通过。`、EXIT=0。
- 提交（Step 5）：`b0d2258`。

未改动 `SUITES`（Task 2 已登记 `res://tests/llm_test.gd`，本任务不再新增套件）。未触碰其它 `src/`、`tests/*`。

## 提交
- commit：`b0d2258` — `feat(gm): LLM 响应解析（fail-closed）`
- 分支：`plan-02-llm-narrative`，父提交 `2544bec`
- 提交命令：
```bash
git add src/gm/gm_response_parser.gd src/gm/gm_response_parser.gd.uid tests/llm_test.gd
git commit -m "feat(gm): LLM 响应解析（fail-closed）"
```
- `git show --stat HEAD`：
```
b0d2258 feat(gm): LLM 响应解析（fail-closed）
 src/gm/gm_response_parser.gd     | 54 ++++++++++++++++++++++++++++++++++++++++
 src/gm/gm_response_parser.gd.uid |  1 +
 tests/llm_test.gd                | 19 ++++++++++++++
 3 files changed, 74 insertions(+)
```
- `.gd.uid` 由 `tools/test.sh` 的 `--import` 阶段生成，随实现一并提交（`uid://nxrn4o0gksdd`）。

## 文件
新增：
- `src/gm/gm_response_parser.gd` — `class_name GmResponseParser extends RefCounted`；`MAX_NARRATION=4000`；`TAG_WHITELIST=["train","work","social","rest","cast","idle"]`；内嵌 `class Result`（`ok/error/narration/ops/tags`）；`static parse(text) -> Result`（围栏剥离 → strip → 空/非字典/缺 narration/ops 非数组一律 `ok=false`，narration 超长截断到 4000，ops 深拷贝，tags 白名单过滤）；`static _strip_fences(text)`。
- `src/gm/gm_response_parser.gd.uid`

修改：
- `tests/llm_test.gd` — 追加 10 条 `GmResponseParser` 断言（合法 JSON / narration / ops / tags 白名单 / markdown 围栏 / 缺 narration / 非法 JSON / ops 非数组 / 超长仍可解析 / 超长截断）。`[llm]` 断言总数 16 → 26。

未触碰 `tests/run_tests.gd`（`SUITES` 已含 `llm_test`）。

## 测试原始输出
### 红灯证据（移除实现文件后重跑 `bash tools/test.sh`，EXIT=1）
```
SCRIPT ERROR: Parse Error: Identifier "GmResponseParser" not declared in the current scope.
SCRIPT ERROR: Parse Error: Cannot infer the type of "ok" variable because the value doesn't have a set type.
... （fenced / no_narr / bad_json / bad_ops / long_res 同类报错）
套件无法实例化（语法错误？）: res://tests/llm_test.gd
==== 总计失败=1，失败套件=1 ====
main scene ready, godot=4.7.2-stable (official)
测试失败：单测=1 冒烟=0
```
（6 条类型推断错误是 `GmResponseParser` 未声明导致的连带报错，根因即计划预期的 `Identifier "GmResponseParser" not declared`。）

### 绿灯（实现就位，`bash tools/test.sh`，EXIT=0）
```
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=18 失败=0
[magic_level] 断言=48 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=176 失败=0
[spell] 断言=227 失败=0
[gm] 断言=59 失败=0
[panel] 断言=71 失败=0
[selfcheck] 断言=32 失败=0
[save] 断言=96 失败=0
[async_probe] 断言=2 失败=0
[llm] 断言=26 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
main scene ready, godot=4.7.2-stable (official)
全部通过。
```
（`[probe] 失败=1` 仍是 `harness_test.gd` 的故意失败探针，不计入总计。stdout 中 `ERROR: Parse JSON failed ...` 来自「非法 JSON 失败」用例，是 `JSON.parse_string` 对 `"不是 JSON"` 的预期报错日志，该断言 `a.is_false(bad_json.ok)` 通过，属计划内行为。）

## 偏离
1. **绿灯断言数。** 计划未给出绝对断言数，实际 `[llm]` 断言 16 → 26（新增 10 条），失败=0。
2. **JSON 解析错误日志。** 非法 JSON 用例会产生一条 `ERROR: Parse JSON failed` 引擎日志（Godot `JSON.parse_string` 的固有行为），不是测试失败，属预期。
3. **其余无偏离。** 测试用例与实现均逐字取自计划 Task 4；简报硬性要求 `[llm]` 失败=0、15 套件失败=0、`main scene ready`、EXIT=0 全部达成。
