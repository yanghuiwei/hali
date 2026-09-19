# 哈利·波特·魔法纪元 · 计划 01：核心模拟地基 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Godot 4.7.2 中交付一个可运行、可自动化测试的文本人生模拟核心：读正典内容表 → 创建角色 → 按月推进世界 → 提交行动得到结果 → 渲染状态面板 → 存档/读档，全部核心逻辑在无头模式下测试。

**Architecture:** 纯 GDScript，零第三方插件。逻辑与表现分离：`src/model`（数据模型）/ `src/rules`（规则）/ `src/core`（注册表·时钟·RNG·回合引擎）/ `src/gm`(叙事接口) / `src/persist`（存档）/ `src/ui`（Godot 场景，代码构建控件）。所有内容（时代、血统、身份、技能、魔杖、地点、传闻、魔咒、失败率区间）来自 `data/*.json`，代码不硬编码内容。`GameMaster` 是接口：本计划只实现确定性的 `ScriptedGameMaster`（离线叙事替身，测试依赖它），LLM 叙事在计划 02 以 `LlmGameMaster` 接入同一接口。测试用 `SceneTree` 脚本运行，退出码 0/1，完全离线。

**Tech Stack:** Godot 4.7.2 stable（GDScript，非 .NET 构建，仓库内为 `Godot_v4.7.2-stable_win64_console.exe`）、JSON 内容表、git、bash（Git Bash）。

## Global Constraints

以下为项目级不变量，逐字取自 `哈利·波特·魔法纪元.md`（正典规格）。每个任务的实现与测试都隐含遵守，不再重复。

- 正典优先：原著明确设定 ＞ 模拟器扩展推演；原著未明确处可自由生成，但不得与原著明确事实冲突（第零章）。
- 世界不围绕玩家存在；玩家没有默认传奇血统、死亡圣器、预言、强大魔杖或校长宠爱（第二章、第六十九章）。
- 货币：**1加隆 = 17西可 = 493纳特**（第十八章）。普通魔杖 7–10 加隆；一瓶优质疗伤药剂 5–20 加隆。
- 施法失败概率（第二十二章）：新手/未入学 60–80%；霍格沃茨低年级 30–50%；O.W.L 15–30%；N.E.W.T 5–15%；熟练成年巫师 2–5%；大师级 低于2%。
- 魔法等级序列（第二十三章）：哑炮 → 麻瓜出身未入学 → 霍格沃茨新生 → O.W.L水平 → N.E.W.T水平 → 熟练成年巫师 → 专家级 → 大师级 → 传奇级 → 神话级。
- 环境因素（战斗压力、受伤、情绪剧烈波动、魔杖不合、咒语不熟、黑魔法干扰）必须改变失败概率（第二十二章）。
- 每回合 = 一个月；每月结算本月世界动态；世界不会停下来等玩家（第四十七章、第七十四章第10条）。
- 每 15 回合强制自检，**禁止续写剧情**，输出【剧情快照】+【人设OOC自检报告】，等待玩家指令（第七十二章）。
- 防过度热闹：禁止每月都有黑魔头/魂器/死亡圣器/魔法战争；日常上课、魔药、魁地奇必须大量存在（第六十八章）。
- 防数值刷怪：重复低难度动作成长收益迅速下降；成长来自新环境、新问题、新理解（第七十章）。
- 防无限生产：禁止复制咒无限复制稀有资源、治疗咒无限复活、时间转换器无限回溯、低阶咒语无限叠加（第五十五章、第五十四条）。
- 死亡默认真实且不可逆；NPC 不会因玩家喜欢而复活（第四十二章、第五十三章）。
- 世界信息保护：玩家不得自动知晓隐藏真相；信息需凭身份、地点、人脉、调查获得（第四十三章、第五十七章）。
- 引擎固定为 Godot 4.7.2 stable；仅 GDScript；禁止引入第三方插件、外部素材、任何网络依赖。
- 源码与数据文件一律 UTF-8；玩家可见文本用中文，代码标识符用英文。
- **持久化字段只用 JSON 原生类型**（Dictionary / Array / String / int / float / bool / null）。不要往 `to_dict()` 里放 `Vector2`、`PackedStringArray`、自定义对象——它们会在存读档往返中变形。
- **JSON 没有 int/float 之分**：`JSON.parse_string` 把所有数字读成 float，而 Godot 的 Dictionary 深比较是**类型严格**的（实测 `{"n":493} != {"n":493.0}`）。因此 `to_dict()` 必须输出经 `JsonUtil.normalize()` 规范化的形式（整数值的 float 归一为 int），`from_dict()` 也必须对动态子字典做同样处理。否则「存读档往返后状态完全一致」的断言必然失败。
- GDScript 字符串字面量里不要写 `\u`、`\x` 这类转义（`"\u"` 是解析错误）。需要反斜杠时用 `String.chr(92)`。
- 单元测试必须离线、无网络、无 LLM 调用；固定入口 `bash tools/test.sh`。

---

## 文件结构

先锁定分解，再写任务。每个文件一个职责。

```
E:/Hali/
├─ 哈利·波特·魔法纪元.md          # 正典规格（唯一事实来源，保持原位）
├─ README.md                         # 项目说明与运行方式（引导时建立，任务 11 定稿）
├─ project.godot                     # Godot 工程定义
├─ .gitignore
├─ README.md                         # 运行与测试说明（任务 11）
├─ tools/
│  └─ test.sh                        # 唯一测试入口：import → 单测 → 场景冒烟
├─ data/                             # 内容 = 数据，改内容不改代码
│  ├─ eras.json                      # 8 时代 + 世界变量基线（任务 2）
│  ├─ bloodlines.json                # 12 血统（任务 2）
│  ├─ birth_identities.json          # 11 出生身份（任务 2）
│  ├─ aptitudes.json                 # 6 魔法资质（任务 2）
│  ├─ houses.json                    # 6 学院倾向（任务 2）
│  ├─ sim_styles.json                # 6 模拟风格（任务 2）
│  ├─ political_leanings.json        # 6 政治倾向（任务 2）
│  ├─ locations.json                 # 18 地点 + 危险度（任务 5）
│  ├─ rumors.json                    # 月度传闻模板池（任务 5）
│  ├─ skills.json                    # 19 技能（任务 6）
│  ├─ wand_woods.json                # 魔杖木材（任务 6）
│  ├─ wand_cores.json                # 魔杖杖芯（任务 6）
│  ├─ wand_flexibilities.json        # 魔杖弹性（任务 6）
│  ├─ wand_lengths.json              # 魔杖长度档位（任务 6）
│  └─ spells.json                    # 28 条魔咒 + 反漏洞守卫（任务 7）
├─ src/
│  ├─ core/
│  │  ├─ registry.gd                 # 内容表加载 + 完整性校验
│  │  ├─ game_clock.gd               # 年/月/回合
│  │  ├─ rng_service.gd              # 命名流确定性随机（可存档恢复）
│  │  ├─ json_util.gd                # JSON 数值规范化（int/float 陷阱的唯一出口）
│  │  └─ turn_engine.gd              # 行动→裁决→结算→自检闸门
│  ├─ model/
│  │  ├─ money.gd                    # 加隆/西可/纳特
│  │  ├─ player_state.gd             # 玩家档案（对应第六十二章/六十三章面板）
│  │  └─ world_state.gd              # 世界状态 + 月度演化 tick()
│  ├─ rules/
│  │  ├─ magic_level.gd              # 等级序列 + 失败率区间 + 环境修正
│  │  ├─ character_creation.gd       # 第七十五章启动界面 → PlayerState
│  │  ├─ spell_resolver.gd           # 第二十一/二十二章 + 第五十五条守卫
│  │  ├─ progression.gd              # 第七十章反刷成长
│  │  ├─ state_ops.gd                # 状态变更操作解释器
│  │  └─ self_check.gd               # 第七十二章强制自检
│  ├─ gm/
│  │  ├─ game_master.gd              # 叙事接口（计划 02 接 LLM）
│  │  └─ scripted_game_master.gd     # 确定性离线叙事替身
│  ├─ persist/
│  │  ├─ save_codec.gd               # 第七十一章存档编解码 + 校验和
│  │  └─ save_store.gd               # user:// 存槽读写
│  └─ ui/
│     ├─ panel_formatter.gd          # 第六十二–六十五章面板纯函数
│     ├─ main.tscn                   # 最小场景（一个 Control）
│     └─ main.gd                     # 代码构建界面 + 主循环
└─ tests/
   ├─ run_tests.gd                   # SceneTree 测试运行器
   ├─ assert.gd                      # 零依赖断言库
   └─ *_test.gd                      # 每任务一个套件
```

**为什么这样分：** `data/` 是内容，`src/rules/` 是规则，`src/ui/` 是表现——正典规格未来会持续扩写（更多魔咒、更多地点、更多传闻），扩内容不应触碰代码；`GameMaster` 接口把「谁说故事」与「世界怎么算」隔开，因此计划 01 可以完全离线测试，计划 02 只替换一个类。

**后续计划（不在本次范围，避免误以为缺失）：** 02 LLM 叙事引擎（`LlmGameMaster`、提示词组装、结构化世界增量、正典优先校验）；03 派系与政治经济（九大支柱中的魔法部/纯血家族/古灵阁/商业）；04 神奇生物生态与区域危险度；05 NPC 自主系统与信息/谣言可信度；06 多世代传承与世界记忆。

---

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
if [ -f "$ROOT/src/ui/main.tscn" ]; then
	"$GODOT" --headless --path . --quit-after 5
	smoke=$?
else
	echo "（跳过：src/ui/main.tscn 尚未创建，任务 11 将启用）"
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

### Task 2: 内容注册表 + 正典内容表

**Files:**
- Create: `src/core/registry.gd`
- Create: `data/eras.json`
- Create: `data/bloodlines.json`
- Create: `data/birth_identities.json`
- Create: `data/aptitudes.json`
- Create: `data/houses.json`
- Create: `data/sim_styles.json`
- Create: `data/political_leanings.json`
- Create: `tests/registry_test.gd`
- Modify: `tests/run_tests.gd`（`SUITES` 追加一行）

**Interfaces:**
- Consumes: `TestAssert`（任务 1）
- Produces:
  - `Registry`（`class_name`，`extends RefCounted`）
    - `TABLE_FILES: Dictionary`（表名 → 文件名）
    - `duplicate_ids: PackedStringArray`
    - `static from_tables(tables: Dictionary) -> Registry`（`tables` 为 表名 → 条目数组；每个条目是含 `id`/`label` 的 Dictionary）
    - `static load_default() -> Registry`（读 `res://data/*.json`）
    - `entry(table: String, id: String) -> Dictionary`（缺失返回空字典 `{}`）
    - `has(table: String, id: String) -> bool`
    - `ids(table: String) -> PackedStringArray`（已排序）
    - `table_dict(table: String) -> Dictionary`（id → 条目）
    - `validate() -> PackedStringArray`（空 = 通过）
  - 内容表字段约定（后续任务全部按此读取）：
    - `eras`: `id,label,start_year,canon_note,secrecy_law,ministry_exists,world_vars{galleons 无关的 7 项世界变量}`
    - `bloodlines`: `id,label,magic_aptitude(bool),prejudice(float 0..1),wealth_tier(int),skill_bias{skill_id:int},default_flags[],risk,note`
    - `birth_identities`: `id,label,start_knuts(int),skill_bias{},contacts(int),note`
    - `aptitudes`: `id,label,failure_delta(float),grants[],special_options[],note`
    - `houses`: `id,label,traits[],note`
    - `sim_styles`: `id,label,event_intensity(float),mundane_ratio(float),note`
    - `political_leanings`: `id,label,pureblood_opinion(float -1..1),ministry_opinion(float -1..1),risk,note`

- [ ] **Step 1: 写失败测试**

创建 `tests/registry_test.gd`：

```gdscript
class_name RegistryTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	# 正典内容表完整性
	var errors := reg.validate()
	for e in errors:
		a.fail("内容表校验失败: " + e)
	a.eq(errors.size(), 0, "默认内容表应无错误")

	# 第七十五章启动界面的选项数量必须与规格一致
	a.eq(reg.ids("eras").size(), 8, "时代 8 项")
	a.eq(reg.ids("bloodlines").size(), 12, "血统 12 项")
	a.eq(reg.ids("birth_identities").size(), 11, "出生身份 11 项")
	a.eq(reg.ids("aptitudes").size(), 6, "魔法资质 6 项")
	a.eq(reg.ids("houses").size(), 6, "学院倾向 6 项")
	a.eq(reg.ids("sim_styles").size(), 6, "模拟风格 6 项")
	a.eq(reg.ids("political_leanings").size(), 6, "政治倾向 6 项")

	# 标签必须与规格逐字一致
	a.eq(reg.entry("eras", "hogwarts_founding")["label"], "霍格沃茨建校早期", "第一时代标签")
	a.eq(reg.entry("eras", "custom")["label"], "自定义时代", "第八时代标签")
	a.eq(reg.entry("bloodlines", "squib")["label"], "哑炮", "哑炮标签")
	a.eq(reg.entry("bloodlines", "obscurial")["label"], "默然者", "默然者标签")
	a.eq(reg.entry("aptitudes", "squib")["label"], "哑炮无魔法天赋", "资质标签")

	# 关键字查询
	a.is_true(reg.has("bloodlines", "werewolf"), "狼人存在")
	a.is_false(reg.has("bloodlines", "dragon"), "不存在的血统")
	a.eq(reg.entry("eras", "没有这个时代"), {}, "缺失条目返回空字典")
	a.eq(reg.entry("bloodlines", "hogwarts_founding"), {}, "跨表查询不得命中")

	# 关键语义字段
	a.is_false(reg.entry("bloodlines", "squib")["magic_aptitude"], "哑炮无魔法天赋")
	a.is_true(reg.entry("bloodlines", "muggle_born")["magic_aptitude"], "麻瓜出身有魔法天赋")
	a.eq(reg.entry("eras", "witch_hunts")["start_year"], 1692, "保密法年份 1692")
	a.eq(reg.entry("eras", "custom")["start_year"], null, "自定义时代年份为空")
	a.eq(reg.entry("aptitudes", "squib")["grants"].size(), 0, "哑炮不授予特殊天赋")

	# 校验器必须能抓到坏数据
	var dup := Registry.from_tables({
		"eras": [
			{"id": "a", "label": "甲"},
			{"id": "a", "label": "乙"},
		],
	})
	var dup_errors := dup.validate()
	var joined := " | ".join(dup_errors)
	a.is_true(joined.contains("重复 id"), "重复 id 必须报错")
	a.is_true(joined.contains("缺少数据表"), "缺失数据表必须报错")

	var no_label := Registry.from_tables({"eras": [{"id": "a"}]})
	a.is_true(" | ".join(no_label.validate()).contains("缺少 label"), "缺 label 必须报错")

	# ids() 必须稳定排序，保证 UI 下拉顺序可复现
	var ids := reg.ids("houses")
	var sorted_copy := ids.duplicate()
	sorted_copy.sort()
	a.eq(ids, sorted_copy, "ids 已排序")

	return a.report("registry")
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /e/Hali
sed -i 's|"res://tests/harness_test.gd",|"res://tests/harness_test.gd",\n\t"res://tests/registry_test.gd",|' tests/run_tests.gd
bash tools/test.sh
```

预期：`套件无法加载（语法错误？）: res://tests/registry_test.gd`（`Registry` 未定义），退出码 1。

- [ ] **Step 3: 写注册表实现**

创建 `src/core/registry.gd`：

```gdscript
class_name Registry
extends RefCounted

const TABLE_FILES: Dictionary = {
	"eras": "eras.json",
	"bloodlines": "bloodlines.json",
	"birth_identities": "birth_identities.json",
	"aptitudes": "aptitudes.json",
	"houses": "houses.json",
	"sim_styles": "sim_styles.json",
	"political_leanings": "political_leanings.json",
}

var duplicate_ids: PackedStringArray = PackedStringArray()
var _tables: Dictionary = {}

static func from_tables(tables: Dictionary) -> Registry:
	var r := Registry.new()
	for table_name in tables.keys():
		var index := {}
		var entries = tables[table_name]
		if typeof(entries) != TYPE_ARRAY:
			continue
		for entry in entries:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var key := str(entry.get("id", ""))
			if index.has(key):
				r.duplicate_ids.append("%s/%s" % [table_name, key])
			index[key] = entry
		r._tables[table_name] = index
	return r

static func load_default() -> Registry:
	var tables := {}
	for table_name in TABLE_FILES.keys():
		var path := "res://data/%s" % TABLE_FILES[table_name]
		var raw := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(raw)
		tables[table_name] = parsed if typeof(parsed) == TYPE_ARRAY else []
	return from_tables(tables)

func entry(table_name: String, id: String) -> Dictionary:
	var index: Dictionary = _tables.get(table_name, {})
	if not index.has(id):
		return {}
	return index[id]

func has(table_name: String, id: String) -> bool:
	return (_tables.get(table_name, {}) as Dictionary).has(id)

func ids(table_name: String) -> PackedStringArray:
	var out := PackedStringArray()
	for key in (_tables.get(table_name, {}) as Dictionary).keys():
		out.append(str(key))
	out.sort()
	return out

func table_dict(table_name: String) -> Dictionary:
	return _tables.get(table_name, {})

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for dup in duplicate_ids:
		errors.append("重复 id: %s" % dup)
	for table_name in TABLE_FILES.keys():
		if not _tables.has(table_name):
			errors.append("缺少数据表: %s" % table_name)
			continue
		var index: Dictionary = _tables[table_name]
		if index.is_empty():
			errors.append("数据表为空: %s" % table_name)
			continue
		for key in index.keys():
			if str(key).is_empty():
				errors.append("%s: 存在空 id 条目" % table_name)
			var e: Dictionary = index[key]
			if str(e.get("label", "")).is_empty():
				errors.append("%s/%s: 缺少 label" % [table_name, key])
	return errors
```

- [ ] **Step 4: 写内容表数据**

创建 `data/eras.json`（8 时代，含第七十五章标签与第四时代锚点；`world_vars` 为世界变量基线，第七十四章第6条「权力是流动的」由此初始化）：

```json
[
	{"id": "hogwarts_founding", "label": "霍格沃茨建校早期", "start_year": 990, "canon_note": "原著未给出确切建校年份，通说约公元10世纪；四位创始人共同建校，斯莱特林与格兰芬多的分裂成为派系斗争开端", "secrecy_law": false, "ministry_exists": false, "world_vars": {"war_pressure": 0.1, "ministry_stability": 0.2, "corruption": 0.1, "pureblood_influence": 0.4, "muggle_relations": 0.5, "economy_index": 0.3, "secrecy_integrity": 0.0}},
	{"id": "witch_hunts", "label": "中世纪猎巫时期", "start_year": 1692, "canon_note": "1692年《国际巫师保密法》正式实施，魔法世界与麻瓜世界彻底分离，魔法部成立", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.3, "ministry_stability": 0.5, "corruption": 0.3, "pureblood_influence": 0.5, "muggle_relations": 0.1, "economy_index": 0.4, "secrecy_integrity": 1.0}},
	{"id": "grindelwald", "label": "格林德沃崛起时代", "start_year": 1926, "canon_note": "格林德沃提出“为了更伟大的利益”，战争席卷欧洲，最终被邓布利多击败", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.6, "ministry_stability": 0.5, "corruption": 0.4, "pureblood_influence": 0.6, "muggle_relations": 0.2, "economy_index": 0.6, "secrecy_integrity": 0.9}},
	{"id": "first_wizarding_war", "label": "第一次巫师战争", "start_year": 1970, "canon_note": "汤姆·里德尔以伏地魔之名聚集食死徒，魔法部陷入腐败与恐惧，凤凰社成立抵抗", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.8, "ministry_stability": 0.4, "corruption": 0.6, "pureblood_influence": 0.7, "muggle_relations": 0.3, "economy_index": 0.5, "secrecy_integrity": 0.8}},
	{"id": "second_wizarding_war", "label": "第二次巫师战争", "start_year": 1995, "canon_note": "魔法部一度被食死徒渗透，霍格沃茨全面开战，最终伏地魔死亡、魂器毁灭", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.9, "ministry_stability": 0.3, "corruption": 0.7, "pureblood_influence": 0.6, "muggle_relations": 0.4, "economy_index": 0.5, "secrecy_integrity": 0.7}},
	{"id": "reconstruction", "label": "战后重建时代", "start_year": 1998, "canon_note": "战后纯血家族瓦解、魔法部改革、麻瓜出身平权等问题依然存在", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.3, "ministry_stability": 0.5, "corruption": 0.5, "pureblood_influence": 0.3, "muggle_relations": 0.5, "economy_index": 0.5, "secrecy_integrity": 0.8}},
	{"id": "modern", "label": "现代巫师社会", "start_year": 2010, "canon_note": "黑魔法的阴影并未完全消散，纯血主义的幽灵仍在游荡，新的魔法知识与麻瓜科技正在改变世界", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.1, "ministry_stability": 0.7, "corruption": 0.3, "pureblood_influence": 0.2, "muggle_relations": 0.6, "economy_index": 0.7, "secrecy_integrity": 0.9}},
	{"id": "custom", "label": "自定义时代", "start_year": null, "canon_note": "由玩家指定年份；系统据年份反查最近的原著锚点", "secrecy_law": true, "ministry_exists": true, "world_vars": {"war_pressure": 0.2, "ministry_stability": 0.6, "corruption": 0.3, "pureblood_influence": 0.3, "muggle_relations": 0.5, "economy_index": 0.6, "secrecy_integrity": 0.8}}
]
```

创建 `data/bloodlines.json`（12 血统，第七章 + 第七十五章选项；`prejudice` 为第十章结构性偏见强度）：

```json
[
	{"id": "muggle_born", "label": "麻瓜出身", "magic_aptitude": true, "prejudice": 0.4, "wealth_tier": 0, "skill_bias": {"muggle_world": 2, "social": 1}, "default_flags": [], "risk": "", "note": "在麻瓜世界长到十一岁，缺少魔法社会人脉与背景"},
	{"id": "half_blood", "label": "混血巫师", "magic_aptitude": true, "prejudice": 0.2, "wealth_tier": 0, "skill_bias": {"social": 1}, "default_flags": [], "risk": "", "note": "许多最强大的巫师是混血"},
	{"id": "pureblood_cadet", "label": "纯血旁支", "magic_aptitude": true, "prejudice": 0.1, "wealth_tier": 1, "skill_bias": {"history_of_magic": 1}, "default_flags": [], "risk": "", "note": "拥有姓氏带来的便利，也背负家族期望与偏见"},
	{"id": "sacred_twenty_eight", "label": "神圣二十八族", "magic_aptitude": true, "prejudice": 0.05, "wealth_tier": 2, "skill_bias": {"history_of_magic": 2, "social": 1}, "default_flags": [], "risk": "", "note": "神圣二十八族只是英国的一部分"},
	{"id": "squib", "label": "哑炮", "magic_aptitude": false, "prejudice": 0.7, "wealth_tier": 0, "skill_bias": {"muggle_world": 2}, "default_flags": ["no_magic"], "risk": "", "note": "出生于巫师家庭但无法使用魔法；仍可看见魔法世界，从事非魔法工作"},
	{"id": "obscurial", "label": "默然者", "magic_aptitude": true, "prejudice": 0.6, "wealth_tier": -1, "skill_bias": {}, "default_flags": ["obscurial"], "risk": "极高：几乎总是无法活到成年，力量极不稳定", "note": "幼年压抑魔法能力而诞生的危险黑暗力量，不是职业而是被诅咒的状态"},
	{"id": "part_veela", "label": "混血媚娃", "magic_aptitude": true, "prejudice": 0.4, "wealth_tier": 0, "skill_bias": {"social": 2}, "default_flags": ["veela_heritage"], "risk": "", "note": "拥有特殊魅力，也面临严重偏见"},
	{"id": "werewolf", "label": "狼人", "magic_aptitude": true, "prejudice": 0.8, "wealth_tier": -1, "skill_bias": {"dada": 1}, "default_flags": ["werewolf", "registered_werewolf"], "risk": "月圆之夜无法自控，就业与登记法歧视", "note": "狼人不等于怪物"},
	{"id": "half_giant", "label": "半巨人", "magic_aptitude": true, "prejudice": 0.7, "wealth_tier": -1, "skill_bias": {"care_of_magical_creatures": 2}, "default_flags": ["giant_blood"], "risk": "体格显眼，难以隐藏身份", "note": "巨人被驱逐，半巨人同样受歧视"},
	{"id": "half_centaur", "label": "半马人", "magic_aptitude": true, "prejudice": 0.7, "wealth_tier": -1, "skill_bias": {"astronomy": 2, "divination": 1}, "default_flags": ["centaur_blood"], "risk": "马人被划为“野兽”，法律地位低下", "note": "马人语言部分人类无法理解"},
	{"id": "elf_bound", "label": "家养小精灵契约相关", "magic_aptitude": true, "prejudice": 0.9, "wealth_tier": -2, "skill_bias": {"household_magic": 3}, "default_flags": ["bound_contract"], "risk": "契约奴役，逃跑即被追捕", "note": "家养小精灵可能真心认同奴役，也可能渴望自由"},
	{"id": "custom", "label": "自定义", "magic_aptitude": true, "prejudice": 0.0, "wealth_tier": 0, "skill_bias": {}, "default_flags": [], "risk": "", "note": "玩家自定血统；不得与原著明确事实冲突"}
]
```

创建 `data/birth_identities.json`（11 项；`start_knuts` 为 11 岁起始个人财产，普通巫师家庭 `4930` = 10加隆，恰好够买一根 7–10 加隆的魔杖，用于自洽性测试）：

```json
[
	{"id": "ordinary_wizard_family", "label": "普通巫师家庭", "start_knuts": 4930, "skill_bias": {"charms": 1}, "contacts": 3, "note": "普通巫师家庭年收入约数百加隆"},
	{"id": "muggle_family", "label": "麻瓜家庭", "start_knuts": 1479, "skill_bias": {"muggle_world": 2}, "contacts": 0, "note": "对魔法一无所知，完全依赖学校与猫头鹰"},
	{"id": "orphan", "label": "孤儿", "start_knuts": 0, "skill_bias": {"stealth": 1, "social": 1}, "contacts": 0, "note": "无家庭资源，人脉靠自己建立"},
	{"id": "declined_pureblood", "label": "纯血没落家族", "start_knuts": 2465, "skill_bias": {"history_of_magic": 2}, "contacts": 4, "note": "姓氏仍在，财富已去，背负家族期望"},
	{"id": "noble_pureblood", "label": "纯血豪门", "start_knuts": 98600, "skill_bias": {"history_of_magic": 2, "social": 1}, "contacts": 8, "note": "巨额财产不代表可以无代价"},
	{"id": "ministry_official", "label": "魔法部官员家庭", "start_knuts": 19720, "skill_bias": {"social": 2, "history_of_magic": 1}, "contacts": 6, "note": "一封推荐信可以打开霍格沃茨董事会的大门"},
	{"id": "auror_family", "label": "傲罗家庭", "start_knuts": 12325, "skill_bias": {"dada": 2, "charms": 1}, "contacts": 5, "note": "傲罗是执法者，也是政治工具"},
	{"id": "professor_family", "label": "教授家庭", "start_knuts": 14790, "skill_bias": {"charms": 1, "transfiguration": 1, "history_of_magic": 1}, "contacts": 5, "note": "学术资源与人脉，社会地位稳固"},
	{"id": "goblin_contract", "label": "古灵阁妖精契约相关", "start_knuts": 7395, "skill_bias": {"ancient_runes": 2, "social": 1}, "contacts": 4, "note": "妖精与巫师的关系充满历史仇恨与契约陷阱"},
	{"id": "st_mungo_family", "label": "圣芒戈治疗师家庭", "start_knuts": 9860, "skill_bias": {"healing": 2, "potions": 1}, "contacts": 4, "note": "治疗师不是万能复活机，很多伤害无法完全治愈"},
	{"id": "custom", "label": "自定义", "start_knuts": 4930, "skill_bias": {}, "contacts": 2, "note": "玩家自定出生身份"}
]
```

创建 `data/aptitudes.json`（6 项；`failure_delta` 为失败率偏移，负值更擅长施法）：

```json
[
	{"id": "squib", "label": "哑炮无魔法天赋", "failure_delta": 1.0, "grants": [], "special_options": [], "note": "无法施展咒语，人生可转向麻瓜世界或非魔法工作"},
	{"id": "normal", "label": "普通", "failure_delta": 0.0, "grants": [], "special_options": [], "note": "标准巫师天赋"},
	{"id": "good", "label": "良好", "failure_delta": -0.05, "grants": [], "special_options": [], "note": "学习魔咒较顺手"},
	{"id": "excellent", "label": "优秀", "failure_delta": -0.10, "grants": [], "special_options": [], "note": "天赋突出，仍不是传奇"},
	{"id": "special", "label": "特殊", "failure_delta": -0.10, "grants": [], "special_options": ["metamorphmagus", "parselmouth", "seer", "transfiguration_talent", "occlumency_talent"], "note": "需指定具体天赋：易容马格斯/蛇佬腔/预言天分/变形天赋/大脑封闭术天赋"},
	{"id": "random", "label": "随机", "failure_delta": 0.0, "grants": [], "special_options": [], "note": "创建时由系统掷定资质"}
]
```

