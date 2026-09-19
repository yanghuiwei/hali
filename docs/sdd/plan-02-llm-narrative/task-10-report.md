# Task 10 报告：`OpenAiCompatProvider`

## 结果
- 绿灯通过。`[llm] 断言=61 失败=0`；全 16 套件失败=0；主场景 `main scene ready`；EXIT=0。
- 起点 `878e9e3`（分支 `plan-02-llm-narrative`），交付提交 `c87959e`。
- 实现/测试逐字取自计划 `docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md` `### Task 10` Step 3 / Step 1，无偏离；nested 类型统一写作 `LlmProvider.LlmRequest` / `LlmProvider.LlmResponse`（简报要求）。仅新增 provider + 追加 `tests/llm_test.gd`（硬性 #1）。

## 改动（3 文件，+109）
- `src/gm/providers/openai_compat_provider.gd`（新建，104 行）：`extends LlmProvider`。
  - 字段 `base_url/model/api_key/_host/_http`；`_init(host, base_url, model, api_key)`。
  - `static from_settings(host, settings)` 从 `LlmSettings` 取值构造。
  - `_chat_url()`：`rstrip("/")`，已含 `/chat/completions` 则原样，否则补 `/chat/completions`。
  - `_build_headers()`：`Content-Type: application/json` + `Authorization: Bearer <key>`。
  - `_build_body(req)`：`model/messages(system+user)/temperature/max_tokens`，`json_mode` 为真时加 `response_format={"type":"json_object"}`。
  - `static _parse_http(status, body)`：非 2xx → `error="HTTP <status>（<body 前 200 字符>）"`；非 JSON 字典 / 缺 choices / 缺 message / content 为空 → 对应错误；成功则填 `text` 且 `ok=true`。
  - `complete(req)`：未配置三要素则返回 `provider 未配置`；惰性创建 `HTTPRequest`（设 timeout，`_host` 非空时挂到场景树）；计时 → `request()` → `await request_completed` → 取 status/body → `_parse_http` → 填 `latency_ms`。
- `src/gm/providers/openai_compat_provider.gd.uid`（Godot 4.7 导入生成，随实现提交）。
- `tests/llm_test.gd`（`return a.report("llm")` 前，+15 行）：按计划 Step 1 追加 11 条纯函数断言（不联网）——URL 拼接、body 含 model/system 消息/json_mode、Authorization 头、2xx 解析成功与 content 取出、非 2xx 失败且错误含状态码、非 JSON 失败。

## TDD 记录
- **Red（实现前）**：用临时 worktree `git worktree add /tmp/hali-red 878e9e3`（起点，无 provider），仅拷入追加了新用例的 `tests/llm_test.gd`，`--import` 后跑 `run_tests.gd`：
```
SCRIPT ERROR: Parse Error: Identifier "OpenAiCompatProvider" not declared in the current scope.  # ×4
==== 总计失败=1，失败套件=1 ====
EXIT=1
```
  与计划 Step 2 预期一致（`OpenAiCompatProvider not declared`，EXIT=1）。worktree 已 `remove --force` 清理。
- **Green（实现后）**：见下完整输出，全绿 EXIT=0。

## 提交
- `c87959e` — `feat(gm): OpenAI 兼容 HTTP provider`
- `git show --stat`：`src/gm/providers/openai_compat_provider.gd | 104 ++++++`、`src/gm/providers/openai_compat_provider.gd.uid | 1 +`、`tests/llm_test.gd | 15 +-`，3 files changed, 109 insertions(+)。未触碰其它文件。

## 验收核对（硬性 #2/#3）
- `[llm]` 61/0（Task 9 基线为 51/0，本任务 +10 条断言；计划列 11 条中 `a.eq(p._chat_url(), ...)` 等，逐条通过）。
- 全 16 套件失败=0（`SUITES` 共 16 项；`[probe]` 是运行器自带的「故意失败探针」，不计入套件）。
- `main scene ready` 出现；EXIT=0。
- 提交信息与简报一致；提交后即写本报告。

