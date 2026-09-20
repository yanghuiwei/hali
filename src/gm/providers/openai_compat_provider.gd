class_name OpenAiCompatProvider
extends LlmProvider

var base_url := ""
var model := ""
var api_key := ""
var _host: Node = null
var _http: HTTPRequest = null

func _init(host: Node = null, base_url_: String = "", model_: String = "", api_key_: String = "") -> void:
	_host = host
	base_url = base_url_
	model = model_
	api_key = api_key_

static func from_settings(host: Node, settings: LlmSettings) -> OpenAiCompatProvider:
	return OpenAiCompatProvider.new(host, settings.base_url, settings.model, settings.api_key)

func _chat_url() -> String:
	var base := base_url.rstrip("/")
	if base.ends_with("/chat/completions"):
		return base
	return base + "/chat/completions"

func _build_headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json", "Authorization: Bearer %s" % api_key])

func _build_body(request: LlmProvider.LlmRequest) -> String:
	var body := {
		"model": model,
		"messages": [
			{"role": "system", "content": request.system_prompt},
			{"role": "user", "content": request.user_prompt},
		],
		"temperature": request.temperature,
		"max_tokens": request.max_tokens,
	}
	if request.json_mode:
		body["response_format"] = {"type": "json_object"}
	return JSON.stringify(body)

static func _parse_http(status: int, body: String) -> LlmProvider.LlmResponse:
	var r := LlmProvider.LlmResponse.new()
	r.http_status = status
	if status == 0:
		r.error = "请求未到达服务端（HTTP 状态 0：连接失败/超时中断）"
		return r
	if status < 200 or status >= 300:
		r.error = "HTTP %d（%s）" % [status, body.substr(0, 200)]
		return r
	var parsed = JSON.parse_string(body)
	if typeof(parsed) != TYPE_DICTIONARY:
		r.error = "响应不是合法 JSON"
		return r
	var choices = (parsed as Dictionary).get("choices", [])
	if typeof(choices) != TYPE_ARRAY or (choices as Array).is_empty():
		r.error = "响应缺少 choices"
		return r
	var first = (choices as Array)[0]
	if typeof(first) != TYPE_DICTIONARY:
		r.error = "响应 choices[0] 不是对象"
		return r
	var message = (first as Dictionary).get("message", {})
	if typeof(message) != TYPE_DICTIONARY:
		r.error = "响应缺少 message"
		return r
	var finish := str((first as Dictionary).get("finish_reason", ""))
	var raw_content = (message as Dictionary).get("content", "")
	# content 必须是字符串：JSON `null` / 数字 / 对象经 `str()` 会变成**非空串**（如 `<null>`），
	# 会让 ok 误判为 true，把垃圾文本送去解析并白烧一次重试（复审 M-b 实证）。
	r.text = raw_content if typeof(raw_content) == TYPE_STRING else ""
	r.ok = not r.text.is_empty()
	if not r.ok:
		# §8#67：区分「模型没吐内容」与「预算被思维链/截断耗尽」——否则两者错误串一样，无法定位
		r.error = "响应内容为空（finish_reason=%s%s）" % [
			finish if not finish.is_empty() else "未知",
			"；思考型模型需提高 max_tokens" if finish == "length" else "",
		]
	return r

func complete(request: LlmProvider.LlmRequest) -> LlmProvider.LlmResponse:
	if base_url.is_empty() or model.is_empty() or api_key.is_empty():
		var miss := LlmProvider.LlmResponse.new()
		miss.error = "provider 未配置"
		return miss
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = maxf(1.0, float(request.timeout_ms) / 1000.0)
		if _host != null:
			_host.add_child(_http)
	var started := Time.get_ticks_msec()
	var err := _http.request(_chat_url(), _build_headers(), HTTPClient.METHOD_POST, _build_body(request))
	if err != OK:
		var e := LlmProvider.LlmResponse.new()
		e.error = "请求发起失败（%d）" % err
		return e
	var result: Array = await _http.request_completed
	var status := int(result[1])
	var body := (result[3] as PackedByteArray).get_string_from_utf8()
	var resp := _parse_http(status, body)
	# 脱敏：错误串可能回显服务端 body，绝不能带出 api_key
	if not resp.ok and not api_key.is_empty():
		resp.error = resp.error.replace(api_key, "***")
	resp.latency_ms = Time.get_ticks_msec() - started
	return resp
