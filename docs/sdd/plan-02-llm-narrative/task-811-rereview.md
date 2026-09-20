# Tasks 8–11 修复轮 scoped 复审记录（+ F4 闭合）

> ⚠️ **§1（修复轮 `a48f108` 的复审）是重建版，不是 reviewer 原文。**
> 原始 log（`.superpowers/sdd/2026-09-19-hp-magic-era-02-llm-narrative/task-811-rereviewer.log`，约 9.0KB）**已随旧机器丢失**（排查同上：`.superpowers` 计划 02 目录不存在、`~/.pi/.../subagent-artifacts/` 只有 2026-09-18 计划 01 工件、git 全历史与 stash 均无）。
> **重建依据**：`task-811-rereview-brief.md`（逐条列出修复项与核对项）、`NEXT-STEPS.md` A3（结论「F2/F3 ADDRESSED 且反证承重，F4 当时仍未闭合」）、提交 `a48f108` 与其 diff（`review-15c1ff0..a48f108.diff`）。
> **§2/附录 A 不是重建**：那是 2026-09-20 由**独立只读 reviewer**（内置 `reviewer` agent，工具集 `read/grep/find/ls`，`deepseek-flash` + thinking high，与主会话同模型）在 `15c1ff0..18eaa5c` 上实跑得出的**原文**。

---

## 1. 修复轮 `a48f108` 的 scoped 复审（重建版）

**范围**：`15c1ff0..a48f108`；审查包 `review-15c1ff0..a48f108.diff`。
**修复项与核对项**（逐字取 `task-811-rereview-brief.md`）：

| 修复项 | 内容 | 复审关注点 |
| --- | --- | --- |
| **F3（Important）** | `button_row` 升为成员；新增 `_set_buttons_enabled()`；`_on_command_submitted` 首尾调用 | 是否真的覆盖「等待期按钮不可点」，有无遗漏按钮/分支；`_on_start_pressed`/`_on_load` 是否仍共享 rng |
| **F2** | `_parse_http` 对 `choices[0]` 非对象返回结构化错误（不再 `as Dictionary` 硬错 → 返回 nil → 降级链断） | 实现是否正确 |
| **F6** | `complete` 对失败 `error` 做 `api_key` 掩码 | 实现是否正确 |
| **F1 / F5** | 补 `warnings→op_errors` 与 `submit()` 拒绝异步 GM 的断言 | 新增断言是否**可判别**（反证：去掉 `_resolve` 的 warnings 循环 → `[llm]` 变红；还原） |
| **F4** | `_build_gm` 提示改为 `+=` 不再覆盖状态行 | 是否闭合 |
| 越界 | `git diff --name-only 15c1ff0..a48f108` | 仅 `src/ui/main.gd`、`src/gm/providers/openai_compat_provider.gd`、`tests/llm_test.gd`、计划、审查包 |
| 自跑 | `bash tools/test.sh` | `[llm] 65`、全 16 套件失败=0、`main scene ready`、EXIT=0 |

**结论（重建）**：
- **F2 / F3 ADDRESSED 且反证承重**（`NEXT-STEPS.md` A3 原文）。
- **F4 仍未闭合**：`a48f108` 只把提示改成 `+=`，但 `_on_load` 里 `_build_gm()` 仍先于 `status_label.text = ...` 执行，提示依然被整体覆盖。
- 其余 F1/F5/F6 无异议；**未发现新缺陷**。
- 总判定：**通过（附 F4 未闭合）**。

**注意事项**：首轮复审自己有没有实跑反证、跑的是哪两条、输出如何，**已不可知**（log 丢失）。2026-09-20 在 `main` 上补跑的两条反证见 `task-811-review.md` §D，结论一致（都转红）。

## 2. F4 闭合：`18eaa5c` + 2026-09-20 独立只读复审

**F4 的最终修复（`18eaa5c`，1 文件 +2/−1）**：`_on_load` 调整顺序 —— 先 `status_label.text = PanelFormatter.status_line(world) + " ｜ 回合 %d" % world.clock.turn`，**再** `engine = TurnEngine.new(world, _build_gm(), rng)`，并加注释「先设状态行，再建 GM：`_build_gm` 在未配置时会向状态行追加提示（F4）」。该修复当时**没有**对应的复审文件，故本次补一份 scoped 复审。

**复审方式**：按项目约定（`NEXT-STEPS.md` §D2「审查者只读」、§D1「与主会话同模型」）派**独立**只读 reviewer，范围 `15c1ff0..18eaa5c`，审查包 `review-15c1ff0..18eaa5c.diff`（本仓库新增）。
**结论**：**通过**；**F1–F6 全部 ADDRESSED，F4 已真正闭合**（读档路径不再覆盖提示，创建路径同样保住提示）。完整原文见附录 A。

