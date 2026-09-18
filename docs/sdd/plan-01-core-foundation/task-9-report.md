# Task 9 报告

## 结果
完成。`bash tools/test.sh` 全绿（`[panel] 失败=0`、`[selfcheck] 失败=0`、`[gm] 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、`全部通过。`），退出码 `0`。

## 提交
`d9135ab` feat(ui): 第六十二至六十五章面板与第七十二章强制自检

## 文件
- 新建：`src/ui/panel_formatter.gd`、`src/ui/panel_formatter.gd.uid`、`tests/panel_test.gd`、`tests/panel_test.gd.uid`、`tests/selfcheck_test.gd`、`tests/selfcheck_test.gd.uid`
- 修改：`src/rules/self_check.gd`（用完整实现替换 Task 8 最小桩；`.gd.uid` 内容未变，未出现在 diff 中）、`tests/run_tests.gd`（`SUITES` 在 `gm_test.gd` 之后追加两条套件路径）

## 计划修正
- `.uid` 补充：按简报强制裁定，提交时显式包含 `src/ui/panel_formatter.gd.uid`、`tests/panel_test.gd.uid`、`tests/selfcheck_test.gd.uid`（`src/rules/self_check.gd.uid` 已在库中且内容未变化，无需改动）。
- 逐字照抄之外的偏离（1 处，最小修正）：`src/ui/panel_formatter.gd` 的 `player_panel()` 在标题行后新增一行 `lines.append("【姓名】%s" % p.name_text)`。
  - 原因：计划 Step 4 的 `player_panel` 实现**从不输出玩家姓名**，但计划 Step 1 的 `tests/panel_test.gd` 断言 `panel.contains("张三")`（标签「姓名」）。逐字照抄后 `[panel] 姓名: 期望为真` 失败（见下方红色原始输出）。正典第六十二章面板格式（`哈利·波特·魔法纪元.md:635-646`）也不含姓名字段，属计划内部（测试 vs 实现）自相矛盾。
  - 修正方式：仅新增一行独立 `【姓名】` 字段，未改动任何既有输出行、未改动任何断言，其余代码逐字照抄。可观察输出新增 `【姓名】张三`。

## 测试原始输出

### 先红（Step 2，逐字照抄测试 + 追加套件后，退出码 1）

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
SCRIPT ERROR: Parse Error: Identifier "PanelFormatter" not declared in the current scope.
   at: GDScript::reload (res://tests/panel_test.gd:35)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Cannot infer the type of "panel" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/panel_test.gd:35)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Identifier "PanelFormatter" not declared in the current scope.
   at: GDScript::reload (res://tests/panel_test.gd:47)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Cannot infer the type of "magic_panel" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/panel_test.gd:47)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Identifier "PanelFormatter" not declared in the current scope.
   at: GDScript::reload (res://tests/panel_test.gd:62)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Cannot infer the type of "squib_magic" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/panel_test.gd:62)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Identifier "PanelFormatter" not declared in the current scope.
   at: GDScript::reload (res://tests/panel_test.gd:67)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Cannot infer the type of "rel" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/panel_test.gd:67)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Identifier "PanelFormatter" not declared in the current scope.
   at: GDScript::reload (res://tests/panel_test.gd:74)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Cannot infer the type of "power" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/panel_test.gd:74)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Identifier "PanelFormatter" not declared in the current scope.
   at: GDScript::reload (res://tests/panel_test.gd:82)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Identifier "PanelFormatter" not declared in the current scope.
   at: GDScript::reload (res://tests/panel_test.gd:84)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Cannot infer the type of "block" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/panel_test.gd:84)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
ERROR: Failed to load script "res://tests/panel_test.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
套件无法实例化（语法错误？）: res://tests/panel_test.gd
SCRIPT ERROR: Parse Error: Static function "snapshot()" not found in base "SelfCheck".
   at: GDScript::reload (res://tests/selfcheck_test.gd:30)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Cannot infer the type of "snap" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/selfcheck_test.gd:30)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Static function "ooc_report()" not found in base "SelfCheck".
   at: GDScript::reload (res://tests/selfcheck_test.gd:39)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Cannot infer the type of "ooc" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/selfcheck_test.gd:39)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Static function "ooc_report()" not found in base "SelfCheck".
   at: GDScript::reload (res://tests/selfcheck_test.gd:48)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Static function "ooc_report()" not found in base "SelfCheck".
   at: GDScript::reload (res://tests/selfcheck_test.gd:53)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Static function "ooc_report()" not found in base "SelfCheck".
   at: GDScript::reload (res://tests/selfcheck_test.gd:58)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
SCRIPT ERROR: Parse Error: Static function "ooc_report()" not found in base "SelfCheck".
   at: GDScript::reload (res://tests/selfcheck_test.gd:63)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
ERROR: Failed to load script "res://tests/selfcheck_test.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:47)
       [1] _initialize (res://tests/run_tests.gd:26)
套件无法实例化（语法错误？）: res://tests/selfcheck_test.gd
==== 总计失败=2，失败套件=2 ====
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
测试失败：单测=1 冒烟=0
EXIT=1
```

（注：测试追加套件后第一次实现前还出现一次中间态失败 `[panel] 姓名: 期望为真` + `[panel] 断言=65 失败=1`，即上文「计划修正」记录的姓名缺口；为此做了最小修正。）

### 后绿（Step 5，退出码 0）

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
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```

（`[probe]` 两行是断言库自检探针，故意失败，probe 套件不在 `SUITES` 中，不计入总计。）

## 遇到的问题 / 偏离
1. **姓名字段缺失（计划内部矛盾，已做最小修正）**：如「计划修正」节所述，计划 Step 1 的 `panel_test.gd` 断言 `panel.contains("张三")`，但计划 Step 4 的 `player_panel()` 不输出姓名；正典第六十二章面板格式同样不含姓名。逐字照抄必然失败。修正：新增一行 `【姓名】%s`，未改动其它输出与全部断言。
2. 其余代码（`tests/panel_test.gd`、`tests/selfcheck_test.gd`、`src/rules/self_check.gd`）逐字照抄计划，未出现 `String.join` / 类型推断等编译问题，无其它偏离。
3. 起点校验：`git status --short` 为空，`git log --oneline -1` = `463a73d`（与简报一致）。
4. `src/rules/self_check.gd.uid` 内容未因重写而变化（未出现在提交 diff 中）；三条新脚本 `.uid` 已随提交入库，工作区提交后干净。
