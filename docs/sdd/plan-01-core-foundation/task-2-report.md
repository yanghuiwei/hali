# Task 2 报告：内容注册表 + 正典内容表

状态：TASK_COMPLETE
提交：`52b68ba feat(content): 内容注册表与七张正典内容表`（单提交，分支 `plan-01-core-foundation`）

## 1. 实现了什么

### `src/core/registry.gd`（新增，`class_name Registry extends RefCounted`）

严格按 brief Step 3 的代码实现，接口全部落地：

- `TABLE_FILES: Dictionary` —— 仅 7 张表：`eras / bloodlines / birth_identities / aptitudes / houses / sim_styles / political_leanings`。
  **未**包含 `locations / rumors / skills / spells / wands`（属任务 5–7，按 brief 决策 6 排除）。
- `duplicate_ids: PackedStringArray` —— `from_tables()` 建索引时发现同表重复 `id` 即追加 `"表名/id"`。
- `static from_tables(tables: Dictionary) -> Registry` —— 表名 → 条目数组；非数组、非字典条目被跳过；每个表转成 `id → 条目` 索引。
- `static load_default() -> Registry` —— 逐表读 `res://data/<file>`，`FileAccess.get_file_as_string` + `JSON.parse_string`；解析结果不是数组时降级为空数组（缺失/坏文件由 `validate()` 报「缺少数据表」/「数据表为空」）。
- `entry(table, id) -> Dictionary` —— 缺失或跨表查询返回 `{}`。
- `has(table, id) -> bool`
- `ids(table) -> PackedStringArray` —— 排序后返回。
- `table_dict(table) -> Dictionary` —— `id → 条目`。
- `validate() -> PackedStringArray` —— 空数组 = 通过；同时汇报四类错误：`重复 id`、`缺少数据表`、`数据表为空`（含空 id 条目的 `存在空 id 条目`）、`缺少 label`。

### `data/` 七张正典内容表（新增，UTF-8 无 BOM，JSON 逐字取自 brief Step 4，未改字段、未调整顺序、未增删条目）

| 文件 | 条目数 | 字段 |
|---|---|---|
| `data/eras.json` | 8 | `id,label,start_year,canon_note,secrecy_law,ministry_exists,world_vars{7 项}` |
| `data/bloodlines.json` | 12 | `id,label,magic_aptitude,prejudice,wealth_tier,skill_bias,default_flags,risk,note` |
| `data/birth_identities.json` | 11 | `id,label,start_knuts,skill_bias,contacts,note` |
| `data/aptitudes.json` | 6 | `id,label,failure_delta,grants,special_options,note` |
| `data/houses.json` | 6 | `id,label,traits,note` |
| `data/sim_styles.json` | 6 | `id,label,event_intensity,mundane_ratio,note` |
| `data/political_leanings.json` | 6 | `id,label,pureblood_opinion,ministry_opinion,risk,note` |

### `tests/registry_test.gd`（新增）

逐字使用 brief Step 1 的测试，`class_name RegistryTest`，26 条断言：内容表校验、7 张表条目数（8/12/11/6/6/6/6）、5 个逐字标签、存在性/跨表查询/缺失返回空字典、关键语义字段（哑炮无 `magic_aptitude`、麻瓜出身有、`witch_hunts.start_year==1692`、`custom.start_year==null`、哑炮 `grants` 为空）、坏数据校验（重复 id / 缺少数据表 / 缺少 label）、`ids()` 已排序。

### `tests/run_tests.gd`（修改 1 行）

按 brief Step 2 的 `sed -i` 命令在 `SUITES` 中追加 `"res://tests/registry_test.gd",`；保留原有 `"res://tests/harness_test.gd",`。

## 2. TDD 证据

### RED（实现前）

命令：

```bash
cd /e/Hali
sed -i 's|"res://tests/harness_test.gd",|"res://tests/harness_test.gd",\n\t"res://tests/registry_test.gd",|' tests/run_tests.gd
timeout 240 bash tools/test.sh; echo "EXIT=$?"
```

输出（节选）：

