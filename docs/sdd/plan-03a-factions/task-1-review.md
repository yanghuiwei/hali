# Task 1 审查记录 · 12f6a50..eacb773

> 审查者：只读 `reviewer`（deepseek-flash，run 747ee7f9）｜审查包：`review-12f6a50..eacb773.diff`（1 commit, 20700B）
> 结论：**Spec ✅ 符合；Task quality = Approved**；Critical 0 / Important 0 / Minor 5（其中 4 条 plan-mandated）
> 控制器核对（2026-09-20）：工作区干净、`.uid` 未被引擎二次改写、`bash tools/test.sh` 逐字 `EXIT=0`（`[registry] 断言=210 失败=0`、`总计失败=0，失败套件=0`、`全部通过。`）。

## Spec Compliance（逐条）

1. `data/factions.json` 17 条 + 逐字段取值 ✅ —— id 列表与简报逐字一致（`:3,24,39,54,69,87,104,119,141,163,178,193,208,223,238,253,272`）；17×9 字段全核；点名项 `death_eaters.base_power=0.05`（`:127`）、其 `era_overrides` 恰 6 时代（`:131-138`）、`ministry` 5 个覆盖 0.30/0.20/0.65/0.55/0.45（`:16-20`）；`era_overrides` 空对象 10 处 + 带值 7 处 = 17、带值键数 26，与测试断言数互为校验。
2. `data/governments.json` 4 条 + `canon_line` + summary ✅ —— `canon_line` 160/162/164/166（`:5,11,17,23`）经正典原文件 150–174 行核对无误；4 条摘要与正典相符；两内容文件正则核对无任何真实人物姓名（第十三章家族名留给 03c 的约束满足）。
3. `src/core/registry.gd` ✅ —— 两表注册于 `"eras"` 后（`:6-7`）；「缺 label 必须报错」**仍是逐表检查**（`:89-90`），实现选择「叠加」而非「替换」（比 brief 措辞更保守）；**点名风险实测否证**：`_validate_entry()` 只对 `factions`（`:105`）/`governments`（`:127`）有分支，其余表返回空数组 → 既有 15 张表行为逐字不变；缺失/空表分支仍在 `:79-82`。
4. `src/rules/factions.gd` 只含常量 ✅ —— 28 行、无 `func`，9 个 `const` 与简报逐字一致；`.gd.uid`（`uid://b3iab2qb8125d`）随脚本入库。
5. `tests/registry_test.gd` 新断言非恒真 ✅ —— 新增 184 条 = 19 表级 + 85 逐派系字段 + 11 institutions + 17 rivals + 23 allies + 26 era_overrides + 3 坏内容；26+184=210 与绿灯日志吻合。简报要求**不含**的「两处枚举一致性」断言确实未包含（全文 grep `WorldFactions` 0 命中）。

### ⚠️ 无法只从 diff 判定（控制器已处理）

| 项 | 控制器核对结果 |
| --- | --- |
| Task 9 的 aliases 关键词命中行为 | 转 Task 9 dispatch 显式裁定（见 Minor 1） |
| `.gd.uid` 是否与引擎生成值一致 | ✅ 提交后 `git status` 干净、`git diff HEAD -- '*.uid'` 空 → 未被二次改写 |
| 日志无字面 `EXIT=` | ✅ 控制器重跑：`bash tools/test.sh` → `EXIT=0` |
| 2 条 `SCRIPT ERROR` 噪音 | ✅ 与基线逐字同位置同文案（`task-1-baseline.log:19,28` vs `task-1-test-green.log:19,28`），本次新增 0 条 |

## Strengths

- 内容与简报取值表逐字段一致（17×9 字段 + 26 条 era_overrides 全核），无一处静默改值。
- 提交范围精确：6 文件纯新增 438 行，无越界文件、无残留临时探针。
- `validate()` 用「叠加」而非「替换」，把 15 张既有表的 label 校验原样保住（比 brief 措辞更安全），是本次最值得肯定的一处判断。
- diff 之外只查了 3 处点名风险并全部否证：`TABLE_FILES` 无泛化消费者；`duplicate_ids` 按表计算（`registry.gd:29-43`），跨表 id 复用（`hogwarts`/`gringotts`/`black_market`）不冲突；创建界面仍 7 个下拉。

## Issues（Critical 0 / Important 0 / Minor 5）

1. **`data/factions.json:211`：`black_market.aliases` 含裸地点名「翻倒巷」**（与 `data/locations.json:4` 的地点 label 同名）。影响：Task 9 的 `_detect_faction` 用 `text.contains(alias)`，任何提到「翻倒巷」的文本都会归到 `black_market`；且与实现者报告「自主决定 4：刻意不收录裸地点名」自述矛盾（`diagon_merchants:181` 未收录「对角巷」）。**处置：不阻断本任务；Task 9 前显式裁定（删别名 / 明确保留并写进报告）。**
2. **`domains`（17 条）与 `aliases`（49 条）在 `src/`、`tests/` 零消费、零校验**（`grep` 0 命中）。影响：写错值/错字没有任何测试会失败。**处置：控制器裁定并入 Task 2 的 `validate_content`（domains 白名单 + aliases 非空）。**
3. **`src/core/registry.gd:118-120`：`base_power` 值域检查不校验类型**（`"abc"` → 0.0 静默通过；`true` → 1.0 在值域内）。plan-mandated，低优先。**处置：随 Task 2 的 `validate_content` 一并收口（补类型分支）。**
4. **`tests/registry_test.gd:92-95`：`era_overrides` 断言被 `typeof == TYPE_DICTIONARY` 守卫，字段缺失时整段静默跳过**；`:106` 与既有 `:53` 的「缺少数据表」断言重复。当前 17 条都显式写了该字段故不致盲。plan-mandated。**处置：Task 2 补「`era_overrides` 必须是 Dictionary」校验。**
5. **`_KINDS/_LEGAL/_SECRECY/_INSTITUTIONS` 两处枚举重复**（`registry.gd:95-99` vs `factions.gd:6-10`，当前逐字相同）。为避开 core→rules 反向依赖的合理取舍，但护栏完全依赖 Task 2 那条一致性断言。plan-mandated。**处置：Task 2 必须真的加上该断言。**

**已核对但不算 finding**：新内容文件每字段一行的缩进风格、`era_overrides: {}` 显式空对象（字段契约要求存在，`get(..., {})` 兼容两种写法）、`death_eaters/order_of_phoenix` 在早期时代为 0.0 属简报原值、跨表 id 复用不报错。
