### Task 3: 玩家派系接口（`standing` + 三个 op + OpGuard + 存档校验）

**Files:**
- Modify: `src/model/player_state.gd`、`src/rules/state_ops.gd`、`src/gm/op_guard.gd`、`src/persist/save_codec.gd`
- Test: `tests/factions_test.gd`（追加）、`tests/save_test.gd`（追加）、`tests/gm_test.gd`（追加）、`tests/llm_test.gd`（追加）

**Interfaces:**
- Consumes: Task 2 的 `WorldFactions.state_of` / `initialize`；既有 `StateOps.apply(world, ops) -> PackedStringArray`。
- Produces:
  - `PlayerState.standing: Dictionary`（`faction_id -> int(-100..100)`）
  - `PlayerState.standing_of(faction_id: String) -> int`
  - `PlayerState.add_standing(faction_id: String, delta: int) -> int`（返回钳制后的新值）
  - op `join_faction` / `leave_faction` / `faction_standing_delta`（载荷见 spec §7.3）
  - `OpGuard.MAX_STANDING_DELTA := 20`
  - `world.flags["illegal_affiliation"]`（加入 outlaw 派系时写入派系 id）

- [ ] **Step 1: 写失败测试**

`tests/factions_test.gd` 的 `run()` 末尾（`return a.report` 之前）追加：

```gdscript
	# ---- 玩家立场与加入/退出（Task 3） ----
	var pw := make_world("modern")
	WorldFactions.initialize(pw)
	a.eq(pw.player.standing, {}, "初始无立场记录")
	a.eq(pw.player.standing_of("ministry"), 0, "未记录即 0")

	var errs := StateOps.apply(pw, [
		{"op": "join_faction", "faction_id": "不存在的派系"},
	])
	a.is_true(" | ".join(errs).contains("未知派系"), "加入未知派系被拒")
	a.eq(pw.player.faction_id, "", "被拒的加入不写状态")

	errs = StateOps.apply(pw, [{"op": "join_faction", "faction_id": "death_eaters"}])
	a.is_true(" | ".join(errs).contains("未揭示"), "未揭示的派系不能加入")
	a.eq(pw.player.faction_id, "", "未揭示派系的加入不写状态")

	errs = StateOps.apply(pw, [{"op": "join_faction", "faction_id": "ministry"}])
	a.eq(errs.size(), 0, "加入已揭示派系无错误")
	a.eq(pw.player.faction_id, "ministry", "所属写入")

	errs = StateOps.apply(pw, [{"op": "faction_standing_delta", "faction_id": "ministry", "delta": 500}])
	a.eq(errs.size(), 0, "立场调整无错误")
	a.eq(pw.player.standing_of("ministry"), 100, "立场钳到 100")
	a.is_true(int(WorldFactions.state_of(pw, "ministry").get("stance_to_player", 0)) > 0,
		"玩家立场反向影响派系对玩家的态度")

	errs = StateOps.apply(pw, [{"op": "leave_faction"}])
	a.eq(errs.size(), 0, "退出无错误")
	a.eq(pw.player.faction_id, "", "退出后无所属")
	a.eq(pw.player.standing_of("ministry"), 100, "退出不清立场")

	# outlaw 派系：先揭示才能加入；加入成功但要留痕（正典第五十章允许，代价留 03c）
	WorldFactions.ensure_state(pw, "death_eaters")["revealed"] = true
	errs = StateOps.apply(pw, [{"op": "join_faction", "faction_id": "death_eaters"}])
	a.eq(pw.player.faction_id, "death_eaters", "已揭示的 outlaw 派系可以加入")
	a.eq(str(pw.flags.get("illegal_affiliation", "")), "death_eaters", "非法所属被记录进 flags")
	a.is_true(" | ".join(errs).contains("非法"), "非法所属给出警告")
```

并在 `tests/save_test.gd` 的 `run()` 末尾（`return a.report("save")` 之前）追加：

