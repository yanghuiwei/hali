class_name SelfCheck
extends RefCounted

const AUDIT_INTERVAL := 15

static func is_audit_turn(turn: int) -> bool:
	return turn > 0 and turn % AUDIT_INTERVAL == 0

static func report(_world: WorldState) -> String:
	return "【剧情快照】\n（自检报告将在任务 9 补全）\n【人设OOC自检报告】\n（自检报告将在任务 9 补全）"
