# 新会话开场语（直接复制下方整块内容发给 agent）

> 用途：换会话/换机器接手时，把下面 ``` 代码块里的内容**整段**粘贴给新会话的 agent 即可。
> 为什么单独放一个文件：聊天窗口里的长文本不方便复制，这里有版本控制、可随时更新。
> 维护规则：每完成一个阶段就回来更新本文件（尤其是「接下来做什么」那一段）。

---

```text
项目 E:/Hali（Godot 4.7.2 stable，Windows + Git Bash）。当前分支 plan-03-factions（已推送，**尚未合入 main**；顶端以 `git log --oneline -1` 为准）。

【先做体检】
git fetch origin && git status -sb          # 期望：干净（素材已于 d67bbb1 入库，工作区不应再有未跟踪目录）
bash tools/test.sh                          # 期望：EXIT=0，18 套件 / 1746 断言 / 失败 0
timeout 300 bash tools/b1_acceptance.sh     # 期望：EXIT=0，探针 105 断言 / 0 失败（会临时移走 llm_settings.json 并逐字还原）

【按顺序读这些文件】
1. HANDOFF.md                                  现状、铁律、§4 踩坑 15 条、§8 待裁定项
2. NEXT-STEPS.md                               先读 §0.5 恢复指引，再读 §B「当前暂停点」
3. docs/sdd/plan-03a-factions/progress.md      03a 的耐久台账（每任务提交/断言数/审查结论/挂账 Minor）
4. docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md   03a 计划（文本被按实跑修正过多次，以文件为准）
5. docs/superpowers/specs/2026-09-20-hp-magic-era-03a-P-presentation-design.md
   表现层与素材契约；§8 是素材实测盘点 + 8 条待我拍板的决策

【接下来做什么】
A. 继续计划 03a：
   - Task 12：§8#69 哑炮不进霍格沃茨（house_id="none"）· §8#70 创建界面姓名默认空 + 性别下拉 ·
     §8#16 rumors.weight 生效 · §8#21 wand_cores.rarity 生效（新增 RngService.stream_pick_weighted）
     ⚠️ **计划文本有实测缺陷，必须先改计划再改代码**：`data/wand_cores.json` 的 `rarity` 是**字符串标签**
     （"common"/"rare"），`float("common")==0.0` ⇒ 总权重 0 ⇒ 回退均匀抽取 ⇒ §8#21 **静默假修**，
     而计划自带的断言（只测 weight=0 / 全零 / 空表）抓不到。正解：给每条杖芯加数值 `weight`，调用改 `"weight"`。
     ⚠️ 另：`stream_pick` 用 randi_range、`stream_pick_weighted` 用 randf ⇒ 同名流的**消耗方式变了** ⇒
     `wand_wood`/`wand_core`/`pick_%d` 之后的一切抽取结果都变 ⇒ `[creation]`/`[world_tick]`/`[save]` 里依赖
     固定种子的期望值会变（**内容变了就改期望值，不许放宽断言**）。
   - Task 13：全量回归 → 把新工件同步进 docs/sdd/plan-03a-factions/ → 更新 README/HANDOFF/NEXT-STEPS →
     git checkout main && git merge --no-ff plan-03-factions → 推送
   - ⚠️ Task 12/13 的 brief 必须重新抽取：scripts/task-brief docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md 12（不要用旧 brief）
B. 我的素材：✅ **已落位（提交 `d67bbb1`，53 files，19MB）**
   —— 目录已改成 `assets/`、音频统一 OGG 进 `assets/audio/bgm/`（32.4MB→14.4MB）、4 个 BGM 的 `.import`
   已设 `loop=true`（实测 `AudioStreamOggVorbis.loop==true`）、`assets/CREDITS.md` 授权台账已建、
   `.gitattributes` 已补 mp3/wav/otf/psd/zip/svg/jpeg 二进制规则、`harry_p.zip` 已删（md5 重复）、
   素材原件备份在仓库外 `E:/Hali-asset-originals/`。**实测事实一律以 03a-P spec §8.4 为准。**
   ⛔ **仍缺 2 项**（只阻塞 P3/P5，不阻塞 P1/P2/P4）：① **CJK 正文字体**（必须全字集、**不能子集化**，
   因为玩家可输入任意汉字）② **`interface.psd` 切片 PNG**（本机无 PIL/psd_tools/ImageMagick）。
   ⚠️ **待你确认**：`bg_main.ogg` 时长 211.88s，而原始 mp3 是 309.09s（ffprobe）⇒ **少了 97 秒**；若非有意剪辑需重转。
   然后实现 03a-P 的 P1–P5。
C. B2（真机 LLM 联调剩余项）已裁定暂不做，不用管。

【流程铁律（沿用，别自创）】
subagent-driven-development：每任务 = 抽 brief → 派 worker(deepseek-flash) 实现 → 自跑绿灯 →
**先写报告文件再返回** → 生成审查包 scripts/review-package PLAN BASE HEAD → 派只读 reviewer →
处置 findings（Minor 记台账并按归属转后续任务；Critical/Important 走修复轮 + scoped 复审，最多 5 轮）→
更新台账 → 推送。

【运行纪律（都是实跑踩出来的）】
1. 每个任务完成后 git push（别攒着）
2. 探针/破坏实验一律加外部 timeout：timeout 300 bash tools/b1_acceptance.sh
3. 每组破坏实验后 tasklist | grep -i godot 查残留进程，有就 taskkill //PID <PID> //F
4. 破坏实验的还原用 cp 备份 + md5 校验；**不要**用 git checkout -- <file>（会冲掉未提交改动）
5. 不要并发跑两个 headless Godot 实例（会争 .godot 缓存）
6. 派 reviewer 要限制阅读预算（只读 1 次 diff、≤4 次 grep、报告 ≤120 行、不许整文件打印源码），
   否则容易在长独白里撞上下文上限而失败
7. 计划/spec 与实跑冲突时：**先改计划文本**（单独一次 docs 提交 + 写明依据与实测数据），再改代码
```
