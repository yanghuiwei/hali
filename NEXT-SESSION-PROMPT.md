# 新会话开场语（直接复制下方整块内容发给 agent）

> 用途：换会话/换机器接手时，把下面 ``` 代码块里的内容**整段**粘贴给新会话的 agent 即可。
> 为什么单独放一个文件：聊天窗口里的长文本不方便复制，这里有版本控制、可随时更新。
> 维护规则：**每完成一个任务就回来更新本文件**（尤其是「现状」与「接下来做什么」两段 + 体检数字），
> 并与 `NEXT-STEPS.md`（待办全表）、`docs/sdd/<plan>/progress.md`（耐久台账）三份保持一致。
> **这三份的刷新是「每任务收尾清单」的第 1–3 步，见下方。**

---

```text
项目 E:/Hali（Godot 4.7.2 stable，Windows + Git Bash，纯 GDScript）。交付点 = 分支 `main`
（顶端以 `git log --oneline -1` 为准，**文档里不钉死哈希**）。

【先做体检】
git fetch origin && git status -sb          # 期望：干净。⚠️ 仓库根可能有**外来**未跟踪文件（如 .workbuddy/），不算失败，别删别提交
bash tools/test.sh                          # 期望：EXIT=0；21 套件 / 2023 断言 / 失败 0；4 步全过
timeout 300 bash tools/b1_acceptance.sh     # 期望：EXIT=0；151 断言 / 0 失败（会临时移走 llm_settings.json 并逐字还原）

`tools/test.sh` **自带 stderr 噪音门禁**：`SCRIPT ERROR` 必须 == 2 **且** `^ERROR:` 必须 == 7，不符即 `EXIT=1`。
这两个数字是**健康指标**（不是失败）：只在刻意增删负例时改常量（`tools/test.sh` 的 `EXPECTED_*`，可用环境变量覆盖）。
**新增噪音通常都是真 bug**（JSON 解析失败 / 资源加载失败 / 类型赋值错误），而且这类问题**套件内断言抓不到**
（已有 3 次独立实证：拆 `ResourceLoader.exists` 守卫、拆 scheme 守卫、`generate_wand` 有类型接收）。

【按顺序读（不要跳）】
1. `HANDOFF.md` —— 现状、铁律、§4 踩坑清单、§8 待裁定项
2. `NEXT-STEPS.md` —— 先读 §0A「快跑模式」，再读 §B 的当前待办
3. `docs/sdd/plan-03a-factions/progress.md` —— 耐久台账（每任务提交/断言数/审查结论/挂账）
4. 计划与 spec：
   - `docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md`（03a，13 任务；**文本被按实跑修正过多次，以文件为准**）
   - `docs/superpowers/specs/2026-09-20-hp-magic-era-03a-P-presentation-design.md`（表现层与素材契约；§2 有 🔒 接口冻结）

【现状（一句话）】
计划 01 / 02 / **03a（派系与政治骨架，Tasks 1–13）** / **03a-P（表现层与素材接线，P1–P5 + B8）** 均已完成并合入 `main`。
素材已全部入库：**CJK 正文字体**（霞鹜文楷；中文界面已可读，`FontFile.has_char()` 实测 PASS）+ 4 份 OFL 官方原文
+ `interface.psd` 切出的 **13 张 UI 切片**（其中 7 个键已接进主题：按钮四态 / 输入框 / 滚动条）+ 图标语义核定。
⇒ **现在可以直接跑窗口程序看效果**：`./Godot_v4.7.2-stable_win64_console.exe --path .`
（要观测界面文本用 `HALI_DEBUG_LOG=1` 前缀；有两处**待目视确认**：按钮贴图与文字的贴合度、滚动条 grabber 观感。）

【接下来做什么】
A. **§B7：下一批主线** —— **03b 经济骨架** / **03c 社会与法律**（边界照 03a spec §14）。**开新分支**做。
B. **人类目视验收（顺手可做）**：跑窗口程序看主题与中文字体效果（无头环境看不到像素）——
   两处已登记待确认：按钮贴图与文字贴合度、8px 滚动条里 grabber 压缩观感、禁用态是否够暗。
   **调观感只需改 `data/presentation.json` 的 `nine_patch`，零代码。**
