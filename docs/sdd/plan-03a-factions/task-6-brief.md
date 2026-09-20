### Task 6: 信息保护 —— `reveal()` + 传闻揭示 + 派系传闻内容

**Files:**
- Modify: `src/rules/factions.gd`、`data/rumors.json`、`src/core/registry.gd`
- Test: `tests/factions_test.gd`、`tests/registry_test.gd`

**Interfaces:**
- Consumes: Task 3 的 `visible_faction_ids()`；既有 `world.add_fact(kind, text)`；Task 5 的 `apply_rumor_reveals` 预置位。
- Produces:
  - `static func reveal(world: WorldState, faction_id: String, source: String) -> bool`
  - `apply_rumor_reveals()` 填实（读 `ev["rumor_id"]` → `rumors` 表的 `reveals_faction` → `reveal()`）
  - `data/rumors.json` 新增可选字段 `reveals_faction`（至少 4 条）

- [ ] **Step 1: 写失败测试**

`tests/factions_test.gd` 末尾追加：

```gdscript
	# ---- 信息保护与揭示（Task 6） ----
	var rw := make_world("modern")
	WorldFactions.initialize(rw)
	a.is_false(WorldFactions.reveal(rw, "death_eaters", ""), "空来源不能揭示")
	a.is_false(WorldFactions.reveal(rw, "death_eaters", "system"), "system 来源不能揭示（第四十三/五十七章）")
	a.is_false(bool(WorldFactions.state_of(rw, "death_eaters")["revealed"]), "被拒的揭示不写状态")
	a.is_false(WorldFactions.reveal(rw, "不存在的派系", "破釜酒吧传闻"), "未知派系不能揭示")
	a.is_true(WorldFactions.reveal(rw, "death_eaters", "破釜酒吧传闻"), "合法来源可以揭示")
	a.is_true(bool(WorldFactions.state_of(rw, "death_eaters")["revealed"]), "揭示后 revealed=true")
	a.is_true(WorldFactions.visible_faction_ids(rw).has("death_eaters"), "揭示后进入可见列表")
	a.is_true(rw.history.size() >= 1, "揭示写入 history（可追溯）")
	a.is_false(WorldFactions.reveal(rw, "death_eaters", "破釜酒吧传闻"), "重复揭示返回 false（幂等）")
	a.is_false(WorldFactions.visible_faction_ids(rw).has("order_of_phoenix"), "未揭示派系不在可见列表")

	# 传闻揭示：只有带 reveals_faction 的传闻才揭示
	WorldFactions.apply_rumor_reveals(rw, [{"rumor_id": "不存在的传闻", "category": "政治", "text": "x"}])
	a.is_false(WorldFactions.visible_faction_ids(rw).has("order_of_phoenix"), "无 reveals_faction 的传闻不揭示")
	var rumor_with_reveal := ""
	for rid in rw.registry.ids("rumors"):
		var reveal_target := str(rw.registry.entry("rumors", str(rid)).get("reveals_faction", ""))
		if reveal_target.is_empty():
			continue
		if WorldFactions.visible_faction_ids(rw).has(reveal_target):
			continue
		if rumor_with_reveal.is_empty():
			rumor_with_reveal = str(rid)
	a.is_true(not rumor_with_reveal.is_empty(), "内容表里至少有一条带 reveals_faction 的未揭示传闻")
	if not rumor_with_reveal.is_empty():
		var target := str(rw.registry.entry("rumors", rumor_with_reveal).get("reveals_faction", ""))
		WorldFactions.apply_rumor_reveals(rw, [{"rumor_id": rumor_with_reveal, "category": "政治", "text": "传闻"}])
		a.is_true(WorldFactions.visible_faction_ids(rw).has(target), "被抽中的传闻揭示对应派系（%s）" % target)
```

`tests/registry_test.gd` 的派系段追加：

```gdscript
	var reveal_count := 0
	for rid in reg.ids("rumors"):
		var re := reg.entry("rumors", str(rid))
		var reveal_target := str(re.get("reveals_faction", ""))
		if not reveal_target.is_empty():
			reveal_count += 1
			a.is_true(reg.has("factions", reveal_target), "传闻 %s 的 reveals_faction 存在（%s）" % [str(rid), reveal_target])
	a.is_true(reveal_count >= 3, "至少 3 条传闻用于揭示派系（实际 %d）" % reveal_count)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[registry\]|总计"`
