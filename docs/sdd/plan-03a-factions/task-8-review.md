# Task 8 审查记录 · 9e896de..8bc42e9

> 审查者：只读 `reviewer`（deepseek-flash，run 77cca4a3）｜审查包：`review-9e896de..8bc42e9.diff`（1 commit / 5 files）
> 结论：**Spec ✅ 符合；Task quality = Approved**；Critical 0 / **Important 0** / Minor 7 → **无修复轮**
> 控制器核对：`task-8-test-verify.log`（`EXIT=0`、`[prompt] 34`、`[panel] 102`、`SCRIPT ERROR` 2 = 基线）；`git status --porcelain` **空**（⚠️ 项 2 闭合）。

## Spec Compliance（7/7）

1. `government` 键 ✅ `prompt_builder.gd:73-75` 先读 `flags[GOVERNMENT_FLAG]`、空才现算；label 经 `registry.entry("governments", …)`。
2. `known_factions` 键 ✅ 只遍历 `visible_faction_ids()`（`:77`），格式 `%s(%.2f,立场%+d%s)`、`,所属` 条件附加、空集 → `已知势力：无`（`:84`）。
3. **信息保护覆盖 `user_prompt` 全文** ✅ `prompt_test.gd:63-65` 对 `user_prompt` **与** `system_prompt` 整体断言 5 个未揭示派系 label；6 个未揭示派系全覆盖，无遗漏。
4. **键集合断言** ✅ `prompt_test.gd:50-54`（`keys()`→`sort()`→精确 9 键），能抓多键/少键/改名。
5. M4/M5 落地 ✅（文案更新 `b1_acceptance.gd:270-281` + 4 条行为型断言；`panel_formatter.gd:46` 改 `_label` + `panel_test.gd:170-175`）。
6. 既有 `[prompt]` 13 条断言**全保留** ✅（红步日志只列 6 条新失败 = 未删改凑绿）。
7. 绑定约束 ✅（无第三方、内容经 registry、`data/`/`src/persist/` 未动、`SAVE_VERSION` 未改、未触碰 `factions.gd`）。

## 五个点名风险的结论

1. **两键真的会进 `user_prompt`（模型可见性）** ✅ 链路核实：`build()` = `JSON.stringify(state_digest(world))`（`prompt_builder.gd:12`）→ `JsonUtil.normalize` 对 Dictionary **递归重建、保留全部键**（`json_util.gd:11-15`）→ `user_prompt` 在 `openai_compat_provider.gd:33` **原样发出**。本任务目的达成。
2. **键集合断言能抓重构/改名** ✅（但抓不到**键顺序**变化，见 M4）。
3. **「神圣二十八族」豁免** ✅ (a) 该词确在 `bloodlines.json:4` 与 `factions.json:82-86` 两张表；(b) 豁免**只**针对血统名（`prompt_test.gd:69` 断言血统 label 存在 + 理由），`:71-72` **仍独立断言** `known_factions` 不含它 → 派系侧泄漏没被放过；(c) `content_index()` 只含 `skills/spells/locations/houses/bloodlines`（`prompt_builder.gd:38`），**不含 factions** ⇒ `system_prompt` 路径不可能泄漏派系名。
4. **M5 未破坏既有输出** ✅（空 id 走 `"无"` 分支、`_label` 不会被调；`panel_test.gd:74-84` 全保留）。⚠️ 但报告 §8.4 措辞有误：`_label` 对**未知 id 回退原始 id**，「未知」只给空 id（见 M2）。
5. **B1 探针改动安全** ✅（`_world(node)` 存在、期望值现读 `institution_control()`、备份/还原未动且日志证明逐字还原 PASS）。

## Strengths（节选）

- **信息保护是"能失败"的**：审查者不采信报告自述，而是用源码推演破坏面（忽略 `revealed` 应红 8 条）再与 `task-8-destruction.log` 对照——**恰好 8 条**，完全吻合；且 `[gm]`/`[factions]` 也连锁变红。
- **键集合契约被钉死**：`fkeys.sort()` + 精确 9 键，把"提示词契约被重构"变成可失败断言；红步 `期望 9 键/实际 7 键` 与代码自洽。
- **只追加不重构**：既有 7 键的字典字面量全是 context 行，新键是末尾两行；两键计算全为**只读**调用（无 `world` 写入副作用，不污染 tick/存档）。
- M4 的断言是**行为型**（`_on_power` → 读镜像日志），不会"实现读什么就断言什么"空转。

## Issues

### Critical / Important
无。审查者逐条排除三类应拦问题：信息保护无越界（6 个未揭示派系全覆盖 + `system_prompt` 无泄漏渠道 + 破坏实验实证）、无脆弱实现、断言有判别力。

### Minor（7，全部登记 + 归属）

| # | 内容 | 控制器裁定/归属 |
| --- | --- | --- |
| **M1** | `prompt_test.gd:49-72`：**「空可见集 → `已知势力：无`」分支无任何断言**（`make_world()` 有 11 个 public 派系，空集分支从未执行）→ 若被改成 `"已知势力："` 或漏掉该分支，无断言会红 | **并入 Task 11**（测试可判别性批次，§8#64 主题） |
| **M2** | 报告 §8.4 失实（`_label` 对未知 id 回退**原始 id**，「未知」只给空 id）；未知 id 会在面板显示英文 id；**有效但未揭示**的 `faction_id` 会显示中文 label（仅手改/畸形存档可达，正常路径 `state_ops.gd:83-86` 强制可见性） | 登记 + 报告措辞更正；**不改代码**（`_label` 被广泛复用）。留 03b/05 UX 批次 |
| **M3** | 计划代码块与实现漂移（计划写不带前缀的值，实现把「政体：」「已知势力：」放进值里；实现更贴合 brief 且测试已钉住） | ✅ **控制器已改计划**（`783f8d1`，对齐实现、保留前缀） |
| **M4** | 键集合断言在 `sort()` 后比较，**抓不到键顺序变化**（"只追加在末尾"的证据目前只有 diff + 既有 13 条断言） | 登记（风险低、属文本顺序；不建议引入脆断言） |
| **M5** | `gov_id` 优先读 flags 的 3 行在 `prompt_builder.gd:73-75` 与 `panel_formatter.gd:112-114` 重复（DRY） | **并入 Task 11**（可选清理：提 `WorldFactions.government_id(world)`） |
| **M6** | `state_digest` 未防御 `initialize` 缺席（手工搭世界会得 `已知势力：无`）；与 `power_panel` 既有行为一致、生产路径必初始化 | 登记（无需改） |
| **M7** | 报告 §⑤ 摘录不全（列 6 条却写"失败=8"，未提 `[gm]`/`[factions]` 也红） | 登记（数字对、摘录不全） |

## ⚠️ 控制器裁定（spec Q4 口径）

审查者指出 spec `design.md:55` 的 Q4 写「只暴露 revealed 部分 + **权力四角权重**」，而实现只给了 per-faction `power` + `government`，没有显式 `power_share()`。
**裁定：不需要显式暴露** —— `power_share()` 是已列 power 的**纯函数**（四角归一化），再单列一份与已有信息重复；`government`（由机构控制权推导）已表达格局。**已改 spec Q4 措辞为「+ 政治格局」并附勘误**（`783f8d1`）；若 03b 的经济挂钩需要显式四角权重，那时加一个键即可（成本一行）。
