# Task 2 审查记录 · dabefab..19654f0

> 审查者：只读 `reviewer`（deepseek-flash，run 9d58c8e6）｜审查包：`review-dabefab..19654f0.diff`（1 commit / 7 files / +405）
> 结论：**Spec ✅ 符合；Task quality = Approved**；Critical 0 / **Important 1（plan-mandated，待人类裁定）** / Minor 6
> 控制器核对（2026-09-20，`task-2-test-verify.log`）：`bash tools/test.sh` → **EXIT=0**、`[factions] 43 失败=0`、`[registry] 212 失败=0`、`总计失败=0，失败套件=0`、`全部通过。`；`SCRIPT ERROR` **2 条 = 基线 2 条**（逐字同位）；`git status` 干净、`*.uid` 未被二次改写。

## Spec Compliance（逐条）

1. 10 个函数签名逐字一致 ✅ —— `validate_content:36`、`initialize:85`、`ensure_state:106`、`state_of:130`、`base_power:96`、`power_of:136`、`power_share:141`、`institution_control:160`、`government_type:183`、内部 `entry_of:93`；Task 1 的 9 个常量零改动。
2. `validate_content` 覆盖 brief 三类 + 控制器并入四条 ✅（一处断言空白见 Minor 4）：institutions 枚举 `:41-43`、rivals/allies `:44-47`、era_overrides 引用 `:57-59`（**无失败断言**）；domains `:60-63`、aliases 非空 `:66-73`、base_power 类型 `:76-79`、era_overrides 必须存在且为 Dictionary `:51-56`，各有红例。
3. `factions_test.gd` 已登记 `SUITES`（`run_tests.gd:24`）+ 43 断言覆盖九类用例 ✅（确定性属 Task 4、揭示属 Task 6，与计划切分一致，非缺失）。审查者逐条数过 = 43，与报告一致。
4. 两条枚举护栏 ✅ —— `registry_test.gd:116-117`（`insts`/`kinds` vs `WorldFactions.*`），改任一侧任一元素即红。
5. 计划 Step 3 逐字/等价实现 ✅，仅两处偏差且均已授权/必要：① 阈值 0.28（人类裁定 A，计划已同步）；② null-clock 早退 + inline 兜底（噪音修复，属必要硬化）。

**点名风险复核**：① `main.gd` 的 `PackedStringArray.append_array(PackedStringArray)` 类型兼容、真实内容 0 错误 → 主场景新增 0 warning；② `from_dict → initialize` 未改变往返/负例语义（`_validate_payload` 已挡 `clock` 非字典，`decode` 以 `world.clock == null` 判失败）；③ null-clock 防护**未漏**合法路径（全仓只有 `create`/`from_dict` 两条构造路径，老存档缺 `clock` 键得默认非 null clock）；④ `government_type()` 短路顺序与正典 160-166 一致，但**语义与 spec §7.4 措辞不符**（见 Important 1）。

## Strengths

- 10 个函数签名与计划的耦合面被严格守住（含 `static`、具体类型），后续 Task 5/6/7 依赖面稳定。
- 断言钉住真实行为而非恒真：幂等先改 `ministry.power` 再断言；部分状态先 `clear()` 再补齐；老存档真走 `SaveCodec.encode/decode`；平局用例构造 0.70/0.70 且两侧 base_power 不同（0.58/0.55）使判据真实；空态把 17 条 `control` 全清后断言 8 键/全 0/全空 holder。
- null-clock 诊断可信：基线 2 条 SCRIPT ERROR 与两条畸形载荷一一对应，佐证「17 条 nil-access 噪音」确为新增接线引入，修法方向正确。
- 分层约束未破坏：`factions.gd` 无任何 `preload`（无 UI/GM 反向依赖）；阈值是规则不是内容；存档格式/`save_version` 未动。

## Issues

### Critical
无。

### Important（1，plan-mandated）