```gdscript
	# ---- 计划 03a：standing 与 factions 必须往返一致 ----
	w.player.faction_id = "ministry"
	w.player.add_standing("ministry", 42)
	w.flags["government_type"] = "ministry_bureaucracy"
	var f_text := SaveCodec.encode(w)
	var f_back := SaveCodec.decode(f_text, reg)
	a.is_true(bool(f_back["ok"]), "含 standing 的存档可解码")
	var f_world: WorldState = f_back["world"]
	a.eq(f_world.player.faction_id, "ministry", "faction_id 往返一致")
	a.eq(f_world.player.standing_of("ministry"), 42, "standing 往返一致")
	a.eq(f_world.flags.get("government_type", ""), "ministry_bureaucracy", "政体缓存往返一致")
	a.eq(f_world.factions.size(), 17, "factions 往返一致（17 条）")
```

在 `tests/gm_test.gd` 的 `run()` 末尾（`return a.report("gm")` 之前）追加：

```gdscript
	# ---- 计划 03a：派系 op 的守卫与端到端 ----
	var fe := StateOps.apply(w, [{"op": "join_faction", "faction_id": "nope"}])
	a.is_true(" | ".join(fe).contains("未知派系"), "join_faction 未知 id 被拒")
	a.eq(w.player.faction_id, "", "被拒的加入不写状态")
	var fe2 := StateOps.apply(w, [{"op": "join_faction", "faction_id": "death_eaters"}])
	a.is_true(" | ".join(fe2).contains("未揭示"), "未揭示的派系不能加入（第四十三/五十七章）")
	var fe3 := StateOps.apply(w, [{"op": "join_faction", "faction_id": "ministry"}])
	a.eq(fe3.size(), 0, "加入公开派系无错误")
	a.eq(w.player.faction_id, "ministry", "所属写入")
	var fe4 := StateOps.apply(w, [{"op": "faction_standing_delta", "faction_id": "ministry", "delta": 5}])
	a.eq(fe4.size(), 0, "立场调整无错误")
	a.eq(w.player.standing_of("ministry"), 5, "立场累加")
	a.is_true(int(WorldFactions.state_of(w, "ministry").get("stance_to_player", 0)) > 0, "派系态度反向变化")
```

在 `tests/llm_test.gd` 的 OpGuard 用例区（`var gres := OpGuard.sanitize_detailed(gworld, [...])` 之后）追加：

```gdscript
	# ---- 计划 03a：OpGuard 只允许 LLM 动 membership/standing，不允许任何 set_faction_* ----
	var fguard := OpGuard.sanitize_detailed(gworld, [
		{"op": "join_faction", "faction_id": "ministry"},
		{"op": "faction_standing_delta", "faction_id": "ministry", "delta": 999},
		{"op": "set_faction_power", "faction_id": "ministry", "power": 1.0},
	])
	a.eq(fguard.ops[0]["op"], "join_faction", "join_faction 进入净化结果")
	a.eq(int(fguard.ops[1]["delta"]), OpGuard.MAX_STANDING_DELTA, "standing 增量被钳到上限")
	var faction_kinds := ""
	for o in fguard.ops:
		faction_kinds += str(o.get("op", "")) + ","
	a.is_true(faction_kinds.contains("set_faction_power"), "未知 set_faction_* 透传给 StateOps 拒绝，不静默丢弃")
	a.is_true(" | ".join(StateOps.apply(gworld, fguard.ops)).contains("未知操作"),
		"StateOps 最终拒绝 set_faction_power")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[save\]|^\[llm\]|总计"`
Expected: 上述断言出现失败（`join_faction` 未知 → `StateOps` 报「未知操作」）。

- [ ] **Step 3: 实现**

`src/model/player_state.gd`：

1) 字段区（`var faction_id: String = ""` 之后）加：

```gdscript
var standing: Dictionary = {}      # 计划 03a：faction_id -> 玩家立场/声望 -100..100
```

2) `to_dict()` 里 `"relations": relations, "faction_id": faction_id,` 改为：

```gdscript
		"relations": relations, "faction_id": faction_id, "standing": standing,
```

3) `from_dict()` 里 `p.faction_id = str(d.get("faction_id", ""))` 之后加：

```gdscript
	p.standing = JsonUtil.normalize(d.get("standing", {}))
```

4) 新方法（放在 `faction_id` 相关逻辑附近，例如 `knows_spell` 之前）：

```gdscript
const STANDING_MIN := -100
const STANDING_MAX := 100

func standing_of(faction_id: String) -> int:
	return clampi(int(standing.get(faction_id, 0)), STANDING_MIN, STANDING_MAX)

func add_standing(faction_id: String, delta: int) -> int:
	var value := clampi(standing_of(faction_id) + delta, STANDING_MIN, STANDING_MAX)
	standing[faction_id] = value
	return value
```

