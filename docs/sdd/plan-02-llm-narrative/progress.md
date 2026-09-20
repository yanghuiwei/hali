# SDD ledger — plan-02：LLM 叙事引擎

分支 `plan-02-llm-narrative`（从 main 拉出）。计划 `docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md`（12 任务）。
流程同计划 01：brief → worker（deepseek-flash）→ 绿灯 → 报告 → 只读 reviewer → 修复轮 + scoped 复审 → 台账。

> 2026-09-20 补录：收尾时本文件只写到 Task 7，Tasks 8–12 缺条目（`.superpowers/.../progress.md` 同样只有 1–7）。本次按提交/diff/报告/简报补齐 Tasks 8–12，并新增「台账覆盖核对」节。
> **注意**：首轮审查 `task-811-review.md` 与复审 `task-811-rereview.md` 的原始 reviewer log 已随旧机器丢失（见两文件页首的排查记录）。现已按提交/diff/报告/简报 + 实测反证出**重建版**并在页首显式标注；其中 `task-811-rereview.md` 附录 A 是 **2026-09-20 独立只读 reviewer** 对 `15c1ff0..18eaa5c` 的复审**原文**（非重建）。

## Task 1（协程探针 + 运行器 async 化）
- brief `task-1-brief.md`；worker 提交 `ccd08ef`（3 files）：`tests/async_probe_test.gd`(+uid)、`tests/run_tests.gd`（`_initialize`/`_run_suite` 改 await；SUITES +async_probe）。未走备份方案：`SceneTree._initialize` 可 await，实测一次跑绿。
- 绿灯：`[async_probe] 断言=2 失败=0`、13 套件失败=0、`main scene ready`、EXIT=0。
- 审查 `task-1-review.md`：**Approved with findings**，Critical=0/**Important=1**/Minor=1。
  Important：async 化后若套件协程永不恢复，`_initialize` 永久挂起，`quit()` 保证失效（反证：注入 6000s await → timeout 强杀 EXIT=124）。
- 修复 `632ff2e`：`run_tests.gd` 加全局看门狗 `create_timer(SUITE_TIMEOUT_SEC=300)` → `quit(1)`；计划 Task 1 同步。
  反证：看门狗临时改 2s + 注入挂死 → 打印「测试总超时」+ EXIT=1。
- scoped 复审 `task-1-rereview.md`：**通过**。残余 Minor：看门狗是整轮预算非逐套件；不覆盖同步死循环；test.sh 的 import/冒烟无超时。
- 交付点：分支顶端 `632ff2e`。

## Task 2（LlmProvider + MockLlmProvider）
- worker 提交 `a33a33a`（7 files）：`src/gm/llm_provider.gd`、`src/gm/providers/mock_provider.gd`、`tests/llm_test.gd`（各 +.uid）、`run_tests.gd` +1 行。
- 绿灯：`[llm] 断言=9 失败=0`、14 套件失败=0、EXIT=0。
- 审查 `task-2-review.md`：无 Critical/Important；Minor：我的 brief 期望「断言=10」实为 9（计划 Step 1 逐字只有 9 条），worker 如实记录、无需改码。
- 交付点 `a33a33a`。

## Task 3（LlmSettings）`2544bec`
`src/gm/llm_settings.gd`（+uid）；`[llm] 断言=16 失败=0`；审查并入 Tasks 3–5。

## Task 4（GmResponseParser）`b0d2258`
`src/gm/gm_response_parser.gd`（+uid）；`[llm] 断言=26`。

## Task 5（PromptBuilder）`d888989`
`src/gm/prompt_builder.gd`（+uid）、`tests/prompt_test.gd`（+uid）、SUITES +1；`[prompt] 断言=11`。
worker 发现计划测试 2 处自相矛盾并最小修正（系统提示含字面量 `<玩家行动>`；内部 flag 需 `_` 前缀），计划已同步。

