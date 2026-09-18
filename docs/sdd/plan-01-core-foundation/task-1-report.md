# Task 1 报告（补写）：测试运行器坏套件挂住进程的修复

状态：FIXED / VERIFIED
提交：`281fdd6 fix(test): 测试运行器在套件语法错误时必须自行退出而不是挂住`（分支 `plan-01-core-foundation`，单提交）
变更文件：`tests/run_tests.gd`（唯一文件，+23 / −11）

说明：本文件是补写的。Task 1 的原实现者在提交后即被 30 分钟挂钟超时杀掉，没来得及写报告；
该实现遗留的缺陷（见下）已经复现并在此修复，修复过程与三次验证均记录在此。

## 1. 缺陷

契约（计划 Task 1）：**缺失或无法加载的套件必须计为失败，且运行器在任何情况下都必须以 `quit(...)` 结束（不能挂住进程）。**

当 `SUITES` 里某条路径指向**存在但解析失败**的脚本（语法错误，或 TDD RED 阶段引用尚未写入的 `class_name`）时，旧实现会永久挂住进程：

1. `load(path)` 返回的是**非 null 的坏 `GDScript`**，因此 `if script == null` 守卫不生效（已用探针脚本实测：`script_is_null=false`）。
2. `script.new()` 抛运行期错误。
3. GDScript 运行期错误会**中止所在函数**，于是 `_initialize()` 在到达 `quit()` 之前就中断了。
4. `SceneTree` 于是永远跑下去，无头 Godot 永不退出（复现时被 45 秒 OS 超时杀掉，退出码 124，而不是干净的 1）。

**缺失文件**（路径不存在）的路径本身是正确的，旧实现会打印 `缺少测试套件` 并 `quit(1)`；坏脚本这一条才是漏网的。

## 2. 修复方式

保持 `extends SceneTree` 与 `const SUITES: Array[String]`（后续任务仍按原契约追加路径），把**所有有风险的调用**（`FileAccess.file_exists`、`load`、`new`、`run`）从 `_initialize()` 移入新函数：

```gdscript
func _run_suite(path: String) -> Variant
```

- 返回套件失败数（`int`）；套件**缺失 / 无法加载 / 无法实例化 / 运行中抛错**时返回 `null`。
- `_initialize()` 只做循环与控制流：拿到 `null` 就把 `total_failures` 与 `failed_suites` 各 +1 并打印命名该路径的诊断，然后照常走到结尾的 `==== 总计失败=%d，失败套件=%d ====`、`ALL TESTS PASSED`、`quit(1)` / `quit(0)`。
- 关键点：套件里的运行期错误只中止 `_run_suite` 这一帧，`_initialize()` 因此必然执行到 `quit(...)`，进程自行终止；没有加 `timeout` 包装，也没有全局兜错。

### 使用的实例化前有效性检查：`script.can_instantiate()`

先验证了该方法在 Godot 4.7.2 上存在且语义正确（探针脚本 `tests/tmp_probe.gd`，用完即删）：

```
PROBE script_is_null=false
PROBE can_instantiate=false
PROBE has_method=true
EXIT=0
```

即 `GDScript` 上存在 `can_instantiate()`、对坏脚本返回 `false`、对正常脚本返回 `true`（本次三个正常套件都走通了 `new()` 分支）。因此采用它：

```gdscript
if not script.can_instantiate():
	printerr("套件无法实例化（语法错误？）: ", path)
	return null
```

该守卫是**双保险**而非唯一防线：即便某个坏脚本仍能通过 `can_instantiate()`，`new()`/`run()` 的抛错也只会让 `_run_suite` 返回 `null`，`_initialize()` 依旧能收尾退出。

## 3. 验证（三次运行，均为实测原样输出）

### 3.1 坏套件路径（fault path）

命令：

```bash
cd /e/Hali
printf 'class_name TmpBrokenTest\nextends RefCounted\n\nfunc run() -> int\n\tthis is not valid gdscript !!!\n' > tests/tmp_broken_test.gd
sed -i 's|\t"res://tests/registry_test.gd",|\t"res://tests/registry_test.gd",\n\t"res://tests/tmp_broken_test.gd",|' tests/run_tests.gd
./Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd; echo "EXIT=$?"
```

（**没有**任何 OS 级 `timeout` 包装。）

输出：

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

