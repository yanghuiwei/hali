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

---

## Task 4（玩家与世界数据模型）

Task 4: 开工前裁定 HANDOFF §8 第 2 条（魔杖价矛盾）——按正典 `哈利·波特·魔法纪元.md:223`「一根普通魔杖：7‑10加隆」统一。
  计划第 1059–1060 行测试原写「扣 1 加隆 / 剩 9 加隆」，改为价格下限 7 加隆 = 3451 纳特，期望 `"3加隆 0西可 0纳特"`；
  计划文档与测试代码两处同步。裁定依据与算术见 task-4-brief.md 与 task-4-review.md。
Task 4: 分支处置 —— 本地 `main` 已被 PR #1 合并到 `eccc871`，且 `aec187c`（远端 plan-01）是其祖先；
  本地 `plan-01-core-foundation` 由 `aec187c` fast-forward 到 `eccc871` 后继续开发（工作分支仍为 plan-01-core-foundation，符合 HANDOFF §1）。
Task 4: 简报 `task-4-brief.md` 写盘后派发 worker subagent（模型 deepseek-flash，符合用户「子代理必须用当前大模型」要求）。
  worker 提交 `2e3deb8 feat(model): 时钟、玩家与世界状态模型`（12 files, +356/−2），并立即写盘 `task-4-report.md`。
  交付：`src/core/game_clock.gd`、`src/core/json_util.gd`、`src/model/player_state.gd`、`src/model/world_state.gd`、
  `tests/model_test.gd`（各含 `.gd.uid`），`tests/run_tests.gd` 的 SUITES 追加 model_test。
Task 4: Step 5 gate —— worker 自跑 `bash tools/test.sh`：先红（GameClock 未定义，EXIT=1）后绿（`[model] 断言=46 失败=0`，EXIT=0）；
  controller 独立复跑确认同样全绿（原始输出见 task-4-report.md）。Task 3 的「未跑 Step 5、未写报告」P1 流程问题本次未重演。
Task 4: 第一轮审查（reviewer subagent，只读，deepseek-flash）→ **Approved with findings**：Critical=0 / Important=2 / Minor=6。
  逐字记录 `task-4-review.md`。reviewer 独立跑绿并复核魔杖价修正「正当、唯一（在裁定范围内）、无夹带」。
Task 4: 第一轮 Important —— (1) `WorldState.create` 用 `duplicate(true)` 保留 JSON 整数值 float，而 `from_dict` 走 normalize，
  create 与读档内存类型不对称（如 `witch_hunts.secrecy_integrity=1.0` vs `1`）；
  (2) from_dict 收到显式 null/非容器字段时可能因类型化赋值运行期报错（畸形存档边界，未实测）。
Task 4: 修复轮（controller 执行）提交 `8264ef9 fix(model): world_vars 规范化对称 + 端到端 JSON 往返与类型一致性断言`：
  create 改为 `JsonUtil.normalize((...).duplicate(true))`（关闭 Important #1）；修正 `political_leading_id` 拼写回退（Minor #3）；
  `model_test.gd` 新增 p3 / w3（经 JSON 字符串的端到端往返）+ we2（witch_hunts create/from_dict 的 world_vars 类型一致）3 条断言，
  `[model]` 46 → 49；计划文档 Step 1/4/5 同步。
Task 4: controller 反证 we2 非空转 —— 临时把 create 改回 `duplicate(true)`，`[model] 失败=1`、EXIT=1（期望 `1.0`，实际 `1`），随后还原并复跑绿。原始输出见 task-4-report.md「修复轮」节。
Task 4: 修复轮 scoped 复审（reviewer subagent，只读，deepseek-flash）→ **通过**：Important #1 ADDRESSED、Minor #3 ADDRESSED、
  无夹带、无新代码缺陷；reviewer 另在仓库外沙箱 `/tmp/hali_cf` 对 8 个时代逐一实测 create/from_dict 的 world_vars 类型一致（含 registry 隔离验证），并已清理。
