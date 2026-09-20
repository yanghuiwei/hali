# Task 7 实现报告 · 势力面板重写（第六十五章；修 §8#7）

> 提交：**`9e896de`**（`feat(ui): 势力面板重写——机构控制权 + 已知势力（修 §8#7）（计划 03a Task 7）`）
> 分支：`plan-03-factions`｜BASE：`537bd68`（+ 控制器 docs `0be229f`）
> 结构：brief Step 1→5 全程执行（先写失败测试 → 红 → 实现 → 绿 → 提交）；brief 的断言与代码**逐字采用**（唯一改动是引入 `_institution_value()` helper 以避免 4 处重复的嵌套强转，面板文本格式逐字不变）

---

## ① 改动文件

| 文件 | 变化 | 说明 |
| --- | --- | --- |
| `src/ui/panel_formatter.gd` | +77 / −15 | `power_panel()` 重写；新增 `_institution_value()` / `_institution_holder_label()` / `_known_factions_line()` |
| `tests/panel_test.gd` | +67 | brief 的 18 条 + 控制器点名的 holder 泄漏/§8#7 证据/全隐藏占位/政体缓存路径 |
| `tests/factions_test.gd` | +12 | 收口 4a：`reveal()` 畸形世界不得留部分写入（状态型护栏） |
| `tests/save_test.gd` | +10 | 收口 4b：揭示状态随存档往返 |
| `tests/world_tick_test.gd` | +10 | 收口 4c：每个传闻事件带非空 `rumor_id` |

合计 5 文件、+161 / −15。**未新建任何文件。**

## ② 绿灯原始输出（`bash tools/test.sh`）

```
[probe] 断言=1 失败=1          ← 断言库自检探针，故意失败，不计入套件
[harness] 断言=8 失败=0
[registry] 断言=244 失败=0
[money] 断言=18 失败=0
[magic_level] 断言=48 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=180 失败=0
[creation] 断言=176 失败=0
[spell] 断言=229 失败=0
[gm] 断言=71 失败=0
[panel] 断言=99 失败=0
[selfcheck] 断言=32 失败=0
[save] 断言=112 失败=0
[async_probe] 断言=2 失败=0
[llm] 断言=88 失败=0
[prompt] 断言=13 失败=0
[debug_mirror] 断言=23 失败=0
[factions] 断言=193 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
main scene ready, godot=4.7.2-stable (official)      ← 3/4 主场景冒烟（且全篇无 [HALI]）
[HALI] PROBE-APPEND-MARK                             ← 4/4 调试镜像冒烟
全部通过。
EXIT=0
```

- `SCRIPT ERROR` 条数：**本次 2 = 基线 2**（`task-7-test-green.log` vs `task-1-baseline.log`）。
- 红步原始输出（`task-7-test-red.log`）：`[panel] 断言=96 失败=15` / `==== 总计失败=15，失败套件=1 ====` / `测试失败：单测=1 冒烟=0 镜像=0`（15 条即下列缺失的新格式能力：政体、机构 holder 标签、威森加摩/傲罗控制权、无「待定」、【已知势力】、揭示后出现、立场、[所属]、holder 未知势力保护、全隐藏占位）。
- 附加证据（未在 brief 要求，为确认面板重写不破坏验收通道而做）：`bash tools/b1_acceptance.sh` → **断言 78 条失败 0，全部通过**。

## ③ 断言数前后对比

| 套件 | 前（Task 6 收尾） | 后 | Δ |
| --- | --- | --- | --- |
| `[panel]` | 71 | **99** | **+28** |
| `[factions]` | 191 | **193** | +2 |
| `[save]` | 107 | **112** | +5 |
| `[world_tick]` | 154 | **180** | +26 |
| 其余 15 套件 | — | 不变 | 0 |
| 合计（含 `[probe]`） | 1572 | **1633** | +61 |

> `[world_tick]` 的 +26 是**数据驱动**的：4c 对日志里**每一条**传闻事件断言一次（本次 25 条）+ 1 条前置断言。供审查者知情。

## ④ 各项断言的「能失败的证据」（7 组破坏实验，每组后逐字还原并校验 md5）

| # | 破坏方式 | 期望变红的断言 | 结果 |
| --- | --- | --- | --- |
| BE1 | 删掉 `reveal()` 的 null 早退 | `[factions] 畸形世界不得留下部分写入` | **RED** ✅（还原 md5 一致） |
| BE2 | `WorldState.to_dict()` 丢掉 `factions` | `[save] 读档后仍可见（revealed 随存档往返）` | **RED** ✅ |
| BE3 | `tick()` 的事件字典不写 `rumor_id` | `[world_tick] 传闻事件带 rumor_id（第 13/14 回合…）` | **RED** ✅ |
| BE4 | 傲罗指标改读 `world_vars`（退化成 §8#7 的错法） | `[panel] 傲罗指标随派系控制权变化` | **RED** ✅ |
| BE5 | holder 未揭示也直接印 label（信息泄漏） | `[panel] 未揭示的 holder 显示为「未知势力」` | **RED** ✅ |
| BE6 | 【已知势力】改列**全部**派系（信息泄漏） | `[panel] 未揭示的派系不得出现` | **RED** ✅ |
| BE7 | 忽略 `flags["government_type"]` 缓存、每次现算 | `[panel] 有缓存时以 flags 为准` | **RED** ✅ |

（BE1/BE2 见 `be_task7.py` 第一次运行输出；BE3–BE7 见同脚本第二次运行输出。全部 `还原一致=True`。）

