# 下一步待办 · 哈利·波特·魔法纪元

> 用途：换机器/换会话后接手**第一份**要读的执行清单（配合 `HANDOFF.md`）。HANDOFF 讲「现状与铁律」，本文件讲「接下来做什么、按什么顺序、验收标准是什么」。
> 最后更新：2026-09-20（**计划 03a「派系与政治骨架」Task 1–11 已完成并推送**到分支 `plan-03-factions`；**人类要求暂停**——他要改一个小计划 + 正在整理字体/美术/声音素材。队列 A/B1 早在 `main` 上完成。）
> 维护规则：每完成一项就在方框里打勾并补上提交哈希；**换机器前必须回来更新本文件**。

---

---

## 0. 交接核对（换机器后先做这三件事）

```bash
cd /e/Hali
git fetch origin && git status -sb     # 期望：工作区干净
bash tools/test.sh                     # 期望：EXIT=0；全部套件失败=0；main scene ready；4 步全过
```

引擎：Windows + Git Bash，**Godot 4.7.2 stable（非 .NET）**，两个 exe 放仓库根（不入库，见 HANDOFF §2）。
基线事实：`main` == `origin/main`；工作区干净。**以 `git log --oneline -1` 为交付点**（本文件不再钉死 HEAD 哈希）。

基线测试绿（本文件写下时实测，`tools/test.sh` 已扩为 4 步）：

```
[harness]=8  [registry]=26  [money]=18  [magic_level]=48  [model]=49  [clock]=47
[world_tick]=104  [creation]=176  [spell]=229  [gm]=63  [panel]=71  [selfcheck]=32
[save]=97  [async_probe]=2  [llm]=84  [prompt]=13  [debug_mirror]=23
==== 总计失败=0，失败套件=0 ====   ALL TESTS PASSED
main scene ready, godot=4.7.2-stable (official)
[HALI] PROBE-APPEND-MARK（第 4 步：HALI_DEBUG_LOG=1 镜像冒烟）   全部通过。
```

---

## 0.5 恢复指引（新会话开场照这个做）

```bash
cd /e/Hali
git fetch origin && git status -sb        # 期望：干净；当前分支 plan-03-factions（**尚未合入 main**）
git log --oneline -1                      # 期望：HEAD = 本文件那次 docs 提交
bash tools/test.sh                        # 期望 EXIT=0；18 套件、**1746 断言**、失败=0
timeout 300 bash tools/b1_acceptance.sh   # 期望 EXIT=0；探针 105 断言 / 0 失败（会临时移走 llm_settings.json 并逐字还原）
```

> 📋 **新会话开场语**：整段可直接复制的内容在 [`NEXT-SESSION-PROMPT.md`](NEXT-SESSION-PROMPT.md)（体检命令 + 读文件顺序 + 接下来做什么 + 流程铁律 + 运行纪律）。下面是同一份信息的展开版。

**读文件顺序（不要跳）**

1. `HANDOFF.md` —— 现状、铁律、§4 踩坑、§7 耐久副本规则、§8 待裁定项
2. `NEXT-STEPS.md`（本文件）—— 接下来做什么
3. `docs/sdd/plan-03a-factions/progress.md` —— **03a 的耐久台账**：每任务的提交哈希 / 断言数 / 审查结论 / 挂账 Minor + 暂停点
4. `docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md` —— 03a 计划（13 任务）。⚠️ 它的文本在 Task 4–11 期间被控制器按实跑**修过多次**（阈值 0.45→0.28、`state_digest` 改为加键、`tick()` 片段用 `self`、`engine==null` 立即恢复…）⇒ **以计划文件当前文本为准**，且 Task 12/13 的 brief 必须重新抽取
5. `docs/superpowers/specs/2026-09-20-hp-magic-era-03a-P-presentation-design.md` —— 表现层与素材接线**草稿 spec**（待人类评审）
6. `docs/superpowers/specs/2026-09-20-hp-magic-era-03-factions-design.md` —— 03a 设计 spec（§7.4/§13.2 有勘误段）

**工作流（沿用，别自创）**：subagent-driven-development
`scripts/task-brief PLAN N` 抽 brief → 派 `worker`(deepseek-flash) 实现 → 自跑绿灯 → **先写报告文件再返回** → `scripts/review-package PLAN BASE HEAD` 生成审查包 → 派只读 `reviewer` → 处置 findings（Minor 记台账并按归属转给后续任务；Critical/Important 走修复轮 + scoped 复审，最多 5 轮）→ 更新台账 → **推送**。

**运行纪律（全是实跑踩出来的，见 `HANDOFF §4`）**

1. 每个任务完成后 `git push origin <branch>`（别攒着）；
2. 探针/破坏实验一律加**外部** `timeout`（例如 `timeout 300 bash tools/b1_acceptance.sh`）；
3. 每组破坏实验后 `tasklist | grep -i godot` 查残留进程（有则 `taskkill //PID <PID> //F`）；
4. 破坏实验的还原用**副本备份**（`cp` 回来 + md5 校验），**不要**用 `git checkout -- <file>` 对付未提交改动（已冲掉过一次实现者自己的改动）；
5. **不要并发跑两个 headless Godot 实例**（会争 `.godot` 缓存）；
6. 派 reviewer 时**限制阅读预算**（只读 1 次 diff、≤4 次 grep、报告 ≤120 行、不许整文件打印源码）——否则容易在长独白里撞上下文上限而失败（已发生过一次，重派时缩小输入即通过）。

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

