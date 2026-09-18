class_name ClockTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()

	# 同一 seed 必须完全可复现（存档读档后世界必须继续一致）
	var r1 := RngService.new(20260918)
	var r2 := RngService.new(20260918)
	for i in 20:
		a.eq(r1.stream_int("world", 0, 1000), r2.stream_int("world", 0, 1000), "同种子同流第 %d 次" % i)

	# 不同 seed 应产生不同序列
	var r3 := RngService.new(1)
	var r4 := RngService.new(2)
	var differs := false
	for i in 20:
		if r3.stream_int("world", 0, 1000000) != r4.stream_int("world", 0, 1000000):
			differs = true
	a.is_true(differs, "不同种子产生不同序列")

	# 命名流互不干扰：抽 A 不影响 B 的首个值
	var r5 := RngService.new(7)
	var r6 := RngService.new(7)
	var first_b_5: int = r5.stream("b").randi_range(0, 100000)
	for i in 30:
		r6.stream("a").randf()
	a.eq(r6.stream("b").randi_range(0, 100000), first_b_5, "抽 a 流不影响 b 流")

	# 概率边界
	a.is_false(RngService.new(5).chance("x", 0.0), "概率 0 必失败")
	a.is_true(RngService.new(5).chance("x", 1.0), "概率 1 必成功")

	# stream_pick 边界
	var picker := RngService.new(9)
	a.eq(picker.stream_pick("p", []), null, "空数组返回 null")
	a.eq(picker.stream_pick("p", ["只有一个"]), "只有一个", "单元素数组")

	# 存档恢复随机流：状态可持久化并续跑一致
	var r7 := RngService.new(42)
	for i in 5:
		r7.stream_float("world")
	var snapshot := r7.state_dict()
	var next_a := r7.stream_int("world", 0, 999999)
	var r8 := RngService.new(42)
	r8.load_state(snapshot)
	a.eq(r8.stream_int("world", 0, 999999), next_a, "恢复后继续抽同一随机数")
	a.eq(JSON.stringify(snapshot).length() > 0, true, "随机状态可 JSON 序列化")

	return a.report("clock")