创建 `data/houses.json`（6 项，第四章 + 第二十四章「学院不是性格标签」）：

```json
[
	{"id": "system", "label": "系统判定", "traits": [], "note": "由系统根据血统、资质、性格关键词判定"},
	{"id": "gryffindor", "label": "格兰芬多", "traits": ["勇气", "胆识", "骑士精神"], "note": "学院不是性格标签，格兰芬多也可以是懦夫"},
	{"id": "slytherin", "label": "斯莱特林", "traits": ["野心", "血统", "精明", "意志"], "note": "斯莱特林也可以是英雄"},
	{"id": "ravenclaw", "label": "拉文克劳", "traits": ["智慧", "知识", "创造力", "好奇"], "note": "知识垄断带来政治权力"},
	{"id": "hufflepuff", "label": "赫奇帕奇", "traits": ["忠诚", "勤勉", "公平", "坚韧"], "note": "勤勉者构成魔法社会大多数"},
	{"id": "none", "label": "未入学/成年/其他学校", "traits": [], "note": "含布斯巴顿、德姆斯特朗、伊法魔尼等"}
]
```

创建 `data/sim_styles.json`（6 项；`event_intensity` 与 `mundane_ratio` 供第六十八章防过度热闹使用）：

```json
[
	{"id": "brutal_realism", "label": "极度现实", "event_intensity": 0.5, "mundane_ratio": 0.8, "note": "代价真实，失败常见"},
	{"id": "campus_adventure", "label": "经典校园冒险", "event_intensity": 0.6, "mundane_ratio": 0.7, "note": "霍格沃茨生活为主轴"},
	{"id": "epic_wizarding_war", "label": "史诗巫师战争", "event_intensity": 1.0, "mundane_ratio": 0.4, "note": "战争推进，但世界仍不会每月都是决战"},
	{"id": "dark_fantasy", "label": "黑暗奇幻", "event_intensity": 0.8, "mundane_ratio": 0.5, "note": "黑魔法与禁忌更常见"},
	{"id": "daily_life", "label": "日常人生", "event_intensity": 0.2, "mundane_ratio": 1.0, "note": "上课、做魔药、打魁地奇、喝黄油啤酒"},
	{"id": "mixed", "label": "混合模式", "event_intensity": 0.5, "mundane_ratio": 0.7, "note": "默认模式"}
]
```

创建 `data/political_leanings.json`（6 项）：

```json
[
	{"id": "blood_equality", "label": "血统平等", "pureblood_opinion": -1.0, "ministry_opinion": 0.2, "risk": "在纯血势力当权时可能被针对", "note": "推动麻瓜出身平权、狼人权益、家养小精灵解放"},
	{"id": "pureblood_conservative", "label": "纯血保守", "pureblood_opinion": 1.0, "ministry_opinion": 0.5, "risk": "战后公开表态可能招致调查", "note": "维护传统与血统秩序"},
	{"id": "neutral_opportunist", "label": "中立投机", "pureblood_opinion": 0.0, "ministry_opinion": 0.5, "risk": "两边都可做生意，两边都不信任你", "note": "商人式政治"},
	{"id": "order_of_phoenix", "label": "凤凰社支持", "pureblood_opinion": -0.5, "ministry_opinion": -0.3, "risk": "没有官方身份，以信任与牺牲维持运作", "note": "独立于魔法部的抵抗网络"},
	{"id": "death_eater_sympathy", "label": "食死徒同情", "pureblood_opinion": 0.8, "ministry_opinion": -0.8, "risk": "被傲罗追捕、被威森加摩审判", "note": "黑巫师有政治目标，不是无脑反派"},
	{"id": "free_independent", "label": "自由独立", "pureblood_opinion": 0.0, "ministry_opinion": 0.0, "risk": "没有靠山", "note": "不站队，靠本事吃饭"}
]
```

- [ ] **Step 5: 运行测试，确认通过**

```bash
cd /e/Hali
bash tools/test.sh
```

预期：`[registry] 断言=... 失败=0`、`ALL TESTS PASSED`、`全部通过。`

- [ ] **Step 6: 提交**

```bash
cd /e/Hali
git add src/core/registry.gd data/ tests/registry_test.gd tests/run_tests.gd
git commit -m "feat(content): 内容注册表与七张正典内容表"
```

---

### Task 3: 货币 + 魔法等级与失败率

**Files:**
- Create: `src/model/money.gd`
- Create: `src/rules/magic_level.gd`
- Create: `tests/money_test.gd`
- Create: `tests/magic_level_test.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `TestAssert`
- Produces:
  - `Money`（`extends RefCounted`，值语义，所有运算返回新对象）
    - 常量 `KNUTS_PER_SICKLE := 17`、`SICKLES_PER_GALLEON := 17`、`KNUTS_PER_GALLEON := 493`
    - `static from_knuts(total: int) -> Money`
    - `static from_dict(d: Dictionary) -> Money`（`{"galleons":int,"sickles":int,"knuts":int}`）
    - `total_knuts() -> int`、`parts() -> Array[int]`（`[加隆, 西可, 纳特]`，可为负）
    - `add(other: Money) -> Money`、`subtract(other: Money) -> Money`
    - `formatted() -> String`（`"1加隆 1西可 1纳特"`）、`to_dict() -> Dictionary`
  - `MagicLevel`（`extends RefCounted`）
    - `enum Tier { SQUIB, PRE_SCHOOL, FIRST_YEAR, OWL, NEWT, ADULT, EXPERT, MASTER, LEGEND, MYTH }`
    - `LABELS: Array[String]`（10 项，顺序即 Tier）
    - `BANDS: Array[Vector2]`（每级的失败率区间，Vector2(min, max)）
    - `MODIFIER_KEYS: Array[String]`（`combat_stress`, `injury`, `emotion`, `wand_mismatch`, `unfamiliar_spell`, `dark_magic_interference`）
    - `static label_of(tier: int) -> String`
    - `static index_of_label(label: String) -> int`（未找到返回 -1）
    - `static base_rate(tier: int) -> float`（区间中点）
    - `static effective_rate(tier: int, modifiers: Dictionary, aptitude_delta: float = 0.0) -> float`（钳制到 [0.005, 0.95]）

- [ ] **Step 1: 写失败测试**

创建 `tests/money_test.gd`：

```gdscript
class_name MoneyTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()

	# 第十八章：1加隆 = 17西可 = 493纳特
	a.eq(Money.KNUTS_PER_GALLEON, 493, "1加隆=493纳特")
	a.eq(Money.from_knuts(493).parts(), [1, 0, 0], "493纳特=1加隆")
	a.eq(Money.from_knuts(17).parts(), [0, 1, 0], "17纳特=1西可")
	a.eq(Money.from_knuts(510).parts(), [1, 1, 0], "493+17 = 1加隆1西可（17纳特进位为1西可）")
	a.eq(Money.from_knuts(511).parts(), [1, 1, 1], "493+17+1 = 1加隆1西可1纳特")

	# 展示格式
	a.eq(Money.from_knuts(493 + 17 + 1).formatted(), "1加隆 1西可 1纳特", "格式")
	a.eq(Money.from_knuts(0).formatted(), "0加隆 0西可 0纳特", "零")

	# 一根普通魔杖 7–10 加隆（第十八章），必须落在同一货币体系内
	var wand_price := Money.from_knuts(7 * Money.KNUTS_PER_GALLEON)
	a.eq(wand_price.parts(), [7, 0, 0], "魔杖 7 加隆")
	a.is_true(Money.from_knuts(10 * Money.KNUTS_PER_GALLEON).total_knuts() > wand_price.total_knuts(), "10加隆 > 7加隆")

	# 值语义：add/subtract 不得修改原对象
	var base := Money.from_knuts(100)
	var plus := base.add(Money.from_knuts(50))
	a.eq(base.total_knuts(), 100, "add 不修改原对象")
	a.eq(plus.total_knuts(), 150, "add 返回新对象")
	a.eq(plus.subtract(Money.from_knuts(200)).total_knuts(), -50, "允许负债（第十九章：家族破产）")

	# 往返
	var d := Money.from_knuts(493 * 3 + 17 * 2 + 5).to_dict()
	a.eq(d, {"galleons": 3, "sickles": 2, "knuts": 5}, "to_dict 归一")
	a.eq(Money.from_dict(d).total_knuts(), Money.from_knuts(493 * 3 + 17 * 2 + 5).total_knuts(), "往返一致")
	a.eq(Money.from_dict({}).total_knuts(), 0, "空字典=0")

	return a.report("money")
```

创建 `tests/magic_level_test.gd`：

```gdscript
class_name MagicLevelTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()

	# 第二十三章：等级序列
	a.eq(MagicLevel.LABELS.size(), 10, "十级")
	a.eq(MagicLevel.label_of(MagicLevel.Tier.SQUIB), "哑炮", "第一级")
	a.eq(MagicLevel.label_of(MagicLevel.Tier.PRE_SCHOOL), "麻瓜出身未入学", "第二级")
	a.eq(MagicLevel.label_of(MagicLevel.Tier.MYTH), "神话级", "第十级")
	a.eq(MagicLevel.index_of_label("N.E.W.T水平"), MagicLevel.Tier.NEWT, "按标签反查")
	a.eq(MagicLevel.index_of_label("不存在的等级"), -1, "未知标签返回 -1")
	a.eq(MagicLevel.label_of(99), "未知", "越界安全")

	# 第二十二章失败率区间，逐字核对
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.PRE_SCHOOL], Vector2(0.60, 0.80), "未入学 60-80%")
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.FIRST_YEAR], Vector2(0.30, 0.50), "低年级 30-50%")
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.OWL], Vector2(0.15, 0.30), "O.W.L 15-30%")
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.NEWT], Vector2(0.05, 0.15), "N.E.W.T 5-15%")
	a.eq(MagicLevel.BANDS[MagicLevel.Tier.ADULT], Vector2(0.02, 0.05), "熟练成年 2-5%")
	a.is_true(MagicLevel.BANDS[MagicLevel.Tier.MASTER].y <= 0.02, "大师级低于 2%")
	a.eq(MagicLevel.effective_rate(MagicLevel.Tier.SQUIB, {}), 0.95, "哑炮无法施法，钳制上界")

	# 无环境因素时等于区间中点
	a.near(MagicLevel.effective_rate(MagicLevel.Tier.FIRST_YEAR, {}), 0.40, 0.0001, "低年级中点 40%")
	a.near(MagicLevel.effective_rate(MagicLevel.Tier.NEWT, {}), 0.10, 0.0001, "N.E.W.T 中点 10%")

	# 第二十二章：环境因素大幅改变失败概率
	var calm := MagicLevel.effective_rate(MagicLevel.Tier.ADULT, {})
	var stressed := MagicLevel.effective_rate(MagicLevel.Tier.ADULT, {"combat_stress": 1.0, "injury": 1.0})
	a.is_true(stressed > calm, "战斗压力与受伤提高失败率")
	a.is_true(stressed - calm >= 0.20, "两项满值环境因素至少 +20 个百分点")
	a.is_true(MagicLevel.effective_rate(MagicLevel.Tier.MYTH, {"combat_stress": 1.0, "injury": 1.0, "emotion": 1.0, "wand_mismatch": 1.0, "unfamiliar_spell": 1.0, "dark_magic_interference": 1.0}) <= 0.95, "失败率上界 0.95")
	a.is_true(MagicLevel.effective_rate(MagicLevel.Tier.LEGEND, {}) >= 0.005, "失败率下界 0.005（没有绝对成功）")

	# 资质偏移（data/aptitudes.json 的 failure_delta）
	a.near(MagicLevel.effective_rate(MagicLevel.Tier.FIRST_YEAR, {}, -0.10), 0.30, 0.0001, "优秀资质降低失败率")

	# 未知修正键必须被忽略而不是崩
	a.near(MagicLevel.effective_rate(MagicLevel.Tier.FIRST_YEAR, {"不存在的因素": 5.0}), 0.40, 0.0001, "未知修正键被忽略")

	return a.report("magic_level")
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /e/Hali
sed -i 's|"res://tests/registry_test.gd",|"res://tests/registry_test.gd",\n\t"res://tests/money_test.gd",\n\t"res://tests/magic_level_test.gd",|' tests/run_tests.gd
bash tools/test.sh
```

预期：两个套件 `套件无法加载（语法错误？）`，退出码 1。

- [ ] **Step 3: 实现 `Money`**

创建 `src/model/money.gd`：

```gdscript
class_name Money
extends RefCounted

const KNUTS_PER_SICKLE := 17
const SICKLES_PER_GALLEON := 17
const KNUTS_PER_GALLEON := 493

var _knuts: int = 0

static func from_knuts(total: int) -> Money:
	var m := Money.new()
	m._knuts = total
	return m

static func from_dict(d: Dictionary) -> Money:
	return from_knuts(int(d.get("galleons", 0)) * KNUTS_PER_GALLEON \
		+ int(d.get("sickles", 0)) * KNUTS_PER_SICKLE \
		+ int(d.get("knuts", 0)))

func total_knuts() -> int:
	return _knuts

func add(other: Money) -> Money:
	return from_knuts(_knuts + other.total_knuts())

func subtract(other: Money) -> Money:
	return from_knuts(_knuts - other.total_knuts())

func parts() -> Array[int]:
	var negative := _knuts < 0
	var v: int = absi(_knuts)
	var g: int = v / KNUTS_PER_GALLEON
	var rest: int = v % KNUTS_PER_GALLEON
	var s: int = rest / KNUTS_PER_SICKLE
	var k: int = rest % KNUTS_PER_SICKLE
	if negative:
		return [-g, -s, -k]
	return [g, s, k]

func formatted() -> String:
	var p := parts()
	return "%d加隆 %d西可 %d纳特" % [p[0], p[1], p[2]]

func to_dict() -> Dictionary:
	var p := parts()
	return {"galleons": p[0], "sickles": p[1], "knuts": p[2]}
```

- [ ] **Step 4: 实现 `MagicLevel`**

创建 `src/rules/magic_level.gd`：

```gdscript
class_name MagicLevel
extends RefCounted

enum Tier { SQUIB, PRE_SCHOOL, FIRST_YEAR, OWL, NEWT, ADULT, EXPERT, MASTER, LEGEND, MYTH }

const LABELS: Array[String] = [
	"哑炮", "麻瓜出身未入学", "霍格沃茨新生", "O.W.L水平", "N.E.W.T水平",
	"熟练成年巫师", "专家级", "大师级", "传奇级", "神话级",
]

# 第二十二章施法失败概率，逐字编码为区间
const BANDS: Array[Vector2] = [
	Vector2(1.00, 1.00),   # 哑炮：无法施法
	Vector2(0.60, 0.80),   # 新手/未入学
	Vector2(0.30, 0.50),   # 霍格沃茨低年级
	Vector2(0.15, 0.30),   # O.W.L
	Vector2(0.05, 0.15),   # N.E.W.T
	Vector2(0.02, 0.05),   # 熟练成年巫师
	Vector2(0.02, 0.05),   # 专家级
	Vector2(0.005, 0.02),  # 大师级
	Vector2(0.005, 0.015), # 传奇级
	Vector2(0.005, 0.01),  # 神话级
]

const MODIFIER_KEYS: Array[String] = [
	"combat_stress", "injury", "emotion", "wand_mismatch", "unfamiliar_spell", "dark_magic_interference",
]

const MODIFIER_WEIGHT := 0.15

static func label_of(tier: int) -> String:
	if tier < 0 or tier >= LABELS.size():
		return "未知"
	return LABELS[tier]

static func index_of_label(label: String) -> int:
	return LABELS.find(label)

static func base_rate(tier: int) -> float:
	var band: Vector2 = BANDS[clampi(tier, 0, BANDS.size() - 1)]
	return (band.x + band.y) * 0.5

static func effective_rate(tier: int, modifiers: Dictionary, aptitude_delta: float = 0.0) -> float:
	var clamped_tier := clampi(tier, 0, BANDS.size() - 1)
	if clamped_tier == Tier.SQUIB:
		return 0.95
	var rate := base_rate(clamped_tier) + aptitude_delta
	for key in MODIFIER_KEYS:
		rate += clampf(float(modifiers.get(key, 0.0)), 0.0, 1.0) * MODIFIER_WEIGHT
	return clampf(rate, 0.005, 0.95)
```

- [ ] **Step 5: 运行测试，确认通过**

```bash
cd /e/Hali
bash tools/test.sh
```

预期：`[money] 失败=0`、`[magic_level] 失败=0`、`全部通过。`

- [ ] **Step 6: 提交**

```bash
cd /e/Hali
git add src/model/money.gd src/rules/magic_level.gd tests/money_test.gd tests/magic_level_test.gd tests/run_tests.gd
git commit -m "feat(rules): 巫师货币与魔法等级失败率"
```

---

### Task 4: 玩家与世界数据模型

**Files:**
- Create: `src/model/player_state.gd`
- Create: `src/model/world_state.gd`
- Create: `src/core/json_util.gd`（JSON 数值规范化：存读档往返一致性的前提）
- Create: `src/core/game_clock.gd`（模型往返需要时钟，故与模型同任务交付）
- Create: `tests/model_test.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `Money`、`MagicLevel`（任务 3）、`Registry`（任务 2）
- Produces:
  - `JsonUtil`（`extends RefCounted`）
    - `static normalize(value) -> Variant`：递归处理 Dictionary/Array；整数值的 float 归一为 int，真正的小数（如 0.42）保持 float，bool/String/null 原样
  - `GameClock`（`extends RefCounted`）
    - 字段 `year: int`、`month: int`（1–12）、`turn: int`（回合数，起始 0）
    - `static from_dict(d: Dictionary) -> GameClock`、`to_dict() -> Dictionary`
    - `advance_month() -> void`（跨年自动进位，`turn += 1`）、`advance_months(n: int) -> void`
    - `formatted() -> String`（`"1991年9月"`）、`months_between(other: GameClock) -> int`
  - `PlayerState`（`extends RefCounted`）字段：
    `name_text, gender, age_months, bloodline_id, birth_identity_id, birthplace, family_status, aptitude_id, aptitude_special, house_id, political_leaning_id, personality: Array, life_goal, sim_style_id, wand: Dictionary, magic_tier: int, money_knuts: int, reputation: int, skills: Dictionary, magic: Dictionary, relations: Dictionary, faction_id, current_goal, location_id, job, alive: bool, flags: Dictionary, known_facts: Dictionary, next_id: int`
    方法：`age_years() -> int`、`money() -> Money`、`set_money(m: Money) -> void`、`skill(skill_id: String) -> int`、`add_skill(skill_id: String, amount: int) -> void`（钳制 0..100）、`knows_spell(spell_id: String) -> bool`、`learn_spell(spell_id: String) -> void`、`to_dict() -> Dictionary`（**输出经 `JsonUtil.normalize()` 规范化**）、`static from_dict(d: Dictionary) -> PlayerState`（对 `magic`/`skills`/`flags`/`relations` 等动态子字典调用 `JsonUtil.normalize()`）
    `magic` 字典结构（第六十三章面板）：`{"capacity":int,"control":int,"affinity":int,"subjects":Array,"known_spells":Array,"experimenting":Array,"potions":int,"occlumency":int,"apparition":int,"patronus":String}`
  - `WorldState`（`extends RefCounted`）
    - 字段 `registry: Registry`（**瞬态，不序列化**）、`save_version: int`、`game_seed: int`、`era_id: String`、`clock: GameClock`、`player: PlayerState`、`npcs: Dictionary`、`factions: Dictionary`、`locations: Dictionary`、`history: Array`、`pending: Array`、`world_vars: Dictionary`、`log: Array`、`flags: Dictionary`、`rng_state: Dictionary`
    - `static create(era_id, player, seed, registry) -> WorldState`（用 `eras.world_vars` 初始化世界变量）
    - `to_dict() -> Dictionary`（**输出经 `JsonUtil.normalize()` 规范化**）、`static from_dict(d: Dictionary, registry: Registry) -> WorldState`
    - `era() -> Dictionary`、`current_location() -> Dictionary`
    - `add_fact(kind: String, text: String) -> Dictionary`（写入 `history` 与 `log`，返回该 fact）

- [ ] **Step 1: 写失败测试**

创建 `tests/model_test.gd`：

```gdscript
class_name ModelTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	# ---- GameClock ----
	var clock := GameClock.from_dict({"year": 1991, "month": 9, "turn": 0})
	a.eq(clock.formatted(), "1991年9月", "时钟格式")
	clock.advance_month()
	a.eq(clock.formatted(), "1991年10月", "推进一个月")
	a.eq(clock.turn, 1, "回合数+1")
	for i in 4:
		clock.advance_month()
	a.eq(clock.formatted(), "1992年2月", "跨年进位")
	a.eq(clock.turn, 5, "回合数累计")
	clock.advance_months(12)
	a.eq(clock.formatted(), "1993年2月", "advance_months 跨年")
	a.eq(clock.turn, 17, "advance_months 累加回合")
	var later := GameClock.from_dict({"year": 1993, "month": 5, "turn": 0})
	a.eq(clock.months_between(later), 3, "月份差")
	a.eq(later.months_between(clock), -3, "月份差为负")
	a.eq(GameClock.from_dict(clock.to_dict()).formatted(), "1993年2月", "时钟往返")

	# ---- PlayerState ----
	var p := PlayerState.from_dict({
		"name_text": "张三",
		"gender": "男",
		"age_months": 132,
		"bloodline_id": "muggle_born",
		"money_knuts": 4930,
	})
	a.eq(p.age_years(), 11, "11岁")
	a.eq(p.money().formatted(), "10加隆 0西可 0纳特", "起始财产")
	# 正典第十八章：一根普通魔杖 7‑10 加隆；取价格下限 7 加隆 = 7 × 493 = 3451 纳特
	p.set_money(p.money().subtract(Money.from_knuts(7 * Money.KNUTS_PER_GALLEON)))
	a.eq(p.money().formatted(), "3加隆 0西可 0纳特", "买 7 加隆普通魔杖后剩 3 加隆（正典第十八章）")
	p.add_skill("potions", 3)
	p.add_skill("potions", 2)
	a.eq(p.skill("potions"), 5, "技能累加")
	p.add_skill("potions", 1000)
	a.eq(p.skill("potions"), 100, "技能上界 100")
	p.add_skill("potions", -1000)
	a.eq(p.skill("potions"), 0, "技能下界 0")
	a.eq(p.skill("未学过的技能"), 0, "未知技能为 0")
	a.is_false(p.knows_spell("wingardium_leviosa"), "尚未掌握魔咒")
	p.learn_spell("wingardium_leviosa")
	p.learn_spell("wingardium_leviosa")
	a.is_true(p.knows_spell("wingardium_leviosa"), "掌握魔咒")
	a.eq(p.magic["known_spells"].size(), 1, "不重复记录同一魔咒")
	a.has_key(p.magic, "capacity", "第六十三章面板字段存在")

	# 往返：中文与嵌套结构必须无损
	var p2 := PlayerState.from_dict(p.to_dict())
	a.eq(p2.name_text, "张三", "姓名往返")
	a.eq(p2.to_dict(), p.to_dict(), "玩家状态完全往返")
	# 端到端：经 JSON 字符串（真实存档路径）往返后仍必须逐字节相等
	var p3 := PlayerState.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	a.eq(p3.to_dict(), p.to_dict(), "经 JSON 字符串的玩家状态往返")

	# ---- JsonUtil：JSON 数值规范化（存读档往返一致性的唯一保障） ----
	a.is_true(typeof(JsonUtil.normalize(2.0)) == TYPE_INT, "2.0 归一为 int")
	a.is_true(typeof(JsonUtil.normalize(0.42)) == TYPE_FLOAT, "0.42 保持 float")
	a.eq(JsonUtil.normalize(0.42), 0.42, "浮点值不变")
	a.eq(JsonUtil.normalize([1.0, 2.5, {"a": 3.0}]), [1, 2.5, {"a": 3}], "递归处理数组与字典")
	a.eq(JsonUtil.normalize(true), true, "bool 原样")
	a.eq(JsonUtil.normalize(null), null, "null 原样")
	a.eq(JsonUtil.normalize("张三"), "张三", "字符串原样")
	# 未经规范化的 JSON 往返必然不等（这就是必须归一的原因）
	var raw_round_trip = JSON.parse_string(JSON.stringify({"n": 493}))
	a.ne(raw_round_trip, {"n": 493}, "JSON 解析出的 float 与 int 深比较不相等")
	a.eq(JsonUtil.normalize(raw_round_trip), {"n": 493}, "规范化后相等")

	# ---- WorldState ----
	var w := WorldState.create("first_wizarding_war", p, 20260918, reg)
	a.eq(w.clock.year, 1970, "时代锚定起始年份")
	a.eq(w.era()["label"], "第一次巫师战争", "时代查询")
	a.eq(w.world_vars["war_pressure"], 0.8, "世界变量取自时代基线")
	a.eq(w.world_vars.size(), 7, "七项世界变量")
	a.eq(w.save_version, 1, "存档版本")
	a.eq(w.player.name_text, "张三", "持有玩家")
	var fact := w.add_fact("major", "伏地魔第一次倒台")
	a.eq(w.history.size(), 1, "写入历史")
	a.eq(fact["turn"], 0, "事实带回合号")
	a.eq(w.log.size(), 1, "写入日志")

	var w2 := WorldState.from_dict(w.to_dict(), reg)
	a.eq(w2.to_dict(), w.to_dict(), "世界状态完全往返")
	a.eq(w2.registry, reg, "往返后重新挂载注册表")
	a.is_true(w2.era()["id"] == "first_wizarding_war", "往返后仍能查询内容表")
	# 端到端：经 JSON 字符串（真实存档路径）往返后仍必须相等
	var w3 := WorldState.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())), reg)
	a.eq(w3.to_dict(), w.to_dict(), "经 JSON 字符串的世界状态往返")

	# create 与 from_dict 必须产出同型的 world_vars（含整数值 float，如 witch_hunts.secrecy_integrity=1.0）
	var we := WorldState.create("witch_hunts", PlayerState.from_dict({"name_text": "乙"}), 1, reg)
	var we2 := WorldState.from_dict(we.to_dict(), reg)
	a.eq(we2.world_vars, we.world_vars, "world_vars 类型在 create 与 from_dict 间一致")

	# to_dict 不得包含瞬态注册表；也不得出现非 JSON 原生类型
	var d := w.to_dict()
	a.is_false(d.has("registry"), "注册表不序列化")
	a.is_true(JSON.stringify(d).length() > 0, "世界状态可被 JSON 序列化")

	return a.report("model")
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /e/Hali
sed -i 's|"res://tests/magic_level_test.gd",|"res://tests/magic_level_test.gd",\n\t"res://tests/model_test.gd",|' tests/run_tests.gd
bash tools/test.sh
```

预期：`套件无法加载（语法错误？）: res://tests/model_test.gd`（`GameClock` 未定义），退出码 1。

- [ ] **Step 3: 实现 `GameClock`**

创建 `src/core/game_clock.gd`：

```gdscript
class_name GameClock
extends RefCounted

var year: int = 1991
var month: int = 9
var turn: int = 0

static func from_dict(d: Dictionary) -> GameClock:
	var c := GameClock.new()
	c.year = int(d.get("year", 1991))
	c.month = clampi(int(d.get("month", 1)), 1, 12)
	c.turn = int(d.get("turn", 0))
	return c

func to_dict() -> Dictionary:
	return {"year": year, "month": month, "turn": turn}

func advance_month() -> void:
	month += 1
	if month > 12:
		month = 1
		year += 1
	turn += 1

func advance_months(n: int) -> void:
	for i in maxi(n, 0):
		advance_month()

func formatted() -> String:
	return "%d年%d月" % [year, month]

func months_between(other: GameClock) -> int:
	return (other.year - year) * 12 + (other.month - month)
```

- [ ] **Step 4: 实现 `JsonUtil` 与 `PlayerState`**

先创建 `src/core/json_util.gd`：

```gdscript
class_name JsonUtil
extends RefCounted

# JSON 没有 int/float 之分，解析回来全是 float；而 Godot 的 Dictionary 深比较是类型严格的。
# 因此存档往返（to_dict → JSON → from_dict → to_dict）必须先把整数值的 float 归一为 int。
static func normalize(value):
	match typeof(value):
		TYPE_FLOAT:
			var f := float(value)
			if is_finite(f) and f == floor(f) and absf(f) < 9007199254740992.0:
				return int(f)
			return f
		TYPE_DICTIONARY:
			var out := {}
			for key in (value as Dictionary).keys():
				out[key] = normalize(value[key])
			return out
		TYPE_ARRAY:
			var arr := []
			for item in (value as Array):
				arr.append(normalize(item))
			return arr
		_:
			return value
```

再创建 `src/model/player_state.gd`：

创建 `src/model/player_state.gd`：

