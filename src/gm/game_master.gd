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
#
# §8#65①（计划 03a Task 11）：`act` **可以是同步函数，也可以是含 await 的协程**；
# 调用方统一写 `await gm.act(...)`（同步实现的 await 会立即拿到返回值）。
# 协程实现**必须**覆写 `is_async()` 返回 true，否则同步入口 `TurnEngine.submit()` 会把
# 协程对象当成 GmResult 送进结算（旧实现用 `gm is LlmGameMaster` 具体类型判断，换任何
# 其它协程 GM 就会崩）。
func act(_world: WorldState, _action_text: String) -> GmResult:
	var r := GmResult.new()
	r.narration = "（尚未接入叙事引擎）"
	return r

# 默认同步。协程实现（如 LlmGameMaster）覆写为 true。
func is_async() -> bool:
	return false
