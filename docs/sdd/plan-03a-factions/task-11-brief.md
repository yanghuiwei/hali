### Task 11: 顺手项 B —— 降级原因透出（`§8#61`）、测试可判别性（`§8#64`）、契约与鸭子类型（`§8#65`）

**Files:**
- Modify: `src/gm/llm_game_master.gd`、`src/gm/game_master.gd`、`src/core/turn_engine.gd`、`docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md`（标点级同步）
- Test: `tests/llm_test.gd`、`tests/gm_test.gd`

**Interfaces:**
- Produces:
  - `GameMaster.is_async() -> bool`（基类返回 `false`；`LlmGameMaster` 覆写为 `true`）
  - `TurnEngine.submit()` 改用 `if gm.is_async():` 拒绝，并给出**非空** `narration`
  - `LlmGameMaster._fallback()` 把降级原因写进 `warnings`（UI 会打印到 `op_errors`）

- [ ] **Step 1: 写失败测试**

`tests/llm_test.gd` 追加：

```gdscript
	# ---- 计划 03a（§8#61）：降级原因必须透出给调用方 ----
	var fmock := MockLlmProvider.new()
	fmock.errors = ["网络抖动"]
	var fgm := LlmGameMaster.new(fmock, ScriptedGameMaster.new(RngService.new(3)), null)
	var fres: GameMaster.GmResult = await fgm.act(lw, "我要去上课")
	var warned := ""
	for w in fres.warnings:
		warned += str(w) + " | "
	a.is_true(warned.contains("降级"), "降级写进 warnings")
	a.is_true(warned.contains("网络抖动"), "降级原因（原始错误）进 warnings")

	# ---- 计划 03a（§8#64①）：重试请求必须带修复提示（否则把 build_repair 换成 build 也能绿） ----
	var rmock := MockLlmProvider.new()
	rmock.queue = ["不是 JSON", "{\"narration\":\"修好了\",\"ops\":[],\"tags\":[]}"]
	var rgm := LlmGameMaster.new(rmock, null, null)
	var rres: GameMaster.GmResult = await rgm.act(lw, "我要去上课")
	a.eq(rres.narration, "修好了", "二次尝试成功")
	a.eq(rmock.requests.size(), 2, "确实重试了一次")
	a.is_true(str(rmock.requests[1].system_prompt).contains("上一次输出无法解析"), "第二次请求带修复提示")

	# ---- 计划 03a（§8#64②）：无 provider 的降级叙事要断言具体文案 ----
	var no_prov := LlmGameMaster.new(null, null, null)
	var nres: GameMaster.GmResult = await no_prov.act(lw, "我要去上课")
	a.is_true(nres.narration.contains("本地规则结算"), "无 provider 时明确告知用本地规则结算")
	a.is_true(nres.narration.contains("provider 未配置"), "并给出原因")
```

`tests/gm_test.gd` 追加：

```gdscript
	# ---- 计划 03a（§8#65③）：鸭子类型判定 + blocked 非空文案 ----
	a.is_false(ScriptedGameMaster.new(RngService.new(1)).is_async(), "离线替身声明为同步")
	a.is_true(LlmGameMaster.new(null, null, null).is_async(), "LLM 主模块声明为协程")
	var sync_world := make_world()
	var async_engine := TurnEngine.new(sync_world, LlmGameMaster.new(null, null, null), RngService.new(1))
	var blocked_out: Dictionary = async_engine.submit("我要去上课")
	a.is_true(bool(blocked_out["blocked"]), "同步 submit 拒绝协程 GM")
	a.is_true(not str(blocked_out["narration"]).is_empty(), "拒绝时给出非空提示（UI 不会白屏）")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[llm\]|^\[gm\]|总计"`
Expected: 失败（`is_async` 未定义；降级 warnings 为空）。

- [ ] **Step 3: 实现**

`src/gm/game_master.gd`：在 `act()` 声明前后加：

```gdscript
# 计划 03a（§8#65①）：act 可以是同步函数，也可以是含 await 的协程；调用方统一写 await gm.act(...)。
# is_async() 用于 TurnEngine 判定能否走同步 submit()（默认 false，协程实现必须覆写为 true）。
func is_async() -> bool:
	return false
```

`src/gm/llm_game_master.gd`：加

```gdscript
func is_async() -> bool:
	return true
```

并把 `_fallback()` 改为：

```gdscript
func _fallback(world: WorldState, action_text: String, reason: String) -> GmResult:
	last_error = reason
	if fallback == null:
		var r := GmResult.new()
		r.narration = "%s（原因：%s）" % [FALLBACK_NOTE, reason]
		r.warnings.append("LLM 降级：%s" % reason)
		return r
	var r2 := fallback.act(world, action_text)
	r2.narration = "%s %s" % [r2.narration, FALLBACK_NOTE]
	r2.warnings.append("LLM 降级：%s" % reason)
	return r2
```

`src/core/turn_engine.gd`：

```gdscript
	if gm.is_async():
		push_error("submit() 不能驱动协程 GM；请用 submit_async()")
		out["blocked"] = true
		out["narration"] = "本模块需要异步回合（请使用 submit_async 路径）；本回合未结算。"
		return out
```

`docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md`：`_post_submit` 改为 `_resolve`（与代码一致），并在 `### 6.1 GameMaster` 的代码块里补 `is_async()`。

- [ ] **Step 4: 跑测试确认通过**

Run: `bash tools/test.sh 2>&1 | grep -E "^\[llm\]|^\[gm\]|总计|全部通过"`
Expected: 全部 `失败=0`；`全部通过。`

- [ ] **Step 5: 提交**

```bash
git add src/gm/llm_game_master.gd src/gm/game_master.gd src/core/turn_engine.gd docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md tests/llm_test.gd tests/gm_test.gd
git commit -m "fix(gm): 降级原因透出 + is_async 鸭子类型 + 测试可判别性（§8#61/#64/#65）（计划 03a Task 11）"
```

---

