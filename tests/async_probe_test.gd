class_name AsyncProbeTest
extends RefCounted

static func async_double(x: int) -> int:
	await Engine.get_main_loop().process_frame
	return x * 2

static func sync_seven() -> int:
	return 7

func run() -> int:
	var a := TestAssert.new()
	var v = await async_double(21)
	a.eq(v, 42, "await 协程返回最终值")
	var sync_val = await sync_seven()
	a.eq(sync_val, 7, "await 普通函数返回值直接返回")
	return a.report("async_probe")
