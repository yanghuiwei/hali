# Task 4 审查记录 · 5525525..dd81fa2

> 审查者：只读 `reviewer`（deepseek-flash，run 7e76fd11）｜审查包：`review-5525525..dd81fa2.diff`（2 commits：`ee335b1` 实现 + `dd81fa2` 测试补强 / 2 文件 / +287-10）
> 结论：**Spec ✅ 逐条符合；Task quality = Rejected**（1 Important 真缺陷 + 7 Minor）
> 控制器核对（`task-4-test-verify.log`）：`bash tools/test.sh` → **EXIT=0**、`[factions] 111 失败=0`、`总计失败=0，失败套件=0`、`全部通过。`；`SCRIPT ERROR` **2 条 = 基线**。

## Spec Compliance

| 核对项 | 结果 |
| --- | --- |
| 四个常量 `EVOLVE_REGRESSION/EVOLVE_NOISE/SUPPRESS_RATE/SUPPRESS_FLOOR` = 0.04/0.02/0.03/0.05 | ✅ `factions.gd:202-205` |
| `structure_pull` 逐 kind 与 brief 等价（含缺省键） | ✅ `:209-227` |
| `apply_rival_pressure` / `evolve` 与 brief 逐行等价（回归+噪音+`last_change_turn`+control 滞后 0.5+双下限+胜者获益+末尾写政体缓存+返回 `[]`） | ✅（去重缺陷见 I1） |
| 6 条 Minor 全部收口、断言非恒真 | ✅（逐条核对：规则 2 改 `float(control.get(inst, 0.0))` + 2 断言；null-clock 5 断言；三字段 `TYPE_ARRAY` 守卫 + 5 断言；era_overrides 时代红例；join 改换 5 断言；`delta=-5 → -2` 3 断言） |
| brief 原有两条压制断言**原样保留**（未为通过而删改） | ✅ `tests:298-301` |

**点名风险 4 项**：① RNG **不撞流**（`stream()` 以 `hash(seed|name)` 播种，且 `*31337`/`*7919`/`*104729`/`gm_rng` 盐各不相同）✅；② 去重逻辑 **❌ 见 I1**；③ **未提前写 `social_tension`** ✅（全仓仅常量声明，无写入点）；④ 报告 §6.2 的强声明**成立**、新增用例**确有判别力**（审查者用与 seed 无关的上下界推理独立复算）✅。

## Issues

### Critical
无。

### Important（1）

**I1 `plan-mandated`：`apply_rival_pressure()` 的 `if oid <= id: continue` 让「由字典序较大的一方单方声明」的敌对关系静默失效**
- 位置：`src/rules/factions.gd:237`（定义于 `:232-253`，由 `:274` 在 `evolve` 中调用）。
- 机制：对无向对 `{a,b}`（`a<b`），只放过 `(id=a, other=b)`；若**只有 `b` 声明 `a`**，该对永不被处理。
- 实测（控制器独立复现，`data/factions.json` 全表）：11 个已声明敌对对中**6 个生效、5 个被丢弃** —— `auror_office↔black_market`、`black_market↔diagon_merchants`、`common_folk↔sacred_twenty_eight`、`death_eaters↔mysteries`、`death_eaters↔wizengamot`。**黑市完全不受压制**，食死徒少两条应有的压制。
- 现有测试看不到：唯一隔离单对的用例用的是**对称**声明夹具。
- 处置：控制器已按「改计划、不顺着错的计划写实现」先改计划文本（`6c35c26`：去重改「无向对键」+ `rivals` 非数组跳过 + 新增「非对称敌对声明也必须被处理」回归用例 + 反证说明改正），随后进入修复轮 1（resume 原实现者）。

### Minor（7）

| # | 内容 | 处置 |
| --- | --- | --- |
| M1 | 报告 §④ 账目不平（Minor 写 26 条但分项和 21；演化段写 25 条但分项和 28；真实 **+51**：30+2+5+5+1+5+3） | 修复轮 1：按实测数字改正报告 |
| M2 | `compared_fields/expected_fields` 是同源算术互证（自指），真正判别力来自 `JSON.stringify` 双世界对比 | 修复轮 1：改真正逐字段断言或降格为注释 |
| M3 | `evolve()` 缺早退：`initialize` 已守 `registry/clock`，`evolve` 紧接着无保护读 `world.clock.turn` | 修复轮 1：加早退 + 断言 |
| M4 | `entry_of(...).get("rivals", []) as Array` 无运行时类型守卫 | 已含在 I1 的修复代码内 |
| M5 | `press2_before` 断言判别余量仅 0.0043（需 `noise > -0.0156`），换 seed/改 `EVOLVE_NOISE` 会退化为恒真 | 修复轮 1：改与 seed 无关的格局或删该条只留稳健全的一条 |
| M6 | `factions.gd` 现约 **305 行**，聚合六类职责，Task 5/6 后可能 400+ | **控制器裁定：本任务不拆分**，Task 5 后评估 |
| M7 | 除 Minor 3 要求的守卫外，另加「缺失 institutions/rivals/allies」报错（超出 Minor 3 措辞） | 保留（合理硬化，有断言覆盖） |

### ⚠️ 控制器已核对的项
1. 绿灯：`EXIT=0`、`[factions] 111 失败=0` ✅（见页首）
2. `SCRIPT ERROR` 2 条 = 基线 ✅
3. 报告 §6.1 破坏实验用 `--script run_tests.gd` 直跑（非完整 4 步）→ 完整证据以 `task-4-test-verify.log` 与修复轮的 `test.sh` 输出为准
4. 浮点逐位值未逐位复核，但审查者已用与 seed 无关的上下界推理确认结论成立