## Tasks 3–5 合并审查 `task-345-review.md`
无 Critical/Important；Minor 8 条。修复轮（本提交）：M1 断言不再自指（字面量 4000，反证 MAX_NARRATION=100 会红）、M4 narration 必须字符串 + tags 非数组报错、M5 玩家输入剥离定界符（加注入断言）。
未修（登记）：M2 截断 200/800/1600 分支未测；M3 settings env/坏 JSON 未测；M7 台账类工件混入提交；M8 摘要只截条数不截字节（留 Task 8）。
修复后 `[llm] 28/0`、`[prompt] 13/0`、全绿。

## Task 6（StateOps.train_skill + §8#33）`0a86471`
`[gm] 63/0`、`[spell] 229/0`。

## Task 7（OpGuard）`38589b4`
`[llm] 39/0`。

## Tasks 6–7 合并审查 `task-67-review.md`
无 Critical/Important；Minor：F1 负支出未记警告、F2 spec 措辞与钳制不符、F3/F4 测试覆盖、以及未验证项「OpGuard 对畸形内层类型可能 `int({})` 崩溃」。
修复轮：`_to_int` 让畸形字段回退 0 不崩（反证：去掉后 `[llm]` 套件崩溃、哨兵捕获）、负支出加警告、spec §8 `set_magic_tier` 改为「钳到 ±1」、补 `_gm_rng_counter` 存档往返断言。
修复后 `[llm] 41/0`、`[save] 97/0`、全绿。

---

## Task 8（`GmResult.warnings` + `LlmGameMaster`）`fed4767`
- 工件：brief `task-8-brief.md`、报告 `task-8-report.md`；实现/测试逐字取自计划 `### Task 8` Step 3 / Step 1，无偏离。
- 改动（4 文件，+86）：`src/gm/game_master.gd`（+1：`GmResult.warnings: PackedStringArray`）、`src/gm/llm_game_master.gd`（新建 55 行：`MAX_ATTEMPTS=2` / `FALLBACK_NOTE`；provider 报错则重发原请求、JSON 解析失败则改发 `PromptBuilder.build_repair`；两次都失败 → 降级 `ScriptedGameMaster` 并追加降级说明；成功路径 `OpGuard.sanitize_detailed` → `deltas=guard.ops` / `warnings=guard.warnings` / `narration`·`tags` 透传）、`llm_game_master.gd.uid`、`tests/llm_test.gd`（+29，5 条断言）。
- TDD：Step 2 红——`Cannot infer the type of "gm3"` → `llm_test.gd` 无法加载、套件无法实例化，`总计失败=1，失败套件=1`、EXIT=1（与计划预期方向一致）。
- 绿灯：`[llm] 断言=46 失败=0`；16 套件失败=0；`main scene ready`；EXIT=0。提交 `fed4767`。
- 残余（报告登记，计划未要求）：`last_error` 内容、`MAX_ATTEMPTS` 恰为 2 次的调用计数、`warnings` 填充路径均无断言。

## Task 9（`TurnEngine.submit_async`）`878e9e3`
- 工件：brief `task-9-brief.md`、报告 `task-9-report.md`；实现/测试逐字取自计划 `### Task 9` Step 3 / Step 1。
- 改动（2 文件，+56/−9）：`submit()` 拆为 `_blank_result()` / `_pre_submit()`（死亡 + 自检挂起两守卫）/ `_resolve()`（`StateOps.apply` → **追加 `result.warnings` 到 `op_errors`** → `world.tick()` → 写回 `world.rng_state = rng.state_dict()`，保留 §8#34 的 rng 共享 → 第 15 回合自检）；`submit()` 对 `LlmGameMaster` 走 `push_error` + `blocked=true` 且**不推进回合**；新增 `submit_async()` 与 `submit()` 共用同一 `_blank_result`/`_pre_submit`/`_resolve`。
- TDD：Step 2 红——直接跑 `run_tests.gd` 得 `Nonexistent function 'submit_async'` + `[llm] 套件未正常结束（未调用 report）`，`总计失败=1`、EXIT=1。
- 绿灯：`[llm] 断言=51 失败=0`、`[gm] 断言=63 失败=0`（语义未变，死亡/自检/存档往返用例照跑）、16 套件失败=0、EXIT=0。提交 `878e9e3`。
- 残余（报告登记）：`submit()` 的 `LlmGameMaster` 分支只用一次性探针人工验证（未留单测）；`submit_async` 若 `gm.act` 永不恢复则调用方挂起（与 Task 1「看门狗是整轮预算」同一残余），Task 11 接线时须注意。