```gdscript
class_name PlayerState
extends RefCounted

const SKILL_MAX := 100

var name_text: String = ""
var gender: String = ""
var age_months: int = 0
var bloodline_id: String = ""
var birth_identity_id: String = ""
var birthplace: String = ""
var family_status: String = ""
var aptitude_id: String = ""
var aptitude_special: String = ""
var house_id: String = "none"
var political_leaning_id: String = ""
var personality: Array = []
var life_goal: String = ""
var sim_style_id: String = "mixed"
var wand: Dictionary = {}
var magic_tier: int = MagicLevel.Tier.PRE_SCHOOL
var money_knuts: int = 0
var reputation: int = 0
var skills: Dictionary = {}
var magic: Dictionary = {}
var relations: Dictionary = {}
var faction_id: String = ""
var current_goal: String = ""
var location_id: String = ""
var job: String = ""
var alive: bool = true
var flags: Dictionary = {}
var known_facts: Dictionary = {}
var next_id: int = 1

static func new_default() -> PlayerState:
	var p := PlayerState.new()
	p.magic = {
		"capacity": 10, "control": 10, "affinity": 10,
		"subjects": [], "known_spells": [], "experimenting": [],
		"potions": 0, "occlumency": 0, "apparition": 0, "patronus": "",
	}
	return p

func age_years() -> int:
	return age_months / 12

func money() -> Money:
	return Money.from_knuts(money_knuts)

func set_money(m: Money) -> void:
	money_knuts = m.total_knuts()

func skill(skill_id: String) -> int:
	return int(skills.get(skill_id, 0))

func add_skill(skill_id: String, amount: int) -> void:
	skills[skill_id] = clampi(skill(skill_id) + amount, 0, SKILL_MAX)

func knows_spell(spell_id: String) -> bool:
	return (magic.get("known_spells", []) as Array).has(spell_id)

func learn_spell(spell_id: String) -> void:
	var known: Array = magic.get("known_spells", [])
	if not known.has(spell_id):
		known.append(spell_id)
	magic["known_spells"] = known

func to_dict() -> Dictionary:
	return JsonUtil.normalize({
		"name_text": name_text, "gender": gender, "age_months": age_months,
		"bloodline_id": bloodline_id, "birth_identity_id": birth_identity_id,
		"birthplace": birthplace, "family_status": family_status,
		"aptitude_id": aptitude_id, "aptitude_special": aptitude_special,
		"house_id": house_id, "political_leaning_id": political_leaning_id,
		"personality": personality, "life_goal": life_goal, "sim_style_id": sim_style_id,
		"wand": wand, "magic_tier": magic_tier, "money_knuts": money_knuts,
		"reputation": reputation, "skills": skills, "magic": magic,
		"relations": relations, "faction_id": faction_id, "current_goal": current_goal,
		"location_id": location_id, "job": job, "alive": alive,
		"flags": flags, "known_facts": known_facts, "next_id": next_id,
	})

static func from_dict(d: Dictionary) -> PlayerState:
	var p := PlayerState.new_default()
	p.name_text = str(d.get("name_text", ""))
	p.gender = str(d.get("gender", ""))
	p.age_months = int(d.get("age_months", 0))
	p.bloodline_id = str(d.get("bloodline_id", ""))
	p.birth_identity_id = str(d.get("birth_identity_id", ""))
	p.birthplace = str(d.get("birthplace", ""))
	p.family_status = str(d.get("family_status", ""))
	p.aptitude_id = str(d.get("aptitude_id", ""))
	p.aptitude_special = str(d.get("aptitude_special", ""))
	p.house_id = str(d.get("house_id", "none"))
	p.political_leaning_id = str(d.get("political_leaning_id", ""))
	p.personality = JsonUtil.normalize(d.get("personality", []))
	p.life_goal = str(d.get("life_goal", ""))
	p.sim_style_id = str(d.get("sim_style_id", "mixed"))
	p.wand = JsonUtil.normalize(d.get("wand", {}))
	p.magic_tier = int(d.get("magic_tier", MagicLevel.Tier.PRE_SCHOOL))
	p.money_knuts = int(d.get("money_knuts", 0))
	p.reputation = int(d.get("reputation", 0))
	p.skills = JsonUtil.normalize(d.get("skills", {}))
	p.magic = JsonUtil.normalize(d.get("magic", p.magic))
	p.relations = JsonUtil.normalize(d.get("relations", {}))
	p.faction_id = str(d.get("faction_id", ""))
	p.current_goal = str(d.get("current_goal", ""))
	p.location_id = str(d.get("location_id", ""))
	p.job = str(d.get("job", ""))
	p.alive = bool(d.get("alive", true))
	p.flags = JsonUtil.normalize(d.get("flags", {}))
	p.known_facts = JsonUtil.normalize(d.get("known_facts", {}))
	p.next_id = int(d.get("next_id", 1))
	return p
```

> 注意 `from_dict` 里 `p.magic = d.get("magic", p.magic)`：旧存档缺字段时保留 `new_default()` 的面板骨架，而不是变成空字典。

- [ ] **Step 5: 实现 `WorldState`**

创建 `src/model/world_state.gd`：

```gdscript
class_name WorldState
extends RefCounted

const SAVE_VERSION := 1

var registry: Registry = null      # 瞬态：不入存档
var save_version: int = SAVE_VERSION
var game_seed: int = 0
var era_id: String = ""
var clock: GameClock = null
var player: PlayerState = null
var npcs: Dictionary = {}
var factions: Dictionary = {}
var locations: Dictionary = {}
var history: Array = []
var pending: Array = []
var world_vars: Dictionary = {}
var log: Array = []
var flags: Dictionary = {}
var rng_state: Dictionary = {}
var era_start_year: int = 0        # 时代锚点年份，供时间线自检使用

static func create(era_id_: String, player_: PlayerState, seed_: int, registry_: Registry) -> WorldState:
	var w := WorldState.new()
	w.registry = registry_
	w.game_seed = seed_
	w.era_id = era_id_
	w.player = player_
	var era: Dictionary = registry_.entry("eras", era_id_)
	var start_year := int(era.get("start_year", 1991)) if era.get("start_year", null) != null else 1991
	w.era_start_year = start_year
	w.clock = GameClock.from_dict({"year": start_year, "month": 9, "turn": 0})
	# JSON 解析出的整数值 float 必须归一，保证 create 与 from_dict 的内存类型一致（HANDOFF 第 4 节第 1 条）
	w.world_vars = JsonUtil.normalize((era.get("world_vars", {}) as Dictionary).duplicate(true))
	w.player.age_months = maxi(w.player.age_months, 0)
	return w

func era() -> Dictionary:
	return registry.entry("eras", era_id)

func current_location() -> Dictionary:
	return registry.entry("locations", player.location_id)

func add_fact(kind: String, text: String) -> Dictionary:
	var fact := {"kind": kind, "text": text, "turn": clock.turn, "year": clock.year}
	history.append(fact)
	log.append({"turn": clock.turn, "kind": kind, "text": text})
	return fact

func to_dict() -> Dictionary:
	return JsonUtil.normalize({
		"save_version": save_version,
		"game_seed": game_seed,
		"era_id": era_id,
		"era_start_year": era_start_year,
		"clock": clock.to_dict(),
		"player": player.to_dict(),
		"npcs": npcs, "factions": factions, "locations": locations,
		"history": history, "pending": pending, "world_vars": world_vars,
		"log": log, "flags": flags, "rng_state": rng_state,
	})

static func from_dict(d: Dictionary, registry_: Registry) -> WorldState:
	var w := WorldState.new()
	w.registry = registry_
	w.save_version = int(d.get("save_version", SAVE_VERSION))
	w.game_seed = int(d.get("game_seed", 0))
	w.era_id = str(d.get("era_id", ""))
	w.era_start_year = int(d.get("era_start_year", 0))
	w.clock = GameClock.from_dict(d.get("clock", {}))
	w.player = PlayerState.from_dict(d.get("player", {}))
	w.npcs = JsonUtil.normalize(d.get("npcs", {}))
	w.factions = JsonUtil.normalize(d.get("factions", {}))
	w.locations = JsonUtil.normalize(d.get("locations", {}))
	w.history = JsonUtil.normalize(d.get("history", []))
	w.pending = JsonUtil.normalize(d.get("pending", []))
	w.world_vars = JsonUtil.normalize(d.get("world_vars", {}))
	w.log = JsonUtil.normalize(d.get("log", []))
	w.flags = JsonUtil.normalize(d.get("flags", {}))
	w.rng_state = JsonUtil.normalize(d.get("rng_state", {}))
	return w
```

- [ ] **Step 6: 运行测试，确认通过**

```bash
cd /e/Hali
bash tools/test.sh
```

预期：`[model] 失败=0`、`全部通过。`

- [ ] **Step 7: 提交**

```bash
cd /e/Hali
git add src/core/game_clock.gd src/model/player_state.gd src/model/world_state.gd tests/model_test.gd tests/run_tests.gd
git commit -m "feat(model): 时钟、玩家与世界状态模型"
```

---

### Task 5: 确定性随机 + 月度世界演化

**Files:**
- Create: `src/core/rng_service.gd`
- Create: `data/locations.json`
- Create: `data/rumors.json`
- Modify: `src/model/world_state.gd`（新增 `tick()`）
- Modify: `src/core/registry.gd`（`TABLE_FILES` 追加 `locations`、`rumors`）
- Create: `tests/clock_test.gd`
- Create: `tests/world_tick_test.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `WorldState`、`GameClock`（任务 4）、`Registry`（任务 2）
- Produces:
  - `RngService`（`extends RefCounted`）
    - `_init(seed_value: int)`
    - `stream(name: String) -> RandomNumberGenerator`（同名流稳定；不同名互不干扰）
    - `stream_int(name: String, from: int, to: int) -> int`
    - `stream_float(name: String) -> float`
    - `stream_pick(name: String, options: Array)`
    - `chance(name: String, probability: float) -> bool`
    - `state_dict() -> Dictionary`、`load_state(d: Dictionary) -> void`（存档可恢复随机流）
  - `WorldState.tick() -> Array`：推进一个月，返回本月事件（Dictionary 数组，元素含 `kind`/`category`/`text`/`major`）
  - 数据表：`locations`（`id,label,zone,danger,danger_label`）、`rumors`（`id,category,text,weight,major,min_year,zones[],requires_flags[]`）

- [ ] **Step 1: 写失败测试**

创建 `tests/clock_test.gd`：

```gdscript
class_name ClockTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()

	# 同一 seed 必须完全可复现（存档读档后世界必须继续一致）
	var r1 := RngService.new(20260918)
	var r2 := RngService.new(20260918)
	for i in 20:
		a.eq(r1.stream_int("world", 0, 1000), r2.stream_int("world", 0, 1000), "同种子同流第 %d 次" % i)

	# 不同 seed 应产生不同序列
	var r3 := RngService.new(1)
	var r4 := RngService.new(2)
	var differs := false
	for i in 20:
		if r3.stream_int("world", 0, 1000000) != r4.stream_int("world", 0, 1000000):
			differs = true
	a.is_true(differs, "不同种子产生不同序列")

	# 命名流互不干扰：抽 A 不影响 B 的首个值
	var r5 := RngService.new(7)
	var r6 := RngService.new(7)
	var first_b_5: int = r5.stream("b").randi_range(0, 100000)
	for i in 30:
		r6.stream("a").randf()
	a.eq(r6.stream("b").randi_range(0, 100000), first_b_5, "抽 a 流不影响 b 流")

	# 概率边界
	a.is_false(RngService.new(5).chance("x", 0.0), "概率 0 必失败")
	a.is_true(RngService.new(5).chance("x", 1.0), "概率 1 必成功")

	# stream_pick 边界
	var picker := RngService.new(9)
	a.eq(picker.stream_pick("p", []), null, "空数组返回 null")
	a.eq(picker.stream_pick("p", ["只有一个"]), "只有一个", "单元素数组")

	# 存档恢复随机流：状态可持久化并续跑一致
	var r7 := RngService.new(42)
	for i in 5:
		r7.stream_float("world")
	var snapshot := r7.state_dict()
	var expected: Array = []
	for i in 20:
		expected.append(r7.stream_int("world", 0, 999999))
	# 存档必须经 JSON 字符串端到端往返后仍一致（seed/state 是 int64，未字符串化会在 JSON 里丢精度）
	var r8 := RngService.new(42)
	r8.load_state(JSON.parse_string(JSON.stringify(snapshot)))
	for i in 20:
		a.eq(r8.stream_int("world", 0, 999999), expected[i], "经 JSON 往返后第 %d 次抽取一致" % i)
	# 恢复后新建的命名流必须沿用原 seed，而不是构造时的 seed（否则不同实例读同一存档会分叉）
	var r9 := RngService.new(0)
	r9.load_state(JSON.parse_string(JSON.stringify(snapshot)))
	a.eq(r9.stream_int("new_stream", 0, 999999),
		RngService.new(42).stream_int("new_stream", 0, 999999), "恢复后新流沿用原 seed")

	return a.report("clock")
```

创建 `tests/world_tick_test.gd`：

```gdscript
class_name WorldTickTest
extends RefCounted

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	# 内容表新增项
	a.eq(reg.validate().size(), 0, "新增表后仍无校验错误")
	a.is_true(reg.ids("locations").size() >= 18, "地点表至少 18 项")
	a.is_true(reg.ids("rumors").size() >= 12, "传闻模板至少 12 条")
	a.eq(reg.entry("locations", "forbidden_forest")["danger_label"], "高危险区", "禁林危险度（第四十四章）")
	a.eq(reg.entry("locations", "diagon_alley")["danger_label"], "安全区", "对角巷安全区")
	a.eq(reg.entry("locations", "azkaban")["danger_label"], "高危险区", "阿兹卡班高危险区")
	a.eq(reg.entry("locations", "ministry_of_magic")["danger_label"], "低危险区", "魔法部公开区域低危险")

	# 月度演化：世界继续向前（第四十七章）
	var p := PlayerState.new_default()
	p.name_text = "张三"
	p.bloodline_id = "muggle_born"
	p.birth_identity_id = "ordinary_wizard_family"
	p.sim_style_id = "mixed"
	p.location_id = "london_muggle"
	var w := WorldState.create("modern", p, 20260918, reg)

	var start_year := w.clock.year
	w.clock.advance_months(12)
	a.eq(w.clock.year, start_year + 1, "12 回合 = 1 年")

	for i in 24:
		var events := w.tick()
		a.eq(w.clock.turn, 13 + i, "tick 每次推进一个回合")
		if events.size() > 0:
			a.has_key(events[0], "kind", "事件含 kind")
			a.has_key(events[0], "text", "事件含 text")

	a.eq(w.clock.turn > 0, true, "回合推进")
	a.is_true(w.log.size() > 0, "世界产生日志（第四十三章：传闻与新闻）")

	# 世界变量必须始终落在 [0,1]（第四十九章：阶层与权力流动，不能失控）
	for key in w.world_vars.keys():
		var v := float(w.world_vars[key])
		a.between(v, 0.0, 1.0, "世界变量 %s 在界内" % key)

	# 第六十八章防过度热闹：major 事件必须稀少，且相邻 major 至少相隔 12 个月
	var w2 := WorldState.create("second_wizarding_war", p, 38, reg)
	w2.player.sim_style_id = "epic_wizard_war_typo"   # 未知风格必须被安全处理
	w2.player.location_id = "ministry_of_magic"       # 让 major 候选真的进入候选集，避免断言空转
	var major_count := 0
	var last_major_turn := -1000
	var min_gap := 9999
	for i in 240:
		for e in w2.tick():
			if bool(e.get("major", false)):
				major_count += 1
				min_gap = mini(min_gap, int(e["turn"]) - last_major_turn)
				last_major_turn = int(e["turn"])
	a.is_true(major_count >= 1, "该配置下至少出现一次 major，避免断言空转（实际=%d）" % major_count)
	a.is_true(major_count <= 20, "240 个月内 major 事件不超过 20 次（约 1/12 月上限），实际=%d" % major_count)
	a.is_true(min_gap >= 12, "相邻 major 事件至少相隔 12 个月（实际最小间隔=%d）" % min_gap)

	# 确定性：同种子同世界 → 同演化
	var wa := WorldState.create("modern", PlayerState.new_default(), 777, reg)
	var wb := WorldState.create("modern", PlayerState.new_default(), 777, reg)
	wa.player.sim_style_id = "mixed"
	wb.player.sim_style_id = "mixed"
	wa.player.location_id = "diagon_alley"
	wb.player.location_id = "diagon_alley"
	for i in 10:
		a.eq(wa.tick(), wb.tick(), "第 %d 个月演化完全一致" % i)

	# 信息保护（第四十三章/第五十七章）：低阶身份不得直接获知魔法部内幕
	var w3 := WorldState.create("modern", PlayerState.new_default(), 5, reg)
	w3.player.bloodline_id = "muggle_born"
	w3.player.house_id = "none"
	w3.player.location_id = "ministry_of_magic"   # 让 ministry 类传闻真的进入候选集，避免断言空转
	var leaked := false
	var events_seen := 0
	for i in 40:
		for e in w3.tick():
			events_seen += 1
			if str(e.get("category", "")) == "魔法部内幕":
				leaked = true
	a.is_true(events_seen > 0, "该配置下确实产生了事件（否则信息保护断言空转）")
	a.is_false(leaked, "未入学麻瓜出身者不应收到“魔法部内幕”级信息")

	return a.report("world_tick")
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /e/Hali
sed -i 's|"res://tests/model_test.gd",|"res://tests/model_test.gd",\n\t"res://tests/clock_test.gd",\n\t"res://tests/world_tick_test.gd",|' tests/run_tests.gd
bash tools/test.sh
```

预期：`套件无法加载`（`RngService` 未定义）+ `缺少数据表: locations`。

- [ ] **Step 3: 实现 `RngService`**

创建 `src/core/rng_service.gd`：

```gdscript
class_name RngService
extends RefCounted

var seed_value: int = 0
var _streams: Dictionary = {}

func _init(seed_value_: int = 0) -> void:
	seed_value = seed_value_

func stream(name: String) -> RandomNumberGenerator:
	if not _streams.has(name):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d|%s" % [seed_value, name])
		_streams[name] = rng
	return _streams[name]

func stream_int(name: String, from: int, to: int) -> int:
	return stream(name).randi_range(from, to)

func stream_float(name: String) -> float:
	return stream(name).randf()

func stream_pick(name: String, options: Array):
	if options.is_empty():
		return null
	return options[stream(name).randi_range(0, options.size() - 1)]

func chance(name: String, probability: float) -> bool:
	return stream_float(name) < clampf(probability, 0.0, 1.0)

func state_dict() -> Dictionary:
	# 先物化基础流：保证存档里始终有随机状态可恢复（即使本次回合没有抽过任何随机数）
	stream("world")
	var streams := {}
	for name in _streams.keys():
		var rng: RandomNumberGenerator = _streams[name]
		# seed/state 是 int64，JSON 会把数字解析成 double 而丢精度，因此一律以十进制字符串入档
		streams[name] = {"seed": str(rng.seed), "state": str(rng.state)}
	# seed_value 也必须入档（同样字符串化）：恢复后新建的命名流要用原种子派生
	return {"seed_value": str(seed_value), "streams": streams}

func load_state(d: Dictionary) -> void:
	_streams.clear()   # 恢复语义是“替换”而不是“合并”
	seed_value = int(str(d.get("seed_value", seed_value)))
	var streams: Dictionary = d.get("streams", {})
	for name in streams.keys():
		var entry: Dictionary = streams[name]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(str(entry.get("seed", 0)))
		rng.state = int(str(entry.get("state", 0)))
		_streams[str(name)] = rng
```

- [ ] **Step 4: 写地点与传闻数据表**

创建 `data/locations.json`（第三十三/三十四章、第四十四章区域危险度）：

```json
[
	{"id": "london_muggle", "label": "伦敦（麻瓜世界）", "zone": "muggle", "danger": 1, "danger_label": "低危险区"},
	{"id": "diagon_alley", "label": "对角巷", "zone": "wizarding", "danger": 0, "danger_label": "安全区"},
	{"id": "knockturn_alley", "label": "翻倒巷", "zone": "wizarding", "danger": 3, "danger_label": "高危险区"},
	{"id": "hogsmeade", "label": "霍格莫德", "zone": "wizarding", "danger": 1, "danger_label": "低危险区"},
	{"id": "hogwarts", "label": "霍格沃茨", "zone": "school", "danger": 1, "danger_label": "低危险区"},
	{"id": "forbidden_forest", "label": "禁林", "zone": "wild", "danger": 3, "danger_label": "高危险区"},
	{"id": "chamber_of_secrets", "label": "密室", "zone": "forbidden", "danger": 4, "danger_label": "极度危险区"},
	{"id": "room_of_requirement", "label": "有求必应屋", "zone": "school", "danger": 2, "danger_label": "中等危险区"},
	{"id": "ministry_of_magic", "label": "魔法部", "zone": "wizarding", "danger": 1, "danger_label": "低危险区"},
	{"id": "st_mungos", "label": "圣芒戈魔法伤病医院", "zone": "wizarding", "danger": 0, "danger_label": "安全区"},
	{"id": "gringotts", "label": "古灵阁", "zone": "wizarding", "danger": 2, "danger_label": "中等危险区"},
	{"id": "gringotts_deep_vaults", "label": "古灵阁地下金库", "zone": "forbidden", "danger": 4, "danger_label": "极度危险区"},
	{"id": "azkaban", "label": "阿兹卡班", "zone": "forbidden", "danger": 3, "danger_label": "高危险区"},
	{"id": "godrics_hollow", "label": "戈德里克山谷", "zone": "wizarding", "danger": 1, "danger_label": "低危险区"},
	{"id": "spinners_end", "label": "蜘蛛尾巷", "zone": "muggle", "danger": 2, "danger_label": "中等危险区"},
	{"id": "the_burrow", "label": "陋居", "zone": "wizarding", "danger": 0, "danger_label": "安全区"},
	{"id": "malfoy_manor", "label": "马尔福庄园", "zone": "wizarding", "danger": 2, "danger_label": "中等危险区"},
	{"id": "grimmauld_place", "label": "格里莫广场12号", "zone": "wizarding", "danger": 1, "danger_label": "低危险区"},
	{"id": "beauxbatons", "label": "布斯巴顿（法国）", "zone": "school", "danger": 1, "danger_label": "低危险区"},
	{"id": "durmstrang", "label": "德姆斯特朗（北欧）", "zone": "school", "danger": 2, "danger_label": "中等危险区"},
	{"id": "ilvermorny", "label": "伊法魔尼（美国）", "zone": "school", "danger": 1, "danger_label": "低危险区"}
]
```

创建 `data/rumors.json`（第四十七章的六类动态 + 第四十三章可信度；`major` 事件受第六十八章约束；`zones`/`min_year`/`requires_flags` 实现信息保护）：

```json
[
	{"id": "ministry_election", "label": "魔法部改选", "category": "魔法部动态", "text": "魔法部又要改选了，部长位置据说有三位竞争者。", "weight": 10, "major": false, "min_year": 1692, "zones": ["diagon_alley", "ministry_of_magic", "hogsmeade"], "requires_flags": []},
	{"id": "ministry_internal", "label": "魔法部内幕", "category": "魔法部内幕", "text": "有司长在威森加摩的走廊里被拦下问话，具体原因没人肯说。", "weight": 4, "major": false, "min_year": 1692, "zones": ["ministry_of_magic"], "requires_flags": ["ministry_access"]},
	{"id": "war_rumor", "label": "北方失踪", "category": "战争", "text": "北方又有人失踪了，预言家日报只用了三行字。", "weight": 8, "major": false, "min_year": 1970, "zones": ["diagon_alley", "hogsmeade", "knockturn_alley"], "requires_flags": []},
	{"id": "wizard_life", "label": "破釜酒吧新酒", "category": "巫师", "text": "破釜酒吧的老板换了新蜂蜜酒，老主顾们争论了整整一晚。", "weight": 14, "major": false, "min_year": 990, "zones": ["diagon_alley", "hogsmeade", "the_burrow", "godrics_hollow"], "requires_flags": []},
	{"id": "creature_activity", "label": "马人驱赶学生", "category": "神奇生物", "text": "禁林边缘的马人最近驱赶了几个闯进林子的学生。", "weight": 10, "major": false, "min_year": 990, "zones": ["hogwarts", "forbidden_forest", "hogsmeade"], "requires_flags": []},
	{"id": "creature_dragon", "label": "龙越界", "category": "神奇生物", "text": "龙类保护区报告有一条龙越过了界线，罗马尼亚那边正在追踪。", "weight": 3, "major": false, "min_year": 990, "zones": ["diagon_alley", "ministry_of_magic", "knockturn_alley"], "requires_flags": []},
	{"id": "economy_price", "label": "魔药材料涨价", "category": "经济", "text": "魔药材料涨价了，曼德拉草尤其贵，几家魔药店已经开始限购。", "weight": 12, "major": false, "min_year": 990, "zones": ["diagon_alley", "knockturn_alley", "hogsmeade"], "requires_flags": []},
	{"id": "economy_wand", "label": "魔杖木材短缺", "category": "经济", "text": "魔杖木材运输受阻，奥利凡德店里的交货期又长了半个月。", "weight": 8, "major": false, "min_year": 990, "zones": ["diagon_alley"], "requires_flags": []},
	{"id": "international", "label": "国际巫师联合会会议", "category": "国际", "text": "国际巫师联合会就某国的保密法执行问题又开了一次没有结论的会。", "weight": 6, "major": false, "min_year": 1692, "zones": ["ministry_of_magic", "diagon_alley"], "requires_flags": []},
	{"id": "quidditch", "label": "魁地奇转会", "category": "巫师", "text": "魁地奇联赛换季，几家俱乐部的转会消息占据了报纸的半个版面。", "weight": 12, "major": false, "min_year": 990, "zones": ["diagon_alley", "hogsmeade", "hogwarts", "the_burrow"], "requires_flags": []},
	{"id": "school_term", "label": "霍格沃茨开学", "category": "巫师", "text": "霍格沃茨开学了，对角巷挤满了买书和买坩埚的学生。", "weight": 14, "major": false, "min_year": 990, "zones": ["hogwarts", "diagon_alley", "hogsmeade"], "requires_flags": []},
	{"id": "daily_life", "label": "平静日常", "category": "巫师", "text": "没什么大事。有人在魔法广播里抱怨天气，有人在家给猫头鹰换窝。", "weight": 20, "major": false, "min_year": 990, "zones": ["london_muggle", "spinners_end", "the_burrow", "godrics_hollow", "grimmauld_place", "st_mungos", "gringotts", "room_of_requirement", "beauxbatons", "durmstrang", "ilvermorny", "malfoy_manor"], "requires_flags": []},
	{"id": "major_azkaban_break", "label": "阿兹卡班越狱", "category": "战争", "text": "阿兹卡班发生了大规模越狱，魔法部承认这是一次严重的失败。", "weight": 1, "major": true, "min_year": 1692, "zones": ["diagon_alley", "ministry_of_magic", "knockturn_alley", "azkaban"], "requires_flags": []},
	{"id": "major_ministry_coup", "label": "魔法部政变传闻", "category": "战争", "text": "有消息说魔法部内部正在发生政变，几个司的入口被封锁了。", "weight": 1, "major": true, "min_year": 1692, "zones": ["ministry_of_magic", "diagon_alley"], "requires_flags": []},
	{"id": "major_gringotts_crisis", "label": "古灵阁停摆", "category": "经济", "text": "古灵阁宣布暂停部分金库业务，恐慌在纯血家族之间蔓延。", "weight": 1, "major": true, "min_year": 990, "zones": ["gringotts", "diagon_alley", "knockturn_alley"], "requires_flags": []},
	{"id": "major_hogwarts_occupied", "label": "霍格沃茨异变", "category": "战争", "text": "霍格沃茨上空笼罩着不寻常的沉默，猫头鹰邮件停了两天。", "weight": 1, "major": true, "min_year": 1970, "zones": ["hogwarts", "hogsmeade"], "requires_flags": []}
]
```

- [ ] **Step 5: 追加数据表到注册表**

修改 `src/core/registry.gd` 的 `TABLE_FILES`：

```gdscript
const TABLE_FILES: Dictionary = {
	"eras": "eras.json",
	"bloodlines": "bloodlines.json",
	"birth_identities": "birth_identities.json",
	"aptitudes": "aptitudes.json",
	"houses": "houses.json",
	"sim_styles": "sim_styles.json",
	"political_leanings": "political_leanings.json",
	"locations": "locations.json",
	"rumors": "rumors.json",
}
```

- [ ] **Step 6: 实现 `WorldState.tick()`**

在 `src/model/world_state.gd` 中，`add_fact()` 之后追加：

```gdscript
const VARS_REGRESSION := 0.05     # 每月向时代基线回归的比例
const MAJOR_EVENT_GAP := 12       # 第六十八章：重大事件之间至少相隔 12 个月
const RECENT_LOG_LIMIT := 200

func sim_style() -> Dictionary:
	var style := registry.entry("sim_styles", player.sim_style_id)
	if style.is_empty():
		style = registry.entry("sim_styles", "mixed")
	return style

func _era_baseline() -> Dictionary:
	var era_entry := era()
	var baseline: Dictionary = era_entry.get("world_vars", {})
	if baseline.is_empty():
		return {"war_pressure": 0.2, "ministry_stability": 0.6, "corruption": 0.3,
			"pureblood_influence": 0.3, "muggle_relations": 0.5,
			"economy_index": 0.6, "secrecy_integrity": 0.8}
	return baseline

