class_name MockLlmProvider
extends LlmProvider

var queue: Array[String] = []
var errors: Array[String] = []
var requests: Array = []

func complete(request: LlmProvider.LlmRequest) -> LlmProvider.LlmResponse:
	requests.append(request)
	var index := requests.size() - 1
	var r := LlmProvider.LlmResponse.new()
	if index < errors.size() and not str(errors[index]).is_empty():
		r.error = str(errors[index])
		return r
	if index < queue.size():
		r.ok = true
		r.text = str(queue[index])
		return r
	r.error = "mock 队列为空"
	return r
