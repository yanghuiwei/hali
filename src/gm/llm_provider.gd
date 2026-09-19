class_name LlmProvider
extends RefCounted

class LlmRequest:
	var system_prompt: String = ""
	var user_prompt: String = ""
	var temperature: float = 0.8
	var max_tokens: int = 1024
	var timeout_ms: int = 30000
	var json_mode: bool = true

class LlmResponse:
	var ok: bool = false
	var text: String = ""
	var error: String = ""
	var http_status: int = 0
	var latency_ms: int = 0

# 可能是协程；调用方统一 `await provider.complete(req)`。
func complete(_request: LlmRequest) -> LlmResponse:
	var r := LlmResponse.new()
	r.error = "未实现的 provider"
	return r
