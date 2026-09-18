# Task 7 修复轮 2 · scoped 复审简报（reviewer）

> 只读复审。禁止修改文件、禁止 git 写操作。工具：read、bash（只读 + `bash tools/test.sh`）。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。
> 上一轮复审见 `.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-7-rereviewer.log`（提出 R1）。

## 修复提交

- 修复轮 2：`d52ebda fix(spell): 稀有度守卫改为 fail-closed 白名单 + 归一化，封死变体绕过`
- 上一修复轮：`3499881`
- 查看：`git show d52ebda`、`git diff 3499881..d52ebda`

## controller 声称本轮处置的内容（请逐条核实）

1. **R1（denylist + 精确匹配 → 变体绕过）**：`spell_resolver.gd` 把
   `const RARE_RARITIES = ["rare","legendary","稀有","史诗","传奇","神话","传说"]` 改为 **fail-closed 白名单**
   `const COMMON_RARITIES = ["common","普通","常见"]`；`target_rarity` 先 `strip_edges().to_lower()` 归一；
   守卫改为 `if not COMMON_RARITIES.has(target_rarity): 拦截`。即「不在普通白名单内的一律按稀有处理」。
2. **测试（+7 断言，`[spell]` 216 → 223）**：变体负例 `Rare`/`稀有 `/`傳說`/`uncommon`/`epic` 必须被拦；
   正例 `普通` 与 ` Common `（归一化）必须放行。
3. **计划同步**：Step 1（测试）、Step 4（const/归一化/守卫）、以及 Interfaces 第 2499 行的 `target_rarity` 说明。
4. **反证（controller 执行）**：去掉 `strip_edges().to_lower()` 后 → `[spell] 归一化后 Common 视为普通物品: 期望为假`，`失败=1`，EXIT=1；随后还原。

## 请你完成

1. `git diff 3499881..d52ebda` 逐行核对是否只含上述 1–3 项、无夹带、无越界文件。
2. 独立判断 fail-closed 修法是否**正确且充分**：
   - 变体（大小写、空白、繁体、任意未知值）是否全部被拦；`common`/`普通`/`常见` 及归一化变体是否放行；
   - **是否误伤**：默认缺键（`conditions` 无 `target_rarity`）是否仍按 `common` 放行；是否有合法调用会因 fail-closed 被错误拦截；
   - `to_lower()` 对中文/全角字符的行为；`strip_edges()` 是否覆盖全角空格。
3. 判断新增断言是否**非空转**：`" Common "` 正例应能捕获「去掉归一化」的回归；变体负例应能捕获「退回 denylist」的回归（可只读推演或沙箱验证，不得在仓库内留改动）。
4. 自己跑一次 `bash tools/test.sh`（单实例），确认 `[spell] 断言=223 失败=0`、`==== 总计失败=0，失败套件=0 ====`、
   `ALL TESTS PASSED`、`全部通过。`、退出码 0。
5. 复核计划 Step 1/Step 4 与 Interfaces 是否与代码逐字/语义一致。
6. 更新残留清单：R1 是否关闭；第一轮 Important #2（`energy_loop_count` 终身累计）及其余 Minor 的最终严重度与「留到哪个任务/需要什么裁定」。

## 输出格式

```markdown
# Task 7 修复轮 2 scoped 复审

复审者：<reviewer subagent>　模型：deepseek-flash　范围：3499881..d52ebda

## 结论
- R1：ADDRESSED / PARTIAL / NOT ADDRESSED
- 新增断言非空转：是 / 否
- 有无新问题/夹带：有（列出）/ 无
- 总评：**通过** / **不通过（需再修）**

## 证据
<diff 观察、测试原始输出关键行、变体枚举、独立推演/沙箱验证>

## 残留发现（含第一轮未处置项）
| # | 严重度 | 位置 | 问题 | 留到哪个任务 / 需要什么裁定 |
|---|--------|------|------|------------------------------|

## 未验证/存疑
```
