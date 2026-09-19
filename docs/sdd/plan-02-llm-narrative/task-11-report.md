# Task 11 报告：UI 异步接线

## 结果
- 绿灯通过。全 16 套件失败=0（`==== 总计失败=0，失败套件=0 ====`）；主场景冒烟出现 `main scene ready, godot=4.7.2-stable (official)`；`全部通过。`；EXIT=0。
- 起点 `c87959e`（分支 `plan-02-llm-narrative`），交付提交 `15c1ff0`。
- 只改 `src/ui/main.gd`（硬性 #1）：1 文件，+13/−3。`tools/test.sh` 未改（计划标为可选；冒烟本就存在且仍绿）。

## 改动（逐字取计划 `### Task 11` Step 2）
1. 新增 `_build_gm()`（`src/ui/main.gd:206`，插在 `_personality_words` 与 `_append` 之间）：
```gdscript
func _build_gm() -> GameMaster:
	var settings := LlmSettings.load_from()
	if settings.is_configured():
		return LlmGameMaster.new(OpenAiCompatProvider.from_settings(self, settings), ScriptedGameMaster.new(rng))
	status_label.text = "（未配置 LLM，使用本地叙事替身；配置见 user://llm_settings.json）"
	return ScriptedGameMaster.new(rng)
```
2. `_on_start_pressed`：`engine = TurnEngine.new(world, ScriptedGameMaster.new(rng), rng)` → `engine = TurnEngine.new(world, _build_gm(), rng)`；`rng` 创建后传入同一实例共享，未变。
3. `_on_load`：`rng = RngService.new(world.game_seed)` 后同样改为 `engine = TurnEngine.new(world, _build_gm(), rng)`。
4. `_on_command_submitted` 改协程：`var result := engine.submit(text)` → 前置 `command_edit.editable = false`、`_append("（世界正在回应…）")`、`var result: Dictionary = await engine.submit_async(text)`；尾部 `command_edit.text = ""` 前补 `command_edit.editable = true`。其余打印逻辑（narration/events/op_errors/audit/status_line/清空输入）与「确认自检」短路分支逐字保留（通报顺序：`>>> text` → `（世界正在回应…）` → 结果）。

## Step 1：失败现象确认（实现前）
`grep -n "engine.submit" src/ui/main.gd` → 命中一行：`227: var result := engine.submit(text)`。同步 `submit()` 对 `LlmGameMaster` 会拿到协程对象而非结果（`turn_engine.gd:62` 亦以 `push_error("submit() 不能驱动 LlmGameMaster；请用 submit_async()")` 兜底），与计划预期一致，确认需要改异步。

## TDD / 验证说明
- 本任务是纯 UI 接线，计划未要求新增单测；回归面即既有 16 套件（`submit_async` 的引擎语义已由 Task 9 的 `gm` 套件覆盖：`[gm] 断言=63 失败=0`）。
- UI 协程路径无自动化用例：`_on_command_submitted` 依赖 `LineEdit.text_submitted` 与 `HTTPRequest`，headless 冒烟只验证场景 `_ready` 与脚本可解析。真实 LLM 端到端留待人工 GUI 验收（Task 10 报告同款残余项）。
- 静态校验：`_build_gm()` 返回类型 `GameMaster`，`LlmGameMaster`/`ScriptedGameMaster` 均 `extends GameMaster`；`main.gd` 在 `--import` 与冒烟（脚本加载）阶段无解析错误。

## 提交
- `15c1ff0` — `feat(ui): 回合异步接线与 LLM 配置提示`
- `git show --stat`：`src/ui/main.gd | 16 +++++++++++++---`，1 file changed, 13 insertions(+), 3 deletions(-)。未触碰其它文件。

## 验收核对（硬性 #2）
- `[gm]` 63/0、`[llm]` 61/0，全 16 套件失败=0。
- `main scene ready` 出现（`grep -q` 通过，冒烟非假绿）。
- `全部通过。`、EXIT=0。
- 提交信息与简报逐字一致；提交后即写本报告。

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
   ... (llm_test 负例 ×2 / _parse_http 负例 ×1，见下)
[llm] 断言=61 失败=0
[prompt] 断言=13 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

main scene ready, godot=4.7.2-stable (official)
全部通过。
```
> 说明：`[probe]` 为运行器自带「故意失败探针」，不计入套件；`save` 的 `SCRIPT ERROR` 与 `Parse JSON failed` 均为既有负路径用例的刻意日志（Task 10 报告已登记，本任务未新增日志），对应套件失败数均为 0。为控制篇幅，三条 `Parse JSON failed` 的 GDScript backtrace 已折叠（首条 llm_test.gd:60，第二条 llm_game_master.gd:24→llm_test.gd:122，第三条 openai_compat_provider.gd:48→llm_test.gd:182；与该提交前基线逐字相同）。

## 备注 / 观察（不阻塞）
- **残余风险（沿用 Task 9 登记）**：`submit_async()` 若内部 `await gm.act(...)` 永不恢复（provider 挂起且 `HTTPRequest.timeout` 未覆盖的边界），UI 会停在「世界正在回应…」且 `command_edit.editable=false`——输入被锁且无 UI 层看门狗。`LlmGameMaster` 有 2 次尝试 + 降级，`OpenAiCompatProvider` 设了 `HTTPRequest.timeout`（默认 30s），实际可恢复概率高；是否补 UI 层超时/「取消」按钮留待 Task 12 或计划 03 裁定。
- `_build_gm()` 未配置分支直接写 `status_label.text`（计划逐字要求）：创建/读档后该提示会覆盖标题行，直到首条指令结束才由 `PanelFormatter.status_line` 覆盖回来——可接受，属计划既定行为。
- `LlmSettings.load_from()` 每次开始/读档都读盘一次（`user://llm_settings.json` + `HALI_LLM_API_KEY`），无缓存也不在热路径，无需优化。
