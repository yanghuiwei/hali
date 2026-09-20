# Task 11 实现报告 · 顺手项 B（§8#61 / §8#64 / §8#65）+ 7 条挂账 Minor

**任务**：计划 03a Task 11 ｜ **提交**：`17ff8e5`（14 files, +173 / -18）｜ **分支**：`plan-03-factions`
**status：DONE**（无 concerns；详见 §7 残余）

---

## 1. brief 三条顺手项

| 项 | 改动 | 断言 |
| --- | --- | --- |
| **§8#61** 降级原因透出 | `LlmGameMaster._fallback()` 两条分支（有/无 fallback）都 `warnings.append("LLM 降级：%s" % reason)`。有 fallback 时**原因不进叙事**（叙事仍由本地替身产出 + 一句降级说明），走 warnings → `TurnEngine` 并进 `op_errors` → UI 打印 | `[llm]` +5：降级写进 warnings、原始错误串进 warnings、`last_error` 仍保留、无 fallback 分支也进 warnings、有 fallback 时原因走 warnings |
| **§8#65①** `act` 可协程 | `src/gm/game_master.gd` 的 `act` 上方补契约说明（同步或协程，调用方统一 `await`；协程实现**必须**覆写 `is_async()`）——计划 02 spec §5 文件表要求而未落 | 文档级（无断言，见 §5 说明） |
| **§8#65②** 命名漂移 | spec `2026-09-19-...-02-llm-narrative-design.md` 的 `_post_submit` → `_resolve`（2 处：§5 文件表行、§6.3 正文），并注明「以 `turn_engine.gd` 实现为准」 | 文档级（`grep -c _post_submit` 结果为 **1**：只剩我加的那句说明） |
| **§8#65③** 鸭子类型 | `GameMaster.is_async()`（默认 `false`）/ `LlmGameMaster.is_async()`（`true`）；`TurnEngine.submit()` 由 `gm is LlmGameMaster` 改为 `gm.is_async()`，且拒绝时 `narration` 非空 | `[gm]` +5：离线替身声明同步、LLM 声明协程、拒绝 blocked、narration 非空且含「异步」、被拒提交不推进回合 |
| **§8#64①** 重试判别力 | `[llm]` 断言第二次请求的 `system_prompt` 含「上一次输出无法解析」**且第一次不含** | `[llm]` +2 |
| **§8#64②** 准恒真断言 | 原 `res3.narration.length() > 0`（fallback != null 时恒真）→ 拆成「叙事含『本地规则结算』」+「原因走 warnings」 | `[llm]` 改动 1 条 → 2 条 |
| **§8#64③** 脱敏负向断言 | Task 10 已落（`mask()` 三条），本任务复核未重复添加 | — |

## 2. 7 条挂账 Minor 逐条处置

| # | 处置 | 证据 |
| --- | --- | --- |
| **Task 8 M1**（空可见集无断言） | ✅ 实施：`prompt_test` 造「全部派系 `revealed=false`」夹具 + **夹具前置断言**（`visible_faction_ids().size()==0`）+ 断言 `known_factions == "已知势力：无"` + 政体键形态不受影响 | 破坏 E5（把该分支改成 `"已知势力："`）→ **1 条精准红** |
| **Task 8 M5**（取政体 id 重复 3 行） | ✅ 实施：新增 `WorldFactions.government_id(world)`（缓存优先 / 空串现算），`prompt_builder` 与 `panel_formatter` 两处改为调用 + 4 条断言（无缓存现算、有缓存优先、缓存值来自内容表、空串视为无缓存） | 破坏 E6（让 `government_id` 忽略缓存直接现算）→ **1 条精准红** |
| **Task 9 M4**（回退路径无断言） | ✅ 实施：`[gm]` 断言「我去魔法部打听消息」→ `tags.has("social")` + 派系 op 计数为 **0** | 破坏 E8（命中派系名但无关键词时提前 return）→ **2 条红**（其中 1 条是 Task 9 既有断言「抗议产出 -5」） |
| **Task 9 M5**（label 是否硬编码） | ✅ 实施：`Registry.from_tables` 全量复制（逐条 `duplicate(true)`，避免改到已加载注册表）→ 把 `ministry` 的 label 改成「奥术部」→ 断言夹具自检（改名生效）+ 旁白含「奥术部」**且不含「魔法部」** | 破坏 E9（把旁白 label 硬编码回「魔法部」）→ **2 条精准红** |
| **Task 9 M8**（`faction_standing_delta` 缺 revealed 校验） | ✅ 实施：`state_ops.gd` 补 `elif not visible_faction_ids(world).has(id): errors.append("该派系尚未揭示，无法表态: %s")`，与 `join_faction` 同门 + 5 条断言（被拒不改 standing、被拒不改派系态度、揭示后正常写入、态度反向变化） | 破坏 E7（删掉该分支）→ **5 条精准红** |
| **Task 10 P2-1**（探针措辞自相矛盾） | ✅ 实施：`tools/b1_acceptance.gd` 两处——`_submit_bounded` 注释改为「持有**外层**句柄救不回内层链」；`_part11b` 标题改为「（可观测契约，非 I1 护栏）」 | 纯注释（无断言） |
| **Task 10 P2-2**（`_turn_state` 只写死状态） | ✅ 实施（**选删除**）：`main.gd` 删掉声明与那一行写入，注释写明理由。理由：它没有任何读取点（`grep -n _turn_state src/` 现为 0 命中），留着会让读者误以为它参与判定；判定早已全部走本轮私有 `round_state` | 全仓 `grep _turn_state` = **0 命中**；全套件绿灯 + 探针绿灯 |