**保留溯源**：该次运行的 async 目录 `C:\Users\yhweix\AppData\Local\Temp\pi-subagents-user-yhweix\async-subagent-runs\79f6f75c-436d-436c-96f5-ca795c9b4c15`（临时，会回收）、会话文件 `~/.pi/agent/sessions/--E--Hali--/2026-09-20T01-38-44-227Z_01a0bc77-357f-716d-b101-b8001c07e1a6/769ab0e1-4b1f-4a7c-a874-863a7482b236/run-0/session.jsonl`。

**复审提出的 3 条 Minor 及处置**：

| # | 发现 | 处置 |
| --- | --- | --- |
| N1 | `main.gd:249` 首条指令结束后 `status_label.text` 整体刷新，未配置 LLM 提示自此消失 | **接受**（计划既定行为，`task-11-report.md` 已登记；非 F4 回归） |
| N2 | `main.gd:239` `await engine.submit_async(text)` 若永不恢复，输入与整排按钮停在禁用态；UI 层无超时/取消 | **登记**（既有残余；已加入 `NEXT-STEPS.md` §C 待裁定表） |
| N3 | **计划文档漂移**：`docs/superpowers/plans/2026-09-19-...-02-llm-narrative.md` 的 `_on_load` 片段仍写作 `rng=…; engine=TurnEngine.new(world,_build_gm(),rng)`，按该片段重实施会**复现 F4** | **已修**（本次提交同步为「先写 status_line、再建 GM」并加注 `18eaa5c`） |

## 3. 残余与未验证（累积）

1. UI 协程卡死无看门狗（N2 / `task-11-report.md` / `task-9-report.md`）。
2. 真实 `HTTPRequest` 链路、`api_key` 掩码端到端、提示注入绕过率 —— 只能靠**人工真机联调**（`NEXT-STEPS.md` B2）。
3. F3/F4 的最终确认只能靠**人工 GUI 验收**（headless 对 UI 接线不可观测；`task-811-review.md` §D 反证 ③ 已证）。
4. 本次复审**工具集不含 bash**，因此它自跑不了 `tools/test.sh` / `git`；静态论证边界见附录 A「未验证清单」（控制器已在 2026-09-20 补齐实跑：`EXIT=0`、16 套件失败=0）。

---

## 附录 A：2026-09-20 独立只读复审原文（verbatim）

````text
# Tasks 8–11 修复轮 scoped 复审记录（含 F4 闭合）

## 结论

| 条目 | 判定 | 一句话依据 |
|---|---|---|
| F1（warning 未进 `op_errors` 且无断言） | **ADDRESSED** | `_resolve` 已追加 `result.warnings`；测试用「会触发钳制警告、StateOps 不报错」的用例，断言可判别、非恒真 |
| F2（`choices[0]` 非对象硬错） | **ADDRESSED** | `_parse_http` 显式 `typeof(first) != TYPE_DICTIONARY` 护栏，null/数组/字符串均安全降级 |
| F3（等待期只禁 `command_edit`，整排按钮可点） | **ADDRESSED** | `button_row` 升为成员；`_set_buttons_enabled` 覆盖整排 7 个按钮；等待期禁用、结束恢复；「确认自检」短路分支在禁用之前返回 |
| F4（`_build_gm` 提示被 `status_label.text` 覆盖） | **ADDRESSED（已闭合）** | `_build_gm` 改 `+=`，且 `_on_load` 已把 `status_label.text=status_line` 调到 `_build_gm()` 之前；`_on_start_pressed` 无后续覆盖 |
| F5（同步 `submit()` 拒绝异步 GM 无断言） | **ADDRESSED** | `submit()` 有 `gm is LlmGameMaster` 分支；测试在 turn=2（无死亡、无自检挂起）时断言 `blocked` 且不推进 |
| F6（失败 `error` 未脱敏 `api_key`） | **ADDRESSED** | `complete()` 对 `resp.error` 做 `replace(api_key,"***")`；无需脱敏的两条早退路径本就不含 key |

**总判定：通过。** F4 已真正闭合——读档路径现在「先写状态行、再建 GM」，未配置提示不再被覆盖；创建路径同样保住提示。

## 证据

### F4（重点核对项 1）
- `src/ui/main.gd:207-212`：`_build_gm()` 未配置分支为
  `status_label.text += "（未配置 LLM，使用本地叙事替身；配置见 user://llm_settings.json）"` —— 由赋值改为追加，不再抹掉已有文本。
