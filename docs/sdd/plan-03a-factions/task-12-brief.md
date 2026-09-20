# Task 12 Brief —— 哑炮学院（`§8#69`）+ 创建界面姓名/性别（`§8#70`）+ 内容旋钮生效（`§8#16/#21`）

计划 03a · Task 12。**唯一执行依据 = 计划文件的当前文本**：
`docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md`，第 **2299–2531** 行（`### Task 12: …` 到 `### Task 13:` 之前）。
**先完整读那一段**（含 Step 3 末尾刚订正的「实测缺陷」说明块），再动手。
本 brief 只补充「计划里没写、但你一定会踩」的上下文，不重复计划的代码。

---

## 0. 基线与环境

| 项 | 值 |
| --- | --- |
| 仓库 / 分支 | `E:/Hali`，分支 `plan-03-factions` |
| BASE | `e8f33dd`（控制器会在 dispatch 里再确认一次） |
| 引擎 | Godot 4.7.2 stable，两个 exe 在仓库根（`*.exe` 不入库） |
| 测试唯一入口 | `bash tools/test.sh` → 期望 `EXIT=0` / **18 套件 / 1746 断言 / 失败 0** / 4 步全过 |
| 绿基线断言数（控制器实测） | `[creation]=176 [world_tick]=180 [save]=112 [panel]=102 [gm]=128 [llm]=106 [prompt]=38 [factions]=204 [registry]=244` |
| 基线 stderr 噪音 | **`SCRIPT ERROR` 恰好 2 条**（`save` 的坏档负例）。**这个数字不许变**：多了就是新 bug，少了也是（说明负例被弄没了） |

---

## 1. 交付物（计划 Step 1/3/5 已写好代码，照它做）

1. `src/rules/character_creation.gd` —— 哑炮 `house_id = "none"`（正典第七章/第二十四章：哑炮不进霍格沃茨，通常被送往麻瓜学校）。
   做法：把 `:175` 那个**无条件**的 `p.house_id = assign_house(choices, rng, registry)` 移进「非哑炮」分支（哑炮分支在 `:201-205`）。
2. `src/ui/main.gd` —— 姓名框默认**空** + `placeholder_text`；新增「性别」下拉（男 / 女 / 未定）；
   `_on_start_pressed()` 里把硬编码的 `"gender": "未定"` 改成读下拉的真实值。
   注意：`_show_creation()` 开头是 `for child in creation_box.get_children(): child.queue_free()` + `dropdowns.clear()`
   ⇒ 你新增的 `gender_dropdown` 成员变量**必须跟着一起重置**（计划已写明写在 `dropdowns.clear()` 旁边）。
   建议**复用** `_add_dropdown()` 的形态，但它是给 `registry` 表用的；性别是硬编码三项，计划给的是手写 OptionButton。
3. `src/core/rng_service.gd` —— 新增 `stream_pick_weighted(name: String, entries: Array, weight_key: String = "weight")`。
4. `data/wand_cores.json` —— **每一条**加数值字段 `weight`（`common`=6、`rare`=1），`rarity` 字段**保留**（它是语义标签，不是权重）。
5. `src/rules/character_creation.gd::generate_wand` —— 木材与杖芯抽取改用 `stream_pick_weighted(..., "weight")`。
6. `src/model/world_state.gd::tick()` —— 传闻抽取改用 `stream_pick_weighted(..., "weight")`。
7. 测试：`tests/creation_test.gd`（哑炮 + 杖芯分布）、`tests/world_tick_test.gd`（权重）、`tools/b1_acceptance.gd`（性别下拉 + 姓名默认）。

---

## 2. 控制器已实测核实的事实（**别再自己试一遍，直接用**）

1. **`data/wand_cores.json` 的 `rarity` 是字符串** `"common"` / `"rare"`，**不是数值**。
   实测 `float("common") == 0.0`、`maxf(float("rare"), 0.0) == 0.0` ⇒ 计划**原文**的 `stream_pick_weighted(..., "rarity")`
   总权重恒为 `0.0` ⇒ 回退均匀抽取 ⇒ **`§8#21` 静默假修**，而计划自带的断言（只测 weight=0 / 全零 / 空表）**抓不到**。
   实测对照（`RngService.new(7)`，6 条杖芯，6000 次）：`weight`=6/1 → common 各 ≈1700（85.3%）/ rare 各 ≈283（14.7%）；
   `"rarity"` 字符串 → 六条各 ≈1000（完全均匀）。
   ⇒ 按**订正后**的口径做（新增数值 `weight` + 传 `"weight"`），并让新加的分布断言**能失败**。
2. **`data/wand_woods.json` 没有 `weight` 字段**（实测只有 `id` / `label`）⇒ 传 `"weight"` 时全部走默认 `1.0`，等价均匀抽取。
   计划允许「照改」或「保持原 `stream_pick` 不动」**二选一**，但**必须在报告里写明选了哪个、为什么**。
3. **`world_state.gd:134` 的 `ev` 里已经有 `"rumor_id"`**（Task 6 加的）⇒ 计划 Step 3 里那句「并保证事件字典带上 `rumor_id`」
   **已经是既成事实，不要重复加、不要动它**。
4. **「字面 `null` 赋给 `Dictionary`」是解析期错误**（实测 `Cannot assign a value of type "null" as "Dictionary"`）
   ⇒ `stream_pick_weighted` **不要**加 `-> Dictionary` 返回标注（空表时它返回 `null`）。
