# 下一步待办 · 哈利·波特·魔法纪元

> 用途：换机器后接手**第一份**要读的执行清单（配合 `HANDOFF.md`）。HANDOFF 讲「现状与铁律」，本文件讲「接下来做什么、按什么顺序、验收标准是什么」。
> 最后更新：2026-09-20（**队列 A（A1–A7）已全部完成**，分支 `docs/plan-02-closeout` → `main`；计划 01 + 计划 02 均已合入 `main`）。
> 维护规则：每完成一项就在方框里打勾并补上提交哈希；**换机器前必须回来更新本文件**。

---

## 0. 交接核对（换机器后先做这三件事）

```bash
cd /e/Hali
git fetch origin && git status -sb     # 期望：工作区干净
git log --oneline -1                   # 期望：读到本文件的那次 docs 提交（历史里含 d885cf9 / 1f82483 / a48f108 / 15c1ff0 / 38589b4）
bash tools/test.sh                     # 期望：EXIT=0；16 套件失败=0；main scene ready
```

引擎：Windows + Git Bash，**Godot 4.7.2 stable（非 .NET）**，两个 exe 放仓库根（不入库，见 HANDOFF §2）。
基线事实（本次核对确认）：`main` == `plan-02-llm-narrative` == `origin/main` == `origin/plan-02-llm-narrative` == `d885cf9`；工作区干净。

基线测试绿（本文件写下时实测）：

```
[harness]=8  [registry]=26  [money]=18  [magic_level]=48  [model]=49  [clock]=47
[world_tick]=104  [creation]=176  [spell]=229  [gm]=63  [panel]=71  [selfcheck]=32
[save]=97  [async_probe]=2  [prompt]=13  [llm]=65
==== 总计失败=0，失败套件=0 ====   ALL TESTS PASSED
main scene ready, godot=4.7.2-stable (official)   全部通过。
```

---

## A. 队列 A —— 计划 02 文档收口（**建议最先做，一行代码都不用改**）

> ✅ **本队列已于 2026-09-20 全部完成（A1–A7）**，分支 `docs/plan-02-closeout`，合入 `main`。提交：`0367eb7`(A1) · `18a1cf5`(A1 勾选 + A2 缺失核对) · `c17263f`(A4/A5/A6/A7) · `e6fdc24`(A2/A3) · 本勾选提交。
> 遗留说明：A2 的**原始 reviewer log 已随旧机器丢失**，已用**重建版**代替并在工件页首显式标注（见 A2 条目）；不可恢复的部分已登记。
> 后续追加（采 A2 方案 (2)）：对首轮范围做了一次**独立盲审重跑** → `task-811-review-rerun.md`（11 条：P1×2/P2×9；独立复现首轮 3 条，新报 5 条仍成立的问题 → `HANDOFF §8#61–#65`）。

计划 02 的功能与测试已全部完成并绿灯，但「过程台账」的耐久副本（`docs/sdd/`，见 HANDOFF §7 的交接规则）在收尾时没跟上。以下 7 项都是**只动文档**，风险低、可一次分支批量完成。

建议分支：`git checkout main && git checkout -b docs/plan-02-closeout`；每项完成后重跑 `bash tools/test.sh`（文档改动也应保持绿灯）再提交。

- [x] **A1 补录计划 02 耐久台账 Tasks 8–12**（`0367eb7`）
  - 现状：`docs/sdd/plan-02-llm-narrative/progress.md`（46 行）只记到 **Tasks 1–7**；Tasks 8–12 一条都没有。`.superpowers/.../progress.md`（工具工作区，被 gitignore）同样只有 1–7，所以**耐久副本真的缺**。
  - 要做：按已有 1–7 的写法补 8–12 条目（brief → worker 提交 → 绿灯断言数 → 审查结论/严重度 → 修复提交 → scoped 复审结论 → 残余）。
  - 素材：提交 `fed4767`（Task 8 `LlmGameMaster`）、`878e9e3`（Task 9 `submit_async`）、`c87959e`（Task 10 provider）、`15c1ff0`（Task 11 UI）、`a48f108`（Tasks 8–11 修复轮）、`18eaa5c`（F4 修复）、`1f82483` / `d885cf9`（Task 12 文档收尾）；报告 `task-8/9/10/11-report.md`；审查包 `review-*.diff`。
  - 验收：Tasks 1–12 在台账里都有条目，且每条都能指到提交哈希与断言数。