## B. 队列 B —— 计划 03a 收尾 + 表现层（**当前暂停点**）

> ⚖️ **状态（2026-09-20）**：计划 03a 的 **Task 1–11 已完成并推送**（分支 `plan-03-factions`，**尚未合入 `main`**）；**人类要求暂停**，因为他要改一个小计划、并在整理字体/美术/声音素材。
> **恢复第一件事**：读 `docs/sdd/plan-03a-factions/progress.md`（耐久台账）+ 本节。

- [x] **B3 计划 03「派系与政治经济」启动** —— 已拆为 03a/03b/03c；**03a 已完成 Task 1–11**
  - 分支 `plan-03-factions`｜计划 `docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md`（13 任务）｜spec `docs/superpowers/specs/2026-09-20-hp-magic-era-03-factions-design.md`
  - 已完成：T1 内容表(17 派系 / 4 政体 / 5 政治事件) · T2 规则层(初始化 / 机构控制权 / 权力四角 / 政体推导) · T3 玩家 `standing` + 3 op + `OpGuard` + 存档校验 · T4 `evolve` 演化 + 政体刷新 · T5 `tension` + 政治事件 + `tick()` 接线 · T6 信息保护 `reveal()` + 传闻揭示 · **T7 势力面板重写（修 `§8#7`）** · T8 提示词只暴露已揭示派系（Q4） · T9 离线替身派系关键词 · T10 UI 看门狗 + provider 卫生（`§8#58/#62/#63`） · T11 降级原因 + 测试可判别性 + 鸭子类型（`§8#61/#64/#65`）
  - 质量数据：18 套件 **1746 断言**（起点 1048）；审查 **Critical 0**；Important 5 条全部修复或按人类裁定收口；修复轮 4 轮（T4/T5/T6/T10）；B1 验收探针 105 断言全过
- [ ] **B4 计划 03a 续做（暂停点；恢复后从这里继续）**
  - **Task 12**（未开始）：`§8#69` 哑炮不进霍格沃茨（`house_id="none"`）· `§8#70` 创建界面姓名默认空 + 性别下拉 · `§8#16` `rumors.weight` 生效 · `§8#21` `wand_cores.rarity` 生效（新增 `RngService.stream_pick_weighted`）
  - **Task 13**（未开始）：全量回归（`tools/test.sh` + `b1_acceptance.sh`）→ 把新工件同步进 `docs/sdd/plan-03a-factions/`（**T1–T11 的副本已在暂停时预先落盘**）→ 更新 README/HANDOFF/NEXT-STEPS → `git checkout main && git merge --no-ff plan-03-factions` → 推送
  - ⚠️ Task 12/13 的 brief 必须**重新抽取**（计划文本在 T4–T11 期间被改过多次）
- [ ] **B5 计划 03a-P「表现层与素材接线」**（人类正在整理素材；草稿 spec 待评审）
  - 草稿 spec：`docs/superpowers/specs/2026-09-20-hp-magic-era-03a-P-presentation-design.md`（现状审计 / 素材契约 / 5 个 seam / 任务草案 P1–P5 / 7 个待人类回答的问题）
  - **硬前提（已实测）**：Godot 内置字体**不含 CJK 字形**（`你/魔/法/あ/한` 全 `has_char=false`，只有 `A` true）⇒ 中文界面**必须自带 CJK 字体**；建议把「未配置 CJK 字体 → `presentation_test` 失败」钉进 CI
  - 素材契约：`assets/{fonts,ui,emblems,backdrops,portraits,audio/{bgm,sfx,ambient},credits.md}` + `data/presentation.json`（键→路径，**全可选、缺则回退**）+ `data/audio_cues.json`（cue→音效/BGM/音量）
  - 插入位置：**Task 12 之后、Task 13 收尾之前**；**若素材先到，P1–P3 可提前**（与 Task 12 的文件重叠几乎为零）
  - 一条已挂账的 UX 修复也归这里：`LlmGameMaster` 无 fallback 分支的**降级原因双显**（叙事里 `（原因：X）` + `warnings` 也打印）
  - **待人类回答的 7 问**：① 字体格式/套数（TTF/OTF、是否含繁体）② 图片格式/尺寸/是否 9-slice 与按钮三态 ③ 音频格式与循环 ④ 命名策略（逻辑键 vs 自带映射表）⑤ 槽位清单（时代背景/学院徽记/派系徽记/地点插图/玩家立绘/NPC 立绘/UI 皮肤/Logo）⑥ 大文件是否走 Git LFS ⑦ `credits.md` 必填字段
- [ ] **B2 真机 LLM 联调（剩余项）** —— ⏸️ 人类已裁定**暂不做**；剩余：断网/401/超时真的降级且有提示、连续多回合、`api_key` 掩码端到端、提示注入绕过率、思考档位参数名（见 `docs/sdd/plan-02-llm-narrative/b2-live-integration.md` §7.1）