- `src/ui/main.gd:297-299`（读档路径顺序）：
  ```
  status_label.text = PanelFormatter.status_line(world) + " ｜ 回合 %d" % world.clock.turn
  # 先设状态行，再建 GM：_build_gm 在未配置时会向状态行追加提示（F4）
  engine = TurnEngine.new(world, _build_gm(), rng)
  ```
  先写 status_line，再 `_build_gm()` 追加提示 → 提示保留（旧序为 engine 在前、status 在后，会把提示覆盖掉，即首轮未闭合的根因）。
- `src/ui/main.gd:190`（创建路径）：`engine = TurnEngine.new(world, _build_gm(), rng)` 之后该函数体内**没有任何** `status_label.text =` 赋值，故未配置提示（追加到标题行 `:41`）同样保留。
- 其它分支排查（问题 1 的「还有没有其它分支覆盖」）：`_on_save:278`、`_on_status:262`、`_on_audit:306`、`_on_magic/_on_relation/_on_power`、`_show_creation_error` 均**不写** `status_label.text`；`_ready`→`_build_ui:41` 只在构建时设标题（那时尚无提示）。唯一仍会整体替换状态行的是 `_on_command_submitted:249`，属首条指令后的正常状态行刷新。

### F3（重点核对项 2）
- `src/ui/main.gd:23`：`var button_row: HBoxContainer = null` —— 已是成员（`_build_ui:61` 由局部 `:=` 改为成员赋值，`:68` 把 7 个按钮全部 add 进 `button_row`：状态/魔法/关系/势力/存档/读档/自检）。
- `src/ui/main.gd:255-260`：
  ```
  func _set_buttons_enabled(enabled: bool) -> void:
      if button_row == null: return
      for child in button_row.get_children():
          if child is Button:
              (child as Button).disabled = not enabled
  ```
  覆盖整排，无遗漏（该行仅含 Button）。
- 等待期：`main.gd:235-236` `command_edit.editable=false` + `_set_buttons_enabled(false)`；结束在 `:250-251` 恢复。`blocked` 分支：`submit_async` 正常返回一个 dict，`await` 会恢复 → 按钮恢复，不会卡死。
- 自检短路分支：`main.gd:229-234`（`确认自检`）在 `_set_buttons_enabled(false)` 之前 `return`，故**不会**留下禁用态。
- 另注：`creation_box` 的「读取存档」按钮不在 `button_row`，但进入 play 后 `creation_box.visible=false`（`:191/:296`），等待期不可点，故不构成 F3 缺口。

### F1（重点核对项 3）
- `src/core/turn_engine.gd:37-45`：`_resolve` 中
  ```
  var errors := StateOps.apply(world, result.deltas)
  for warning in result.warnings:
      errors.append(str(warning))
  ...
  out["op_errors"] = errors
  ```
  `StateOps.apply` 返回 `PackedStringArray`（`src/rules/state_ops.gd:5-6`），故 `op_errors` 确为 `PackedStringArray`。
- `src/gm/llm_game_master.gd`：`r.warnings = guard.warnings`（`OpGuard.sanitize_detailed` 产物）。
- 测试可判别性：`tests/llm_test.gd:145-159`，第二段队列为 `{"op":"add_money","knuts":999999}` → `OpGuard` 钳到 `MAX_MONEY_GAIN=1000` 并 append 警告「金钱收益已钳到上限 1000」（`src/gm/op_guard.gd:40-49`）；而 `StateOps` 对该 `add_money` 不产生 error（`state_ops.gd:17-19`）。因此**移除 F1 修复后 `op_errors` 为空、断言转红** → 非恒真、右操作数 `(out_warn["op_errors"] as PackedStringArray).size() > 0` 非自指。

### F5（重点核对项 3）
- `src/core/turn_engine.gd:57-66`：
  ```
  func submit(action_text: String) -> Dictionary:
      var out := _blank_result()
      if not _pre_submit(out): return out
      if gm is LlmGameMaster:
          push_error("submit() 不能驱动 LlmGameMaster；请用 submit_async()")
          out["blocked"] = true
          return out
      return _resolve(out, gm.act(world, action_text))
  ```
- 测试 `tests/llm_test.gd:161-164`：`engine` 的 gm 为 `LlmGameMaster`；此刻 `ew.clock.turn=2`（`game_clock.gd:6` 初值 0 + 两次 `submit_async`），`SelfCheck.is_audit_turn(turn)=turn>0 and %15==0`（`src/rules/self_check.gd:6`），无自检挂起；`alive` 仍为 true（死亡用例在其后）。故命中的是 **GM 类型守卫分支**而非其它守卫，断言可判别。`push_error` 只打印 ERROR，不中止套件（`tests/run_tests.gd:_run_suite` 仅以 `report_calls` 与返回 int 判成败）。