Task 4: 移交人类批次的遗留（新增，与 HANDOFF §8 合并）——
  1. （范围外 Important）from_dict 对显式 null/非容器字段的健壮性：建议加 typeof 回退，或明确「存档只由 to_dict 产出」，Task 10 处理。
  2. （Minor）`JsonUtil.normalize` 未覆盖非有限 float、≥2^53 整数值 float、Dictionary 键类型；当前游戏数值不触发。
  3. （Minor）计划 Interfaces 段（1000–1020 行）缺 `era_start_year`、`new_default()`、`normalize -> Variant`，与 Step 代码不一致（文档级）。
  4. （Minor）`custom` 时代 `start_year:null` 静默回退 1991、月份固定 9，create 无处接收玩家指定年份（与 eras.json 语义不符）。
  5. （Minor）`advance_months(负数)` 静默 no-op；`GameClock.from_dict` 缺省 month=1 与类默认 month=9 不一致。
  6. （Minor，需 Task 5 留意）registry 原值仍是整数值 float `1.0`，而状态内 `world_vars` 已归一为 int `1`；未来直接比较二者会类型不等。
Task 4: 交付点 —— 分支 `plan-01-core-foundation` 顶端 `8264ef9`（含 2e3deb8）。工作区干净。

---

## Task 5（确定性随机 + 月度世界演化）

Task 5: 开工前 gate 裁定（计划自身矛盾）——计划 `data/rumors.json` 每条无 `label`，但 `Registry.validate()` 要求每条目有非空 label，
  且 `tests/registry_test.gd` 断言「缺 label 必须报错」。按计划原样写会使 `reg.validate().size()==0` 必红。
  裁定：给 16 条 rumor 各补一个短中文 `label`（传闻标题），计划与数据同步；不放松 validate()（否则破坏 Task 2 契约）。
Task 5: 简报 `task-5-brief.md` 写盘后派发 worker subagent（deepseek-flash）。worker 提交 `23e67cd feat(world): 确定性随机与月度世界演化`
  （12 files, +339/−16），并立即写盘 `task-5-report.md`。交付：`src/core/rng_service.gd`、`data/locations.json`(21)、`data/rumors.json`(16)、
  `src/core/registry.gd` 追加两表、`src/model/world_state.gd` 追加 `tick()`、`tests/clock_test.gd`、`tests/world_tick_test.gd`（各含 .uid）。
Task 5: Step 7 gate —— worker 自跑 `bash tools/test.sh`：先红（RngService 未定义，EXIT=1）后绿（`[clock] 28/0`、`[world_tick] 101/0`，EXIT=0）；
  controller 独立复跑确认（原始输出见 task-5-report.md）。
Task 5: 第一轮审查（reviewer subagent，只读）→ Critical=0 / Important=4 / Minor=9，记录 `task-5-review.md`。reviewer 签核 label 修正为唯一正当且无夹带。
Task 5: Important —— (1) `major_ready` 循环外只算一次，同月最多抽 2 条，可能同月落地 2 起 major，违背 12 个月间隔；
  (2) `weight` 声明但 `stream_pick` 均匀抽取，稀有度旋钮失效（计划级）；(3) `rng_state` 死字段、`state_dict/load_state` 在 src 零调用（计划级）；
  (4) `load_state` 不恢复 `seed_value`，恢复后新建流退回构造 seed。
Task 5: 修复轮 1（controller）提交 `f9038ca`：`tick()` 加 `break`（同月至多一起 major）；`state_dict/load_state` 加入并恢复 `seed_value`；
  消除死变量与两处空转测试（w2 定位 ministry_of_magic、加 major 间隔断言、w3 加 events_seen）。
Task 5: 修复轮 1 复审（reviewer）→ **通过**（#1/#4 ADDRESSED，无夹带）；提出 N1：`rng.state` 是 int64，`state_dict → JSON → load_state` 会丢精度导致序列分叉（既有隐患）。
Task 5: 修复轮 2（controller）提交 `24d5d43`：`state_dict` 把 `seed_value`/`seed`/`state` 十进制字符串化、`load_state` 用 `int(str(...))` 解析并 `_streams.clear()`；
  `clock_test` 改为 20 次续抽 + 真 JSON 往返；`world_tick_test` 的 w2 种子 1234→38（使 major 间隔断言可判别）、`events is Array` 换成 turn 断言。
