# Task 2 报告

## 结果
完成。按计划 Task 2 逐字落地 `LlmProvider` 接口（含内嵌 `LlmRequest`/`LlmResponse`）与 `MockLlmProvider`，并登记 `res://tests/llm_test.gd` 到 `tests/run_tests.gd` 的 `SUITES`。

- 红：先只登记套件、暂移实现文件，`[llm]` 因 `Could not find type "LlmProvider"` 解析失败，`总计失败=1，失败套件=1`，EXIT=1（见下「红灯证据」）。
- 绿：实现就位后 `bash tools/test.sh` → `[llm] 断言=9 失败=0`、`==== 总计失败=0，失败套件=0 ====`、`ALL TESTS PASSED`、`main scene ready`、`全部通过。`、EXIT=0。
- 一处与简报不符：简报写 `[llm] 断言=10`，但计划里的 Task 2 用例逐字抄录后是 **9** 条断言（详见「偏离」）。本任务以简报的首要指令「逐字用计划里的代码」为准，未擅自加断言。

## 提交
- commit：`a33a33a`（`feat(gm): LlmProvider 接口与 Mock provider`）
- 分支：`plan-02-llm-narrative`，父提交 `f44c50d`
- 提交命令（照简报原样）：
```bash
git add src/gm/llm_provider.gd src/gm/llm_provider.gd.uid src/gm/providers/mock_provider.gd src/gm/providers/mock_provider.gd.uid tests/llm_test.gd tests/llm_test.gd.uid tests/run_tests.gd
git commit -m "feat(gm): LlmProvider 接口与 Mock provider"
```
- `git show --stat HEAD`：
```
a33a33a feat(gm): LlmProvider 接口与 Mock provider
 src/gm/llm_provider.gd                | 23 +++++++++++++++++++++++
 src/gm/llm_provider.gd.uid            |  1 +
 src/gm/providers/mock_provider.gd     | 20 ++++++++++++++++++++
 src/gm/providers/mock_provider.gd.uid |  1 +
 tests/llm_test.gd                     | 33 +++++++++++++++++++++++++++++++++
 tests/llm_test.gd.uid                 |  1 +
 tests/run_tests.gd                    |  1 +
 7 files changed, 80 insertions(+)
```

## 文件
新增：
- `src/gm/llm_provider.gd` — `class_name LlmProvider`；内嵌 `class LlmRequest`（system_prompt/user_prompt/temperature/max_tokens/timeout_ms/json_mode）、`class LlmResponse`（ok/text/error/http_status/latency_ms）；基类 `complete()` 返回 `未实现的 provider`。
- `src/gm/llm_provider.gd.uid`
- `src/gm/providers/mock_provider.gd` — `class_name MockLlmProvider extends LlmProvider`；`queue`/`errors`/`requests`，按索引出队、可注入错误、队列空返回失败；签名用限定类型 `LlmProvider.LlmRequest` / `LlmProvider.LlmResponse`。
- `src/gm/providers/mock_provider.gd.uid`
- `tests/llm_test.gd` — `class_name LlmTest`，`[llm]` 套件（Mock 出队 / 队列空 / 请求记录 / 错误注入）。
- `tests/llm_test.gd.uid`

修改：
- `tests/run_tests.gd` — `SUITES` 末尾加一行 `"res://tests/llm_test.gd",`（仅此一处改动）。

未触碰其它 `src/`、`tests/*` 与 `tests/assert.gd`。

## 测试原始输出
### 红灯证据（登记套件、暂移实现，`bash tools/test.sh`，EXIT=1）
关键片段：
```
== 2/3 单元测试 ==
...
SCRIPT ERROR: Parse Error: Could not find type "LlmProvider" in the current scope.
   at: GDScript::reload (res://tests/llm_test.gd:30)
ERROR: Failed to load script "res://tests/llm_test.gd" with error "Parse error".
套件无法实例化（语法错误？）: res://tests/llm_test.gd
==== 总计失败=1，失败套件=1 ====
== 3/3 主场景冒烟 ==
main scene ready, godot=4.7.2-stable (official)
测试失败：单测=1 冒烟=0
```

### 绿灯（实现就位，`bash tools/test.sh`，EXIT=0）
```
== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/3 单元测试 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

[probe] 故意失败: 期望 <2>，实际 <1>
[probe] 断言=1 失败=1
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
SCRIPT ERROR: Invalid assignment of property or key 'personality' with value of type 'int' on a base object of type 'RefCounted (PlayerState)'.
   at: from_dict (res://src/model/player_state.gd:97)
   GDScript backtrace (most recent call first):
       [0] from_dict (res://src/model/player_state.gd:97)
       [1] from_dict (res://src/model/world_state.gd:177)
       [2] decode (res://src/persist/save_codec.gd:81)
       [3] run (res://tests/save_test.gd:79)
       [4] _run_suite (res://tests/run_tests.gd:67)
       [5] _initialize (res://tests/run_tests.gd:35)
SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor.
   at: from_dict (res://src/core/game_clock.gd:10)
   GDScript backtrace (most recent call first):
       [0] from_dict (res://src/core/game_clock.gd:10)
       [1] from_dict (res://src/model/world_state.gd:176)
       [2] decode (res://src/persist/save_codec.gd:81)
       [3] run (res://tests/save_test.gd:79)
       [4] _run_suite (res://tests/run_tests.gd:67)
       [5] _initialize (res://tests/run_tests.gd:35)
[save] 断言=96 失败=0
[async_probe] 断言=2 失败=0
[llm] 断言=9 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

main scene ready, godot=4.7.2-stable (official)
全部通过。
```
（`[probe] 失败=1` 是 `harness_test.gd` 的故意失败探针，历来存在且不计入总计；两条 `SCRIPT ERROR` 来自 `save_test` 的畸形存档用例，基线即为 0 失败，非本任务引入。）

## 偏离
1. **`[llm] 断言=10` vs 实测 9。** 简报硬性第 3 条要求 `[llm] 断言=10 失败=0`，但计划 Task 2 的 `tests/llm_test.gd` 代码块逐字抄录只有 9 条断言调用（`a.eq`×5 + `a.is_false`×2 + `a.is_true`×2，另加 `a.report("llm")`）。核对方式：
   ```
   sed -n '165,199p' docs/.../2026-09-19-hp-magic-era-02-llm-narrative.md | grep -c '^\s*a\.'
   # → 9
   ```
   简报同时要求「**逐字用计划里的代码**」。两者冲突时以逐字为准，故未自行增删断言、未改 `assert.gd`。若确需 10 条，请指明要补的断言（例如给 `r2.ok` 加一条 `is_true`），可在 Task 3 扩充 `tests/llm_test.gd` 时一并处理。
2. **套件数措辞。** 简报称「14 套件失败=0（async_probe 在内）」；本任务前 `SUITES` 恰为 14 项，加入 `llm_test` 后运行器为 15 个套件。运行器汇总行实为 `失败套件=0`，已满足，无其它偏差。
