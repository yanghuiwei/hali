# Tasks 8–11 独立盲审记录（重跑 · 2026-09-20）

> **这不是重建版，也不是原始 log 的替代品。** 原始 reviewer log（`task-811-reviewer.log`）已随旧机器丢失、不可恢复（排查见 `task-811-review.md` 页首）。本文件是 **2026-09-20 对同一范围（`fed4767^..15c1ff0`）重跑的一次独立审查**，用途不同：
>
> | 文件 | 回答的问题 | 性质 |
> | --- | --- | --- |
> | `task-811-review.md` | **当时那个人发现了什么**（历史可追溯） | 重建版（据旁证反推） |
> | 本文件 | **这版代码本身还有没有问题**（独立复核） | **真实复审原文** |
>
> 两者并存、互不替代（`NEXT-STEPS.md` A2 的方案 (2)）。

## 盲审纪律与对象

- **对象**：`15c1ff0` 的完整源码快照（`git archive 15c1ff0` 导出，8 文件 / +264−12）+ 变更集包 `review-fed4767^..15c1ff0.diff`。
- **隔离**：明确禁止 reviewer 读 `E:/Hali/src/**`、`E:/Hali/tests/**`（已修复版本）与任何审查台账（`docs/sdd/**`、`HANDOFF.md`、`NEXT-STEPS.md`），使其**不知道**首轮发现的 F1–F6，避免锚定。核对项沿用首轮 brief 的 7 个中性问题（"问了什么"），并额外要求做**恒真断言排查**。
- **工具**：内置 `reviewer` agent（`read/grep/find/ls`，**无 bash**，`deepseek-flash` + thinking high，与主会话同模型）。故其结论全为静态论证，**未运行任何测试**——它在报告里自报了这一点。
- **溯源**：async 目录 `C:\Users\yhweix\AppData\Local\Temp\pi-subagents-user-yhweix\async-subagent-runs\79b9dbaf-7549-474b-ac07-a3c390ac9be9`（临时）；会话文件 `~/.pi/agent/sessions/--E--Hali--/2026-09-20T01-38-44-227Z_01a0bc77-.../67edb4be-aea5-4016-a90a-bc351197a4a2/run-0/session.jsonl`。

---

## 1. 三方对照表（重跑发现 ↔ 首轮发现 ↔ 当前 `main` 实况）