## 3. 红 → 绿（原始输出）

**Step 2 红步**（`task-11-test-red.log`，逐字 `EXIT=1`）：

```text
[llm] 并给出降级原因: 期望为真
[llm] 降级事件写进 warnings: 期望为真
[llm] 降级原因（原始错误串）进 warnings: 期望为真
[llm] last_error 仍保留原始原因: 期望为真
[llm] 无 fallback 时降级原因也进 warnings: 期望为真
[llm] 断言=106 失败=5
==== 总计失败=7，失败套件=3 ====
```
（另 2 个失败套件是 `[gm]`/`[factions]` **解析失败**：`Static function "government_id()" not found in base "WorldFactions"` —— 红步证明「测试真的在等一个还不存在的实现」。）

**Step 4 绿步**（`task-11-test-green.log`，逐字 `EXIT=0`）：

```text
[harness] 断言=8 失败=0     [registry] 断言=244 失败=0   [money] 断言=18 失败=0
[magic_level] 断言=48 失败=0 [model] 断言=49 失败=0       [clock] 断言=47 失败=0
[world_tick] 断言=180 失败=0 [creation] 断言=176 失败=0   [spell] 断言=229 失败=0
[gm] 断言=128 失败=0        [panel] 断言=102 失败=0       [selfcheck] 断言=32 失败=0
[save] 断言=112 失败=0      [async_probe] 断言=2 失败=0   [llm] 断言=106 失败=0
[prompt] 断言=38 失败=0     [debug_mirror] 断言=23 失败=0 [factions] 断言=204 失败=0
==== 总计失败=0，失败套件=0 ====
全部通过。
```

- `SCRIPT ERROR` 条数：**2**（= 基线 2；两条即 `save_test.gd:80` 的畸形载荷负例，`player.personality`/`game_clock` 各一条）
- **探针**：`timeout 300 bash tools/b1_acceptance.sh` → **EXIT=0**，`B1 自动验收最终：断言 105 条，失败 0 条`
- **临时单套件快跑器 `tools/_tmp_suite.gd` 已删除**（`git status` 干净，无残留）

## 4. 断言数前后对比

| 套件 | 改前 | 改后 | Δ |
| --- | --- | --- | --- |
| `[gm]` | 116 | **128** | +12 |
| `[llm]` | 97 | **106** | +9 |
| `[prompt]` | 35 | **38** | +3 |
| `[factions]` | 193 | **204** | +11 |
| 其余 14 套件 | — | 不变 | 0 |
| B1 探针 | 105 | 105 | 0（未改探针逻辑，仅注释） |

## 5. 破坏实验（`能失败的证据`，共 9 组）

方法：单套件快跑器（`tools/_tmp_suite.gd`，带 SceneTreeTimer 看门狗 + 外部 `timeout 120`）→ 改一处 → 跑 → **从备份副本还原** → 复跑确认绿。**不使用 `git checkout` 还原**（详见 §7-4 的自曝教训）。