## Task 10（`OpenAiCompatProvider`）`c87959e`
- 工件：brief `task-10-brief.md`、报告 `task-10-report.md`；实现/测试逐字取自计划 `### Task 10` Step 3 / Step 1；nested 类型按简报写作 `LlmProvider.LlmRequest` / `LlmProvider.LlmResponse`。
- 改动（3 文件，+109）：`src/gm/providers/openai_compat_provider.gd`（新建 104 行：`from_settings` / `_chat_url()` 补 `/chat/completions` / `_build_headers()` 带 `Authorization: Bearer` / `_build_body()`（`json_mode` → `response_format={"type":"json_object"}`）/ `static _parse_http()` 结构化失败 / `complete()` 惰性建 `HTTPRequest` + timeout + `await request_completed` + `latency_ms`）、`.uid`、`tests/llm_test.gd`（+15，11 条纯函数断言，不联网）。
- TDD：Step 2 红——用临时 worktree `/tmp/hali-red`（起点 `878e9e3`）+ 新测试，复现 `Identifier "OpenAiCompatProvider" not declared` ×4，`总计失败=1`、EXIT=1；worktree 已 `remove --force` 清理。
- 绿灯：`[llm] 断言=61 失败=0`、16 套件失败=0、`main scene ready`、EXIT=0。提交 `c87959e`。
- 残余（报告登记）：`complete()` 的联网路径与真实 `HTTPRequest` 行为（`await request_completed`、timeout、4xx/5xx）不在单测内，留 Task 11 / 人工联调。

## Task 11（UI 异步接线）`15c1ff0`
- 工件：brief `task-11-brief.md`、报告 `task-11-report.md`；逐字取计划 `### Task 11` Step 2。
- 改动（仅 `src/ui/main.gd`，+13/−3）：新增 `_build_gm()`（`LlmSettings.load_from().is_configured()` → `LlmGameMaster.new(OpenAiCompatProvider.from_settings(self, settings), ScriptedGameMaster.new(rng))`；未配置 → 状态行提示 + `ScriptedGameMaster`）；`_on_start_pressed`/`_on_load` 改用 `_build_gm()` 且传同一 `rng` 实例（保 §8#34）；`_on_command_submitted` 改协程：`command_edit.editable=false` → `await engine.submit_async(text)` → 结束后恢复 `editable` 并清空。
- 无新增单测（纯接线，计划未要求）；回归面 = 既有 16 套件 + 冒烟。
- 绿灯：`[gm] 63/0`、`[llm] 61/0`、16 套件失败=0、`main scene ready`、EXIT=0。提交 `15c1ff0`。
- 残余（报告登记）：UI 协程路径无自动化覆盖（headless 冒烟只验证 `_ready` + 脚本可解析）；provider 永不恢复时输入会被锁在「世界正在回应…」（无 UI 层看门狗），留人工验收/计划 03 裁定。