| 重跑 ID | 严重度（重跑） | 内容 | 对应首轮 | 当前 `main` 实况（2026-09-20 核验） |
| --- | --- | --- | --- | --- |
| **F1** | **P1** | `openai_compat_provider.gd:56` `choices[0]` 非对象不校验 → 运行期错误沿 `await` 链放大 | **= 首轮 F2** | ✅ **已修**（`a48f108` 加 `typeof(first) != TYPE_DICTIONARY` 护栏，现 `:56-59`） |
| **F2** | **P1** | UI 等待窗口**无错误兜底**：`editable=false` 后 `await` 链中任何运行期错误都会让协程在恢复语句前中止；`_on_load`/`_on_start_pressed` 也不重置 `editable` → **永久禁用，只能重启** | ⚠️ **首轮未发现** | ⚠️ **仍成立**（`main.gd:235-236` 禁用 → `:250-251` 恢复，中间无兜底；`_on_load` 只 `grab_focus` 于 `:304`）。已登记 `HANDOFF §8#62`（与 §8#58 同源，本条更锐） |
| F3 | P2 | 等待期只禁 `command_edit`，七个按钮可点 → 回合在飞时读档会造成叙事与状态错配 | **= 首轮 F3** | ✅ **已修**（`a48f108`：`button_row` 成员化 + `_set_buttons_enabled`，`main.gd:236/:250`） |
| **F4** | P2 | 降级原因**没有记入 `op_errors`**；`last_error` 是 write-only 死状态（全仓无读取者）——与 spec §9「降级 … **并记 op_errors**」不符 | ⚠️ **首轮未发现** | ⚠️ **仍成立**（`llm_game_master.gd:47-55` 的 `fallback != null` 分支既不动 `warnings` 也不把 `reason` 写进叙事；`last_error` 全仓仅 `:9` 声明 + `:48` 赋值）。已登记 `HANDOFF §8#61` |
| F5 | P2 | "解析失败 → `build_repair` 再试"**不可判别**：mock 不看请求内容，把 `build_repair` 换成 `build` 测试照样绿 | ≈ 首轮 F1/F5（漏断言同类） | ⚠️ **仍成立**（`tests/llm_test.gd` 只断言 `mock.requests[0]`，无 `requests[1].system_prompt` 断言）。已登记 `§8#64` |
| F6 | P2 | `llm_test.gd:136` `res3.narration.length() > 0` **准恒真**（`fallback != null` 时必然非空） | ≈ 首轮 F1/F5 | ⚠️ **仍成立**（`:136` 未变）。已登记 `§8#64` |
| F7 | P2 | 只正向断言"密钥在请求头"（`:183`），对"错误串不得带出 `api_key`"**零负向覆盖** | ≈ 首轮 F6 的测试侧 | ⚠️ **仍成立**（实现已掩码，但无 `is_false(...contains("sk-secret"))` 断言）。已登记 `§8#64` |
| F8 | P2 | 文档/命名漂移：`game_master.gd` 的 `act` 未注明"可协程"；实现叫 `_resolve` 而 spec §6.3 写的是 `_post_submit` | ⚠️ 首轮未发现 | ⚠️ **仍成立**（`game_master.gd:13` 无协程说明）。已登记 `§8#65` |
| F9① | P2 | provider 每次「开始人生」/「读档」都新建实例，其 `HTTPRequest` 节点 `add_child` 到 `self` 后**从不释放** → 反复读档线性泄漏 Node；且 `_http.timeout` 只在创建时设一次 | ⚠️ 首轮未发现 | ⚠️ **仍成立**（`openai_compat_provider.gd:75-79`）。**机制订正**：是**每个 provider 实例**懒建 1 个（非每次 `complete()`），故泄漏量 = 开始/读档次数。已登记 `§8#63` |
| F9② | P2 | `_build_gm` 有 UI 副作用（写 `status_label`），`_on_load` 紧接着覆盖它 → **读档路径看不到"未配置 LLM"提示** | **= 首轮 F4** | ✅ **已修**（`18eaa5c`：先写状态行、再建 GM；`main.gd:302-303`） |
| F10 | P2 | `submit()` 用 `gm is LlmGameMaster` **具体类型**判断拒绝协程 GM；blocked 时 `narration` 为空（无提示文案） | ⚠️ 首轮未发现 | ⚠️ **仍成立**（`turn_engine.gd:61-64`）。已登记 `§8#65` |
| F11 | P2 | 降级路径 `ScriptedGameMaster` 由 GM **直改 world**，绕开 `OpGuard`/`StateOps` | 首轮未列（= `§8#3/#35`、spec §14.1） | 📌 **已知债务，早已登记**（`a48f108` 未动它） |

**统计**：重跑共 11 条，其中 P1×2 / P2×9。**独立复现了首轮 3 条发现**（F2→F1、F3→F3、F4→F9②），**新发现 5 条在 `main` 上仍成立的问题**（重跑 F2/F4/F8/F9①/F10）+ 3 条漏断言同类（F5/F6/F7），并确认 1 条已知债务（F11）。

## 2. 重跑对首轮的两点"反向修订"（值得记录）

1. **严重度标定分歧**：同一个 `choices[0]` 缺陷，首轮（据重建素材反推）记为 **Minor**，重跑直接判 **P1**——理由是它会沿 `await` 链把闭包错误放大到 UI，并（在当时缺少按钮禁用的代码里）触发**永久禁用**。重建版给 F2 标的严重度只是推定，**这次分歧说明推定值可能偏低**。
2. **重跑的 F1 与首轮 F2 是同一个缺陷**，但重跑独立地把「`_parse_http` 元素级类型校验」和「UI 无恢复路径」串成了一条**可达的故障链**——这正是首轮没做到的因果分析（首轮 F2 只写了"降级链断"）。

## 3. 处置