1. **`government_type()` 规则 1/3 与 spec §7.4 措辞不一致 —— 需人类二选一**
   - 位置：`src/rules/factions.gd:188-190`（规则 1 = `war_pressure >= 0.6` + `power_of(RESISTANCE) > power_of(MINISTRY)`）、`:206`（规则 3 用 `power_of(MINISTRY_ID) < 0.5`）。
   - spec 原文：§7.4 规则 1 要求「`war_pressure >= 0.6` **且 魔法部控制权 < 0.4 且凤凰社 power 最高**」；规则 3 要求「纯血 `power_share ≥ 0.28` **且 魔法部控制权 < 0.5**」；D5 亦写「由**谁控制魔法部** + 战争压力 + 凤凰社实力推导」。
   - 实现用的是魔法部 **power**（不是 `institution_control` 的 control），规则 1 少一个条件、未要求「凤凰社 power 最高」。
   - 性质：**不是实现者偏离** —— brief Step 3 与计划 `:617-618/634` 就是这段代码，且 brief 的构造用例只有在该语义下才能全绿（该用例里魔法部 `control.law_enforcement` 恒 0.75 ≥ 0.4，而 `power` 被压到 0.30/0.75）。
   - 余量提示：同一测试的抵抗格局里纯血占比 = **0.27994**（比 0.28 低 6e-5）；规则 1 先短路故当前无害，但阈值仍属「首版拍数」。
   - 建议处置：(a) 推荐——在 spec §7.4 加勘误（与 §13.2 同格式），把实现口径写成权威：规则 1 = 两条件（战时 + 抵抗组织强于魔法部），规则 3 的「魔法部弱」= `power_of(ministry) < 0.5`，测试不动；(b) 按 spec 字面补条件，但必须同步重订 brief 构造用例与阈值（需人类裁定）。

### Minor（6）

1. **规则 2 缺失键回退语义可疑且无测试** —— `factions.gd:200` `control.get(inst, law if inst == "law_enforcement" else wiz)`：某 dark 派系未声明该机构时，用**全局归并持有值**（可能来自非黑暗派系）代替。复现：`death_eaters.control = {}` + 魔法部持 0.75/0.58 → mean=0.665 ≥ 0.6 → 判独裁，尽管黑暗势力零控制；与 `institution_control` 的「未声明=不参与」语义（`:166-172`）自相矛盾。当前 17 条内容只有 1 个 dark 且恒带两键 → 死代码。建议改 `float(control.get(inst, 0.0))` 或注明设计意图 + 补用例。
2. **null-clock 修复无任何断言** —— `factions.gd:86`、`:120` 只有代码没有断言；报告给的是 stderr 计数对比。建议补可直接断言的负例（`WorldState.new()` + `initialize`）。
3. **`validate_content` 的 institutions/rivals/allies 缺类型守卫** —— `:41`、`:45` 对字符串/字典 `as Array` 得 `null` → `for ... in null` 抛错并**中止整个内容自检**；应照 `:51-56` 补 `TYPE_ARRAY` 分支。
4. **`era_overrides`「引用不存在的时代」分支无失败断言** —— `factions.gd:57-59` 无红例（现有只覆盖「缺失」「非字典」）。
5. **空值防护不对称**（report-only）—— `entry_of`/`base_power`/`ensure_state`/`power_share`/`government_type` 均无守卫地解引用 `world.registry`；当前生产调用点仅 `create`/`from_dict`，不可达。
6. **文件体量** —— `factions.gd` 本次 +181 后共 **209 行**，仍单一职责；提醒 Task 5/6 还要加 `evolve`/`visible_factions`/`reveal`（预计 ~450 行），届时宜评估拆分。

**报告本身的口径问题（不阻断）**：报告 §④ 表格「本任务后」列残留 TDD 红阶段的「失败 1」（终态 43/0，同报告其余章节自述一致）；§⑦「阈值余量足」略乐观（抵抗格局占比 0.27994 仅差 6e-5，但被规则 1 短路）。

**已核对但不计为 finding**：基线那 2 条 `SCRIPT ERROR` 是既有刻意负例噪音。
