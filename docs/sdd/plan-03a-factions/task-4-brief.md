### Task 4: `WorldFactions.evolve()` —— 实力/控制权演化 + 政体刷新

**Files:**
- Modify: `src/rules/factions.gd`
- Test: `tests/factions_test.gd`

**Interfaces:**
- Consumes: Task 2 的 `initialize/ensure_state/state_of/power_of/base_power/power_share/institution_control/government_type`；`RngService`。
- Produces:
  - `static func evolve(world: WorldState) -> Array`（本任务恒返回空数组；Task 5 让它产出事件）
  - 常量 `EVOLVE_REGRESSION := 0.04`、`EVOLVE_NOISE := 0.02`、`SUPPRESS_RATE := 0.03`、`SUPPRESS_FLOOR := 0.05`
  - `static func structure_pull(world: WorldState, faction_id: String) -> float`、`static func apply_rival_pressure(world: WorldState) -> void`
  - 副作用：更新 `world.factions[*].power` / `.control[*]` / `.last_change_turn`，写 `world.flags[GOVERNMENT_FLAG]`

- [ ] **Step 1: 写失败测试**

在 `tests/factions_test.gd` 的 `run()` 末尾（`return a.report("factions")` 之前）追加：

```gdscript
	# ---- 演化：确定性、结构拉力、政体缓存（Task 4） ----
	var e1 := make_world("modern")
	var e2 := make_world("modern")
	WorldFactions.initialize(e1)
	WorldFactions.initialize(e2)
	for i in 3:
		WorldFactions.evolve(e1)
		WorldFactions.evolve(e2)
	for fid in e1.registry.ids("factions"):
		a.near(WorldFactions.power_of(e1, str(fid)), WorldFactions.power_of(e2, str(fid)), 0.0000001,
			"%s 实力演化可复现（同 seed）" % str(fid))
	a.eq(str(e1.flags.get(WorldFactions.GOVERNMENT_FLAG, "")), WorldFactions.government_type(e1),
		"演化后政体缓存与本回合推导一致")
	a.is_true(e1.registry.has("governments", str(e1.flags[WorldFactions.GOVERNMENT_FLAG])),
		"政体缓存 id 在内容表里存在")

	# 结构拉力：战争/腐败推高黑暗势力与抵抗组织，压低魔法部目标值
	var hawk := make_world("modern")
	hawk.world_vars["war_pressure"] = 0.9
	hawk.world_vars["corruption"] = 0.8
	var dove := make_world("modern")
	dove.world_vars["war_pressure"] = 0.05
	dove.world_vars["corruption"] = 0.05
	a.is_true(WorldFactions.structure_pull(hawk, "death_eaters") > WorldFactions.structure_pull(dove, "death_eaters"),
		"战争与腐败推高黑暗势力")
	a.is_true(WorldFactions.structure_pull(hawk, "order_of_phoenix") > WorldFactions.structure_pull(dove, "order_of_phoenix"),
		"战争推高抵抗组织")
	a.is_true(WorldFactions.structure_pull(hawk, "ministry") < WorldFactions.structure_pull(dove, "ministry"),
		"腐败压低魔法部")

	# 敌对压制：强的一方压低弱的一方，但不会归零
	var press := make_world("modern")
	WorldFactions.initialize(press)
	WorldFactions.ensure_state(press, "ministry")["power"] = 0.95
	WorldFactions.ensure_state(press, "death_eaters")["power"] = 0.60
	var before_weak := WorldFactions.power_of(press, "death_eaters")
	WorldFactions.evolve(press)
	a.is_true(WorldFactions.power_of(press, "death_eaters") < before_weak, "敌对强者压制弱者")
	a.is_true(WorldFactions.power_of(press, "death_eaters") >= WorldFactions.SUPPRESS_FLOOR - 0.0001,
		"压制有下限，不会归零")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|总计"`
Expected: 失败（`evolve`/`structure_pull` 未定义 → 套件未 report）。

- [ ] **Step 3: 实现**

在 `src/rules/factions.gd` 追加：

