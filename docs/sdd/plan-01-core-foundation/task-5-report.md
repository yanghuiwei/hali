# Task 5 报告

## 结果

完成。`bash tools/test.sh` 全绿：`[clock] 失败=0`、`[world_tick] 失败=0`、`总计失败=0，失败套件=0`、`ALL TESTS PASSED`、`全部通过。`，退出码 0。

## 提交

`23e67cd feat(world): 确定性随机与月度世界演化`

## 文件

- 新建：
  - `src/core/rng_service.gd`（`RngService`：命名流、可存档随机状态）+ `src/core/rng_service.gd.uid`
  - `data/locations.json`（21 项地点，含 `danger_label`）
  - `data/rumors.json`（16 条传闻模板，含 `label` 修正）
  - `tests/clock_test.gd` + `tests/clock_test.gd.uid`
  - `tests/world_tick_test.gd` + `tests/world_tick_test.gd.uid`
- 修改：
  - `src/core/registry.gd`（`TABLE_FILES` 追加 `"locations": "locations.json"`、`"rumors": "rumors.json"`）
  - `src/model/world_state.gd`（在 `add_fact()` 之后追加 `VARS_REGRESSION` / `MAJOR_EVENT_GAP` / `RECENT_LOG_LIMIT` 常量、`sim_style()`、`_era_baseline()`、`tick()`）
  - `tests/run_tests.gd`（`SUITES` 在 `"res://tests/model_test.gd",` 之后追加 `clock_test.gd`、`world_tick_test.gd`）
  - `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`（计划级修正：`data/rumors.json` 代码块 16 条补 `label`）

## 计划修正

**问题**：计划 Task 5 的 `data/rumors.json` 样例每条只有 `id/category/text/weight/major/min_year/zones/requires_flags`，缺 `label`（`id` 之后无显示名）。

**依据**：`Registry.validate()`（`src/core/registry.gd`）要求每张表每个条目都有非空 `label`，否则追加 `"<表>/<id>: 缺少 label"` 错误；`tests/registry_test.gd` 明确断言「缺 label 必须报错」。若按计划原样写，`tests/world_tick_test.gd` 的 `a.eq(reg.validate().size(), 0, ...)` 必红，且这是真实的数据完整性缺陷，不能靠改测试掩盖。

**修正**：给 `data/rumors.json` 全部 16 条在 `"id"` 之后逐字补上简报指定的短中文 `label`（作为传闻标题/显示名）；同时把计划原文 `data/rumors.json` 代码块里对应的 16 行也补上同样的 `label`（计划级修正，已随本次提交）。

## 测试原始输出

Step 2（预期红，退出码 1）关键片段：

```
== 2/3 单元测试 ==
[model] 断言=49 失败=0
SCRIPT ERROR: Parse Error: Identifier "RngService" not declared in the current scope.
   at: GDScript::reload (res://tests/clock_test.gd:8)
套件无法实例化（语法错误？）: res://tests/clock_test.gd
套件无法实例化（语法错误？）: res://tests/world_tick_test.gd
==== 总计失败=2，失败套件=2 ====
测试失败：单测=1 冒烟=0
EXIT=1
```

Step 7（绿灯，退出码 0）完整原始输出：

```
== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/3 单元测试 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

[probe] 故意失败: 期望 <2>，实际 <1>
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=15 失败=0
[magic_level] 断言=22 失败=0
[model] 断言=49 失败=0
[clock] 断言=28 失败=0
[world_tick] 断言=101 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```

## 遇到的问题 / 偏离

- 除简报要求的 `rumors.json` `label` 修正（含计划文档同步修正）外，代码与数据逐字照抄计划 Step 1–6；未加功能。
- 实现过程中 `tick()` 的 `rumor_count = 2` 一行在写入时出现过一次笔误（变量名首字母丢失），已在下一次编辑中修正为计划原文 `rumor_count = 2`，最终文件与计划逐字一致（测试全绿）。
- 计划 Step 2 的 `sed` 追加 `SUITES` 等价操作改用精确文本编辑完成，结果一致。
- 无其它偏离。

## 修复轮 1（scoped，controller 执行，提交 f9038ca）

第一轮审查（见 task-5-review.md）给出 Critical=0 / Important=4 / Minor=9。controller 处置 1 项 Important（#1 同月双 major）与 1 项 Important（#4 `load_state` 不恢复 `seed_value`），并消除部分空转测试（#5/#6/#7）：

- `src/model/world_state.gd`：`tick()` 中 `if is_major: add_fact(...)` 后加 `break`，同月至多一起重大事件。
- `src/core/rng_service.gd`：`state_dict()` 返回 `{"seed_value", "streams"}`；`load_state()` 恢复 `seed_value`。
- `tests/world_tick_test.gd`：删除死变量；w2 定位到 `ministry_of_magic`，新增「至少一次 major」与「相邻 major 间隔 ≥12」断言；信息保护测试加 `events_seen > 0`。
- `tests/clock_test.gd`：新增「恢复后新流沿用原 seed」断言。
- 计划 Step 1/3/6 同步。

反证：临时把 `state_dict/load_state` 改回旧 schema → `[clock] 恢复后新流沿用原 seed: 期望 <528154>，实际 <475519>`，失败=1；但临时删除 `break` 在当前种子 1234 下未触发失败（已在修复轮 1 复审中如实披露，并在修复轮 2 换种子解决）。

修复轮 1 复审：**通过**（#1、#4 ADDRESSED）；提出 N1（int64 经 JSON 丢精度）等。

## 修复轮 2（scoped，controller 执行，提交 24d5d43）

- `src/core/rng_service.gd`：`seed_value`/`seed`/`state` 一律十进制字符串入档，`load_state` 用 `int(str(...))` 解析，并 `_streams.clear()`（替换语义）。
- `tests/clock_test.gd`：存档恢复改为 20 次续抽 + 真 `JSON.stringify → parse_string` 逐一比对（替换空转的 `length()>0`）。
- `tests/world_tick_test.gd`：w2 种子 `1234 → 38`（可判别双 major）；`events is Array` 换成 `w.clock.turn == 13 + i`。
- 计划 Step 1/3 同步。

反证：
- 删除 `break`（种子 38）→ `[world_tick] 相邻 major 事件至少相隔 12 个月（实际最小间隔=0）: 期望为真`，失败=1；
- 把 `state_dict/load_state` 改回裸 int → `[clock] 经 JSON 往返后第 1..N 次抽取一致` 大量失败（`失败=19`）。

最终全绿：`[clock] 断言=47 失败=0`、`[world_tick] 断言=104 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、EXIT=0。

修复轮 2 复审：**通过**（N1、N2 ADDRESSED，R12 空转消除，无 Critical）。未处置项（R2 `weight`、R3 `rng_state`、N3/N4/N5、R8–R11/R13）已登记入 HANDOFF §8。