| 类别 | 条目 | 动作 |
| --- | --- | --- |
| 已在 `main` 修掉 | 重跑 F1、F3、F9② | 无需动作；作为「修复确实解决了重跑独立识别出的缺陷」的交叉验证证据 |
| **新增登记（本轮）** | 重跑 F2 → `HANDOFF §8#62`；F4 → `§8#61`；F9① → `§8#63`；F5/F6/F7 → `§8#64`；F8/F10 → `§8#65` | 已写入 `HANDOFF.md` §8，并在 `NEXT-STEPS.md` §C 表登记触发时机 |
| 已登记（去重） | 重跑 F11 → `§8#3/#35`（spec §14.1） | 无新增 |
| 未采纳的建议 | 重跑建议②「`_on_load`/`_on_start_pressed` 末尾加 `command_edit.editable = true`」 | **不采纳为充分修复**：`main` 上按钮同批被禁用，读档入口不可达，仅重置 `editable` 治不了本；应改为"提交—恢复"的唯一出口（helper/状态机）才真正消除 `§8#62` |

## 4. 未验证清单（重跑自报 + 控制器补充）

重跑自报（原文见 §5）：①GDScript 运行期错误语义（是"中止函数返回默认值"还是"返回 null 继续"）是 F1/F2 的支点，无 bash 无法证实；②`await` 用于非协程返回值在 4.7.2 的行为；③`LineEdit.editable=false` 是否连 `text_submitted` 一起拦掉（是否存在等待期二次提交并发跑两回合）；④真实 HTTP 链路（`timeout` 只在建节点时生效、`response_format` 兼容性、401 body 是否回显凭证）；⑤异步路径的 `rng_state` 往返一致性；⑥文件清单来自变更集包而非自行 `git` 枚举；⑦`gres.warnings.size() >= 3` 的精确条数。

控制器补充：
8. 重跑对**快照**的判断我已逐条在 `main` 上复核（§1 最后一列），但**未实测复现** `§8#62` 的冻结（需要一个会抛错的 provider 桩 + 人工 GUI），仍属静态结论。
9. `§8#62` 的**可达性**未做对抗性验证：当前 `main` 上 `choices[0]` 路径已封，`HTTPRequest` 失败会走 provider 错误 → 降级，故触发冻结需要一个未被封住的运行期错误（例如畸形状态导致 `PanelFormatter` 报错，见 `§8#45`）。概率低、后果重（须重启），这是它被登记而非当轮修复的原因。

## 5. 重跑原文（verbatim）

