# SDD ledger — plan: docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md

Branch: `plan-01-core-foundation` (branched from `main` @ 0b4dd62)
Workspace: `/e/Hali/.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation`
Plan: 11 tasks, each with its own test suite; engine = repo-root `Godot_v4.7.2-stable_win64_console.exe` (git-ignored, must stay on disk).

Reason for in-place branch instead of a worktree: the Godot engine binary is untracked
(180MB) and lives only in `/e/Hali`; a worktree would have no engine to run
`tools/test.sh`. The user's VS Code workspace is also `/e/Hali`.

## Preflight scan (before Task 1)

Surfaced to the human as one batched question:

1. Task 8 ships a *deliberate* minimal `SelfCheck` stub that Task 9 replaces with the
   full implementation. Plan text: "本步先写入 `src/rules/self_check.gd` 的**最小实现**…任务 9 会用完整实现替换它".
   A reviewer may flag this as a placeholder.
2. Task 8's `ScriptedGameMaster` calls `SpellResolver.cast()` directly (mutating world)
   instead of returning a `cast_spell` delta. Plan text documents this in the task and in
   the Interfaces block, but it differs from the stated "GM returns deltas, engine applies"
   contract, so a reviewer may call it an architecture violation.
3. Task 9 `power_panel` maps several 第六十五章 labels onto the same `world_vars` values
   (法律执行/傲罗/威正加摩 all read war_pressure/ministry_stability/corruption). Cosmetic.

Rulings: (pending human answer; findings from the review loop are adjudicated when they arise)

## Progress

Task 1: complete (commits 04808e2..b2ca0f4, review clean)
Task 1: note — implementer (worker/deepseek-v4-flash) timed out at the 30-minute wall clock AFTER committing; no implementer report file exists. Controller ran the suite itself and supplied controller-observed output to the reviewer; reviewer then verified from the diff. Mitigation for later tasks: instruct implementers to write the report file immediately after committing, before any optional extra checks.
Task 1: minor (deferred): tools/test.sh:17 discards the --import exit status (plan-mandated). A later out-of-SUITES script that fails to import would yield a false green.
Task 1: minor (deferred): tests/run_tests.gd:29-34 — an empty SUITES const would print ALL TESTS PASSED. Not reachable today (1 entry).
Task 1: controller-closed ⚠️ items from review — broken assertion → exit 1; missing suite path → exit 1 with "缺少测试套件"; cold cache (rm -rf .godot) → exit 0, 8/8 assertions.

Task 1: fix round 1/5 (1 addressed, 0 open — runner hung when a SUITES entry existed but failed to parse; now isolated into _run_suite + can_instantiate() guard; commits 52b68ba..281fdd6; scoped re-review: ADDRESSED, no new breakage)
Task 1: reopened post-completion because the defect violates Task 1's own stated requirement ("运行器在任何情况下都必须以 quit(...) 结束"). Controller reproduced the hang (exit 124) before the fix and self-exit-1 after it.
Task 1: minor (deferred): a suite that parses but raises mid-run() — quit guarantee holds, but failure accounting depends on int(null) semantics; not covered by a probe.
Task 2: complete (commits b2ca0f4..52b68ba, review clean — Spec ✅, Approved; 1 Important plan-mandated finding + minors deferred to the human batch)
Task 2: note — implementer (worker) wrote task-2-report.md immediately after committing; report exists and was usable.

