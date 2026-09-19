# Task 3 报告：`LlmSettings`

## 结果
完成。按计划 Task 3 逐字落地：

- 先写失败测试（Step 1）：在 `tests/llm_test.gd` 的 `return a.report("llm")` 之前逐字追加 `# ---- LlmSettings ----` 用例块。
- 红（Step 2）：`Identifier "LlmSettings" not declared in the current scope.`，`套件无法实例化（语法错误？）: res://tests/llm_test.gd`，`总计失败=1，失败套件=1`，EXIT=1。
- 实现（Step 3）：新建 `src/gm/llm_settings.gd`（计划代码块 `sed -n '315,360p'` 原样落盘，逐字核对 tab 缩进）。
- 绿（Step 4）：`[llm] 断言=16 失败=0`、`总计失败=0，失败套件=0`、`ALL TESTS PASSED`、`main scene ready`、`全部通过。`、EXIT=0。
- 提交（Step 5）：`2544bec`。

未改动 `SUITES`（Task 2 已登记 `res://tests/llm_test.gd`）。未触碰其它 `src/`、`tests/*`。

## 提交
- commit：`2544bec` — `feat(gm): LLM 配置读写与环境变量覆盖`
- 分支：`plan-02-llm-narrative`，父提交 `a33a33a`
- 提交命令：
```bash
git add src/gm/llm_settings.gd src/gm/llm_settings.gd.uid tests/llm_test.gd
git commit -m "feat(gm): LLM 配置读写与环境变量覆盖"
```
- `git show --stat HEAD`：
```
2544bec feat(gm): LLM 配置读写与环境变量覆盖
 src/gm/llm_settings.gd     | 46 ++++++++++++++++++++++++++++++++++++++++++++++
 src/gm/llm_settings.gd.uid |  1 +
 tests/llm_test.gd          | 17 +++++++++++++++++
 3 files changed, 64 insertions(+)
```
- `.gd.uid` 由 `tools/test.sh` 的 `--import` 阶段生成，随实现一并提交（`uid://bxtwtklshebbl`）。

## 文件
新增：
- `src/gm/llm_settings.gd` — `class_name LlmSettings extends RefCounted`；字段 `provider/base_url/model/api_key/temperature/max_tokens/timeout_ms`；`DEFAULT_PATH="user://llm_settings.json"`；`static load_from(path=DEFAULT_PATH)`（文件缺失/非法 JSON/非字典时回退默认，`HALI_LLM_API_KEY` 非空则覆盖 `api_key`）、`_apply(Dictionary)`、`is_configured()`（三要素非空）、`save_to(path=DEFAULT_PATH)`（写 JSON 缩进串，返回 `Error`）。
- `src/gm/llm_settings.gd.uid`

修改：
- `tests/llm_test.gd` — 追加 7 条 `LlmSettings` 断言（默认未配置 / 三要素齐全 / 写盘 OK / 读回 base_url、model、api_key / 缺失文件回退默认）。`[llm]` 断言总数 9 → 16。

未触碰 `tests/run_tests.gd`（`SUITES` 已含 `llm_test`）。

## 测试原始输出
### 红灯证据（只有测试、暂无实现，`bash tools/test.sh`，EXIT=1）
```
SCRIPT ERROR: Parse Error: Cannot infer the type of "s" variable because the value doesn't have a set type.
SCRIPT ERROR: Parse Error: Cannot infer the type of "s2" variable because the value doesn't have a set type.
SCRIPT ERROR: Parse Error: Cannot infer the type of "s3" variable because the value doesn't have a set type.
SCRIPT ERROR: Parse Error: Identifier "LlmSettings" not declared in the current scope.
ERROR: Failed to load script "res://tests/llm_test.gd" with error "Parse error".
套件无法实例化（语法错误？）: res://tests/llm_test.gd
==== 总计失败=1，失败套件=1 ====
main scene ready, godot=4.7.2-stable (official)
测试失败：单测=1 冒烟=0
```
（3 条类型推断错误是 `LlmSettings` 未声明导致的连带报错，根因即计划预期的 `Identifier "LlmSettings" not declared`。）

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
[llm] 断言=16 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
main scene ready, godot=4.7.2-stable (official)
全部通过。
```
（`[probe] 失败=1` 仍是 `harness_test.gd` 的故意失败探针，不计入总计；两条 `SCRIPT ERROR` 来自 `save_test` 的畸形存档用例，基线即为 0 失败，非本任务引入。）

## 偏离
1. **「14 套件失败=0」措辞。** 简报这条与 Task 2 报告记录一致地偏旧：`SUITES` 在 Task 2 加入 `llm_test` 后为 **15** 项（本任务不再新增套件）。运行器汇总行 `失败套件=0` 已满足；若按打印行数计为 16 行，多出的一行是 `harness` 套件内的 `[probe]` 故意失败探针。
2. **其余无偏离。** 测试用例与实现均逐字取自计划 Task 3；`stdout` 中 `[llm] 失败=0` 满足简报硬性要求，EXIT=0、`main scene ready` 均达成。