`src/rules/state_ops.gd`：在 `match op:` 里（`"relation_delta"` 之后）加三个分支：

```gdscript
			"join_faction":
				var join_id := str(raw.get("faction_id", ""))
				if not world.registry.has("factions", join_id):
					errors.append("未知派系: %s" % join_id)
				elif not WorldFactions.visible_faction_ids(world).has(join_id):
					errors.append("该派系尚未揭示，无法加入: %s" % join_id)
				else:
					world.player.faction_id = join_id
					if str(world.registry.entry("factions", join_id).get("legal_status", "legal")) == "outlaw":
						world.flags["illegal_affiliation"] = join_id
						errors.append("警告：加入非法组织（%s），法律后果留待后续结算" % join_id)
			"leave_faction":
				world.player.faction_id = ""
			"faction_standing_delta":
				var standing_id := str(raw.get("faction_id", ""))
				if not world.registry.has("factions", standing_id):
					errors.append("未知派系: %s" % standing_id)
				else:
					var raw_delta = raw.get("delta", 0)
					var delta := int(raw_delta) if (typeof(raw_delta) == TYPE_INT or typeof(raw_delta) == TYPE_FLOAT) else 0
					world.player.add_standing(standing_id, delta)
					var fstate := WorldFactions.ensure_state(world, standing_id)
					if not fstate.is_empty():
						fstate["stance_to_player"] = clampi(int(fstate.get("stance_to_player", 0)) + delta / 2, -100, 100)
```

`join_faction` 依赖 `WorldFactions.visible_faction_ids()`——**本任务直接把它实现成最终版**（Task 6 只在此基础上加 `reveal()`，不得重写它）：

```gdscript
# 信息保护（第四十三/五十七章）：只有 revealed 的派系对玩家可见。
static func visible_faction_ids(world: WorldState) -> PackedStringArray:
	var out := PackedStringArray()
	for fid in world.registry.ids("factions"):
		if bool(state_of(world, str(fid)).get("revealed", false)):
			out.append(str(fid))
	return out
```

`src/gm/op_guard.gd`：加常量与分支：

```gdscript
const MAX_STANDING_DELTA := 20
```

在 `match op:` 的 `"relation_delta"` 分支之后加：

```gdscript
			"join_faction", "leave_faction":
				if op == "join_faction":
					var fid := str(raw.get("faction_id", ""))
					if fid.is_empty():
						out.warnings.append("忽略缺 faction_id 的 join_faction")
						continue
					out.ops.append({"op": "join_faction", "faction_id": fid})
				else:
					out.ops.append({"op": "leave_faction"})
			"faction_standing_delta":
				var sid := str(raw.get("faction_id", ""))
				if sid.is_empty():
					out.warnings.append("忽略缺 faction_id 的 faction_standing_delta")
					continue
				out.ops.append({"op": "faction_standing_delta", "faction_id": sid,
					"delta": clampi(_to_int(raw.get("delta", 0)), -MAX_STANDING_DELTA, MAX_STANDING_DELTA)})
```

`src/persist/save_codec.gd`：`_validate_payload` 里，`player` 的嵌套校验新增一项（放在既有 `dict_fields` 检查之后）：

```gdscript
	# 计划 03a：player.standing 必须是对象（faction_id -> 整数）
	if parsed.has("player") and typeof(parsed["player"]) == TYPE_DICTIONARY:
		var p: Dictionary = parsed["player"]
		if p.has("standing") and typeof(p["standing"]) != TYPE_DICTIONARY:
			return "存档载荷字段类型错误：player.standing 应为对象"
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[save\]|^\[gm\]|^\[llm\]|总计|全部通过"`
Expected: 全部 `失败=0`，`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/model/player_state.gd src/rules/state_ops.gd src/gm/op_guard.gd src/persist/save_codec.gd src/rules/factions.gd tests/factions_test.gd tests/save_test.gd tests/gm_test.gd tests/llm_test.gd
git commit -m "feat(factions): 玩家所属/立场与加入退出 op + 守卫与存档校验（计划 03a Task 3）"
```

---