Task 3: brief written (task-3-brief.md, 13:22). Dispatched; implementer landed src/model/money.gd, src/rules/magic_level.gd,
tests/money_test.gd, tests/magic_level_test.gd, tests/run_tests.gd (SUITES now 4 entries) plus a plan-doc correction in the
working tree, but ended WITHOUT writing task-3-report.md and WITHOUT confirming Step 5 (green suite) — the plan's own commit
gate. No ledger entry existed until this one; the 13:22–13:45 gap is only reconstructable from file mtimes.
Task 3: implementer finding (accepted) — the plan text for `Money.from_knuts` was wrong: it asserted 510 → [1,0,17] and
511 → [1,1,0], which contradicts 第十八章 (1加隆=17西可=493纳特, 17 纳特必须进位为 1 西可). Implementer implemented canon
normalisation and corrected the plan instead of coding to the bad expectation. Corrected plan text: 510 → [1,1,0],
511 → [1,1,1]; birth_identities start_knuts comment aligned to 普通巫师家庭 4930 (10加隆).
Task 3: stray process — an orphaned headless engine (PID 16240, `--headless --path . --script res://tests/run_tests.gd`,
started 13:09:30, i.e. on the PRE-fix runner from before 281fdd6) was still spinning at ~22% of one core after 35 min
(CPU 382s → 397s over the wait). Read as the leftover of the Task 1 hang reproduction: the bash `timeout` killed the shell
but orphaned the engine child. Killed before running the suite so it could not contend for the `.godot` cache.
Task 3: Step 5 gate run by the controller (implementer did not). First run RED: `[money] 断言=15 失败=2` — money_test.gd
still carried the two pre-correction expectations while money.gd normalises per canon. Controller aligned exactly those two
assertions to the already-corrected plan text and re-ran.
Task 3: controller-observed suite output (post-fix, `bash tools/test.sh`):
`[harness] 断言=8 失败=0`, `[registry] 断言=26 失败=0`, `[money] 断言=15 失败=0`, `[magic_level] 断言=22 失败=0`,
`总计失败=0，失败套件=0`, `ALL TESTS PASSED`, 冒烟跳过（ui/main.tscn 未创建，任务 11 启用）, EXIT=0.
(Task 1 precedent: reviewer is read-only and cannot run the suite, so the controller supplies this output.)
Task 3: FOR REVIEWER — one controller edit to a task file: the 2 assertions in tests/money_test.gd. Adjudicate whether the
post-edit expectations are canon-correct, and whether the red→green history hides a defect or is exactly the fix the
corrected plan mandates.
Task 3: 提交为 61d4ac1（docs(plan)）与 50fc993（feat(rules)）（controller 收尾）。
Task 3: review dispatched (reviewer, read-only) → 结论：**Spec ✅ / Approved with findings**；逐字记录见 `task-3-review.md`。
Task 3: review 发现 — 0 Critical；1 Important（P1 流程门禁：未写 task-3-report.md 且提交前无绿灯，控制器补跑关闭，不阻塞；报告缺失本身 P2）；
5 Minor。reviewer 已签核两件关键争议：计划文本修正（510→[1,1,0]、511→[1,1,1]）为**唯一正确**且无夹带数值改动；
控制器对 tests/money_test.gd 两行断言的改动属「修正测试以匹配正确实现」，未掩盖缺陷。
Task 3: review Minor（属于计划原文，非实现者偏差）— (a) magic_level_test 的 clamp 上下界两条断言空转（0.9075<0.95、0.01>0.005），
BANDS 仅 5/10 档精确断言，LABELS 仅 3/10，(b) money_test 负值只测 total，(c) 断言消息章节引错（"第十九章：家族破产"，
正典支撑在第三章:46 / 第三十八章:451 / 第五十三章:575），(d) BANDS[MASTER] 用 is_true 代替精确相等。
Task 3: 移交人类批次的裁定项（新增，与 Preflight 3 条合并）—
1. `BANDS[0]=(1.00,1.00)` 与 `effective_rate(SQUIB)=0.95` 不一致 → 哑炮 5% 施法成功率，与正典 第127行「哑炮…无法施展咒语」严格读法冲突；
   选项：BANDS[0] 改 (0.95,0.95)，或 effective_rate 对 SQUIB 返回 1.0/直接拒绝施法。
2. 计划 Task 4 测试（计划 1060-1061）把魔杖价写成 1 加隆却标注"剩 9 加隆"，与新增注释/正典 第223行「7–10 加隆」矛盾 —— 必须在 Task 4 动工前统一。
3. `Money` 负值的 parts()/formatted() 未定义（-50 → "0加隆 -2西可 -16纳特"），第六十二章财富面板会出现该形态。
4. 大师级失败率上界 0.02 对正典 第288行「低于2%」是开/闭区间歧义。
5. 是否按 review Minor 2/3 先补齐 clamp 上下界与 BANDS 十档断言，还是作为计划级补测留到后续任务批量处理。
Task 3: controller 已停在此处，等人类裁定与是否进入 Task 4。
Task 3: 提醒 —— 上方 Preflight 的 3 条（Task 8 SelfCheck 最小桩、ScriptedGameMaster 直接调用 cast、Task 9 power_panel 标签重叠）
至今仍未裁定，需与上面的 5 条一起批量回答。

Task 3: 交接整理（controller）—— commit 055d9ef：新增 HANDOFF.md（换机指引 + 分支说明 + 进度表 + 踩坑 + 待裁定项）
与 docs/sdd/plan-01-core-foundation/ 耐久副本（本目录的台账/简报/报告/审查包，因 .superpowers 被双重忽略而不会随源码走），
并把 README 进度表更新为 Task 1–3 完成。分支已推送：origin/plan-01-core-foundation @ 055d9ef
（此前只在本地，远端仅 main @ 0b4dd62，换机器会拿到空壳）。
Task 3: 本机状态 —— 工作区干净，无活跃子代理，无残留 Godot 进程；交付点 = 分支顶端（ccf59d8 起），下一步 = Task 4（先裁定第 2 条魔杖价矛盾）。
Task 3: 同步规则 — 以后每完成一个任务，把该任务工件从本目录复制到 docs/sdd/plan-01-core-foundation/ 一起提交（副本以 docs/ 下为准）。