- [x] **A2 把 Tasks 8–11 审查结论提升为耐久副本** —— 按下文核对结论的 **(a) 重建版**方案完成：`task-811-review.md` + `task-811-rereview.md` 已落盘，页首均显式标注「非 reviewer 原文」及重建依据。
  - 现状：`docs/sdd/plan-02-llm-narrative/` 只有 `task-811-review-brief.md`、`task-811-rereview-brief.md`；**缺** `task-811-review.md` 与 `task-811-rereview.md`。
  - 正文只存在于被忽略的 `.superpowers/sdd/2026-09-19-hp-magic-era-02-llm-narrative/task-811-reviewer.log`（首轮，11.7KB）与 `task-811-rereviewer.log`（复审，9.0KB）。
  - 要做：把两份 log 的**完整结论**（发现表 F1–F9、反证表、未验证清单）原样落进 `docs/sdd/plan-02-llm-narrative/`（可清理成干净 md），提交。
  - 验收：`docs/sdd/plan-02-llm-narrative/` 下有 `task-811-review.md` + `task-811-rereview.md`，内容与 log 一致且无省略。
  - ⚠️ **核对结论（2026-09-20，在 `main` 上实测）**：两份 log **在本机不存在**，无法「原样落进」。已排除的可能位置：`.superpowers/sdd/2026-09-19-hp-magic-era-02-llm-narrative/`（目录不存在，本机 `.superpowers/sdd/` 只有计划 01 的 2026-09-18 目录）、`~/.pi/agent/sessions/--E--Hali--/subagent-artifacts/`（只有 2026-09-18 的计划 01 worker/oracle/reviewer 工件，无 09-19）、`git log --all`（从未入库）、stash（空）。**结论：文件已随旧机器丢失，`内容与 log 一致` 这条验收标准不可达**。
  - 可行的替代（已裁定）：**采 (a)**——出重建版并显式标注「非 reviewer 原文」。已落盘：`task-811-review.md`（首轮：范围/结论 Approved with findings/发现表 F1–F6/反证表/未验证清单）与 `task-811-rereview.md`（修复轮复审重建 + F4 闭合 + 2026-09-20 独立只读复审原文）。
  - ℹ️ **数目订正**：本项写的「发现表 F1–F9」与 A3 的「首轮审查 6 条」不一致；按 A3 + 修复轮 diff 核对，实为 **F1–F6（6 条）**，无 F7–F9。
  - ➕ **追加（方案 (2)）**：`task-811-review-rerun.md` —— 对**同一范围**（`fed4767^..15c1ff0`）的**独立盲审重跑**（快照 + 不告知首轮结论）。共 11 条（P1×2/P2×9）：独立复现首轮 3 条（均已修）、确认 1 条已知债务、**新报 5 条至今仍成立**的问题（已登记 `§8#61–#65`）。两条 P1 中，`choices[0]`（重跑 F1 = 首轮 F2）已在 `a48f108` 修掉；UI 无失败恢复（重跑 F2）登记为 `§8#62`。

- [x] **A3 补记 F4 的修复与最终结论** —— 已在 `task-811-rereview.md` §2 + 附录 A 闭合：**F1–F6 全部 ADDRESSED、F4 已真正闭合**（指向 `18eaa5c`）。
  - 首轮审查 6 条：F1/F5/F6（Minor，已修）、**F3 Important**（等待期按钮行未禁用，已修）、**F2**（`choices[0]` 非对象导致降级链断，已修）、**F4 Minor**（`_on_load` 里 `_build_gm()` 的「未配置 LLM」提示被下一行 `status_label.text` 覆盖）。
  - 复审（对比 `15c1ff0..a48f108`）：F2/F3 **ADDRESSED** 且反证承重，**F4 当时仍未闭合**；此后 `18eaa5c` 才修掉（读档路径先设状态行再建 GM）。该修复**没有**对应的复审文件。
  - 要做：在 A2 的复审记录里补一条「F4 后续由 `18eaa5c` 修复 + 结论」；若要更严格，可对 `15c1ff0..18eaa5c` 起一份 scoped 复审（改动 1 文件 2 行，10 分钟内可完成）。
  - 验收：F4 在耐久工件里状态为「已闭合」，并指到 `18eaa5c`。
  - 执行记录：按 §D2 派了**独立只读 reviewer**（内置 `reviewer` agent，read/grep/find/ls，`deepseek-flash` + thinking high，与主会话同模型）对 `15c1ff0..18eaa5c` 做 scoped 复审，新增审查包 `review-15c1ff0..18eaa5c.diff`；结论 **通过**（逐项证据 + 未验证清单原文见 `task-811-rereview.md` 附录 A）。它另报 3 条 Minor：①提示在首条指令后消失（**已接受**，计划既定行为）、②UI 等待期无超时/取消（**已登记** HANDOFF §8#58）、③**计划文档 `_on_load` 片段漂移**（按片段重实施会复现 F4）→ **已同步修正计划**。

