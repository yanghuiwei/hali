# 加固批次 修复轮 scoped 复审记录

审查者：reviewer subagent（只读）　模型：deepseek-flash　范围：`e094a52..7d24783`

## 结论
- Important #1：**ADDRESSED**（三条「不写入」断言均落地且经反证可判别）
- Minor #2 / #4：**ADDRESSED / ADDRESSED**
- 新缺陷：**无**
- 裁定：**通过**

## 证据

### 0. 范围与越界（核对项 5）
```
git diff --name-status e094a52..7d24783
A  docs/sdd/plan-01-core-foundation/review-e72e54d..e094a52.diff   # 审查包工件（上轮 review diff）
M  tests/gm_test.gd
M  tests/magic_level_test.gd
M  tools/test.sh
```
无 `src/`、无 docs 计划文档改动。唯一 docs 变更即审查包 diff 文件（简报明确属允许范围）。HEAD=`7d24783`，分支 `plan-01-core-foundation`。
`docs/.../review-e094a52..7d24783.diff` 内容 = 3 行头部 + `git diff e094a52..7d24783 -- tests tools` 的逐字副本（对比确认一致，头部注明「review diff 略」）。

### 1. 三条修复落实（核对项 1）
- **Important #1**（`tests/gm_test.gd:53,66-68`）：
  `var money_before_bad := w.player.money_knuts` 在非法批次 `errs4` 之前采样；新增
  `is_false(w.player.flags.has(""))`、`eq(w.player.money_knuts, money_before_bad)`、`is_false(w.player.relations.has(""))`，
  与既有 `is_false(w.flags.has(""))` 构成四个 op 的对称覆盖。`errs4.size()==5` 的计数断言保留。
- **Minor #2**（`tests/magic_level_test.gd:11-17`）：新增 7 条 `label_of` 精确断言，与原有 3 条（SQUIB/PRE_SCHOOL/MYTH）合起来十档文本逐档钉死；文本与 `src/rules/magic_level.gd:6-9` 的 `LABELS` 逐字一致。
- **Minor #4**（`tools/test.sh:26`）：`mktemp` 后紧跟 `trap 'rm -f "$smoke_log"' EXIT`，单引号延迟展开正确、变量在 trap 执行时已赋值；末尾原 `rm -f` 保留（幂等，正/失败路径双保险）。

### 2. 反证 Important #1（逐个 op 实测变红后还原）
| 反证注入 | 观测 | 退出码 |
|---|---|---|
| `set_player_flag` 改为「先写入后报错」 | `[gm] 空 player flag key 未写入: 期望为假`；`[gm] 断言=59 失败=1` | **EXIT=1** |
| `add_money` 改为「报错但仍写入」 | `[gm] 非法 add_money 不改动财富: 期望 <5430>，实际 <5437>`；`失败=2` | **EXIT=1** |
| `relation_delta` 空 `npc_id` 改为仍写入 | `[gm] 空 npc_id 未写入: 期望为假`；`失败=1` | **EXIT=1** |

第一条与控制器实测完全吻合（`空 player flag key 未写入`、`[gm] 失败=1`、EXIT=1）。每次注入后均 `git checkout -- src/rules/state_ops.gd`，md5 复核 = `ff6b0e63ed0f56c5e8273f5aefe299ff`（与注入前一致）。→ 上轮「回归可静默通过」的假绿缺口已关闭。

### 3. 反证 Minor #2（核对项 3）
把 `LABELS` 的 `"专家级"` 改成 `"专家"`（仅此一处），跑 `magic_level` 套件：
```
[magic_level] 第七级: 期望 <专家级>，实际 <专家>
[magic_level] 断言=48 失败=1 ；runner EXIT=1
```
还原后 md5 = `f7c178cbfc6307bfe3dd6b62953b17f1`（一致）。→ 十档文本断言确有判别力。

### 4. 全量回归（核对项 4）
`TMPDIR=/tmp/... bash tools/test.sh`，**EXIT=0**：
```
[probe] 断言=1 失败=1（哨兵负例，预期）
[harness=8] [registry=26] [money=18] [magic_level=48] [model=49] [clock=47]
[world_tick=104] [creation=176] [spell=227] [gm=59] [panel=71] [selfcheck=32] [save=96]
==== 总计失败=0，失败套件=0 ====  ALL TESTS PASSED
main scene ready, godot=4.7.2-stable (official)   全部通过。
```
13 套件失败=0，`[magic_level] 48`、`[gm] 59` 与预期一致；冒烟日志出现 `main scene ready`。把 `TMPDIR` 指向空目录后运行，运行结束残留文件数 = 0（trapt + 显式 rm 均生效）。

### 5. 只读纪律/还原自证
`git diff --stat HEAD` 为空；临时 runner `tests/_tmp_reviewer_probe.gd` 及其 Godot 生成的 `.uid` 已删除；`git status --porcelain --untracked-files=all` 仅剩**开始审查前就存在**的 `?? docs/sdd/plan-01-core-foundation/review-e094a52..7d24783.diff`。`src/`、`tests/`、`tools/` 均已回到 HEAD 状态。

## 残余风险 / 建议
1. 上轮 **Minor #5 未处理**（简报范围外，予以确认而非判负）：`save_test.gd` 「非十六进制校验和被拒」命名夸大（实为普通校验和不匹配）；§8#40「第 14 回合 audit 为空」、§8#43「哑炮分支 2 子串」未补；§8#37「`relation_delta` 增量无上下限」本轮仍只补了空 `npc_id`。建议并入下批或写入 HANDOFF 未关闭清单。
2. 上轮 **Minor #3 仍在**：`run_tests.gd` 的哨兵只覆盖「未调用 report」的中止性错误，非中止运行期错误仍会 `EXIT=0`。属既有边界，非本轮引入。
3. `magic_level_test` 中自反式 round-trip 循环（`index_of_label(LABELS[i])==i`）被保留而非删除。因十档文本已全部字面钉住，判别力不再依赖该循环，判定不构成问题；但与简报「替换」字面略有出入（实为「补充 + 保留」）。
4. `tools/test.sh` 的 trap 实际增益限于信号中断（无 `set -e`，各失败路径本就被末尾 `rm -f` 覆盖）。属正确且无害的加固。
5. 轻微：新断言直接用 `w.player.money_knuts` 字段采样（与文件内既有风格一致），非 `money().to_knuts()`；无风险。

## 未验证/存疑
- **未实测 SIGINT 下的 trap 生效**（需打断冒烟进程，不可稳定复现；且会污染 `.godot` 缓存），仅静态核对 trap 语法/展开时机 + 正常路径零残留。
- 未对 `docs/sdd/.../review-e094a52..7d24783.diff` 是否应随代码提交作约定性判断（简报已将其列入允许范围，故不计为越界）；但把审查包工件并入修复提交属实践层面的可讨论点。
- 未重新审查 `e094a52` 之前的历史实现（本轮严格限定增量范围）。
