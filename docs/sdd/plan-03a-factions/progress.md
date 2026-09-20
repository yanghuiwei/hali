# SDD ledger — plan: docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md

> 分支：plan-03-factions（从 main@685af4b）｜跑者：控制器（主会话）｜子代理：worker（实现）+ reviewer（审查）
> 铁律提醒：每任务 = brief → worker → 自跑绿灯 → 先写报告 → 只读 reviewer → 台账；工件耐久副本进 docs/sdd/plan-03a-factions/（Task 13 统一）。

## Task 1: 内容表 factions/governments + Registry 注册与字段校验
- BASE: 12f6a50（派系计划提交）
- brief: task-1-brief.md
- dispatch: worker / deepseek-flash / run c93c0c76-157e-4d54-8bc5-67d5c8e0d1e0（2026-09-20）
- 裁定（控制器）：① 无类型 Array vs Array[String] 的比较若失败改为字符串拼接比较，不许放宽常量类型；② registry 与 WorldFactions 的枚举常量故意重复（防 core→rules 类循环），靠测试断言防漂移；③ aliases 必须中文、不与别的派系重复；④ 派系 label 不得含真实人物姓名（家族名留 03c）。
- Task 1 实现：DONE，提交 `eacb773`（6 files, +438）；`[registry]` 26→210 断言，全仓失败=0，EXIT=0
  - 实现者关键实测（对后续任务有用）：① 无类型 `Array` 与 `Array[String]` 用 `==` **可**逐元素比较（Task 2 的枚举一致性断言可原样用）；② `PackedStringArray == Array` 是**解析期错误**，凡比较 `WorldFactions.visible_faction_ids()` 处只能用 `.has()`（Task 3/6 现有写法安全）。
  - 实现者残余：`rivals/allies` 未做双向对称校验（内容层取舍，`apply_rival_pressure` 用 `oid <= id` 去重，不对称不会重复计算）；`canon_line` 不进校验；`muggle_world` 的 kind=foreign 故不进权力四角。
- review package: review-12f6a50..eacb773.diff（1 commit, 20700B）
- dispatch（审查）: reviewer / deepseek-flash / run 747ee7f9-5a08-4758-9f8e-f96a748fe8d7（2026-09-20）
- 审查：**Spec ✅ / Approved**，Critical 0 / Important 0 / Minor 5（4 条 plan-mandated）→ 无修复轮。工件：`task-1-review.md`
- ⚠️ 项控制器核对：工作区干净、`.uid` 未被二次改写、重跑 `bash tools/test.sh` 逐字 `EXIT=0`、2 条 SCRIPT ERROR 与基线逐字同位置（本次新增 0 条）
- Task 1: minor (deferred): `data/factions.json:211` black_market.aliases 含裸地点名「翻倒巷」（与实现者报告自述矛盾）→ 裁定转 Task 9 dispatch 显式处理
- Task 1: minor (deferred→Task 2 收口): domains/aliases 零消费零校验；`base_power` 未校验类型；`era_overrides` 断言被 typeof 守卫（字段缺失即静默跳过）
- Task 1: minor (deferred): 枚举常量两处重复（合理取舍），护栏依赖 Task 2 的「两处枚举一致」断言必须真的加上
- 状态：**Task 1 complete**（eacb773）


## Task 2: WorldFactions 规则层（初始化 / 机构控制权 / 权力四角 / 政体推导）
- BASE: eacb773（Task 1 顶端）
- brief: task-2-brief.md
- dispatch: worker / deepseek-flash / run ba18a033-7aa9-4fb8-8e4d-1c732fb1deea（2026-09-20）
- 裁定（控制器）：
  ① 照 Task 1 实测结论写（Array vs Array[String] 可直接 ==；PackedStringArray 只能 .has()）；
  ② **并入 Task 1 审查 Minor 收口**：validate_content 增加 domains 白名单 / aliases 非空（strip 后） / base_power 类型 / era_overrides 必须存在且为 Dictionary，并各配一条能失败的断言；
  ③ 「两处枚举一致性」断言必须真的加进 registry_test（core↔rules 枚举重复的唯一护栏）；
  ④ government_type 的 dark 分支兜底写法保留；create/from_dict 都调 initialize（幂等）；main.gd 只加 validate_content 一行。
- Task 9 实现完成：提交 `a36faab`（3 files, +143-1），**EXIT=0**；`[gm] 71→102`、其余套件不变；`SCRIPT ERROR` 2 = 基线（控制器复核 `task-9-test-verify.log`）；**B1 探针 82/0**（降级路径未破坏验收）
  - `FACTION_JOIN/LEAVE/SUPPORT/OPPOSE` + `_detect_faction()`（只扫 `visible_faction_ids`）；分支插在施法后、TRAIN 前，未命中不提前 return
  - 控制器裁定落地：`black_market.aliases` 删掉裸地名「翻倒巷」（实测现为 `["翻倒巷黑市","黑市"]`）+ 7 条别名回归断言
  - 4 组破坏实验：D-A 提前 return（10+5 红）、D-B 忽略揭示扫全表（4 红）、D-C 加回「翻倒巷」（2 红）、D-D tie-break 反过来（1 红）；每组后 md5 逐字还原
  - 如实登记：红步是**套件中止**（测未实现 API 的固有结果，非测试缺陷）；tie-break 按 id 序「确定但粗糙」（真实玩法由 LLM 主路径承担语义）；名词性文本歧义（「我最讨厌食死徒」→ 落 idle，不误判为支持）
- review package: review-8bc42e9..a36faab.diff（4 commits，其中 3 个是控制器 docs；审查只需看代码提交 `a36faab` 的 3 文件）
- dispatch（审查）: reviewer / deepseek-flash / run 41dbd54b（2026-09-20）
- 审查：**Approved**，Critical 0 / **Important 0** / Minor 8 → **无修复轮**。工件 `task-9-review.md`
- 审查者逐条自查：① 分支顺序/不吞普通动作 ✅（`:88` 的 if 包住四分支）② tie-break 确定 ✅（`registry.ids()` 显式 sort → id 字典序首个；并按 17 条内容反推确认「我支持魔法部和古灵阁」唯一先命中 gringotts）③ 未揭示是**双门**（脚本只扫 visible + state_ops 也校验）④ 别名歧义 ✅ ⑤ 降级路径/tags 无回归 ✅（「确认自检」在 UI 层就被短路）
- Task 9: minor (deferred→**Task 10**)：M1 `aliases as Array` 运行期无第二道门（2 行守卫）；M2 `faction` tag 不在 LLM 白名单（契约漂移，各 1 行）；M3 `leave_faction` 不带目标派系（旁白与归属可能不一致）
- Task 9: minor (deferred→**Task 11**)：M4 回退路径缺断言；M5 旁白 label 无法区分硬编码（用临时 registry 改名验证）；M8 `faction_standing_delta` 缺 revealed 校验
- Task 9: minor (登记)：M6 报告 §⑧ D-A「10 条全红」是**过度声明**（实际约 4 条，方向成立）；M7 红步为套件中止（可接受，建议后续把「测新 API」与实现分开以保留一次干净失败）→ Task 13 写入 HANDOFF §4 踩坑
- 状态：**Task 9 complete**（a36faab）

## Task 10: 顺手项 A —— UI 等待期看门狗（§8#58/#62）+ provider 复用/timeout/dispose（§8#63）+ Task 9 三条 Minor
- BASE: a36faab
- brief: task-10-brief.md
- dispatch: worker / deepseek-flash / run 3061f0b8（2026-09-20；中途因破坏实验死锁被控制器清进程 + steer 纠正）
- Task 10 实现完成：提交 `a6fe196`（10 files, +243-21），**EXIT=0**；`[gm] 102→116`、`[llm] 88→97`、`[prompt] 34→35`，其余不变；`SCRIPT ERROR` 2 = 基线；**B1 探针 82→91 断言 / 0 失败 / EXIT=0**（控制器复核 `task-10-test-verify.log` + `task-10-b1-verify.log`）
  - 看门狗：`turn_timeout_sec`（180s，`HALI_TURN_TIMEOUT_SEC` 覆盖）+ `_run_turn` 独立协程 + deadline 轮询 → **恢复出口唯一**；破坏实验 A（删恢复两行）→ 探针 7 条红（含 Part 9 两条）；W2（只删超时提示）→ 恰好 1 条红
  - provider 卫生：`ensure_http/http_timeout_sec/dispose/mask`；破坏 B（每次新建 + dispose no-op）→ `[llm]` 2 红；B2（timeout 只设一次）→ 1 红
  - M1/M2/M3 全部落地；**实现者实测订正了我的诊断**：`"黑市" as Array` 不是返回 null，而是 `Invalid cast` 中止 `_detect_faction` 自身，因返回类型是 `String` ⇒ 调用方得 `""`、**套件不会中止**，真实后果是「静默降级 + 每条 stderr 噪音 + 跳过 id 靠后的派系」
  - **教训（写进计划与台账）**：破坏实验一律「保留 deadline、只删恢复/提示」；探针改用 `_submit_bounded()`（只轮询可观测信号 + 5s 上限，不 `await` 被测协程）⇒ 即使被测代码没有看门狗，探针也能干净变红并退出