Task 5: 修复轮 2 反证 —— 删 `break`（种子 38）→ `min_gap=0` 失败；改回裸 int → `[clock] 失败=19`。最终全绿：`[clock] 47/0`、`[world_tick] 104/0`、EXIT=0。
Task 5: 修复轮 2 复审（reviewer）→ **通过**（N1/N2 ADDRESSED，R12 空转消除，无 Critical，无夹带）。
Task 5: 移交人类批次（与 HANDOFF §8 合并）——
  1. （Important，计划级）`weight` 声明但未用于抽取（`stream_pick` 均匀）；二选一：实现加权或删字段。可留到内容平衡任务。
  2. （Important，计划级）`rng_state` 死字段、`state_dict/load_state` 未在 WorldState 层接线；当前 tick 用 `game_seed + turn*prime` 派生，故字段冗余。
     接线前须定夺「删字段改述为派生式确定性」还是「接入长驻 RngService」。
  3. （Minor）`RngService` 无 schema 版本号，旧扁平 schema 静默不恢复；`hash()` 为 32 位有碰撞风险；同月可重复抽到同一条 rumor；
     `history` 无上限、`log` 三种 schema；`age_months` 与 clock 各自计时；信息保护断言仍恒真（`ministry_access` 无人授予）。
  4. （Minor，新增 N5）`WorldState.game_seed` 仍是裸 int，>2^53 经 JSON 丢失，与 RngService 的字符串化不对称；须与存档系统任务同批解决。
  5. （Minor，测试缺口）仍无 `tick → to_dict → JSON → from_dict → tick` 的 WorldState 级存档续跑对比测试。
Task 5: 交付点 —— 分支 `plan-01-core-foundation` 顶端 `24d5d43`。工作区干净。

---

## Task 6（角色创建流水线）

Task 6: 开工前发现并裁定计划缺陷 —— `generate_wand` 首行 `var wood: Dictionary = rng.stream_pick(...)`，而 `stream_pick` 返回字符串 id，
  类型化赋值会运行期报错。裁定改为 `var wood: String = str(rng.stream_pick(...))`，计划与代码同步（controller 用探针确认 `stream_pick` 接受 PackedStringArray）。
Task 6: 简报 `task-6-brief.md` 写盘后派发 worker subagent（deepseek-flash）。worker 提交
  `f3d8a31 feat(creation): 第七十五章启动界面到玩家档案的创建流水线`（12 files, +448/−1），并立即写盘 `task-6-report.md`。
  交付：`src/rules/character_creation.gd`、`data/skills.json`(19) + 四张魔杖表（woods 16 / cores 6 / flexibilities 6 / lengths 13）、
  `src/core/registry.gd` 追加 5 表、`tests/creation_test.gd`（各含 .uid）。
Task 6: Step 5 gate —— worker 自跑 `bash tools/test.sh`：先红（CharacterCreation 未定义，EXIT=1）后绿（`[creation] 141/0`，EXIT=0）；controller 独立复跑确认。
Task 6: 第一轮审查（reviewer subagent，只读）→ Critical=0 / Important=3 / Minor=5，记录 `task-6-review.md`。reviewer 签核 wood 修正为唯一正确且无夹带。
Task 6: Important —— (1) `aptitude_special` 反漏洞绕过：只在 `aptitude_id=="special"` 时校验，但 `create()` 无条件写 `p.flags[aptitude_special]`，可注入任意 flag；
  (2) `birthplace` 未校验即写入 `player.location_id`，非法值会让世界演化静默过滤传闻；
  (3) `wand_cores.rarity` 死字段（杖芯均匀抽取，与 Task 5 `weight` 同类）。
Task 6: 修复轮 1（controller）提交 `2341540`：`validate_choices` 增加 `aptitude_special` 非 special 时的报错门 + `create()` 侧 special 门；
  增加 `birthplace` 合法地点校验；`personality` 关键词非空 + `.duplicate()`；测试 +5 断言（141→146）、`sly_house` 精确断言、哑炮不判学院。
