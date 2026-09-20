# Task 8 实现报告 · 提示词摘要暴露已揭示派系（计划 03a）

## ① 任务号与提交哈希

- 任务：计划 03a Task 8 —— `PromptBuilder.state_digest` 增加「政体」与「已知势力」两行，**只暴露已揭示（revealed）派系**（spec Q4）。
- 提交：**`8bc42e9`**（`feat(gm): 提示词摘要暴露已揭示派系与政体（计划 03a Task 8）`）
- 基线：`9e896de`（Task 7 顶端；控制器 docs 提交 `aa152d2`/`ad67396`/`0be229f`/`28d3a4d` 已在其中）

## ② 改动文件清单（5 个，均为 brief 允许或控制器点名）

| 文件 | 改动 |
| --- | --- |
| `src/gm/prompt_builder.gd` | `state_digest()` 末尾追加 2 个字符串键 + 15 行计算（唯一改动点，其余键与顺序逐字未动） |
| `src/ui/panel_formatter.gd` | 1 行：`player_panel` 的【所属势力】改 `_label(world,"factions",…)`（Task 7 审查 M5） |
| `tests/prompt_test.gd` | 追加 21 条断言（原 13 → 34） |
| `tests/panel_test.gd` | 追加 3 条断言（原 99 → 102） |
| `tools/b1_acceptance.gd` | Task 7 审查 M4：更新过期文案 + 4 条行为型断言（B1 探针 78 → 82 断言） |

未触碰：`src/rules/factions.gd`（仅破坏实验中临时改、已逐字还原）、`data/*`、`src/model/*`、`src/persist/*`、`SAVE_VERSION`。

## ③ 测试原始输出

**红步**（`task-8-test-red.log`，`EXIT=1`）：

```
[panel] 所属势力显示中文 label: 期望为真
[panel] 不再显示原始 faction_id: 期望为假
[panel] 断言=102 失败=2
[prompt] 摘要键集合 = 计划 02 既有 7 键 + 本计划新增 2 键（提示词契约未被重构）: 期望 <["clock", "era", "government", "known_factions", "location", "player", "recent_history", "recent_log", "world_vars"]>，实际 <["clock", "era", "location", "player", "recent_history", "recent_log", "world_vars"]>
[prompt] 摘要含政体（label 取自内容表）: 期望为真
[prompt] 摘要含已知势力行: 期望为真
[prompt] 摘要含已揭示派系: 期望为真
[prompt] 揭示后进入已知势力行: 期望为真
[prompt] 所属与立场随派系一起标注（格局未演化时 power = base_power）: 期望为真
[prompt] 断言=34 失败=6
==== 总计失败=8，失败套件=2 ====
```

**绿步**（`task-8-test-green.log`，逐字 `EXIT=0`）：

```
[panel] 断言=102 失败=0
[llm] 断言=88 失败=0
[prompt] 断言=34 失败=0
[factions] 断言=193 失败=0
==== 总计失败=0，失败套件=0 ====
全部通过。
```

- `SCRIPT ERROR` 条数：**2**（= 基线；来自 `save` 坏档负例与解析层负例，逐字同 `task-1-baseline.log:19/28`）
- `bash tools/b1_acceptance.sh`（`task-8-b1-verify.log`）：**EXIT=0，断言 78 → 82，失败 0，`全部通过。`**

## ④ 断言数前后对比

| 套件 | 前 | 后 | 差 | 说明 |
| --- | --- | --- | --- | --- |
| `[prompt]` | 13 | **34** | +21 | 键集合 1 + 政体/已知势力/已揭示 3 + 信息保护 10（5 user + 5 system）+ 豁免理由 3 + 揭示后 3 + 所属立场 1 |
| `[panel]` | 99 | **102** | +3 | M5 的 label / 不显示 id / 无所属仍「无」 |
| B1 探针 | 78 | **82** | +4 | §8#7 行为型证据 2 + 文案/含行 2 |
| 其余 16 套件 | — | — | 0 | 未触碰 |

## ⑤ 信息保护的「能失败」证据（破坏实验）

把 `WorldFactions.visible_faction_ids()` 里的 `if bool(state_of(...).get("revealed", false)):` 改成 `if true:`（忽略揭示状态），重跑：

```
[prompt] user_prompt 不含未揭示派系 食死徒: 期望为假
[prompt] user_prompt 不含未揭示派系 凤凰社: 期望为假
[prompt] user_prompt 不含未揭示派系 神秘事务司: 期望为假
[prompt] user_prompt 不含未揭示派系 翻倒巷黑市: 期望为假
[prompt] user_prompt 不含未揭示派系 欧陆纯血网络: 期望为假
[prompt] 已知势力行不含未揭示派系: 期望为假
[prompt] 断言=34 失败=8
[panel] 断言=102 失败=4   ← 面板侧的信息保护断言同时变红（跨套件相互印证）
DESTRUCTION EXIT=1
```

还原后 `md5sum -c` = `src/rules/factions.gd: OK`，`git diff --stat src/rules/factions.gd` 空（逐字还原）。

**红步过程中发现并处理的一个假红（值得记）**：`「神圣二十八族」`同时是 `data/bloodlines.json` 的**公开血统 label**（建角即可见），它出现在 `system_prompt` 是因为 `content_index.bloodlines` 本来就含它 —— 不是派系泄漏。我没有把它从断言里偷偷删掉，而是改成**显式豁免 + 理由断言**：