- review package: review-a36faab..a6fe196.diff（2 commits，其中 `35f43ca` 是控制器 docs）
- dispatch（审查）: reviewer / deepseek-flash / run 3b253a36（2026-09-20）
- 审查者第 1 次失败（**不是**发现不了问题）：run `3b253a36` 跑了 150s、`exitCode=1`、输出 29.6k tokens、`windowPeak=64244` → 判定为**超出其上下文/输出上限**（它读了太多文件、内部独白过长）。
- 控制器处置：① 重生成**只含代码提交**的审查包 `review-35f43ca..a6fe196.diff`（33KB，排除控制器 docs 提交）；② 重派时**精简指令**（只判定 3 件最关键的事：恢复出口唯一性/迟到结果污染/provider 生命周期与脱敏；其余简答），并明确要求「只读 1 次 diff、最多 4 次 grep、报告 ≤120 行、不整文件打印源码」。
- 重派：reviewer / deepseek-flash / run 652777a4（2026-09-20）
- 经验（给 Task 13 的踩坑清单）：**审查任务要控制输入体量**（diff 越大越要限定阅读预算），否则 64k 窗口的 reviewer 容易在长独白里撞上限而失败。
- 审查（第 2 次，成功）：**Approved**，Critical 0 / **Important 1（plan-mandated，我的计划写错）** / Minor 4 → 进修复轮
  - **I1 的真实缺陷**：看门狗与 `_run_turn()` 共用成员字典 `_turn_state`，而 `done=true` 是 await **之后**的独立语句 ⇒ 超时后迟到的旧协程会把 `done=true` 写进**新一轮**字典 ⇒ 提前退出 / 渲染错位 / 空字典抛错 ⇒ **恢复被跳过（§8#62 回归）**
  - 审查者确认：`mask()` 覆盖所有返回路径 ✅；`dispose()` 后不存在对已释放节点 `request` ✅；既有 `[gm]`/`[llm]` 断言全保留 ✅
- 控制器：已改计划（`f97f2fc`：本轮私有 `round_state` + 恢复前置于渲染 + engine 空守卫 + `.get` 兜底）→ **修复轮 1**（run 71cfa8c9）
- 修复轮 1 完成：提交 `0f11aaf`（2 files），**EXIT=0**；探针 **101→105 断言 / 0 失败**（控制器复核 `task-10-fix1-*`）
  - R1-3：**实现者发现我的守卫不够**——`_run_turn` 里的 `engine == null` 只是 `return`、不置 `done` ⇒ 仍要等满超时（实测 5010ms）；它另加 `_on_command_submitted` 的立即恢复分支（实测 **3ms**）→ 控制器已把这条补进计划（`b257c54`）
  - **R3（重要且诚实）：I1 机制成立但「黑盒不可达（No Repro）」**——`_run_turn` 是 fire-and-forget 内层协程；外层到点返回后内层挂起链失去唯一引用、被 Godot 丢弃 ⇒ `await` 永不恢复 ⇒ 迟到写**执行不到**。黑盒实验（共享字典版 vs 修复版）逐条 PASS 一致、turn 不推进；语言级最小实验（已删）证明「只要执行就会污染」。⇒ 该组新断言**不是 I1 的回归护栏**（它钉的是可观测契约；本轮唯一有红→绿证据的是 engine 立即恢复那 3 条）
  - 控制器裁定：**保留修复**（把"依赖协程 GC 时序"的隐含假设变成显式不变量，成本为零），并把 I1 在台账登记为「机制已证实 / 黑盒不可达」+ 明确写出该组断言不作护栏；若将来有人 `await _run_turn(...)` 或引擎改变挂起链持有语义，缺陷即变可达（登记为条件性风险）
- scoped 复审: reviewer / deepseek-flash / run 5d0e2a5b（review-f97f2fc..0f11aaf.diff，1 commit 15496B）
- scoped 复审：**Fix round 1 = Accepted**（四处落地、控制流无漏渲染、同意「机制成立但黑盒不可达」、新引入 0 功能问题）→ 工件 `task-10-review.md`（含首轮审查 + 修复轮 + 复审三段）
  - 复审者独立确认：生产路径**无任何**持有 `_run_turn` 内层句柄的地方（唯一调用点 `:301` fire-and-forget，FunctionState 立即丢弃）⇒ No Repro 结论可信
  - 新引入 P2：① `tools/b1_acceptance.gd:133/:461` 措辞与同函数 `:500-501` 的自我否认冲突（暗示 hold_ref 可复活迟到协程）；② `_turn_state` 现为只写死状态（`:31`/`:300`），易误认为参与判定 → **两条并入 Task 11**
- 状态：**Task 10 complete**（a6fe196 + 0f11aaf，含修复轮 1）

## Task 11: 顺手项 B —— 降级原因（§8#61）+ 测试可判别性（§8#64）+ 契约与鸭子类型（§8#65）+ 挂账 Minor
- BASE: 0f11aaf
- brief: task-11-brief.md
- dispatch: worker / deepseek-flash / run（2026-09-20）
- 裁定（控制器）：见 dispatch（含 7 条挂账 Minor 并入）
- 状态：dispatched（等报告）

### Task 2 中途状态（阻塞：待人类裁定）
- 实现全部完成、报告已写（`task-2-report.md`，13.1KB/174 行），**未提交**（按控制器指令：发现 plan 内部矛盾后不改阈值、不提交）。
- 当前 `bash tools/test.sh` = EXIT=1，全仓仅 1 条红：`[factions] 纯血权重高 + 魔法部弱 → 寡头制: 期望 <pureblood_oligarchy>，实际 <ministry_bureaucracy>`；其余 17 套件失败=0（`[factions]` 43 断言 / `[registry]` 212 / `[save]` 97 …）。
- 矛盾：spec §7.4 规则要求 `power_share()["pureblood"] >= 0.45`，但四角归一化下单角现实上限 ≈ 1/3（构造用例 0.3010、理论上限 0.3017、默认 0.1627）→ 该分支在任何合法状态都不可达。
- 实现者额外修掉的真问题（新噪音）：`from_dict → initialize` 撞上 save_test 的畸形载荷负例（`clock == null`）会喷 17 条 `SCRIPT ERROR`；已加 null-clock 防护，修复后回到基线 2 条。
- 已收口 Task 1 审查 Minor：#2 domains/aliases 校验、#3 base_power 类型、#4 era_overrides 必须存在且为 Dictionary + 「两处枚举一致」护栏断言（registry 210→212）。
- **阻塞**：等人类在 A（阈值 0.45→0.28，推荐）/ A2（→0.30）/ B（改测试摆 10 个数）/ C（改绝对实力语义）中裁定；裁定后 worker 只做「改一处常量 → 复跑 → 提交 → 回填报告」。
- **裁定（人类，2026-09-20）：A** —— 阈值 0.45 → 0.28（恢复 spec「占比」原意，只修算错的数值）。
- 控制器已先按「改计划再改代码」修正文本并**单独提交** `dabefab`（只动 spec+plan 两个 docs 文件）：
  spec §7.4 门限 0.45→0.28 + §13.2 勘误段（含实测 0.3010/0.3017/0.1627）；计划 Task 5 的 `oligarchy_pressure`
  死分支 0.40→0.26；计划 Task 2 规则代码同步 0.28。构造用例一字不改。