## Tasks 8–11 合并审查（首轮）`task-811-review-brief.md`
- 对象：`fed4767`(Task 8)、`878e9e3`(Task 9)、`c87959e`(Task 10)、`15c1ff0`(Task 11)；审查包 `review-fed4767^..15c1ff0.diff`；核对项 7 条 + 反证 3 条。
- 结论：**Approved with findings**——Critical=0 / **Important=1（F3）** / Minor=5（F1/F2/F4/F5/F6）。
- 发现表：
  | ID | 严重度 | 位置 | 内容 |
  | --- | --- | --- | --- |
  | F1 | Minor | `tests/llm_test.gd` | `OpGuard` 的 warning 必须进 `op_errors`，缺可判别断言 |
  | F2 | Minor | `openai_compat_provider.gd:_parse_http` | `choices[0]` 非对象时 `as Dictionary` 硬错 → 返回 nil → 降级链断 |
  | F3 | **Important** | `src/ui/main.gd` | 等待 LLM 期间只禁用了 `command_edit`，整排按钮仍可点（「读档」可在 in-flight 回合替换 world/engine） |
  | F4 | Minor | `src/ui/main.gd:_on_load`/`_build_gm` | 「未配置 LLM」提示被 `status_label.text` 覆盖 |
  | F5 | Minor | `tests/llm_test.gd` | 同步 `submit()` 对 `LlmGameMaster` 的拒绝分支无断言 |
  | F6 | Minor | `openai_compat_provider.gd:complete` | 失败 `error` 可能回显服务端 body，未脱敏 `api_key` |
- 未验证清单（留人工）：真实 `HTTPRequest` 链路（`await request_completed`/`add_child`/timeout/4xx-5xx）、`api_key` 掩码的端到端执行、提示注入的实际绕过率、UI 等待期按钮状态（headless 不可观测）。

## Tasks 8–11 修复轮 + scoped 复审 `a48f108`
- 修复（5 文件：2 源 + 1 测试 + 计划 + 审查包）：
  - **F1**：`[llm]` 新增「OpGuard warning 进入 op_errors」断言（mock 队列第二项改 `add_money 999999` → 触发「金钱收益已钳到上限」warning）；计划 Task 9 同步。
  - **F5**：新增「submit() 拒绝异步 GM」「被拒的同步提交不推进回合」2 条断言；计划同步。
  - **F2**：`_parse_http` 对 `choices[0]` 非对象返回结构化错误「响应 choices[0] 不是对象」；新增断言 `_parse_http(200, '{"choices":[123]}')` → `ok=false` 不崩。
  - **F6**：`complete` 对失败 `error` 做 `api_key` → `***` 掩码。
  - **F3（Important）**：`button_row` 升为成员 + 新增 `_set_buttons_enabled()`，`_on_command_submitted` 首尾调用，等待期禁用整排按钮。
  - **F4（部分）**：`_build_gm` 未配置提示改 `+=`（不再覆盖状态行）——读档路径仍随后被 `status_label.text` 覆盖，故首轮未闭合。
- 绿灯：`[llm] 61 → 65/0`、16 套件失败=0、`main scene ready`、EXIT=0。提交 `a48f108`。
- **反证（2026-09-20 在 `main` 上实测复现，非转述）**：
  ① 注释掉 `turn_engine.gd:_resolve` 的 `for warning in result.warnings` 循环 → `[llm] 断言=65 失败=1`、`总计失败=1`、EXIT=1；② `llm_game_master.gd` 改 `r.deltas = parsed.ops`（绕过 `OpGuard.sanitize_detailed`）→ `[llm] 断言=65 失败=1`、EXIT=1；③ `_build_gm()` 强制返回 `ScriptedGameMaster` → 冒烟仍 `main scene ready`、EXIT=0（headless 对 UI/LLM 接线不可观测）。三条均已还原，工作区干净。
- scoped 复审（`task-811-rereview-brief.md`，对象 `15c1ff0..a48f108`）：**F2/F3 ADDRESSED 且反证承重**；**F4 仍未闭合**；无新缺陷；通过。
- 残余：F4（由下一条闭合）；UI 层无超时/取消（沿用 Task 9/Task 11 登记）。