```text
# Tasks 8–11 独立盲审记录（重跑，2026-09-20）

**审查对象**：`C:/Users/yhweix/AppData/Local/Temp/hali-r1/`（= `15c1ff0` 快照）+ 变更集包 `docs/sdd/plan-02-llm-narrative/review-fed4767^..15c1ff0.diff`。
**盲审纪律**：未读 `E:/Hali/src/**`、`E:/Hali/tests/**`，也未读任何审查台账（快照内同样存在 `docs/sdd/**`，故意跳过；仅在 grep 命中里被文件名污染，未读取其内容）。未运行任何命令（工具集无 bash、无写权限）。

## 结论

总体：设计骨架忠实落地——LLM 侧五文件对 `world` **只有读**，重试/降级/净化/`rng_state` 写回/warnings 透出都真实存在且接线正确；但**畸形响应有一条未兜底的路径**（`choices[0]` 非对象）会把错误沿 `await` 链一路放大到 UI，且 UI 的"等待期禁用"没有恢复兜底、`_on_load` 也不重置 `editable` → 一旦该路径触发，输入将**永久禁用**（只能重启）。另有 9 条 Minor（覆盖/文档/泄漏面）。

Critical(P0)：**0**　Important(P1)：**2**　Minor(P2)：**9**

**合并判定：BLOCK**（仅因 F1+F2 这一对；其余为 notes。注意这是历史快照的重审，不是当前仓库的合并门禁。）

## 发现表

| ID | 严重度 | 文件:行号 | 问题 | 为什么是问题 | 建议 |
|---|---|---|---|---|---|
| F1 | **P1** | `src/gm/providers/openai_compat_provider.gd:56` | `((choices as Array)[0] as Dictionary).get(...)` 未校验 `choices[0]` 是否为对象 | 校验只到 `choices` 是非空数组（:53）。`choices[0]` 是字符串/数字时 `as Dictionary` 得 `null`，`.get` 触发运行期错误。按本项目自述的 GDScript 语义（plan Task 1「运行期错误会让函数提前中止，typed 返回值退化为默认值」），错误会串到 `complete()`(:86 `resp.latency_ms`)→`act`(:23 `response.ok`)→`submit_async`(:73 `_resolve`)→UI。**违反题目第 4 点「choices[0] 不是对象是否安全失败」** | `var first = (choices as Array)[0]` 后 `if typeof(first) != TYPE_DICTIONARY: r.error = "响应缺少 message"; return r`（把类型判定前移到元素级） |
| F2 | **P1** | `src/ui/main.gd:234` / `248` / `273-292` | 等待窗口无错误兜底：`editable=false` 后，`await` 链中任何运行期错误都会让协程在 :248 之前中止；而 `_on_load`(:273-292) 与 `_on_start_pressed`(:164-195) 都**不**重置 `command_edit.editable` | 题目第 5 点直接问"中途异常会不会卡在禁用态"。答案是：会，且**无自愈路径**——7 个按钮虽仍可点（见 F3），但点「读档」后 `editable` 仍是 `false`（:292 只 `grab_focus`），玩家再也无法输入，只能重启。触发点 F1 已证实可达 | ①修 F1；②`_on_load`/`_on_start_pressed` 末尾加 `command_edit.editable = true`；③把「提交—恢复」包成 helper，恢复语句放在唯一出口（GDScript 无 `finally`，可用 defer/回调或状态机） |
| F3 | P2 | `src/ui/main.gd:232-249`（`_build_ui` 的按钮行 :61-67） | 等待期只禁用了 `command_edit`，`状态/魔法/关系/势力/存档/读档/自检` 七个按钮全部可点 | 回合在飞时点「读档」→ `_on_load` 替换 `world`/`engine`/`rng`，老协程随后在**旧 world** 上结算并把叙事写进新时间线的 `log_view`，`:247` 的 `status_label` 又用新 world → 叙事与状态错配。plan Task 11 Step 2 字面只要求 `command_edit.editable=false`，故属"按计划实现但留有重入洞" | 等待期一并禁用 `play_box` 内按钮（或加 `_busy` 布尔守卫，`_on_load` 等入口直接 return） |
| F4 | P2 | `src/gm/llm_game_master.gd:47-54` | 降级原因没有记入 `op_errors`；`last_error`(:9,:48) 全仓库无读取点 | 设计 §9 明确：「降级 … 追加系统提示 …, **并记 op_errors**」。实现只改文案，`r2.warnings` 保持空；`last_error` 是 write-only 死状态，UI 拿不到降级原因（HTTP 状态码/解析错误） | `_fallback` 里 `r2.warnings.append("LLM 降级：%s" % reason)`（或直接把 `reason` 塞进 `GmResult.warnings`），UI 侧已会打印 `op_errors` |
| F5 | P2 | `tests/llm_test.gd:123-125` | "解析失败 → 用 `build_repair` 再试"**不可判别**：mock 不看请求内容，把 `build_repair`(:27) 换成 `build` 测试照样绿 | 题目第 6 点「哪些已实现行为完全没有断言覆盖」：这是本次改动的核心分支之一 | 补 `a.is_true(provider.requests[1].system_prompt.contains("无法解析"))` |
| F6 | P2 | `tests/llm_test.gd:136` | `res3.narration.length() > 0` 准恒真：`fallback != null` 时 `_fallback`(:53-54) 必然返回非空叙事，此断言不可能失败 | 该用例声称验"无 provider 也有叙事"，实际只证明"没崩"；且未断言 FALLBACK_NOTE（对比 :132） | 改成 `a.is_true(res3.narration.contains("本地规则结算"))` 并加 `a.eq(gm3.last_error, "provider 未配置")` |
| F7 | P2 | `tests/llm_test.gd:175` | 只正向断言"密钥在请求头里"，对设计要求「所有错误信息不得带出 api_key」零负向覆盖 | 题目第 4 点要求核对脱敏；测试把泄漏向量写成正向断言，反而没有任何"不含密钥"的判别 | 加 `a.is_false(err_resp.error.contains("sk-secret"))`、`a.is_false(p._build_body(lreq).contains("sk-secret"))` |
| F8 | P2 | `src/gm/game_master.gd:11-12`；`src/core/turn_engine.gd:37` | 文档/命名与 spec 漂移：`act` 未注明"可协程"（plan 文件表第 33 行明确要求）；实现叫 `_resolve`，设计 §6.3 写的是 `_post_submit` | 契约文档与实现不一致，后来者读 §6.3 会找不到符号；"可协程"未注明会诱导像老 `submit()` 那样同步调用 | Task 12 Step 3 就地同步文档（plan 已把该同步列入 Task 12，故不阻塞 8–11） |
| F9 | P2 | `src/ui/main.gd:206-211` / `283-289` | ①每次「开始人生」/「读档」都 `LlmGameMaster.new(... OpenAiCompatProvider.from_settings(self, ...))`，provider 每次 `complete()` 懒建 `HTTPRequest` 并 `add_child`(:72-74) 到 `self`，旧节点从不 `queue_free`/`remove_child` → 反复读档线性泄漏 Node；②`_build_gm` 副作用写 `status_label`(:210)，`_on_load` 紧接着 :287 覆盖它 → **读档路径看不到"未配置 LLM"提示**（`_on_start_pressed` 路径能看到） | 长会话（读档几十次）里泄漏 Node；同一功能两条入口提示行为不一致 | ①provider 复用一个 `HTTPRequest`（或 `_host.remove_child/_http.queue_free()`）；②`_build_gm` 不做 UI 副作用，改由调用方按需提示 |
| F10 | P2 | `src/core/turn_engine.gd:61-64` | `submit()` 用 `gm is LlmGameMaster` 这种**具体类型**判断来拒绝协程 GM，且 blocked 时 `narration` 为空（`:59` 之后没有填文案） | 换任何"协程 act 的非 LlmGameMaster"（新 provider 包装、测试替身）就会把协程对象送进 `_resolve`(`:65` → `result.deltas`) 而崩；另外 UI 若误用 `submit()` 只会得到 `blocked=true` + 空叙事，无提示。此写法与 plan Task 9 Step 3 逐字一致，属"规格如此" | 改为鸭子类型/显式 `assert`（如 `assert(not gm.has_method("act") or gm is ScriptedGameMaster)`）或给 blocked 分支补文案 |
| F11 | P2（report-only） | `src/gm/scripted_game_master.gd:59-61`（`SpellResolver.cast(world,…)`、`Progression.gain(world,…)` → `spell_resolver.gd:122-133`、`progression.gd:14-24` 写 `world.flags`） | 降级路径（Task 8 正式扶正为生产路径）由 GM **直改 world**，绕开 `OpGuard` 与 `StateOps` | 与题目"一切世界变更必经 StateOps"不变量冲突；但 plan「已知边界」第 3 条**已声明**为刻意保留（"LLM 主路径已纠正"），且非本 4 提交改动 | 计划 03 收口：降级路径也改为产 ops（或显式在 spec 里把该边界标为长期债务） |

## 证据（逐条对应题目 1–7）

**Q1 五个文件对 `world` 有无写操作？→ 无（LLM 侧干净）。**
- `llm_game_master.gd`：全文无 `world.` 左值；只把 `world` 传给 `PromptBuilder.build`(:18)、`OpGuard.sanitize_detailed`(:39)、`fallback.act`(:53)。
- `op_guard.gd`：`world` 仅出现在 :36 `registry.has`、:55 `player.magic_tier`（读）；`_to_int` 只做类型归一。
- `prompt_builder.gd`：`world.` 全为读（:42-43, :48-70, :72-84）；`world.log.slice`/`history.slice` 返回拷贝；`JsonUtil.normalize` 对 Dictionary/Array 是**递归重建新容器**（`json_util.gd:13-27`），故 `state_digest` 与 world 无容器别名，返回结构可安全外传。
- `gm_response_parser.gd`：不接收 world，纯文本解析。
- `openai_compat_provider.gd`：不接收 world。
- 唯一"GM 写 world"出现在**降级委托**（ScriptedGameMaster，见 F11），LlmGameMaster 自身代码不写。

**Q2 重试/降级/warnings/repair。**
- 重试：`MAX_ATTEMPTS=2`(:4) + `for attempt in MAX_ATTEMPTS`(:21)，即"首轮 + 重试 1 次"，与设计 §9 一致。
- 解析失败 → `build_repair` 替换请求后重试（:26-27）✓；provider 失败 → `parsed=null`(:29)，下一轮仍用原请求 ✓。
- 收敛判定（:31-38）：`response==null`→"无响应"；`not response.ok`→provider 错误；`parsed` 失败→解析错误；任一失败即 `_fallback`(:38) ✓。
- **warnings 确实进了 GmResult**：`r.warnings = guard.warnings`(:44)，随后被 `TurnEngine._resolve` 追加进 `op_errors`(`turn_engine.gd:39-41`) → UI 打印(`main.gd:243-244`) ✓。
- 缺口：降级原因未记 op_errors（F4）；repair 请求内容未被断言（F5）。

**Q3 TurnEngine。**
- 共用守卫/结算：`_pre_submit`(:24-35) 与 `_resolve`(:37-49) 被 `submit`(:57-65) 与 `submit_async`(:68-73) 共享 ✓。
- 同步 `submit()` 遇 `LlmGameMaster`：:61-64 `push_error` + `blocked=true` 后直接 return，**不会**把协程对象交给 `_resolve`（:65 在同一 if 之后），也不会推进回合 ✓；代价是 narration 为空（F10）。
- warnings 透出：`op_errors`(:39-41) ✓（`gm_test.gd` 既有的 `w8.rng_state.size() > 0` 断言只覆盖同步路径）。
- `world.rng_state = rng.state_dict()`：仍在 `_resolve` 内(:48) ✓；`_init` 仍在有存档状态时 `rng.load_state`(:12-13) ✓。
- `submit_async` 对**同/非协程** GM 都写 `await gm.act(...)`(:72)：非协程返回值依赖 Godot 4 `await` 语义（设计 §6.1 与 `tests/async_probe_test.gd` 已声明），我未能实跑（见未验证清单）。

**Q4 `_parse_http` 逐种畸形输入。**
| 输入 | 结果 | 证据 |
|---|---|---|
| 非 2xx | 安全失败（error 含状态码 + body 前 200 字） | :45-47 |
| 2xx 非 JSON | 安全失败 | :49-51 |
| 缺 `choices` / `choices` 非数组 / 空数组 | 安全失败 | :52-55 |
| `choices[0]` 非对象 | **不安全**（运行期错误） | :56 → F1 |
| 缺 `message` | 走 :60 → `content=""` → `ok=false`，error="响应内容为空"（语义略偏，但不崩） | :60-63 |
| `message` 非对象（如 `123`） | 安全失败 error="响应缺少 message" | :57-58 |
| `content` 为空/缺失 | 安全失败 error="响应内容为空" | :61-63 |
| `api_key` 是否外泄 | `_parse_http`/`complete` 自身所有 error 串（:46,50,54,58,63,69,80）都不含 key；唯一外来文本是服务端 body 前 200 字（:46），理论上若服务端回显请求头可能带出 → 不可证 | 同上 |

**Q5 main.gd 异步接线。**
- 禁用面：只有 `command_edit.editable=false`(:234)，恢复 `=true`(:248) + `text=""`(:249)；7 个按钮、creation_box 未处理（F3）。
- 早退分支：`world==null`(:225-226) 与「确认自检」(:229-233) 都在禁用**之前** return；禁用之后无任何 `return` → 逻辑上不会漏恢复；但无错误兜底（F2）。
- `_on_start_pressed`：`rng`(:183) → `CharacterCreation.create(…, rng)`(:184) → `WorldState.create(…, rng.seed_value, …)`(:188) → `TurnEngine.new(world, _build_gm(), rng)`(:189)，`_build_gm` 用同一成员 `rng`(:209/:211) → **引擎与 GM 共享同一 `RngService` 实例** ✓。
- `_on_load`：`rng = RngService.new(world.game_seed)`(:283) → :284 同一实例给引擎与 GM；`TurnEngine._init` 再把 `world.rng_state` 载入该实例(`turn_engine.gd:12-13`)，因是引用传递，GM 也看到恢复后的状态 ✓；参数求值顺序（`_build_gm()` 先于 `TurnEngine.new`）不破坏共享 ✓。

**Q6 llm_test 新增断言（diff 新增块：:107-183）。**
- **没有严格恒真的断言**；但有 1 条准恒真（F6 :136）。
- **没有发现断言错对象**：我逐一核对了对象别名（`gp` 与 `gworld.player`、`ep` 与 `ew.player` 均为同一引用；`gp.magic_tier` 默认 `PRE_SCHOOL=1`(player_state.gd:21)，OpGuard 把 `tier=9` 钳成 `clampi(9,0,2)=2`，`absi(2-1)=1<=1` 成立，索引 3 确为 `set_magic_tier`（拒绝项 `_gm_rng_counter`/`system` 不占位），:87-104 的既有断言与实现一致；`potions` 在 `data/skills.json:4` 存在 → :100 的 `warnings>=3` 成立）。唯一"方向错位"的是 :175（F7）。
- **完全无断言覆盖的已实现行为**：①`GmResult.warnings` 的透出链（LlmGameMaster→GmResult→`op_errors`，全仓库只有 `gres.warnings` 直测 OpGuard）；②降级原因/`last_error`；③`build_repair` 是否真被使用（F5）；④`provider==null` 时 `last_error` 与"（原因：…）"文案；⑤`complete()` 的"provider 未配置"分支；⑥`_parse_http` 的 5 种畸形分支（缺 choices / 非数组 / 空数组 / `choices[0]` 非对象 / `message` 非对象 / `content` 空 / 非 2xx body 截断到 200 字）；⑦`_chat_url` 对已含 `/chat/completions` 与尾斜杠 `rstrip` 分支；⑧`json_mode=false` 时 `response_format` 不出现、`temperature/max_tokens` 传递；⑨`submit()` 遇 `LlmGameMaster` 的 `push_error`+blocked 路径；⑩`submit_async` 的"自检挂起 blocked"分支（仅测了死亡分支）；⑪`submit_async` 之后的 `rng_state` 已推进/存档往返（同步路径由 `gm_test.gd:181-184` 覆盖）；⑫`main.gd` 全部逻辑（`SUITES` 无 UI 套件，`run_tests.gd:6-23`）。
- 常量自指问题（**不在本 4 提交 diff 内**，属 Task 7 的既有块）：`:89/90/91/104` 用 `OpGuard.MAX_MONEY_GAIN`/`MAX_RELATION_DELTA`/`MAX_OPS` 断言自身，改坏设计数值（1000/±20/20）测试不会红；对照 `:67` 明确改用字面量 4000。report-only。

**Q7 越界/一致性。**
- 变更集包的文件清单：`src/core/turn_engine.gd`、`src/gm/game_master.gd`、`src/gm/llm_game_master.gd(+.uid)`、`src/gm/providers/openai_compat_provider.gd(+.uid)`、`src/ui/main.gd`、`tests/llm_test.gd` —— 与 Task 8/9/10/11 的 "Files" 声明逐项吻合；**未**触碰 `docs/**`、`data/**`、`tools/**`、`project.godot`，`.uid` 随脚本提交符合 plan 约定。**结论：无越界。**
- 边界说明（供交叉核对，不是缺陷）：`op_guard.gd`、`gm_response_parser.gd`、`prompt_builder.gd`、`llm_settings.gd`、`mock_provider.gd`、`tests/prompt_test.gd`、`tests/async_probe_test.gd`、`tests/run_tests.gd`、`state_ops.gd` 的 `train_skill` 均**不在这 4 个提交里**（属 Task 1–7 产物）。我对 Q1/Q2 中这些文件的结论基于快照内容，但"是否越界"只对这 4 个提交成立。
- 另：`MockLlmProvider` 放在 `src/gm/providers/`（会随游戏发布）而非 `tests/`，设计 §6.2 有意如此，非本 4 提交引入，仅记录。

## 反证 / 可判别性分析

**能被现有测试捕获的**：F1 之外的所有代码变更，现有套件都能守（`llm_test` 覆盖 parser/OpGuard/降级文案/端到端推进；`gm_test`/`save_test` 覆盖同步 submit、审计阻塞、死亡阻塞、`rng_state` 写回与存档续跑一致性；`prompt_test` 覆盖 `state_dict`/注入剥离/`build_repair` 文案）。也就是说**这 4 个提交没有引入可被现有测试捕获的回归**——F1/F2 全部落在既有断言之外。

**能被新测试捕获的**：
- F1：加 `OpenAiCompatProvider._parse_http(200, '{"choices":["x"]}')` 即可暴露——若运行期错误中止函数，套件会因"未调用 `report`"被 `run_tests.gd:60-63` 判为失败套件（而不是干净的红色断言），这也是它今天没被发现的原因。
- F4：加 `a.is_true("叙事引擎暂不可用" in "".join(out["op_errors"]))` 即可判别。
- F5：把 `provider.requests[1].system_prompt` 纳入断言才有判别力；当前断言对"是否用 `build_repair`"**不可判别**。
- 既有常量自指断言（`:89/90/91/104`）：不可判别设计数值，只能发现"钳制逻辑消失"。

**恒真清单**：仅 `llm_test.gd:136` 为准恒真（F6）。其余新断言都对具体行为敏感，我没有找到严格恒真项；也没有找到"断言错对象"项——`res/deltas`、`out/ew`、`body/headers`、`gworld/gp` 的引用关系逐一核对无误。

**F2 的可判别性**：`main.gd` 零自动化覆盖（`SUITES` 里没有 UI 套件），plan Task 11 Step 3 的人工冒烟是"窗口 + 一次正常行动"，**不可能**造出畸形响应 → F2 只能靠人工复现（打一个返回 `{"choices":["x"]}` 的假 endpoint，或注入使 `_parse_http` 报错的桩）。**声明：本结论为静态推理，我未运行任何测试，也未实际复现。**

## 未验证清单

1. **GDScript 运行期错误语义（F1/F2 的支点）**：错误是"中止当前函数并返回类型默认值"还是"返回 null 后继续执行"。项目自述取前者（`docs/.../plan-02...md` Task 1 注释：「运行期错误会让 `suite.run()` 提前中止（typed int 函数返回 0）」）。若实为后者，则 `openai_compat_provider.gd:57-58` 的 `typeof` 检查会兜住 F1（降级为 P2），F2 也随之降为纯理论。**无法在不实跑 Godot 的前提下证实**。
2. `await` 作用于非协程返回值（`ScriptedGameMaster.act`）在本快照指定的 Godot 4.7.2 上是否即时返回值。设计 §6.1 与 `tests/async_probe_test.gd` 断言其成立，但我未运行 `[async_probe]`；若该语义不成立，则"未配置 LLM"路径的 UI 会直接坏掉（影响面比 F1 更大）。
3. `main.gd` 的禁用/恢复行为（F2/F3）无任何自动化证据；且 `LineEdit.editable=false` 在 Godot 4.7.2 是否连 Enter(`text_submitted`) 一起拦掉（是否存在等待期二次提交并发跑两个回合）我只做了静态推断，未验证。
4. 真实 HTTP 链路：超时（`_http.timeout` 只在建节点时按首个请求设置一次，后续请求的 `timeout_ms` 变更不生效）、`response_format` 是否被各兼容端点接受、断网/401 时的 `body` 内容是否可能回显凭证（F7 的"是否真的会泄漏"）——均未验证。
5. `world.rng_state` 在 `submit_async` 之后的一致性/存档往返：只由同步路径的既有测试覆盖，异步路径我未实跑。
6. 本 4 提交的文件清单来自变更集包（`review-fed4767^..15c1ff0.diff` 的清单与 4 条 commit subject），我**没有**用 git 自行枚举 diff（无 bash）；若该包本身裁剪过，Q7 的"无越界"结论需以 git 复核为准。
7. `gres.warnings.size() >= 3` 的精确条数（我按实现推演为 3：金钱钳制/下划线 flag/system 来源）未实跑确认；`registry` 中 `potions` 存在已由 `data/skills.json:4` 证实。
```

## 6. 这一轮重跑的结论（控制器）

1. **重跑值得做**：它独立复现了首轮 3 条发现中的 3 条（包括 `_on_load` 提示覆盖那条），说明盲审是有效的；同时**挖出 5 条首轮没发现、至今仍成立的问题**（其中 `§8#61` 的降级原因丢失是 spec §9 的偏差）。
2. **它不能替代重建版**：它审的是"这版代码有什么问题"，回答不了"当时那个人发现了什么"。
3. **它对首轮的严重度标定提出了反例**：同一缺陷首轮（推定）Minor、重跑 P1 → 重建版的严重度列只能当参考。
4. **两者共同的盲区**已在各自"未验证清单"里：真实 HTTP 链路、UI 等待期行为、异步路径的存档一致性 —— 这些只有 `NEXT-STEPS.md` B1/B2 的**人工验收**能关掉。