- Task 2 审查 BASE = `dabefab`（把控制器 docs 提交排除在代码审查范围外）
- 已 resume worker（run eec33780）执行：改一处常量 + 加注释 → 复跑 EXIT=0 → 提交 → 回填报告
- Task 2 实现完成：提交 `19654f0`（7 files, +405），**EXIT=0**；`[factions] 43 失败=0`、`[registry] 212 失败=0`、其余 17 套件失败=0
  - 裁定 A 已落地：`government_type()` 阈值 0.28 + 依据注释；构造用例一字未改
  - 实现者另修掉一个真问题：`from_dict → initialize` 撞 `save_test` 畸形载荷负例（clock==null）→ 17 条新 SCRIPT ERROR；加 null-clock 防护后回到基线 2 条
  - Task 1 审查 Minor #2/#3/#4/#5 已收口（domains 白名单/aliases 非空/base_power 类型/era_overrides 必须为 Dictionary + 两处枚举护栏 210→212）
- review package: review-dabefab..19654f0.diff（1 commit, 26055B；BASE 用 dabefab 以排除控制器 docs 提交）
- dispatch（审查）: reviewer / deepseek-flash / run 9d58c8e6-3ea2-4276-a9a2-05076bc68a12（2026-09-20）
- 审查：**Spec ✅ / Approved**，Critical 0 / **Important 1（plan-mandated，待人类裁定）** / Minor 6 → 工件 `task-2-review.md`
- ⚠️ 项控制器核对（`task-2-test-verify.log`）：`EXIT=0`、`[factions] 43 失败=0`、`[registry] 212 失败=0`、`SCRIPT ERROR` 2 条 = 基线 2 条、工作区干净、`*.uid` 未改写
- **待人类裁定（Important 1）**：`government_type()` 规则 1/3 用魔法部 **power**，spec §7.4 字面写「魔法部**控制权** < 0.4 / < 0.5」且规则 1 多了「凤凰社 power 最高」。实现=brief=计划=构造用例，spec 措辞是我写松了 → 建议 (a) spec §7.4 加勘误把实现口径写成权威（测试不动）；(b) 按字面补条件则须重订构造用例与阈值
- Task 2: minor (deferred→Task 4 收口，控制者裁定)：① 规则 2 的 `control.get(inst, law/wiz)` 回退语义 → 改 `float(control.get(inst, 0.0))` + 补用例；② null-clock 硬化补可直接断言的负例；③ `validate_content` 的 institutions/rivals/allies 补 `TYPE_ARRAY` 守卫；④ 补「era_overrides 引用不存在的时代」红例
- Task 2: minor (deferred, report-only)：空值防护不对称（生产不可达）；`factions.gd` 209 行（Task 5/6 后 ~450 行，届时评估拆分）
- 状态：**Task 2 complete**（19654f0）
- ✅ **Important 1 已裁定（人类，2026-09-20）：(a)** —— 改 spec、代码与测试一行不改。控制器已提交 `5525525`：
  spec §7.4 把**实现口径写成权威**（规则 1 = 战时 + `power_of(抵抗) > power_of(魔法部)`；规则 3 的「魔法部弱」= `power_of(ministry) < 0.5`）并附理由
  （第十一章「战争时期可能成为影子政府」；「凤凰社 power 最高」按字面几乎不可达，与 §13.2 的 0.45 同类笔误；`control` 的正确用法是规则 2 的独裁判定）+ 余量数据 + D5 措辞收紧
  + 规则 2「未声明按 0 计」收口登记在 Task 4

## Task 3: 玩家派系接口（standing + 三个 op + OpGuard + 存档校验）
- BASE: 19654f0
- brief: task-3-brief.md
- dispatch: worker / deepseek-flash / run 316f0069（2026-09-20）
- 裁定（控制器）：① `visible_faction_ids()` 本任务实现成最终版（Task 6 只加 `reveal()`）；② StateOps 层不钳 delta（钳制在 OpGuard=20，最终 standing ±100）；③ join 允许直接改换所属、outlaw 只警告不 rollback；④ 新断言用各文件既有变量名并插在 `return a.report(...)` 之前；⑤ save_codec 只加 `player.standing` 类型检查、不动 SAVE_VERSION
- Task 3 实现完成：提交 `f6bc495`（9 files, +157/-1），**EXIT=0**；`[factions] 43→60`、`[save] 97→107`、`[gm] 63→71`、`[llm] 84→88`，其余套件不变；`SCRIPT ERROR` 2 条 = 基线
- review package: review-19654f0..f6bc495.diff（1 commit, 23596B）
- dispatch（审查）: reviewer / deepseek-flash / run ebcd6551-4545-43cb-a9a5-4579c62ec191（2026-09-20）
- 审查：**Spec ✅ / Approved**，Critical 0 / Important 0 / Minor 6 → 工件 `task-3-review.md`
- ⚠️ 项控制器核对：绿步重跑 `EXIT=0`（`[factions] 60`/`[save] 107`/`[gm] 71`/`[llm] 88` 全 0 失败）、`SCRIPT ERROR` 2 = 基线 2、红步日志 `总计失败=4，失败套件=4` 且 4 条缺 API 逐条可辨、工作区干净
- Task 3: minor (deferred→Task 4 收口)：`join_faction` 直接改换语义无断言（补断言、不改代码）；`delta / 2` 向零截断（补负向奇数边界断言钉住，语义不改）
- Task 3: minor (deferred→Task 11 收口)：`llm_test.gd:117-121` 字符串拼接式弱断言 → 收紧为精确索引断言（§8#64 测试可判别性批次）
- Task 3: minor (deferred, park)：① `illegal_affiliation` 陈旧化（无读取端；**03c 必须定清除/归一规则**）；② `faction_standing_delta` 不鉴别 NaN/Inf（被 clampi 收口，无危害）；③ 嵌套校验只保护 `standing`（既有缺口，存档 v2 议题）
- 状态：**Task 3 complete**（f6bc495）；控制器 docs 提交 5525525（spec §7.4 裁定 (a)）

## Task 4: WorldFactions.evolve（演化 + 政体刷新）+ Task 2/3 审查 Minor 收口
- BASE: 5525525
- brief: task-4-brief.md
- dispatch: worker / deepseek-flash / run 2cee2bf4（2026-09-20）
- 裁定（控制器）：见 dispatch（含 6 条 Minor 收口：规则 2 回退改 0.0 / null-clock 断言 / validate_content 三字段 TYPE_ARRAY 守卫 / era_overrides 时代红例 / join 改换语义断言 / delta=-5 截断断言）
- Task 4 实现完成：`ee335b1`（factions.gd +107/-10、factions_test.gd +180）＋ `dd81fa2`（确定性证据补强 +10）
  - **实现者发现的计划缺陷（重要）**：brief 原有的两条压制断言**没有判别力**——注释掉 `apply_rival_pressure()` 后仍全绿（现代世界 `structure_pull(death_eaters)=+0.06` 使目标值仅 0.11，单靠回归就把 0.60 拉到 0.5691，已低于起点）。它保留原断言，另加①「可判别」用例（把 war_pressure/corruption 提到 1.0 抬高败者目标值、败者起点 0.06 → 只有真压制才会压回起点以下）②「单对精确幅度」最小夹具用例（断言跌幅恰 `SUPPRESS_RATE*0.35=0.0105`、胜者 `+0.00525`；在 17 派系真实表上多对叠加净跌 0.004752，故必须用最小夹具）。→ **待控制器改计划 Task 4 Step 4 的反证说明**（否则后续读者会照抄一份假证据）。
  - 断言：`[factions] 60→109→111`；全仓 `EXIT=0`、`SCRIPT ERROR` 2 = 基线
  - 破坏实验 S1/S2/S2b/S3/S4a-c/S5 六组，每组都逐字还原 + md5 校验