## 测试原始输出（完整，含 EXIT）
命令：`bash tools/test.sh` → EXIT=0
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
[spell] 断言=229 失败=0
[gm] 断言=63 失败=0
[panel] 断言=71 失败=0
[selfcheck] 断言=32 失败=0
SCRIPT ERROR: Invalid assignment of property or key 'personality' with value of type 'int' on a base object of type 'RefCounted (PlayerState)'.
   at: from_dict (res://src/model/player_state.gd:97)
   GDScript backtrace (most recent call first):
       [0] from_dict (res://src/model/player_state.gd:97)
       [1] from_dict (res://src/model/world_state.gd:177)
       [2] decode (res://src/persist/save_codec.gd:81)
       [3] run (res://tests/save_test.gd:79)
       [4] _run_suite (res://tests/run_tests.gd:68)
       [5] _initialize (res://tests/run_tests.gd:36)
SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor.
   at: from_dict (res://src/core/game_clock.gd:10)
   GDScript backtrace (most recent call first):
       [0] from_dict (res://src/core/game_clock.gd:10)
       [1] from_dict (res://src/model/world_state.gd:176)
       [2] decode (res://src/persist/save_codec.gd:81)
       [3] run (res://tests/save_test.gd:79)
       [4] _run_suite (res://tests/run_tests.gd:68)
       [5] _initialize (res://tests/run_tests.gd:36)
[save] 断言=97 失败=0
[async_probe] 断言=2 失败=0
ERROR: Parse JSON failed. Error at line 0: Unexpected character
   at: parse_string (core/io/json.cpp:629)
   GDScript backtrace (most recent call first):
       [0] parse (res://src/gm/gm_response_parser.gd:20)
       [1] run (res://tests/llm_test.gd:60)
       [2] _run_suite (res://tests/run_tests.gd:68)
       [3] _initialize (res://tests/run_tests.gd:36)
       [4] _run_suite (res://tests/run_tests.gd:77)
       [5] run (res://tests/async_probe_test.gd:17)
       [6] async_double (res://tests/async_probe_test.gd:6)
ERROR: Parse JSON failed. Error at line 0: Unexpected character
   at: parse_string (core/io/json.cpp:629)
   GDScript backtrace (most recent call first):
       [0] parse (res://src/gm/gm_response_parser.gd:20)
       [1] act (res://src/gm/llm_game_master.gd:24)
       [2] run (res://tests/llm_test.gd:122)
       [3] _run_suite (res://tests/run_tests.gd:68)
       [4] _initialize (res://tests/run_tests.gd:36)
       [5] _run_suite (res://tests/run_tests.gd:77)
       [6] run (res://tests/async_probe_test.gd:17)
       [7] async_double (res://tests/async_probe_test.gd:6)
ERROR: Parse JSON failed. Error at line 0: Expected 'true', 'false', or 'null', got 'not'
   at: parse_string (core/io/json.cpp:629)
   GDScript backtrace (most recent call first):
       [0] _parse_http (res://src/gm/providers/openai_compat_provider.gd:48)
       [1] run (res://tests/llm_test.gd:182)
       [2] _run_suite (res://tests/run_tests.gd:68)
       [3] _initialize (res://tests/run_tests.gd:36)
       [4] _run_suite (res://tests/run_tests.gd:77)
       [5] run (res://tests/async_probe_test.gd:17)
       [6] async_double (res://tests/async_probe_test.gd:6)
[llm] 断言=61 失败=0
[prompt] 断言=13 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

main scene ready, godot=4.7.2-stable (official)
全部通过。
EXIT=0
```
> 说明：`[probe]` 为运行器自带「故意失败探针」，不计入套件；`save` 的 `SCRIPT ERROR` 是负路径坏档用例的刻意日志，其余两条 `Parse JSON failed` 是解析负例（含本任务新增的 `_parse_http(200,"not json")`），对应套件失败数均为 0。

## 备注 / 观察（不阻塞）
- 计划 Step 1 的 11 条断言全部收录；其中 `_parse_http` 的 choices 缺失/为空、message 缺失、content 为空等分支本任务未单列断言（计划未要求），实现已按计划逐字覆盖。
- `complete()` 的联网路径不在单测范围内（简报明确不联网）；协程部分依赖 `HTTPRequest`，其真实行为留待 Task 11 UI 接线时端到端验证。
- Provider 未做响应内容截断/JSON 修复：`text` 原样透传给 `GmResponseParser`（已支持 markdown 围栏与 4000 字截断），职责边界正确。
