class_name LlmGameMaster
extends GameMaster

const MAX_ATTEMPTS := 2
const FALLBACK_NOTE := "（叙事引擎暂不可用，已用本地规则结算）"

var provider: LlmProvider = null
var fallback: GameMaster = null
var last_error: String = ""

func _init(provider_: LlmProvider = null, fallback_: GameMaster = null) -> void:
	provider = provider_
	fallback = fallback_

func act(world: WorldState, action_text: String) -> GmResult:
	if provider == null:
		return _fallback(world, action_text, "provider 未配置")
	var request := PromptBuilder.build(world, action_text)
	var response: LlmProvider.LlmResponse = null
	var parsed: GmResponseParser.Result = null
	for attempt in MAX_ATTEMPTS:
		response = await provider.complete(request)
		if response.ok:
			parsed = GmResponseParser.parse(response.text)
			if parsed.ok:
				break
			request = PromptBuilder.build_repair(world, action_text, parsed.error)
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

func _fallback(world: WorldState, action_text: String, reason: String) -> GmResult:
	last_error = reason
	if fallback == null:
		var r := GmResult.new()
		r.narration = "%s（原因：%s）" % [FALLBACK_NOTE, reason]
		return r
	var r2 := fallback.act(world, action_text)
	r2.narration = "%s %s" % [r2.narration, FALLBACK_NOTE]
	return r2