- [x] **A4 订正 HANDOFF §1 / §9 的过期分支信息**（`c17263f`）
  - `HANDOFF.md` §1 表格仍写「执行分支 `main`（顶端 `026efe3`）」「当前 HEAD `plan-01-core-foundation` == `main` == `026efe3`」，与 §0 及实际 `d885cf9` 冲突；§9 首行仍写「分支：`plan-01-core-foundation`」。
  - 要做：改成「执行分支 `main`；计划 01 顶端 `026efe3` 的历史见 §1 说明；计划 02 已合入 `main`（`d885cf9`）；后续计划从 `main` 拉新分支」，§9 同步。

- [x] **A5 订正 HANDOFF §2 的期望输出样例**（`c17263f`）
  - 样例里写的是 13 套件、`money=15 / magic_level=22 / panel=65 / selfcheck=26`、无 `[async_probe]`；实测已变为 16 套件、`18 / 48 / 71 / 32`，并新增 `[async_probe]=2 / [prompt]=13 / [llm]=65`（差值是加固批次 `e094a52` + 计划 02，**不是回归**）。
  - 要做：把样例换成 §0 上方那段实测输出；保留「`[probe]` 故意失败」的说明。

- [x] **A6 订正 README 的「进行中」措辞**（`c17263f`）
  - `README.md:13`「计划 02 在分支 `plan-02-llm-narrative` 上进行」、`:35`「### 计划 02 · LLM 叙事引擎（进行中）」、`:37`「后续计划：02 LLM 叙事引擎（进行中）；03…」。
  - 要做：改为「计划 02 已完成并合入 `main`」，后续计划列表改为从 **03 派系与政治经济** 起。

- [x] **A7 Task 12 工件说明** —— 采方案 2（成本最低），已在 A1 的 `progress.md` 台账中注明「Task 12 由控制器直接执行、无独立 brief/report/reviewer 工件」（`0367eb7`）。
  - `docs/sdd/plan-02-llm-narrative/` 无 `task-12-brief.md` / `task-12-report.md`（Task 12 是纯文档收尾，由控制器直接执行 `1f82483`）。
  - 要做：三选一 —— 补一页极简 brief+report；或在 A1 台账里注明「Task 12 由控制器执行、无独立工件」；或保持现状但在 `progress.md` 顶部写清。（**建议第二种，成本最低**）

---

## B. 队列 B —— 计划 03 与人工验收

- [ ] **B1 人工 GUI 验收（HANDOFF §6 第 1 项 / §8#55，**只能人来跑**）**
  - `./Godot_v4.7.2-stable_win64_console.exe --path .`，按计划 01 Step 6 的 8 项清单逐项确认：创建界面 7 个下拉 / 哑炮角色 / 练魔药收益递减 / 打工加钱 / 魔法·关系·势力面板 / 存档·读档 / 重启后创建界面直接读档 / 第 15 回合自检挂起与「确认自检」。
  - 计划 02 追加：等待 LLM 期间 `command_edit` 与整排按钮置灰、结束恢复；未配置时状态行显示提示（创建路径与**读档路径**都要看，后者正是 F4）。

