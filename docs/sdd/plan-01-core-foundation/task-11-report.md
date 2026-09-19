# Task 11 报告

## 结果
完成。`bash tools/test.sh` 全绿：13 个单测套件全部 `失败=0`，主场景冒烟实际执行并打印 `main scene ready, godot=4.7.2-stable (official)`，最后打印 `全部通过。`，退出码 **0**。

## 提交
`70ad341` feat(ui): 主界面、创建流程与运行说明

## 文件
- 新建：
  - `src/ui/main.tscn`（最小 Control 场景，界面控件全部由 `main.gd` 代码构建）
  - `src/ui/main.gd`（创建流程 → 主循环；含存档/读档/自检接线）
  - `src/ui/main.gd.uid`（Godot 自动生成，按 HANDOFF §4 第 5 条入库）
- 修改：
  - `project.godot`（`[application]` 段新增 `run/main_scene="res://src/ui/main.tscn"`）
  - `tools/test.sh`（冒烟检查路径 `ui/main.tscn` → `src/ui/main.tscn`，跳过提示同步）
  - `README.md`（增量收尾）
  - `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`（同步强制裁定）

## 计划修正

### 路径统一（`ui/` → `src/ui/`）
统一为 `src/ui/main.tscn` / `src/ui/main.gd`。计划原文同步了以下位置：
1. Task 1 内嵌的 `tools/test.sh` 片段：`if [ -f "$ROOT/ui/main.tscn" ]` → `src/ui/main.tscn`，以及跳过提示。
2. Task 11 `Interfaces` 的 `Produces`：`run/main_scene = "res://ui/main.tscn"` → `res://src/ui/main.tscn`。
3. Task 11 Step 1 说明文字两处 `ui/main.tscn` → `src/ui/main.tscn`，以及 `ls ui/main.tscn` → `ls src/ui/main.tscn`。
4. Task 11 Step 4 的 ini 片段：`run/main_scene="res://ui/main.tscn"` → `run/main_scene="res://src/ui/main.tscn"`。
5. 「完成后验收」段无 `ui/main.tscn` 字样，无需改动。
6. 另：Task 11 Step 8 的 `git add` 补上 `src/ui/main.gd.uid`（强制裁定 3）。

### 共享 RNG（保 §8#34）
Task 11 Step 3 的两处均改为 GM 与引擎共享同一个 `rng` 实例：
1. `_on_start_pressed`：`TurnEngine.new(world, ScriptedGameMaster.new(RngService.new(world.game_seed + 1)), rng)` → `TurnEngine.new(world, ScriptedGameMaster.new(rng), rng)`；`rng = RngService.new(SEED_SALT + Time.get_ticks_msec() % 100000)` 保留在前。
2. `_on_load`：同型替换为 `TurnEngine.new(world, ScriptedGameMaster.new(rng), rng)`；`rng = RngService.new(world.game_seed)` 保留在前，`TurnEngine._init` 用 `world.rng_state` 覆盖其流状态。

### README 收尾方式
未整篇覆盖。在现有 README 上做增量修改：
- 「当前进度」措辞改为 **计划 01 · 核心模拟地基 已完成**，并补一句窗口程序可实际游玩。
- 进度表任务 11 状态：`下一步` → `✅ 完成`（现 11 个任务全部 ✅）。
- 「运行」节去掉「主场景在任务 11 建立后可用」「任务 1 建立后可用」两处占位说明，注明主场景为 `src/ui/main.tscn`。
- 「目录约定」的 `src/ui/` 条目改为「Godot 主场景与主界面（`main.tscn` / `main.gd`）＋面板格式化」。
- 「存档位置」「设计不变量」两节与最终代码一致，无需改动；HANDOFF/台账链接、进度表保留。

### 其它逐字照抄之外的偏离
无。`main.tscn` / `main.gd` 逐字按计划 Step 2/3 照抄，仅应用强制裁定 1/2。

## 测试原始输出
命令：`bash tools/test.sh`（先跑一次确认「修改前冒烟被跳过」对照：修改前 `tools/test.sh:24` 检查 `$ROOT/ui/main.tscn`，该文件不存在 → 会打印跳过提示且 `smoke=0`，属假绿；本任务修正后冒烟真正执行。）

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
SCRIPT ERROR: Invalid assignment of property or key 'personality' with value of type 'int' on a base object of type 'RefCounted (PlayerState)'.
   at: from_dict (res://src/model/player_state.gd:97)
   GDScript backtrace (most recent call first):
       [0] from_dict (res://src/model/player_state.gd:97)
       [1] from_dict (res://src/model/world_state.gd:177)
       [2] decode (res://src/persist/save_codec.gd:81)
       [3] run (res://tests/save_test.gd:79)
       [4] _run_suite (res://tests/run_tests.gd:58)
       [5] _initialize (res://tests/run_tests.gd:27)
SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor.
   at: from_dict (res://src/core/game_clock.gd:10)
   GDScript backtrace (most recent call first):
       [0] from_dict (res://src/core/game_clock.gd:10)
       [1] from_dict (res://src/model/world_state.gd:176)
       [2] decode (res://src/persist/save_codec.gd:81)
       [3] run (res://tests/save_test.gd:79)
       [4] _run_suite (res://tests/run_tests.gd:58)
       [5] _initialize (res://tests/run_tests.gd:27)
[save] 断言=81 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

main scene ready, godot=4.7.2-stable (official)
全部通过。
EXIT=0
```

说明：
- 上面两段 `SCRIPT ERROR` 来自 `save_test` 的**故意坏档负例**（计划既有，非本任务引入），该套件仍 `断言=81 失败=0`。
- 13 个套件：harness / registry / money / magic_level / model / clock / world_tick / creation / spell / gm / panel / selfcheck / save（probe 为断言库自检探针，不在 SUITES 内）。
- **Step 6 人工 GUI 验收的 8 项（窗口标题与 7 个下拉框、哑炮角色创建、练习收益递减、打工、面板、存档/读档回合数一致、重启读档、第 15 回合自检与「确认自检」）待人类执行**，本机 headless 无法自动化。

## 遇到的问题 / 偏离
无。逐字照抄的 `main.gd` 在 headless 下可正常加载执行：`Callable(self, ...)`、`SpinBox`、`RichTextLabel.scroll_following`、`result["op_errors"] as PackedStringArray` 等均无报错，未做任何最小修正。
