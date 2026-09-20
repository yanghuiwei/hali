### Task 9: 玩家动作接线（离线替身的关键词 → 派系 op）

**Files:**
- Modify: `src/gm/scripted_game_master.gd`
- Test: `tests/gm_test.gd`

**Interfaces:**
- Consumes: `WorldFactions.visible_faction_ids`；Task 3 的三个 op。
- Produces: `ScriptedGameMaster._detect_faction(world, text) -> String`；四个关键词组常量 `FACTION_JOIN/FACTION_LEAVE/FACTION_SUPPORT/FACTION_OPPOSE`。
- 语义：只有**已揭示**派系才能被说出（未揭示的就当玩家不知道）；识别到派系且命中关键词才产出 op，否则**不提前 return**（继续走原有的练习/打工/社交/休息/施法分支）。

- [ ] **Step 1: 写失败测试**

在 `tests/gm_test.gd` 的 `run()` 末尾（`return a.report("gm")` 之前）追加：

```gdscript
	# ---- 计划 03a：离线替身也支持派系动作（Task 9） ----
	var sw := make_world()
	WorldFactions.initialize(sw)
	var sg := ScriptedGameMaster.new(RngService.new(7))

	var join_res := sg.act(sw, "我要加入魔法部")
	var joined := false
	for d in join_res.deltas:
		if str(d.get("op", "")) == "join_faction" and str(d.get("faction_id", "")) == "ministry":
			joined = true
	a.is_true(joined, "关键词「加入魔法部」产出 join_faction")
	StateOps.apply(sw, join_res.deltas)
	a.eq(sw.player.faction_id, "ministry", "端到端：所属写入")

	var support_res := sg.act(sw, "我公开支持魔法部")
	var standing_op := false
	for d in support_res.deltas:
		if str(d.get("op", "")) == "faction_standing_delta":
			standing_op = true
	a.is_true(standing_op, "关键词「支持」产出 faction_standing_delta")
	var oppose_res := sg.act(sw, "我要抗议魔法部")
	var negative := false
	for d in oppose_res.deltas:
		if str(d.get("op", "")) == "faction_standing_delta" and int(d.get("delta", 0)) < 0:
			negative = true
	a.is_true(negative, "关键词「抗议」产出负向立场")

	# 未揭示的派系：玩家说“加入食死徒”不应该凭空产出 op（第四十三/五十七章）
	var hidden_res := sg.act(sw, "我要加入食死徒")
	a.eq(hidden_res.deltas.size(), 0, "未揭示派系的动作不产出任何 op")

	# 不抢原有分支：普通动作仍走原语义
	var work_res := sg.act(sw, "我去对角巷打工赚钱")
	a.eq(str(work_res.tags[0]), "work", "派系分支不影响打工识别")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[gm\]|总计"`
Expected: 失败（「加入魔法部」目前落到 idle，`deltas` 为空）。

- [ ] **Step 3: 实现**

在 `src/gm/scripted_game_master.gd` 的常量区加：

```gdscript
const FACTION_JOIN: Array[String] = ["加入", "投靠", "效力", "为…做事", "入伙"]
const FACTION_LEAVE: Array[String] = ["退出", "脱离", "叛出", "不再属于"]
const FACTION_SUPPORT: Array[String] = ["支持", "拥护", "声援", "捐款", "赞助"]
const FACTION_OPPOSE: Array[String] = ["反对", "抗议", "抨击", "揭露", "抵制"]
```

加方法：

```gdscript
# 计划 03a：识别玩家嘴里提到的“已揭示”派系（label 或 aliases）。未揭示的一律识别为空。
func _detect_faction(world: WorldState, text: String) -> String:
	for fid in WorldFactions.visible_faction_ids(world):
		var id := str(fid)
		var entry := world.registry.entry("factions", id)
		var label := str(entry.get("label", ""))
		if not label.is_empty() and text.contains(label):
			return id
		for alias in (entry.get("aliases", []) as Array):
			if not str(alias).is_empty() and text.contains(str(alias)):
				return id
	return ""
```

在 `act()` 里（施法分支之后、`TRAIN_KEYWORDS` 分支之前）插入：

```gdscript
	# 计划 03a：派系动作（第五十章「可以支持凤凰社、加入食死徒、反对魔法部」）
	var faction_id := _detect_faction(world, text)
	if not faction_id.is_empty():
		var faction_label := str(world.registry.entry("factions", faction_id).get("label", faction_id))
		if _contains_any(text, FACTION_LEAVE):
			r.tags.append("faction")
			r.deltas.append({"op": "leave_faction"})
			r.narration = "你与%s断了关系。名字从名单上划掉，代价还看不出来。" % faction_label
			return r
		if _contains_any(text, FACTION_JOIN):
			r.tags.append("faction")
			r.deltas.append({"op": "join_faction", "faction_id": faction_id})
			r.narration = "你向%s表明愿意效力。他们先记下你的名字，再看看你能做什么。" % faction_label
			return r
		if _contains_any(text, FACTION_SUPPORT):
			r.tags.append("faction")
			r.deltas.append({"op": "faction_standing_delta", "faction_id": faction_id, "delta": 5})
			r.narration = "你公开支持%s。有人点头，有人把这件事记在了心里。" % faction_label
			return r
		if _contains_any(text, FACTION_OPPOSE):
			r.tags.append("faction")
			r.deltas.append({"op": "faction_standing_delta", "faction_id": faction_id, "delta": -5})
			r.narration = "你公开反对%s。他们会记住你的立场。" % faction_label
			return r
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[gm\]|^\[factions\]|总计|全部通过"`
Expected: 全部 `失败=0`；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/gm/scripted_game_master.gd tests/gm_test.gd
git commit -m "feat(gm): 离线替身支持加入/退出/支持/反对派系（计划 03a Task 9）"
```

---