```
[harness] 断言=8 失败=0
SCRIPT ERROR: Parse Error: Identifier "Registry" not declared in the current scope.
   at: GDScript::reload (res://tests/registry_test.gd:6)
SCRIPT ERROR: Parse Error: Cannot infer the type of "reg" variable because the value doesn't have a set type.
...
ERROR: Failed to load script "res://tests/registry_test.gd" with error "Parse error".
SCRIPT ERROR: Invalid call. Nonexistent function 'new' in base 'GDScript'.
```

失败符合预期：`Registry` 尚不存在，套件加载失败（brief Step 2 预期的 `套件无法加载（语法错误？）` 等价形态；实际形态是 GDScript 解析错误 + `Failed to load script`，因为 `load()` 返回非 null 的坏脚本而 `new()` 失败）。harness 套件仍 8/8 通过。

### GREEN（实现 + 数据后）

命令：

```bash
cd /e/Hali
timeout 240 bash tools/test.sh; echo "EXIT=$?"
```

输出：

```
== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/3 单元测试 ==
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

（`[probe]` 是 harness 套件内部故意制造的失败探针，属任务 1 既有输出。）

额外验证（仅一次、非重复全量跑测）：`python -c "json.load(...)"` 逐文件校验 7 张表 JSON 合法，并确认首字节为 `5b 0a 09`（`[` 开头，无 BOM、无乱码）。

## 3. 文件变更

新增：
- `src/core/registry.gd`（80 行）
- `src/core/registry.gd.uid`（Godot 生成）
- `data/eras.json`、`data/bloodlines.json`、`data/birth_identities.json`、`data/aptitudes.json`、`data/houses.json`、`data/sim_styles.json`、`data/political_leanings.json`
- `tests/registry_test.gd`（64 行）、`tests/registry_test.gd.uid`

修改：
- `tests/run_tests.gd`（+1 行）

未提交任何 `.godot/` 缓存；提交后 `git status --short` 为空。

## 4. 自查发现

1. **只加了七张表**：`TABLE_FILES` 与 `data/` 均为 7 项，无 `locations/rumors/skills/spells/wand` 越界。
2. **`git add` 比 brief 的命令多两个 `.uid`**：`src/core/registry.gd.uid`、`tests/registry_test.gd.uid` 由 Godot 导入生成，且任务 1 的提交把 `.uid` 一并入库（`tests/assert.gd.uid` 等）。为保持仓库一致、避免留下未跟踪生成物，随同一次提交包含。除此之外严格按 brief 的命令范围。
3. **JSON 数字读入为 float**：`reg.entry("eras","witch_hunts")["start_year"]` 实际是 `1692.0`。测试用 `eq` 做数值比较，`1692.0 == 1692` 为真，故通过；但后续任务的 `to_dict()` 深比较必须走真源约束里的 `JsonUtil.normalize()`（整数值归一为 int），否则存读档往返断言会失败。这是既有全局约束，本任务未引入新问题。
4. **`entry()` / `table_dict()` 返回内部字典引用**（brief 的实现如此）：调用方若原地修改返回值会污染注册表状态。建议后续任务把注册表视为只读内容源；如需防御可改用 `duplicate(true)`，但那会改变 brief 指定的行为，未擅自修改。
5. **`validate()` 的错误前缀**：空 `id` 报为「存在空 id 条目」，表整体为空报「数据表为空」，均含 brief 要求的 `缺少数据表` 之外的独立信息；被断言的三条子串（`重复 id`、`缺少数据表`、`缺少 label`）均已验证命中。

## 5. 关注点 / 遗留

- **RED 阶段引擎会挂起（非本任务缺陷）**：`tests/run_tests.gd`（任务 1 冻结文件）在套件 `load()` 返回坏脚本、`script.new()` 失败时，`_initialize()` 中途抛错，永远不会执行 `quit()`，headless 引擎会一直挂着。本次 RED 验证因此需要 `timeout 240`，实际是靠超时结束。若后续任务希望 RED 更干脆，可建议控制器另开任务加固 harness（例如 `if script == null or not script.can_instantiate(): continue`）；本任务按决策 1 未改动该文件。
- 无其它阻塞或未决产品决策。
