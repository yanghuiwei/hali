# Task 6 修复轮 · scoped 复审简报（reviewer）

> 只读复审。禁止修改文件、禁止 git 写操作。工具：read、bash（只读 + `bash tools/test.sh`）。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。
> 第一轮完整审查见 `.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-6-reviewer.log`
> （Critical=0 / Important=3 / Minor=5）。

## 修复提交

- 修复轮：`2341540 fix(creation): 封堵 aptitude_special 注入 + 校验 birthplace + 收窄性格/学院判定`
- 原始实现：`f3d8a31`
- 查看：`git show 2341540`、`git diff f3d8a31..2341540`

## controller 声称本轮处置的内容（请逐条核实）

1. **Important #1（`aptitude_special` 反漏洞被绕过）**：
   - `validate_choices`：`aptitude_id != "special"` 时若 `aptitude_special` 非空，追加 `aptitude_special` 错误；
   - `create()`：只有 `aptitude_id == "special"` 才写 `p.aptitude_special` 与 `p.flags[aptitude_special]`。
2. **Important #2（`birthplace` 未校验）**：`validate_choices` 新增 `registry.has("locations", birthplace)`，非法即报错。
3. **Minor #5（性格与学院判定收窄）**：`personality` 每个关键词必须非空；`create()` 用 `.duplicate()` 复制数组（不再与调用方共享引用）；
   测试把 `sly_house` 的弱断言（是四院之一）改为精确 `== "slytherin"`；新增哑炮 `assign_house == "none"` 覆盖。
4. **计划同步**：计划 Task 6 的 Step 1（测试）与 Step 4（实现）代码块已同步为与代码逐字一致。
5. **新增回归测试（共 +5 断言，`[creation]` 141 → 146）**：漏洞输入被拒且不产出玩家、非法出生地报错、空性格关键词报错、哑炮不判学院、斯莱特林精确判定。
6. **反证（controller 执行）**：临时删除 `aptitude_special` 的 `elif` 门与 `birthplace` 校验后运行，得到
   `[creation] 非特殊资质携带 aptitude_special 必须被拒绝: 期望为真`、`校验失败时不产出玩家: 期望为真`、`非法出生地必须报错: 期望为真`，
   `[creation] 失败=3`，EXIT=1；随后还原并复跑绿。**注意**：`create()` 侧的 special 门无法被现有测试单独证伪（validate 先拦下），属纵深防御，请评估是否可接受。

## 请你完成

1. `git diff f3d8a31..2341540` 逐行核对是否只含上述内容、无夹带、无越界文件（应仅 `character_creation.gd`、`creation_test.gd`、计划文档）。
2. 独立判断 #1 的两道门是否**充分**：
   - 是否还有其它路径能把任意键写进 `player.flags`（例如 `bloodline.default_flags`、`aptitude.grants`、`aptitude_special`）；
   - `aptitude_id == "random"` 被掷定为 `special` 时会怎样（此时 `aptitude_special` 为空，是否会出现「special 资质但无天赋」的不一致，是否可接受）；
   - 合法的 special 流程（`aptitude_id="special"` + 合法/非法 `aptitude_special`）是否仍按预期工作。
3. 独立判断 #2 是否**正确且不误伤**：合法的 12 血统 / `base_choices` 路径是否都仍能创建；出生地空值是否被拒；是否仍有 `p.birthplace` 与 `p.location_id` 口径不一致的残留。
4. 独立判断 #3：`.duplicate()` 是否真的切断了引用共享（可沙箱验证）；空关键词校验是否覆盖 `String.contains("")` 的过宽匹配问题。
5. 自己跑一次 `bash tools/test.sh`（单实例），确认 `[creation] 断言=146 失败=0`、`==== 总计失败=0，失败套件=0 ====`、
   `ALL TESTS PASSED`、`全部通过。`、退出码 0。
6. 复核计划 Step 1/Step 4 与代码逐字一致。
7. 明确第一轮哪些 finding **未处置**（预期：Important #3 `rarity` 死字段；Minor #4 自带魔杖 `length_inches` 未校验；#6 `prejudice_level` 写入 flags；#7c `no_magic` 部分空转；#8 冗余写入），并给出最终严重度与是否可留到后续任务。

## 输出格式

```markdown
# Task 6 修复轮 scoped 复审

复审者：<reviewer subagent>　模型：deepseek-flash　范围：f3d8a31..2341540

## 结论
- Important #1：ADDRESSED / PARTIAL / NOT ADDRESSED
- Important #2：ADDRESSED / PARTIAL / NOT ADDRESSED
- Minor #5：已收窄 / 仍过宽
- 有无新问题/夹带：有（列出）/ 无
- 总评：**通过** / **不通过（需再修）**

## 证据
<diff 观察、测试原始输出关键行、对两道门/出生地/引用的独立推演或沙箱验证>

## 残留发现（含第一轮未处置项）
| # | 严重度 | 位置 | 问题 | 是否可留到后续任务 |
|---|--------|------|------|--------------------|

## 未验证/存疑
```
