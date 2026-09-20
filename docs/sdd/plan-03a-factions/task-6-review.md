# Task 6 审查与修复轮记录 · 413cd3f..537bd68

## A. 首轮审查（审查包 `review-413cd3f..51a3455.diff`，审查者 run e2475682）

> 结论：**Spec ✅ / Task quality = Approved**；Critical 0 / **Important 1** / Minor 6
> 控制器核对（`task-6-test-verify.log`）：`EXIT=0`、`[factions] 184`、`[registry] 244`、`SCRIPT ERROR` 2 = 基线。

**Spec 核对 6/6 通过**（`reveal()` 四约束、`apply_rumor_reveals` 填实无 `pass`、只追加 4 条传闻、两处校验、`visible_faction_ids()` 未被重写），唯 I1 错字未落实。

**点名 5 风险结论**：① E2E 夹具前提**成立**（`Registry.TABLE_FILES.keys()` 全量复制 18 张表；链路走真实 `tick → events → apply_rumor_reveals → reveal`，未绕过）；② `last_change_turn` 双写**不会**被清掉/数值覆盖（同回合都取已 `advance_month()` 的 turn），但**语义双写**削弱 Task 5 不变量（Minor 1）；③ 声明性偏离**接受**（既有 16 条确实都带 `weight`/`requires_flags`；`requires_flags: []` 等价无前置；`weight` 零消费符合 Task 12 范围）；④ 引用检查**不误报**（坏类型 `123` 会「多报」而非漏报）；⑤ 唯一真实耦合是 `factions_test.gd:629-651` 的 `last_change_turn` 双向断言（今天绿依赖内容/随机而非设计）。

**Strengths（节选）**：实现与 brief 逐字对齐、diff 最小（+156/-7）；4 个 `reveals_faction` 目标均为**非 public**（`semi`×2/`secret`×2）⇒ 无「对已公开派系空转」的死条目；端到端证据被判定**不是假绿**（唯一候选 + 两道前提守卫 + 精确计数）。

### Issues
- **Important I1**：`factions.gd:383` 误写成「过**隘**」（应「过**阈**」）；**且提交信息/报告声称三处都改对了**（事实性错误陈述）。
- Minor 1：`last_change_turn` 语义双写（plan-mandated）→ 控制器裁定单一化。
- Minor 2：`history.size() >= 1` 判别力弱。
- Minor 3：`reveal()` 缺 null 守卫（对外 API）。
- Minor 4：跨存档未覆盖 `revealed` → 并入 Task 7。
- Minor 5：4 条传闻 `min_year: 0` → 控制器裁定改 2 条。
- Minor 6：报告漏登记新增 `label`（`validate()` 强制要求）。

## B. 修复轮 1（提交 `537bd68`，3 files / +35-6）

> 控制器：`EXIT=0`、`[factions] 184→191`、`SCRIPT ERROR` 2 = 基线（`task-6-fix1-verify.log`）。
> 控制器另提交 `28d3a4d`（裁定 M1 语义单一化）与 `0be229f`（计划补 `reveal()` 空守卫，修 Minor 3 的计划漂移）。
> 控制器核对 `git log -1 537bd68`：**提交正文已明确纠正失实陈述**（"首轮只改对 2/3，第三处误写成另一个错字；报告与提交信息据此更正"）→ 该 ⚠️ 项闭合。

| Finding | 处置 |
| --- | --- |
| I1 错字 + 失实陈述 | ✅ `过隘`→`过阈`、`死阀值`→`死阈值`，全仓 `grep 阀\|隘` 零命中；报告页首加 ⚠️ 更正块 |
| M1 `last_change_turn` | ✅ 删掉 `reveal()` 里的写入；哨兵断言（置 4242 → reveal → 仍 4242）；R1 加回该行 → 恰好 1 条红 |
| M2 弱断言 | ✅ 改为「恰好一条 `kind=faction_revealed` + `text` 非空」 |
| M3 null 守卫 | ✅ 补守卫 + 3 条断言；**但如实登记这 3 条断言在破坏下全绿**（见下） |
| M5 `min_year` | ✅ 食死徒/凤凰社 → **1970**，另两条保持 0；补「世界年份 ≥ min_year」前置断言（R3 改 3000 → 6 条红） |
| M6 `label` | ✅ 报告补登记 |

**附带发现**：`data/eras.json` 的 **`modern.start_year = 2010`**（非 1991），控制器已独立核实；E2E 夹具年份 2010 ≥ 1970 故无需调整。

## C. scoped 复审（修复包 `review-28d3a4d..537bd68.diff`，审查者 run 30f21d41）

> 结论：**Fix round 1 = Accepted**；6 条 findings 全部**已解决**；新引入 0 Critical / 0 Important / 2 Minor。

**范围核对**：diff 只含该动的三处，`reveal()` 其余行为逐字未变（`:428` 写 `revealed`、`:433` `add_fact` 含 label+source、`:434` `return true`、`:426` 幂等、`:421` 来源早退、`:423` 未知派系早退）。

**M1 判别力**：成立——`rw` 在本块前未 tick（`stale.tick()` 跑在另一世界），故 `rw.clock.turn == 0`，哨兵 4242 与 0 可区分；加回写入行 ⇒ 期望 4242 / 实际 0，必红。

**M3 护栏评估（复审者独立复核，诊断正确）**：
1. 删守卫后第一次解引用在 `factions.gd:423` `world.registry.has(...)`：`registry==null` → `Nonexistent function 'has' in base 'Nil'`；`world==null` → `Invalid access to property 'registry' on Nil`。两者都是**中止性**错误 ⇒ 函数按返回类型退化为默认 `false` ⇒ 三条 `is_false` 全绿。旁证三条（两条不同错误串与两条代码路径 1:1 对应；报告给的 `factions.gd:421` 恰为 `423−2`，自洽；"未中止套件"与运行器哨兵行为一致）。
2. **还有一条可观测差异，是真正可用的状态型护栏**：换 `registry` 合法、`clock == null` 的世界，删守卫后会**穿透**到 `ensure_state` 写入 `world.factions`、`revealed=true` 已持久化，直到 `add_fact` 读 `clock.turn` 才中止 ⇒ 断言 `state_of(half, "death_eaters").is_empty()` **有守卫绿、删守卫红**。
3. 三条断言**该留**（钉住「畸形输入不得返回 true、不得中止套件」的契约），但不应被当作"能失败的证据"；按 ② 补一条即可把护栏做**实**。

**新引入 Minor**：P2-1 三条 M3 断言非护栏（按 ② 补一条）；P2-2 计划文本（控制器已在 `0be229f` 补齐）。

**⚠️ 控制器核对结果**：① 绿步 `SCRIPT ERROR = 2` = 基线 ✅（`task-6-fix1-verify.log`）；② `537bd68` 提交正文已纠正失实陈述 ✅；③ 复审者自承对 `§8#56` 的引用略宽（"中止后退化"的先例其实在 §8#48 与 plan-01 `:4143`）→ 措辞问题，结论不受影响。
