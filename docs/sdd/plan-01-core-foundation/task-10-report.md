# Task 10 报告

## 结果
完成。`bash tools/test.sh` 全绿（`[save] 断言=47 失败=0`、`总计失败=0，失败套件=0`、`ALL TESTS PASSED`、`全部通过。`），退出码 `0`。

## 提交
`dbd93d2` feat(persist): 第七十一章存档编解码与存槽

## 文件
- 新建：`src/persist/save_codec.gd`、`src/persist/save_codec.gd.uid`、`src/persist/save_store.gd`、`src/persist/save_store.gd.uid`、`tests/save_test.gd`、`tests/save_test.gd.uid`
- 修改：`tests/run_tests.gd`（`SUITES` 在 `"res://tests/selfcheck_test.gd",` 之后追加 `"res://tests/save_test.gd",`）、`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`（同步 Step 1/Step 3 的实际代码，见「计划修正」）
- 未触碰 `src/model/`、`src/gm/`、`src/rules/`、`src/ui/`、`data/`。

## 计划修正
1. **`.uid` 补充**（强制裁定 1）：提交时显式包含三个新建脚本的 `.gd.uid`（跑过 `bash tools/test.sh` 后由 Godot 生成）。计划 Step 6 的 `git add` 未列出，按 HANDOFF §4 第 5 条硬性要求补齐。
2. **强制裁定 2 的端到端块**：已在 `tests/save_test.gd` 的 `return a.report("save")` 之前逐字插入 `submit → to_dict → JSON → from_dict → 重建引擎 → submit` 对比块，并同步进计划 Step 1 的代码块。
3. **逐字照抄之外的偏离（2 处最小修正，均已同步回计划原文）**：
   - **A. `src/persist/save_codec.gd` 第 14 行：`JSON.stringify(world.to_dict())` → `JSON.stringify(world.to_dict(), "", true, true)`（开启 `full_precision`）。**
     原因：Godot 4.7 的 `JSON.stringify` 默认把 float 截断到约 15 位有效数字，读档后 double 末位漂移。强制裁定 2 的断言 `a.eq(w3r.to_dict(), w3.to_dict(), "读档后重建引擎续跑：世界状态一致")` 逐字照抄后必然失败（证据见下方「中间红」的 `VAL world_vars.*`：如 `0.4221542611122131` 经 JSON 往返变成 `0.42215426111221299000`；7 项 `world_vars` 全部末位不一致）。这属 HANDOFF §8#19/#20 同族的「JSON 数值精度」问题，但落在**编码层**而非 `WorldState`/`RngService` 的序列化格式。修法只加参数、不改任何字段结构、不动 `WorldState`/`RngService`，且 `full_precision=true` 经实测可精确往返 double（`0.1`、`1.0/3.0`、`0.669387664616108` 往返后 `==`）。未改 `sort_keys`（仍为默认 `true`），载荷键序与校验和逻辑不变。
   - **B. `tests/save_test.gd` 随机流对比块：把「先无记录地抽 20 次 `rng_a`，再在循环里用 `rng_a` 的第 20+i 次对 `rng_b` 的第 i 次」改为「先抽 20 次存入 `expected_draws`，循环内 `rng_b` 的第 i 次对 `expected_draws[i]`」。**
     原因：计划 Step 1 的写法存在 off-by-20，两个 RNG 从同一 `rng_state` 出发，却在比较不同下标，20 条断言全部失败（证据见「中间红」的 `读档后第 0..19 次随机数一致`）。修正后语义严格回归断言文字「读档后第 i 次随机数一致」：仍抽 20 次、仍用 `a.near(..., 0.0000001)`、断言条数与含义不变，与 `tests/clock_test.gd:37-54` 的既有模式一致。
   - 两处偏离均在提交前同步进了计划原文（计划 Step 1 / Step 3 的代码块现与 `tests/save_test.gd`、`src/persist/save_codec.gd` 逐字节一致），符合 HANDOFF §4 第 9 条「改计划、不要顺着错的计划写实现」。除此之外的 `SaveCodec`/`SaveStore`/`save_test.gd` 全部逐字照抄计划 Step 1/3/4。

## 测试原始输出