- review package: review-5525525..dd81fa2.diff（2 commits, 21447B）
- dispatch（审查）: reviewer / deepseek-flash / run 7e76fd11-4eba-4508-9676-bf734ff12cd2（2026-09-20）
- 审查：**Spec ✅ / Task quality = Rejected**，Critical 0 / **Important 1（真缺陷）** / Minor 7 → 工件 `task-4-review.md`
- ⚠️ 项控制器核对：`EXIT=0`、`[factions] 111 失败=0`、`SCRIPT ERROR` 2 = 基线
- **I1（Important，plan-mandated）**：`factions.gd:237` 的 `if oid <= id: continue` 让「字典序较大方单方声明」的敌对对被静默丢弃。**控制器独立复现：11 个敌对对中 5 个被丢**（auror_office↔black_market / black_market↔diagon_merchants / common_folk↔sacred_twenty_eight / death_eaters↔mysteries / death_eaters↔wizengamot）→ 黑市完全不受压制
- 处置：控制器先改计划文本 `6c35c26`（去重改「无向对键」+ rivals 非数组跳过 + 补「非对称声明必须生效」回归用例 + 反证说明改正：原「敌对强者压制弱者」断言**无判别力**），随后**修复轮 1**
- Task 4: minor (修复轮一并处理)：M1 报告账目、M2 自指断言、M3 `evolve` 早退、M5 种子余量
- Task 4: minor (控制器裁定)：M4 已含在 I1 修复内；M6 **不拆分** factions.gd（Task 5 后评估）；M7 额外缺失字段报错保留
- 修复轮 1: resume 原实现者 / run 369829c2（2026-09-20）
- 修复轮 1 完成：提交 `3223509`（只含 `src/rules/factions.gd` + `tests/factions_test.gd`），**EXIT=0**、`[factions] 111→115 失败=0`、`SCRIPT ERROR` 2 = 基线（控制器复核 `task-4-fix1-verify.log`）
  - I1：去重改无向对键（`pair_key` + `seen`）+ `rivals` 非数组跳过 + `oid.is_empty()/==id` 跳过；新增「非对称声明」回归用例（改前 113 断言 1 红 → 改后 115 绿）；实测 `seen` 键数 = 11（旧实现只处理 6 对）
  - M3：`evolve()` 加 `world==null or registry==null or clock==null` 早退 + 2 断言（改前两条 nil 访问 SCRIPT ERROR → 改后绿）
  - M2：改为真逐字段遍历（`compared_fields` 现为观测值 102 = 17 派系 × 6 键 + 差异列表 + `JSON.stringify` 冗余护栏）
  - M5：删除与 seed 挂钩的「power < 起点」断言（余量 0.0043），保留与 seed 无关的 `near(power, SUPPRESS_FLOOR)`；并说明为何它 seed 无关（death_eaters 同时是 4 对败者，累计压制 ≈0.06 ≫ 噪音 ±0.02）
  - M1：报告账目改为审查者逐条核过的构成（60 + 51 = 111）+ 修复轮 +4 = 115
- scoped 复审: reviewer / deepseek-flash / run f33a7ea9（review-6c35c26..3223509.diff，1 commit 12321B）
- scoped 复审：**Fix round 1 = Accepted**（I1/M1/M2/M3/M5 全部已解决）→ 工件 `task-4-rereview.md`
  - 复审者独立复算：无向对键在两种迭代顺序下都得到 `min|max`（每对恰好一次）；内容表 11 对 / 旧实现 6 处理 5 丢，与控制器实测逐字吻合；保留的 M5 断言经数值+反证双向确认「无压制时对任何 seed 必红」（余量 56×容差）
  - 新引入 Minor N1：`tests:387-388` 两条 M3 断言**无判别力**（`evolve -> Array`，中止时返回默认 `[]`）→ **控制器裁定接受并登记**（M3 的真正看护是「SCRIPT ERROR 条数 = 基线 2」通道，每轮都在核）
  - 新引入 Minor N2：计划 Task 4 的 `evolve()` 块缺早退（Task 5 照抄会丢守卫）→ 控制器**已改计划** `a1fa03d`；测试注释数字失真（4 对 → 6 对）并入 Task 5 顺手改正
- 状态：**Task 4 complete**（ee335b1 + dd81fa2 + 3223509，含修复轮 1）

## Task 5: tension 社会矛盾 + 政治事件 + tick() 接线
- BASE: a1fa03d
- brief: task-5-brief.md
- dispatch: worker / deepseek-flash / run 3f34b624（2026-09-20）
- Task 5 实现完成：提交 `ab9ceb8`（7 files, +369-7），**EXIT=0**；`[factions] 115→155`、`[registry] 212→237`、`[world_tick] 104→151`、`[save] 107`（内容变化）、其余 15 套件不变；`SCRIPT ERROR` 2 = 基线（控制器复核 `task-5-test-verify.log`）
- 状态：DONE_WITH_CONCERNS，三条 concerns 控制器已处置：
  - **A（超 brief 的必要新增）**：接演化后 `[save]` 的既有不变量「读档后重建引擎续跑：世界状态一致」因 **1 ULP** 变红（`§8#50`：JSON double 往返不逐位，被回归+噪声长尾浮点新触发）。实现者加 `QUANTIZE_DECIMALS=4` + `quantize()/quantize_state()`（幂等、只用于持久化游戏数值）→ 恢复该不变量。**控制器已并入计划** `aa152d2`，并注明它只**收窄** `§8#50` 触发面、存档 v2 仍是独立议题。
  - **B（计划文本缺陷）**：计划 tick 片段写 `evolve(world)`，但该片段在 `WorldState.tick()` 内（无 `world` 变量）→ 实现者用 `self`；**控制器已改计划** `aa152d2` 并加注说明。
  - **C**：实现者放松了**自己新写**两条断言的容差（1e-6 → 2e-4，因量化）；既有断言一条未动（`save` 的严格等式反而因量化重新变绿）→ 交审查判定是否诚实。
- 实现者自曝的两个**断言盲区**（有价值）：E2 首跑没红（`oligarchy_pressure` 的 OR 另一条救场 → 补专用夹具 + 前置断言）；E6 首跑是套件中止而非干净失败（`e["rumor_id"]` 下标访问抛错 → 改 `e.get("rumor_id","")`）。后者正是仓库既有 `§8#56` 的陷阱。
- review package: review-a1fa03d..ab9ceb8.diff（1 commit, 33380B）
- dispatch（审查）: reviewer / deepseek-flash / run c4afe7f1（2026-09-20）
- 审查：**Approved**，Critical 0 / **Important 1（死断言）** / Minor 9 → 工件 `task-5-review.md`（待写）
  - A/B/C 三条 concern 均**判成立**（量化=已登记 §8#50 的收窄非掩盖；`self` 无遗留裸 `world`；2e-4 未触碰既有容差、仍能抓 0.1 量级回归）
  - 审查者独立算出的有价值结论：① 六项点名风险逐条否证/降级；② `last_major_turn` **共用**导致「高张力时代政治事件几乎吃掉全部重大配额、现代 era 一个都不触发」的系统性偏向（Minor 6，需按 era 普查后调参）；③ 量化 vs `last_change_turn` 的 0.2%/派系/月 不自洽（Minor 2，给了最小修法）
- 控制器：已改计划 `ad67396`（测试 key 改 `event_id`；`pick_political_event` 加副作用提示）→ **修复轮 1**（run aa334555）
- 修复轮范围：I1 死断言（换高张力夹具或删除 + 必须能失败）、M2 量化后再判 `last_change_turn`、M3 补「走 flags 路径」的判别断言、M4 注释数字口径（控制器给的 0.06 有误）、M1 副作用注释
- Task 5: minor (deferred, park)：M5 §8#50 只收窄（**Task 13 必须保证不被当"已结案"**）、M6 按 era 的事件配比普查、M7 `factions.gd` 428 行拆分、M8 `secrecy_crisis` 无内容
- 修复轮 1 完成：提交 `413cd3f`（3 files, +94-17），**EXIT=0**、`[factions] 155→160`、`[world_tick] 151→154`、`SCRIPT ERROR` 2 = 基线（控制器复核 `task-5-fix1-verify.log`）
  - I1：选方案 (a) 高张力夹具——每月重置 `world_vars` 到极端值 + 玩家 `location_id` 空串（传闻候选为空 ⇒ 配额纯归政治事件）→ 间隔断言变成**无条件**强断言；实测事件在第 1/13/25/37 回合（4 次、最小间隔恰 12）；前置 2 条防空转；破坏实验 I1-a（pick 恒返回 {}）→ 红、I1-b（不写 `last_major_turn`）→ 红（旧版两种破坏下都绿）
  - **M2：实现者没有只做最小修法，而是发现了更深的原因**——最小修法（先量化再判）当场跑出 **55/510** 个假标记；根因**不是量化**，而是**敌对压制把值改回来了**（回归把 death_eaters 推到 0.0501 并标记，紧接着它作为 6 对的败者被压回 0.05 → 持久值 0.05→0.05 却带"本月变了"标记）。改为「快照本回合起始量化值 → 回归 → 压制 → 量化 → 统一判定」⇒ `last_change_turn` 语义从「回归是否改动」变为「**本回合持久值是否改动**」（双方向自洽）。**控制器裁定接受该语义**（字段无生产读取方；「持久值变过」更自洽）。M2-a 复现旧 bug（56 不一致）、M2-b 去掉统一判定（453 不一致）→ 新循环承重
  - M3：补「写 flag 后改 world_vars → tension_of 不变、compute_tension 变」+ 前置断言 + 缺 flag 回退；破坏实验（tension_of 改现算）→ 红
  - M4/M1：注释口径订正 + 副作用提示（控制器给的 0.06 是错的，已改准确口径）
