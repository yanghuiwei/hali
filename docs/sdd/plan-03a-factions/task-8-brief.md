### Task 8: `PromptBuilder.state_digest` 暴露已揭示派系（Q4）

**Files:**
- Modify: `src/gm/prompt_builder.gd`
- Test: `tests/prompt_test.gd`

**Interfaces:**
- Consumes: `WorldFactions.visible_faction_ids/power_of/government_type`；`PlayerState.standing_of/faction_id`。
- Produces: `PromptBuilder.state_digest(world)` 文本新增两行：`政体：<label>` 与 `已知势力：<label>(%.2f,立场%+d,所属) …`（无可见派系时为 `已知势力：无`）。**未揭示派系不得出现**。

- [ ] **Step 1: 写失败测试**

在 `tests/prompt_test.gd` 的 `run()` 末尾（`return a.report("prompt")` 之前）追加：

```gdscript
	# ---- 计划 03a：提示词只暴露已揭示的派系（第四十三/五十七章） ----
	WorldFactions.initialize(w)
	var digest := PromptBuilder.state_digest(w)
	a.is_true(digest.contains("政体："), "摘要含政体")
	a.is_true(digest.contains("已知势力："), "摘要含已知势力行")
	a.is_true(digest.contains("魔法部"), "摘要含公开派系")
	a.is_false(digest.contains("食死徒"), "摘要不得含未揭示派系（信息保护）")
	WorldFactions.ensure_state(w, "death_eaters")["revealed"] = true
	var digest2 := PromptBuilder.state_digest(w)
	a.is_true(digest2.contains("食死徒"), "揭示后才进入摘要")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[prompt\]|总计"`
Expected: 失败（摘要无「政体：」「已知势力：」）。

- [ ] **Step 3: 实现**

在 `src/gm/prompt_builder.gd` 的 `state_digest()` 末尾（`return` 之前）追加：

```gdscript
	# 计划 03a：政治格局（只给已揭示的派系——未揭示的绝不进提示词，第四十三/五十七章）
	var gov_id := str(world.flags.get(WorldFactions.GOVERNMENT_FLAG, ""))
	if gov_id.is_empty():
		gov_id = WorldFactions.government_type(world)
	lines.append("政体：%s" % str(world.registry.entry("governments", gov_id).get("label", gov_id)))
	var faction_parts: Array[String] = []
	for fid in WorldFactions.visible_faction_ids(world):
		var id := str(fid)
		faction_parts.append("%s(%.2f,立场%+d%s)" % [
			str(world.registry.entry("factions", id).get("label", id)),
			WorldFactions.power_of(world, id),
			world.player.standing_of(id),
			",所属" if world.player.faction_id == id else ""])
	if faction_parts.is_empty():
		lines.append("已知势力：无")
	else:
		lines.append("已知势力：%s" % " ".join(faction_parts))
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[prompt\]|^\[llm\]|总计|全部通过"`
Expected: 全部 `失败=0`；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/gm/prompt_builder.gd tests/prompt_test.gd
git commit -m "feat(gm): 提示词摘要暴露已揭示派系与政体（计划 03a Task 8）"
```

---