### F2 / F6（重点核对项 4）
- F2：`src/gm/providers/openai_compat_provider.gd:56-59`
  ```
  var first = (choices as Array)[0]
  if typeof(first) != TYPE_DICTIONARY:
      r.error = "响应 choices[0] 不是对象"
      return r
  ```
  `{"choices":[123]}`/`[null]`/`[["a"]]` 分别 typeof=INT/NIL/ARRAY → 均走护栏返回失败（旧码 `(...[0] as Dictionary).get(...)` 会对非字典元素得到 null 再 `.get` 报错）。`message` 非字典另有 `:60-63` 护栏。测试 `tests/llm_test.gd:192-193`。
- F6：`src/gm/providers/openai_compat_provider.gd:91-92`
  ```
  if not resp.ok and not api_key.is_empty():
      resp.error = resp.error.replace(api_key, "***")
  ```
  `complete()` 的失败出口共三处：① `:71-74` `provider 未配置`（不含 key，且 key 为空时也早退）；② `:83-85` `请求发起失败（%d）`（只有 Error 码，不含 key）；③ `:89-92` 经 `_parse_http`，非 2xx 会把 `body.substr(0,200)` 拼进 error（唯一可能回显 key 的路径）→ 已脱敏。`_parse_http` 所有 `ok=false` 出口均写入非空 `error`，`error` 为空串时 `replace` 亦安全。
- `LlmGameMaster._fallback` 用 `reason=response.error` 拼 `narration`，因上游已脱敏，故降级叙事也不会带出 key。

### 越界/夹带（重点核对项 5）
- 审查包文件统计列出本区段改动共 5 个文件：`docs/sdd/.../review-fed4767^..15c1ff0.diff`（审查包）、`docs/superpowers/plans/...02-llm-narrative.md`（计划文档）、`src/gm/providers/openai_compat_provider.gd`、`src/ui/main.gd`、`tests/llm_test.gd`。逐一为 F1–F6 所需或允许范围，**未见无关改动**（`.uid` 属 15c1ff0 段，未在本区段）。
- 实际工作区文件内容与 diff 后态一致（已 `read` 三处源文件核对）。

## 新发现

- **Minor（报告项，非阻断）** `src/ui/main.gd:249`：`_on_command_submitted` 结束时会用 `status_label.text = PanelFormatter.status_line(...)` 整体替换状态行，故未配置 LLM 提示在**首条指令后**消失。此行为在计划侧已明确接受（`docs/sdd/plan-02-llm-narrative/task-11-report.md:98`「直到首条指令结束才被 status_line 覆盖回来——可接受，属计划既定行为」），不属 F4 回归。
- **Minor（风险/沿用残余）** `src/ui/main.gd:239`：`await engine.submit_async(text)` 若因异常未能恢复，GDScript 无 try/catch，`command_edit.editable` 与整排按钮将**停留在禁用态**；UI 层无超时/取消（`progress.md:107` 已登记）。静态阅读未发现正常流程下的卡死路径，仅列为残余风险。
- **Minor（文档漂移）** 计划文档 `docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md:1363-1366` 的 `_on_load` 片段仍写作 `rng=…; engine=TurnEngine.new(world,_build_gm(),rng)`，未反映 `18eaa5c` 要求的「先写 status_line 再建 GM」顺序；按此片段重实施会复现 F4。仅为片段示意，无代码影响。

## 未验证清单

1. **未运行测试**：工具集无 bash，无法执行 `bash tools/test.sh` 或 Godot headless；`[llm]`/`[gm]`/`[save]` 是否全绿、EXIT 码、F1/F5 新断言是否实际转绿**均未实跑验证**，仅做静态论证（含对移除修复后应转红的推理）。
2. **未运行 git**：无法独立核验 `15c1ff0..18eaa5c` 的精确文件集；对「无越界改动」的结论依据是提供方 `review-15c1ff0..18eaa5c.diff` 的文件统计 + 三处源文件后态比对。
3. **UI 接线不可观测**：headless 冒烟对 `_set_buttons_enabled`/`_build_gm` 提示/`_on_load` 顺序**不可观测**（`progress.md:105` 亦确认「把 `_build_gm` 强制走 Scripted，冒烟仍 EXIT=0」）。F3/F4 结论均为逐行静态阅读，无自动化证据。
4. **运行时语义未验**：`choices[0]` 非对象在旧码下的具体报错形式、`gm.act` 无 `await` 时的返回值形态等运行期行为未实跑，仅按类型系统推断「若无护栏/守卫则测试转红」。
5. **`_http` 未入树/超时未触发时 `request_completed` 是否恢复**未实测（仅确认 `from_settings(self,…)` 传入非空 host）。

未发现 P0/P1 阻断项；`Merge verdict: OK`（附上述 Minor 报告项）。
````