- 新增未验证项（登记）：① `apply_rival_pressure` 现在会影响 `last_change_turn`（控制器已接受该语义）；② M2 断言样本 510（30 回合 × 17 派系）未覆盖「目标值 = 当前值」的完全静止世界；③ I1 夹具每月重置 world_vars 是测试装置，真实频率仍未普查（M6）
- scoped 复审: reviewer / deepseek-flash / run 2998066b（review-ad67396..413cd3f.diff，1 commit 15670B）
- scoped 复审：**Fix round 1 = Accepted**（I1/M2/M3/M4/M1 全部已解决）→ 工件 `task-5-rereview.md`
  - 复审者独立核实了 I1 夹具的关键前提（`new_default().location_id == ""` + 17 条传闻 zones 均非空 ⇒ 候选集为空 ⇒ 配额纯归政治事件）
  - M2 语义决定：三条评估全过（双向自洽、无新问题、样本数 510 是观测值）
  - 新引入 Minor：① 三处错字「过阀」应为「过阈」（并入 Task 6）；② 附赠断言近乎恒真（report-only）
- 状态：**Task 5 complete**（ab9ceb8 + 413cd3f，含修复轮 1）

## Task 6: 信息保护 —— reveal() + 传闻揭示 + 派系传闻内容
- BASE: 413cd3f
- brief: task-6-brief.md
- dispatch: worker / deepseek-flash / run 898f2479（2026-09-20）
- Task 6 实现完成：提交 `51a3455`（6 files, +156-7），**EXIT=0**；`[factions] 160→184`、`[registry] 237→244`、`[world_tick] 154`（仅错字）、其余不变；`SCRIPT ERROR` 2 = 基线（控制器复核 `task-6-test-verify.log`）
  - `reveal()` 四约束 + `apply_rumor_reveals` 填实（去掉 `pass`）+ 4 条带 `reveals_faction` 的派系传闻（`major:false`、`min_year:0`、四个 zones id 经控制器核实存在）
  - **端到端确定性做法（值得记）**：用 `Registry.from_tables()` 复制默认内容表、把 `rumors` 换成"只留 `rumor_marked_ones` 一条"，玩家 `location_id="knockturn_alley"`（落在其 zones 内）⇒ 候选集恒为这一条 ⇒ 把"随机抽中传闻"变成确定事件，且仍走真实的 `tick → events → apply_rumor_reveals → reveal` 链路（不走捷径直接调 `reveal()`）
  - 破坏实验 D1–D5 证明断言承重（D1 去掉 system 拒绝 → 4 红；D2 去掉幂等 → 2 红；D3 还原 `pass` → 5 红；D4/D5 删校验 → 各 1 红），每组后 md5 逐字还原
  - 声明性偏离：新 4 条传闻多加 `weight`/`requires_flags` 两个键以求与既有 16 条同形（`requires_flags: []` 等价无前置；`weight` 仍未生效，属 Task 12 的 §8#16 范围，**未提前实现**）
- review package: review-413cd3f..51a3455.diff（1 commit, 23842B）
- dispatch（审查）: reviewer / deepseek-flash / run e2475682（2026-09-20）
- 审查：**Approved**，Critical 0 / **Important 1（错字改成了另一个错字 + 报告失实陈述）** / Minor 6 → 工件 `task-6-review.md`（待写）
  - 审查者对行为面全部认可，并**判定端到端夹具不是假绿**（全量复制注册表 + 唯一候选 + 两道前提守卫 + 精确计数断言）
  - 点名 5 风险结论：① 夹具前提成立（`Registry.TABLE_FILES.keys()` 全量复制）② `last_change_turn` 双写**不会**被清掉/覆盖，但**语义双写**削弱了 Task 5 的不变量（Minor 1，控制器裁定）③ 声明性偏离接受（既有 16 条确实都带 `weight`/`requires_flags`）④ 引用检查不误报 ⑤ 唯一真实耦合是 `factions_test.gd:629-651` 的 `last_change_turn` 双向断言（今天绿得依赖内容/随机而非设计）
- 控制器：已改计划 `28d3a4d`（**裁定 `last_change_turn` 语义单一化为「power 变更回合」→ `reveal()` 不再写该字段**；否决"新增 `revealed_turn` 字段"）→ **修复轮 1**（run ca2ecffe）
- 修复轮范围：I1 错字（`过隘`→`过阈` + 测试里 `死阀值`→`死阈值` + 更正报告失实陈述）、M1 reveal 不写 last_change_turn + 断言、M2 收紧弱断言、M3 reveal 补空守卫、M5 两条传闻 `min_year`→1970（组织语境）、M6 补登记 `label`
- Task 6: minor (deferred→Task 7 dispatch)：跨存档未覆盖 `revealed`（读档后仍可见/不可再加入）
- 修复轮 1 完成：提交 `537bd68`（3 files, +35-6），**EXIT=0**、`[factions] 184→191`、`SCRIPT ERROR` 2 = 基线（控制器复核 `task-6-fix1-verify.log`）
  - I1：`过隘`→`过阈` + `死阀值`→`死阈值` + **报告页首加更正声明**（承认首轮自述失实）；全仓 `grep "过隘|过阀|死阀"` 零命中
  - M1：`reveal()` 删掉 `last_change_turn` 写入（字段语义单一化）；断言用"哨兵法"（置 4242 → reveal → 仍 4242），破坏实验 R1 恰好 1 条红
  - M2：history 断言改为「恰好一条 `kind=faction_revealed` + 文案非空」
  - M3：补 `world/registry/clock == null` 早退 + 3 条断言；**但它如实报告这 3 条断言在破坏下全绿**（GDScript 中止时返回类型默认值 `false`，恰好满足 `is_false`）——真判别通道是 stderr 计数（R2 下 `SCRIPT ERROR` 2→4）。与 Task 4 审查 N1、仓库 `§8#56` 同源 → 交复审评估
  - M5：`rumor_marked_ones`/`rumor_phoenix_network` 的 `min_year` → **1970**（组织语境），另两条保持 0；并补「世界年份 2010 ≥ 1970」前置断言防静默空转（R3 把它改成 3000 → 6 条红）。附带发现：`data/eras.json` 的 **modern.start_year = 2010**（不是 1991），控制器已独立核实
  - M6：报告补登记新条目还加了 `label`（`registry.validate()` 强制要求）
- 控制器：已改计划 `0be229f`（计划补 `reveal()` 空守卫，修 Minor 3 的计划漂移）
- scoped 复审: reviewer / deepseek-flash / run 30f21d41（review-28d3a4d..537bd68.diff，1 commit 16307B）
- scoped 复审：**Fix round 1 = Accepted**（I1/M1/M2/M3/M5/M6 全部已解决）→ 工件 `task-6-review.md`（含首轮审查 + 修复轮 + 复审三段）
  - 复审者独立复核 M3 诊断**正确**，并给出**真正可用的状态型护栏**：换 `registry` 合法、`clock == null` 的世界 → 删守卫会穿透写入 `world.factions`（`revealed=true` 已持久化）→ 断言 `state_of(half,"death_eaters").is_empty()` 有守卫绿/删守卫红 → **并入 Task 7 dispatch**
  - 新引入 Minor：P2-1 三条 M3 断言非护栏（同上补一条）；P2-2 计划漂移（控制器已 `0be229f` 补齐）
- 控制器核对 ⚠️：① 绿步 `SCRIPT ERROR` 2 = 基线 ✅；② `git log -1 537bd68` 提交正文**已纠正失实陈述** ✅；③ 复审者对 `§8#56` 引用略宽（先例实为 §8#48 / plan-01:4143），措辞问题不影响结论
- 状态：**Task 6 complete**（51a3455 + 537bd68，含修复轮 1）