5. **随机流消耗方式会变**：`stream_pick` 用 `randi_range`，`stream_pick_weighted` 用 `randf`
   ⇒ 同一个命名流的内部状态推进不同 ⇒ `wand_wood` / `wand_core` / `pick_%d` **之后的一切抽取结果都会变**
   ⇒ `[creation]` / `[world_tick]` / `[save]` 里**依赖固定种子的期望值**会变。**这是预期内的，不是回归。**

---

## 3. 三个陷阱（都会让你「看起来绿了、其实错了」）

1. **假绿**：把 `"rarity"` 当权重 → 总权重 0 → 回退均匀 → 计划自带断言全绿但功能没生效。
   必须让新加的两条分布断言**真的能失败**（反证：把 `weight` 全改成 `1` → 断言必须变红）。
2. **「改期望值」≠「放宽断言」**：因第 2.5 条导致旧断言变红时，**改的是期望值**（内容变了），
   **不许**放宽/删除断言、**不许**改随机流名字去绕开。
   若某条断言你无法判断是「内容变」还是「真回归」，**在报告里点名**，不要自己拍。
3. **`tools/b1_acceptance.gd` 的 `_part2_squib_start()`**：它会把姓名写进输入框（`:243`），
   并在 `:269-270` 用 `note(...)` 打印「哑炮的 house_id = %s（正典里哑炮不进霍格沃茨）」。
   断言改成 `"none"` 之后，这两句 note 的**措辞要同步**（现在读起来像在报告一个偏差，改完就不再是偏差）。

---

## 4. 破坏实验要求（HANDOFF §4 第 12/13 条，逐步照做）

至少 **4 组**，每组都能让**特定**断言变红，证明新断言承重：

| 组 | 破坏 | 期望 |
| --- | --- | --- |
| D1 | 哑炮仍走 `assign_house` | `[creation]` 哑炮断言红 |
| D2 | 姓名仍预填「无名者」 或 删掉性别下拉 | b1 探针红 |
| D3 | 杖芯改回 `"rarity"`（或把 `weight` 全改成 1） | 新的杖芯分布断言红 |
| D4 | 传闻回到 `stream_pick` | `[world_tick]` 的权重断言红 |

**纪律（都是踩出来的，别自创）：**
1. 还原一律「先 `cp` 到备份目录 → 还原时 `cp` 回来 → `md5sum -c` 校验」。
   ⛔ **严禁 `git checkout -- <file>`**：它回到 **HEAD**，会冲掉你自己未提交的改动（Task 11 的实现者因此丢过一轮改动）。
2. 探针/破坏实验一律加**外部** `timeout`：`timeout 300 bash tools/b1_acceptance.sh`。
3. 每组实验后 `tasklist | grep -i godot` 查残留进程，有就 `taskkill //PID <PID> //F`。
4. **不要**造「永不返回」的破坏形态；**保留 deadline、只删恢复/提示**。
   （Task 10 曾因「把看门狗 deadline 变成永不触发」导致探针永不退出 → bash 死锁 4 分钟 + 残留 Godot 进程。）
5. **不要并发跑两个 headless Godot 实例**（会争 `.godot/` 缓存）。

---

## 5. 验收命令

```bash
bash tools/test.sh
# 期望：EXIT=0；[creation] 与 [world_tick] 断言数上升；其余套件不下降；SCRIPT ERROR 仍是 2 条

timeout 300 bash tools/b1_acceptance.sh
# 期望：EXIT=0；失败 0（哑炮那项改为断言 house_id == "none"）
```

两段**原始输出**（含每套件断言数与总计）必须贴进报告。

---

## 6. 提交与报告

- **只提交，不要 push**（控制器统一推送）。`git add` 只写明确路径，严禁 `git add -A`：
  ```bash
  git add data/wand_cores.json src/rules/character_creation.gd src/ui/main.gd \
          src/core/rng_service.gd src/model/world_state.gd \
          tests/creation_test.gd tests/world_tick_test.gd tools/b1_acceptance.gd
  ```
  提交信息：`fix(rules,ui): 哑炮不进霍格沃茨 + 创建界面姓名/性别 + 权重/稀有度生效（§8#69/#70/#16/#21）（计划 03a Task 12）`
  （新增脚本要连 `.gd.uid` 一起 `git add`——本任务不改脚本文件名，按说不会有新的 `.uid`。）
- **⚠️ 先写报告文件再返回**（Task 1 的实现者曾提交后超时，报告永久缺失）：
  `.superpowers/sdd/2026-09-20-hp-magic-era-03a-factions/task-12-report.md`
  必须含：
  1. 改动文件与行数（`git show --stat`）
  2. 绿步原始输出（`tools/test.sh` + `b1_acceptance.sh`）
  3. 红步原始输出（计划 Step 2 的失败输出 + 4 组破坏实验各自的输出）
  4. 断言数前后对比（逐套件）
  5. **声明性偏离**：任何与计划文本不一致的地方 + 依据与理由
  6. 你发现但**没修**的残余（范围外的东西不要偷偷修，登记进报告）
  7. 你对 `wand_woods` 的处置选择与理由（见 §2.2）

---

## 7. 不要做

- 不改 `docs/`（台账由控制器写）、**不 push**、不动 `assets/`（另一个 agent 正在那里加字体/切片）
- 不重构无关代码、不加计划外的新功能、不改 `§8` 里其他挂账项
- 不改 `data/rumors.json` 的权重数值（`weight` 生效即可，**调参不在本任务范围**）
