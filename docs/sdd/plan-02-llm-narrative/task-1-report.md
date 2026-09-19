# Task 1 报告

## 结果
通过。协程探针套件 `[async_probe] 断言=2 失败=0`，原有 13 套件失败=0，`==== 总计失败=0，失败套件=0 ====`，`main scene ready`，`全部通过。`，EXIT=0。
`SceneTree._initialize` 直接 `await` 可行（未挂住、无解析错误），**未走备份方案**。

## 提交
- hash：`ccd08ef`
- 分支：`plan-02-llm-narrative`
- message：`test(async): 运行器支持协程套件 + 异步探针`
- 起点：`4459586`

## 文件
- 新建 `tests/async_probe_test.gd`（逐字用计划 Task 1 Step 1 代码）
- 新建 `tests/async_probe_test.gd.uid`（`uid://dhv413gv5p2dr`，已一起提交）
- 修改 `tests/run_tests.gd`：
  - `SUITES` 末尾追加 `"res://tests/async_probe_test.gd",`
  - `_initialize`：`var result: Variant = await _run_suite(path)`
  - `_run_suite`：`var result = await suite.run()`；其余（`report_calls` 哨兵、`quit()` 保证、目标形态）逐字保持
- 未改 `tests/assert.gd`（`report_calls` 已存在）、未改任何 `src/` 文件

## 是否走了备份方案（是/否 + 现象）
否。先按计划直接 `await`：
- Step 2 确认过失败（证明运行器原本非 async）：
  `SCRIPT ERROR: Trying to call an async function without "await". at: _run_suite (res://tests/run_tests.gd:60)`，`==== 总计失败=1，失败套件=1 ====`，EXIT=1。
- Step 4 async 化后即通过，引擎未空转、正常退出，无 `await` 相关解析错误。故无需 `call_deferred` + `process_frame` 轮询备份方案。

## 测试原始输出（完整，含 EXIT）
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
[spell] 断言=227 失败=0
[gm] 断言=59 失败=0
[panel] 断言=71 失败=0
[selfcheck] 断言=32 失败=0
SCRIPT ERROR: Invalid assignment of property or key 'personality' with value of type 'int' on a base object of type 'RefCounted (PlayerState)'.
   at: from_dict (res://src/model/player_state.gd:97)
   GDScript backtrace (most recent call first):
       [0] from_dict (res://src/model/player_state.gd:97)
       [1] from_dict (res://src/model/world_state.gd:177)
       [2] decode (res://src/persist/save_codec.gd:81)
       [3] run (res://tests/save_test.gd:79)
       [4] _run_suite (res://tests/run_tests.gd:60)
       [5] _initialize (res://tests/run_tests.gd:28)
SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor.
   at: from_dict (res://src/core/game_clock.gd:10)
   GDScript backtrace (most recent call first):
       [0] from_dict (res://src/core/game_clock.gd:10)
       [1] from_dict (res://src/model/world_state.gd:176)
       [2] decode (res://src/persist/save_codec.gd:81)
       [3] run (res://tests/save_test.gd:79)
       [4] _run_suite (res://tests/run_tests.gd:60)
       [5] _initialize (res://tests/run_tests.gd:28)
[save] 断言=96 失败=0
[async_probe] 断言=2 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

main scene ready, godot=4.7.2-stable (official)
全部通过。
EXIT=0
```

## 偏离
无。`save_test` 的两处 `SCRIPT ERROR` 为既有现象（该套件仍以 `report_calls` 哨兵判定通过，断言=96 失败=0），非本任务引入，未改动。