## Task 7: 势力面板重写（第六十五章；修 §8#7）
- BASE: 537bd68（+ 控制器 docs 0be229f）
- brief: task-7-brief.md
- dispatch: worker / deepseek-flash / run cb2ac7d8（2026-09-20）
- Task 7 实现完成：提交 `9e896de`（5 files, +161-15），**EXIT=0**；`[panel] 71→99`、`[factions] 191→193`、`[save] 107→112`、`[world_tick] 154→180`，其余不变；`SCRIPT ERROR` 2 = 基线（控制器复核 `task-7-test-verify.log`）；**另复跑 `bash tools/b1_acceptance.sh` → 78 断言 0 失败**（对外验收通道未被面板重写破坏）
  - holder 未揭示 → 「未知势力」（值照常显示）；BE4 反证「傲罗指标改读 world_vars 必红」⇒ §8#7 真的修好了
  - 三条收口落地：4a 状态型护栏（BE1 删守卫必红，补上了 Task 6 三条 `is_false` 做不到的那条）、4b 跨存档 revealed（BE2）、4c 每条传闻事件带 rumor_id（BE3，用 `.get`）
  - 报告自曝测试 bug 两个（`panel_test` 重复声明 `power`、`world_tick_test` 变量名冲突）+ 一个小坑（神圣二十八族也声明 wizengamot，故 holder 平局需设 0.91 才能压过它）
  - 残余登记：① 政体缓存 3 条断言是写报告阶段补的（不在初始 TDD 红步）；② 【已知势力】顺序用 `sort_custom` 不保证稳定（同实力者顺序未断言）；③ 隐藏派系的 control **值**仍显示（有意：值=世界事实、只隐藏身份）；④「部长」一栏暂以「控制执法司的派系」代替（NPC 系统属计划 05）
- review package: review-0be229f..9e896de.diff（1 commit, 18488B）
- dispatch（审查）: reviewer / deepseek-flash / run 2b83a0b9（2026-09-20）
- 审查：**Approved**，Critical 0 / **Important 0** / Minor 7 → **无修复轮**。工件 `task-7-review.md`
- ⚠️ 项控制器核对：`bash tools/b1_acceptance.sh` → **断言 78 / 失败 0 / EXIT=0**（`task-7-b1-verify.log`）⇒ 面板重写未破坏对外验收通道
- 审查者判定 §8#7 修复方式为「结构性 + 行为式」双证据（`is_false(world_vars.has("auror_office"))` 排除标量来源 + 改 control 观察面板）
- Task 7: minor (deferred→Task 8)：M4 `b1_acceptance.gd:269` 文案过期 + 面板零回归判别力；M5 `player_panel` 的【所属势力】打印原始 id（应用 `_label`）
- Task 7: minor (控制器裁定/登记)：M1 隐藏派系**值**显示=接受（保护的是身份；升级条件已写明，留 03b/05 评估模糊化）；M2 `_institution_value` 默认值不可达；M3 并列顺序（若断言第 2/3 名须先定平局序）；M6 霍格沃茨行去掉正典「派系」字段=接受（Task 13 登记偏差+理由）；M7 报告次数口径 + `panel_test` 硬编码 `base_power`
- 状态：**Task 7 complete**（9e896de）

## Task 8: PromptBuilder.state_digest 暴露已揭示派系（Q4）+ Task 7 两条 Minor
- BASE: 9e896de
- brief: task-8-brief.md
- dispatch: worker / deepseek-flash / run 0c56f952（2026-09-20）
- Task 8 实现完成：提交 `8bc42e9`（5 files），**EXIT=0**；`[prompt] 13→34`、`[panel] 99→102`、B1 探针 `78→82`，其余不变；`SCRIPT ERROR` 2 = 基线（控制器复核 `task-8-test-verify.log`）
  - **它又一次发现计划缺陷**：brief/计划的 Task 8 是照「文本摘要」写的（`lines.append("政体：…")` / `digest.contains(...)`），但 `state_digest()` 实际返回 **Dictionary**（`build()` 用 `JSON.stringify` 塞进 user_prompt）→ 照抄会 `Nonexistent function 'contains'` 中止套件；改用**加两个键** `government`/`known_factions`（控制器已核实 `prompt_builder.gd:12` 为 `JSON.stringify(state_digest(world))` ⇒ 新键必然进提示词）
  - 信息保护破坏实验：把 `visible_faction_ids()` 的 revealed 判断改成 `if true:` → `[prompt]` 8 条红 + `[panel]` 4 条红（跨套件互相印证）；还原后 md5 一致
  - **它抓到并正确处理的假红**：「神圣二十八族」同时是 `data/bloodlines.json` 的**公开血统 label**（建角可见，出现在 `system_prompt` 的 content_index 里）——它**没有**偷偷把词从断言里删掉，而是写成「显式豁免血统名 + 仍断言作为未揭示派系不得进 `known_factions`」
  - 收口 M4/M5：B1 探针文案更新 + 4 条行为型断言（走 `node.call("_on_power")`）；`player_panel` 所属势力改 `_label`；并发现探针实测控制权是 **0.62**（跑了 4 回合后漂移）故期望值必须现读而非硬编码 0.60
- 控制器：已改计划 `5aef800`（Task 8 改为「加键」形态 + 键集合断言 + 五条实跑教训）
- review package: review-9e896de..8bc42e9.diff（1 commit, 13356B）
- dispatch（审查）: reviewer / deepseek-flash / run 77cca4a3（2026-09-20）
- 审查：**Approved**，Critical 0 / **Important 0** / Minor 7 → **无修复轮**。工件 `task-8-review.md`
- ⚠️ 项控制器处置：① spec Q4「权力四角权重」→ **裁定不需要显式暴露**（`power_share()` 是已列 power 的纯函数，重复；`government` 已表达格局）→ 已改 spec 措辞为「+ 政治格局 + 勘误」；② `git status --porcelain` **空**（破坏实验后工作区干净）；③ 真实 LLM 叙事质量属 B2（已裁定暂不做）
- 审查者用**源码推演破坏面**（忽略 revealed 应红 8 条）再与 `task-8-destruction.log` 对照 → **恰好 8 条**，且 `[gm]`/`[factions]` 连锁变红 ⇒ 判定信息保护断言真有判别力
- Task 8: minor (deferred→Task 11)：M1 「空可见集 → `已知势力：无`」分支无断言；M5 `gov_id` 取法 3 行重复（可提 `WorldFactions.government_id`）
- Task 8: minor (登记)：M2 报告 §8.4 措辞失实（`_label` 未知 id 回退原始 id）+ 未揭示-but-valid faction_id 会显示 label（仅畸形存档可达）；M3 计划/实现漂移（**控制器已改计划 `783f8d1`**）；M4 键集合断言抓不到键顺序；M6 `state_digest` 无 initialize 防御；M7 报告摘录不全
- 状态：**Task 8 complete**（8bc42e9）


### 推送记录
- 2026-09-20：`git push origin plan-03-factions` → `12f6a50..a1fa03d`（10 commits：Task 1–4 全部提交 + 3 个控制器 docs 提交）。此后每个任务完成后都会推送一次，避免本地积压。

## Task 9 预备：控制器对 Task 1 审查 Minor 1 的裁定（2026-09-20）
- 事实核对（`data/factions.json`）：`black_market.aliases = ["翻倒巷黑市","黑市","翻倒巷"]`，而 `diagon_merchants.aliases = ["对角巷商会","商会","店主们"]`（**没有**裸「对角巷」）。
- **裁定：删掉裸地点名「翻倒巷」**（保留「翻倒巷黑市」「黑市」）。理由：Task 1 实现者自己声明的策略（报告「自主决定 4」）就是**刻意不收录裸地点名**，以免「我去对角巷打工赚钱」这类普通动作被误判成派系动作；数据里的「翻倒巷」与它自己的策略矛盾 → 删掉是**恢复声明的意图**，不是改设计（与前面 0.45/0.28、power vs control 两处同类：都是我/实现者笔误，不是设计分歧）。
- 注册给 03b/05：**地点 → 派系**的识别应该用「地点 + 动作」组合（例如「去翻倒巷卖东西」），而不是把地点名塞进 `aliases` 做子串匹配。