### 先红（Step 1 后、Step 3 前，`SaveCodec` 未定义，退出码 1）

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
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=176 失败=0
[spell] 断言=227 失败=0
[gm] 断言=38 失败=0
[panel] 断言=65 失败=0
[selfcheck] 断言=26 失败=0
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:31)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Cannot infer the type of "text" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/save_test.gd:31)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:32)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:34)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Cannot infer the type of "decoded" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/save_test.gd:34)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Cannot infer the type of "tampered" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/save_test.gd:45)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:46)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Cannot infer the type of "tampered_result" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/save_test.gd:46)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:51)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Cannot infer the type of "no_header" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/save_test.gd:51)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Cannot infer the type of "wrong_version" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/save_test.gd:54)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:55)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:58)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:59)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:59)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:60)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:60)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveStore" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:64)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveStore" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:65)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveStore" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:66)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Cannot infer the type of "saved" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/save_test.gd:66)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveStore" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:69)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveStore" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:70)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Cannot infer the type of "loaded" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/save_test.gd:70)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveStore" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:73)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveStore" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:74)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveStore" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:75)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:83)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Cannot infer the type of "snapshot_text" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/save_test.gd:83)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:84)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:101)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Cannot infer the type of "checkpoint" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/save_test.gd:101)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Parse Error: Identifier "SaveCodec" not declared in the current scope.
   at: GDScript::reload (res://tests/save_test.gd:102)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
ERROR: Failed to load script "res://tests/save_test.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:48)
       [1] _initialize (res://tests/run_tests.gd:27)
套件无法实例化（语法错误？）: res://tests/save_test.gd
==== 总计失败=1，失败套件=1 ====
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
测试失败：单测=1 冒烟=0
EXIT=1
```

### 中间红（Step 3/4 逐字照抄后，暴露两处计划缺陷；节选失败行）

```
[save] 读档后第 0 次随机数一致: 期望 0.438234 ± 0.000000，实际 0.331689
[save] 读档后第 1 次随机数一致: 期望 0.432055 ± 0.000000，实际 0.755952
...（第 0..19 次全部不一致，共 20 条）
[save] 读档后重建引擎续跑：世界状态一致: 期望 <{ ... "world_vars": { "war_pressure": 0.42157235162258, ... } ...}>，实际 <{ ... "world_vars": { "war_pressure": 0.42157235162258, ... } ...}>
[save] 断言=47 失败=21
==== 总计失败=21，失败套件=1 ====
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
测试失败：单测=1 冒烟=0
EXIT=1
```

诊断（临时脚本，已删除）：`VAL .world_vars.war_pressure: 0.42157235162258 vs 0.42157235162258` 打印相同但 `==` 不等；`%.20f` 显示 `0.42215426111221310000` vs `0.42215426111221299000`，确认是 `JSON.stringify` 默认 15 位截断。

### 最终绿（提交前，退出码 0）

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
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=176 失败=0
[spell] 断言=227 失败=0
[gm] 断言=38 失败=0
[panel] 断言=65 失败=0
[selfcheck] 断言=26 失败=0
[save] 断言=47 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```

## 遇到的问题 / 偏离
1. **计划 Step 1 随机流对比块 off-by-20**：`rng_a` 先无记录抽 20 次，随后循环又把 `rng_a` 与 `rng_b` 各自推进，导致比较的是 `rng_b[i]` vs `rng_a[20+i]`，20 条断言恒失败。最小修正为「先抽 20 次存入 `expected_draws`，循环内对 `expected_draws[i]`」，断言文字/条数/容差均不变（见「计划修正 3.B」）。
2. **`JSON.stringify` 默认精度截断**：使强制裁定 2 的 `w3r.to_dict() == w3.to_dict()` 无法成立。按简报第 1 条未改 `WorldState`/`RngService` 序列化格式，改为在 `SaveCodec.encode` 开启 `full_precision`（加参数、不改结构），断言与可观察语义不变（见「计划修正 3.A」）。这同时消除了第 71 章存读档对 `world_vars` 等任意 double 的隐性丢失，属 HANDOFF §8#19/#20 同族债务在编码层的收口；`game_seed` 的 int64 字符串化（§8#19）本轮仍未做，未越界。
3. 逐字照抄的 `SaveCodec.decode` 的 lambda `fail.call(...)`、`DirAccess.make_dir_recursive_absolute`、`String.split` 在本机 Godot 4.7.2 下均按预期工作，无需修正。
4. 临时诊断脚本 `tools/_dbg_save.gd`、`tools/_dbg_float.gd`（及其 `.uid`）已删除，未进入提交。
5. 无 CRLF/并发 Godot 实例问题；测试只写 `user://test_saves` 并在开始前自清理，未触碰 `user://saves`。