Task 6: 修复轮 1 反证 —— 删两道校验门 → `[creation] 失败=3`，EXIT=1。scoped 复审 **通过**；提出 N1（`random` 可掷出 `special` 但无具体天赋）。
Task 6: 修复轮 2（controller）提交 `61ad053`：随机资质池排除 `special`；测试随机资质循环新增 `a.ne(..., "special")`（+30，146→176）；计划同步。
Task 6: 修复轮 2 反证 —— `special` 放回池 → `[creation] 失败=4`（30 种子中 4 个命中）。scoped 复审 **通过**（N1 ADDRESSED，无夹带）。
Task 6: 最终全绿：`[creation] 断言=176 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、EXIT=0。
Task 6: 移交人类批次（与 HANDOFF §8 合并）——
  1. （Minor）`wand_cores.rarity` 声明但未用于抽取（计划级，与 Task 5 `weight` 同类）。
  2. （Minor）玩家自带魔杖的 `length_inches` 未校验（可传任意值），且「自带魔杖」分支无测试。
  3. （Minor）`prejudice_level`（float）写入 bool 语义的 `flags`；建议提为 `PlayerState` 数值字段。
  4. （Minor）`create()` 的 `no_magic` 与 squib 血统 `default_flags` 重复（断言部分空转）；`p.job=""` 冗余；`grants` 循环恒空转。
  5. （Minor）`assign_house` 双向 `contains` 子串过宽、性格关键词无数量上限。
  6. （Minor，新增）存档载入路径（`PlayerState.from_dict`）不重跑 `validate_choices`，「无天赋的特殊资质」可经手改存档进入状态；建议随存档任务补一次载入校验。
Task 6: 交付点 —— 分支 `plan-01-core-foundation` 顶端 `61ad053`。工作区干净。

---

## Task 7（魔咒解析器与反漏洞守卫）

Task 7: 开工前发现并裁定计划缺陷 —— `no_rare_resource_duplication` 的拦截文案用 `% target_rarity`（英文 `"rare"`），
  与测试 `blocked_reason.contains("稀有")` 冲突。按测试意图改为「复制咒无法复制稀有资源（%s）…」，计划与代码同步。
Task 7: 简报 `task-7-brief.md` 写盘后派发 worker subagent（deepseek-flash）。worker 提交
  `f323b55 feat(spell): 魔咒解析器与第五十五条反漏洞守卫`（8 files, +304/−1），并立即写盘 `task-7-report.md`。
  交付：`src/rules/spell_resolver.gd`、`data/spells.json`（32 条）、`src/core/registry.gd` 追加 spells、`tests/spell_test.gd`（各含 .uid）。
Task 7: Step 5 gate —— worker 自跑 `bash tools/test.sh`：先红（SpellResolver 未定义，EXIT=1）后绿（`[spell] 212/0`，EXIT=0）；controller 独立复跑确认。
Task 7: 第一轮审查（reviewer subagent，只读）→ Critical=0 / Important=2 / Minor=4，记录 `task-7-review.md`。reviewer 签核「稀有」文案修正为唯一正确且无夹带。
Task 7: Important —— (1) `RARE_RARITIES` 缺中文「稀有」，传中文可绕过反复制守卫；
  (2) `energy_loop_count` 终身累计、无重置点，第 4 次成功施放基础咒即永久封禁（计划层语义，需 Human 裁定）。
Task 7: 修复轮 1（controller）提交 `3499881`：`RARE_RARITIES` 补「稀有」「传说」；补中文稀有负例、门钥匙（requires_ministry_approval 此前零覆盖）、未知条件键丢弃断言（212→216）。
Task 7: 修复轮 1 反证 —— 移除「稀有」→ `[spell] 失败=1`。scoped 复审 **通过**；提出 R1：denylist + 精确匹配仍可被繁体/大小写/空白/未知值绕过。
Task 7: 修复轮 2（controller）提交 `d52ebda`：改为 fail-closed 白名单 `COMMON_RARITIES=["common","普通","常见"]` + `strip_edges().to_lower()` 归一；补变体负例与归一化正例（216→223）；计划 Interfaces 同步。
Task 7: 修复轮 2 反证 —— 去掉归一化 → `[spell] 失败=1`。scoped 复审 **通过**（R1 ADDRESSED，独立枚举无绕过路径，无夹带）。
Task 7: 最终全绿：`[spell] 断言=223 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、EXIT=0。
Task 7: 移交人类批次 / Task 8 前必须裁定（与 HANDOFF §8 合并）——
  1. （Important，**Task 8 实施前必须裁定**）`energy_loop_count`（以及 `time_rewind_count`）的语义：per-turn / per-scene / per-life；
     当前实现为终身累计、无重置，Task 8 计划 2956–2958 已固化该语义，改语义须同步改计划。
  2. （Minor）`illegal_cast_count` 仅成功时自增（未遂不计）；被拦截 `Outcome` 的 `failure_rate=1.0` 语义；
     `difficulty` 为绝对失败率偏移（文档表述）；`legilimens`/`confundo` 的 legal_risk、计数器自增等测试缺口；
     白名单 `常见` 与简体 `传说` 零独立断言；全角空白/全角拉丁会被 fail-closed 过度拦截。
Task 7: 交付点 —— 分支 `plan-01-core-foundation` 顶端 `d52ebda`。工作区干净。

