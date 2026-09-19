# Task 7 报告：`OpGuard`

## 结果
- 绿灯通过。`[llm] 断言=39 失败=0`；总计失败=0、失败套件=0；主场景 `main scene ready`；EXIT=0。
- 起点 `0a86471`（分支 `plan-02-llm-narrative`），交付提交 `38589b4`。
- 实现逐字取自计划 `docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md` `### Task 7` Step 3，测试逐字取自 Step 1，无偏离；`SUITES` 未改动。

## 改动（3 文件，+113）
- `src/gm/op_guard.gd`（新建，79 行）
  - 常量：`MAX_OPS=20`、`MAX_MONEY_GAIN=1000`、`MAX_RELATION_DELTA=20`、`TRAIN_BASE_GAIN=4`；内嵌 `Result`（`ops` / `warnings`）。
  - `sanitize` 返回 `.ops`，`sanitize_detailed` 返回完整 `Result`。
  - `gain_skill`→`train_skill`（丢弃 LLM 的 `amount`，固定 `base_gain=4`，未知技能丢弃）；`add_money` 按本回合累计收益钳到 1000；`set_magic_tier` 只允许相对当前 ±1 并再夹到合法档位；`relation_delta` 三项（trust/interest/hostility）各钳 ±20；`set_flag`/`set_player_flag` 拒绝空 key 与 `_` 前缀；`know_fact` 拒绝空 id/来源或 `source=="system"`；白名单 op（`cast_spell`/`learn_spell`/`set_location`/`set_job`）透传；未知 op 生成警告后透传给 `StateOps` 判定；超过 `MAX_OPS` 截断并告警。
- `src/gm/op_guard.gd.uid`（新建，Godot 生成的资源 UID，一并提交）。
- `tests/llm_test.gd`（`return a.report("llm")` 前，+33 行）：按计划 Step 1 追加 OpGuard 用例（11 条断言 + 循环检查）。

## TDD 记录
- Step 2（实现前，`bash tools/test.sh`）：`SCRIPT ERROR: Parse Error: Identifier "OpGuard" not declared`（`res://tests/llm_test.gd:104`），`套件无法实例化（语法错误？）`，`[prompt] 断言=13 失败=0`，`==== 总计失败=1，失败套件=1 ====`，EXIT=1 —— 与计划预期一致。
- Step 4（实现后）：全 17 套件失败=0、总计失败=0、EXIT=0（见下）。

## 提交
- `38589b4` — `feat(gm): OpGuard 净化与钳制`
- 仅 `src/gm/op_guard.gd`、`src/gm/op_guard.gd.uid`、`tests/llm_test.gd` 三个文件，未触碰其它 `src/`／`tests/*`。

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
[llm] 断言=39 失败=0
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
- `OpGuard` 是纯函数式守卫，不修改 `world`；`set_magic_tier` 的基准取 `world.player.magic_tier`，因此不同当前档位的 ±1 语义会随玩家状态变化。
- `add_money` 的上限是「本回合累计收益」1000（非单笔），多笔小额会逐笔占用额度；仅正向收益计数，负向（扣钱）不受该限额影响。
- `cast_spell` 等白名单 op 直接透传原始字典，`conditions` 等字段不做改写，交由 `StateOps`/`SpellResolver` 校验。