## C. 仍然开放的人类裁定项（HANDOFF §8 中与后续计划直接相关的）

计划 03+ 动到相应模块时**顺手裁定**，不必单开批次：

> ✅ **计划 03a 已闭合的项（2026-09-20）**：`§8#7`（势力面板 7 标签→4 变量错映射，T7 重写为机构控制权）· `§8#16`/`§8#21`（`weight`/`rarity` 未生效 → Task 12 收口，**截止暂停时仍未做**）· `§8#58`/`§8#62`（UI 等待期无超时/无失败恢复 → T10 看门狗 + 单一恢复出口）· `§8#63`（provider 泄漏 + `timeout` 只生效一次 → T10）· `§8#61`（降级原因未透出 → T11）· `§8#64`（测试可判别性 3 条 → T11）· `§8#65`（契约文档/鸭子类型漂移 → T11）· `§8#66`/`§8#67`（settings 不生效 / 错误串诊断不足 → 早前 `3240af6`）。
> ⏳ **仍未做**：`§8#69`（哑炮有学院）· `§8#70`（创建界面姓名/性别）→ 都在 **Task 12**。

> ⚖️ **2026-09-20 人类裁定**：下表全部项（含新登记的 `§8#58`、`§8#61–#65`）**不单开加固批次，一律留给计划 03 启动后顺手处理**。因此启动计划 03 时，下列行就是它的**必办清单的一部分**（已同步进 B3）。

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
| §8#58 | 计划 02 新增：UI 等待期无超时/取消（`await submit_async` 不恢复则输入与按钮停在禁用态） | **计划 03**（已裁定） |
| §8#61 | 计划 02 重跑盲审：降级原因未进 `op_errors` + `last_error` 是 write-only（spec §9 偏差） | **计划 03**（已裁定；1 行修） |
| §8#62 | 计划 02 重跑盲审：UI 提交路径无失败恢复 → 永久禁用只能重启；**不可**只补 `_on_load` 的 `editable`（治标） | **计划 03 动 UI 时**（已裁定） |
| §8#63 | 计划 02 重跑盲审：provider 泄漏 `HTTPRequest` 节点（每次开始/读档 1 个）+ `timeout` 只生效一次 | **计划 03**（已裁定；建议与「设置界面」小计划一起） |
| §8#64 | 计划 02 重跑盲审：测试可判别性批次（`build_repair` 不可判别 / `narration.length()>0` 准恒真 / 无 `api_key` 负向断言） | **计划 03**（已裁定；可与 §8#8/#40/#43 合并） |
| §8#65 | 计划 02 重跑盲审：契约文档与类型守卫漂移（`act` 未注「可协程」/ `_resolve` vs spec `_post_submit` / `gm is` 具体类型 + blocked 空文案） | **计划 03**（已裁定） |
| ~~**§8#66**~~ | ~~B2 实测发现的阻塞 bug：`llm_settings.json` 的 `temperature`/`max_tokens`/`timeout_ms` 完全不生效~~ | ✅ **已修（`3240af6`，2026-09-20）** |
| ~~§8#67~~ | ~~B2 实测：错误串诊断性不足~~ | ✅ **已修（`3240af6`）**；残留：默认值仍 1024（已在 README 写明思考型模型需显式配大） |
| §8#68 | 复审 M-a：`LlmSettings.provider` 无读取端（只有一种实现） | 计划 03 做 provider 路由时顺手 |
| §8#69 | **新发现（B1 点击）：哑炮却有学院**（`bloodline=squib` → `house_id=gryffindor`）——`character_creation.gd:175` 无条件 `assign_house()` 后才在 `:205` 设 `no_magic`；正典里哑炮不进霍格沃茨 | 魔法/学院相关任务，或计划 03（已裁定随 03） |
| §8#70 | 新发现（UX）：创建界面姓名框默认「无名者」可直接提交、且**无性别输入**（恒为「未定」） | 计划 03，或「设置界面」小计划 |

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
| 交付点 | **分支 `plan-03-factions`** 顶端（`main` 只到计划 02；03a 的合入在 Task 13） |
| 计划 01 计划 / 台账 | `docs/superpowers/plans/2026-09-18-...-01-core-foundation.md` / `docs/sdd/plan-01-core-foundation/progress.md` |
| 计划 02 计划 / spec / 台账 | `docs/superpowers/plans/2026-09-19-...-02-llm-narrative.md` / `docs/superpowers/specs/2026-09-19-...-02-llm-narrative-design.md` / `docs/sdd/plan-02-llm-narrative/progress.md` |
| 测试入口 | `bash tools/test.sh`（`0` 全绿 / `1` 失败 / `2` 找不到引擎） |
| 正典规格 | `哈利·波特·魔法纪元.md`（仓库根，勿移动改名） |
| 下一步第一件事 | **B4 Task 12**（03a 续做）；素材就绪则并行定稿 **B5 03a-P**；两者都在分支 `plan-03-factions` 上做，最后 Task 13 合入 `main` |