[probe] 故意失败: 期望 <2>，实际 <1>
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
SCRIPT ERROR: Parse Error: Unexpected "Indent" in class body.
   at: GDScript::reload (res://tests/tmp_broken_test.gd:5)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:38)
       [1] _initialize (res://tests/run_tests.gd:17)
ERROR: Failed to load script "res://tests/tmp_broken_test.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
   GDScript backtrace (most recent call first):
       [0] _run_suite (res://tests/run_tests.gd:38)
       [1] _initialize (res://tests/run_tests.gd:17)
套件无法实例化（语法错误？）: res://tests/tmp_broken_test.gd
==== 总计失败=1，失败套件=1 ====
EXIT=1
```

结论：自行退出，退出码 1，诊断点名了路径（缺陷已修；修复前同一场景是 45 秒超时杀进程、退出码 124）。

回滚：

```bash
rm -f tests/tmp_broken_test.gd tests/tmp_broken_test.gd.uid
git checkout -- tests/run_tests.gd
git status --short   # → 空
```

### 3.2 缺失文件路径（missing-file path）

命令：

```bash
cd /e/Hali
sed -i 's|\t"res://tests/registry_test.gd",|\t"res://tests/registry_test.gd",\n\t"res://tests/nope_test.gd",|' tests/run_tests.gd
./Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd; echo "EXIT=$?"
```

输出：

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

[probe] 故意失败: 期望 <2>，实际 <1>
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
缺少测试套件: res://tests/nope_test.gd
==== 总计失败=1，失败套件=1 ====
EXIT=1
```

回滚：`git checkout -- tests/run_tests.gd` → `git status --short` 为空。

### 3.3 全绿路径（green path）

命令：`cd /e/Hali && bash tools/test.sh; echo "EXIT=$?"`

输出：

```
== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/3 单元测试 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

[probe] 故意失败: 期望 <2>，实际 <1>
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```

结论：`ALL TESTS PASSED` / `全部通过。`，`[harness] 断言=8 失败=0`、`[registry] 断言=26 失败=0`，退出码 0。

### 3.4 收尾状态

```
$ git status --short        # 空
$ git log --oneline -1
281fdd6 fix(test): 测试运行器在套件语法错误时必须自行退出而不是挂住
$ git show --stat --oneline HEAD
281fdd6 fix(test): ... 
 tests/run_tests.gd | 34 +++++++++++++++++++++++-----------
 1 file changed, 23 insertions(+), 11 deletions(-)
```

未改 `tools/test.sh`、`tests/assert.gd`、任何套件文件或其他任何文件。

## 4. 自审（self-review）

- **契约未变**：`extends SceneTree` 保持；`const SUITES: Array[String]` 仍是顶层常量、仍由 sed/手工追加路径（后续任务照旧）。输出格式逐字未改（每套件 `[name] 断言=N 失败=M`、`==== 总计失败=%d，失败套件=%d ====`、`ALL TESTS PASSED`、退出码 1/0）。
- **没有引入新决策**：`can_instantiate()` 的可用性已实测确认（4.7.2 上存在），不构成"改用别的方法"的架构岔路。
- **没有加超时或全局兜错**：进程自行终止靠的是"危险调用不与 `quit()` 同帧"，不是外部 `timeout`，也没有 `try/catch` 式全局吞错。
- **提交顺序说明**：为让回滚（恢复被临时追加的 `SUITES` 行）用 `git checkout -- tests/run_tests.gd` 一次到位、不留脏文件，先提交修复再做三次验证（回滚后 `git status --short` 均为空）。验证全部通过，故无 amend。
- **探针工件已清理**：`tests/tmp_probe.gd`、`tests/tmp_broken_test.gd` 及其 `.uid` 均已删除，最终工作树干净。

## 5. 遗留顾虑（concerns）

1. **不可达的假绿（既有，已记录在 progress.md，未在本任务修）**：若 `SUITES` 被清空为空数组，运行器会打印 `ALL TESTS PASSED` 并 `quit(0)`。当前不可达（固定三条），超出本任务范围。
2. **`load()` 返回非 `GDScript` 资源的情形**：若有人把 `SUITES` 指向 `.tscn` 等路径，`var script: GDScript = load(path)` 的类型赋值会抛错并中止 `_run_suite` → 计为失败 + 明确计数，但诊断信息只会是 Godot 自身的类型错误文本，不含指向该路径的自定义中文诊断。可接受（仍是失败且必然退出），未额外加防御以免扩大改动面。
3. **`tools/test.sh:17` 丢弃 `--import` 的退出码**（计划既定，既有遗留）：一处 `class_name` 导入失败可能造成假绿，与本缺陷无关。
4. 本文件为事后补写；Task 1 的原始 RED/GREEN 步骤输出只剩 controller 观测记录与 diff，不在本报告中重复。
