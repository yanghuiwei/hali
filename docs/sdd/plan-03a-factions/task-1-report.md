# Task 1 报告 · 内容表 `factions` / `governments` + Registry 注册与字段校验

- **计划**：`docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md`（Task 1）
- **分支**：`plan-03-factions`（BASE = `12f6a50`）
- **状态**：DONE
- **提交**：`eacb773`（`feat(data): 派系与政体内容表 + Registry 注册与字段校验（计划 03a Task 1）`）
- **原始日志留档**：`.superpowers/sdd/2026-09-20-hp-magic-era-03-factions/task-1-test-green.log`、`task-1-baseline.log`

---

## 1. 改动 / 新建文件

| 文件 | 状态 | 说明 |
| --- | --- | --- |
| `data/factions.json` | 新建（290 行） | 17 个派系，字段契约：`id,label,kind,aliases,legal_status,secrecy,domains,agenda,base_power,rivals,allies,institutions,era_overrides` |
| `data/governments.json` | 新建（26 行） | 第十一章四大政体，`canon_line` = 160/162/164/166 |
| `src/rules/factions.gd` | 新建（28 行） | **本任务只放常量**（`INSTITUTIONS/KINDS/LEGAL_STATUS/SECRECY/CORNERS/MINISTRY_ID/RESISTANCE_ID/TENSION_FLAG/GOVERNMENT_FLAG`），函数在 Task 2 加 |
| `src/rules/factions.gd.uid` | 新建 | 引擎 import 生成，按铁律一并入库 |
| `src/core/registry.gd` | 修改（+42 行） | `TABLE_FILES` 注册两表；`validate()` 改为「公共检查 + 按表 `_validate_entry()`」 |
| `tests/registry_test.gd` | 修改（+51 行） | 追加计划 03a 的派系/政体内容表断言（brief Step 1 原文） |

`git show --stat`：`6 files changed, 438 insertions(+)`。工作区干净。

---

## 2. 测试原始输出

### 2.1 红（Step 2，写测试后、实现前）

```
[registry] 派系表 17 条: 期望 <17>，实际 <0>
[registry] 派系 ministry 存在: 期望为真
[registry] 派系 auror_office 存在: 期望为真
[registry] 派系 wizengamot 存在: 期望为真
[registry] 派系 mysteries 存在: 期望为真
[registry] 派系 hogwarts 存在: 期望为真
[registry] 派系 sacred_twenty_eight 存在: 期望为真
[registry] 派系 reformist_pureblood 存在: 期望为真
[registry] 派系 death_eaters 存在: 期望为真
[registry] 派系 order_of_phoenix 存在: 期望为真
[registry] 派系 gringotts 存在: 期望为真
[registry] 派系 diagon_merchants 存在: 期望为真
[registry] 派系 daily_prophet 存在: 期望为真
[registry] 派系 black_market 存在: 期望为真
[registry] 派系 common_folk 存在: 期望为真
[registry] 派系 international_confederation 存在: 期望为真
[registry] 派系 continental_pureblood 存在: 期望为真
[registry] 派系 muggle_world 存在: 期望为真
[registry] 政体表 4 条: 期望 <4>，实际 <0>
[registry] 坏 kind 必须报错: 期望为真
[registry] 断言=48 失败=21
==== 总计失败=21，失败套件=1 ====
```

### 2.2 绿（Step 4，实现后，`bash tools/test.sh`，EXIT=0）

