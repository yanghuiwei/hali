### Task 7: 势力面板重写（第六十五章）

**Files:**
- Modify: `src/ui/panel_formatter.gd`
- Test: `tests/panel_test.gd`

**Interfaces:**
- Consumes: `WorldFactions.power_share/institution_control/government_type/visible_faction_ids/power_of/state_of`；`world.registry.entry("governments", id)`；`PlayerState.standing_of`。
- Produces: `PanelFormatter.power_panel(world) -> String` 新格式（三行 + 【已知势力】一行）；新增私有 helper `_known_factions_line(world)`、`_institution_holder_label(world, ic, institution_id)`。

- [ ] **Step 1: 写失败测试**

在 `tests/panel_test.gd` 末尾（`return a.report("panel")` 之前）追加：

```gdscript
	# ---- 计划 03a：势力面板（第六十五章 + 【已知势力】） ----
	WorldFactions.initialize(w)
	var power := PanelFormatter.power_panel(w)
	a.is_true(power.contains("《哈利·波特·魔法纪元·势力面板》"), "势力面板标题")
	a.is_true(power.contains("政体：魔法部官僚制"), "政体来自内容表")
	a.is_true(power.contains("法律执行：0.75（魔法部）"), "机构指标来自控制权 + holder 标签")
	a.is_true(power.contains("傲罗：0.60（傲罗指挥部）"), "傲罗控制权来自傲罗指挥部")
	a.is_true(power.contains("威森加摩：0.58（威森加摩）"), "威森加摩控制权来自威森加摩派系")
	a.is_true(power.contains("国际："), "含国际指标")
	a.is_true(power.contains("财政："), "含财政指标")
	a.is_true(power.contains("稳定度："), "含稳定度指标")
	a.is_true(power.contains("腐败度："), "含腐败度指标")
	a.is_true(power.contains("纯血影响："), "含纯血影响指标")
	a.is_true(power.contains("麻瓜关系："), "含麻瓜关系指标")
	a.is_false(power.contains("待定"), "不再有占位「待定」")
	a.is_true(power.contains("【已知势力】"), "含【已知势力】行")
	a.is_true(power.contains("食死徒") == false, "未揭示的派系不得出现（第四十三/五十七章）")

	WorldFactions.ensure_state(w, "death_eaters")["revealed"] = true
	w.player.faction_id = "ministry"
	w.player.add_standing("ministry", 30)
	var power2 := PanelFormatter.power_panel(w)
	a.is_true(power2.contains("食死徒"), "揭示后出现在面板里")
	a.is_true(power2.contains("立场 +30"), "显示玩家立场")
	a.is_true(power2.contains("[所属]"), "标出玩家所属派系")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[panel\]|总计"`
Expected: 失败（旧格式无「政体：」「【已知势力】」，且旧文本含「待定」）。

- [ ] **Step 3: 实现**

把 `src/ui/panel_formatter.gd` 的 `power_panel()` 整体替换为：