# 第四十七章：每个回合（一个月）系统自动结算本月世界动态。
# 玩家不参与，世界照样发展。
func tick() -> Array:
	var events: Array = []
	clock.advance_month()
	# per-turn 语义（第五十五条·魔法体系漏洞保护 / HANDOFF §8 第 27 条裁定）：低阶咒语叠加计数每回合（月）重置；
	# time_rewind_count 为终身一次性，故意不在此重置。
	flags.erase("energy_loop_count")

	# 1) 世界变量向时代基线缓慢回归，并带轻微扰动（第六十四章：权力与秩序是流动的）
	var baseline := _era_baseline()
	var drift_rng := RngService.new(game_seed + clock.turn * 7919)
	for key in world_vars.keys():
		var target := float(baseline.get(key, world_vars[key]))
		var current := float(world_vars[key])
		var noise := drift_rng.stream_float("drift_%s" % key) * 0.04 - 0.02
		world_vars[key] = clampf(current + (target - current) * VARS_REGRESSION + noise, 0.0, 1.0)

	# 2) 本月区级动态：按玩家所在地与身份筛出可得信息（第四十三章：信息由身份、地点、人脉决定）
	var candidates: Array = []
	var last_major_turn := int(flags.get("last_major_turn", -MAJOR_EVENT_GAP))
	var major_ready := (clock.turn - last_major_turn) >= MAJOR_EVENT_GAP
	for rumor_id in registry.ids("rumors"):
		var rumor := registry.entry("rumors", rumor_id)
		if clock.year < int(rumor.get("min_year", 0)):
			continue
		var zones: Array = rumor.get("zones", [])
		if not zones.is_empty() and not zones.has(player.location_id):
			continue
		var ok_flags := true
		for required in rumor.get("requires_flags", []):
			if not flags.has(required):
				ok_flags = false
		if not ok_flags:
			continue
		if bool(rumor.get("major", false)) and not major_ready:
			continue
		candidates.append(rumor)

	var month_rng := RngService.new(game_seed + clock.turn * 104729)
	if not candidates.is_empty():
		var style := sim_style()
		var intensity := clampf(float(style.get("event_intensity", 0.5)), 0.0, 1.0)
		var mundane := clampf(float(style.get("mundane_ratio", 0.7)), 0.0, 1.0)
		var rumor_count := 1
		if month_rng.chance("extra_rumor", 0.35 * intensity):
			rumor_count = 2
		for i in rumor_count:
			var picked: Dictionary = month_rng.stream_pick("pick_%d" % i, candidates)
			if picked.is_empty():
				continue
			var is_major := bool(picked.get("major", false))
			# 只有真正掷中重大事件概率时才落地（第六十八章防过度热闹）
			if is_major:
				var prob := 0.15 * intensity * (1.0 - mundane * 0.5)
				if not month_rng.chance("major_gate", prob):
					continue
				flags["last_major_turn"] = clock.turn
			var ev := {
				"kind": "rumor",
				"category": str(picked.get("category", "")),
				"text": str(picked.get("text", "")),
				"major": is_major,
				"turn": clock.turn,
			}
			events.append(ev)
			log.append(ev)
			if is_major:
				add_fact("major", str(picked.get("text", "")))
				break   # 同月最多一起重大事件，保证 MAJOR_EVENT_GAP 成立

	# 3) 生活基线：日常必须大量存在（第六十八章），世界不会每个月都在打仗
	var style_now := sim_style()
	var mundane_ratio := clampf(float(style_now.get("mundane_ratio", 0.7)), 0.0, 1.0)
	if month_rng.chance("mundane_day", 0.5 + mundane_ratio * 0.4):
		log.append({"turn": clock.turn, "kind": "mundane",
			"text": "%s，日子照常过。" % clock.formatted()})

	# 4) 年龄推进（玩家与世界同时变老）
	player.age_months += 1

	# 5) 日志裁剪，避免存档无限膨胀
	while log.size() > RECENT_LOG_LIMIT:
		log.pop_front()

	return events
```

- [ ] **Step 7: 运行测试，确认通过**

```bash
cd /e/Hali
bash tools/test.sh
```

预期：`[clock] 失败=0`、`[world_tick] 失败=0`、`全部通过。`

如果 `major 事件超过 20 次` 断言失败：说明 `MAJOR_EVENT_GAP` 与 `major_gate` 双闸门未生效，检查 `flags["last_major_turn"]` 是否在 `tick()` 中被写入（`WorldState.flags` 是持久字段，不要写进 `world_vars`）。

- [ ] **Step 8: 提交**

```bash
cd /e/Hali
git add src/core/rng_service.gd src/model/world_state.gd src/core/registry.gd data/locations.json data/rumors.json tests/clock_test.gd tests/world_tick_test.gd tests/run_tests.gd
git commit -m "feat(world): 确定性随机与月度世界演化"
```

---

### Task 6: 角色创建流水线

**Files:**
- Create: `src/rules/character_creation.gd`
- Create: `data/skills.json`
- Create: `data/wand_woods.json`、`data/wand_cores.json`、`data/wand_flexibilities.json`、`data/wand_lengths.json`
- Modify: `src/core/registry.gd`（`TABLE_FILES` 追加 `skills`、`wand_woods`、`wand_cores`、`wand_flexibilities`、`wand_lengths`）
- Create: `tests/creation_test.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `Registry`、`PlayerState`、`WorldState`、`RngService`、`Money`、`MagicLevel`
- Produces:
  - `CharacterCreation`（`extends RefCounted`）
    - `class Result: var player: PlayerState; var errors: PackedStringArray`
    - `static validate_choices(choices: Dictionary, registry: Registry) -> PackedStringArray`
    - `static create(choices: Dictionary, registry: Registry, rng: RngService) -> Result`
    - `static default_skills_for(choices: Dictionary, registry: Registry) -> Dictionary`
    - `static generate_wand(rng: RngService, registry: Registry) -> Dictionary`
    - `static assign_house(choices: Dictionary, rng: RngService, registry: Registry) -> String`
  - `choices` 字典键（对应第七十五章启动界面）：
    `era_id, bloodline_id, birth_identity_id, name_text, gender, age_years, birthplace, family_status, aptitude_id, aptitude_special, wand (可空), house_id, political_leaning_id, personality (Array[String] 3 项), life_goal, sim_style_id`
  - `wand` 字典：`{"wood":String,"core":String,"length_inches":float,"flexibility":String,"label":String}`
  - `data/skills.json`：`id,label,category,note`
  - `data/wand_woods.json` / `data/wand_cores.json` / `data/wand_flexibilities.json` / `data/wand_lengths.json`：都是**数组表**（元素含 `id`/`label`；杖芯带 `rarity`，长度带 `inches`）。
    注册表只接受数组表，所以魔杖内容不能用单个对象文件。

- [ ] **Step 1: 写失败测试**

创建 `tests/creation_test.gd`：

```gdscript
class_name CreationTest
extends RefCounted

func base_choices() -> Dictionary:
	return {
		"era_id": "modern",
		"bloodline_id": "muggle_born",
		"birth_identity_id": "ordinary_wizard_family",
		"name_text": "张三",
		"gender": "男",
		"age_years": 11,
		"birthplace": "london_muggle",
		"family_status": "父母均为麻瓜，家中无人相信魔法",
		"aptitude_id": "normal",
		"aptitude_special": "",
		"wand": {},
		"house_id": "system",
		"political_leaning_id": "free_independent",
		"personality": ["好奇", "固执", "怕黑"],
		"life_goal": "我想知道魔法到底能走多远",
		"sim_style_id": "mixed",
	}

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	# 内容表新增项
	a.eq(reg.validate().size(), 0, "技能与魔杖表加入后仍无校验错误")
	a.is_true(reg.ids("skills").size() >= 19, "技能表至少 19 项")
	a.is_true(reg.ids("wand_lengths").size() >= 10, "魔杖长度档位充足")
	a.is_true(reg.ids("wand_cores").size() >= 6, "杖芯至少 6 种")
	a.is_true(reg.ids("wand_woods").size() >= 10, "木材至少 10 种")

	# 血统/身份里的 skill_bias 必须全部指向真实技能（跨表完整性）
	for bloodline_id in reg.ids("bloodlines"):
		for skill_id in reg.entry("bloodlines", bloodline_id).get("skill_bias", {}).keys():
			a.is_true(reg.has("skills", skill_id), "血统 %s 引用了未定义技能 %s" % [bloodline_id, skill_id])
	for identity_id in reg.ids("birth_identities"):
		for skill_id in reg.entry("birth_identities", identity_id).get("skill_bias", {}).keys():
			a.is_true(reg.has("skills", skill_id), "身份 %s 引用了未定义技能 %s" % [identity_id, skill_id])

	# ---- 合法创建 ----
	var rng := RngService.new(20260918)
	var result := CharacterCreation.create(base_choices(), reg, rng)
	a.eq(result.errors.size(), 0, "合法选择不应报错")
	var p := result.player
	a.eq(p.name_text, "张三", "姓名")
	a.eq(p.age_months, 132, "11 岁 = 132 个月")
	a.eq(p.money().formatted(), "10加隆 0西可 0纳特", "普通巫师家庭起始财产（第十八章自洽）")
	a.eq(p.sim_style_id, "mixed", "模拟风格")
	a.is_true(p.skill("muggle_world") >= 2, "麻瓜出身带来麻瓜世界见闻")
	a.is_true(p.skill("charms") >= 1, "普通巫师家庭带来魔咒基础")
	a.eq(p.personality.size(), 3, "三个性格关键词")
	a.is_true(p.wand.has("wood"), "生成魔杖木材")
	a.is_true(p.wand.has("label"), "魔杖有可读标签")
	a.eq(p.magic["known_spells"].size(), 0, "入学前不掌握咒语（第六十九章防主角光环）")
	a.is_true(p.alive, "活着")
	a.eq(p.location_id, "london_muggle", "出生地")

	# 魔杖长度必须来自内容表
	var length_ids := reg.ids("wand_lengths")
	a.is_true(length_ids.has(str(p.wand["length_inches"]).trim_suffix(".0")), "魔杖长度取自内容表")

	# ---- 确定性：同种子同选择 → 完全相同 ----
	var p_a := CharacterCreation.create(base_choices(), reg, RngService.new(99)).player
	var p_b := CharacterCreation.create(base_choices(), reg, RngService.new(99)).player
	a.eq(p_a.to_dict(), p_b.to_dict(), "同种子创建结果完全一致")

	# ---- 哑炮：无魔法，且不能有咒语/魔杖 ----
	var squib := base_choices()
	squib["bloodline_id"] = "squib"
	squib["aptitude_id"] = "squib"
	var squib_result := CharacterCreation.create(squib, reg, RngService.new(1))
	a.eq(squib_result.errors.size(), 0, "哑炮可以创建")
	a.eq(squib_result.player.magic_tier, MagicLevel.Tier.SQUIB, "哑炮等级")
	a.eq(squib_result.player.wand, {}, "哑炮没有魔杖")
	a.is_true(squib_result.player.magic["known_spells"].is_empty(), "哑炮没有咒语")
	a.is_true(squib_result.player.flags.has("no_magic"), "哑炮带 no_magic 标记")

	# ---- 血统与资质冲突必须报错，而不是静默修正（第七十五章：哑炮无魔法天赋） ----
	var conflict := base_choices()
	conflict["bloodline_id"] = "squib"
	conflict["aptitude_id"] = "excellent"
	var conflict_errors := CharacterCreation.validate_choices(conflict, reg)
	a.is_true(" | ".join(conflict_errors).contains("哑炮"), "哑炮血统与非哑炮资质冲突必须报错")

	# ---- 反漏洞：未选特殊资质时不得注入特殊天赋标记 ----
	var exploit := base_choices()
	exploit["aptitude_special"] = "parselmouth"
	var exploit_result := CharacterCreation.create(exploit, reg, RngService.new(11))
	a.is_true(exploit_result.errors.size() > 0, "非特殊资质携带 aptitude_special 必须被拒绝")
	a.is_true(exploit_result.player == null, "校验失败时不产出玩家")

	# ---- 出生地必须是合法地点 id（否则世界演化会静默过滤传闻） ----
	var bad_place := base_choices()
	bad_place["birthplace"] = "不存在的出生地"
	a.is_true(" | ".join(CharacterCreation.validate_choices(bad_place, reg)).contains("birthplace"), "非法出生地必须报错")

	# ---- 非法输入逐个报错 ----
	var bad := base_choices()
	bad["era_id"] = "不存在的时代"
	bad["bloodline_id"] = "不存在的血统"
	bad["age_years"] = 3
	bad["personality"] = ["只有一个"]
	bad["life_goal"] = ""
	var errs := CharacterCreation.validate_choices(bad, reg)
	var joined := " | ".join(errs)
	a.is_true(joined.contains("era_id"), "时代非法")
	a.is_true(joined.contains("bloodline_id"), "血统非法")
	a.is_true(joined.contains("age_years"), "年龄低于 11 必须报错")
	a.is_true(joined.contains("personality"), "性格不足 3 项")
	a.is_true(joined.contains("life_goal"), "目标为空")
	var empty_kw := base_choices()
	empty_kw["personality"] = ["", "好奇", "固执"]
	a.is_true(" | ".join(CharacterCreation.validate_choices(empty_kw, reg)).contains("personality"), "空性格关键词必须报错")

	# ---- 特殊资质必须指明具体天赋 ----
	var special := base_choices()
	special["aptitude_id"] = "special"
	special["aptitude_special"] = "parselmouth"
	var sp := CharacterCreation.create(special, reg, RngService.new(3))
	a.eq(sp.errors.size(), 0, "特殊资质带具体天赋")
	a.eq(sp.player.aptitude_special, "parselmouth", "记录蛇佬腔")
	a.is_true(sp.player.flags.has("parselmouth"), "蛇佬腔写入标记")
	special["aptitude_special"] = "不存在的天赋"
	a.is_true(" | ".join(CharacterCreation.validate_choices(special, reg)).contains("aptitude_special"), "非法天赋报错")

	# ---- 随机资质必须被掷定，且不能掷出哑炮（玩家没选哑炮血统） ----
	var rand_apt := base_choices()
	rand_apt["aptitude_id"] = "random"
	for i in 30:
		var r := CharacterCreation.create(rand_apt, reg, RngService.new(1000 + i))
		a.ne(r.player.aptitude_id, "squib", "随机资质不得变成哑炮")
		a.ne(r.player.aptitude_id, "random", "随机资质必须被解析")
		a.ne(r.player.aptitude_id, "special", "随机资质不得掷出未指定天赋的特殊资质")

	# ---- 学院判定 ----
	var sly := base_choices()
	sly["bloodline_id"] = "sacred_twenty_eight"
	sly["house_id"] = "system"
	sly["personality"] = ["野心", "精明", "算计"]
	var sly_house := CharacterCreation.assign_house(sly, RngService.new(7), reg)
	a.eq(sly_house, "slytherin", "血统偏置 + 性格匹配判定出斯莱特林")
	var forced := base_choices()
	forced["house_id"] = "ravenclaw"
	a.eq(CharacterCreation.assign_house(forced, RngService.new(7), reg), "ravenclaw", "玩家指定学院优先")
	var unschooled := base_choices()
	unschooled["house_id"] = "none"
	a.eq(CharacterCreation.assign_house(unschooled, RngService.new(7), reg), "none", "未入学不判学院")
	var squib_house := base_choices()
	squib_house["bloodline_id"] = "squib"
	squib_house["aptitude_id"] = "squib"
	a.eq(CharacterCreation.assign_house(squib_house, RngService.new(7), reg), "none", "哑炮不判学院")

	# ---- 全部 12 血统都能创建成功（内容全覆盖） ----
	for bloodline_id in reg.ids("bloodlines"):
		var c := base_choices()
		c["bloodline_id"] = bloodline_id
		if bloodline_id == "squib":
			c["aptitude_id"] = "squib"
		var r := CharacterCreation.create(c, reg, RngService.new(42))
		a.eq(r.errors.size(), 0, "血统 %s 可创建" % bloodline_id)

	return a.report("creation")
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /e/Hali
sed -i 's|"res://tests/world_tick_test.gd",|"res://tests/world_tick_test.gd",\n\t"res://tests/creation_test.gd",|' tests/run_tests.gd
bash tools/test.sh
```

预期：`套件无法加载`（`CharacterCreation` 未定义）+ `缺少数据表: skills`。

- [ ] **Step 3: 写技能与魔杖数据表**

创建 `data/skills.json`：

```json
[
	{"id": "charms", "label": "魔咒学", "category": "学术", "note": "悬浮、开锁、照明等基础魔咒"},
	{"id": "transfiguration", "label": "变形术", "category": "学术", "note": "物体变形、活物变形、消失术、显形术"},
	{"id": "potions", "label": "魔药学", "category": "学术", "note": "精确科学与艺术的结合"},
	{"id": "herbology", "label": "草药学", "category": "学术", "note": "魔药材料与神奇植物"},
	{"id": "dada", "label": "黑魔法防御术", "category": "学术", "note": "缴械、铁甲、守护神"},
	{"id": "history_of_magic", "label": "魔法史", "category": "学术", "note": "原著历史事件与家族谱系"},
	{"id": "astronomy", "label": "天文学", "category": "学术", "note": "天象与季节"},
	{"id": "divination", "label": "占卜术", "category": "学术", "note": "预言可能成真，也可能被误解"},
	{"id": "ancient_runes", "label": "古代魔文", "category": "学术", "note": "古代巫师掌握现代无法复现的魔法"},
	{"id": "care_of_magical_creatures", "label": "神奇生物照料", "category": "学术", "note": "栖息地、领地、行为规律"},
	{"id": "wand_lore", "label": "魔杖学", "category": "工艺", "note": "木材、杖芯、长度、弹性"},
	{"id": "healing", "label": "治疗术", "category": "工艺", "note": "黑魔法伤害与咬伤处理"},
	{"id": "household_magic", "label": "家务魔法", "category": "工艺", "note": "家养小精灵传统魔法"},
	{"id": "quidditch", "label": "魁地奇", "category": "体能", "note": "学院队、俱乐部、国家队"},
	{"id": "stealth", "label": "潜行", "category": "体能", "note": "傲罗追踪术的反面"},
	{"id": "social", "label": "社交口才", "category": "社会", "note": "酒馆、政治密谈、招募"},
	{"id": "deception", "label": "伪装与谎言", "category": "社会", "note": "假身份、混入、误导"},
	{"id": "muggle_world", "label": "麻瓜世界见闻", "category": "社会", "note": "街道、电话亭、地铁、科技"},
	{"id": "black_market", "label": "黑市人脉", "category": "社会", "note": "翻倒巷的博金-博克店与地下拍卖会"}
]
```

创建四张魔杖数组表（第十七章魔杖系统；「魔杖选择巫师」）。注册表 `from_tables` 只接受**数组表**，所以魔杖内容必须拆成四张表，而不是一个对象文件：

```json
// data/wand_lengths.json —— 长度是数值档位，用 id 承载英寸值
[
	{"id": "9", "label": "9英寸", "inches": 9.0},
	{"id": "9.5", "label": "9.5英寸", "inches": 9.5},
	{"id": "10", "label": "10英寸", "inches": 10.0},
	{"id": "10.25", "label": "10.25英寸", "inches": 10.25},
	{"id": "10.75", "label": "10.75英寸", "inches": 10.75},
	{"id": "11", "label": "11英寸", "inches": 11.0},
	{"id": "11.5", "label": "11.5英寸", "inches": 11.5},
	{"id": "12", "label": "12英寸", "inches": 12.0},
	{"id": "12.75", "label": "12.75英寸", "inches": 12.75},
	{"id": "13", "label": "13英寸", "inches": 13.0},
	{"id": "13.5", "label": "13.5英寸", "inches": 13.5},
	{"id": "14", "label": "14英寸", "inches": 14.0},
	{"id": "15", "label": "15英寸", "inches": 15.0}
]
```

`data/wand_woods.json`：

```json
[
	{"id": "holly", "label": "冬青木"},
	{"id": "yew", "label": "紫杉木"},
	{"id": "hawthorn", "label": "山楂木"},
	{"id": "willow", "label": "柳木"},
	{"id": "oak", "label": "橡木"},
	{"id": "beech", "label": "山毛榉"},
	{"id": "mahogany", "label": "桃花心木"},
	{"id": "cherry", "label": "樱桃木"},
	{"id": "blackthorn", "label": "黑刺李木"},
	{"id": "elm", "label": "榆木"},
	{"id": "vine", "label": "葡萄藤木"},
	{"id": "walnut", "label": "胡桃木"},
	{"id": "ash", "label": "白蜡木"},
	{"id": "larch", "label": "落叶松木"},
	{"id": "fir", "label": "冷杉木"},
	{"id": "alder", "label": "桤木"}
]
```

`data/wand_cores.json`：

```json
[
	{"id": "unicorn_hair", "label": "独角兽尾毛", "rarity": "common"},
	{"id": "dragon_heartstring", "label": "龙心弦", "rarity": "common"},
	{"id": "phoenix_feather", "label": "凤凰羽毛", "rarity": "rare"},
	{"id": "thestral_tail_hair", "label": "夜骐尾羽", "rarity": "rare"},
	{"id": "veela_hair", "label": "媚娃头发", "rarity": "rare"},
	{"id": "troll_whisker", "label": "巨怪胡须", "rarity": "common"}
]
```

`data/wand_flexibilities.json`：

```json
[
	{"id": "very_flexible", "label": "非常柔韧"},
	{"id": "flexible", "label": "柔韧"},
	{"id": "springy", "label": "有弹性"},
	{"id": "supple", "label": "易弯曲"},
	{"id": "rigid", "label": "坚硬"},
	{"id": "unbending", "label": "不易弯曲"}
]
```

同时把测试里那两行魔杖断言改为：

```gdscript
	a.is_true(reg.ids("wand_lengths").size() >= 10, "魔杖长度档位充足")
	a.is_true(reg.ids("wand_cores").size() >= 6, "杖芯至少 6 种")
```

并在 `src/core/registry.gd` 的 `TABLE_FILES` 追加：

```gdscript
	"skills": "skills.json",
	"wand_woods": "wand_woods.json",
	"wand_cores": "wand_cores.json",
	"wand_flexibilities": "wand_flexibilities.json",
	"wand_lengths": "wand_lengths.json",
```

- [ ] **Step 4: 实现 `CharacterCreation`**

创建 `src/rules/character_creation.gd`：

```gdscript
class_name CharacterCreation
extends RefCounted

const MIN_AGE_YEARS := 11
const MAX_AGE_YEARS := 80
const HOUSE_TENDENCY := {
	"slytherin": ["野心", "精明", "血统", "意志", "算计", "权力"],
	"gryffindor": ["勇气", "胆识", "冲动", "正义", "鲁莽"],
	"ravenclaw": ["好奇", "智慧", "知识", "钻研", "冷静"],
	"hufflepuff": ["忠诚", "勤勉", "公平", "坚韧", "善良"],
}
const BLOODLINE_HOUSE_BIAS := {
	"sacred_twenty_eight": "slytherin",
	"pureblood_cadet": "slytherin",
	"muggle_born": "gryffindor",
	"werewolf": "gryffindor",
	"part_veela": "ravenclaw",
}

class Result:
	var player: PlayerState = null
	var errors: PackedStringArray = PackedStringArray()

static func validate_choices(choices: Dictionary, registry: Registry) -> PackedStringArray:
	var errors := PackedStringArray()
	var era_id := str(choices.get("era_id", ""))
	if not registry.has("eras", era_id):
		errors.append("era_id 非法: %s" % era_id)
	var bloodline_id := str(choices.get("bloodline_id", ""))
	if not registry.has("bloodlines", bloodline_id):
		errors.append("bloodline_id 非法: %s" % bloodline_id)
	if not registry.has("birth_identities", str(choices.get("birth_identity_id", ""))):
		errors.append("birth_identity_id 非法: %s" % str(choices.get("birth_identity_id", "")))
	if not registry.has("houses", str(choices.get("house_id", "system"))):
		errors.append("house_id 非法: %s" % str(choices.get("house_id", "")))
	if not registry.has("sim_styles", str(choices.get("sim_style_id", "mixed"))):
		errors.append("sim_style_id 非法: %s" % str(choices.get("sim_style_id", "")))
	if not registry.has("political_leanings", str(choices.get("political_leaning_id", "free_independent"))):
		errors.append("political_leaning_id 非法: %s" % str(choices.get("political_leaning_id", "")))

	if str(choices.get("name_text", "")).strip_edges().is_empty():
		errors.append("name_text 不得为空")

	var age_years := int(choices.get("age_years", 0))
	if age_years < MIN_AGE_YEARS or age_years > MAX_AGE_YEARS:
		errors.append("age_years 必须在 %d–%d 之间，实际 %d" % [MIN_AGE_YEARS, MAX_AGE_YEARS, age_years])

	var birthplace := str(choices.get("birthplace", ""))
	if not registry.has("locations", birthplace):
		errors.append("birthplace 非法: %s" % birthplace)

	var personality: Array = choices.get("personality", [])
	if personality.size() < 3:
		errors.append("personality 需要 3 个性格关键词，实际 %d 个" % personality.size())
	for keyword in personality:
		if str(keyword).strip_edges().is_empty():
			errors.append("personality 关键词不得为空")
	if str(choices.get("life_goal", "")).strip_edges().is_empty():
		errors.append("life_goal 不得为空")

	# 血统与资质必须自洽（哑炮血统 = 无魔法；有魔法血统 ≠ 哑炮资质）
	var aptitude_id := str(choices.get("aptitude_id", "normal"))
	if not registry.has("aptitudes", aptitude_id):
		errors.append("aptitude_id 非法: %s" % aptitude_id)
	var bloodline: Dictionary = registry.entry("bloodlines", bloodline_id)
	var bloodline_has_magic := bool(bloodline.get("magic_aptitude", true))
	if bloodline_id == "squib" and aptitude_id != "squib":
		errors.append("哑炮血统无法拥有魔法资质（当前 aptitude_id=%s）；请把 aptitude_id 设为 squib" % aptitude_id)
	if bloodline_has_magic and aptitude_id == "squib":
		errors.append("血统 %s 拥有魔法天赋，不能选择哑炮资质" % bloodline_id)

	if aptitude_id == "special":
		var allowed := []
		for option in (registry.entry("aptitudes", "special").get("special_options", []) as Array):
			allowed.append(str(option))
		var chosen := str(choices.get("aptitude_special", ""))
		if not allowed.has(chosen):
			errors.append("aptitude_special 非法: %s，允许值 %s" % [chosen, ", ".join(allowed)])
	elif not str(choices.get("aptitude_special", "")).is_empty():
		errors.append("aptitude_special 只有 aptitude_id=special 时才能设置: %s" % str(choices.get("aptitude_special", "")))

	var wand_choice: Dictionary = choices.get("wand", {})
	if not wand_choice.is_empty():
		if not registry.has("wand_woods", str(wand_choice.get("wood", ""))):
			errors.append("魔杖木材非法: %s" % str(wand_choice.get("wood", "")))
		if not registry.has("wand_cores", str(wand_choice.get("core", ""))):
			errors.append("魔杖杖芯非法: %s" % str(wand_choice.get("core", "")))
		if not registry.has("wand_flexibilities", str(wand_choice.get("flexibility", ""))):
			errors.append("魔杖弹性非法: %s" % str(wand_choice.get("flexibility", "")))
	return errors

static func default_skills_for(choices: Dictionary, registry: Registry) -> Dictionary:
	var skills := {}
	var pairs := [["bloodlines", "bloodline_id"], ["birth_identities", "birth_identity_id"]]
	for pair in pairs:
		var entry: Dictionary = registry.entry(str(pair[0]), str(choices.get(str(pair[1]), "")))
		var bias: Dictionary = entry.get("skill_bias", {})
		for skill_id in bias.keys():
			skills[str(skill_id)] = int(skills.get(str(skill_id), 0)) + int(bias[skill_id])
	return skills

static func generate_wand(rng: RngService, registry: Registry) -> Dictionary:
	var wood: String = str(rng.stream_pick("wand_wood", registry.ids("wand_woods").duplicate()))
	var wood_entry: Dictionary = registry.entry("wand_woods", str(wood))
	var core_ids := registry.ids("wand_cores").duplicate()
	var core_id := str(rng.stream_pick("wand_core", core_ids))
	var core_entry: Dictionary = registry.entry("wand_cores", core_id)
	var flex_ids := registry.ids("wand_flexibilities").duplicate()
	var flex_id := str(rng.stream_pick("wand_flex", flex_ids))
	var length_ids := registry.ids("wand_lengths").duplicate()
	var length_id := str(rng.stream_pick("wand_length", length_ids))
	var length_entry: Dictionary = registry.entry("wand_lengths", length_id)
	var inches := float(length_entry.get("inches", 11.0))
	return {
		"wood": str(wood),
		"core": core_id,
		"length_inches": inches,
		"flexibility": flex_id,
		"label": "%s，%s，%.2f英寸，%s" % [
			str(wood_entry.get("label", wood)),
			str(core_entry.get("label", core_id)),
			inches,
			str(registry.entry("wand_flexibilities", flex_id).get("label", flex_id)),
		],
	}

static func assign_house(choices: Dictionary, rng: RngService, registry: Registry) -> String:
	var requested := str(choices.get("house_id", "system"))
	if requested != "system":
		return requested
	var bloodline_id := str(choices.get("bloodline_id", ""))
	var bloodline: Dictionary = registry.entry("bloodlines", bloodline_id)
	var age_years := int(choices.get("age_years", 11))
	if not bool(bloodline.get("magic_aptitude", true)) or age_years < 11:
		return "none"
	var scores := {"gryffindor": 1.0, "slytherin": 1.0, "ravenclaw": 1.0, "hufflepuff": 1.0}
	var bias := str(BLOODLINE_HOUSE_BIAS.get(bloodline_id, ""))
	if not bias.is_empty():
		scores[bias] = float(scores[bias]) + 1.0
	var personality: Array = choices.get("personality", [])
	for house in HOUSE_TENDENCY.keys():
		for keyword in HOUSE_TENDENCY[house]:
			for p in personality:
				if str(p).contains(str(keyword)) or str(keyword).contains(str(p)):
					scores[house] = float(scores[house]) + 1.5
	var best := ""
	var best_score := -1.0
	var tie_break: Array = []
	for house in scores.keys():
		var s := float(scores[house])
		if s > best_score:
			best_score = s
			best = house
			tie_break = [house]
		elif is_equal_approx(s, best_score):
			tie_break.append(house)
	if tie_break.size() > 1:
		best = str(rng.stream_pick("house_tiebreak", tie_break))
	return best

static func create(choices: Dictionary, registry: Registry, rng: RngService) -> Result:
	var out := Result.new()
	out.errors = validate_choices(choices, registry)
	if out.errors.size() > 0:
		return out

	var p := PlayerState.new_default()
	p.name_text = str(choices["name_text"]).strip_edges()
	p.gender = str(choices.get("gender", ""))
	p.age_months = int(choices["age_years"]) * 12
	p.bloodline_id = str(choices["bloodline_id"])
	p.birth_identity_id = str(choices["birth_identity_id"])
	p.birthplace = str(choices.get("birthplace", ""))
	p.family_status = str(choices.get("family_status", ""))
	p.house_id = assign_house(choices, rng, registry)
	p.political_leaning_id = str(choices["political_leaning_id"])
	p.personality = (choices.get("personality", []) as Array).duplicate()
	p.life_goal = str(choices["life_goal"])
	p.current_goal = p.life_goal
	p.sim_style_id = str(choices["sim_style_id"])
	p.location_id = str(choices.get("birthplace", "london_muggle"))

	var bloodline: Dictionary = registry.entry("bloodlines", p.bloodline_id)
	var identity: Dictionary = registry.entry("birth_identities", p.birth_identity_id)
	p.money_knuts = int(identity.get("start_knuts", 0))

	# 资质：random 在创建时掷定，且不得掷出哑炮（玩家没选哑炮血统）
	var aptitude_id := str(choices["aptitude_id"])
	if aptitude_id == "random":
		var pool: Array = []
		for candidate in registry.ids("aptitudes"):
			var cid := str(candidate)
			if cid == "random" or cid == "squib" or cid == "special":
				continue
			pool.append(cid)
		aptitude_id = str(rng.stream_pick("aptitude", pool))
	p.aptitude_id = aptitude_id
	var aptitude: Dictionary = registry.entry("aptitudes", aptitude_id)

	# 哑炮：无魔法、无魔杖（第七十五章）
	var has_magic := bool(bloodline.get("magic_aptitude", true)) and aptitude_id != "squib"
	if not has_magic:
		p.magic_tier = MagicLevel.Tier.SQUIB
		p.wand = {}
		p.flags["no_magic"] = true
		p.job = ""
	else:
		p.magic_tier = MagicLevel.Tier.PRE_SCHOOL
		var wand_choice: Dictionary = choices.get("wand", {})
		p.wand = wand_choice if not wand_choice.is_empty() else generate_wand(rng, registry)
		p.magic["capacity"] = 10 + int(rng.stream_int("capacity", 0, 5))
		p.magic["control"] = 10 + int(rng.stream_int("control", 0, 5))
		p.magic["affinity"] = 10 + int(rng.stream_int("affinity", 0, 5))

	# 血统自带标记与特殊资质标记（第十章：偏见真实存在）
	for flag in (bloodline.get("default_flags", []) as Array):
		p.flags[str(flag)] = true
	for granted in (aptitude.get("grants", []) as Array):
		p.flags[str(granted)] = true
	# 反漏洞：只有 aptitude_id=special 才能写入 aptitude_special 与对应天赋标记
	if aptitude_id == "special":
		p.aptitude_special = str(choices.get("aptitude_special", ""))
		if not p.aptitude_special.is_empty():
			p.flags[p.aptitude_special] = true
	p.flags["prejudice_level"] = float(bloodline.get("prejudice", 0.0))

	# 初始技能
	var bias := default_skills_for(choices, registry)
	for skill_id in bias.keys():
		p.add_skill(str(skill_id), int(bias[skill_id]))
	if has_magic and p.skill("charms") < 1:
		p.add_skill("charms", 1)

	out.player = p
	return out
```

