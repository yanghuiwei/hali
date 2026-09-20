### Task 10: 顺手项 A —— UI 等待期看门狗（`§8#58`）、提交失败恢复（`§8#62`）、provider 复用与 timeout（`§8#63`）

**Files:**
- Modify: `src/ui/main.gd`、`src/gm/providers/openai_compat_provider.gd`
- Test: `tests/llm_test.gd`（provider 部分）、`tools/b1_acceptance.gd`（UI 看门狗部分）

**Interfaces:**
- Produces（provider）：
  - `OpenAiCompatProvider.ensure_http(timeout_ms: int) -> HTTPRequest`（懒建一次，之后复用）
  - `OpenAiCompatProvider.http_timeout_sec() -> float`
  - `OpenAiCompatProvider.dispose() -> void`（释放 `HTTPRequest` 节点）
  - `static OpenAiCompatProvider.mask(text: String, api_key: String) -> String`（脱敏，`complete()` 与测试共用）
- Produces（UI）：
  - `main.gd` 新字段 `var turn_timeout_sec: float = 180.0`（可被环境变量 `HALI_TURN_TIMEOUT_SEC` 覆盖）
  - `main.gd` 新方法 `_run_turn(text)`、`_render_turn_result(result)`、`_turn_state` 字典
  - 行为：等待期置灰；**无论 `await` 链是否抛错**，最多 `turn_timeout_sec` 秒后一定恢复输入与按钮，并提示已恢复

- [ ] **Step 1: 写失败测试**

在 `tests/llm_test.gd` 的 provider 段追加：

```gdscript
	# ---- 计划 03a（§8#63）：HTTPRequest 复用、timeout 每请求更新、dispose 不泄漏 ----
	var host := Node.new()
	Engine.get_main_loop().root.add_child(host)
	var prov := OpenAiCompatProvider.new(host, "https://example.invalid/v1", "m", "k")
	prov.ensure_http(30000)
	a.eq(host.get_child_count(), 1, "懒建一个 HTTPRequest")
	prov.ensure_http(60000)
	a.eq(host.get_child_count(), 1, "第二次不重复建（不泄漏）")
	a.near(prov.http_timeout_sec(), 60.0, 0.001, "timeout 每次请求都更新（不再只生效一次）")
	prov.dispose()
	await Engine.get_main_loop().process_frame
	a.eq(host.get_child_count(), 0, "dispose 释放节点")

	# ---- 计划 03a（§8#64③）：错误串脱敏的负向断言 ----
	var masked := OpenAiCompatProvider.mask("HTTP 401（boom sk-secret end）", "sk-secret")
	a.is_false(masked.contains("sk-secret"), "脱敏后不含 api_key")
	a.is_true(masked.contains("***"), "脱敏后出现掩码")
	a.eq(OpenAiCompatProvider.mask("nothing", ""), "nothing", "空 key 不替换")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[llm\]|总计"`
Expected: 失败（`ensure_http`/`dispose`/`mask` 未定义）。

- [ ] **Step 3: 实现**

`src/gm/providers/openai_compat_provider.gd`：

1) 把 `complete()` 里建节点的两行换成：

```gdscript
	ensure_http(request.timeout_ms)
```

2) 把 `complete()` 末尾的脱敏改为：

```gdscript
	if not resp.ok:
		resp.error = mask(resp.error, api_key)
```

3) 加方法：

```gdscript
# §8#63：懒建一次并复用；timeout 每次请求都重新设（旧实现只在建节点时设一次）。
func ensure_http(timeout_ms: int) -> HTTPRequest:
	if _http == null:
		_http = HTTPRequest.new()
		if _host != null:
			_host.add_child(_http)
	_http.timeout = maxf(1.0, float(timeout_ms) / 1000.0)
	return _http

func http_timeout_sec() -> float:
	return _http.timeout if _http != null else 0.0

# §8#63：每次「开始人生」/「读档」都会重建 provider，旧 provider 的 HTTPRequest 必须释放。
func dispose() -> void:
	if _http != null:
		if _http.get_parent() != null:
			_http.get_parent().remove_child(_http)
		_http.queue_free()
		_http = null

# 错误串可能回显服务端 body，绝不能带出 api_key（§8#64③）
static func mask(text: String, api_key: String) -> String:
	if api_key.is_empty():
		return text
	return text.replace(api_key, "***")
```

`src/ui/main.gd`：

1) 字段区加：

```gdscript
var turn_timeout_sec: float = 180.0
var _turn_state: Dictionary = {}
var _llm_provider: OpenAiCompatProvider = null
```

2) `_ready()` 里（`_debug_mirror = DebugMirror.from_env()` 之后）加：

```gdscript
	var env_timeout := OS.get_environment("HALI_TURN_TIMEOUT_SEC")
	if not env_timeout.is_empty() and env_timeout.is_valid_float():
		turn_timeout_sec = maxf(0.1, env_timeout.to_float())
```

3) 用下列版本替换整个 `_on_command_submitted()`（原来的叙事/事件/错误/自检渲染搬进 `_render_turn_result()`，**恢复出口只剩一处**）：

