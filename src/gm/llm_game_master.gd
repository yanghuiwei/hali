class_name LlmGameMaster
extends GameMaster

const MAX_ATTEMPTS := 2
const FALLBACK_NOTE := "（叙事引擎暂不可用，已用本地规则结算）"

var provider: LlmProvider = null
var fallback: GameMaster = null
var last_error: String = ""
var settings: LlmSettings = null

func _init(provider_: LlmProvider = null, fallback_: GameMaster = null, settings_: LlmSettings = null) -> void:
	provider = provider_
	fallback = fallback_
	settings = settings_

# §8#66：`PromptBuilder` 造出的 request 带的是 `LlmProvider.LlmRequest` 的**类默认值**
# （0.8 / 1024 / 30000），若不在此处用 settings 覆盖，`user://llm_settings.json` 的
# `temperature` / `max_tokens` / `timeout_ms` 就永远不会进入真实请求（对思考型模型，
# `max_tokens=1024` 会把预算全用到思维链上，导致 `content` 恒空、每回合静默降级）。
func _apply_settings(req: LlmProvider.LlmRequest) -> LlmProvider.LlmRequest:
	if settings != null:
		req.temperature = settings.temperature
		req.max_tokens = settings.max_tokens
		req.timeout_ms = settings.timeout_ms
	return req

func act(world: WorldState, action_text: String) -> GmResult:
	if provider == null:
		return _fallback(world, action_text, "provider 未配置")
	var request := _apply_settings(PromptBuilder.build(world, action_text))
	var response: LlmProvider.LlmResponse = null
	var parsed: GmResponseParser.Result = null
	for attempt in MAX_ATTEMPTS:
		response = await provider.complete(request)
		if response.ok:
			parsed = GmResponseParser.parse(response.text)
			if parsed.ok:
				break
			request = _apply_settings(PromptBuilder.build_repair(world, action_text, parsed.error))
		else:
			parsed = null
	var reason := "未知错误"
	if response == null:
		reason = "无响应"
	elif not response.ok:
		reason = response.error
	elif parsed != null and not parsed.ok:
		reason = parsed.error
	if response == null or not response.ok or parsed == null or not parsed.ok:
		return _fallback(world, action_text, reason)
	var guard := OpGuard.sanitize_detailed(world, parsed.ops)
	var r := GmResult.new()
	r.narration = parsed.narration
	r.deltas = guard.ops
	r.tags = parsed.tags
	r.warnings = guard.warnings
	return r

# §8#65③：声明自己是协程实现，供 TurnEngine 做鸭子类型判定（不再依赖具体类型）。
func is_async() -> bool:
	return true

# §8#61：降级时**必须**把原因透出给调用方。原实现只把它写进 `last_error`（全仓只有声明与赋值、
# 没有读取者），玩家与调用方只能看到一句笼统的「暂不可用」，无法区分「网络抖动」与「模型不吐 JSON」。
# 现在两条分支都往 `warnings` 追加一条——`TurnEngine` 会把 warnings 并进 `op_errors`，UI 会打印。
# 有 fallback 时原因**不进叙事**（叙事仍由本地替身产出 + 一句降级说明），只走 warnings。
func _fallback(world: WorldState, action_text: String, reason: String) -> GmResult:
	last_error = reason
	if fallback == null:
		var r := GmResult.new()
		r.narration = "%s（原因：%s）" % [FALLBACK_NOTE, reason]
		r.warnings.append("LLM 降级：%s" % reason)
		return r
	var r2 := fallback.act(world, action_text)
	r2.narration = "%s %s" % [r2.narration, FALLBACK_NOTE]
	r2.warnings.append("LLM 降级：%s" % reason)
	return r2