```gdscript
# ---------- 月度演化（第十二/四十六/四十七/四十九章） ----------

const EVOLVE_REGRESSION := 0.04   # 每月向「目标实力」回归的比例
const EVOLVE_NOISE := 0.02        # ±0.02 扰动
const SUPPRESS_RATE := 0.03       # 敌对压制：每月按实力差比例削弱败者
const SUPPRESS_FLOOR := 0.05      # 弱者的实力下限

# 结构性拉力：世界变量如何推动某类派系（正典第十二/十七/四十九章的定性关系）
static func structure_pull(world: WorldState, faction_id: String) -> float:
	var kind := str(entry_of(world, faction_id).get("kind", ""))
	var v := world.world_vars
	match kind:
		"ministry":
			return float(v.get("ministry_stability", 0.5)) * 0.10 - float(v.get("corruption", 0.3)) * 0.20
		"institution":
			return float(v.get("ministry_stability", 0.5)) * 0.05
		"pureblood":
			return float(v.get("pureblood_influence", 0.3)) * 0.15
		"dark":
			return float(v.get("war_pressure", 0.2)) * 0.30 + float(v.get("corruption", 0.3)) * 0.10
		"resistance":
			return float(v.get("war_pressure", 0.2)) * 0.25
		"commerce", "media":
			return (float(v.get("economy_index", 0.6)) - 0.5) * 0.20
		"foreign":
			return float(v.get("muggle_relations", 0.5)) * 0.10
		"school":
			return float(v.get("secrecy_integrity", 0.8)) * 0.10
		_:
			return 0.0

# 敌对压制：对每一对 rivals（按 id 排序只算一次），强者压低弱者、自己小幅获益
static func apply_rival_pressure(world: WorldState) -> void:
	for fid in world.registry.ids("factions"):
		var id := str(fid)
		for other in (entry_of(world, id).get("rivals", []) as Array):
			var oid := str(other)
			if oid <= id:
				continue
			var pa := power_of(world, id)
			var pb := power_of(world, oid)
			if is_equal_approx(pa, pb):
				continue
			var winner := id if pa > pb else oid
			var loser := oid if pa > pb else id
			var gap := absf(pa - pb)
			var loser_state := ensure_state(world, loser)
			if not loser_state.is_empty():
				var floor := maxf(SUPPRESS_FLOOR, base_power(world, loser) * 0.25)
				loser_state["power"] = clampf(float(loser_state["power"]) - SUPPRESS_RATE * gap, floor, 1.0)
			var winner_state := ensure_state(world, winner)
			if not winner_state.is_empty():
				winner_state["power"] = clampf(float(winner_state["power"]) + SUPPRESS_RATE * gap * 0.5, 0.0, 1.0)

# 单回合演化：就地更新 world.factions / world.flags，返回事件数组（结构与 tick 的 events 一致）
static func evolve(world: WorldState) -> Array:
	initialize(world)
	var rng := RngService.new(world.game_seed + world.clock.turn * 31337)
	for fid in world.registry.ids("factions"):
		var id := str(fid)
		var st := ensure_state(world, id)
		if st.is_empty():
			continue
		var target := clampf(base_power(world, id) + structure_pull(world, id), 0.0, 1.0)
		var current := clampf(float(st.get("power", target)), 0.0, 1.0)
		var noise := rng.stream_float("faction_%s" % id) * (EVOLVE_NOISE * 2.0) - EVOLVE_NOISE
		var next := clampf(current + (target - current) * EVOLVE_REGRESSION + noise, 0.0, 1.0)
		if not is_equal_approx(next, current):
			st["last_change_turn"] = world.clock.turn
		st["power"] = next
		var control: Dictionary = st.get("control", {})
		for inst in control.keys():
			control[inst] = clampf(float(control[inst]) + (next - float(control[inst])) * 0.5, 0.0, 1.0)
	apply_rival_pressure(world)
	world.flags[GOVERNMENT_FLAG] = government_type(world)
	return []
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|总计|全部通过"`
Expected: `[factions] 断言=... 失败=0`；`全部通过。`

**反证实验（spec §9.4 要求，必须贴进报告）**：把 `apply_rival_pressure()` 的调用在 `evolve()` 里注释掉，重跑 —— 「敌对强者压制弱者」那条断言必须变红；恢复后重跑变绿。把两段原始输出都贴进报告，否则视为假绿。

- [ ] **Step 5: 提交**

```bash
git add src/rules/factions.gd tests/factions_test.gd
git commit -m "feat(factions): 派系实力/控制权演化与政体刷新（计划 03a Task 4）"
```

---