- [ ] **Step 5: 运行测试，确认通过**

```bash
cd /e/Hali
bash tools/test.sh
```

预期：`[creation] 失败=0`、`全部通过。`

- [ ] **Step 6: 提交**

```bash
cd /e/Hali
git add src/rules/character_creation.gd src/core/registry.gd data/skills.json data/wand_woods.json data/wand_cores.json data/wand_flexibilities.json data/wand_lengths.json tests/creation_test.gd tests/run_tests.gd
git commit -m "feat(creation): 第七十五章启动界面到玩家档案的创建流水线"
```

---

### Task 7: 魔咒解析器与反漏洞守卫

**Files:**
- Create: `src/rules/spell_resolver.gd`
- Create: `data/spells.json`
- Modify: `src/core/registry.gd`（`TABLE_FILES` 追加 `spells`）
- Create: `tests/spell_test.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `Registry`、`WorldState`、`PlayerState`、`RngService`、`MagicLevel`
- Produces:
  - `SpellResolver`（`extends RefCounted`）
    - `GUARDS: Dictionary`（守卫 id → 中文说明）
    - `class Outcome: var ok: bool; var blocked: bool; var blocked_reason: String; var failure_rate: float; var roll: float; var success: bool; var side_effect: String; var narration: String; var guards: PackedStringArray; var legal_risk: bool`
    - `static cast(world: WorldState, spell_id: String, conditions: Dictionary, rng: RngService) -> Outcome`
    - `static modifiers_from(conditions: Dictionary) -> Dictionary`
  - `conditions` 字典键（第二十二章环境因素 + 目标属性）：
    `combat_stress, injury, emotion, wand_mismatch, unfamiliar_spell, dark_magic_interference`（float 0..1）；`target_alive: bool`；`target_rarity: String`（`common`/`rare`/`legendary`；比较前先 strip_edges + 小写归一，未在普通白名单内的值一律按稀有处理）
  - `data/spells.json`：`id,label,category,min_tier(等级标签),difficulty(float),forbidden(bool),guards[],side_effects[],note`
  - 守卫 id：`no_rare_resource_duplication`、`no_resurrection`、`no_time_rewind`、`no_unlimited_energy`、`unforgivable`、`requires_registration`、`requires_ministry_approval`、`forbidden_lifetime`

- [ ] **Step 1: 写失败测试**

创建 `tests/spell_test.gd`：

```gdscript
class_name SpellTest
extends RefCounted

func make_world(reg: Registry, tier: int) -> WorldState:
	var p := PlayerState.new_default()
	p.bloodline_id = "half_blood"
	p.aptitude_id = "normal"
	p.magic_tier = tier
	p.location_id = "hogwarts"
	var w := WorldState.create("modern", p, 20260918, reg)
	return w

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	a.eq(reg.validate().size(), 0, "魔咒表加入后仍无校验错误")
	a.is_true(reg.ids("spells").size() >= 24, "魔咒表至少 24 条")

	# 内容完整性：每条魔咒的 min_tier 必须是合法等级标签，守卫必须是已定义守卫
	for spell_id in reg.ids("spells"):
		var spell := reg.entry("spells", spell_id)
		a.is_true(MagicLevel.index_of_label(str(spell.get("min_tier", ""))) >= 0, "魔咒 %s 的 min_tier 非法" % spell_id)
		for guard in (spell.get("guards", []) as Array):
			a.is_true(SpellResolver.GUARDS.has(str(guard)), "魔咒 %s 引用未知守卫 %s" % [spell_id, str(guard)])
		a.is_true((spell.get("side_effects", []) as Array).size() > 0, "魔咒 %s 必须有失败副作用" % spell_id)

	# ---- 等级不足被拦截（第二十三章） ----
	var low := make_world(reg, MagicLevel.Tier.FIRST_YEAR)
	var rng := RngService.new(1)
	var blocked := SpellResolver.cast(low, "expecto_patronum", {}, rng)
	a.is_true(blocked.blocked, "新生无法施展守护神咒")
	a.is_true(blocked.blocked_reason.contains("等级"), "拦截原因说明等级不足")
	a.is_false(blocked.ok, "被拦截时 ok=false")

	var unknown := SpellResolver.cast(low, "没有这条魔咒", {}, rng)
	a.is_true(unknown.blocked, "未知魔咒被拦截")
	a.is_true(unknown.blocked_reason.contains("未知"), "未知魔咒原因明确")

	# ---- 第五十五条：复制咒不得无限复制稀有资源 ----
	var mid := make_world(reg, MagicLevel.Tier.ADULT)
	var rare := SpellResolver.cast(mid, "geminio", {"target_rarity": "rare"}, RngService.new(2))
	a.is_true(rare.blocked, "复制稀有资源被拦截")
	a.is_true(rare.blocked_reason.contains("稀有"), "稀有资源原因明确")
	var common := SpellResolver.cast(mid, "geminio", {"target_rarity": "common"}, RngService.new(2))
	a.is_false(common.blocked, "复制普通物品不被拦截")
	# 稀有度词表必须同时识别中文（否则中文「稀有」会静默绕过反复制守卫）
	var rare_cn := SpellResolver.cast(mid, "geminio", {"target_rarity": "稀有"}, RngService.new(2))
	a.is_true(rare_cn.blocked, "中文「稀有」也必须被反复制守卫拦截")
	# 归一化 + fail-closed：大小写/空白/繁体/未知稀有度都不得绕过反复制守卫
	for rarity in ["Rare", "稀有 ", "傳說", "uncommon", "epic"]:
		a.is_true(SpellResolver.cast(mid, "geminio", {"target_rarity": rarity}, RngService.new(2)).blocked, "稀有度变体 %s 必须被拦截" % rarity)
	a.is_false(SpellResolver.cast(mid, "geminio", {"target_rarity": "普通"}, RngService.new(2)).blocked, "中文「普通」视为普通物品")
	a.is_false(SpellResolver.cast(mid, "geminio", {"target_rarity": " Common "}, RngService.new(2)).blocked, "归一化后 Common 视为普通物品")

	# ---- 第五十五条：治疗咒不得无限复活 ----
	var dead := SpellResolver.cast(mid, "vulnera_sanentur", {"target_alive": false}, RngService.new(3))
	a.is_true(dead.blocked, "对死者施治疗术被拦截")
	a.is_true(dead.blocked_reason.contains("复活") or dead.blocked_reason.contains("死者"), "复活原因明确")
	var alive_target := SpellResolver.cast(mid, "vulnera_sanentur", {"target_alive": true}, RngService.new(3))
	a.is_false(alive_target.blocked, "对活人施治疗术不被拦截")

	# ---- 第五十五条：时间转换器不得无限回溯 ----
	var master := make_world(reg, MagicLevel.Tier.MASTER)
	master.flags["time_rewind_count"] = 0
	a.is_false(SpellResolver.cast(master, "time_turner", {}, RngService.new(4)).blocked, "首次时间回溯允许（但受严格限制）")
	master.flags["time_rewind_count"] = 1
	a.is_true(SpellResolver.cast(master, "time_turner", {}, RngService.new(4)).blocked, "第二次时间回溯被拦截")

	# ---- 第五十五条：低阶咒语无限叠加 ----
	master.flags["energy_loop_count"] = 0
	a.is_false(SpellResolver.cast(master, "lumos", {}, RngService.new(5)).blocked, "正常照明咒")
	master.flags["energy_loop_count"] = 3
	a.is_true(SpellResolver.cast(master, "lumos", {}, RngService.new(5)).blocked, "低阶咒语叠加过量被拦截")
	# per-turn 语义：推进一个回合后叠加计数重置；时间回溯计数为终身一次性，不重置
	a.eq(int(master.flags.get("energy_loop_count", 0)), 3, "拦截后叠加计数仍为 3")
	master.tick()
	a.eq(int(master.flags.get("energy_loop_count", 0)), 0, "tick 后叠加计数归零（per-turn）")
	a.is_false(SpellResolver.cast(master, "lumos", {}, RngService.new(5)).blocked, "新回合可重新施放基础咒")
	a.is_true(SpellResolver.cast(master, "time_turner", {}, RngService.new(4)).blocked, "时间回溯终身一次性：跨回合仍被拦截")

	# ---- 第二十五章：不可饶恕咒不拦截，但必须留下法律风险 ----
	var unforgivable := SpellResolver.cast(master, "imperio", {}, RngService.new(6))
	a.is_false(unforgivable.blocked, "不可饶恕咒可以被使用")
	a.is_true(unforgivable.legal_risk, "不可饶恕咒带法律风险")
	a.is_true(forbidden_count(reg) >= 6, "至少 6 条禁忌/受限魔咒")

	# ---- 魂器：终身禁忌，永久拦截（需要神话级才能绕过等级拦截，真正让守卫生效） ----
	var myth := make_world(reg, MagicLevel.Tier.MYTH)
	var horcrux := SpellResolver.cast(myth, "horcrux", {}, RngService.new(7))
	a.is_true(horcrux.blocked, "魂器永远被拦截")
	a.is_true(horcrux.guards.has("forbidden_lifetime"), "魂器带终身禁忌守卫")
	a.is_true(horcrux.blocked_reason.contains("禁忌"), "魂器拦截原因说明禁忌")

	# ---- 需登记的阿尼马格斯 ----
	master.player.flags.erase("animagus_registered")
	a.is_true(SpellResolver.cast(master, "animagus", {}, RngService.new(8)).blocked, "未登记不得变形")
	master.player.flags["animagus_registered"] = true
	a.is_false(SpellResolver.cast(master, "animagus", {}, RngService.new(8)).blocked, "登记后可变形")

	# ---- 需魔法部批准的门钥匙 ----
	master.flags.erase("ministry_approval")
	a.is_true(SpellResolver.cast(master, "portkey", {}, RngService.new(12)).blocked, "无魔法部批准不得使用门钥匙")
	master.flags["ministry_approval"] = true
	a.is_false(SpellResolver.cast(master, "portkey", {}, RngService.new(12)).blocked, "有批准后可使用门钥匙")

	# ---- 失败率必须落在规格区间内（用难度 0 的咒语对齐等级区间），环境因素抬高失败率 ----
	var adult := make_world(reg, MagicLevel.Tier.ADULT)
	var calm := SpellResolver.cast(adult, "lumos", {}, RngService.new(9))
	a.between(calm.failure_rate, 0.02, 0.05, "熟练成年巫师基础咒语失败率 2-5%（第二十二章）")
	# 咒语难度是在等级区间之上的额外偏移
	var hard := SpellResolver.cast(adult, "confringo", {}, RngService.new(9))
	a.is_true(hard.failure_rate > calm.failure_rate, "高难度咒语失败率更高")
	var stressed := SpellResolver.cast(adult, "lumos", {
		"combat_stress": 1.0, "injury": 1.0, "emotion": 1.0,
		"wand_mismatch": 1.0, "unfamiliar_spell": 1.0, "dark_magic_interference": 1.0,
	}, RngService.new(9))
	a.between(stressed.failure_rate, 0.92, 0.95, "六项满值环境因素把失败率推到上界")
	a.is_true(modifiers_from_test(adult) > 0.0, "未知条件被忽略")
	a.is_false(SpellResolver.modifiers_from({"不存在的因素": 1.0}).has("不存在的因素"), "未知条件键被丢弃")

	# ---- 确定性 ----
	var seq_a := []
	var seq_b := []
	for i in 10:
		seq_a.append(SpellResolver.cast(adult, "expelliarmus", {}, RngService.new(100 + i)).success)
		seq_b.append(SpellResolver.cast(adult, "expelliarmus", {}, RngService.new(100 + i)).success)
	a.eq(seq_a, seq_b, "同种子同结果")

	# ---- 成功与失败都要有旁白；失败必须有副作用 ----
	var any_success := false
	var any_failure := false
	for i in 50:
		var out := SpellResolver.cast(adult, "stupefy", {"combat_stress": 1.0}, RngService.new(200 + i))
		a.is_true(out.narration.length() > 0, "必须有旁白")
		if out.success:
			any_success = true
			a.eq(out.side_effect, "", "成功无副作用")
		else:
			any_failure = true
			a.is_true(out.side_effect.length() > 0, "失败必有副作用（第二十二章）")
	a.is_true(any_success, "50 次里应有成功")
	a.is_true(any_failure, "50 次里应有失败")

	return a.report("spell")

func forbidden_count(reg: Registry) -> int:
	var n := 0
	for spell_id in reg.ids("spells"):
		if bool(reg.entry("spells", spell_id).get("forbidden", false)):
			n += 1
	return n

func modifiers_from_test(w: WorldState) -> float:
	var m := SpellResolver.modifiers_from({"不存在的因素": 1.0, "combat_stress": 0.5})
	return float(m.get("combat_stress", 0.0))
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /e/Hali
sed -i 's|"res://tests/creation_test.gd",|"res://tests/creation_test.gd",\n\t"res://tests/spell_test.gd",|' tests/run_tests.gd
bash tools/test.sh
```

预期：`套件无法加载`（`SpellResolver` 未定义）+ `缺少数据表: spells`。

- [ ] **Step 3: 写魔咒数据表**

创建 `data/spells.json`（第二十一章分类；`min_tier` 用 `MagicLevel.LABELS` 原文；`difficulty` 为该咒相对难度偏移；`forbidden` 为法律禁忌；`guards` 为第五十五条反漏洞守卫）：

```json
[
	{"id": "lumos", "label": "照明咒", "category": "基础魔咒", "min_tier": "麻瓜出身未入学", "difficulty": 0.0, "forbidden": false, "guards": ["no_unlimited_energy"], "side_effects": ["咒语反噬", "短暂失语"], "note": "最基础的咒语之一"},
	{"id": "wingardium_leviosa", "label": "悬浮咒", "category": "基础魔咒", "min_tier": "霍格沃茨新生", "difficulty": 0.02, "forbidden": false, "guards": ["no_unlimited_energy"], "side_effects": ["目标偏转", "魔力失控"], "note": "发音错误会让目标乱飞"},
	{"id": "alohomora", "label": "开锁咒", "category": "基础魔咒", "min_tier": "霍格沃茨新生", "difficulty": 0.02, "forbidden": false, "guards": [], "side_effects": ["目标偏转", "魔力枯竭"], "note": "对魔法加固的锁常常无效"},
	{"id": "reparo", "label": "修复咒", "category": "基础魔咒", "min_tier": "霍格沃茨新生", "difficulty": 0.03, "forbidden": false, "guards": [], "side_effects": ["咒语反噬", "目标偏转"], "note": "修复不是复原，破碎的东西会留下痕迹"},
	{"id": "scourgify", "label": "清洁咒", "category": "基础魔咒", "min_tier": "麻瓜出身未入学", "difficulty": 0.0, "forbidden": false, "guards": [], "side_effects": ["目标偏转"], "note": "家务魔法的基础"},
	{"id": "incendio", "label": "生火咒", "category": "基础魔咒", "min_tier": "霍格沃茨新生", "difficulty": 0.05, "forbidden": false, "guards": [], "side_effects": ["爆炸", "伤害自己", "伤害同伴"], "note": "火不认人"},
	{"id": "diffindo", "label": "切割咒", "category": "基础魔咒", "min_tier": "霍格沃茨新生", "difficulty": 0.03, "forbidden": false, "guards": [], "side_effects": ["伤害自己", "伤害同伴"], "note": "精确度要求高"},
	{"id": "expelliarmus", "label": "缴械咒", "category": "防御与战斗魔咒", "min_tier": "霍格沃茨新生", "difficulty": 0.03, "forbidden": false, "guards": [], "side_effects": ["目标偏转", "魔力枯竭"], "note": "傲罗的基础功"},
	{"id": "stupefy", "label": "昏迷咒", "category": "防御与战斗魔咒", "min_tier": "O.W.L水平", "difficulty": 0.05, "forbidden": false, "guards": [], "side_effects": ["目标偏转", "伤害同伴"], "note": "多人同时施放会叠加威力"},
	{"id": "impedimenta", "label": "障碍咒", "category": "防御与战斗魔咒", "min_tier": "霍格沃茨新生", "difficulty": 0.03, "forbidden": false, "guards": [], "side_effects": ["目标偏转"], "note": "阻断而非伤害"},
	{"id": "protego", "label": "铁甲咒", "category": "防御与战斗魔咒", "min_tier": "O.W.L水平", "difficulty": 0.06, "forbidden": false, "guards": [], "side_effects": ["咒语反噬", "魔力枯竭"], "note": "挡不住不可饶恕咒"},
	{"id": "confringo", "label": "粉身碎骨", "category": "防御与战斗魔咒", "min_tier": "N.E.W.T水平", "difficulty": 0.10, "forbidden": false, "guards": [], "side_effects": ["爆炸", "伤害自己", "伤害同伴"], "note": "破坏力强，代价真实"},
	{"id": "expulso", "label": "爆炸咒", "category": "防御与战斗魔咒", "min_tier": "N.E.W.T水平", "difficulty": 0.10, "forbidden": false, "guards": [], "side_effects": ["爆炸", "伤害自己"], "note": "环境会改变结果"},
	{"id": "incarcerous", "label": "束缚咒", "category": "防御与战斗魔咒", "min_tier": "O.W.L水平", "difficulty": 0.05, "forbidden": false, "guards": [], "side_effects": ["目标偏转", "魔力枯竭"], "note": "绳索可被切断"},
	{"id": "expecto_patronum", "label": "守护神咒", "category": "防御与战斗魔咒", "min_tier": "N.E.W.T水平", "difficulty": 0.12, "forbidden": false, "guards": [], "side_effects": ["魔力枯竭", "情绪失控"], "note": "需要足够快乐的记忆；形态由性格决定"},
	{"id": "evanesco", "label": "消失术", "category": "变形术", "min_tier": "O.W.L水平", "difficulty": 0.06, "forbidden": false, "guards": [], "side_effects": ["目标偏转", "魔力枯竭"], "note": "消失不等于摧毁"},
	{"id": "aparecium", "label": "显形术", "category": "变形术", "min_tier": "O.W.L水平", "difficulty": 0.04, "forbidden": false, "guards": [], "side_effects": ["咒语反噬"], "note": "隐形墨水与隐藏文字"},
	{"id": "animagus", "label": "阿尼马格斯", "category": "变形术", "min_tier": "熟练成年巫师", "difficulty": 0.15, "forbidden": false, "guards": ["requires_registration"], "side_effects": ["咒语反噬", "魔力失控", "伤害自己"], "note": "人变动物，必须登记；未登记属违法"},
	{"id": "legilimens", "label": "摄神取念", "category": "心智魔法", "min_tier": "N.E.W.T水平", "difficulty": 0.12, "forbidden": false, "guards": ["restricted_mind_magic"], "side_effects": ["咒语反噬", "短暂失语"], "note": "滥用摄神取念是禁忌（第二十五章）"},
	{"id": "occlumency", "label": "大脑封闭术", "category": "心智魔法", "min_tier": "O.W.L水平", "difficulty": 0.10, "forbidden": false, "guards": [], "side_effects": ["魔力枯竭", "情绪失控"], "note": "防御性心智魔法"},
	{"id": "obliviate", "label": "遗忘咒", "category": "心智魔法", "min_tier": "N.E.W.T水平", "difficulty": 0.14, "forbidden": true, "guards": ["restricted_mind_magic"], "side_effects": ["目标偏转", "咒语反噬"], "note": "记忆可以被破坏，且很难精确"},
	{"id": "confundo", "label": "混淆咒", "category": "心智魔法", "min_tier": "O.W.L水平", "difficulty": 0.10, "forbidden": true, "guards": ["restricted_mind_magic"], "side_effects": ["目标偏转"], "note": "法律与道德风险随使用次数上升"},
	{"id": "imperio", "label": "夺魂咒", "category": "心智魔法", "min_tier": "熟练成年巫师", "difficulty": 0.14, "forbidden": true, "guards": ["unforgivable"], "side_effects": ["咒语反噬", "魔力枯竭"], "note": "不可饶恕咒，阿兹卡班级罪行"},
	{"id": "crucio", "label": "钻心咒", "category": "死亡与灵魂魔法", "min_tier": "熟练成年巫师", "difficulty": 0.16, "forbidden": true, "guards": ["unforgivable"], "side_effects": ["咒语反噬", "情绪失控"], "note": "不可饶恕咒，需要真正的恶意"},
	{"id": "avada_kedavra", "label": "阿瓦达索命", "category": "死亡与灵魂魔法", "min_tier": "专家级", "difficulty": 0.20, "forbidden": true, "guards": ["unforgivable"], "side_effects": ["咒语反噬", "魔力枯竭"], "note": "不可饶恕咒；死亡不可逆"},
	{"id": "inferi", "label": "阴尸", "category": "死亡与灵魂魔法", "min_tier": "大师级", "difficulty": 0.25, "forbidden": true, "guards": ["forbidden_lifetime", "unforgivable"], "side_effects": ["爆炸", "咒语反噬"], "note": "操纵死者，极度禁忌"},
	{"id": "horcrux", "label": "魂器", "category": "死亡与灵魂魔法", "min_tier": "神话级", "difficulty": 0.50, "forbidden": true, "guards": ["forbidden_lifetime"], "side_effects": ["伤害自己", "咒语反噬"], "note": "分裂灵魂，最深的禁忌"},
	{"id": "apparition", "label": "幻影移形", "category": "时间与空间魔法", "min_tier": "N.E.W.T水平", "difficulty": 0.12, "forbidden": false, "guards": [], "side_effects": ["分体", "被困", "伤害自己"], "note": "需要目的地、决心、从容"},
	{"id": "portkey", "label": "门钥匙", "category": "时间与空间魔法", "min_tier": "熟练成年巫师", "difficulty": 0.08, "forbidden": false, "guards": ["requires_ministry_approval"], "side_effects": ["目标偏转"], "note": "需要魔法部批准"},
	{"id": "time_turner", "label": "时间转换器", "category": "时间与空间魔法", "min_tier": "大师级", "difficulty": 0.30, "forbidden": true, "guards": ["no_time_rewind"], "side_effects": ["时间乱流", "伤害自己"], "note": "极度魔法部管制，禁止无限回溯"},
	{"id": "geminio", "label": "复制咒", "category": "变形术", "min_tier": "O.W.L水平", "difficulty": 0.08, "forbidden": false, "guards": ["no_rare_resource_duplication"], "side_effects": ["目标偏转", "魔力枯竭"], "note": "复制品会劣化，且不能复制稀有资源"},
	{"id": "vulnera_sanentur", "label": "治疗咒", "category": "魔药学与草药学", "min_tier": "O.W.L水平", "difficulty": 0.08, "forbidden": false, "guards": ["no_resurrection"], "side_effects": ["咒语反噬", "魔力枯竭"], "note": "治疗师不是万能复活机"}
]
```

- [ ] **Step 4: 实现 `SpellResolver`**

创建 `src/rules/spell_resolver.gd`：

```gdscript
class_name SpellResolver
extends RefCounted

# 第五十五条 / 第二十五章守卫说明（同时是唯一合法守卫集合）
const GUARDS: Dictionary = {
	"no_rare_resource_duplication": "禁止复制咒无限复制稀有资源",
	"no_resurrection": "禁止治疗咒无限复活",
	"no_time_rewind": "禁止时间转换器无限回溯",
	"no_unlimited_energy": "禁止低阶咒语无限叠加",
	"unforgivable": "不可饶恕咒：触犯法律",
	"requires_registration": "需要登记（阿尼马格斯）",
	"requires_ministry_approval": "需要魔法部批准",
	"forbidden_lifetime": "终身禁忌",
	"restricted_mind_magic": "受限心智魔法：滥用即违法",
}

# 稀有度采用 fail-closed 白名单：只有显式认定的普通稀有度才允许复制，
# 大小写/空白先归一；未知值（含繁体、拼写变体、任意字符串）一律按稀有处理，避免绕过守卫。
const COMMON_RARITIES: Array[String] = ["common", "普通", "常见"]
const ENERGY_LOOP_LIMIT := 3
const TIME_REWIND_LIMIT := 1

class Outcome:
	var ok: bool = false
	var blocked: bool = false
	var blocked_reason: String = ""
	var failure_rate: float = 1.0
	var roll: float = 1.0
	var success: bool = false
	var side_effect: String = ""
	var narration: String = ""
	var guards: PackedStringArray = PackedStringArray()
	var legal_risk: bool = false