## ⑤ 控制器点名项与收口项的证据

- **③ holder 未揭示（我点名的新风险）**：`_institution_holder_label()` 在 holder 未被 `visible_faction_ids()` 收录时返回「未知势力」，控制权**数值**照常显示。断言：`法律执行：0.99（未知势力）` + `is_false(panel.contains("食死徒"))`；揭示后同一天显示 `法律执行：0.99（食死徒）`。失败证据 = **BE5**。
- **4a 状态型护栏（`tests/factions_test.gd`）**：`half_world.clock = null; half_world.factions.clear();` → `reveal()` 返回 false 且 `state_of(...).is_empty()`。失败证据 = **BE1**（删守卫后：`ensure_state` 会先写入条目、`reveal` 置 `revealed=true`，直到 `add_fact` 读 `clock.turn` 才中止 ⇒ 条目留在 `world.factions` 里 ⇒ 本条红）。**与既有三条 `is_false` 断言的区别**：那三条在删守卫后仍绿（GDScript 中止时返回返回类型默认值 `false`），只有本条能红。
- **4b 跨存档 revealed（`tests/save_test.gd`）**：`reveal()` → `encode/decode` → 读档后仍在 `visible_faction_ids()` 且 `factions.size() == 17`。失败证据 = **BE2**。
- **4c 传闻事件 `rumor_id`（`tests/world_tick_test.gd`）**：对 `w.log` 中每条 `kind == "rumor"` 断言 `not str(e.get("rumor_id","")).is_empty()`，另有前置 `rumor_log_events >= 1` 防空转。**没有用下标访问** `e["rumor_id"]`（避免 Task 5 的 E6 教训：缺键时下标访问会抛运行期错误、让整个套件中止，而不是给出一条干净失败）。失败证据 = **BE3**。

## ⑥ §8#7 修好的证据（机构指标确实来自派系控制权）

1. **结构性前提**：`a.is_false(w.world_vars.has("auror_office"))` —— `world_vars` 里**根本没有**机构键，所以「傲罗」「威森加摩」「国际」「法律执行」不可能是从标量读的。
2. **行为证据**：把 `auror_office` 对机构 `auror_office` 的 control 改到 `0.90` → 面板出现 `傲罗：0.90（傲罗指挥部）`；改回 `0.60` 后恢复。同理 `wizengamot` 的 control 改到 `0.91` → `威森加摩：0.91（威森加摩）`。
3. **反证**：**BE4**（让傲罗指标改读 `world_vars`）→ 该断言必红（`0.00`）；**BE7** 另证政体来自内容表+缓存。
4. 附带发现（我自己的测试 bug，已在代码注释里写清）：神圣二十八族**也**声明了 `wizengamot`（0.55），所以第一次我把 `wizengamot` 设成 0.31 时 holder 仍是神圣二十八族（面板显示 `0.55（神圣二十八族）`）→ 断言红。已改为 0.91 并在注释里写明为什么不能用 0.31。

## ⑦ 未验证项 / 残余

1. **政体缓存路径的 3 条断言是在写报告阶段补的**（初始 TDD 红里没有它们）：`未缓存` → 现算、`有缓存` → 以 flags 为准、`新建世界尚未缓存政体`。它们的失败证据是 **BE7**，不是初始红步。
2. **【已知势力】的并列顺序未定义**：用 `sort_custom` 按实力降序，`sort_custom` 不保证稳定 ⇒ 实力相同的派系（本次公开派系里 `auror_office`/`gringotts` 都是 0.60、`daily_prophet`/`common_folk` 都是 0.45）**谁先谁后无断言**。测试只钉「魔法部（0.75）居首」。
3. **机构 holder 平局**：`institution_control()` 的平局按「power 高者」裁决（Task 2 已定），面板只显示裁决结果；平局场景无专门断言。
4. **面板显示隐藏派系的控制权「值」**（如 `法律执行：0.99（未知势力）`）：这是**有意的设计选择**——值是世界事实、被隐藏的只是**身份**（第四十三/五十七章禁止的是揭示身份）。但它意味着玩家能观察到「存在一个未知强权」。供 03b/05 的「信息可信度」细化时再评估是否要把数值也模糊化。
5. **「部长」一栏的语义替换**：正典第六十五章的「部长」是 NPC 职务（人名），NPC 系统属计划 05；本任务把「**控制执法司的派系**」填进这一栏。等 05 有 NPC 后应改回具体人名。这是有意的、已在提交信息与本报告登记。
6. `_institution_holder_label()` 每个机构各调一次 `visible_faction_ids()`（面板最多 5 次 × 17 派系遍历）：性能可忽略，未做缓存。
7. 我在本任务里自曝的两个测试 bug（不涉生产代码）：① 在 `panel_test.gd` 里重复声明 `power`、在 `factions_test.gd` 里重复声明 `half` → 两个套件解析失败（`There is already a variable named …`），已改为复用/重命名；② 4c 最初把局部变量命名为 `rumor_events`，与该函数既有同名变量冲突，已改名 `rumor_log_events`。

## ⑧ 是否触碰 brief 未列出的文件

**是**：`tests/factions_test.gd`、`tests/save_test.gd`、`tests/world_tick_test.gd` —— 这三处是**控制器明确要求的收口项（第 4 条 4a/4b/4c）**，各只加一组追加式断言（均在 `return a.report(...)` 之前），未改任何既有断言。除此之外未触碰 brief 未列出的文件，未新建文件。