## F4 闭合（读档路径状态行顺序）`18eaa5c`
- `_on_load` 调整顺序：先 `status_label.text = PanelFormatter.status_line(...)`，**再** `engine = TurnEngine.new(world, _build_gm(), rng)`，使 `_build_gm()` 的「未配置 LLM」追加提示得以保留（1 文件，+2/−1）。
- 该修复当时**没有**对应的复审文件；2026-09-20 补 scoped 复审：按 §D2 派**独立只读 reviewer**（内置 `reviewer` agent，read/grep/find/ls，`deepseek-flash` + thinking high），范围 `15c1ff0..18eaa5c`，新增审查包 `review-15c1ff0..18eaa5c.diff`。
- **结论：通过 —— F1–F6 全部 ADDRESSED，F4 已真正闭合**（读档路径不再覆盖提示；创建路径 `_on_start_pressed` 之后无 `status_label.text` 赋值，同样保住提示；`_on_save`/`_on_status`/`_on_audit` 等分支均不写状态行）。原文见 `task-811-rereview.md` 附录 A。
- 复审另报 3 条 Minor：①首条指令后提示被正常状态行刷新（**接受**，计划既定行为）→ 登记 HANDOFF §8#59；②`await submit_async` 不恢复则输入与按钮停在禁用态、UI 无超时/取消 → 登记 HANDOFF §8#58；③**计划文档漂移**：计划 `Task 11` 的 `_on_load` 片段仍是旧顺序（按片段重实施会复现 F4）→ **已同步修正计划**并加注 `18eaa5c`（HANDOFF §8#60）。

## Task 12（文档收尾：README / HANDOFF / 台账）`1f82483` + 合入 `main` `d885cf9`
- **Task 12 由控制器直接执行，无独立 brief / report / reviewer 工件**（纯文档；NEXT-STEPS A7 采「在台账注明」方案）。
- `1f82483`（32 文件，+1607）：README 补计划 02 状态/`src/gm/providers/`/LLM 配置说明；HANDOFF 补计划 02 分支、测试数、`§8#3/#33` 收口状态、LLM 配置与降级行为；并**补齐 Tasks 2–11 的 brief / report / 审查简报耐久副本**（即本文件所在的 `docs/sdd/plan-02-llm-narrative/`）。
- `d885cf9`：HANDOFF §0 记录计划 02 已合入 `main`，交付点 = `main` 顶端。
- 绿灯：全 16 套件失败=0、`main scene ready`、EXIT=0。

## 台账覆盖核对（2026-09-20）
Tasks 1–12 均有条目且各自可指到提交哈希与断言数：1 `ccd08ef`+`632ff2e` / 2 `a33a33a` / 3 `2544bec` / 4 `b0d2258` / 5 `d888989`（+`9920ba0` 修复）/ 6 `0a86471` / 7 `38589b4`（+`59a70ed` 修复）/ 8 `fed4767` / 9 `878e9e3` / 10 `c87959e` / 11 `15c1ff0`（+`a48f108`、`18eaa5c` 修复）/ 12 `1f82483` + `d885cf9`。
**已知缺口（部分收口）**：首轮审查与复审的**原始 reviewer log 已随旧机器丢失**（`.superpowers/sdd/2026-09-19-...` 未随源码走，本机 `~/.pi/agent/sessions/--E--Hali--/subagent-artifacts/` 只有计划 01 的 2026-09-18 工件）。现已补 **重建版** `task-811-review.md` + `task-811-rereview.md`（页首标注非原文，依据 = 提交/diff/报告/简报 + 实测反证）；`task-811-rereview.md` 附录 A 含 2026-09-20 独立只读复审**原文**。**残余不可恢复**：首轮 reviewer 自己的反证过程与措辞已不可复原。
**追加（2026-09-20）**：对首轮范围补了一次**独立盲审重跑** `task-811-review-rerun.md`（快照 `15c1ff0` + 不告知首轮结论）。结果 11 条（P1×2 / P2×9）：独立复现首轮 3 条（重跑 F1/F3/F9② = 首轮 F2/F3/F4，均已修）、确认 1 条已知债务（降级路径直改 world）、**新报 5 条至今仍成立**的问题 → 登记 `HANDOFF §8#61–#65`；它也反过来证明重建版的**严重度列只是推定**（同一 `choices[0]` 缺陷：重建标 Minor、重跑标 P1）。