| # | 破坏点 | 结果 |
| --- | --- | --- |
| E1 | 删掉 `_fallback` 的两条 warnings 追加 | `[llm]` **4 红** |
| E2 | `build_repair` → `build` | `[llm]` **7 红**（含「第二次请求带修复提示」） |
| E3 | `FALLBACK_NOTE` 文案改掉 | `[llm]` **2 红**（「本地规则结算」那条） |
| E4 | 删掉 `LlmGameMaster.is_async()` 覆写 | `[gm]` **4 红**（含「被拒的提交不推进回合」） |
| E5 | 空可见集分支改成 `"已知势力："` | `[prompt]` **1 红** |
| E6 | `government_id` 忽略缓存 | `[factions]` **1 红** |
| E7 | 删掉 standing 的 revealed 校验 | `[factions]` **5 红** |
| E8 | 命中派系名但无关键词时提前 `return` | `[gm]` **2 红** |
| E9 | 旁白 label 硬编码成「魔法部」 | `[gm]` **2 红** |

每组还原后 md5 与备份**逐字一致**（7 个源文件全 `OK`），随后四条受影响套件复跑全部 `失败=0`。

## 6. 触碰的文件（brief 未列出但控制器点名）

- `src/rules/factions.gd`（M5 新增 `government_id()`）、`src/rules/state_ops.gd`（M8 补门）、
  `src/ui/panel_formatter.gd`（M5 改调用）、`src/gm/prompt_builder.gd`（M5 改调用）、
  `src/ui/main.gd`（P2-2 删只写成员）、`tools/b1_acceptance.gd`（P2-1 措辞）、
  `tests/prompt_test.gd`、`tests/factions_test.gd`（M1/M5/M8 断言）。
- **未触碰**：`data/`、`src/persist/`、`src/model/`、`docs/superpowers/plans/`（计划文本由控制器维护）、
  `scripts` 表、存档格式与 `SAVE_VERSION`。

## 7. 未验证项 / 残余（如实登记）

1. **`§8#65①`（`act` 可协程注释）与 `§8#65②`（spec 命名同步）没有断言**——它们是文档/契约注释，无运行时可判别信号。可核对证据：`grep -c "_post_submit" spec` = 1（仅剩说明句）；`game_master.gd` 的注释块 + `is_async()` 声明。**不作护栏**。
2. **§8#64② 的"原因走 warnings"这条是我按实现口径写的**：有 fallback 时原因**不进叙事**（叙事由本地替身 + 一句降级说明），只有 `fallback == null` 分支才把原因拼进叙事。若控制器希望"有 fallback 时叙事里也带原因"，那是一次用户可见文案变更（不在本任务范围）。
3. **`MockLlmProvider` 的 `errors` 必须覆盖 `MAX_ATTEMPTS`(2)**：我第一版夹具只给 1 条错误，最终透出的原因是 `mock 队列为空` 而不是我想验的病因（红步 3 条红暴露了它）。已在测试里写明注释。这是**共享夹具的陷阱**，后续写 Mock 的测试要注意。
4. **⚠️ 我自曝一个流程事故（已修正，建议写进踩坑清单）**：E1 的还原我用了 `git checkout -- <file>`，它回到 **HEAD** 而不是回到实验前的工作区状态 → **把我本人未提交的 `llm_game_master.gd` 改动冲掉了**（校验输出 `还原校验: MISMATCH` 暴露）。处置：重新应用改动 + 改用「先 `cp` 到备份目录、还原时 `cp` 回来」，之后 9 组实验的还原校验全部 `OK`。
   **建议**：破坏实验的还原一律用副本备份（或对未提交改动先用 `git stash`/临时提交保护），**不要**用 `git checkout` 对付未提交的工作区。
5. **`government_id()` 未加空值守卫**（与 `government_type()` 一致）：生产路径（`create`/`from_dict` 已初始化）不可达。登记。
6. **`is_async()` 是新增虚方法，未在 spec 的 §6.1 之外登记**：`tests/gm_test.gd` 只覆盖「基类 false / Llm 子类 true / TurnEngine 拒绝」三面；若有第三种 GM 实现（如未来的 Mock 协程 GM），需自行覆写——已写进 `game_master.gd` 的注释。
7. **spec 只改了控制器点名的两处**（`_post_submit`→`_resolve` 与 §6.1 的 `is_async()`）；spec 里其它与代码的潜在漂移（若有）未顺手扫，保持"标点级同步"的范围。
