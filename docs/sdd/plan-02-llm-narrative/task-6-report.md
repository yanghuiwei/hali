# Task 6 报告：`StateOps.train_skill` + §8#33 RNG 加盐

## 结果
- 绿灯通过。`[gm] 断言=63 失败=0`、`[spell] 断言=229 失败=0`；总计失败=0、失败套件=0；主场景 `main scene ready`；EXIT=0。
- 起点 `9920ba0`（分支 `plan-02-llm-narrative`），交付提交 `0a86471`。
- 实现逐字取自计划 `docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md` `### Task 6` Step 3，测试逐字取自 Step 1，无偏离。

## 改动（3 文件，+33/-2）
- `src/rules/state_ops.gd`
  - `match op:` 中 `"gain_skill"` 分支后新增 `"train_skill"`：校验 `registry.has("skills", skill_id)`，`Progression.gain(world, id, base_gain)` 记账后再 `world.player.add_skill(id, gain)`（收益只应用一次，反刷逻辑留在 Progression）。
  - `world_gm_rng` 改为按 `_gm_rng_counter` 加盐：`game_seed + turn*15485863 + counter*2654435761`；计数器写回 `world.flags["_gm_rng_counter"]`，保证同回合内多次 `cast_spell` 使用不同种子且可复现（§8#33）。
- `tests/gm_test.gd`（`return a.report("gm")` 前，+13 行）：`train_skill` 首次满额=4、同地点重复收益下降、`recent_training` 写入 `world.flags`、未知技能报 1 错。
- `tests/spell_test.gd`（`return a.report("spell")` 前，+8 行，复用既有 `make_world(reg, tier)`）：同回合 3 次 `world_gm_rng(...).stream_float("spell_roll")` 两两不同、`_gm_rng_counter == 3`。

## TDD 记录
- Step 2（实现前，`bash tools/test.sh`）：`[spell] 断言=227 失败=2`、`[gm] 断言=60 失败=3`，总计失败=5、失败套件=2，EXIT=1 —— 与计划预期一致（未知 op、`_gm_rng_counter` 缺失）。
- Step 4（实现后）：全 17 套件失败=0、总计失败=0、EXIT=0（见下）。

## 提交
- `0a86471` — `feat(rules): StateOps.train_skill + 施法 RNG 加盐（§8#33）`
- 仅 `src/rules/state_ops.gd`、`tests/gm_test.gd`、`tests/spell_test.gd` 三个文件，未触碰其它。

## 测试原始输出（完整，含 EXIT）
命令：`bash tools/test.sh` → EXIT=0
```
== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/3 单元测试 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

[probe] 故意失败: 期望 <2>，实际 <1>
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=18 失败=0
[magic_level] 断言=48 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=176 失败=0
[spell] 断言=229 失败=0
[gm] 断言=63 失败=0
[panel] 断言=71 失败=0
[selfcheck] 断言=32 失败=0
SCRIPT ERROR: Invalid assignment of property or key 'personality' with value of type 'int' on a base object of type 'RefCounted (PlayerState)'.
   at: from_dict (res://src/model/player_state.gd:97)
   GDScript backtrace (most recent call first):
       [0] from_dict (res://src/model/player_state.gd:97)
       [1] from_dict (res://src/model/world_state.gd:177)
       [2] decode (res://src/persist/save_codec.gd:81)
       [3] run (res://tests/save_test.gd:79)
       [4] _run_suite (res://tests/run_tests.gd:68)
       [5] _initialize (res://tests/run_tests.gd:36)
SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor.
   at: from_dict (res://src/core/game_clock.gd:10)
   GDScript backtrace (most recent call first):
       [0] from_dict (res://src/core/game_clock.gd:10)
       [1] from_dict (res://src/model/world_state.gd:176)
       [2] decode (res://src/persist/save_codec.gd:81)
       [3] run (res://tests/save_test.gd:79)
       [4] _run_suite (res://tests/run_tests.gd:68)
       [5] _initialize (res://tests/run_tests.gd:36)
[save] 断言=96 失败=0
[async_probe] 断言=2 失败=0
ERROR: Parse JSON failed. Error at line 0: Unexpected character
   at: parse_string (core/io/json.cpp:629)
   GDScript backtrace (most recent call first):
       [0] parse (res://src/gm/gm_response_parser.gd:20)
       [1] run (res://tests/llm_test.gd:60)
       [2] _run_suite (res://tests/run_tests.gd:68)
       [3] _initialize (res://tests/run_tests.gd:36)
       [4] _run_suite (res://tests/run_tests.gd:77)
       [5] run (res://tests/async_probe_test.gd:17)
       [6] async_double (res://tests/async_probe_test.gd:6)
[llm] 断言=28 失败=0
[prompt] 断言=13 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

main scene ready, godot=4.7.2-stable (official)
全部通过。
```
> 说明：`[probe] 断言=1 失败=1` 是运行器自带的「故意失败探针」（验证失败会被计数），不属于已登记的 17 个套件，因此总计失败仍为 0、失败套件为 0。`save`/`llm` 段的 `SCRIPT ERROR`/`ERROR` 是这两个套件刻意覆盖非法输入的负路径日志，其断言失败数均为 0。

## 备注
- `world.flags["_gm_rng_counter"]` 以下划线前缀标记为引擎内部 flag；Task 7 的 `OpGuard` 将拒绝 LLM 写该前缀（计划 Task 7 测试已覆盖）。
- `train_skill` 的收益计算与技能写回分离，避免与 `gain_skill` 重复叠加。