## Task 9: 离线替身派系关键词接线（加入/退出/支持/反对）
- BASE: 8bc42e9（+ 控制器 docs 783f8d1 / e4c3e59）
- brief: task-9-brief.md
- dispatch: worker / deepseek-flash / run cea075fb（2026-09-20）
- 控制器裁定（随 dispatch）：
  ① **删掉 `black_market.aliases` 的裸地点名「翻倒巷」**（保留「翻倒巷黑市」「黑市」）——恢复 Task 1 实现者自己声明的策略；并要求一条回归断言「我去翻倒巷买点材料」不得被识别成黑市动作，而「翻倒巷黑市」仍可识别（先揭示）
  ② `FACTION_JOIN` 里含省略号的死关键词「为…做事」→ **「做事」**（计划已改 `e4c3e59`；派系分支要求同句命中已揭示派系名，故「我想做点事」不会误触发）
- 点名风险：① 分支顺序（施法后、TRAIN 前；未命中派系词不得提前 return）② 多派系同句的 tie-break（id 字典序取首个，须确定性 + 断言钉住）③ 未揭示派系不得产出 op ④ 泛称别名（「部长」/「那个人」）在未揭示时不命中（只扫可见集）
- Task 9 实现完成：提交 `a36faab`（3 files, +143-1），**EXIT=0**；`[gm] 71→102`、其余套件不变；`SCRIPT ERROR` 2 = 基线（控制器复核 `task-9-test-verify.log`）；**B1 探针 82/0**（降级路径未破坏验收）
  - `FACTION_JOIN/LEAVE/SUPPORT/OPPOSE` + `_detect_faction()`（只扫 `visible_faction_ids`）；分支插在施法后、TRAIN 前，未命中不提前 return
  - 控制器裁定落地：`black_market.aliases` 删掉裸地名「翻倒巷」（实测现为 `["翻倒巷黑市","黑市"]`）+ 7 条别名回归断言
  - 4 组破坏实验：D-A 提前 return（10+5 红）、D-B 忽略揭示扫全表（4 红）、D-C 加回「翻倒巷」（2 红）、D-D tie-break 反过来（1 红）；每组后 md5 逐字还原
  - 如实登记：红步是**套件中止**（测未实现 API 的固有结果，非测试缺陷）；tie-break 按 id 序「确定但粗糙」（真实玩法由 LLM 主路径承担语义）；名词性文本歧义（「我最讨厌食死徒」→ 落 idle，不误判为支持）
- review package: review-8bc42e9..a36faab.diff（4 commits，其中 3 个是控制器 docs；审查只需看代码提交 `a36faab` 的 3 文件）
- dispatch（审查）: reviewer / deepseek-flash / run 41dbd54b（2026-09-20）
- 审查：**Approved**，Critical 0 / **Important 0** / Minor 8 → **无修复轮**。工件 `task-9-review.md`
- 审查者逐条自查：① 分支顺序/不吞普通动作 ✅（`:88` 的 if 包住四分支）② tie-break 确定 ✅（`registry.ids()` 显式 sort → id 字典序首个；并按 17 条内容反推确认「我支持魔法部和古灵阁」唯一先命中 gringotts）③ 未揭示是**双门**（脚本只扫 visible + state_ops 也校验）④ 别名歧义 ✅ ⑤ 降级路径/tags 无回归 ✅（「确认自检」在 UI 层就被短路）
- Task 9: minor (deferred→**Task 10**)：M1 `aliases as Array` 运行期无第二道门（2 行守卫）；M2 `faction` tag 不在 LLM 白名单（契约漂移，各 1 行）；M3 `leave_faction` 不带目标派系（旁白与归属可能不一致）
- Task 9: minor (deferred→**Task 11**)：M4 回退路径缺断言；M5 旁白 label 无法区分硬编码（用临时 registry 改名验证）；M8 `faction_standing_delta` 缺 revealed 校验
- Task 9: minor (登记)：M6 报告 §⑧ D-A「10 条全红」是**过度声明**（实际约 4 条，方向成立）；M7 红步为套件中止（可接受，建议后续把「测新 API」与实现分开以保留一次干净失败）→ Task 13 写入 HANDOFF §4 踩坑
- 状态：**Task 9 complete**（a36faab）

## Task 10: 顺手项 A —— UI 等待期看门狗（§8#58/#62）+ provider 复用/timeout/dispose（§8#63）+ Task 9 三条 Minor
- BASE: a36faab
- brief: task-10-brief.md
- dispatch: worker / deepseek-flash / run 3061f0b8（2026-09-20；中途因破坏实验死锁被控制器清进程 + steer 纠正）
- Task 10 实现完成：提交 `a6fe196`（10 files, +243-21），**EXIT=0**；`[gm] 102→116`、`[llm] 88→97`、`[prompt] 34→35`，其余不变；`SCRIPT ERROR` 2 = 基线；**B1 探针 82→91 断言 / 0 失败 / EXIT=0**（控制器复核 `task-10-test-verify.log` + `task-10-b1-verify.log`）
  - 看门狗：`turn_timeout_sec`（180s，`HALI_TURN_TIMEOUT_SEC` 覆盖）+ `_run_turn` 独立协程 + deadline 轮询 → **恢复出口唯一**；破坏实验 A（删恢复两行）→ 探针 7 条红（含 Part 9 两条）；W2（只删超时提示）→ 恰好 1 条红
  - provider 卫生：`ensure_http/http_timeout_sec/dispose/mask`；破坏 B（每次新建 + dispose no-op）→ `[llm]` 2 红；B2（timeout 只设一次）→ 1 红
  - M1/M2/M3 全部落地；**实现者实测订正了我的诊断**：`"黑市" as Array` 不是返回 null，而是 `Invalid cast` 中止 `_detect_faction` 自身，因返回类型是 `String` ⇒ 调用方得 `""`、**套件不会中止**，真实后果是「静默降级 + 每条 stderr 噪音 + 跳过 id 靠后的派系」
  - **教训（写进计划与台账）**：破坏实验一律「保留 deadline、只删恢复/提示」；探针改用 `_submit_bounded()`（只轮询可观测信号 + 5s 上限，不 `await` 被测协程）⇒ 即使被测代码没有看门狗，探针也能干净变红并退出
- review package: review-a36faab..a6fe196.diff（2 commits，其中 `35f43ca` 是控制器 docs）
- dispatch（审查）: reviewer / deepseek-flash / run 3b253a36（2026-09-20）
- 审查者第 1 次失败（**不是**发现不了问题）：run `3b253a36` 跑了 150s、`exitCode=1`、输出 29.6k tokens、`windowPeak=64244` → 判定为**超出其上下文/输出上限**（它读了太多文件、内部独白过长）。
- 控制器处置：① 重生成**只含代码提交**的审查包 `review-35f43ca..a6fe196.diff`（33KB，排除控制器 docs 提交）；② 重派时**精简指令**（只判定 3 件最关键的事：恢复出口唯一性/迟到结果污染/provider 生命周期与脱敏；其余简答），并明确要求「只读 1 次 diff、最多 4 次 grep、报告 ≤120 行、不整文件打印源码」。
- 重派：reviewer / deepseek-flash / run 652777a4（2026-09-20）
- 经验（给 Task 13 的踩坑清单）：**审查任务要控制输入体量**（diff 越大越要限定阅读预算），否则 64k 窗口的 reviewer 容易在长独白里撞上限而失败。
- 审查（第 2 次，成功）：**Approved**，Critical 0 / **Important 1（plan-mandated，我的计划写错）** / Minor 4 → 进修复轮
  - **I1 的真实缺陷**：看门狗与 `_run_turn()` 共用成员字典 `_turn_state`，而 `done=true` 是 await **之后**的独立语句 ⇒ 超时后迟到的旧协程会把 `done=true` 写进**新一轮**字典 ⇒ 提前退出 / 渲染错位 / 空字典抛错 ⇒ **恢复被跳过（§8#62 回归）**
  - 审查者确认：`mask()` 覆盖所有返回路径 ✅；`dispose()` 后不存在对已释放节点 `request` ✅；既有 `[gm]`/`[llm]` 断言全保留 ✅