```gdscript
a.eq(str((ci.get("bloodlines", {}) as Dictionary).get("sacred_twenty_eight", "")), "神圣二十八族",
	"豁免理由：「神圣二十八族」是公开血统 label（建角可见）")
a.is_false(str(fdigest.get("known_factions", "")).contains("神圣二十八族"),
	"但未揭示的该派系本身不得进已知势力行")
```

**适配说明（计划缺陷，必须上报）**：brief Step 1 的断言写的是 `digest.contains("政体：")`、Step 3 写的是 `lines.append(...)`，但 `state_digest()` 实际返回的是 **Dictionary**（计划 02 spec §6.5 的键集合契约，既有断言用 `big["recent_log"]` 索引）。若照抄 brief：

1. Step 1 的 `digest.contains(...)` → `Nonexistent function 'contains' in base 'Dictionary'` → **套件中止**（§8#56 陷阱）；
2. 我第一版用 `fdigest["government"]`（下标访问缺失键）→ 实测 `SCRIPT ERROR: Invalid access to property or key 'government' …` → **同样中止套件**。

因此改成：两行以两个字符串键 `government` / `known_factions` 承载（保持「末尾追加两行」的语义），断言用 `.get(..., "")` 读取缺失键 → 红步变成**干净的断言失败**（见 ③）。这一步同时用**键集合断言**钉住了「既有 7 键一个没动」。

## ⑥ 收口 3a 的验收探针证据

`tools/b1_acceptance.gd::_part5_panels`：文案已更新（不再写「7 个标签映射到 4 个 world_vars」），并新增 4 条断言走**真实 UI 链路**（`node.call("_on_power")` → 读 `log_view`）：

```
[PASS] world_vars 没有机构键（指标不来自标量，§8#7 已修）
[PASS] 势力面板傲罗指标 = 派系控制权 0.62
[PASS] 改控制权后面板随之变化（§8#7 的行为型证据）
[PASS] 含【已知势力】行
B1 自动验收最终：断言 82 条，失败 0 条
```

注意实测值是 **0.62**（不是内容表里的 `base_power` 0.60 —— 因为探针此前已跑过 4 个回合，`evolve()` 的控制权滞后让 0.60 漂到 0.62）。这正是我把期望值**从 `institution_control()` 现读**而不是硬编码 0.60 的原因；硬编码会假红。探针会写 `user://`，其备份/还原逻辑未改动（本轮 `llm_settings.json`/`slot1.json` 还原断言均 PASS）。

## ⑦ 提示词契约未被破坏的证据

`req1.system_prompt` / `req1.user_prompt` 在改造前后对同一世界**必然变化**（新增两行进 `user_prompt` 的 JSON），故按控制器要求改为「除新增两行外其余逐字一致」，用两种方式钉住：

1. **键集合断言**（新增）：`fdigest.keys()` 排序后必须恰为
   `["clock","era","government","known_factions","location","player","recent_history","recent_log","world_vars"]` —— 即计划 02 的 7 键 + 新 2 键，**没有**多键、少键或改名；
2. **既有断言全部保留且仍绿**：`[prompt]` 原有 13 条（系统/用户提示确定性 `req1 == req2`、定界符与注入剥离、`secret_internal` 剔除、`potions` 索引、超大 log 截断顺序、修复提示带原因）**一条未改**且全绿；
3. `system_prompt` 的**构造**只由 `content_index()` 决定，本任务未动 `content_index` → `req1.system_prompt == req2.system_prompt` 的既有断言仍是确定性证据。

## ⑧ 未验证项 / 残余

1. **未跑真实 LLM**：只验证了提示词**文本**正确与信息保护；模型看到新两行后叙事是否恰当，需真机联调（B2，用户已裁定暂不做）。
2. **`known_factions` 的 token 预算**：11 个已揭示派系全列时该行约 300+ 字符；未做截断/排序裁剪（spec §13.3 的预算议题留 03b/后续）。当前 17 派系规模下可接受，未加断言。
3. **提示词里 `government` 的两层来源**：优先读 `flags[GOVERNMENT_FLAG]`、缺失才现算。测试覆盖了「新建未 tick 时现算」（`make_world()` 不 tick ⇒ 走现算分支）；**未**覆盖「flags 有缓存时以缓存为准」——该路径在 `panel_test` 已有等价断言（Task 7），但 `prompt_test` 未重复。
4. **`_label()` 未知 id 的行为**：M5 改动依赖 `_label` 对未知 faction id 返回「未知」（我在 `panel_test` 只断言了「有 id → label」「空 id → 无」两种），**未**断言「未知 id → 未知」。
5. 破坏实验只做了「忽略 revealed」一种；未做「删掉某一行的 key」等其它破坏面。

## ⑨ 是否触碰 brief 未列出的文件

**是，三个，均为控制器在 dispatch 中点名的收口项**：

1. `src/ui/panel_formatter.gd`（Task 7 审查 **M5**）；
2. `tests/panel_test.gd`（M5 的断言落点）；
3. `tools/b1_acceptance.gd`（Task 7 审查 **M4**）。

除此之外未触碰任何 brief 未列出/控制器未点名的文件。`data/`、`src/rules/`、`src/model/`、`src/persist/` 全未改动。
