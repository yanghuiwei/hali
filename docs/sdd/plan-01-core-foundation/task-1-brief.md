### Task 1: 仓库引导 + Godot 工程 + 无头测试骨架

**Files:**
- Create: `.gitignore`
- Create: `project.godot`
- Create: `tools/test.sh`
- Create: `tests/assert.gd`
- Create: `tests/harness_test.gd`
- Create: `tests/run_tests.gd`

**Interfaces:**
- Consumes: 无（第一个任务）
- Produces:
  - `TestAssert`（`class_name`，`extends RefCounted`）：`checks: int`、`failures: PackedStringArray`、`eq(actual, expected, msg := "") `、`ne(actual, unexpected, msg := "")`、`is_true(cond, msg := "")`、`is_false(cond, msg := "")`、`near(actual: float, expected: float, eps: float, msg := "")`、`between(actual: float, lo: float, hi: float, msg := "")`、`has_key(d: Dictionary, key, msg := "")`、`fail(msg: String)`、`report(suite: String) -> int`
  - 测试套件协议：任意 `tests/xxx_test.gd` 定义 `class_name XxxTest extends RefCounted`，提供 `func run() -> int`，内部用 `TestAssert`，结尾 `return a.report("套件名")`
  - 唯一测试入口：`bash tools/test.sh`（退出码 0 = 全绿，1 = 有失败）

- [ ] **Step 1: 确认仓库与忽略规则**

引导阶段已完成 `git init -b main`、`.gitignore`、`README.md`，并把 `origin` 指向 `https://github.com/yanghuiwei/hali.git`。执行本任务时先确认现状，不要重复添加远端：

```bash
cd /e/Hali
git remote -v          # 应显示 origin 指向 yanghuiwei/hali
git status --short     # 应干净
```

下面再次给出 `.gitignore` 的目标内容；若文件已一致，本步无需改动。

创建 `.gitignore`：

```gitignore
# 忽略本机 Godot 可执行文件（约 180MB，不入库）
*.exe

# subagent-driven-development 工作区（临时台账/简报/报告）
.superpowers/

# Godot 导入缓存（构建产物，不纳入版本控制）
.godot/
# 导出产物
export/
build/
# 临时文件
*.tmp
*.bak
.DS_Store
```

- [ ] **Step 2: 创建 Godot 工程定义**

创建 `project.godot`（**先不写 `run/main_scene`**，主场景在任务 11 才存在）：

```ini
config_version=5

[application]

config/name="哈利·波特·魔法纪元"
config/description="魔法世界沙盘·超高自由度人生模拟器"
config/features=PackedStringArray("4.7")

[display]

window/size/viewport_width=1280
window/size/viewport_height=800

[rendering]

renderer/rendering_method="gl_compatibility"
```

- [ ] **Step 3: 写断言库**

创建 `tests/assert.gd`：

```gdscript
class_name TestAssert
extends RefCounted

var checks: int = 0
var failures: PackedStringArray = PackedStringArray()

func eq(actual, expected, msg: String = "") -> void:
	checks += 1
	if actual != expected:
		failures.append("%s: 期望 <%s>，实际 <%s>" % [msg, str(expected), str(actual)])

func ne(actual, unexpected, msg: String = "") -> void:
	checks += 1
	if actual == unexpected:
		failures.append("%s: 不应等于 <%s>" % [msg, str(unexpected)])

func is_true(cond: bool, msg: String = "") -> void:
	checks += 1
	if not cond:
		failures.append("%s: 期望为真" % msg)

func is_false(cond: bool, msg: String = "") -> void:
	checks += 1
	if cond:
		failures.append("%s: 期望为假" % msg)

func near(actual: float, expected: float, eps: float, msg: String = "") -> void:
	checks += 1
	if absf(actual - expected) > eps:
		failures.append("%s: 期望 %f ± %f，实际 %f" % [msg, expected, eps, actual])

func between(actual: float, lo: float, hi: float, msg: String = "") -> void:
	checks += 1
	if actual < lo or actual > hi:
		failures.append("%s: 期望落在 [%f, %f]，实际 %f" % [msg, lo, hi, actual])

func has_key(d: Dictionary, key, msg: String = "") -> void:
	checks += 1
	if not d.has(key):
		failures.append("%s: 缺少键 <%s>" % [msg, str(key)])

func fail(msg: String) -> void:
	checks += 1
	failures.append(msg)

func report(suite: String) -> int:
	for f in failures:
		printerr("[%s] %s" % [suite, f])
	print("[%s] 断言=%d 失败=%d" % [suite, checks, failures.size()])
	return failures.size()
```

- [ ] **Step 4: 写第一个测试套件（此时必然失败：运行器还不存在）**

创建 `tests/harness_test.gd`：