Expected: 失败（`reveal` 未定义；`reveals_faction` 计数为 0）。

- [ ] **Step 3: 实现**

`src/rules/factions.gd`：把 Task 5 的空实现替换为：

```gdscript
# 传闻揭示（第四十三/五十七章）：内容表里带 reveals_faction 的传闻被玩家听到时，该派系转为已知。
static func apply_rumor_reveals(world: WorldState, events: Array) -> void:
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var rumor_id := str((ev as Dictionary).get("rumor_id", ""))
		if rumor_id.is_empty():
			continue
		var entry := world.registry.entry("rumors", rumor_id)
		var target := str(entry.get("reveals_faction", ""))
		if target.is_empty():
			continue
		reveal(world, target, "传闻：%s" % str((ev as Dictionary).get("category", "街谈巷议")))
```

并追加（放在 `visible_faction_ids()` 附近）：

```gdscript
# 揭示一个派系。约束：来源必须非空且不是 system（与 StateOps.know_fact 同源，第四十三/五十七章）。
# 已揭示时返回 false（幂等），调用方可据此跳过重复叙事。
static func reveal(world: WorldState, faction_id: String, source: String) -> bool:
	var src := source.strip_edges()
	if src.is_empty() or src == "system":
		return false
	if not world.registry.has("factions", faction_id):
		return false
	var st := ensure_state(world, faction_id)
	if st.is_empty() or bool(st.get("revealed", false)):
		return false
	st["revealed"] = true
	st["last_change_turn"] = world.clock.turn
	world.add_fact("faction_revealed", "你得知了「%s」的存在（来源：%s）。" % [
		str(entry_of(world, faction_id).get("label", faction_id)), src])
	return true
```

`data/rumors.json`：追加 4 条（保留既有条目不动；`zones` 必须是 `data/locations.json` 里真实存在的地点 id；`major` 一律 false，避免抢重大事件配额）：

```json
  {"id": "rumor_malfoy_block", "category": "政治", "text": "听说几个古老姓氏在威森加摩里抱团，把持着席位不肯松手。", "zones": ["diagon_alley", "london_muggle"], "min_year": 0, "major": false, "reveals_faction": "sacred_twenty_eight"},
  {"id": "rumor_marked_ones", "category": "政治", "text": "有人在翻倒巷低声说，那些人又聚起来了，袖口下面有记号。", "zones": ["knockturn_alley", "diagon_alley"], "min_year": 0, "major": false, "reveals_faction": "death_eaters"},
  {"id": "rumor_phoenix_network", "category": "政治", "text": "有人提到一个不挂在魔法部名下的联络网：不问出身，只问你敢不敢站队。", "zones": ["hogsmeade", "london_muggle"], "min_year": 0, "major": false, "reveals_faction": "order_of_phoenix"},
  {"id": "rumor_continental_pureblood", "category": "政治", "text": "《预言家日报》角落里提到欧陆几家的联姻，说那才是真正的权力网络。", "zones": ["diagon_alley", "london_muggle"], "min_year": 0, "major": false, "reveals_faction": "continental_pureblood"}
```

`src/core/registry.gd` 的 `_validate_entry` 增加：

```gdscript
	if table_name == "rumors":
		if e.has("reveals_faction") and typeof(e["reveals_faction"]) != TYPE_STRING:
			errors.append("%s: reveals_faction 必须是字符串" % where)
```

`WorldFactions.validate_content()` 增加引用检查：

```gdscript
	for rid in registry.ids("rumors"):
		var target := str(registry.entry("rumors", str(rid)).get("reveals_faction", ""))
		if not target.is_empty() and not registry.has("factions", target):
			errors.append("rumors/%s: reveals_faction 引用不存在的派系（%s）" % [str(rid), target])
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[factions\]|^\[registry\]|^\[world_tick\]|总计|全部通过"`
Expected: 全部 `失败=0`；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/rules/factions.gd src/core/registry.gd data/rumors.json tests/factions_test.gd tests/registry_test.gd
git commit -m "feat(factions): 信息保护与传闻揭示（计划 03a Task 6）"
```

---