C. 仍挂账（**不阻塞**）：短音效 SFX / 环境音素材 · `bg_main.ogg` 时长异常（211.88s vs 原 309.09s，人类自行替换）·
   存档格式 v2 批次（`§8#26`/`#47`/`#19`/`#49` + `#71` 读档 `house_id` 归一化）· B2 真机 LLM 联调（人类已裁定暂不做）·
   `panel_bg` / `frame_*` / `emblem_ring` / `panel_slot` / `button_close` 这 6 件切片待 03b 界面改版落地

【流程：快跑模式（人类 2026-09-20 裁定；别自创，也别偷偷恢复旧仪式）】
每任务 = 抽 brief（可内联进 dispatch，不必单独写长文件）→ 派 worker（**与主会话同模型**）实现 → 自跑到绿 →
**先写报告文件再返回** → **控制器自己读 diff + 复核绿**（**不派独立 reviewer**，除非涉及**不变量/契约改动**）→
处置 findings（**只有 Critical/Important 走修复轮**；**只有改了可执行逻辑的修复才复审**；注释/文档/报告改动**免审**）→
更新台账 → 推送。

**保留的 4 道廉价门禁（一条都不能省）**：
① `bash tools/test.sh` 全绿（套件断言数只增不减）② `timeout 300 bash tools/b1_acceptance.sh` 全绿
③ **两个 stderr 噪音计数**（`SCRIPT ERROR`==2 且 `ERROR:`==7）④ 工作区干净 + 无残留 godot 进程

**为什么保留 90 秒的 `test.sh`**：理由不是「质量」，是**让红色可归因**——攒几千行后一次跑出几十条红，
无法判断是哪次改动引起（调试考古的成本远高于 90 秒）。
同理，**破坏实验只保留 1 组**，只打最高风险那条，其余靠静态反证（已有实证：只看 diff 推演的破坏结果与 35 万次实测吻合）。

【每任务收尾清单（人类 2026-09-20 要求：做完就更新，保证随时能开新会话接手）】
1. `docs/sdd/<plan>/progress.md` —— 追加该任务条目（提交哈希 / 断言数前后 / 门禁结果 / findings 处置 / 挂账 / 残余）
2. `NEXT-STEPS.md` —— 该待办打勾或标「进行中（run id）」；新发现写成新条目；§E「下一步第一件事」改成真实的下一个
3. `NEXT-SESSION-PROMPT.md` —— **刷新「现状」与「接下来做什么」两段，以及体检数字**（这两段最容易漂）
4. 耐久副本复制进 `docs/sdd/<plan>/`（brief / report / review / `review-*.diff`），与代码同一次提交
5. `git push`（别攒着）

【运行纪律（全是实跑踩出来的）】
1. 每个任务完成后 `git push`（别攒着）
2. 探针/破坏实验一律加**外部** timeout：`timeout 300 bash tools/b1_acceptance.sh`
3. 每组破坏实验后 `tasklist | grep -i godot` 查残留进程，有就 `taskkill //PID <PID> //F`
4. 破坏实验的还原用 `cp` 备份 + `md5sum -c` 校验；**不要**用 `git checkout -- <file>`（会冲掉未提交改动）
5. **不要并发跑两个 headless Godot 实例**（会争 `.godot/` 缓存）；派来的外部 agent 也**不许跑 Godot**
6. 计划/spec 与实跑冲突时：**先改计划文本**（单独一次 docs 提交 + 写明依据与实测数据），再改代码
7. **不要用 PowerShell 驱动 git**（`>`/`Out-File` 会加 UTF-8 BOM，写进 `.git/` 直接弄坏引用——已发生过一次）；
   也**不要手工改 `.git/` 下的任何文件**
8. 派外部 agent 时：给它**独立 worktree + 独立分支**，要求 `git add` 只写明确路径（禁 `-A`）、临时文件写 `/tmp`、
   明示它**只能动哪些目录**；合并前先校「改动是否只在允许目录内」（已发生过一次引用被弄坏的事故）
9. 派发书里若写错了口径：**以仓库内已冻结的契约为准**，并把纠正回写进文档（**不要顺着错的写**）
```
