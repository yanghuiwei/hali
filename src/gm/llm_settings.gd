class_name LlmSettings
extends RefCounted

const DEFAULT_PATH := "user://llm_settings.json"

var provider := "openai_compat"
var base_url := ""
var model := ""
var api_key := ""
var temperature := 0.8
var max_tokens := 1024
var timeout_ms := 30000

static func load_from(path: String = DEFAULT_PATH) -> LlmSettings:
	var s := LlmSettings.new()
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			s._apply(parsed)
	var env_key := OS.get_environment("HALI_LLM_API_KEY")
	if not env_key.is_empty():
		s.api_key = env_key
	return s

func _apply(d: Dictionary) -> void:
	provider = str(d.get("provider", provider))
	base_url = str(d.get("base_url", base_url))
	model = str(d.get("model", model))
	api_key = str(d.get("api_key", api_key))
	temperature = float(d.get("temperature", temperature))
	max_tokens = int(d.get("max_tokens", max_tokens))
	timeout_ms = int(d.get("timeout_ms", timeout_ms))

func is_configured() -> bool:
	return not base_url.is_empty() and not model.is_empty() and not api_key.is_empty()

func save_to(path: String = DEFAULT_PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({
		"provider": provider, "base_url": base_url, "model": model, "api_key": api_key,
		"temperature": temperature, "max_tokens": max_tokens, "timeout_ms": timeout_ms,
	}, "\t"))
	f.close()
	return OK