```
== 1/4 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/4 单元测试 ==
[probe] 断言=1 失败=1
[harness] 断言=8 失败=0
[registry] 断言=210 失败=0
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
[save] 断言=97 失败=0
[async_probe] 断言=2 失败=0
[llm] 断言=84 失败=0
[prompt] 断言=13 失败=0
[debug_mirror] 断言=23 失败=0
==== 总计失败=0，失败套件=0 ====
== 3/4 主场景冒烟（默认配置：必须与未加调试镜像时逐字一致） ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

main scene ready, godot=4.7.2-stable (official)
== 4/4 调试镜像冒烟（HALI_DEBUG_LOG=1，B1 人工验收的观测通道） ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

main scene ready, godot=4.7.2-stable (official)
[HALI] 调试镜像已启用：界面文本将镜像到 stdout（user://logs/*.log）；内容表问题 0 条
[HALI] [状态行] 《哈利·波特·魔法纪元》魔法世界沙盘·超高自由度人生模拟器
[HALI] [创建界面] era_id 选项数=8 当前=custom
…… 7 个下拉各一行 ……
[HALI] PROBE-APPEND-MARK
[HALI] [状态行] PROBE-STATUS-MARK
[HALI] [输入框] editable=false
[HALI] [按钮] 整排 禁用
全部通过。
```

**主场景读出「内容表问题 0 条」**：新增两表后 `registry.validate()` 在主场景里依然零错误（若 8 个时代的 `era_overrides` 有错，这里会变成非 0）。

### 2.3 基线噪音对照（证明本次未新增 stderr 噪音）

把本次改动 `git stash -u` 到一边、在 BASE（`12f6a50`）上跑同一条命令：

| 项 | 基线 `12f6a50` | 本次 `eacb773` |
| --- | --- | --- |
| SCRIPT ERROR 条数 | 2 | 2（**同一位置、同一文案**） |
| 其中 | `Invalid assignment of property or key 'personality' …`、`Invalid call. Nonexistent 'int' constructor.` | 同上（save/解析层坏档负例的既有噪音） |
| `[registry]` | 断言=26 失败=0 | 断言=210 失败=0 |
| 总计 | 失败=0，失败套件=0 | 失败=0，失败套件=0 |
| EXIT | 0 | 0 |

`grep -c SCRIPT ERROR` 两侧都是 2 → **本次改动引入 0 条新噪音**（原始日志见 `task-1-baseline.log` 与 `task-1-test-green.log`）。

---

## 3. 断言数变化

| 套件 | 前 | 后 | 差值 |
| --- | --- | --- | --- |
| `[registry]` | 26 | **210** | +184 |
| 其它 17 套件 | — | 未变 | 0 |

（+184 = 17 条存在性 + 2 条表大小 + 17×7 条逐派系枚举/值域/agenda + institutions/rivals/allies/era_overrides 引用 + 3 条坏内容校验。）

---

## 4. 自主决定与理由

1. **裁定 1 的实测结果（控制器要的数据点）**：在 Godot 4.7.2 上实测
   - 无类型 `Array` 与 `Array[String]` 用 `==` 比较 → **`true`**（逐元素比较，类型标注不影响相等判定）。
     实测：`["law_enforcement", …] == WorldFactions.INSTITUTIONS` → `true`；`kinds == WorldFactions.KINDS` → `true`。
     ⇒ **Task 2 计划里的 `a.eq(insts, WorldFactions.INSTITUTIONS, …)` / `a.eq(kinds, WorldFactions.KINDS, …)` 可以原样使用，不必改成 `",".join()` 形式。**
   - 附带发现（对后续任务有用）：`PackedStringArray == Array` **是解析期错误**，不是返回 false：
     `Parse Error: Invalid operands "PackedStringArray" and "Array" for "==" operator.`
     ⇒ Task 2/3/6 里凡是要比较 `WorldFactions.visible_faction_ids()`（返回 `PackedStringArray`）的地方，只能用 `.has()`/逐元素，**不能**写 `visible == ["ministry"]`。计划里现有的用法是 `.has(...)`，安全。
   - 探针脚本是临时文件，跑完即删（`tools/_tmp_typed_array_probe.gd` / `_tmp_packed_cmp.gd`，未入库，已确认 `tools/` 只剩原有文件）。
