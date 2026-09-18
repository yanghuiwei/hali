# 计划 01 过程台账（耐久副本）

这个目录是 **subagent-driven-development（SDD）流程的耐久副本**，随源码一起提交，换机器后凭它就能接上执行状态。

| 文件 | 内容 |
| --- | --- |
| `progress.md` | 逐事件台账：每个任务的简报/提交范围/审查结论/缺陷修复轮次/控制器补跑证据/**待人类裁定项**。**接手先读这个的末尾。** |
| `task-N-brief.md` | 派给实现者的任务简报（计划原文 + 接口契约 + 验收要求） |
| `task-N-report.md` | 实现者的完工报告（改了哪些文件、Step 5 原始测试输出、偏离计划之处） |
| `task-3-review.md` | Task 3 的独立审查记录（结论 + 分级发现 + 逐条裁定 + 残余风险） |
| `review-<from>..<to>.diff` | 审查包：提交列表 + 文件统计 + 完整 diff，供只读 reviewer 使用 |

- 计划全文：`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`
- 换机器 / 续做指引：仓库根 `HANDOFF.md`
- **同步规则**：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/` 是本机工具工作区（被 git 忽略，不进版本库）。每完成一个任务，把该任务的简报、报告、审查包与更新后的 `progress.md` 复制到这里一起提交。冲突时以本目录为准。
- 已知缺口：`task-3-report.md` 不存在（Task 3 实现者未写报告，等价信息记录在 `progress.md` 的 Task 3 段落里）。
