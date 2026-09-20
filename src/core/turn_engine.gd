class_name TurnEngine
extends RefCounted

var world: WorldState = null
var gm: GameMaster = null
var rng: RngService = null

func _init(world_: WorldState, gm_: GameMaster, rng_: RngService) -> void:
	world = world_
	gm = gm_
	rng = rng_
	if world.rng_state.size() > 0:
		rng.load_state(world.rng_state)

func acknowledge_audit() -> void:
	world.flags.erase("awaiting_audit_ack")

# 一个回合 = 一个月：玩家行动 → 世界结算 → 必要时强制自检。
func _blank_result() -> Dictionary:
	return {"narration": "", "deltas_applied": [], "op_errors": PackedStringArray(),
		"events": [], "audit": "", "blocked": false}

# 死亡 / 自检挂起守卫；true 表示可继续。
func _pre_submit(out: Dictionary) -> bool:
	# 死亡真实且不可逆（第五十三章）
	if not world.player.alive:
		out["blocked"] = true
		out["narration"] = "你已经死了。死亡默认真实且不可逆。请切换到继承人或读取存档。"
		return false
	# 第七十二章：自检未确认前禁止续写剧情
	if bool(world.flags.get("awaiting_audit_ack", false)):
		out["blocked"] = true
		out["narration"] = "上一轮自检尚未确认。请先阅读【剧情快照】与【人设OOC自检报告】，然后确认自检。"
		return false
	return true

func _resolve(out: Dictionary, result: GameMaster.GmResult) -> Dictionary:
	var errors := StateOps.apply(world, result.deltas)
	for warning in result.warnings:
		errors.append(str(warning))
	out["narration"] = result.narration
	out["deltas_applied"] = result.deltas
	out["op_errors"] = errors

	# 第四十七章：世界不会停下来等待玩家
	var events := world.tick()
	out["events"] = events
	world.rng_state = rng.state_dict()

	if SelfCheck.is_audit_turn(world.clock.turn):
		out["audit"] = SelfCheck.report(world)
		world.flags["awaiting_audit_ack"] = true

	return out

# 同步：仅供 ScriptedGameMaster / 既有测试。
func submit(action_text: String) -> Dictionary:
	var out := _blank_result()
	if not _pre_submit(out):
		return out
	# §8#65③：用鸭子类型判定（is_async()）而不是 `gm is LlmGameMaster`——后者只认一个具体类，
	# 换任何「协程 act」的实现都会把协程对象送进 _resolve 而崩；且拒绝时原来 narration 为空，UI 白屏。
	if gm.is_async():
		push_error("submit() 不能驱动协程 GM；请用 submit_async()")
		out["blocked"] = true
		out["narration"] = "本模块需要异步回合（请走 submit_async 路径）；本回合未结算。"
		return out
	return _resolve(out, gm.act(world, action_text))

# 异步：正式路径。
func submit_async(action_text: String) -> Dictionary:
	var out := _blank_result()
	if not _pre_submit(out):
		return out
	var result = await gm.act(world, action_text)
	return _resolve(out, result)
