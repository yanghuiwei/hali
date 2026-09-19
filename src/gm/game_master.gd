class_name GameMaster
extends RefCounted

class GmResult:
	var narration: String = ""
	var deltas: Array = []
	var tags: PackedStringArray = PackedStringArray()
	var warnings: PackedStringArray = PackedStringArray()
	var audit_required: bool = false

# 接口：计划 01 用 ScriptedGameMaster，计划 02 用 LlmGameMaster 替换。
# 实现者只描述发生了什么（叙事 + 状态增量），不直接改世界。
func act(_world: WorldState, _action_text: String) -> GmResult:
	var r := GmResult.new()
	r.narration = "（尚未接入叙事引擎）"
	return r