```gdscript
func _on_command_submitted(text: String) -> void:
	if world == null:
		return
	# 第七十二章：自检后必须等玩家确认，才允许继续叙事
	if text.strip_edges() == "确认自检":
		if engine != null:
			engine.acknowledge_audit()
		_append("（自检已确认。世界继续向前。）")
		command_edit.text = ""
		return
	_set_input_enabled(false)
	_set_buttons_enabled(false)
	_append(">>> %s" % text)
	_append("（世界正在回应…）")
	# §8#58/#62：把等待变成「有上限的等待」。GDScript 的 await 链一旦在内部抛错，调用方永远不会
	# 被唤醒（无 try/catch），旧实现会把输入框与整排按钮永久留在禁用态。看门狗保证恢复出口一定会走到。
	_turn_state = {"done": false, "result": {}}
	_run_turn(text)
	var deadline := Time.get_ticks_msec() + int(maxf(turn_timeout_sec, 0.1) * 1000.0)
	while not bool(_turn_state.get("done", false)) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not bool(_turn_state.get("done", false)):
		_append("（本回合超过 %.0f 秒仍未返回，已恢复输入。请求可能仍在后台；若反复发生，请检查 LLM 配置或改用本地替身。）" % turn_timeout_sec)
	else:
		_render_turn_result(_turn_state["result"])
	_set_status(PanelFormatter.status_line(world) + " ｜ 回合 %d" % world.clock.turn)
	_set_buttons_enabled(true)
	_set_input_enabled(true)
	command_edit.text = ""

# 单独的协程：它的失败不会阻止 _on_command_submitted 的看门狗循环（§8#62）
func _run_turn(text: String) -> void:
	_turn_state["result"] = await engine.submit_async(text)
	_turn_state["done"] = true

func _render_turn_result(result: Dictionary) -> void:
	_append(str(result["narration"]))
	var events: Array = result["events"]
	if not events.is_empty():
		_append(PanelFormatter.events_block(events))
	for err in (result["op_errors"] as PackedStringArray):
		_append("（系统提示：%s）" % str(err))
	if str(result["audit"]) != "":
		_append(str(result["audit"]))
		_append("（自检完毕。等待你的指令——输入“确认自检”继续。）")
```

4) `_build_gm()` 里在 new provider 之前释放旧的：

```gdscript
func _build_gm() -> GameMaster:
	if _llm_provider != null:
		_llm_provider.dispose()      # §8#63：避免每切一次生命周期泄漏一个 HTTPRequest
		_llm_provider = null
	var settings := LlmSettings.load_from()
	if settings.is_configured():
		_llm_provider = OpenAiCompatProvider.from_settings(self, settings)
		return LlmGameMaster.new(_llm_provider, ScriptedGameMaster.new(rng), settings)
	_set_status(status_label.text + "（未配置 LLM，使用本地叙事替身；配置见 user://llm_settings.json）")
	return ScriptedGameMaster.new(rng)
```

5) 在 `tools/b1_acceptance.gd` 末尾（`_verify_restored()` 之前）加一个盘验区块与一个 hang provider：

```gdscript
# 永不返回的 provider：用于验证等待期看门狗（§8#58/#62）
class HangProvider extends LlmProvider:
	func complete(_request: LlmProvider.LlmRequest) -> LlmProvider.LlmResponse:
		await Engine.get_main_loop().create_timer(3600.0).timeout
		return LlmProvider.LlmResponse.new()
```

```gdscript
func _part11_watchdog(node: Node) -> void:
	part("计划 03a 顺手项 · 等待期看门狗（§8#58/#62）")
	node.set("turn_timeout_sec", 0.4)
	var hang_gm := LlmGameMaster.new(HangProvider.new(), ScriptedGameMaster.new(RngService.new(11)), null)
	node.set("engine", TurnEngine.new(_world(node), hang_gm, node.get("rng")))
	var before := _log_len(node)
	await node.call("_on_command_submitted", "我要练习魔药学")
	var block := _log_of(node).substr(before)
	check(block.contains("已恢复输入"), "超时后给出恢复提示")
	check((node.get("command_edit") as LineEdit).editable, "超时后输入框恢复")
	check(_buttons_all(node, false), "超时后整排按钮恢复")
```

并在 `_initialize()` 的 `await _part9_waiting_gate(restarted)` 之后插入 `await _part11_watchdog(restarted)`。

- [ ] **Step 4: 验证**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[llm\]|总计|全部通过" && bash tools/b1_acceptance.sh 2>&1 | grep -E "看门狗|\[PASS\]|\[FAIL\]|断言" | tail -20`
Expected: `[llm]` 失败=0、`全部通过。`；B1 盘验里看门狗三条均为 `[PASS]`，且总失败数为 0。

- [ ] **Step 5: 提交**

```bash
git add src/ui/main.gd src/gm/providers/openai_compat_provider.gd tests/llm_test.gd tools/b1_acceptance.gd
git commit -m "fix(ui,gm): 等待期看门狗 + 提交恢复唯一出口 + provider 复用（§8#58/#62/#63）（计划 03a Task 10）"
```

---