2. **`validate()` 的枚举常量故意重复**（裁定 2）：`registry.gd` 里的 `_KINDS/_LEGAL/_SECRECY/_INSTITUTIONS` 与 `WorldFactions` 同名常量重复是**刻意的**，未做去重——避免 core 层反向依赖 rules 层形成 `class_name` 类循环。那条「两处枚举一致」的断言（Task 2 加）就是防漂移闸门。
3. **`era_overrides` 一律写成显式对象**：无时代差异的派系写 `"era_overrides": {}`，而不是省略字段。理由：Task 2 的 `base_power()` 用 `ef.get("era_overrides", {})` 取值，字段显式存在能让内容表自检（Task 1 测试里 `typeof(overrides) == TYPE_DICTIONARY` 分支）真正覆盖到 17 条的全部。
4. **`aliases` 的取舍**：49 个别名，跨派系无重复（用脚本核过）。刻意**不**收录裸地点名（如「对角巷」「翻倒巷」单独出现），只收「对角巷商会」「翻倒巷黑市」等完整名字——否则 Task 9 的关键词接线会把「我去对角巷打工赚钱」这类普通动作误判成派系动作。
5. **纯血派系用集体名**（裁定 4）：`神圣二十八族` / `改革派纯血` / `欧陆纯血网络`，不含任何真实人物姓名（第十三章的具体家族名留给 03c）。
6. **`domains` 取值**：严格从 brief 给的白名单里取 1–3 个；`daily_prophet` 只给 `["media"]`（给它硬塞 `administration` 没有正典依据）。
7. **`canon_line` 已实测核对**：`sed -n '160p;162p;164p;166p' 哈利·波特·魔法纪元.md` 输出分别是「1. **魔法部官僚制**…」「2. **纯血寡头制**…」「3. **食死徒独裁**…」「4. **凤凰社抵抗组织**…」——四处行号与 brief 给的值一致。
8. **`base_power` 值域与内容一致性**：用一次性脚本核过 17 条的 `kind/legal_status/secrecy/base_power/agenda/institutions/rivals/allies/era_overrides/domains` 全部合法，`rivals/allies` 引用全部存在，`era_overrides` 的时代 id 全部来自 `data/eras.json`（8 个时代）。

---

## 5. 未验证项 / 残余

1. **`rivals`/`allies` 没有做「双向对称」校验**：例如 `black_market.rivals` 含 `auror_office`，而 `auror_office.rivals` 里没有 `black_market`（只有 `death_eaters`）。brief 只要求「引用存在」，我按 brief 执行；不对称是**内容层面**的取舍（正典里黑市是傲罗的打击对象，但傲罗的主敌是食死徒）。若 Task 2/4 的敌对压制逻辑需要对称，请在 Task 2 决定是「代码侧自动对称」还是「补内容」——目前 `apply_rival_pressure()` 用 `oid <= id` 去重，**不对称也不会重复计算**。
2. **`governments.json` 的 `canon_line` 不进任何校验**：它只是溯源信息。若将来正典文件行号漂移，没有任何测试会发现（可接受：正典文件在仓库根、不常改）。
3. **`muggle_world` 的 `kind` 用 `foreign`**：正典第六章第 4 根「麻瓜社会与保密法」在九大支柱里独立成柱，但代码的 `kind` 枚举（brief 给定）没有 `muggle` 之类取值。我选了 `foreign`（「他者」语义），它因此**不进权力四角**（`CORNERS` 里没有 `foreign`）。Task 2/5 若需要「麻瓜世界」影响 `muggle_relations`，走 `structure_pull("foreign")` 已覆盖（`muggle_relations` 项）。
4. **`aliases` 里「那个人」「神秘人」「部长」「老百姓」这类泛称**可能让 Task 9 的关键词识别偏宽（例如玩家说「我支持部长」→ 命中魔法部）。这是有意的（正典里这些就是代称），但 Task 9 的作者应在报告里确认关键词+别名组合的实际表现。
5. 本任务没有随机数、没有状态变更、不涉及存档，因此无确定性/迁移风险。

---

## 6. 是否触碰 brief 未列出的文件

**否。** 只改了 brief 列出的 6 个文件（3 新建 + 2 修改测试/registry + 1 个由引擎生成的 `.uid`）。两个临时探针脚本跑完即删，未入库。