static func modifiers_from(conditions: Dictionary) -> Dictionary:
	var out := {}
	for key in MagicLevel.MODIFIER_KEYS:
		out[key] = clampf(float(conditions.get(key, 0.0)), 0.0, 1.0)
	return out

static func _blocked_outcome(reason: String, guards: PackedStringArray) -> Outcome:
	var o := Outcome.new()
	o.ok = false
	o.blocked = true
	o.blocked_reason = reason
	o.guards = guards
	o.narration = "（%s）" % reason
	return o

static func cast(world: WorldState, spell_id: String, conditions: Dictionary, rng: RngService) -> Outcome:
	var registry := world.registry
	var spell := registry.entry("spells", spell_id)
	var guard_ids := PackedStringArray()
	for guard in (spell.get("guards", []) as Array):
		guard_ids.append(str(guard))
	if spell.is_empty():
		return _blocked_outcome("未知魔咒：%s" % spell_id, guard_ids)

	var player := world.player
	var min_tier := MagicLevel.index_of_label(str(spell.get("min_tier", "")))
	if min_tier < 0:
		min_tier = MagicLevel.Tier.MYTH
	if player.magic_tier < min_tier:
		return _blocked_outcome("魔法等级不足：%s 需要 %s，当前为 %s" % [
			str(spell.get("label", spell_id)),
			MagicLevel.label_of(min_tier),
			MagicLevel.label_of(player.magic_tier),
		], guard_ids)

	var legal_risk := false
	var target_alive := bool(conditions.get("target_alive", true))
	var target_rarity := str(conditions.get("target_rarity", "common")).strip_edges().to_lower()
	for guard in guard_ids:
		match guard:
			"no_rare_resource_duplication":
				if not COMMON_RARITIES.has(target_rarity):
					return _blocked_outcome("复制咒无法复制稀有资源（%s）：世界资源必须有成本、有产出、有消耗" % target_rarity, guard_ids)
			"no_resurrection":
				if not target_alive:
					return _blocked_outcome("治疗咒无法复活死者：死亡真实且不可逆", guard_ids)
			"no_time_rewind":
				# 终身一次性：time_rewind_count 永不由 tick() 重置
				if int(world.flags.get("time_rewind_count", 0)) >= TIME_REWIND_LIMIT:
					return _blocked_outcome("时间转换器禁止无限回溯", guard_ids)
			"no_unlimited_energy":
				# per-turn：计数由 WorldState.tick() 每回合（月）重置
				if int(world.flags.get("energy_loop_count", 0)) >= ENERGY_LOOP_LIMIT:
					return _blocked_outcome("低阶咒语叠加已达上限，无法继续累积能量", guard_ids)
			"forbidden_lifetime":
				return _blocked_outcome("终身禁忌：%s" % str(spell.get("label", spell_id)), guard_ids)
			"requires_registration":
				if not player.flags.has("animagus_registered"):
					return _blocked_outcome("未在魔法部登记，不得成为阿尼马格斯", guard_ids)
			"requires_ministry_approval":
				if not world.flags.has("ministry_approval"):
					return _blocked_outcome("缺少魔法部批准", guard_ids)
			"unforgivable":
				legal_risk = true
			"restricted_mind_magic":
				legal_risk = true

	if bool(spell.get("forbidden", false)):
		legal_risk = true

	# 失败率：等级区间 + 环境因素 + 资质偏移 + 咒语难度
	var aptitude_delta := float(registry.entry("aptitudes", player.aptitude_id).get("failure_delta", 0.0))
	var rate := MagicLevel.effective_rate(player.magic_tier, modifiers_from(conditions), aptitude_delta + float(spell.get("difficulty", 0.0)))

	var o := Outcome.new()
	o.ok = true
	o.guards = guard_ids
	o.legal_risk = legal_risk
	o.failure_rate = rate
	o.roll = rng.stream_float("spell_roll")
	o.success = o.roll > rate

	var label := str(spell.get("label", spell_id))
	if o.success:
		o.narration = "%s成功。" % label
		# 需要代价的魔法对象在成功时也要显式结算（第十五章：没有免费的魔力）
		if guard_ids.has("no_unlimited_energy"):
			world.flags["energy_loop_count"] = int(world.flags.get("energy_loop_count", 0)) + 1
		if guard_ids.has("no_time_rewind"):
			world.flags["time_rewind_count"] = int(world.flags.get("time_rewind_count", 0)) + 1
		if legal_risk:
			world.flags["illegal_cast_count"] = int(world.flags.get("illegal_cast_count", 0)) + 1
			o.narration += "（法律与道德风险已记录）"
	else:
		var effects: Array = spell.get("side_effects", [])
		o.side_effect = str(rng.stream_pick("spell_side_effect", effects)) if not effects.is_empty() else "魔力失控"
		o.narration = "%s失败：%s。" % [label, o.side_effect]
		if o.side_effect == "魔力枯竭" or o.side_effect == "分体" or o.side_effect == "时间乱流":
			world.flags["last_serious_mishap_turn"] = world.clock.turn
	return o
```

- [ ] **Step 5: 追加数据表并运行测试**

在 `src/core/registry.gd` 的 `TABLE_FILES` 追加：

```gdscript
	"spells": "spells.json",
```

```bash
cd /e/Hali
bash tools/test.sh
```

预期：`[spell] 失败=0`、`全部通过。`

- [ ] **Step 6: 提交**

```bash
cd /e/Hali
git add src/rules/spell_resolver.gd src/core/registry.gd data/spells.json tests/spell_test.gd tests/run_tests.gd
git commit -m "feat(rules): 魔咒解析器与第五十五条反漏洞守卫"
```

---

### Task 8: 叙事接口 + 状态操作 + 反刷成长 + 回合引擎

**Files:**
- Create: `src/gm/game_master.gd`
- Create: `src/gm/scripted_game_master.gd`
- Create: `src/rules/state_ops.gd`
- Create: `src/rules/progression.gd`
- Create: `src/core/turn_engine.gd`
- Create: `tests/gm_test.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `WorldState`、`RngService`、`SpellResolver`、`Money`
- Produces:
  - `GameMaster`（`extends RefCounted`，接口基类）
    - `class GmResult: var narration: String; var deltas: Array; var tags: PackedStringArray; var audit_required: bool`
    - `func act(world: WorldState, action_text: String) -> GmResult`（基类返回「无叙事引擎接入」）
  - `ScriptedGameMaster extends GameMaster`：`_init(rng: RngService)`，确定性关键词裁决
  - `StateOps`（`extends RefCounted`）：`static apply(world: WorldState, deltas: Array) -> PackedStringArray`（返回错误列表；未知 op 记错误但不崩）
    - 支持的 op：`add_money`(`knuts:int`)、`gain_skill`(`skill_id:String`,`amount:int`)、`learn_spell`(`spell_id:String`)、`set_flag`(`key:String`,`value`)、`know_fact`(`fact_id:String`,`source:String`)、`set_location`(`location_id:String`)、`set_job`(`job:String`)、`relation_delta`(`npc_id:String`,`trust:int`,`hostility:int`)、`cast_spell`(`spell_id:String`,`conditions:Dictionary`)
  - `Progression`（`extends RefCounted`）：`static gain(world: WorldState, skill_id: String, base_gain: int) -> int`（第七十章反刷）
    - 只**计算并记账**本次可获得的成长量，**不修改玩家技能**；技能写回由 `StateOps` 的 `gain_skill` 操作统一完成，避免同一份收益被应用两次
  - `TurnEngine`（`extends RefCounted`）
    - `_init(world: WorldState, gm: GameMaster, rng: RngService)`
    - `submit(action_text: String) -> Dictionary`，返回 `{"narration":String,"deltas_applied":Array,"op_errors":PackedStringArray,"events":Array,"audit":String,"blocked":bool}`
    - `acknowledge_audit() -> void`（第七十二章：确认自检后才能继续）

- [ ] **Step 1: 写失败测试**

创建 `tests/gm_test.gd`：

```gdscript
class_name GmTest
extends RefCounted

func make_world(tier := 2) -> WorldState:
	var reg := Registry.load_default()
	var p := PlayerState.new_default()
	p.name_text = "张三"
	p.bloodline_id = "half_blood"
	p.birth_identity_id = "ordinary_wizard_family"
	p.magic_tier = tier
	p.location_id = "hogwarts"
	p.sim_style_id = "mixed"
	p.age_months = 132
	p.money_knuts = 4930
	var w := WorldState.create("modern", p, 20260918, reg)
	return w

func run() -> int:
	var a := TestAssert.new()

	# ---- StateOps：未知 op 记错误但不崩 ----
	var w := make_world()
	var errs := StateOps.apply(w, [
		{"op": "add_money", "knuts": 493},
		{"op": "set_job", "job": "魔药学徒"},
		{"op": "不存在的操作", "x": 1},
		{"op": "gain_skill", "skill_id": "potions", "amount": 2},
	])
	a.eq(errs.size(), 1, "只有一个未知 op 错误")
	a.eq(w.player.money().formatted(), "11加隆 0西可 0纳特", "加钱生效")
	a.eq(w.player.job, "魔药学徒", "身份变更生效")
	a.eq(w.player.skill("potions"), 2, "技能生效")

	# 非法内容 id 不得写入
	var errs2 := StateOps.apply(w, [
		{"op": "learn_spell", "spell_id": "不存在的魔咒"},
		{"op": "set_location", "location_id": "不存在的地点"},
	])
	a.eq(errs2.size(), 2, "非法魔咒与地点都报错")
	a.is_false(w.player.knows_spell("不存在的魔咒"), "非法魔咒未写入")

	# know_fact 必须带来源（第四十三章：信息分来源可信度）
	StateOps.apply(w, [{"op": "know_fact", "fact_id": "r1", "source": "破釜酒吧传闻"}])
	a.eq(w.player.known_facts["r1"], "破釜酒吧传闻", "记录信息来源")

	# 施法 op 走 SpellResolver：过度施法不得无限累积
	var w2 := make_world(5)
	for i in 5:
		StateOps.apply(w2, [{"op": "cast_spell", "spell_id": "lumos", "conditions": {}}])
	a.is_true(int(w2.flags.get("energy_loop_count", 0)) <= 3, "低阶咒语叠加计数不超过上限")
	# 直接顶到上限，验证守卫真的拦截（不依赖掷骰结果）
	w2.flags["energy_loop_count"] = 3
	StateOps.apply(w2, [{"op": "cast_spell", "spell_id": "lumos", "conditions": {}}])
	a.is_true(str(w2.flags.get("last_cast_narration", "")).contains("上限"), "达到上限后施法被拦截")

	# ---- Progression：第七十章反刷 ----
	var w3 := make_world()
	var g1 := Progression.gain(w3, "potions", 4)
	var g2 := Progression.gain(w3, "potions", 4)
	var g3 := Progression.gain(w3, "potions", 4)
	a.eq(g1, 4, "首次训练满额")
	a.is_true(g2 < g1, "重复训练收益下降")
	a.is_true(g3 <= g2, "继续下降")
	var total := g1 + g2 + g3
	for i in 20:
		total += Progression.gain(w3, "potions", 4)
	a.eq(total, 8, "同一地点重复 23 次的总收益恰好 8（4+2+1+1，之后归零）")
	# 换地点 = 新环境（第七十章：成长来自新环境）
	w3.player.location_id = "diagon_alley"
	a.is_true(Progression.gain(w3, "potions", 4) >= 1, "换环境后重新获得成长")
	# 不同技能互不影响
	a.eq(Progression.gain(w3, "charms", 4), 4, "未训练过的技能满额")

	# ---- ScriptedGameMaster：确定性叙事替身 ----
	var w4 := make_world()
	var gm := ScriptedGameMaster.new(RngService.new(11))
	var study := gm.act(w4, "我要练习魔药学")
	a.is_true(study.narration.length() > 0, "有叙事")
	a.is_true(study.deltas.size() > 0, "产生状态增量")
	a.is_true(study.tags.has("train"), "打上 train 标签")
	var money_before := w4.player.money_knuts
	var work := gm.act(w4, "我去对角巷打工赚钱")
	a.is_true(work.deltas.size() > 0, "打工产生增量")
	a.is_true(work.tags.has("work"), "打上 work 标签")
	var unknown := gm.act(w4, "我对着墙思考宇宙的尽头")
	a.is_true(unknown.narration.length() > 0, "未知行动也要有叙事，而不是崩溃")
	a.is_true(unknown.tags.has("idle"), "未知行动归为 idle")

	# 施法意图必须能被识别并走 SpellResolver
	var cast_result := gm.act(w4, "我念出 照明咒")
	a.is_true(cast_result.tags.has("cast"), "识别施法意图")
	a.is_true(cast_result.narration.contains("照明咒") or cast_result.narration.length() > 0, "施法旁白")

	# ---- TurnEngine：世界不会停下来等玩家（第四十七章） ----
	var w5 := make_world()
	var engine := TurnEngine.new(w5, ScriptedGameMaster.new(RngService.new(22)), RngService.new(22))
	var before_year := w5.clock.year
	var before_turn := w5.clock.turn
	var r := engine.submit("我要去上课")
	a.has_key(r, "narration", "返回叙事")
	a.has_key(r, "events", "返回本月事件")
	a.eq(w5.clock.turn, before_turn + 1, "每次提交推进一个回合")
	a.is_true(w5.clock.year >= before_year, "时间向前")

	# ---- 第七十二章：第 15 回合强制自检，并且必须等待玩家确认 ----
	var w6 := make_world()
	var engine6 := TurnEngine.new(w6, ScriptedGameMaster.new(RngService.new(33)), RngService.new(33))
	var audit_seen := ""
	for i in 15:
		var res := engine6.submit("我要去上课")
		if str(res.get("audit", "")) != "":
			audit_seen = str(res["audit"])
	a.is_true(audit_seen.contains("剧情快照"), "第 15 回合输出剧情快照")
	a.is_true(audit_seen.contains("人设OOC自检报告"), "第 15 回合输出 OOC 自检报告")
	a.is_true(bool(w6.flags.get("awaiting_audit_ack", false)), "自检后挂起，等待指令")

	var blocked_res := engine6.submit("我要继续上课")
	a.is_true(bool(blocked_res.get("blocked", false)), "未确认自检前拒绝继续剧情")
	a.is_true(str(blocked_res["narration"]).contains("自检"), "提示先确认自检")
	engine6.acknowledge_audit()
	a.is_false(bool(w6.flags.get("awaiting_audit_ack", false)), "确认后解除挂起")
	var resumed := engine6.submit("我要继续上课")
	a.is_false(bool(resumed.get("blocked", false)), "确认后可以继续")

	# ---- 死亡不可逆（第五十三章）：死亡玩家不能再行动 ----
	var w7 := make_world()
	w7.player.alive = false
	var engine7 := TurnEngine.new(w7, ScriptedGameMaster.new(RngService.new(44)), RngService.new(44))
	var dead_res := engine7.submit("我要起床")
	a.is_true(bool(dead_res.get("blocked", false)), "死者无法行动")
	a.is_true(str(dead_res["narration"]).contains("死亡"), "死亡提示")

	# ---- 存档里必须留下随机流状态，读档才能续跑一致（任务 10 会用到） ----
	var w8 := make_world()
	var engine8 := TurnEngine.new(w8, ScriptedGameMaster.new(RngService.new(55)), RngService.new(55))
	engine8.submit("我要去上课")
	a.is_true(w8.rng_state.size() > 0, "回合引擎把随机流状态写回世界")

	return a.report("gm")
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /e/Hali
sed -i 's|"res://tests/spell_test.gd",|"res://tests/spell_test.gd",\n\t"res://tests/gm_test.gd",|' tests/run_tests.gd
bash tools/test.sh
```

预期：`套件无法加载`（`StateOps` 未定义），退出码 1。

- [ ] **Step 3: 实现 `Progression`**

创建 `src/rules/progression.gd`：

```gdscript
class_name Progression
extends RefCounted

const WINDOW_TURNS := 12
const MIN_GAIN := 0

# 第七十章：禁止站在禁林砍 1000 只八眼巨蛛升级。
# 同一（技能, 地点）在 12 回合内的重复次数越多，收益越低；换环境则重新计算。
static func gain(world: WorldState, skill_id: String, base_gain: int) -> int:
	var key := "%s@%s" % [skill_id, world.player.location_id]
	var recent: Dictionary = world.flags.get("recent_training", {})
	var history: Array = recent.get(key, [])
	var kept: Array = []
	for entry in history:
		if world.clock.turn - int(entry) <= WINDOW_TURNS:
			kept.append(int(entry))
	var repeats := kept.size()
	kept.append(world.clock.turn)
	recent[key] = kept
	world.flags["recent_training"] = recent

	var factor := 1.0 / float(1 + repeats)
	# 向下取整（不是四舍五入）：重复 4 次之后收益归零
	var gained: int = maxi(MIN_GAIN, int(float(base_gain) * factor))
	# 注意：这里只计算与记账，不修改玩家技能。
	# 技能写回由 StateOps 的 gain_skill 操作统一完成，避免同一份收益被应用两次。
	return gained
```

- [ ] **Step 4: 实现 `StateOps`**

创建 `src/rules/state_ops.gd`：

```gdscript
class_name StateOps
extends RefCounted

# 所有玩家/世界状态变更都必须经过这里，便于审计与自检（第七十二章）。
static func apply(world: WorldState, deltas: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	for raw in deltas:
		if typeof(raw) != TYPE_DICTIONARY:
			errors.append("非字典操作: %s" % str(raw))
			continue
		var op := str(raw.get("op", ""))
		match op:
			"add_money":
				var m := world.player.money().add(Money.from_knuts(int(raw.get("knuts", 0))))
				world.player.set_money(m)
			"gain_skill":
				var skill_id := str(raw.get("skill_id", ""))
				if not world.registry.has("skills", skill_id):
					errors.append("未知技能: %s" % skill_id)
				else:
					world.player.add_skill(skill_id, int(raw.get("amount", 0)))
			"learn_spell":
				var spell_id := str(raw.get("spell_id", ""))
				if not world.registry.has("spells", spell_id):
					errors.append("未知魔咒: %s" % spell_id)
				else:
					world.player.learn_spell(spell_id)
			"set_flag":
				world.flags[str(raw.get("key", ""))] = raw.get("value", true)
			"set_player_flag":
				world.player.flags[str(raw.get("key", ""))] = raw.get("value", true)
			"know_fact":
				var source := str(raw.get("source", ""))
				if source.is_empty():
					errors.append("know_fact 缺少来源: %s" % str(raw.get("fact_id", "")))
				elif source == "system":
					errors.append("禁止系统直接告知真相（第四十三章/第五十七章）")
				else:
					world.player.known_facts[str(raw.get("fact_id", ""))] = source
			"set_location":
				var location_id := str(raw.get("location_id", ""))
				if not world.registry.has("locations", location_id):
					errors.append("未知地点: %s" % location_id)
				else:
					world.player.location_id = location_id
			"set_job":
				world.player.job = str(raw.get("job", ""))
			"relation_delta":
				var npc_id := str(raw.get("npc_id", ""))
				var rel: Dictionary = world.player.relations.get(npc_id, {"trust": 0, "interest": 0, "hostility": 0})
				rel["trust"] = int(rel.get("trust", 0)) + int(raw.get("trust", 0))
				rel["hostility"] = int(rel.get("hostility", 0)) + int(raw.get("hostility", 0))
				rel["interest"] = int(rel.get("interest", 0)) + int(raw.get("interest", 0))
				world.player.relations[npc_id] = rel
			"set_magic_tier":
				world.player.magic_tier = clampi(int(raw.get("tier", world.player.magic_tier)), 0, MagicLevel.LABELS.size() - 1)
			"cast_spell":
				var outcome := SpellResolver.cast(world, str(raw.get("spell_id", "")), raw.get("conditions", {}), world_gm_rng(world))
				world.flags["last_cast_success"] = outcome.success
				world.flags["last_cast_narration"] = outcome.narration
				if outcome.blocked:
					errors.append(outcome.blocked_reason)
			_:
				errors.append("未知操作: %s" % op)
	return errors

# cast_spell 需要一个随机源；由世界种子与当前回合推导，保证可复现。
static func world_gm_rng(world: WorldState) -> RngService:
	return RngService.new(world.game_seed + world.clock.turn * 15485863)
```

- [ ] **Step 5: 实现 `GameMaster` 与 `ScriptedGameMaster`**

创建 `src/gm/game_master.gd`：

```gdscript
class_name GameMaster
extends RefCounted

class GmResult:
	var narration: String = ""
	var deltas: Array = []
	var tags: PackedStringArray = PackedStringArray()
	var audit_required: bool = false

# 接口：计划 01 用 ScriptedGameMaster，计划 02 用 LlmGameMaster 替换。
# 实现者只描述发生了什么（叙事 + 状态增量），不直接改世界。
func act(_world: WorldState, _action_text: String) -> GmResult:
	var r := GmResult.new()
	r.narration = "（尚未接入叙事引擎）"
	return r
```

创建 `src/gm/scripted_game_master.gd`：

```gdscript
class_name ScriptedGameMaster
extends GameMaster

const TRAIN_KEYWORDS: Array[String] = ["练习", "学习", "训练", "钻研", "研究", "复习", "上课"]
const WORK_KEYWORDS: Array[String] = ["打工", "赚钱", "上班", "经商", "接活", "做生意"]
const SOCIAL_KEYWORDS: Array[String] = ["打听", "询问", "聊天", "结交", "社交", "谈"]
const REST_KEYWORDS: Array[String] = ["休息", "睡觉", "吃饭", "喝", "闲逛", "发呆", "回家"]
const CAST_KEYWORDS: Array[String] = ["念", "施展", "使用咒语", "施法", "用魔杖"]

const SKILL_BY_KEYWORD: Dictionary = {
	"魔药": "potions", "草药": "herbology", "魔咒": "charms", "变形": "transfiguration",
	"黑魔法防御": "dada", "防御": "dada", "历史": "history_of_magic", "天文": "astronomy",
	"占卜": "divination", "魔文": "ancient_runes", "神奇生物": "care_of_magical_creatures",
	"魁地奇": "quidditch", "治疗": "healing", "社交": "social", "口才": "social",
}

var rng: RngService = null

func _init(rng_: RngService = null) -> void:
	rng = rng_ if rng_ != null else RngService.new(0)

func _contains_any(text: String, keywords: Array) -> bool:
	for k in keywords:
		if text.contains(str(k)):
			return true
	return false

func _detect_skill(text: String) -> String:
	# 第六十三章：主修科目来自玩家长期投入
	for keyword in SKILL_BY_KEYWORD.keys():
		if text.contains(str(keyword)):
			return str(SKILL_BY_KEYWORD[keyword])
	return "charms"

func _detect_spell(world: WorldState, text: String) -> String:
	for spell_id in world.registry.ids("spells"):
		var label := str(world.registry.entry("spells", spell_id).get("label", ""))
		if not label.is_empty() and text.contains(label):
			return str(spell_id)
	return ""

func act(world: WorldState, action_text: String) -> GmResult:
	var r := GmResult.new()
	var text := action_text.strip_edges()

	if text.is_empty():
		r.narration = "你没有做任何事。世界继续向前。"
		r.tags.append("idle")
		return r

	# 施法意图优先，避免「练习魔咒」被误判
	var spell_id := _detect_spell(world, text)
	if not spell_id.is_empty() and _contains_any(text, CAST_KEYWORDS):
		r.tags.append("cast")
		# 这里直接调用规则层，因为它必须产出旁白；守卫与代价由 cast() 内部结算。
		# 若由 StateOps 的 cast_spell 操作重放，会掷两次骰并重复结算守卫。
		var outcome := SpellResolver.cast(world, spell_id, {}, rng)
		r.narration = outcome.narration
		if not outcome.blocked and outcome.success:
			# 成功一次即算入门；重复施法不再重复记录（PlayerState.learn_spell 幂等）
			r.deltas.append({"op": "learn_spell", "spell_id": spell_id})
		return r

	if _contains_any(text, TRAIN_KEYWORDS):
		var skill_id := _detect_skill(text)
		var amount := Progression.gain(world, skill_id, 4)
		r.tags.append("train")
		r.deltas.append({"op": "gain_skill", "skill_id": skill_id, "amount": amount})
		var skill_label := str(world.registry.entry("skills", skill_id).get("label", skill_id))
		if amount >= 4:
			r.narration = "你花了整整一个月钻研%s，进步明显。" % skill_label
		elif amount > 0:
			r.narration = "你继续练%s，但收获不如从前（重复练习收益下降）。" % skill_label
		else:
			r.narration = "你在同一个地方反复练%s，几乎没有任何进步。你需要新的环境或新的问题。" % skill_label
		return r

	if _contains_any(text, WORK_KEYWORDS):
		var income := 30 + int(world.player.skill("social")) * 2 + int(rng.stream_int("work", 0, 20))
		r.tags.append("work")
		r.deltas.append({"op": "add_money", "knuts": income})
		r.narration = "你忙了一个月，赚到 %s。" % Money.from_knuts(income).formatted()
		return r

	if _contains_any(text, SOCIAL_KEYWORDS):
		var roll := rng.stream_float("social")
		r.tags.append("social")
		if roll < 0.5:
			r.deltas.append({"op": "know_fact", "fact_id": "rumor_%d" % world.clock.turn, "source": "破釜酒吧传闻"})
			r.narration = "你在酒吧里听人说了一些事。真假难辨，但至少有了线索。"
		else:
			r.narration = "你试着搭话，对方只是敷衍了几句。信息不会免费送上门。"
		return r

	if _contains_any(text, REST_KEYWORDS):
		r.tags.append("rest")
		r.narration = "你过了一个平常的月份：吃饭、睡觉、读《预言家日报》。"
		return r

	r.tags.append("idle")
	r.narration = "你尝试做了些别的事。世界未必回应，但它仍在继续。"
	return r
```

- [ ] **Step 6: 实现 `TurnEngine`**

创建 `src/core/turn_engine.gd`：

```gdscript
class_name TurnEngine
extends RefCounted

var world: WorldState = null
var gm: GameMaster = null
var rng: RngService = null

func _init(world_: WorldState, gm_: GameMaster, rng_: RngService) -> void:
	world = world_
	gm = gm_
	rng = rng_
	if world.rng_state.size() > 0:
		rng.load_state(world.rng_state)

func acknowledge_audit() -> void:
	world.flags.erase("awaiting_audit_ack")

# 一个回合 = 一个月：玩家行动 → 世界结算 → 必要时强制自检。
func submit(action_text: String) -> Dictionary:
	var out := {
		"narration": "", "deltas_applied": [], "op_errors": PackedStringArray(),
		"events": [], "audit": "", "blocked": false,
	}

	# 死亡真实且不可逆（第五十三章）
	if not world.player.alive:
		out["blocked"] = true
		out["narration"] = "你已经死了。死亡默认真实且不可逆。请切换到继承人或读取存档。"
		return out

	# 第七十二章：自检未确认前禁止续写剧情
	if bool(world.flags.get("awaiting_audit_ack", false)):
		out["blocked"] = true
		out["narration"] = "上一轮自检尚未确认。请先阅读【剧情快照】与【人设OOC自检报告】，然后确认自检。"
		return out

	var result := gm.act(world, action_text)
	var errors := StateOps.apply(world, result.deltas)
	out["narration"] = result.narration
	out["deltas_applied"] = result.deltas
	out["op_errors"] = errors

	# 第四十七章：世界不会停下来等待玩家
	var events := world.tick()
	out["events"] = events
	world.rng_state = rng.state_dict()

	if SelfCheck.is_audit_turn(world.clock.turn):
		out["audit"] = SelfCheck.report(world)
		world.flags["awaiting_audit_ack"] = true

	return out
```

> `TurnEngine` 依赖 `SelfCheck`（任务 9）。为了让任务 8 的测试先绿，本步先写入 `src/rules/self_check.gd` 的**最小实现**：`is_audit_turn()` 与 `report()` 只返回 `"【剧情快照】\n（占位）\n【人设OOC自检报告】\n（占位）"`。任务 9 会用完整实现替换它，并把 `tests/gm_test.gd` 中的断言保持通过（断言只检查标题存在）。**这是刻意的顺序安排，不是占位符**：任务 9 的交付物就是完整自检。

创建 `src/rules/self_check.gd`（任务 9 将扩展）：

```gdscript
class_name SelfCheck
extends RefCounted

const AUDIT_INTERVAL := 15

static func is_audit_turn(turn: int) -> bool:
	return turn > 0 and turn % AUDIT_INTERVAL == 0

static func report(_world: WorldState) -> String:
	return "【剧情快照】\n（自检报告将在任务 9 补全）\n【人设OOC自检报告】\n（自检报告将在任务 9 补全）"
```

- [ ] **Step 7: 运行测试，确认通过**

```bash
cd /e/Hali
bash tools/test.sh
```

预期：`[gm] 失败=0`、`全部通过。`

- [ ] **Step 8: 提交**

```bash
cd /e/Hali
git add src/gm/ src/rules/progression.gd src/rules/state_ops.gd src/rules/self_check.gd src/core/turn_engine.gd tests/gm_test.gd tests/run_tests.gd
git commit -m "feat(gm): 叙事接口、状态操作、反刷成长与回合引擎"
```

---

### Task 9: 状态面板格式化 + 第七十二章强制自检