Task 7 后续裁定（Human：「按你建议来」）—— HANDOFF §8 第 27 条关闭：
  裁定：`energy_loop_count` **per-turn**（每回合/月重置）；`time_rewind_count` **终身一次性**（上限 1，不重置）。
  实现提交 `a0bc1d3`：`WorldState.tick()` 在 `advance_month()` 后 `flags.erase("energy_loop_count")`；spell_resolver 两个守卫加语义注释；
  `[spell]` 新增 4 条回归断言（拦截后仍为 3、tick 后归零、新回合可重施、time_turner 跨回合仍拦，223→227）；计划 Task 5/7 同步。
  反证：删除 `flags.erase(...)` → `[spell] 失败=2`，EXIT=1。
  裁定实现复审（reviewer subagent，只读）→ **通过**（per-turn 与终身一次性均 ADDRESSED，Task 8 计划兼容，无夹带）；
  提出 N1（注释误引「第七十五条」，应作「第五十五条」，已改）、N2（台账仍记为未决闸门，已在本文件与 HANDOFF 关闭）、
  N3（per-turn 契约绑定 `tick()`，Task 8 回合推进必须经 `tick()`）、N4（world_tick 层与 wingardium 同 flag 断言缺口）。
Task 7 裁定实现修复复审 → **通过**（N1/N2 CLOSED，无逻辑改动）。残留 N3（per-turn 契约绑定 `WorldState.tick()`，Task 8 回合推进必须统一经 `tick()`，并补端到端断言）、
  N4（world_tick 层与 `wingardium_leviosa` 同 flag 的覆盖缺口）、N5（台账历史条目表述）均为非阻塞，顺延到 Task 8 测试加固批次。
Task 7: 修复轮收尾提交 `153487c`（注释引用改为「第五十五条·魔法体系漏洞保护」+ 关闭 HANDOFF §8#27 闸门）。交付点 = 分支顶端 `153487c`。

---

## Task 8（叙事接口 + 状态操作 + 反刷成长 + 回合引擎）

Task 8: 开工前发现并裁定两处计划测试缺陷 —— (1) Progression 测试 `total := g1` 漏加 g2/g3（按公式 23 次总和应为 8，原写法只得 5）；
  (2) 未知行动文本「我对着墙发呆…」命中 `REST_KEYWORDS` 的「发呆」，拿不到 idle 标签。两处修正并同步计划。
Task 8: 简报 `task-8-brief.md` 写盘后派发 worker subagent（deepseek-flash）。worker 提交
  `432adc8 feat(gm): 叙事接口、状态操作、反刷成长与回合引擎`（16 files, +424/−2），并立即写盘 `task-8-report.md`。
  交付：`src/gm/game_master.gd`、`src/gm/scripted_game_master.gd`、`src/rules/state_ops.gd`、`src/rules/progression.gd`、
  `src/rules/self_check.gd`（任务 8 最小桩，任务 9 替换；计划明说）、`src/core/turn_engine.gd`、`tests/gm_test.gd`（各含 .uid）。
  已用探针确认子类可用父类内嵌类 `GmResult.new()`。
Task 8: Step 7 gate —— worker 自跑 `bash tools/test.sh`：先红（StateOps 未定义）后绿（`[gm] 38/0`，EXIT=0）；controller 独立复跑确认。
Task 8: 第一轮审查（reviewer subagent，只读）→ Critical=0 / Important=3 / Minor=5，记录 `task-8-review.md`。两处强制修正经独立核对为唯一正确、无夹带；其余 7 个计划代码块逐字一致。
Task 8: Important（均为计划级/架构级，**本轮不修**，登记 HANDOFF §8）——
  1. `StateOps.world_gm_rng` 每次新建 RNG → 同一回合内所有 `cast_spell` 掷同一 `spell_roll`、失败副作用同型；
  2. `TurnEngine.rng` 从不掷数、真正影响叙事的 `ScriptedGameMaster.rng` 未入 `world.rng_state` → 读档后叙事随机流重放（与 §8#17 同源，Task 10 必须补端到端存档续跑对比）；
  3. `ScriptedGameMaster.act` 直接改世界（SpellResolver/Progression），绕过 StateOps——审查补三条新后果：副作用不进 `deltas_applied`、被拦截施法无 `op_errors`、`last_cast_*` 在生产路径恒不可达。
Task 8: 流程正确性复核通过：死亡/自检挂起不推进时间；回合推进统一经 `WorldState.tick()`（满足 Task 7 裁定的 per-turn）；自检第 15 回合触发并持久化 `awaiting_audit_ack`。
Task 8: 按 HANDOFF 流程（Task 5 先例），3 Important + 5 Minor 均登记人类/后续批次，本任务不做修复轮。
Task 8: 交付点 —— 分支 `plan-01-core-foundation` 顶端 `432adc8`。工作区干净。