```gdscript
# 第六十五章（计划 03a 重写）：机构级指标来自派系的机构控制权，标量级指标来自 world_vars。
# 信息保护（第四十三/五十七章）：未揭示的派系不出现在任何玩家可见文本里。
static func power_panel(world: WorldState) -> String:
	var vars := world.world_vars
	var ic := WorldFactions.institution_control(world)
	var gov_id := str(world.flags.get(WorldFactions.GOVERNMENT_FLAG, ""))
	if gov_id.is_empty():
		gov_id = WorldFactions.government_type(world)
	var lines: Array[String] = []
	lines.append("《哈利·波特·魔法纪元·势力面板》")
	lines.append("【魔法部状态】政体：%s 部长：%s 法律执行：%.2f（%s） 傲罗：%.2f（%s） 威森加摩：%.2f（%s） 财政：%.2f 国际：%.2f（%s） 稳定度：%.2f 腐败度：%.2f 纯血影响：%.2f 麻瓜关系：%.2f" % [
		_label(world, "governments", gov_id),
		_institution_holder_label(world, ic, "law_enforcement"),
		float((ic["law_enforcement"] as Dictionary)["value"]), _institution_holder_label(world, ic, "law_enforcement"),
		float((ic["auror_office"] as Dictionary)["value"]), _institution_holder_label(world, ic, "auror_office"),
		float((ic["wizengamot"] as Dictionary)["value"]), _institution_holder_label(world, ic, "wizengamot"),
		float(vars.get("economy_index", 0.0)),
		float((ic["international"] as Dictionary)["value"]), _institution_holder_label(world, ic, "international"),
		float(vars.get("ministry_stability", 0.0)), float(vars.get("corruption", 0.0)),
		float(vars.get("pureblood_influence", 0.0)), float(vars.get("muggle_relations", 0.0))])
	lines.append("【霍格沃茨】学院：%s 校方控制：%.2f（%s） 学业：%s 学院杯：仅 NPC 系统（计划 05） 魁地奇：仅 NPC 系统（计划 05） 禁林状况：%s 秘密：未调查 师生关系：%d人" % [
		_label(world, "houses", world.player.house_id),
		float((ic["hogwarts"] as Dictionary)["value"]), _institution_holder_label(world, ic, "hogwarts"),
		_top_skill(world.player, world),
		str(world.flags.get("forbidden_forest_status", "常态")),
		world.player.relations.size()])
	var family: Dictionary = world.player.flags.get("family", {})
	if family.is_empty():
		lines.append("【家族】姓氏：无家族（家族制度属计划 03c） 祖宅：无 财富：%s 成员：0 婚姻：未婚 盟友：0 敌人：0 声望：%d 家族秘密：无 继承人：未定 魔杖传承：无" % [
			world.player.money().formatted(), world.player.reputation])
	else:
		lines.append("【家族】姓氏：%s 祖宅：%s 财富：%s 成员：%d 婚姻：%s 盟友：%d 敌人：%d 声望：%d 家族秘密：%s 继承人：%s 魔杖传承：%s" % [
			str(family.get("surname", "无家族")), str(family.get("seat", "无")),
			world.player.money().formatted(), int(family.get("members", 0)),
			str(family.get("marriage", "未婚")), int(family.get("allies", 0)), int(family.get("enemies", 0)),
			world.player.reputation, str(family.get("secret", "未知")),
			str(family.get("heir", "未定")), str(family.get("wand_legacy", "无"))])
	lines.append(_known_factions_line(world))
	return "\n".join(lines)

# 【已知势力】：只列 revealed 派系，按实力降序；标出玩家所属与立场。
static func _known_factions_line(world: WorldState) -> String:
	var visible := WorldFactions.visible_faction_ids(world)
	if visible.is_empty():
		return "【已知势力】暂无已知势力（魔法世界对你是沉默的）"
	var rows: Array = []
	for fid in visible:
		var id := str(fid)
		rows.append({"id": id, "label": _label(world, "factions", id),
			"power": WorldFactions.power_of(world, id), "standing": world.player.standing_of(id),
			"member": world.player.faction_id == id})
	rows.sort_custom(func(x, y): return float(x["power"]) > float(y["power"]))
	var parts: Array[String] = []
	for row in rows:
		parts.append("%s：%.2f 立场 %+d%s" % [str(row["label"]), float(row["power"]),
			int(row["standing"]), "[所属]" if bool(row["member"]) else ""])
	return "【已知势力】" + " ".join(parts)

static func _institution_holder_label(world: WorldState, ic: Dictionary, institution_id: String) -> String:
	var holder := str((ic[institution_id] as Dictionary).get("holder", ""))
	if holder.is_empty():
		return "无人"
	return _label(world, "factions", holder)
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[panel\]|总计|全部通过"`
Expected: `[panel] 断言=... 失败=0`；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/ui/panel_formatter.gd tests/panel_test.gd
git commit -m "feat(ui): 势力面板重写——机构控制权 + 已知势力（修 §8#7）（计划 03a Task 7）"
```

---