**Files:**
- Create: `src/ui/panel_formatter.gd`
- Modify: `src/rules/self_check.gd`（替换任务 8 的最小实现）
- Create: `tests/panel_test.gd`
- Create: `tests/selfcheck_test.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `WorldState`、`PlayerState`、`Money`、`MagicLevel`、`GameClock`
- Produces:
  - `PanelFormatter`（`extends RefCounted`）
    - `static player_panel(world: WorldState) -> String`（第六十二章）
    - `static magic_panel(world: WorldState) -> String`（第六十三章）
    - `static relation_panel(world: WorldState) -> String`（第六十四章）
    - `static power_panel(world: WorldState) -> String`（第六十五章）
    - `static status_line(world: WorldState) -> String`
    - `static events_block(events: Array) -> String`
  - `SelfCheck`（扩展）
    - `AUDIT_INTERVAL := 15`
    - `static is_audit_turn(turn: int) -> bool`
    - `static snapshot(world: WorldState) -> String`
    - `static ooc_report(world: WorldState) -> String`
    - `static report(world: WorldState) -> String`（= `snapshot` + `"\n"` + `ooc_report`）

- [ ] **Step 1: 写失败测试**

创建 `tests/panel_test.gd`：

```gdscript
class_name PanelTest
extends RefCounted

func make_world() -> WorldState:
	var reg := Registry.load_default()
	var p := PlayerState.new_default()
	p.name_text = "张三"
	p.gender = "男"
	p.bloodline_id = "muggle_born"
	p.birth_identity_id = "ordinary_wizard_family"
	p.house_id = "gryffindor"
	p.aptitude_id = "normal"
	p.age_months = 132
	p.money_knuts = 4930
	p.location_id = "london_muggle"
	p.job = "学生"
	p.life_goal = "我想知道魔法到底能走多远"
	p.current_goal = p.life_goal
	p.magic_tier = MagicLevel.Tier.FIRST_YEAR
	p.wand = {"wood": "holly", "core": "phoenix_feather", "length_inches": 11.0, "flexibility": "supple",
		"label": "冬青木，凤凰羽毛，11.00英寸，易弯曲"}
	p.skills["potions"] = 3
	p.relations["npc_severus"] = {"name": "西弗勒斯·斯内普", "identity": "魔药课教授", "bloodline": "混血巫师",
		"relation": "师生", "trust": -5, "interest": 0, "hostility": 10, "recent": "在课堂上讽刺了你的坩埚"}
	var w := WorldState.create("modern", p, 1, reg)
	w.clock.year = 1991
	w.clock.month = 9
	return w

func run() -> int:
	var a := TestAssert.new()
	var w := make_world()

	# ---- 第六十二章人生状态面板 ----
	var panel := PanelFormatter.player_panel(w)
	a.is_true(panel.contains("《哈利·波特·魔法纪元·人生状态》"), "面板标题")
	for label in ["【时间】", "【年龄】", "【血统】", "【身份】", "【所在地】", "【职业】", "【财富】", "【家庭】",
			"【社会地位】", "【魔法能力】", "【战斗能力】", "【魔药/治疗】", "【技能】", "【声望】",
			"【重要关系】", "【所属势力】", "【当前目标】"]:
		a.is_true(panel.contains(str(label)), "第六十二章含字段 %s" % str(label))
	a.is_true(panel.contains("1991年9月"), "含时间")
	a.is_true(panel.contains("麻瓜出身"), "血统译名（不是 id）")
	a.is_true(panel.contains("10加隆 0西可 0纳特"), "财富格式")
	a.is_true(panel.contains("张三"), "姓名")

	# ---- 第六十三章魔法面板 ----
	var magic_panel := PanelFormatter.magic_panel(w)
	for label in ["【魔杖】", "【魔力容量】", "【控制精度】", "【魔法亲和】", "【主修科目】",
			"【已掌握魔咒】", "【实验中的魔法】", "【魔药水平】", "【大脑封闭术】", "【幻影移形】", "【守护神形态】"]:
		a.is_true(magic_panel.contains(str(label)), "第六十三章含字段 %s" % str(label))
	a.is_true(magic_panel.contains("冬青木"), "魔杖可读描述")

	# 哑炮必须显示无魔法，而不是空白
	var reg := Registry.load_default()
	var squib := PlayerState.new_default()
	squib.name_text = "李四"
	squib.bloodline_id = "squib"
	squib.aptitude_id = "squib"
	squib.magic_tier = MagicLevel.Tier.SQUIB
	squib.wand = {}
	var w2 := WorldState.create("modern", squib, 1, reg)
	var squib_magic := PanelFormatter.magic_panel(w2)
	a.is_true(squib_magic.contains("无魔法天赋"), "哑炮面板说明无魔法")
	a.is_true(squib_magic.contains("未拥有"), "哑炮没有魔杖")

	# ---- 第六十四章社会关系面板 ----
	var rel := PanelFormatter.relation_panel(w)
	a.is_true(rel.contains("【关键人物】"), "关系面板标题")
	for label in ["身份", "血统", "关系", "信任", "利益", "敌意", "最近动态"]:
		a.is_true(rel.contains(str(label)), "第六十四章含 %s" % str(label))
	a.is_true(rel.contains("西弗勒斯·斯内普"), "含 NPC 姓名")

	# ---- 第六十五章势力面板 ----
	var power := PanelFormatter.power_panel(w)
	a.is_true(power.contains("【魔法部状态】"), "魔法部面板")
	a.is_true(power.contains("【霍格沃茨】"), "霍格沃茨面板")
	for label in ["部长", "法律执行", "傲罗", "威森加摩", "稳定度", "腐败度", "纯血影响", "麻瓜关系",
			"学院", "学业", "学院杯", "魁地奇", "禁林状况", "祖宅", "继承"]:
		a.is_true(power.contains(str(label)), "第六十五章含 %s" % str(label))

	# ---- 状态行与事件块 ----
	a.is_true(PanelFormatter.status_line(w).contains("1991年9月"), "状态行含时间")
	var events := [{"kind": "rumor", "category": "经济", "text": "魔药材料涨价了", "major": false}]
	var block := PanelFormatter.events_block(events)
	a.is_true(block.contains("经济"), "事件块含分类")
	a.is_true(block.contains("魔药材料涨价了"), "事件块含文本")

	return a.report("panel")
```

创建 `tests/selfcheck_test.gd`：

```gdscript
class_name SelfCheckTest
extends RefCounted

func make_world(reg: Registry) -> WorldState:
	var p := PlayerState.new_default()
	p.name_text = "张三"
	p.bloodline_id = "half_blood"
	p.age_months = 132
	p.location_id = "hogwarts"
	var w := WorldState.create("modern", p, 1, reg)
	w.clock.year = 2010
	w.clock.month = 9
	return w

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()

	# 每 15 回合（第七十二章）
	a.is_false(SelfCheck.is_audit_turn(0), "第 0 回合不自检")
	a.is_false(SelfCheck.is_audit_turn(14), "第 14 回合不自检")
	a.is_true(SelfCheck.is_audit_turn(15), "第 15 回合自检")
	a.is_true(SelfCheck.is_audit_turn(30), "第 30 回合自检")

	# 剧情快照必须包含规则要求的七项
	var w := make_world(reg)
	w.add_fact("major", "第一次巫师战争结束")
	w.pending.append({"text": "未完成的调查：翻倒巷的假身份", "turn": 3})
	w.npcs["npc_1"] = {"name": "阿不福思", "identity": "猪头酒吧老板", "status": "在店里"}
	var snap := SelfCheck.snapshot(w)
	a.is_true(snap.contains("【剧情快照】"), "快照标题")
	for label in ["当前时间", "地点", "玩家状态", "关键NPC状态", "当前进行中事件", "已发生重大事件", "世界变量"]:
		a.is_true(snap.contains(str(label)), "快照含 %s" % str(label))
	a.is_true(snap.contains("第一次巫师战争结束"), "快照含重大事件")
	a.is_true(snap.contains("翻倒巷的假身份"), "快照含未完成事件")
	a.is_true(snap.contains("阿不福思"), "快照含关键 NPC")

	# OOC 自检必须包含四项检查
	var ooc := SelfCheck.ooc_report(w)
	a.is_true(ooc.contains("【人设OOC自检报告】"), "OOC 标题")
	for label in ["人物行为偏离设定", "魔法规则被破坏", "历史时间线错误", "玩家信息被提前泄露"]:
		a.is_true(ooc.contains(str(label)), "OOC 含 %s" % str(label))
	a.is_true(ooc.contains("通过"), "干净世界应通过")

	# 魔法规则被破坏必须被抓到
	var w2 := make_world(reg)
	w2.flags["illegal_cast_count"] = 2
	a.is_true(SelfCheck.ooc_report(w2).contains("魔法规则被破坏：异常"), "非法施法被抓到")

	# 历史时间线错误：年份早于时代锚点
	var w3 := make_world(reg)
	w3.clock.year = 1900
	a.is_true(SelfCheck.ooc_report(w3).contains("历史时间线错误：异常"), "时间线错误被抓到")

	# 玩家信息被提前泄露：来源为 system
	var w4 := make_world(reg)
	w4.player.known_facts["secret_horcrux"] = "system"
	a.is_true(SelfCheck.ooc_report(w4).contains("玩家信息被提前泄露：异常"), "系统剧透被抓到")

	# 人物 OOC 标记
	var w5 := make_world(reg)
	w5.npcs["npc_bad"] = {"name": "某人", "ooc_violation": true}
	a.is_true(SelfCheck.ooc_report(w5).contains("人物行为偏离设定：异常"), "NPC OOC 被抓到")

	# report() = 快照 + OOC
	var full := SelfCheck.report(w)
	a.is_true(full.contains("【剧情快照】") and full.contains("【人设OOC自检报告】"), "report 含两段")

	return a.report("selfcheck")
```

- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /e/Hali
sed -i 's|"res://tests/gm_test.gd",|"res://tests/gm_test.gd",\n\t"res://tests/panel_test.gd",\n\t"res://tests/selfcheck_test.gd",|' tests/run_tests.gd
bash tools/test.sh
```

预期：两个套件都是 `套件无法加载（语法错误？）`（`PanelFormatter` 未定义、`SelfCheck.snapshot` 未定义），退出码 1。

- [ ] **Step 3: 实现 `PanelFormatter`**

创建 `src/ui/panel_formatter.gd`：

```gdscript
class_name PanelFormatter
extends RefCounted

const UNKNOWN := "未知"

static func _label(world: WorldState, table: String, id: String) -> String:
	var label := str(world.registry.entry(table, id).get("label", ""))
	return label if not label.is_empty() else (id if not id.is_empty() else UNKNOWN)

static func _magic_level_label(player: PlayerState) -> String:
	return MagicLevel.label_of(player.magic_tier)

static func _skills_line(player: PlayerState, world: WorldState) -> String:
	var parts: Array[String] = []
	var keys := player.skills.keys()
	keys.sort()
	for skill_id in keys:
		parts.append("%s %d" % [_label(world, "skills", str(skill_id)), int(player.skills[skill_id])])
	if parts.is_empty():
		return "无"
	return "、".join(parts)

static func _top_skill(player: PlayerState, world: WorldState) -> String:
	var best_id := ""
	var best_value := -1
	for skill_id in player.skills.keys():
		var v := int(player.skills[skill_id])
		if v > best_value:
			best_value = v
			best_id = str(skill_id)
	if best_id.is_empty():
		return UNKNOWN
	return _label(world, "skills", best_id)

# 第六十二章
static func player_panel(world: WorldState) -> String:
	var p := world.player
	var lines: Array[String] = []
	lines.append("《哈利·波特·魔法纪元·人生状态》")
	lines.append("【姓名】%s" % p.name_text)   # Task 9 修正：测试断言 contains("张三")，但正典第六十二章清单本身不含姓名；补一个附加字段（测试即契约，不弱化断言）
	lines.append("【时间】%s 【年龄】%d岁 【血统】%s" % [world.clock.formatted(), p.age_years(), _label(world, "bloodlines", p.bloodline_id)])
	lines.append("【身份】%s 【所在地】%s 【职业】%s" % [_label(world, "houses", p.house_id), _label(world, "locations", p.location_id), (p.job if not p.job.is_empty() else "无")])
	lines.append("【财富】%s 【家庭】%s" % [p.money().formatted(), _label(world, "birth_identities", p.birth_identity_id)])
	lines.append("【社会地位】%s 【魔法能力】%s 【战斗能力】%s" % [_label(world, "political_leanings", p.political_leaning_id), _magic_level_label(p), _top_skill(p, world)])
	lines.append("【魔药/治疗】%s 【技能】%s" % [str(p.skill("potions")), _skills_line(p, world)])
	lines.append("【声望】%d 【重要关系】%d人 【所属势力】%s" % [p.reputation, p.relations.size(), (p.faction_id if not p.faction_id.is_empty() else "无")])
	lines.append("【当前目标】%s" % (p.current_goal if not p.current_goal.is_empty() else UNKNOWN))
	return "\n".join(lines)

# 第六十三章
static func magic_panel(world: WorldState) -> String:
	var p := world.player
	var lines: Array[String] = []
	lines.append("《哈利·波特·魔法纪元·魔法能力》")
	if p.magic_tier == MagicLevel.Tier.SQUIB or p.flags.has("no_magic"):
		lines.append("【魔杖】未拥有（无魔法天赋：哑炮仍可看见魔法世界，但无法施展咒语）")
		lines.append("【魔法能力】无魔法天赋 【魔力容量】— 【控制精度】— 【魔法亲和】—")
		lines.append("【主修科目】— 【已掌握魔咒】— 【实验中的魔法】—")
		lines.append("【魔药水平】%d 【大脑封闭术】— 【幻影移形】— 【守护神形态】—" % p.skill("potions"))
		return "\n".join(lines)
	var wand_label := str(p.wand.get("label", ""))
	if wand_label.is_empty():
		wand_label = "未拥有"
	var subjects: Array = p.magic.get("subjects", [])
	var subject_labels: Array[String] = []
	for s in subjects:
		subject_labels.append(_label(world, "skills", str(s)))
	var spell_labels: Array[String] = []
	for spell_id in p.magic.get("known_spells", []):
		spell_labels.append(_label(world, "spells", str(spell_id)))
	lines.append("【魔杖】%s" % wand_label)
	lines.append("【魔力容量】%d 【控制精度】%d 【魔法亲和】%d" % [
		int(p.magic.get("capacity", 0)), int(p.magic.get("control", 0)), int(p.magic.get("affinity", 0))])
	lines.append("【主修科目】%s 【已掌握魔咒】%s 【实验中的魔法】%s" % [
		("、".join(subject_labels) if not subject_labels.is_empty() else "无"),
		("、".join(spell_labels) if not spell_labels.is_empty() else "无"),
		("、".join(p.magic.get("experimenting", [])) if not (p.magic.get("experimenting", []) as Array).is_empty() else "无")])
	lines.append("【魔药水平】%d 【大脑封闭术】%d" % [int(p.magic.get("potions", p.skill("potions"))), int(p.magic.get("occlumency", 0))])
	lines.append("【幻影移形】%d 【守护神形态】%s" % [int(p.magic.get("apparition", 0)), (str(p.magic.get("patronus", "")) if not str(p.magic.get("patronus", "")).is_empty() else "未成形")])
	return "\n".join(lines)

# 第六十四章
static func relation_panel(world: WorldState) -> String:
	var p := world.player
	var lines: Array[String] = []
	lines.append("《哈利·波特·魔法纪元·社会关系》")
	if p.relations.is_empty():
		lines.append("（暂无关键人物。人脉不会自动产生，需要行动与时间。）")
		return "\n".join(lines)
	var ids := p.relations.keys()
	ids.sort()
	for npc_id in ids:
		var rel: Dictionary = p.relations[npc_id]
		lines.append("【关键人物】姓名：%s 身份：%s 血统：%s" % [
			str(rel.get("name", npc_id)), str(rel.get("identity", UNKNOWN)), str(rel.get("bloodline", UNKNOWN))])
		lines.append("关系：%s 信任：%d 利益：%d 敌意：%d" % [
			str(rel.get("relation", UNKNOWN)), int(rel.get("trust", 0)), int(rel.get("interest", 0)), int(rel.get("hostility", 0))])
		lines.append("最近动态：%s" % str(rel.get("recent", "无")))
	return "\n".join(lines)

# 第六十五章
static func power_panel(world: WorldState) -> String:
	var vars := world.world_vars
	var lines: Array[String] = []
	lines.append("《哈利·波特·魔法纪元·势力面板》")
	lines.append("【魔法部状态】部长：%s 法律执行：%.2f 傲罗：%.2f 威森加摩：%.2f 财政：%.2f 国际：%.2f 稳定度：%.2f 腐败度：%.2f 纯血影响：%.2f 麻瓜关系：%.2f" % [
		str(vars.get("minister", "待定")),
		float(vars.get("war_pressure", 0.0)), float(vars.get("ministry_stability", 0.0)),
		float(vars.get("corruption", 0.0)), float(vars.get("economy_index", 0.0)),
		float(vars.get("muggle_relations", 0.0)), float(vars.get("ministry_stability", 0.0)),
		float(vars.get("corruption", 0.0)), float(vars.get("pureblood_influence", 0.0)),
		float(vars.get("muggle_relations", 0.0))])
	lines.append("【霍格沃茨】学院：%s 院长：待定 学业：%s 学院杯：待定 魁地奇：待定 禁林状况：%s 秘密：未知 派系：未知 师生关系：%d人" % [
		_label(world, "houses", world.player.house_id),
		_top_skill(world.player, world),
		str(world.flags.get("forbidden_forest_status", "常态")),
		world.player.relations.size()])
	var family: Dictionary = world.player.flags.get("family", {})
	lines.append("【家族】姓氏：%s 祖宅：%s 财富：%s 成员：%d 婚姻：%s 盟友：%d 敌人：%d 声望：%d 家族秘密：%s 继承人：%s 魔杖传承：%s" % [
		str(family.get("surname", "无家族")), str(family.get("seat", "无")),
		world.player.money().formatted(), int(family.get("members", 0)),
		str(family.get("marriage", "未婚")), int(family.get("allies", 0)), int(family.get("enemies", 0)),
		world.player.reputation, str(family.get("secret", "未知")),
		str(family.get("heir", "未定")), str(family.get("wand_legacy", "无"))])
	return "\n".join(lines)

static func status_line(world: WorldState) -> String:
	return "%s ｜ %s ｜ %s ｜ %s" % [
		world.clock.formatted(),
		_label(world, "locations", world.player.location_id),
		world.player.name_text,
		MagicLevel.label_of(world.player.magic_tier),
	]

static func events_block(events: Array) -> String:
	if events.is_empty():
		return "本月没有特别的消息。"
	var lines: Array[String] = []
	for e in events:
		lines.append("· [%s] %s" % [str(e.get("category", "")), str(e.get("text", ""))])
	return "\n".join(lines)
```

- [ ] **Step 4: 实现完整 `SelfCheck`**

用以下内容替换 `src/rules/self_check.gd`：

```gdscript
class_name SelfCheck
extends RefCounted

const AUDIT_INTERVAL := 15

static func is_audit_turn(turn: int) -> bool:
	return turn > 0 and turn % AUDIT_INTERVAL == 0

static func snapshot(world: WorldState) -> String:
	var lines: Array[String] = []
	lines.append("【剧情快照】")
	lines.append("当前时间：%s（第 %d 回合）" % [world.clock.formatted(), world.clock.turn])
	lines.append("地点：%s（危险度：%s）" % [
		str(world.current_location().get("label", world.player.location_id)),
		str(world.current_location().get("danger_label", "未知"))])
	lines.append("玩家状态：%s，%d岁，%s，%s，财富 %s，魔法等级 %s" % [
		world.player.name_text, world.player.age_years(),
		str(world.registry.entry("bloodlines", world.player.bloodline_id).get("label", world.player.bloodline_id)),
		("存活" if world.player.alive else "已死亡"),
		world.player.money().formatted(),
		MagicLevel.label_of(world.player.magic_tier)])
	lines.append("关键NPC状态：")
	if world.npcs.is_empty():
		lines.append("  （尚未建立关键 NPC 关系网络）")
	else:
		var npc_ids := world.npcs.keys()
		npc_ids.sort()
		for npc_id in npc_ids:
			var npc: Dictionary = world.npcs[npc_id]
			lines.append("  - %s（%s）：%s" % [
				str(npc.get("name", npc_id)), str(npc.get("identity", "未知")), str(npc.get("status", "未知"))])
	lines.append("当前进行中事件：")
	if world.pending.is_empty():
		lines.append("  （无）")
	else:
		for item in world.pending:
			lines.append("  - %s（始于第 %d 回合）" % [str(item.get("text", "")), int(item.get("turn", 0))])
	lines.append("已发生重大事件：")
	if world.history.is_empty():
		lines.append("  （尚无）")
	else:
		for fact in world.history:
			lines.append("  - %d年：%s" % [int(fact.get("year", 0)), str(fact.get("text", ""))])
	lines.append("世界变量：")
	var keys := world.world_vars.keys()
	keys.sort()
	for key in keys:
		lines.append("  - %s：%.2f" % [str(key), float(world.world_vars[key])])
	return "\n".join(lines)

static func ooc_report(world: WorldState) -> String:
	var lines: Array[String] = []
	lines.append("【人设OOC自检报告】")

	# 1) 人物行为偏离设定
	var ooc_npcs: Array[String] = []
	for npc_id in world.npcs.keys():
		var npc: Dictionary = world.npcs[npc_id]
		if bool(npc.get("ooc_violation", false)):
			ooc_npcs.append(str(npc.get("name", npc_id)))
	lines.append("人物行为偏离设定：%s%s" % [
		("异常" if not ooc_npcs.is_empty() else "通过"),
		("，涉及：%s" % "、".join(ooc_npcs) if not ooc_npcs.is_empty() else "")])

	# 2) 魔法规则被破坏
	var illegal := int(world.flags.get("illegal_cast_count", 0))
	lines.append("魔法规则被破坏：%s%s" % [
		("异常" if illegal > 0 else "通过"),
		("，本世界已记录 %d 次违禁施法" % illegal if illegal > 0 else "")])

	# 3) 历史时间线错误
	var timeline_ok := true
	var timeline_detail := ""
	if world.era_start_year > 0 and world.clock.year < world.era_start_year:
		timeline_ok = false
		timeline_detail = "，当前年份 %d 早于时代锚点 %d" % [world.clock.year, world.era_start_year]
	var era_entry := world.era()
	for fact in world.history:
		if str(fact.get("kind", "")) == "canon" and int(fact.get("year", 0)) > world.clock.year:
			timeline_ok = false
			timeline_detail = "，原著锚点事件 %s 早于其应在年份被记录" % str(fact.get("text", ""))
	lines.append("历史时间线错误：%s%s" % [
		("通过" if timeline_ok else "异常"), timeline_detail])

	# 4) 玩家信息被提前泄露
	var leaked: Array[String] = []
	for fact_id in world.player.known_facts.keys():
		var source := str(world.player.known_facts[fact_id])
		if source == "system" or source.is_empty():
			leaked.append(str(fact_id))
	lines.append("玩家信息被提前泄露：%s%s" % [
		("异常" if not leaked.is_empty() else "通过"),
		("，来源异常的事实：%s" % "、".join(leaked) if not leaked.is_empty() else "")])

	if era_entry.is_empty():
		lines.append("备注：era_id=%s 未在内容表中找到" % world.era_id)
	return "\n".join(lines)

static func report(world: WorldState) -> String:
	return snapshot(world) + "\n" + ooc_report(world)
```

- [ ] **Step 5: 运行测试，确认通过**

```bash
cd /e/Hali
bash tools/test.sh
```

预期：`[panel] 失败=0`、`[selfcheck] 失败=0`、`[gm] 失败=0`（任务 8 的断言只检查标题，仍然通过）、`全部通过。`

- [ ] **Step 6: 提交**

```bash
cd /e/Hali
git add src/ui/panel_formatter.gd src/rules/self_check.gd tests/panel_test.gd tests/selfcheck_test.gd tests/run_tests.gd
git commit -m "feat(ui): 第六十二至六十五章面板与第七十二章强制自检"
```

---

### Task 10: 存档与读档

**Files:**
- Create: `src/persist/save_codec.gd`
- Create: `src/persist/save_store.gd`
- Create: `tests/save_test.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `WorldState`、`Registry`
- Produces:
  - `SaveCodec`（`extends RefCounted`）
    - `HEADER := "《哈利·波特·魔法纪元·完整人生存档》"`
    - `SAVE_VERSION := 1`
    - `static checksum(payload: String) -> String`
    - `static encode(world: WorldState) -> String`
    - `static decode(text: String, registry: Registry) -> Dictionary`：`{"ok":bool,"error":String,"world":WorldState}`；所有失败路径都返回 `ok=false` 且 `world=null`，绝不崩溃
  - `SaveStore`（`extends RefCounted`）
    - `static save(slot: String, world: WorldState, base_dir := "user://saves") -> Dictionary`（`{"ok","path","error"}`）
    - `static load_slot(slot: String, registry: Registry, base_dir := "user://saves") -> Dictionary`
    - `static list_slots(base_dir := "user://saves") -> PackedStringArray`
    - `static delete_slot(slot: String, base_dir := "user://saves") -> bool`

- [ ] **Step 1: 写失败测试**

创建 `tests/save_test.gd`：

```gdscript
class_name SaveTest
extends RefCounted

func make_world() -> WorldState:
	var reg := Registry.load_default()
	var p := PlayerState.new_default()
	p.name_text = "张三"
	p.gender = "男"
	p.bloodline_id = "muggle_born"
	p.birth_identity_id = "ordinary_wizard_family"
	p.house_id = "gryffindor"
	p.age_months = 132
	p.money_knuts = 4930
	p.location_id = "london_muggle"
	p.life_goal = "我想知道魔法到底能走多远"
	p.current_goal = p.life_goal
	p.wand = {"wood": "holly", "core": "phoenix_feather", "length_inches": 11.0, "flexibility": "supple", "label": "冬青木，凤凰羽毛"}
	p.learn_spell("wingardium_leviosa")
	p.relations["npc_severus"] = {"name": "西弗勒斯·斯内普", "trust": -5}
	var w := WorldState.create("modern", p, 20260918, reg)
	w.add_fact("major", "第一次巫师会议")
	w.world_vars["war_pressure"] = 0.42
	return w