```gdscript
class_name HarnessTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()
	a.eq(1 + 1, 2, "算术")
	a.near(1.0 / 3.0, 0.3333, 0.001, "浮点容差")
	a.between(0.5, 0.0, 1.0, "区间")
	a.is_true("张三".length() == 2, "UTF-8 中文长度")
	var parsed = JSON.parse_string('{"galleons": 17}')
	a.has_key(parsed, "galleons", "JSON 解析")
	a.eq("abc".sha256_text().length(), 64, "SHA-256 可用（存档校验和依赖它）")
	# 断言库自身必须能捕获失败，否则测试会假绿
	var probe := TestAssert.new()
	probe.eq(1, 2, "故意失败")
	a.eq(probe.failures.size(), 1, "断言库记录失败")
	a.eq(probe.report("probe"), 1, "report 返回失败数（int，不是字符串）")
	return a.report("harness")
```

- [ ] **Step 5: 运行测试，确认失败**

```bash
cd /e/Hali
./Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
./Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd
```

预期：`ERROR: Failed to load script "res://tests/run_tests.gd" ... No loader found` 或 `Can't open file`，退出码 1。这正是「运行器还没写」。

- [ ] **Step 6: 写测试运行器**

创建 `tests/run_tests.gd`：

```gdscript
extends SceneTree

# 每个任务把自己的套件追加到这里。路径必须真实存在，缺失即失败。
const SUITES: Array[String] = [
	"res://tests/harness_test.gd",
]

func _initialize() -> void:
	var total_failures := 0
	var failed_suites := 0
	for path in SUITES:
		if not FileAccess.file_exists(path):
			printerr("缺少测试套件: ", path)
			total_failures += 1
			failed_suites += 1
			continue
		var script: GDScript = load(path)
		if script == null:
			# 语法错误会让 load() 返回 null
			printerr("套件无法加载（语法错误？）: ", path)
			total_failures += 1
			failed_suites += 1
			continue
		var suite = script.new()
		var failures := int(suite.run())
		if failures > 0:
			failed_suites += 1
		total_failures += failures
	print("==== 总计失败=%d，失败套件=%d ====" % [total_failures, failed_suites])
	if total_failures > 0:
		quit(1)
	else:
		print("ALL TESTS PASSED")
		quit(0)
```

- [ ] **Step 7: 运行测试，确认通过**

```bash
cd /e/Hali
./Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
./Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd
echo "exit=$?"
```

预期输出：

```
[harness] 断言=8 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
exit=0
```

- [ ] **Step 8: 写测试入口脚本**

创建 `tools/test.sh`：

```bash
#!/usr/bin/env bash
# 唯一测试入口：先做导入（生成 .godot 缓存），再跑单测，最后跑主场景冒烟。
# 用法: bash tools/test.sh   （可用 GODOT=/path/to/godot 覆盖引擎路径）
set -uo pipefail

GODOT="${GODOT:-Godot_v4.7.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "找不到 Godot 可执行文件: $GODOT（用 GODOT=... 指定）" >&2
	exit 2
fi

echo "== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） =="
"$GODOT" --headless --path . --import >/dev/null 2>&1

echo "== 2/3 单元测试 =="
"$GODOT" --headless --path . --script res://tests/run_tests.gd
unit=$?

echo "== 3/3 主场景冒烟 =="
if [ -f "$ROOT/ui/main.tscn" ]; then
	"$GODOT" --headless --path . --quit-after 5
	smoke=$?
else
	echo "（跳过：ui/main.tscn 尚未创建，任务 11 将启用）"
	smoke=0
fi

if [ "$unit" -ne 0 ] || [ "$smoke" -ne 0 ]; then
	echo "测试失败：单测=$unit 冒烟=$smoke" >&2
	exit 1
fi
echo "全部通过。"
```

- [ ] **Step 9: 验证入口脚本与失败退出码**

```bash
cd /e/Hali
bash tools/test.sh; echo "预期 exit=0，实际=$?"
# 故意制造失败，确认退出码为 1
sed -i 's/a.eq(1 + 1, 2, "算术")/a.eq(1 + 1, 3, "算术")/' tests/harness_test.gd
bash tools/test.sh; echo "预期 exit=1，实际=$?"
git checkout -- tests/harness_test.gd   # 此时尚未提交，改用下面第二步恢复
```

若上面的 `git checkout` 报错（文件还没提交过），用反向 `sed` 还原：

```bash
sed -i 's/a.eq(1 + 1, 3, "算术")/a.eq(1 + 1, 2, "算术")/' tests/harness_test.gd
bash tools/test.sh; echo "恢复后 exit=0，实际=$?"
```

- [ ] **Step 10: 提交**

```bash
cd /e/Hali
git add .gitignore project.godot tools/test.sh tests/ "哈利·波特·魔法纪元.md"
git status --short   # 确认没有任何 .exe 被暂存
git commit -m "chore: 引导 Godot 4.7.2 工程与无头测试骨架"
```

---