- 控制器：已改计划（`f97f2fc`：本轮私有 `round_state` + 恢复前置于渲染 + engine 空守卫 + `.get` 兜底）→ **修复轮 1**（run 71cfa8c9）
- 修复轮 1 完成：提交 `0f11aaf`（2 files），**EXIT=0**；探针 **101→105 断言 / 0 失败**（控制器复核 `task-10-fix1-*`）
  - R1-3：**实现者发现我的守卫不够**——`_run_turn` 里的 `engine == null` 只是 `return`、不置 `done` ⇒ 仍要等满超时（实测 5010ms）；它另加 `_on_command_submitted` 的立即恢复分支（实测 **3ms**）→ 控制器已把这条补进计划（`b257c54`）
  - **R3（重要且诚实）：I1 机制成立但「黑盒不可达（No Repro）」**——`_run_turn` 是 fire-and-forget 内层协程；外层到点返回后内层挂起链失去唯一引用、被 Godot 丢弃 ⇒ `await` 永不恢复 ⇒ 迟到写**执行不到**。黑盒实验（共享字典版 vs 修复版）逐条 PASS 一致、turn 不推进；语言级最小实验（已删）证明「只要执行就会污染」。⇒ 该组新断言**不是 I1 的回归护栏**（它钉的是可观测契约；本轮唯一有红→绿证据的是 engine 立即恢复那 3 条）
  - 控制器裁定：**保留修复**（把"依赖协程 GC 时序"的隐含假设变成显式不变量，成本为零），并把 I1 在台账登记为「机制已证实 / 黑盒不可达」+ 明确写出该组断言不作护栏；若将来有人 `await _run_turn(...)` 或引擎改变挂起链持有语义，缺陷即变可达（登记为条件性风险）
- scoped 复审: reviewer / deepseek-flash / run 5d0e2a5b（review-f97f2fc..0f11aaf.diff，1 commit 15496B）
- scoped 复审：**Fix round 1 = Accepted**（四处落地、控制流无漏渲染、同意「机制成立但黑盒不可达」、新引入 0 功能问题）→ 工件 `task-10-review.md`（含首轮审查 + 修复轮 + 复审三段）
  - 复审者独立确认：生产路径**无任何**持有 `_run_turn` 内层句柄的地方（唯一调用点 `:301` fire-and-forget，FunctionState 立即丢弃）⇒ No Repro 结论可信
  - 新引入 P2：① `tools/b1_acceptance.gd:133/:461` 措辞与同函数 `:500-501` 的自我否认冲突（暗示 hold_ref 可复活迟到协程）；② `_turn_state` 现为只写死状态（`:31`/`:300`），易误认为参与判定 → **两条并入 Task 11**
- 状态：**Task 10 complete**（a6fe196 + 0f11aaf，含修复轮 1）

## Task 11: 顺手项 B —— 降级原因（§8#61）+ 测试可判别性（§8#64）+ 契约与鸭子类型（§8#65）+ 挂账 Minor
- BASE: 0f11aaf
- brief: task-11-brief.md
- dispatch: worker / deepseek-flash / run（2026-09-20）
- 裁定（控制器）：见 dispatch（含 7 条挂账 Minor 并入）
- 状态：dispatched（等报告）

### Task 10 事故记录（2026-09-20，控制器介入）
- 现象：worker 的 bash 工具卡住 >4 分钟、无活动；`tasklist` 显示两个 Godot 进程（14976 占 225MB、17248 占 8MB）。
- 根因（控制器诊断）：Part 11 的 `HangProvider` 用 3600s 定时器模拟"永不返回"；某组破坏把**看门狗 deadline 变成永不触发** ⇒ `_on_command_submitted` 的协程永不返回 ⇒ 探针 `await` 挂住 ⇒ bash 死锁（**不是**测试红）。
- 处置：按 `HANDOFF §4` 第 6 条清孤儿进程（`taskkill //PID 14976 //F`，17248 已自行退出）→ 向 worker 发 steer：改用"不会挂住"的破坏方式（保留 deadline、只删恢复两行/超时提示 ⇒ 探针仍会在 0.4s 后结束、断言干净变红），并要求外部 `timeout 180` + 每组实验后查残留进程。
- 耐久修正：计划 Task 10 Step 4 的验证命令已改为带 `timeout 300`，并写明该死锁陷阱（控制器提交）。
- 待办：Task 13 把「破坏实验可能死锁 / 必须加外部 timeout / 查残留 godot 进程」写进 `HANDOFF §4` 踩坑清单。

### ⏸️ 暂停点（人类要求改小计划，2026-09-20）
- 人类指示：**Task 11 这轮做完先停**，他那边要改一个小计划。
- 控制器承诺：Task 11 走完「实现 → 审查 → findings 处置（必要时修复轮 + scoped 复审）→ 推送 → 台账」后**暂停**，**不**自动派发 Task 12 / Task 13。
- 恢复时必须先读：人类改过的小计划（可能是本计划文件 `docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md`，也可能新增/调整任务）。若计划文本被改动，受影响的 Task 12/13 需要**重新抽取 brief**（`scripts/task-brief PLAN N`）再派发；Task 1–11 已完成的部分不受影响。
- Task 11 在跑时的工作区改动（未提交）：`src/core/turn_engine.gd`、`src/gm/game_master.gd`、`src/gm/llm_game_master.gd`、`src/gm/prompt_builder.gd`、`src/rules/factions.gd`、`src/rules/state_ops.gd`、`src/ui/main.gd`、`src/ui/panel_formatter.gd`（+ 测试与探针）。

### Task 11 完成 + 方向追加（2026-09-20）
- Task 11 实现完成：提交 `17ff8e5`（14 files, +173-18），**EXIT=0**；`[gm] 116→128`、`[llm] 97→106`、`[prompt] 35→38`、`[factions] 193→204`；探针 105/0；9 组破坏实验 E1–E9 各自精准变红
  - **实现者自曝流程事故（已记入待办）**：E1 的还原用了 `git checkout -- <file>`，它回到 HEAD 而不是实验前状态 → **冲掉自己未提交的改动**（被 `还原校验: MISMATCH` 抓到）→ 改为「cp 备份 + cp 还原」；**破坏实验的还原一律用副本备份，不要用 `git checkout` 对付未提交工作区**（Task 13 写进 HANDOFF §4）
- Task 11 审查：**Approved**，Critical 0 / **Important 0** / Minor 4（全 P2）→ **无修复轮**
  - 审查者确认：鸭子类型**真取代**（全仓代码再无 `is LlmGameMaster` 分支）；`§8#61` 语义自洽（`_resolve` 把 warnings 并进 `op_errors` → `main.gd` 逐条打印，两分支玩家都能看到原因）；`faction_standing_delta` 与 `join_faction` 同门同判且拒绝时不写 standing/stance；`_turn_state` 全仓零引用；`government_id()` 两处调用逐字等价
  - 控制器复核（`task-11-test-verify.log`）：`EXIT=0`、`[gm] 128`、`[llm] 106`、`[prompt] 38`、`[factions] 204`、`SCRIPT ERROR` 2 = 基线
- Task 11: minor 处置：M1/M3（plan-02 spec 里 `_post_submit` 残留与 `is LlmGameMaster` 注释）→ **控制器已改**（`84395e1`）；M2（报告里 E2/E4 的"红数"不可静态复现，判别力本身成立）→ 登记为报告精度问题；M4（无 fallback 分支原因**双显**：叙事含「（原因：X）」且 warnings 也打印）→ 登记，**并入 03a-P 的表现层 UX 批次**
- **CJK 字体实测（一次性探针，跑完即删）**：`ThemeDB.fallback_font.has_char()` 对 你/魔/法/あ/한 全 **false**、只有 `A` true ⇒ **Godot 内置字体不含 CJK 字形**；Godot 4 渲染期虽有系统字体回退但平台相关不可依赖 ⇒ 中文界面**必须自带 CJK 字体**，并加一条 `presentation_test` 断言把"能不能读"钉进 CI（已写入 03a-P spec）
- 状态：**Task 11 complete**（17ff8e5）；**流水暂停**（人类要求）——不派 Task 12 / Task 13
- **人类方向追加**：正在整理字体/美术/声音素材，要求代码能与素材串起来（"不能只顾着写代码"）→ 控制器产出草稿 spec
  `docs/superpowers/specs/2026-09-20-hp-magic-era-03a-P-presentation-design.md`（含现状审计、素材契约、5 个 seam、5 任务草案、7 个待人类回答的问题）
  - 硬前提：**Godot 4 默认字体不含 CJK** ⇒ 全中文界面必须有 CJK 字体资产（待 headless 探针复核 `ThemeDB.fallback_font.has_char`）
- 队列调整建议（待人类确认）：Task 12 → **03a-P（表现层素材接线，5 任务）** → Task 13 收尾合入 main；若素材先到，03a-P 可提前