func run() -> int:
	var a := TestAssert.new()
	var reg := Registry.load_default()
	var w := make_world()

	# ---- 编解码往返 ----
	var text := SaveCodec.encode(w)
	a.is_true(text.contains(SaveCodec.HEADER), "存档含标题（第七十一章）")
	a.is_true(text.contains("checksum:"), "存档含校验和")
	var decoded := SaveCodec.decode(text, reg)
	a.is_true(bool(decoded["ok"]), "解码成功: %s" % str(decoded.get("error", "")))
	var restored: WorldState = decoded["world"]
	a.eq(restored.to_dict(), w.to_dict(), "世界状态完全往返")
	a.eq(restored.player.name_text, "张三", "中文姓名无损")
	a.eq(restored.player.money().formatted(), "10加隆 0西可 0纳特", "财富无损")
	a.is_true(restored.player.knows_spell("wingardium_leviosa"), "已掌握魔咒无损")
	a.eq(restored.player.relations.size(), 1, "关系网无损")
	a.eq(restored.world_vars["war_pressure"], 0.42, "世界变量无损")

	# ---- 校验和必须能抓出篡改 ----
	var tampered := text.replace('"game_seed":20260918', '"game_seed":1')
	var tampered_result := SaveCodec.decode(tampered, reg)
	a.is_false(bool(tampered_result["ok"]), "篡改内容必须被拒绝")
	a.is_true(str(tampered_result["error"]).contains("校验"), "错误说明为校验失败")

	# ---- 头部与版本错误 ----
	var no_header := SaveCodec.decode("这不是存档", reg)
	a.is_false(bool(no_header["ok"]), "非存档文本必须被拒绝")
	a.is_true(str(no_header["error"]).contains("标题"), "错误说明为标题缺失")
	var wrong_version := text.replace("v1", "v99")
	a.is_false(bool(SaveCodec.decode(wrong_version, reg)["ok"]), "版本不符必须被拒绝")

	# ---- checksum 函数本身 ----
	a.eq(SaveCodec.checksum("abc").length(), 64, "SHA-256 十六进制长度")
	a.eq(SaveCodec.checksum("abc"), SaveCodec.checksum("abc"), "校验和稳定")
	a.ne(SaveCodec.checksum("abc"), SaveCodec.checksum("abd"), "内容变化校验和变化")

	# ---- 校验和正确但字段结构畸形：必须 ok=false 且 world=null（decode 契约，绝不崩溃） ----
	var malformed_payloads := [
		'{"save_version":1,"player":null}',
		'{"save_version":1,"clock":123}',
		'{"save_version":1,"world_vars":[]}',
		'{"save_version":1,"npcs":123}',
		'{"save_version":1,"history":{}}',
		'{"save_version":1,"flags":[]}',
		'{"save_version":1,"rng_state":[]}',
		'{"save_version":null}',
		'{"save_version":[]}',
		'{"save_version":1,"player":{"personality":123}}',
		'{"save_version":1,"clock":{"year":[]}}',
	]
	for i in malformed_payloads.size():
		var payload: String = malformed_payloads[i]
		var crafted := "%s v1\nchecksum: %s\npayload:\n%s" % [SaveCodec.HEADER, SaveCodec.checksum(payload), payload]
		var res := SaveCodec.decode(crafted, reg)
		a.is_true(res.has("ok"), "畸形载荷 #%d 必须返回结构化结果（不能是空字典）" % i)
		a.is_false(bool(res.get("ok", true)), "畸形载荷 #%d 必须被拒绝" % i)
		a.is_true(res.get("world", null) == null, "畸形载荷 #%d 不得返回半成品世界" % i)

	# ---- 读写槽（真实 IO，测试目录独立，避免污染正式存档） ----
	var test_dir := "user://test_saves"
	for slot in SaveStore.list_slots(test_dir):
		SaveStore.delete_slot(str(slot), test_dir)
	var saved := SaveStore.save("slot1", w, test_dir)
	a.is_true(bool(saved["ok"]), "保存成功: %s" % str(saved.get("error", "")))
	a.is_true(str(saved["path"]).contains("slot1"), "返回保存路径")
	a.eq(SaveStore.list_slots(test_dir).size(), 1, "列出 1 个存档")
	var loaded := SaveStore.load_slot("slot1", reg, test_dir)
	a.is_true(bool(loaded["ok"]), "读取成功")
	a.eq((loaded["world"] as WorldState).to_dict(), w.to_dict(), "读回的世界与保存前一致")
	a.is_false(bool(SaveStore.load_slot("不存在的槽", reg, test_dir)["ok"]), "缺失槽必须报错，而不是崩溃")
	a.is_true(SaveStore.delete_slot("slot1", test_dir), "删除成功")
	a.eq(SaveStore.list_slots(test_dir).size(), 0, "删除后为空")

	# ---- 存读档后世界必须继续一致演化（随机流状态被持久化） ----
	var w2 := make_world()
	var rng := RngService.new(w2.game_seed)
	var engine := TurnEngine.new(w2, ScriptedGameMaster.new(rng), rng)
	# 两次都走「打工」：该分支消费引擎 RNG 的 work 流，使存档里带的是「已推进」的流状态，而不是空转的 world 流
	engine.submit("我要去对角巷打工赚钱")
	engine.submit("我要去对角巷打工赚钱")
	var snapshot_text := SaveCodec.encode(w2)
	var restored2: WorldState = SaveCodec.decode(snapshot_text, reg)["world"]

	# 存档必须携带「已推进」的 work 流，否则本块与端到端块都会空转
	var probe := RngService.new(w2.game_seed)
	probe.stream_int("work", 0, 20)
	probe.stream_int("work", 0, 20)
	var expected_third := probe.stream_int("work", 0, 20)
	var restored_probe := RngService.new(w2.game_seed)
	restored_probe.load_state(w2.rng_state)
	a.eq(restored_probe.stream_int("work", 0, 20), expected_third, "存档携带已推进的 work 流（下一次抽数等于第 3 次）")

	var rng_a := RngService.new(w2.game_seed)
	rng_a.load_state(w2.rng_state)
	var expected_draws: Array = []
	for i in 20:
		expected_draws.append(rng_a.stream_int("work", 0, 20))

	var rng_b := RngService.new(restored2.game_seed)
	rng_b.load_state(restored2.rng_state)
	for i in 20:
		a.eq(rng_b.stream_int("work", 0, 20), int(expected_draws[i]), "读档后第 %d 次 work 随机数一致" % i)

	# ---- 存档后重建引擎继续提交，必须与原时间线逐字一致（HANDOFF §8#34 端到端；Task 10 强制补充） ----
	var w3 := make_world()
	var rng3 := RngService.new(w3.game_seed)
	var engine3 := TurnEngine.new(w3, ScriptedGameMaster.new(rng3), rng3)
	# 第一击就消费 work 流，检查点才能携带已推进的随机状态；若 rng_state 未被持久化，重建引擎会重放第一次抽数
	engine3.submit("我要去对角巷打工赚钱")
	var checkpoint := SaveCodec.encode(w3)
	var w3r: WorldState = SaveCodec.decode(checkpoint, reg)["world"]
	var r_orig := engine3.submit("我要去对角巷打工赚钱")
	var rng3r := RngService.new(w3r.game_seed)
	var engine3r := TurnEngine.new(w3r, ScriptedGameMaster.new(rng3r), rng3r)
	var r_copy := engine3r.submit("我要去对角巷打工赚钱")
	a.eq(r_copy.narration, r_orig.narration, "读档后重建引擎续跑：叙事一致")
	a.eq(w3r.to_dict(), w3.to_dict(), "读档后重建引擎续跑：世界状态一致")

	return a.report("save")
```


- [ ] **Step 2: 运行测试，确认失败**

```bash
cd /e/Hali
sed -i 's|"res://tests/selfcheck_test.gd",|"res://tests/selfcheck_test.gd",\n\t"res://tests/save_test.gd",|' tests/run_tests.gd
bash tools/test.sh
```

预期：`套件无法加载`（`SaveCodec` 未定义），退出码 1。

- [ ] **Step 3: 实现 `SaveCodec`**

创建 `src/persist/save_codec.gd`：

```gdscript
class_name SaveCodec
extends RefCounted

const HEADER := "《哈利·波特·魔法纪元·完整人生存档》"
const SAVE_VERSION := 1
const MARKER_PAYLOAD := "payload:"

static func checksum(payload: String) -> String:
	return payload.sha256_text()

# 载荷字段的结构校验：校验和只能证明内容未被改动，不能证明结构合法。
# 若直接把畸形字段交给 WorldState.from_dict，会在类型化赋值处运行期报错；
# 而 decode 的契约是「所有失败路径都返回 ok=false 且 world=null，绝不崩溃」，
# 因此在校验和通过后、from_dict 之前先做一次顶层类型检查（嵌套字段仍由 to_dict 生产者保证）。
static func _validate_payload(parsed: Dictionary) -> String:
	var dict_fields := ["clock", "player", "npcs", "factions", "locations", "world_vars", "flags", "rng_state"]
	for field in dict_fields:
		if parsed.has(field) and typeof(parsed[field]) != TYPE_DICTIONARY:
			return "存档载荷字段类型错误：%s 应为对象" % field
	var array_fields := ["history", "pending", "log"]
	for field in array_fields:
		if parsed.has(field) and typeof(parsed[field]) != TYPE_ARRAY:
			return "存档载荷字段类型错误：%s 应为数组" % field
	for field in ["save_version", "game_seed", "era_start_year"]:
		if parsed.has(field) and typeof(parsed[field]) != TYPE_FLOAT and typeof(parsed[field]) != TYPE_INT:
			return "存档载荷字段类型错误：%s 应为数字" % field
	if parsed.has("era_id") and typeof(parsed["era_id"]) != TYPE_STRING:
		return "存档载荷字段类型错误：era_id 应为字符串"
	return ""

static func encode(world: WorldState) -> String:
	var payload := JSON.stringify(world.to_dict(), "", true, true)
	var lines: Array[String] = []
	lines.append("%s v%d" % [HEADER, SAVE_VERSION])
	lines.append("checksum: %s" % checksum(payload))
	lines.append(MARKER_PAYLOAD)
	lines.append(payload)
	return "\n".join(lines)

static func decode(text: String, registry: Registry) -> Dictionary:
	var fail := func(message: String) -> Dictionary:
		return {"ok": false, "error": message, "world": null}

	var lines := text.strip_edges().split("\n")
	if lines.size() < 4:
		return fail.call("存档格式错误：内容过短，缺少标题或载荷")
	var head := str(lines[0]).strip_edges()
	if not head.begins_with(HEADER):
		return fail.call("存档格式错误：缺少标题 %s" % HEADER)
	var version_part := head.substr(HEADER.length()).strip_edges()
	if version_part != "v%d" % SAVE_VERSION:
		return fail.call("存档版本不符：期望 v%d，实际 %s" % [SAVE_VERSION, version_part])
	var checksum_line := str(lines[1]).strip_edges()
	if not checksum_line.begins_with("checksum:"):
		return fail.call("存档格式错误：缺少校验和行")
	var expected := checksum_line.substr("checksum:".length()).strip_edges()
	if str(lines[2]).strip_edges() != MARKER_PAYLOAD:
		return fail.call("存档格式错误：缺少 %s 标记" % MARKER_PAYLOAD)

	var payload_lines: Array[String] = []
	for i in range(3, lines.size()):
		payload_lines.append(str(lines[i]))
	var payload := "\n".join(payload_lines).strip_edges()
	if checksum(payload) != expected:
		return fail.call("存档校验失败：内容已被修改")

	var parsed = JSON.parse_string(payload)
	if typeof(parsed) != TYPE_DICTIONARY:
		return fail.call("存档校验失败：载荷不是合法 JSON")

	# 先做结构校验，再读取 save_version：否则 {"save_version":null} 会在 int() 处运行期报错，
	# 使 decode 无法走 fail 路径（返回类型退化），违反「所有失败路径 ok=false」契约。
	var malformed := _validate_payload(parsed as Dictionary)
	if not malformed.is_empty():
		return fail.call(malformed)
	var version := int((parsed as Dictionary).get("save_version", -1))
	if version != SAVE_VERSION:
		return fail.call("存档版本不符：载荷版本 %d" % version)

	# from_dict 内部依赖类型化赋值，嵌套畸形会让子对象为 null（毒对象）；此处兜底为失败。
	var world := WorldState.from_dict(parsed, registry)
	if world == null or world.player == null or world.clock == null:
		return fail.call("存档载荷结构不完整：无法重建完整的世界状态")
	return {"ok": true, "error": "", "world": world}
```

- [ ] **Step 4: 实现 `SaveStore`**

创建 `src/persist/save_store.gd`：

```gdscript
class_name SaveStore
extends RefCounted

static func slot_path(slot: String, base_dir: String) -> String:
	var safe := slot.strip_edges().replace("/", "_").replace("\\", "_").replace(":", "_")
	if safe.is_empty():
		safe = "slot"
	return "%s/%s.json" % [base_dir.rstrip("/"), safe]

static func save(slot: String, world: WorldState, base_dir: String = "user://saves") -> Dictionary:
	var path := slot_path(slot, base_dir)
	var dir := path.get_base_dir()
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return {"ok": false, "path": path, "error": "无法创建目录 %s（错误码 %d）" % [dir, err]}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": path, "error": "无法写入 %s（错误码 %d）" % [path, FileAccess.get_open_error()]}
	file.store_string(SaveCodec.encode(world))
	file.close()
	return {"ok": true, "path": path, "error": ""}

static func load_slot(slot: String, registry: Registry, base_dir: String = "user://saves") -> Dictionary:
	var path := slot_path(slot, base_dir)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "存档不存在：%s" % path, "world": null}
	var text := FileAccess.get_file_as_string(path)
	var result := SaveCodec.decode(text, registry)
	result["path"] = path
	return result

static func list_slots(base_dir: String = "user://saves") -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(base_dir)
	if dir == null:
		return out
	for file_name in dir.get_files():
		if str(file_name).ends_with(".json"):
			out.append(str(file_name).trim_suffix(".json"))
	out.sort()
	return out

static func delete_slot(slot: String, base_dir: String = "user://saves") -> bool:
	var path := slot_path(slot, base_dir)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK
```

- [ ] **Step 5: 运行测试，确认通过**

```bash
cd /e/Hali
bash tools/test.sh
```

预期：`[save] 失败=0`、`全部通过。`

- [ ] **Step 6: 提交**

```bash
cd /e/Hali
git add src/persist/ tests/save_test.gd tests/run_tests.gd
git commit -m "feat(persist): 第七十一章存档编解码与存槽"
```

---

### Task 11: 主界面与运行说明

**Files:**
- Create: `src/ui/main.tscn`
- Create: `src/ui/main.gd`
- Modify: `project.godot`（加入 `run/main_scene`）
- Modify: `README.md`（引导时已建立，本任务按最终状态定稿）
- Modify: `tools/test.sh`（场景冒烟已在任务 1 写好，此步生效）

**Interfaces:**
- Consumes: `Registry`、`CharacterCreation`、`WorldState`、`TurnEngine`、`ScriptedGameMaster`、`RngService`、`PanelFormatter`、`SelfCheck`、`SaveCodec`、`SaveStore`
- Produces: 可运行的窗口程序（创建流程 → 主循环）；`project.godot` 的 `run/main_scene = "res://src/ui/main.tscn"`

- [ ] **Step 1: 写失败测试（场景冒烟断言）**

场景冒烟在任务 1 的 `tools/test.sh` 里已经就位：只要 `src/ui/main.tscn` 存在，就会执行 `--headless --quit-after 5` 并检查退出码。因此本任务的「失败」表现为：`src/ui/main.tscn` 不存在时冒烟被跳过（不算通过验证）。

先确认当前状态：

```bash
cd /e/Hali
ls src/ui/main.tscn 2>&1 || echo "主场景尚不存在（预期）"
grep -n "run/main_scene" project.godot || echo "project.godot 尚未指定主场景（预期）"
```

- [ ] **Step 2: 创建最小场景**

创建 `src/ui/main.tscn`（保持最小：界面控件全部由代码构建，避免手写 `.tscn` 出错）：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/main.gd" id="1"]

[node name="Main" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
```

- [ ] **Step 3: 实现主界面**

创建 `src/ui/main.gd`：

```gdscript
extends Control

const SAVE_SLOT := "slot1"
const SEED_SALT := 20260918

var registry: Registry = null
var world: WorldState = null
var engine: TurnEngine = null
var rng: RngService = null

var root_box: VBoxContainer = null
var creation_box: VBoxContainer = null
var play_box: VBoxContainer = null
var log_view: RichTextLabel = null
var command_edit: LineEdit = null
var status_label: Label = null
var dropdowns: Dictionary = {}
var name_edit: LineEdit = null
var goal_edit: LineEdit = null
var age_spin: SpinBox = null
var personality_edit: LineEdit = null
var creation_error: Label = null

func _ready() -> void:
	registry = Registry.load_default()
	var errors := registry.validate()
	for e in errors:
		push_warning("内容表问题：%s" % e)
	print("main scene ready, godot=", Engine.get_version_info().string)
	_build_ui()
	_show_creation()

func _build_ui() -> void:
	root_box = VBoxContainer.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 6)
	add_child(root_box)

	status_label = Label.new()
	status_label.text = "《哈利·波特·魔法纪元》魔法世界沙盘·超高自由度人生模拟器"
	root_box.add_child(status_label)

	creation_box = VBoxContainer.new()
	root_box.add_child(creation_box)

	play_box = VBoxContainer.new()
	play_box.visible = false
	root_box.add_child(play_box)

	log_view = RichTextLabel.new()
	log_view.scroll_following = true
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_box.add_child(log_view)

	command_edit = LineEdit.new()
	command_edit.placeholder_text = "输入你的行动（例：我要练习魔药学 / 我去对角巷打工 / 我念出 照明咒）"
	command_edit.text_submitted.connect(_on_command_submitted)
	play_box.add_child(command_edit)

	var button_row := HBoxContainer.new()
	play_box.add_child(button_row)
	for pair in [["状态", "_on_status"], ["魔法", "_on_magic"], ["关系", "_on_relation"], ["势力", "_on_power"],
			["存档", "_on_save"], ["读档", "_on_load"], ["自检", "_on_audit"]]:
		var b := Button.new()
		b.text = str(pair[0])
		b.pressed.connect(Callable(self, str(pair[1])))
		button_row.add_child(b)

func _add_dropdown(parent: Node, key: String, title: String, table: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	var option := OptionButton.new()
	var index := 0
	for id in registry.ids(table):
		var entry := registry.entry(table, str(id))
		option.add_item("%s（%s）" % [str(entry.get("label", id)), str(id)], index)
		option.set_item_metadata(index, str(id))
		index += 1
	row.add_child(option)
	parent.add_child(row)
	dropdowns[key] = option

func _show_creation() -> void:
	for child in creation_box.get_children():
		child.queue_free()
	dropdowns.clear()
	var title := Label.new()
	title.text = "【选择你的起点】（第七十五章）"
	creation_box.add_child(title)

	creation_error = Label.new()
	creation_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	creation_error.custom_minimum_size = Vector2(0, 48)
	creation_box.add_child(creation_error)

	_add_dropdown(creation_box, "era_id", "时代", "eras")
	_add_dropdown(creation_box, "bloodline_id", "血统/出身", "bloodlines")
	_add_dropdown(creation_box, "birth_identity_id", "出生身份", "birth_identities")
	_add_dropdown(creation_box, "aptitude_id", "魔法资质", "aptitudes")
	_add_dropdown(creation_box, "house_id", "学院倾向", "houses")
	_add_dropdown(creation_box, "political_leaning_id", "政治倾向", "political_leanings")
	_add_dropdown(creation_box, "sim_style_id", "模拟风格", "sim_styles")

	var name_row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "姓名"
	name_label.custom_minimum_size = Vector2(120, 0)
	name_row.add_child(name_label)
	name_edit = LineEdit.new()
	name_edit.text = "无名者"
	name_row.add_child(name_edit)
	creation_box.add_child(name_row)

	var age_row := HBoxContainer.new()
	var age_label := Label.new()
	age_label.text = "年龄"
	age_label.custom_minimum_size = Vector2(120, 0)
	age_row.add_child(age_label)
	age_spin = SpinBox.new()
	age_spin.min_value = 11
	age_spin.max_value = 80
	age_spin.value = 11
	age_row.add_child(age_spin)
	creation_box.add_child(age_row)

	var goal_row := HBoxContainer.new()
	var goal_label := Label.new()
	goal_label.text = "人生目标"
	goal_label.custom_minimum_size = Vector2(120, 0)
	goal_row.add_child(goal_label)
	goal_edit = LineEdit.new()
	goal_edit.text = "我想知道魔法到底能走多远"
	goal_row.add_child(goal_edit)
	creation_box.add_child(goal_row)

	var personality_row := HBoxContainer.new()
	var personality_label := Label.new()
	personality_label.text = "性格关键词"
	personality_label.custom_minimum_size = Vector2(120, 0)
	personality_row.add_child(personality_label)
	personality_edit = LineEdit.new()
	personality_edit.text = "好奇,固执,怕黑"
	personality_row.add_child(personality_edit)
	creation_box.add_child(personality_row)

	var start := Button.new()
	start.text = "开始人生"
	start.pressed.connect(_on_start_pressed)
	creation_box.add_child(start)

	# 重启后允许直接读档，不必先创建角色（否则「先创建再点读档」会覆盖刚创建的世界）
	var load_btn := Button.new()
	load_btn.text = "读取存档"
	load_btn.pressed.connect(_on_load)
	creation_box.add_child(load_btn)

func _selected(key: String) -> String:
	var option: OptionButton = dropdowns[key]
	return str(option.get_item_metadata(option.selected))

func _on_start_pressed() -> void:
	var choices := {
		"era_id": _selected("era_id"),
		"bloodline_id": _selected("bloodline_id"),
		"birth_identity_id": _selected("birth_identity_id"),
		"name_text": name_edit.text,
		"gender": "未定",
		"age_years": int(age_spin.value),
		"birthplace": "london_muggle",
		"family_status": "由系统生成",
		"aptitude_id": _selected("aptitude_id"),
		"aptitude_special": "",
		"wand": {},
		"house_id": _selected("house_id"),
		"political_leaning_id": _selected("political_leaning_id"),
		"personality": _personality_words(),
		"life_goal": goal_edit.text,
		"sim_style_id": _selected("sim_style_id"),
	}
	rng = RngService.new(SEED_SALT + Time.get_ticks_msec() % 100000)
	var result := CharacterCreation.create(choices, registry, rng)
	if result.errors.size() > 0:
		_show_creation_error("创建失败：\n%s" % "\n".join(result.errors))
		return
	world = WorldState.create(choices["era_id"], result.player, rng.seed_value, registry)
	engine = TurnEngine.new(world, ScriptedGameMaster.new(rng), rng)
	creation_box.visible = false
	play_box.visible = true
	_append("【原著优先级别已启用】本世界以《哈利·波特》原著七部小说为正典。")
	_append("%s，%d岁。你的人生开始了。" % [world.player.name_text, world.player.age_years()])
	_append(PanelFormatter.player_panel(world))
	command_edit.grab_focus()

func _personality_words() -> Array:
	# LineEdit.text.split() 返回 PackedStringArray；校验器要求 Array，这里显式转换
	var words: Array = []
	for raw in personality_edit.text.split(","):
		var word := str(raw).strip_edges()
		if not word.is_empty():
			words.append(word)
	return words

var _turn_count := 0

func _append(text: String) -> void:
	log_view.append_text(text + "\n")

# 创建/读档失败时，creation_box 可能仍在前台：错误必须写进可见的 creation_error，而不是隐藏的 log_view。
func _show_creation_error(message: String) -> void:
	if creation_error != null:
		creation_error.text = message
	push_warning(message)
	if log_view != null:
		log_view.append_text(message + "\n")

func _on_command_submitted(text: String) -> void:
	if world == null:
		return
	# 第七十二章：自检后必须等玩家确认，才允许继续叙事
	if text.strip_edges() == "确认自检":
		if engine != null:
			engine.acknowledge_audit()
		_append("（自检已确认。世界继续向前。）")
		command_edit.text = ""
		return
	var result := engine.submit(text)
	_turn_count += 1
	_append(">>> %s" % text)
	_append(str(result["narration"]))
	var events: Array = result["events"]
	if not events.is_empty():
		_append(PanelFormatter.events_block(events))
	for err in (result["op_errors"] as PackedStringArray):
		_append("（系统提示：%s）" % str(err))
	if str(result["audit"]) != "":
		_append(str(result["audit"]))
		_append("（自检完毕。等待你的指令——输入“确认自检”继续。）")
	status_label.text = PanelFormatter.status_line(world) + " ｜ 回合 %d" % world.clock.turn
	command_edit.text = ""

func _on_status() -> void:
	if world != null:
		_append(PanelFormatter.player_panel(world))

func _on_magic() -> void:
	if world != null:
		_append(PanelFormatter.magic_panel(world))

func _on_relation() -> void:
	if world != null:
		_append(PanelFormatter.relation_panel(world))

func _on_power() -> void:
	if world != null:
		_append(PanelFormatter.power_panel(world))

func _on_save() -> void:
	if world == null:
		return
	var result := SaveStore.save(SAVE_SLOT, world)
	_append("存档：%s（%s）" % ["成功" if bool(result["ok"]) else "失败", str(result["path"])])

func _on_load() -> void:
	var result := SaveStore.load_slot(SAVE_SLOT, registry)
	if not bool(result["ok"]):
		var msg := "读档失败：%s" % str(result["error"])
		if creation_box != null and creation_box.visible:
			_show_creation_error(msg)
		else:
			_append(msg)
		return
	world = result["world"]
	rng = RngService.new(world.game_seed)
	engine = TurnEngine.new(world, ScriptedGameMaster.new(rng), rng)
	creation_box.visible = false
	play_box.visible = true
	status_label.text = PanelFormatter.status_line(world) + " ｜ 回合 %d" % world.clock.turn
	if creation_error != null:
		creation_error.text = ""
	_append("读档成功：%s" % str(result["path"]))
	_append(PanelFormatter.player_panel(world))

func _on_audit() -> void:
	if world == null:
		return
	_append(SelfCheck.report(world))
	if engine != null:
		engine.acknowledge_audit()
		_append("（已确认自检，可继续行动。）")
```


- [ ] **Step 4: 指定主场景**

修改 `project.godot`，在 `[application]` 段加入：

```ini
run/main_scene="res://src/ui/main.tscn"
```

- [ ] **Step 5: 运行场景冒烟**

```bash
cd /e/Hali
bash tools/test.sh
```

预期：`== 3/3 主场景冒烟 ==` 之后出现 `main scene ready, godot=4.7.2-stable (official)`，退出码 0，最后打印 `全部通过。`

若出现 `Failed to load script "res://src/ui/main.gd"`：先跑一次 `./Godot_v4.7.2-stable_win64_console.exe --headless --path . --import`，`class_name` 全局类依赖导入缓存。

- [ ] **Step 6: 人工验收窗口程序**

```bash
cd /e/Hali
./Godot_v4.7.2-stable_win64_console.exe --path .
```

按下面清单逐项确认（这一项无法自动化，必须人工做一次）：

1. 窗口标题为「哈利·波特·魔法纪元」，出现创建界面与 7 个下拉框（时代/血统/身份/资质/学院/政治倾向/模拟风格）。
2. 选「哑炮」血统 + 「哑炮无魔法天赋」资质 + 姓名 + 年龄 11 + 三个性格关键词 + 一句目标 → 点「开始人生」→ 出现人生状态面板，【血统】显示「哑炮」。
3. 输入「我要练习魔药学」回车 → 出现叙事、状态行回合数 +1；连续输入 3 次，第三次旁白应出现「收益下降」。
4. 输入「我去对角巷打工赚钱」→ 财富增加。
5. 点「魔法」→ 哑炮角色显示「无魔法天赋」「未拥有」。点「关系」「势力」→ 面板可读，无脚本报错。
6. 点「存档」→ 提示成功；点「读档」→ 恢复后状态行回合数与存档前一致。
7. 关掉程序重开，点「读档」→ 世界恢复。
8. 连续行动直到回合数到 15 → 出现【剧情快照】与【人设OOC自检报告】，且此时继续输入行动会被拒绝，提示先确认自检；输入「确认自检」后可继续。

- [ ] **Step 7: 收尾 README.md**

收尾 `README.md`（不要整篇覆盖，保留进度表、HANDOFF/台账链接、目录约定、设计不变量）：

```markdown
# 哈利·波特·魔法纪元

魔法世界沙盘·超高自由度人生模拟器。以《哈利·波特》原著七部小说为正典（见根目录 `哈利·波特·魔法纪元.md`）。

当前进度：**计划 01 · 核心模拟地基**（可运行、可测试的文本模拟核心：内容表 → 角色创建 → 月度世界演化 → 行动裁决 → 状态面板 → 存档读档）。

## 运行

```bash
# 启动游戏窗口
./Godot_v4.7.2-stable_win64_console.exe --path .

# 运行全部测试（导入 + 单元测试 + 场景冒烟）
bash tools/test.sh
```

Windows 上 `bash` 来自 Git Bash。若引擎不在仓库根目录，用 `GODOT=/path/to/godot bash tools/test.sh`。

## 目录约定

- `data/*.json`：内容（时代、血统、身份、资质、学院、技能、魔杖、地点、传闻、魔咒）。改内容不需要改代码。
- `src/model/`：数据模型（货币、玩家、世界、时钟）。
- `src/rules/`：规则（魔法等级、角色创建、魔咒解析、成长、状态操作、自检）。
- `src/core/`：注册表、随机服务、回合引擎。
- `src/gm/`：叙事接口。`ScriptedGameMaster` 是离线确定性替身；LLM 叙事（计划 02）实现同一个 `GameMaster` 接口。
- `src/persist/`：存档编解码与存槽。
- `src/ui/`：Godot 场景与面板格式化。
- `tests/`：全部测试。新增测试套件必须把路径追加到 `tests/run_tests.gd` 的 `SUITES`。

## 存档位置

`%APPDATA%/Godot/app_userdata/哈利·波特·魔法纪元/saves/slot1.json`（`user://saves`）。

## 设计不变量（改动前必读）

- 货币 1加隆 = 17西可 = 493纳特。
- 施法失败率按魔法等级区间取值，环境因素与咒语难度会修正它。
- 每回合 = 一个月；世界始终向前推进。
- 每 15 回合强制自检，未确认前禁止续写剧情。
- 反漏洞：复制稀有资源、无限复活、时间回溯、低阶咒语叠加全部被守卫拦截。
- 重复低难度动作收益递减；换环境才有新成长。
- 死亡不可逆；玩家没有默认主角光环。
```

- [ ] **Step 8: 提交**

```bash
cd /e/Hali
git add src/ui/main.tscn src/ui/main.gd src/ui/main.gd.uid project.godot README.md
git commit -m "feat(ui): 主界面、创建流程与运行说明"
```

---

## 完成后验收

全部任务完成后，一次跑通：

```bash
cd /e/Hali
bash tools/test.sh
echo "exit=$?"
git log --oneline
```

预期：

- 13 个测试套件全部 `失败=0`，`全部通过。`，`exit=0`。
- `git log --oneline` 有 11 个提交（每个任务一个）。
- `./Godot_v4.7.2-stable_win64_console.exe --path .` 能创建角色、行动、看面板、存档读档、触发第 15 回合自检。

## 已知边界（本计划刻意不做，属后续计划）

- 叙事由 `ScriptedGameMaster` 生成：它是确定性的关键词裁决，不是 LLM。计划 02 用 `LlmGameMaster` 实现同一个 `GameMaster` 接口，不改动 `TurnEngine`、`StateOps`、`WorldState`。
- 派系与政治经济只用 `world_vars` 七个标量近似（第六十五章面板可读），九大支柱的完整模拟在计划 03。
- 神奇生物生态、NPC 自主行动、信息可信度、多世代传承分别在计划 04/05/06。
- `data/rumors.json` 是初始模板池；扩内容只需加条目，不需要改代码。