- [ ] **B2 真机 LLM 联调（HANDOFF §0「下一步」）**
  - 写 `user://llm_settings.json`（Windows：`%APPDATA%\Godot\app_userdata\<项目名>\`）或设 `HALI_LLM_API_KEY`；跑一回合，确认：拿到真实叙事、`ops` 生效、等待期窗口不卡死、断网/超时自动降级为 `ScriptedGameMaster` 且有提示。
  - 已知未验证项（来自 `task-811-rereviewer.log`）：真实 `HTTPRequest` 链路（`await request_completed`、`add_child`、timeout、4xx/5xx）、`api_key` 掩码的端到端执行、提示注入的实际绕过率。

- [ ] **B3 计划 03「派系与政治经济」启动**
  - 边界见计划 02 spec §15：03 派系与政治经济（`world_vars` 之外的九大支柱）→ 04 神奇生物生态与区域危险度 → 05 NPC 自主与信息可信度 → 06 多世代传承与世界记忆。
  - 流程（沿用计划 01/02）：`git checkout main && git checkout -b plan-03-...` → brainstorming 探需求 → 写 spec（`docs/superpowers/specs/`）→ writing-plans 出计划（`docs/superpowers/plans/`）→ 逐任务 brief → worker → 绿灯 → 报告 → 只读 reviewer → 台账 → 合入 `main`。
  - spec 里要顺带处理的世界观级遗留：`power_panel` 7 标签映射到 4 个 `world_vars`（HANDOFF §8#7）、`rumors.weight` 与 `wand_cores.rarity` 声明了但未生效（§8#16/#21）。

---

## C. 仍然开放的人类裁定项（HANDOFF §8 中与后续计划直接相关的）

计划 03+ 动到相应模块时**顺手裁定**，不必单开批次：

| 编号 | 内容 | 何时触发 |
| --- | --- | --- |
| §8#3 | `ScriptedGameMaster` 降级路径仍直改世界（LLM 主路径已纠正） | 是否正式收口，或永久登记为债务 |
| §8#4 | 哑炮 `effective_rate` 返回 0.95 ⇒ 有 5% 施法成功率，与正典「无法施展咒语」冲突；且 `base_rate(SQUIB)=1.0` 超出文档化值域 | 魔法/施法相关任务 |
| §8#5 | `Money` 负值显示未定义（`"0加隆 -2西可 -16纳特"`），已被 `player_panel`/`power_panel` 输出到 UI | 任何经济/债务玩法 |
| §8#6 | 大师级失败率上界 0.02 的开/闭区间歧义 | 平衡性任务 |
| §8#9 / #47 | `SaveCodec._validate_payload` 只做顶层类型校验；内层值类型错可能静默降级 | 存档格式 v2 |
| §8#19 | `WorldState.game_seed` 仍是裸 int，>2^53 过 JSON 往返会丢精度（会让读档后世界演化静默分叉） | 存档格式 v2（建议与嵌套校验一起做） |
| §8#26 | 载入路径不重跑 `validate_choices`，手改存档可塞进非法组合 | 存档格式 v2 或载入流程 |
| §8#49 | `SaveStore.save` 无 temp+rename，写盘中断会毁旧档 | 存档格式 v2 |
| §8#55 | 人工 GUI 验收缺口 | 见 B1 |
| §8#58 | 计划 02 新增：UI 等待期无超时/取消（`await submit_async` 不恢复则输入与按钮停在禁用态） | 计划 03 动 UI 时，或「设置界面」小计划 |
| §8#61–#65 | 计划 02 **重跑盲审**新增：降级原因未透出（spec §9 偏差）/ UI 无失败恢复 / provider 泄漏 `HTTPRequest` 节点 / 测试可判别性批次（repair·准恒真·无负向断言）/ 契约文档与类型守卫漂移 | 计划 03，或下一次加固批次（多数是廉价修） |

---

## D. 协作约定（计划 01/02 已固化，续做必须遵守）

1. **子代理必须用** `pi -p --provider deepseek --model deepseek-flash ...`（与主会话同模型），不要用 harness 默认模型。
2. **每任务六步**：brief → worker 实现 → 自跑 `bash tools/test.sh` 到绿 → **先写报告文件再返回** → 只读 reviewer（`pi -p --tools read,bash`）审 diff → 台账记录。
3. **提交前必须有绿灯**；报告里要贴 `tools/test.sh` 的原始输出（含断言数）。
4. **审查者只读**；Critical/Important 要么当轮修掉 + scoped 复审，要么明确登记进人类批次（不得静默放过）。
5. **耐久副本**：任务完成后把 brief / report / review / 审查包 `review-<from>..<to>.diff` 从 `.superpowers/sdd/.../` 同步到 `docs/sdd/<plan>/`，与代码同一次提交（HANDOFF §7）。**A1–A3 就是在补这条规则的历史欠账。**
6. **新增测试套件**必须把路径追加到 `tests/run_tests.gd` 的 `SUITES`，否则不会被执行。
7. **正典优先**：计划文本与《哈利·波特·魔法纪元.md》冲突时改计划、不要顺着错的计划写实现，并在报告里写明依据行号（HANDOFF §4 第 9 条）。
8. **内容进 `data/*.json`**，代码不硬编码内容；`to_dict()` 只放 JSON 原生类型并过 `JsonUtil.normalize()`；新脚本连 `.gd.uid` 一起 `git add`。

---

## E. 一页速查

| 项 | 值 |
| --- | --- |
| 交付点 | `main` 顶端（本文件提交后见 `git log --oneline -1`） |
| 计划 01 计划 / 台账 | `docs/superpowers/plans/2026-09-18-...-01-core-foundation.md` / `docs/sdd/plan-01-core-foundation/progress.md` |
| 计划 02 计划 / spec / 台账 | `docs/superpowers/plans/2026-09-19-...-02-llm-narrative.md` / `docs/superpowers/specs/2026-09-19-...-02-llm-narrative-design.md` / `docs/sdd/plan-02-llm-narrative/progress.md` |
| 测试入口 | `bash tools/test.sh`（`0` 全绿 / `1` 失败 / `2` 找不到引擎） |
| 正典规格 | `哈利·波特·魔法纪元.md`（仓库根，勿移动改名） |
| 下一步第一件事 | **A1**（补计划 02 台账 Tasks 8–12），或先做 B1 人工验收 |
