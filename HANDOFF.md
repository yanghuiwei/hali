# 交接文档 · 哈利·波特·魔法纪元

> 用途：换机器后凭这份文档 + 仓库源码即可继续执行。**先读第 1～3 节。**
> 最后更新：2026-09-20（计划 01 / 02 / 03a（含 03a-P 与 B8）均已合入 `main`；本次修订：**§5/§6 压缩为索引**（去与台账重复的历史堆积）+ **新增 §4 第 23 条踩坑**）。交付点 = 分支 `main` 顶端（以 `git log` 为准）。
>
> 📚 **本项目四份文档的职责（2026-09-20 定；目的：别每次任务都改四份）**
>
> | 文档 | 职责 | 每任务要改吗 |
> | --- | --- | --- |
> | `docs/sdd/<plan>/progress.md` | **耐久台账**（唯一权威：提交 / 断言数 / 审查结论 / 挂账） | ✅ **每次都改** |
> | [`NEXT-STEPS.md`](NEXT-STEPS.md) | **唯一「状态 + 待办」源头** + 工作模式 + 门禁 + 收尾清单 | ✅ 每次都改（**只 3 处**） |
> | [`NEXT-SESSION-PROMPT.md`](NEXT-SESSION-PROMPT.md) | 新会话开场语（体检命令 + 读什么 + 纪律；**不放易变数字**） | ❌ 只在**阶段变化**时 |
> | **本文件（HANDOFF）** | **知识库**：现状 / 铁律 / **§4 踩坑** / **§8 裁定登记** / 环境 | ❌ 只在出现**新踩坑或新裁定**时 |
>
> ⇒ 日常一个任务 = **2 处编辑**（台账 + `NEXT-STEPS.md` 3 行）。**三份冲突时以台账为准。**
> 🧹 已知待压缩：**§8（约 154 行，32% 是计划 01/02 的已闭合项）** ⇒ 拟压成「已闭合索引表 + 仍开放表」，不删结论（登记在 `NEXT-STEPS.md` §A3）。

---

## 0. 一句话状态

**计划 01「核心模拟地基」、计划 02「LLM 叙事引擎」、计划 03a「派系与政治骨架」（13/13 任务）与计划 03a-P「表现层与素材接线」（P1–P5）均已完成并合入 `main`。**

- **03a 交付**：派系内容表（17 派系 / 4 政体 / 5 政治事件）· `WorldFactions` 规则层（初始化 / **机构控制权** / **权力四角** / 政体推导 / 月度演化 / 社会矛盾 `tension` / 政治事件）·
  玩家所属与立场（`standing` + 3 op + `OpGuard` + 存档校验）· **信息保护**（`reveal()` + 传闻揭示）· **势力面板重写（修掉 `§8#7`）** · 提示词只暴露已揭示派系 · 离线替身派系关键词 ·
  UI 看门狗与 provider 卫生（`§8#58/#62/#63`）· 降级原因与鸭子类型（`§8#61/#64/#65`）· 哑炮学院修正（`§8#69`）· 创建界面姓名/性别（`§8#70`）· `rumors.weight` / `wand_cores.weight` 真生效（`§8#16/#21`，新增 `RngService.stream_pick_weighted`）
- **03a-P 交付**：`data/presentation.json` + `data/audio_cues.json` 两张清单表 · 四个表现层模块
  `Presentation`（安全加载/缓存/**缺素材回退**）/ `ThemeBuilder`（清单造主题，暗色）/ `AudioDirector`（8 个 cue 触发点 + BGM 随地点/时代切换）/ `AssetSlots`（背景 / Logo / 学院徽记 / 立绘槽位，**缺素材不可见且不占位**）·
  **接口冻结**：清单顶层键集合与取值形态、`resolve()` 只走嵌套点号下钻、`nine_patch` 顺序 `[上,右,下,左]`
- 计划全文：`docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md`（13 任务；**文本被控制器按实跑修正过多次，以文件当前文本为准**）
  ｜设计 spec：`docs/superpowers/specs/2026-09-20-hp-magic-era-03-factions-design.md` ｜表现层 spec：`docs/superpowers/specs/2026-09-20-hp-magic-era-03a-P-presentation-design.md`
- **耐久台账**：`docs/sdd/plan-03a-factions/progress.md`（每任务提交 / 断言数 / 审查结论 / 挂账 Minor / Phase 0 素材落位 / **快跑模式流程变更**）
- **素材线**：`assets/` 已落位**两批**素材 —— ① 目录改名 / 音频统一 OGG / `CREDITS.md` 台账 / 4 个 BGM `loop=true`；
  ② **CJK 正文字体**（LXGW WenKai v1.522 + 4 份 OFL 官方原文）+ **`interface.psd` 切出的 13 张 UI 切片** + 图标语义核定（`assets/icons/ICON-MEANINGS.md`）
- ✅ **中文界面已可读**：`data/presentation.json` 的 `fonts.body` → `body_cjk.ttf`，`ThemeBuilder:47-50` 消费它设 `default_font`。
  实测 `FontFile.has_char()` 对含生僻字（`龘爨饕餮`）的测试串**缺字=无 / PASS**；既有 4 个字体对「你」全 `false`。
  该断言是**条件式**的（字体到场后自动生效），控制器做过负向验证：把它指向不含中文的 Cinzel ⇒ `test.sh` `EXIT=1` 且报文直指「中文界面是豆腐块」。
- ⏳ **仍缺（不阻塞）**：短音效 SFX / 环境音（缺则静音）· **13 张切片尚未接进主题**（见 `NEXT-STEPS.md` §B8 P5b）

**接下来要做什么：见 [`NEXT-STEPS.md`](NEXT-STEPS.md)**（§0 快跑模式 / §0.5 恢复指引 / §B 下一步 / §C 待裁定项）。

- 计划全文（唯一执行依据）：`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`（4450 行，Task 1–11）
- 正典规格（唯一事实来源）：`哈利·波特·魔法纪元.md`（仓库根，勿移动、勿改名）
- 过程台账 / 简报 / 报告 / 审查包：`docs/sdd/plan-01-core-foundation/`（见第 7 节）

---

## 1. 代码在哪里、要拿哪个分支

| 项 | 值 |
| --- | --- |
| 远端 | `https://github.com/yanghuiwei/hali.git`（`origin`） |
| 交付分支 | **`main`**（计划 01 / 02 / 03a / 03a-P 全部已合入；顶端以 `git log --oneline -1` 为准） |
| 开发分支 | `plan-03-factions`（计划 03a + 03a-P 的工作分支，已按 Task 13 合入 `main`；保留供追溯） |
| `main` 已包含 | 计划 01（Task 1–11 + 收尾加固）· 计划 02（Tasks 1–12）· B1 观测通道 · 计划 03a（Tasks 1–13）· 计划 03a-P（P1–P5）· `assets/` 首批素材 |
| 当前 HEAD | 以 `git log --oneline -1` 为准；**不要把 HEAD 或任何合入哈希钉死在文档里**——已漂移多次 |
| 后续 | 从 `main` 拉新分支（见 `NEXT-STEPS.md` 队列 B） |

```bash
git clone https://github.com/yanghuiwei/hali.git
cd hali
git log --oneline -5            # 交付点 = main 顶端（不要照抄文档里的旧哈希）
git switch -c plan-03b-economy  # 后续计划从 main 拉新分支（例：03b 经济骨架）
```

**计划 01 的历史**（仅供追溯，不代表当前 HEAD）：收尾时把 `plan-01-core-foundation` 合回了 `main`。远端 PR #2 实际合并的是 Task 5 的旧 tip `d4186c5`（不含 Task 6–11），因此本地以 `026efe3` 把旧 merge 与完整分支合并修正，`origin/main` 与 `b196d26` 的 tree 完全一致。

**计划 02 的历史**：开发分支 `plan-02-llm-narrative`（`38589b4..15c1ff0` 为 8 个任务提交，`a48f108`/`18eaa5c` 为审查修复），收口提交 `1f82483`，`d885cf9` 记录「计划 02 已合入 `main`」。

**计划 03a / 03a-P 的历史**：开发分支 `plan-03-factions`（从 `main@685af4b` 拉出）。共四段：
① 03a Task 1–11（含 T4/T5/T6/T10 四轮修复轮）；② **暂停期**：控制器直接执行 **Phase 0 素材落位**（目录改名 / 音频统一 OGG / `CREDITS.md` 台账 / `.gitattributes`）；
③ **Task 12**（哑炮学院 / 创建界面姓名性别 / 权重生效）+ **03a-P P1–P5**（表现层与素材接线，快跑模式下 2 次派发完成）；
④ **Task 13 收尾**（全量回归 + 文档 + `merge --no-ff` 回 `main`）。逐事件记录见 `docs/sdd/plan-03a-factions/progress.md`。

---

## 2. 新机器上跑起来（唯一测试入口）

前置：**Windows + Git Bash**；**Godot 4.7.2 stable，Windows 64-bit，非 .NET 构建**。不需要 Python / Node / 任何包管理器，测试完全离线。

Godot 可执行文件约 180MB，**不入库**（`.gitignore` 里的 `*.exe`）。三种放法，任选：

```bash
# 放法 A（推荐，与工具默认值一致）：把两个 exe 放到仓库根目录，文件名必须完全一致
#   Godot_v4.7.2-stable_win64.exe
#   Godot_v4.7.2-stable_win64_console.exe
bash tools/test.sh

# 放法 B：放在别处，用 GODOT= 覆盖
GODOT=/d/tools/Godot_v4.7.2-stable_win64_console.exe bash tools/test.sh

# 放法 C：已在 PATH 中
GODOT=godot bash tools/test.sh
```

**引擎版本必须是一致的 4.7.2 stable**。换版本会重新生成 `.godot/` 导入缓存与 `*.uid`，产生无意义 diff，甚至让 `class_name` 解析顺序变化。校验方式：跑测试时输出的横幅应为

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
```

脚本行为（`tools/test.sh`，共 4 步）：`1/4` 先 `--headless --import` 生成 `.godot` 缓存（`class_name` 全局类依赖它，冷机器首次必须做）→ `2/4` 跑单元测试 → `3/4` 主场景冒烟（`--headless --quit-after 5`；缺 `main.tscn` 会打印"跳过"且不算失败）→ `4/4` 调试镜像冒烟（`HALI_DEBUG_LOG=1` 跑 `tools/ui_debug_probe.gd`）。

> `3/4` 还**反向**断言：未设 `HALI_DEBUG_LOG` 时输出里不得出现任何 `[HALI]` 行（证明默认行为逐字未变）。

**退出码语义**：`0` 全绿｜`1` 有失败（单测 / 冒烟 / 镜像）｜`2` 找不到 Godot 可执行文件。

冷机器上第一次运行的预期输出（**计划 03a + 03a-P 完成后实测**）：

```
== 1/4 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/4 单元测试 ==
[probe] 故意失败: 期望 <2>，实际 <1>     ← 断言库自检探针，故意失败，不算失败
[probe] 断言=1 失败=1                    ← 同上，probe 套件不在 SUITES 里
[harness] 断言=8 失败=0        [registry] 断言=244 失败=0
[money] 断言=18 失败=0         [magic_level] 断言=48 失败=0
[model] 断言=49 失败=0         [clock] 断言=47 失败=0
[world_tick] 断言=189 失败=0   [creation] 断言=188 失败=0
[spell] 断言=229 失败=0        [gm] 断言=128 失败=0
[panel] 断言=102 失败=0        [selfcheck] 断言=32 失败=0
[save] 断言=112 失败=0         [async_probe] 断言=2 失败=0
[llm] 断言=106 失败=0          [prompt] 断言=38 失败=0
[debug_mirror] 断言=23 失败=0  [factions] 断言=204 失败=0
[presentation] 断言=83 失败=0  [theme_audio] 断言=76 失败=0
[asset_slots] 断言=59 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/4 主场景冒烟（默认配置） ==      main scene ready, godot=4.7.2-stable (official)
== 4/4 调试镜像冒烟（HALI_DEBUG_LOG=1） ==  [HALI] PROBE-APPEND-MARK / [状态行] / [输入框] / [按钮]
全部通过。
```

> 套件数/断言数的**当前值见 [`NEXT-STEPS.md`](NEXT-STEPS.md) §0B（唯一维护点，本文件不再重复维护数字）**。
> 若你在本文件里看到具体数字，那是**当时的快照**；判定「文档/分支是否过旧」一律以 §0B 与 `test.sh` 实测为准（**数字变小不是回归**）。
> 历史上 `[factions]`/`[world_tick]`/`[creation]`/`[prompt]`/`[gm]`/`[llm]`/`[registry]`/`[save]`/`[panel]` 都长过，
> 并新增了 `[presentation]`/`[theme_audio]`/`[asset_slots]` 三个套件。
>
> **stderr 噪音是自动门禁（不是“盯一下”）**：`tools/test.sh` 的第 `2/4` 步会把单测输出 tee 到临时文件，并计数两条通道：
> `SCRIPT ERROR` 必须恰好 **2** 条（`save` 的坏档负例）、`ERROR` 必须恰好 **7** 条（5 条畸形 JSON 负例 + 2 条 `gm_test` 的「`submit()` 不能驱动协程 GM」负例）；
> 不符即 `unit=1` → `EXIT=1`，报文会写明期望值。临时实验可用 `EXPECTED_SCRIPT_ERRORS=` / `EXPECTED_PLAIN_ERRORS=` 覆盖。
> **这两个数字是健康指标，不是“失败”**；只有**故意增删负例**时才改常量，并在提交信息里写明原因。两个常量与原因就写在 `tools/test.sh` 里那一段注释里。
> **为什么要这道门禁**：「解析 JSON 失败 / 资源加载失败 / 类型赋值错误」这类噪音**套件内的断言拓不到**——03a-P 的破坏实验里出现过三次：拆掉守卫后套件全绿（甚至 `[presentation]` 81/0），而外部 `ERROR` 2→3 / 7→12。见 §4 第 16 条。
> **`tools/b1_acceptance.sh`**（B1 人工验收的自动通道，**不进 `test.sh`**：它会写 `user://`）→ 期望 `EXIT=0`、**失败 0**
> （断言数见 `NEXT-STEPS.md` §0B）；它自带 `llm_settings.json` / `saves/slot1.json` 的备份与逐字还原。**跑它一定要加外部 `timeout`**（见 §4 第 12 条）。

窗口程序已可用：`./Godot_v4.7.2-stable_win64_console.exe --path .`（主场景 `src/ui/main.tscn`）。

### 调试镜像（B1 人工 GUI 验收的观测通道）

游戏内的叙事、面板、玩家输入、创建界面选项、状态行、等待期置灰状态**既不 print 也不入档**，所以从外部无法观测一个回合到底发生了什么（B1 卡在这里）。为此加了可选镜像：

```bash
HALI_DEBUG_LOG=1 ./Godot_v4.7.2-stable_win64_console.exe --path .
# 界面文本每行带 [HALI] 前缀进入 stdout，Godot 落进 user://logs/*.log
```

人工点窗口、控制器读日志即可完成 B1（不必改代码、不必从存档反推）。**未设置该变量时一行都不输出**，行为与加该功能前逐字一致（由 `tools/test.sh` 的 `3/4` 反向断言保证）。实现：`src/ui/debug_mirror.gd`（开关语义）+ `src/ui/main.gd`（`_mirror()` 是唯一出口，`_append`/`_set_status`/`_set_input_enabled`/`_set_buttons_enabled` 全部经过它）。

---

## 3. 目录结构与职责

```
哈利·波特·魔法纪元.md   # 正典规格（唯一事实来源）
README.md                # 项目说明、进度表、目录约定
project.godot            # Godot 工程定义（features=4.7，gl_compatibility）
tools/test.sh            # 唯一测试入口（4 步：导入 → 单测 → 默认冒烟 → 调试镜像冒烟）
tools/b1_acceptance.sh   # B1 自动验收（会写 user://，故不进 test.sh；自带备份/还原）
tools/ui_debug_probe.gd  # 镜像冒烟的探针（test.sh 第 4 步）
data/*.json              # 内容即数据：改内容不改代码（时代/血统/身份/资质/学院/风格/倾向…）
data/presentation.json   # 表现层清单：字体/界面/图标/贴图/徽记/背景/立绘/配色（**不是内容表，不进 Registry**）
data/audio_cues.json     # 音频清单：8 个 cue + bgm_by_era/bgm_by_location + master_volume
assets/                  # 素材（字体/图标/贴图/界面/音频），**全部可选、缺则回退**；台账 assets/CREDITS.md
src/core/                # registry(内容表) · game_clock · rng_service · json_util · turn_engine
src/model/               # money · player_state · world_state（均已完成）
src/rules/               # magic_level(已完成) · character_creation · spell_resolver · progression
                         # · state_ops · self_check · factions(计划 03a)
src/gm/                  # game_master(接口) · scripted_game_master(离线替身) · llm_game_master(计划 02) · op_guard · prompt_builder · gm_response_parser · llm_settings
src/gm/providers/        # llm_provider(接口) · openai_compat_provider(HTTP) · mock_provider(测试)
src/persist/             # save_codec · save_store（已完成，第七十一章）
src/ui/                  # main.tscn · main.gd（窗口程序）· panel_formatter（面板）· debug_mirror（HALI_DEBUG_LOG 观测通道）
                         # · presentation（清单加载/缓存/回退）· theme_builder · audio_director · asset_slots（计划 03a-P）
tests/                   # run_tests.gd(运行器) · assert.gd(零依赖断言库) · *_test.gd(每任务一套件)
docs/superpowers/plans/  # 实现计划
docs/sdd/                # 过程台账/简报/报告/审查包（第 7 节）
```

**铁律：内容一律进 `data/*.json`，代码不硬编码内容。** 新增测试套件必须把路径追加到 `tests/run_tests.gd` 的 `SUITES` 常量，否则不会被运行（缺失路径会直接判失败，不会静默跳过）。

---

## 4. 踩过的坑（改代码前必读）

1. **JSON 没有 int/float 之分**：`JSON.parse_string` 把所有数字读成 float，而 Godot 的 `Dictionary` 深比较**类型严格**（`{"n":493} != {"n":493.0}`）。`to_dict()` 输出前必须过 `JsonUtil.normalize()`（整数值的 float 归一为 int），`from_dict()` 同样处理动态子字典。否则"存读档往返后状态一致"的断言必然失败。
2. **`to_dict()` 只放 JSON 原生类型**（Dictionary / Array / String / int / float / bool / null）。放 `Vector2`、`PackedStringArray`、自定义对象会在存读档往返中变形。
3. **GDScript 字符串里不要写 `\u` / `\x` 转义**（`"\u"` 是解析错误）。需要反斜杠用 `String.chr(92)`。
4. **`*.uid` 文件必须入库**：Godot 4.4+ 用 `.uid` 锁定脚本标识，缺失或换了引擎版本都会造成引用漂移。新脚本提交时连同 `.gd.uid` 一起 `git add`。
5. **测试运行器在任何情况下都必须以 `quit(...)` 结束**（Task 1 曾因套件解析失败而挂住，已修复：损坏的套件被隔离进 `_run_suite` + `can_instantiate()` 守卫）。改动 `tests/run_tests.gd` 时不要破坏这个保证。
6. **不要并发跑两个 headless 实例**（会争 `.godot` 缓存）。曾出现 bash `timeout` 杀掉 shell 但把引擎子进程遗成孤儿、空转烧 CPU 的情况。卡住时这样排查：

```bash
tasklist | grep -i godot
taskkill //PID <PID> //F
```

7. **CRLF/LF 警告是正常的**：`.gitattributes` 强制 `eol=lf`，Windows 上 `git add` 计划文档时会看到 "CRLF will be replaced by LF"，不影响内容。
8. **引擎固定 4.7.2 stable + 纯 GDScript**：不引入第三方插件、外部素材、网络依赖；玩家可见文本用中文，标识符用英文；源码与数据一律 UTF-8。
9. **正典优先**：原著明确设定 ＞ 模拟器推演。每完成一个任务，若发现计划文本与正典冲突（Task 3 就发生过：计划把 510 纳特写成 `[1,0,17]`），**改计划、不要顺着错的计划写实现**，并在报告里写明依据的正典行号。
10. **`RichTextLabel.text` 不会被 `append_text()` 更新**：实测 `append_text("abc")` 后 `label.text` 仍是 `""`，要读内容必须用 `get_parsed_text()`；headless 下 `get_line_count()` 恒为 0（无布局）。生产代码目前没有读 `log_view.text` 的地方，但写观测/探针工具时会踩（B1 验收探针就踩过一次）。
11. **`%r` 不是 Godot 的格式占位符**：`"x=%r" % v` 会在运行期报 "String formatting error: unsupported format character"，而运行器**不会**因此变红（见 §8#56）。用 `%s`。
12. **探针/破坏实验会死锁**（计划 03a Task 10 实跑）：探针里用"永不返回的 provider"验证看门狗时，若某组破坏把**看门狗 deadline 变成永不触发**，协程永不返回 ⇒ 探针永不退出 ⇒ **bash 挂死**（不是"测试红"）。处置：① 破坏实验一律选**不会挂住**的形态（保留 deadline、只删恢复/提示）；② 跑探针一律加**外部** `timeout`（`timeout 300 bash tools/b1_acceptance.sh`）；③ 探针自身的等待要有上限（`_submit_bounded()`：只轮询可观测信号 + 5s 上限，**不 `await` 被测协程**）；④ 卡住后先 `tasklist | grep -i godot` 再 `taskkill //PID <PID> //F`（清孤儿进程）。
13. **破坏实验的还原不要用 `git checkout -- <file>`**：它回到 **HEAD**，会冲掉你**未提交**的改动（03a Task 11 实现者就冲掉过自己一轮改动，被 md5 校验 `MISMATCH` 抓到）。改用「先 `cp` 到备份目录 → 还原时 `cp` 回来 → `md5sum -c` 校验」。
14. **派 reviewer 要限制阅读预算**：审查任务也吃上下文——03a Task 10 第一次派出的 reviewer 读了太多文件 + 长独白，输出 29.6k tokens、`windowPeak=64k` 后 **exit 1 失败**。重派时把输入缩小（只含代码提交的审查包）+ 明确限制（**只读 1 次 diff、≤4 次 grep、报告 ≤120 行、不许整文件打印源码**）即通过。
15. **计划文本会错，且必须改计划**：03a 期间计划被实跑证伪 6 次（阈值 0.45 不可达、`state_digest` 当成文本、`tick()` 片段用了未定义的 `world`、`evolve` 缺早退、`reveal` 写 `last_change_turn` 破坏不变量、`engine==null` 守卫不够）。**做法固定**：先由控制器改**计划/spec 文本**（单独一次 docs 提交、写明依据与实测数据），再让实现者按新文本改代码——「改计划、不要顺着错的计划写实现」。

> 以下 16–22 是 **03a / 03a-P 收尾期间**新增的坑（都是实跑踩出来的，不是推测）。

16. **有一类契约只能靠外部 stderr 计数守住**：所谓「零噪音」类不变式（资源加载失败、JSON 解析失败、类型赋值错误）**在套件内不可判别**——破坏实验里可以做到套件全绿而外部报错数变化。已累计 **5 例**：`§8#48`/`§8#56` + Task 4 审查 N1 + Task 6 审查 M3 + Task 10 审查 I1，加 03a-P 的 S2/D1（实测：拆掉 `ResourceLoader.exists()` 守卫 → `[theme_audio]` 76/0 全绿、外部 `ERROR` 8≠7）。**处置**：`tools/test.sh` 第 2 步已把两条计数做成**自动门禁**（见 §2）。凡改动面可能产生噪音的代码，先看门禁有没有红。
17. **可空返回值不要用有类型接收**（实测）：`var x: Dictionary = f()`，若 `f()` 可能返回 `null`，会在**运行期**报 `SCRIPT ERROR: Trying to assign value of type 'Nil' to a variable of type 'Dictionary'`，而且**会中止所在函数**（不是只报一条错就继续）。注意：字面 `null` 赋给 `Dictionary` 是**解析期**错误；可变返回值的 null 是**运行期**错误——两者不同，但都要避。处置：保持无返回类型标注 + 调用处判空。（03a-P Task 12 的 `generate_wand` 一度就是这么写的）
18. **helper 层断言不足以保证「调用处传对了参数」**：只测纯函数/帮助器时，若缺陷在**调用处**（传错键名、漏参、用错字段），断言会全绿。实证：Task 12 的 D3a——把杖芯抽取的 `"weight"` 改回 `"rarity"`（字符串，`float()`==0 ⇒ 静默退化为均匀），**helper 层断言全绿，只有走真实入口的端到端断言变红**。凡修「传错键名/漏参」这类缺陷，**必须至少有一条走真实入口的端到端断言**。
19. **断言要「红得干净」**：凡是 `player`/`result` 可能为 `null` 的路径，先判空或用哨兵串代替解引用。否则缺陷的形态会是**套件中止**（而不是一条干净的失败），**会把后面所有断言掩盖掉**（与台账里 Task 9 M7 / Task 12 Step 1 同源）。
20. **表现层清单里不许出现字面点号键**：`Presentation.resolve()` 只按 `.` **逐段嵌套下钻**，所以清单里写 `"faction.ministry": "…"` 这种字面键时，`resolve("emblems.faction.ministry")` **永远返回 `null`** ⇒ 该行素材「声明了但取不到」（与 `§8#16/#21` 同类的静默失效）。正确写法是**嵌套对象**：`"faction": {"ministry": "…"}`。`presentation_test` 已加**响亮门禁**：递归扫描两张清单，**任何含 `.` 的键都判失败并报出具体键名**。
21. **九宫格边距顺序冻结为 `[上, 右, 下, 左]`**（与 `presentation.gd` 的 `nine_patch()` 文档一致）：Godot `StyleBoxTexture` 用的是 `(left, top, right, bottom)`，两者映射封在 `AssetSlots.patch_insets()` **唯一一处**（写作 `Vector4i(raw[3], raw[0], raw[1], raw[2])`）。**写断言时必须用非对称值**（如 `[1,2,3,4]`）——对称值（`[12,12,12,12]`）测不出左右写反。
22. **不要用 PowerShell 驱动 git；也不要手工改 `.git/` 下的文件**：PowerShell 会把 git 正常的 stderr 当 error record，且 `>` / `Out-File` 会加 **UTF-8 BOM**，把 BOM 写进 `.git/refs/**` 会直接弄坏引用。03a-P 期间真实事故：`git worktree add -b ...` 报 `fatal: invalid reference` 后，改用手工 `mkdir .git/refs/heads/assets` 造分支 ⇒ 该分支的 worktree 引用**悬空**（`git worktree list` 显示 `0000000`、分支 ref 不存在，且在该 worktree 里 `git status` 会把**整个仓库**看成「全新未跟踪」），若当时 `git add -A` 就会造出「整个仓库当初始提交」的巨型 commit。**处置**：用 Git Bash 跑 git；命令失败就把**原始输出**拿出来问，不要手工绕；临时文件写 `/tmp` 或仓库外；`git add` 只写明确路径。
23. **「类型/属性代理」当判别器会变成假绿**：03a-P B8 实测 —— 用 `is StyleBoxFlat` 当「样式来自 ThemeBuilder、不是 Godot 内置默认」的**代理**，而 **Godot 内置默认主题的 `Button.normal` 也是 `StyleBoxFlat`** ⇒ 该断言**从来没有判别力**，只是恰好一直为真（直到我们把 normal 换成 `StyleBoxTexture` 才变红）。同理 `theme.has_stylebox(...)` 也不能当判别器（内置默认同样为 `true`）。**处置**：判别器要选一个**内置默认不会碰巧满足**的可观测量（本次用 `content_margin == ThemeBuilder.CONTENT_MARGIN_H`：我们 8 / 内置默认 4，且该值对扁平与贴图两种盒子都成立 ⇒ 在两者间切换素材时既不假红也不假绿）。**一般规则**：写「X 来自我们而不是引擎默认」这类断言时，先用一个**刻意退回默认**的夹具确认它会红。

---

## 5. 已完成的计划（**索引** —— 详情一律看台账，不再在这里重复）

| 计划 | 内容 | 耐久台账（每任务的提交 / 断言数 / 审查结论 / 挂账） |
| --- | --- | --- |
| 01 | 核心模拟地基（Tasks 1–11 + 收尾加固批次） | `docs/sdd/plan-01-core-foundation/progress.md` |
| 02 | LLM 叙事引擎（Tasks 1–12） | `docs/sdd/plan-02-llm-narrative/progress.md` |
| 03a | 派系与政治骨架（Tasks 1–13） | `docs/sdd/plan-03a-factions/progress.md` |
| 03a-P | 表现层与素材接线（P1–P5 + B8）+ 素材线 | 同上（含 Phase 0 素材落位与素材合并） |

> ⚠️ **本节有意不再列逐任务的提交哈希与历史结论**：那些在台账里是**唯一权威**，且每任务都会更新 ——
> 两处维护必然漂移（本节的旧版本就曾把计划 02/03a 写成「未开始」）。
> 需要「计划 01 各任务的关键结论」时，直接读 `docs/sdd/plan-01-core-foundation/progress.md`。

## 5.5 计划 03a / 03a-P 的关键结论（2026-09-20）

> 逐事件过程见 `docs/sdd/plan-03a-factions/progress.md`；这里只留「接手前必须知道的结论」。

**2a 规则层（`src/rules/factions.gd` + `data/factions.json` / `governments.json` / `political_events.json`）**

- **机构控制权**是「派系实力」之外的第二个量：机构级指标（法律执行/傲罗/威森加摩/国际）一律读**机构控制权 + holder**，不再从 `world_vars` 猜（这正是 `§8#7` 的修法）。
- **权力四角**（`power_share()`）是已列派系 power 的归一化函数，四角之和恒为 1 ⇒ 单角现实上限 ≈ 1/3，**阈值必须按占比语义设**（`oligarchy_pressure` 取 0.28 而非 0.45 —— 旧值在任何合法状态都不可达）。
- **政体推导**：规则 1 = 战时 + 抵抗方 power > 魔法部 power；规则 2 = 独裁者的机构控制权；规则 3 = 魔法部 power < 0.5（spec §7.4 已把实现口径写成权威）。
- **`tension`（社会矛盾）** 与政治事件**共用** `last_major_turn` 配额 ⇒ 高张力时代会吃掉大部分重大事件配额（已登记为「按 era 普查配比」的待办）。
- **信息保护**：`reveal()` 只维护「已揭示」集合，`visible_faction_ids()` 是唯一出口；未揭示派系不进提示词、面板显示「未知势力」；`last_change_turn` 语义单一化为「power 变更回合」（`reveal()` **不**写它）。
- **`RngService.stream_pick_weighted(name, entries, weight_key)`**：权重 ≤ 0 的字典条目在**加权路径**中永不被抽中；全零时**整体回退** `stream_pick`；空表返回 `null`。**故意不加 `-> Dictionary` 返回标注**（见 §4 第 17 条）。
  - 选择逻辑抽成可传 `roll` 的私有函数 `_pick_by_roll()`，**唯一目的是让 `randf()==0.0` 这条不可测边界变成可判别**（概率≈2⁻³²，黑盒永远测不到）。

**2a-P 表现层**

- 四个 seam：`Presentation`（清单加载/缓存/回退）· `ThemeBuilder`（清单 → `Theme`）· `AudioDirector`（cue + BGM，尊重 `master_volume`）· `AssetSlots`（槽位 + 九宫格 StyleBox）。
- **接口冻结**（spec §2）：顶层键**允许集** 8 个（`fonts`/`ui`/`icons`/`textures`/`emblems`/`backdrops`/`portraits`/`palette`）；`fonts`/`ui` 用对象形态、其余用扁平字符串；`resolve()` 只走**嵌套点号下钻**；`nine_patch` 顺序 `[上,右,下,左]`；所有路径 `res://assets/` 开头。
- 两张清单**不进 `Registry`**（`Registry` 的契约是「Array of `{id,label}` 且每表非空」，清单是嵌套字典，硬塞会把 `registry.validate()` 弄红）。
- **清单只登记实际存在的文件** ⇒ 「清单里每条路径都在 `CREDITS.md` 有登记」才能是硬断言；缺键/缺文件/类型不符三条回退路径都有断言。
- **换素材 = 改一行 JSON，零代码**；缺任何素材都必须优雅回退，**不得报错也不得阻塞回合**。
- 主题在**运行期**挂到根 Control 上，**不提交 `.tres`**（否则「改一行 JSON 换素材」会变成「还要重新生成资源」）。
- **缺素材不可见且不占位**：槽位 `TextureRect` 在无贴图时 `visible=false`，容器直接跳过它 ⇒ b1 有两道「加槽位没偷偷改布局」的断言（槽位贡献可见子节点 == 0、可见子节点仍为 2）。
- BGM 循环设在**导入层**（4 个 `.ogg.import` 的 `loop=true`，实测 `AudioStreamOggVorbis.loop == true`）⇒ 播放侧不需要自己管循环。
- `.import` 文件**必须入库**（Godot 4 的导入设置载体）；提交后重跑 `--import`，`git status` 保持干净。
- **stderr 噪音门禁**（`tools/test.sh` 第 2 步）：`SCRIPT ERROR`==2 且 `ERROR`==7，不符即 `EXIT=1`。这是本项目**第一道自动化噪音门禁**（以前靠控制器每轮人工核对）；理由与不可替代性见 §2/§4 第 16 条。

---

## 6. 接下来怎么做

**待办与下一步一律看 [`NEXT-STEPS.md`](NEXT-STEPS.md)** —— 它是唯一的「状态 + 待办」源头：
§0 文档职责 · §0A **快跑模式** · §0B 门禁与基线数字 · §0C 每任务收尾清单 · §A 待办 · §C 待裁定项 · §D 协作约定。

> 本节旧版本维护过一份「后续计划列表」（计划 02/03a/03b…），**已多次漂移**（把已完成的写成「未开始」）⇒ 删除，改为指向。

## 7. 过程状态怎么跟着源码走（重要）

- 本机 scratch 工作区：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/` —— **被 `.gitignore` + 目录内 `.gitignore: *` 双重忽略，不会随源码走**，换机器后是空的。
- 因此**耐久副本**放在仓库内的 `docs/sdd/plan-01-core-foundation/`，内容为：`progress.md`（台账）、`task-N-brief.md`（简报）、`task-N-report.md`（实现者报告）、`task-3-review.md`（审查记录）、`review-<from>..<to>.diff`（审查包：提交列表 + 文件统计 + 完整 diff）。
- **交接规则**：每完成一个任务（提交 + 审查 + 台账更新后），把该任务的四个工件从 `.superpowers/sdd/.../` 同步复制到 `docs/sdd/plan-01-core-foundation/`，与代码一起提交。副本以 `docs/sdd/` 下的为准（它可追溯、可 diff）；`.superpowers/` 只是工具工作区，允许随时清空。
- 注意：`task-3-report.md` **不存在**（Task 3 实现者未写报告），台账里有等价记录，不要误以为文件丢失。

---

## 8. 待人类裁定项（计划 01 已完成；以下为后续批次）

> 📌 **编号说明**：本节条目编号（写作 `§8#N`）**与 §4 的踩坑编号各自独立**，两者都从 1 开始。引用时一律写作 `§8#N` / `§4 第 N 条`，不要只写数字。

> ✅ **计划 03a / 03a-P 期间已闭合（2026-09-20）**：`§8#7`（`power_panel` 7 标签→4 变量错映射 → **T7** 重写为「机构级指标来自派系机构控制权」）· `§8#16`/`§8#21`（`rumors.weight` / `wand_cores.rarity` 声明未生效 → **T12**：新增 `RngService.stream_pick_weighted`，杖芯权重落到数值字段 `weight`）· `§8#69`（哑炮却有学院 → **T12**：哑炮一律 `house_id="none"`）· `§8#70`（创建界面姓名默认「无名者」+ 无性别输入 → **T12**）· `§8#58`/`§8#62`（UI 等待期无超时/无失败恢复 → T10 看门狗 + 单一恢复出口）· `§8#63`（provider 泄漏 + `timeout` 只生效一次 → T10）· `§8#61`（降级原因未透出 → T11）· `§8#64`（测试可判别性 3 条 → T11）· `§8#65`（契约文档/鸭子类型漂移 → T11）· `§8#66`/`§8#67`（settings 不生效 / 错误串诊断不足 → `3240af6`）
>
> ⏳ **新增挂账（03a / 03a-P 审查与实测产出）**：
> - **`§8#69` 的读档路径（新）**：`src/model/player_state.gd` 读档时**原样拷贝** `house_id`、不重判 ⇒ 修复前生成的旧存档
>   （就是 `§8#69` 的原始证据那个 `squib`+`gryffindor`）读进来仍是 `gryffindor`，只有**重新建角**才得 `none`。
>   控制器已裁定**归「存档格式 v2」批次**（与 `§8#26` 同族），理由见计划「Task 12 范围声明」；
>   **创建路径已堵死**（复核：`assign_house` 在生产代码里只有 1 个调用点）。零成本缓解：旧存档属历史数据，重建角色即可。
> - **素材线（新）**：CJK 正文字体（已下载霞鹜文楷 25.6MB，待交付）· OFL 许可证文本（3 个 OFL 字体**缺许可证原文**，这是 OFL 的强制义务）·
>   `interface.psd` 切片 PNG。二者到场后要做的两件事**都是零代码**：跑一次 `--import` 生成 `.import` + 在 `data/presentation.json` 加行（`fonts.body` / `ui.*`）。
>   跟踪：`NEXT-STEPS.md` §B6；交接提示词 `docs/sdd/plan-03a-P/assets-handoff-prompt-v2.md` 与 `assets-agent-repair-prompt.md`
> - **03a-P 残余**：槽位占位尺寸（Logo 48 / 立绘 144 / 徽记 32×32）需素材到场后复核 · 背景槽与不透明 StyleBox 的层级遮挡未验证 ·
>   `ui.panel_bg`/`button_*` 的九宫格**应用**留到切片到场（`AssetSlots.stylebox_for` 已实现且有断言）· `llm_fallback` 的真触发属 B2
> - 内容/玩法参数待实跑观察：政治事件频率按 era 普查（Task 5 M6）· `oligarchy_pressure` 0.26 与政体门限 0.28 两套阈值需复核 · 离线替身同句多派系的 tie-break 按 id 序（确定但粗糙）· 名词性文本（"我最讨厌食死徒"）落 idle
> - 语义已接受但需记账：`illegal_affiliation` 陈旧化（**03c 必须定清除/归一规则**）· 隐藏派系的控制权**数值**仍显示（只隐藏身份；若把"不得主动剧透"读作涵盖存在性则升级）· `last_change_turn` 语义单一化为"power 变更回合"· 量化（`QUANTIZE_DECIMALS=4`）只是**收窄** `§8#50` 触发面、存档 v2 仍是独立议题
> - `wand_woods.json` 没有 `weight` 字段 ⇒ 木材与均匀抽取**分布等价**（将来加权重是**纯内容改动、零代码**）
> - 表现层 UX：`LlmGameMaster` 无 fallback 分支的降级原因**双显**（叙事 + `warnings`）→ 归 **03a-P**（**尚未做**）



前 3 条是计划预检遗留，其后是逐任务审查产出。**第 1 条（Task 8 故意留 `SelfCheck` 最小桩）已由 Task 9 用完整实现替换而关闭**；**第 2 条（魔杖价矛盾）已在 Task 4 开工前按正典裁定并落地**。其余项均为计划级/文档级，或要到 Task 10–11 才触发。

1. ~~**Task 8 故意留 `SelfCheck` 最小桩**~~ **已关闭（Task 9）**：完整 `SelfCheck`（`snapshot`/`ooc_report`/`report`）已替换最小桩（`d9135ab`），`gm_test` 仍绿。
2. ~~**魔杖价自相矛盾**~~ **已裁定（Task 4）**：按正典 `哈利·波特·魔法纪元.md:223`「一根普通魔杖：7‑10加隆」，测试取价格下限 7 加隆（3451 纳特），期望 `"3加隆 0西可 0纳特"`；计划与测试两处已同步。裁定记录见 `docs/sdd/plan-01-core-foundation/task-4-review.md`。
3. **Task 8 `ScriptedGameMaster` 直接调 `SpellResolver.cast()`**（直接改世界）……**计划 02 已部分收口**：LLM 主路径（`LlmGameMaster` → `OpGuard` → `StateOps`）不再直改世界；**降级路径** `ScriptedGameMaster` 仍沿用旧实现（spec §14.1 已登记）。
4. **哑炮失败率**：`BANDS[0] = (1.00, 1.00)` 但 `effective_rate(SQUIB)` 早退返回 `0.95`，等于哑炮有 5% 施法成功率，与正典「哑炮…无法施展咒语」的严格读法冲突（Task 7 判定直接走 `effective_rate`）。二选一：把 `BANDS[0]` 改成 `(0.95, 0.95)`，或让 `effective_rate` 对 SQUIB 返回 1.0 / 直接拒绝施法。另注 `base_rate(SQUIB)=1.0` 超出 `effective_rate` 文档化的 `[0.005, 0.95]` 值域，是潜在陷阱。
5. **`Money` 负值显示未定义**：`Money.from_knuts(-50)` → `parts() = [0, -2, -16]`，`formatted() = "0加隆 -2西可 -16纳特"`。**Task 9 已落地面板（`player_panel`/`power_panel` 会输出该形态），但仍未定义**：债务场景会显示负值西可/纳特。需裁定债务格式（如「负债 X 加隆」）或在 `Money` 层定义。
6. **大师级失败率上界 0.02** 对正典「低于2%」是开/闭区间歧义，测试用 `<=` 掩盖了它。
7. ✅ **已闭合（03a T7：势力面板重写为「机构级指标来自派系机构控制权」）** —— **（Task 9 已落地，扩展）`power_panel` 标签映射** 把 **7 个标签**映射到 **4 个 `world_vars`**：法律执行→`war_pressure`、傲罗/稳定度→`ministry_stability`、威森加摩/腐败度→`corruption`、国际→`muggle_relations`（与「麻瓜关系」重复）。纯显示问题，确认可接受，或后续补独立的 `international_relations` 等键。
8. ~~**是否先补 Task 3 的测试强度缺口**（审查 Minor）~~ **已收口（加固批次 `e094a52`）**：`magic_level_test` 已逐档钉住十档 `BANDS`/`LABELS` 并用真越界输入验证 clamp（22→48 断言）；`money_test` 补了负值 `parts()`/`formatted()`/往返（15→18）。
9. **（Task 4 Important，范围外）~~已由 Task 10 局部收口~~**：Task 10 在 `SaveCodec.decode` 加 `_validate_payload`（顶层容器/标量类型校验）+ `from_dict` 后 `world/player/clock` 非 null 兜底，使「null 型毒对象」不再返回 `ok=true`。**残余**：容器类型正确但内层值类型错（如 `player.magic:{"known_spells":123}`、`rng_state:{"streams":123}`）仍可能静默降级或在 `from_dict` 内报错后返回 `ok=false`（伴随 stderr 噪音）。彻底修法：嵌套白名单校验，或不依赖类型化赋值错误。见 §8#47。
10. **（Task 4 Minor）** `JsonUtil.normalize` 未覆盖非有限 float、≥2^53 的整数值 float、Dictionary 键类型；当前游戏数值不触发，建议在计划/注释写明这三条限制。
11. **（Task 4 Minor）** 计划 Interfaces 段（约 1000–1020 行）缺 `era_start_year`、`PlayerState.new_default()`、`normalize -> Variant`，与 Step 代码不一致（纯文档级）。
12. **（Task 4 Minor）** `custom` 时代 `start_year:null` 静默回退 1991、月份固定 9；`WorldState.create()` 无处接收玩家指定年份，与 `data/eras.json` 中 custom「由玩家指定年份」语义不符。
13. **（Task 4 Minor）** `GameClock.advance_months(负数)` 静默 no-op；`GameClock.from_dict` 缺省 `month=1` 与类默认 `month=9` 不一致。
14. **（Task 4 Minor，Task 5 留意）** registry 原值是整数值 float（如 `secrecy_integrity:1.0`），而状态内 `world_vars` 已归一为 int `1`；未来直接比较二者会因 Godot 字典类型严格比较而不等。约定：比较前先 `JsonUtil.normalize`，或 Registry 载入时统一归一。
15. **（Task 4 已局部落实）** 第 8 条的「测试强度」在 Task 4 已加 3 条（JSON 端到端往返 × 2 + `world_vars` 类型一致性），`magic_level` / `money` 的历史缺口仍待批量处理。

### Task 5 审查新增（均不阻塞 Task 6）

16. ✅ **已闭合（03a T12：新增 `RngService.stream_pick_weighted`，`rumors.weight` 真生效）** —— **（Task 5 Important，计划级）** `data/rumors.json` 的 `weight` 字段声明了但 `tick()` 用 `stream_pick` 均匀抽取，稀有度旋钮失效；二选一：实现加权抽取，或删字段并在契约中说明稀有度由 `major_gate` 负责。建议排入「内容/平衡」任务。
17. **（Task 5 Important，计划级）~~部分收口~~**：Task 8 已让 `TurnEngine.submit` 写 `world.rng_state = rng.state_dict()`（GM 与引擎共享同一 `RngService`），Task 10 的端到端测试已证实「读档 → 重建引擎 → 继续提交」与原时间线一致（`09861d0` 反证：删那一行 → `[save]` 变红）。**残余决策**：是「引擎持有唯一 RNG 并注入 GM」的正式化（Task 11 接线时必须保持共享引用），还是「派生式确定性」并删 `rng_state`。
18. **（Task 5 Minor）** `RngService` 无 schema 版本号，旧扁平 schema 静默不恢复；`String::hash()` 为 32 位有碰撞风险；同月两次 pick 可命中同一条 rumor；`history` 无上限、`log` 三种 schema；`age_months` 无条件推进、与 `clock` 各自计时；信息保护断言仍恒真（`ministry_access` 全仓无人授予）。
19. **（Task 5 Minor，新增 N5）** `WorldState.game_seed` 仍是裸 int，>2^53 经 JSON 往返丢失（与 `RngService` 已字符串化不对称），会让读档后世界演化静默分叉。**Task 10 未修**（计划范围仅 persist 层；`SaveCodec` 已开 `full_precision`，但不覆盖 int64）。建议随存档格式 v2 一并字符串化。
20. **（Task 5 Minor，测试缺口）~~已收口（Task 10）~~**：`tests/save_test.gd` 已有「存 2 回合 → encode → decode → 重建 TurnEngine → 继续 submit」的端到端对比（叙事 + 全量 `to_dict`），以及「已推进的 work 流经 JSON 往返一致」的断言；反证删 `turn_engine.gd:46` 会变红。残余：`tick` 级双世界同轨对比仍可加强（当前由引擎级覆盖）。

### Task 6 审查新增（均不阻塞 Task 7）

21. ✅ **已闭合（03a T12：`data/wand_cores.json` 新增数值字段 `weight`（common=6/rare=1），`rarity` 保留为语义标签）** —— **（Task 6 Minor，计划级）** `data/wand_cores.json` 的 `rarity` 声明但 `generate_wand` 均匀抽取（与 Task 5 `weight` 同类）；二选一：实现按 rarity 加权，或删/改述该字段。
22. **（Task 6 Minor）** 玩家自带魔杖只校验 `wood/core/flexibility`，**不校验 `length_inches`**（可传任意值）；且「自带魔杖」分支无任何测试。
23. **（Task 6 Minor）** `p.flags["prejudice_level"]` 把 float 写进 bool 语义的 `flags`；建议提为 `PlayerState` 数值字段，`flags` 只留 bool。
24. **（Task 6 Minor）** `create()` 的 `no_magic`/`p.job=""` 与 `new_default()`/squib `default_flags` 重复（`no_magic` 断言部分空转）；`aptitude.grants` 循环因全表 `grants=[]` 恒空转。
25. **（Task 6 Minor）** `assign_house` 双向 `contains` 子串过宽（单字关键词可放大得分），且性格关键词无数量上限。
26. **（Task 6 Minor，须登记）** 存档载入路径（`PlayerState.from_dict` / `WorldState.from_dict`）**不重跑 `validate_choices`**，「无天赋的特殊资质」等非法组合可经手改存档进入状态。**Task 10 未处理**（仅做了结构/类型层防御，未做内容层校验）；建议随存档格式 v2 或 Task 11 载入流程补一次校验。

### Task 7 审查新增

27. ~~**（Task 7 Important）**~~ **已裁定并落地（Human，提交 `a0bc1d3`）**：`energy_loop_count` 采用 **per-turn** 语义——`WorldState.tick()` 在 `clock.advance_month()` 后 `flags.erase("energy_loop_count")`，同回合内累计、每回合（月）重置；`time_rewind_count` 维持 **终身一次性**（上限 1，永不重置）。计划 Task 5/7 已同步，`[spell]` 新增 4 条回归断言（223→227）。Task 8 计划测试（同一回合内连续施法 5 次、中间不 `tick()`）不受影响。注意：per-turn 契约绑定在 `WorldState.tick()`，Task 8 回合推进必须统一经 `tick()`（勿直接 `advance_month`）。
28. **（Task 7 Minor）** `illegal_cast_count` 仅成功时自增，非法施法失败（未遂）不计入法律风险台账（Task 8 会读取此计数）。
29. **（Task 7 Minor）** 被拦截的 `Outcome` 沿用 `failure_rate=1.0`、`roll=1.0`，与「未进入掷骰」语义混淆；Task 8 展示层需以 `blocked` 为唯一判据或补 `rolled: bool`。
30. **（Task 7 Minor）** `legilimens`/`confundo` 的 `legal_risk`、计数器「成功时自增」、`last_serious_mishap_turn`、`time_turner` 把「未拦截」当「允许」、确定性用例弱等价等测试缺口；`portkey` 两条只断言 `blocked` 未断言 reason。
31. **（Task 7 Minor，文档级）** `difficulty` 实为**绝对失败率偏移**（0.02–0.30）而非「相对难度」，与计划表述不符；有意则注明，否则改插值/缩放。
32. **（Task 7 Minor）** fail-closed 稀有度白名单的 `常见` 与简体 `传说` 无独立断言；全角空白（U+3000）/全角拉丁会被过度拦截（安全方向，无绕过）；若 Task 8 的 LLM 层可能产出全角字符，需在归一化前加宽度折叠。

### Task 8 审查新增（均不阻塞 Task 9，但需登记）

33. **（Task 8 Important）~~已收口（计划 02 Task 6）~~**：`StateOps.world_gm_rng` 现按调用序号加盐（`game_seed + turn*15485863 + counter*2654435761`，计数器 `_gm_rng_counter` 入 `world.flags` 并随存档往返），同回合多次施法掷不同 roll。
34. **（Task 8 Important，计划级，与 §8#17 同源）** `TurnEngine.rng` 全文从不掷数，真正影响叙事的 `ScriptedGameMaster.rng`（work/social/spell_roll）**未入档**；`world.rng_state` 存的是一个空转 RNG。读档后叙事随机流从头开始（同一「打工」收益恒定、社交掷骰重放），破坏「存档往返一致」不变量。测试 `w8.rng_state.size() > 0` 对此零覆盖。**Task 10 必须补 `submit → to_dict → JSON → from_dict → 重建引擎 → submit` 的端到端对比**，并决定「引擎持有唯一 RNG 并注入 GM」还是「改述为派生式确定性并删除 `rng_state`」。
35. **（Task 8 Important，架构，扩展 §8#3）** `ScriptedGameMaster.act` 直接改世界（`SpellResolver.cast` 写能量/时间/非法施法计数，`Progression.gain` 写 `recent_training`），绕过 `StateOps`（计划内已文档化）。审查新增三条后果：(a) 副作用不进 `deltas_applied`，与第七章「所有变更经 StateOps 便于审计」相悖；(b) 被守卫拦截的施法既无 `op_errors` 也无状态痕迹，调用方无法区分「拒绝」与「正常」；(c) `last_cast_success`/`last_cast_narration` 只有 StateOps 路径会写，生产路径恒为陈旧/未设。留待人类裁定。
36. **（Task 8 Minor）** `TurnEngine.submit` 的 `deltas_applied` 实际是「请求的 delta」（被 StateOps 拒绝的 op 也在其中），字段名误导；建议改名或按 `op_errors` 过滤。
37. **（Task 8 Minor）~~已收口（加固批次 `e094a52`）~~**：`set_flag`/`set_player_flag` 空 key、`know_fact` 空 `fact_id`、`add_money` 非数值、`relation_delta` 空 `npc_id` 现均报错且**不写入**（`gm_test` 有对称的「未写入」断言 + 反证）。**残余**：`relation_delta` 增量仍无上下限。
38. **（Task 8 Minor）** `Progression` 窗口 `turn - entry <= WINDOW_TURNS` 是闭区间（实际保留 13 个回合偏移，与「12 回合内」差一）；`gain==0` 也追加记录，同一回合反复调用可无界累积；键从不 GC（换地点即新建）；「换环境重新计算」导致两地点轮换可把惩罚减半。
39. **（Task 8 Minor，文档级）** 计划 Interfaces 少列 `set_player_flag`、`set_magic_tier` 与 `relation_delta.interest`；`GmResult.audit_required` 无消费者；`tags` 未出现在 `submit` 返回字典（UI 拿不到 cast/train 分类）。
40. **（Task 8 Minor，测试强度）~~已收口（加固批次 `e094a52`）~~**：`cast_result` 去掉了恒真右操作数、`money_before` 真正使用、cast 循环断言计数不增长、`op_errors` 消息内容断言、补了 `set_flag`/`set_player_flag`/`set_magic_tier`/`relation_delta`、`know_fact` 空/`system` 来源、非字典条、blocked 提交不推进回合（38→59 断言）。**未补残余**：第 14 回合 `audit` 为空、哑炮分支子串。

### Task 9 审查新增（均不阻塞 Task 10，但需登记）

41. ✅ **已闭合（03a T7 重写势力面板，不再从 `world_vars` 猜机构级指标）** —— **（Task 9 Minor，扩展 §8#7）** `power_panel` 的「国际」与「麻瓜关系」同映射到 `muggle_relations`，连同已登记的映射共 7 标签→4 变量；纯显示，无新误映射（逐字照抄计划）。见上 §8#7。
42. **（Task 9 Minor，计划级）** 第七十二章第 1 项「人物行为偏离设定」依赖 `npcs[*].ooc_violation`，但该字段在 `src/`、`data/` 全库无写入者 → 生产路径恒为「通过」，检查空转。须由叙事层/未来任务写入，或在计划注明为人工/AI 标注项。
43. **（Task 9 Minor，测试强度）** 负例缺口：`events_block` 空数组、`_top_skill`/`_skills_line` 空技能、`_label` 未知/空 id、`relation_panel` 空关系、非哑炮空魔杖、`snapshot` 空 npcs/pending/history、`ooc_report` 空来源泄露/canon 锚点超前、`is_audit_turn` 负数、哑炮分支仅 2 子串。建议与 §8#8/#40 的测试加固批次合并。
44. **（Task 9 Minor，§8#5 触发）** `Money` 负值显示已经由 `player_panel`/`power_panel` 暴露到 UI；见 §8#5。
45. **（Task 9 Minor，§8#9 同类）** `var rel: Dictionary = p.relations[npc_id]`、`var family: Dictionary = flags.get("family", {})`、`float(world_vars[key])` 在畸形/手改状态下可能运行期报错；建议加 `typeof` 回退，或明确「状态只由 `to_dict()` 产出」。
46. **（Task 9 Minor）** `SelfCheck.ooc_report` 的 `timeline_detail` 在「年份早于锚点」与「canon 事实超前」同时成立时被后者覆盖，只报最后一条异常原因（不影响 yes/no 判定）。
### Task 10 审查新增（均不阻塞 Task 11，但需登记）

47. **（Task 10 Minor，嵌套校验缺失）** `SaveCodec._validate_payload` 只做**顶层**类型检查；容器类型正确但内层值类型错时，`PlayerState.from_dict`/`WorldState.from_dict` 会报错并使子对象为 null（现已被 `decode` 的 null 兜底转为 `ok=false`），或在无类型化赋值的路径静默降级（如 `player.magic:{"known_spells":123}`、`rng_state:{"streams":123}` 到使用点才报错）。建议改为嵌套白名单校验，或不依赖赋值错误。
48. **（Task 10 Minor，日志噪音）** 被守卫拒绝的畸形载荷仍向 stderr 打印 `SCRIPT ERROR`（功能契约已满足：`ok=false`、进程不中断）；根因是 `from_dict` 在守卫前已执行。
49. **（Task 10 Minor）** `SaveStore.save` 用 `FileAccess.WRITE` 直接覆盖，无 temp+rename（写盘中断会留下半截槽，旧档已毁；校验和只能拦住载入）；`list_slots` 对名为 `.json` 的文件会产空槽名，`.JSON` 大小写不识别。
50. **（Task 10 Minor，已改进）** `SaveCodec.encode` 已开 `JSON.stringify(..., true, true)` 的 `full_precision`，但仍**不保证** double 精确往返（实测 `secrecy_integrity` 差 1 ULP）；§8#19 的 `game_seed` int64 未处理。

### Task 11 审查新增（计划 01 收尾；均为 UI/测试强度，非阻塞）

51. ~~**（Task 11 Minor，UI 焦点）**~~ **已收口（`e094a52`）**：`_on_load` 成功后 `command_edit.grab_focus()`。
52. **（Task 11 Minor，UI 仪轨）** `_on_audit` 按钮先打印报告再立即 `acknowledge_audit()`，弱化「必须读完再确认」的仪式感（引擎侧第 72 章不变量仍成立）；若要保留，改为提示输入「确认自检」。（未做，留待裁定）
53. ~~**（Task 11 Minor，假绿风险）**~~ **已收口（`e094a52`）**：`tools/test.sh` 冒烟 `tee` + `grep -q "main scene ready"`，未命中即失败；临时文件加 `trap ... EXIT`。
54. ~~**（Task 11 Minor）**~~ **已收口（`e094a52`）**：删除死变量 `_turn_count`。
55. **（Task 11，人工验收缺口）~~已完成（2026-09-20）~~** —— 已用**自动化通道**跑完计划 Step 6 的 8 项 + 计划 02 追加 2 项：`bash tools/b1_acceptance.sh` → **151 断言 / EXIT=0**（写这份文档时是 78，此后随 T7–T12 / 03a-P 长到 151），报告 `docs/sdd/plan-02-llm-narrative/b1-acceptance.md`。关键：`HALI_DEBUG_LOG` 镜像（见 §2 末尾）让界面文本可外部观测，探针直接驱动界面处理器（等同点按钮/回车），并从真实控件状态 + `get_parsed_text()` 断言。
    - **仍未做的（不影响验收结论，已登记）**：真实 OS 鼠标/键盘事件、像素级排版可读性、真的关进程重开（用同进程新实例模拟）、真机 LLM 几十秒等待与断网降级（属 B2，用户裁定暂不做）。
      **2026-09-20 复核（03a / 03a-P 完成后）：仍未做**。B1 自动通道只能覆盖**可观测契约**（控件状态 + 镜像文本），
      **不覆盖**像素级排版可读性与真实 OS 事件；这两项只能在真正的人工 GUI 验收里做。
56. **（加固批次发现，Minor）** `run_tests.gd` 新增的 `report_calls` 哨兵只覆盖「套件中途中止、未调用 `report()`」；**非中止**运行期错误（如字符串 `%r` 格式错误）仍会 `EXIT=0`。若要全堵，需对 stderr 做白名单扫描或让套件返回期望断言数。
57. **（加固批次发现，Minor）** `save_test.gd` 「非十六进制校验和被拒」断言命名夸大（实现只是普通校验和不匹配，并无 hex 解析）；建议改名。

### 计划 02 审查复审新增（来自 Tasks 8–11 修复轮后的独立 scoped 复审，2026-09-20）

58. ✅ **已闭合（03a T10：等待期看门狗 + 单一恢复出口）** —— **（计划 02 新增，Minor）UI 等待期无超时/取消**：`src/ui/main.gd` 的 `await engine.submit_async(text)` 若因异常永不恢复，`command_edit.editable=false` 与整排按钮的禁用态将**停留在禁用态**（GDScript 无 try/catch，UI 层无看门狗）。缓解：`LlmGameMaster` 有 2 次尝试 + 降级，`OpenAiCompatProvider` 设了 `HTTPRequest.timeout`（默认 30s），故正常流程下概率低。裁定项：是否补 UI 层超时/「取消」按钮（建议随「设置界面」小计划或计划 03 的 UI 改动一起）。
59. **（计划 02 新增，已接受）** `src/ui/main.gd` 的 `_on_command_submitted` 结束时以 `PanelFormatter.status_line(...)` 整体刷新状态行，故「未配置 LLM」提示在**首条指令后**消失（创建路径与读档路径都是如此）。计划侧已明确接受（`task-11-report.md`），登记备查、无需修改。
60. **（计划 02 新增，文档漂移，已修）** 计划文档 `docs/superpowers/plans/2026-09-19-...-02-llm-narrative.md` 的 `_on_load` 步骤片段仍在写旧顺序（`rng=…; engine=TurnEngine.new(world, _build_gm(), rng)`），按该片段重实施会**复现 F4**。已在 2026-09-20 同步为「先写 status_line、再建 GM」并加注 `18eaa5c`。

### 计划 02 重跑盲审新增（2026-09-20，对 `fed4767^..15c1ff0` 的独立盲审）

> 完整记录（含原文、三方对照、现网逐条核验）：`docs/sdd/plan-02-llm-narrative/task-811-review-rerun.md`。重跑共 11 条：P1×2 / P2×9；其中 3 条与首轮重合（已修）、1 条（降级路径直改 world）已在 §8#3/#35。以下为本轮**新登记且至今仍成立**的部分。
>
> ⚖️ **2026-09-20 人类裁定**：本节 #61–#65 与 §8#58 **不单开加固批次**，一律**留给计划 03 启动后顺手处理**（已列入 `NEXT-STEPS.md` §C 与 B3 的必办清单）。

61. ✅ **已闭合（03a T11：降级原因并进 `op_errors`/`warnings`，UI 逐条打印）** —— **（重跑盲审新增，Minor，spec §9 偏差）降级原因未透出 + `last_error` 是 write-only**：`llm_game_master.gd:_fallback` 在 `fallback != null` 分支只把 `FALLBACK_NOTE` 追加到叙事，**不带原因**、也不写 `r2.warnings`；`last_error` 全仓只有声明（`:9`）与赋值（`:48`），**无读取者**。spec §9 要求「降级 … 追加系统提示 … **并记 `op_errors`**」。后果：玩家与调用方拿不到降级原因（HTTP 状态码/解析错误），无法区分「网络抖动」与「模型老不吐 JSON」。便宜修法：`r2.warnings.append("LLM 降级：%s" % reason)`（UI 已会打印 `op_errors`）。
62. ✅ **已闭合（03a T10：把「提交—恢复」收进唯一出口，并在 `engine==null` 时立即恢复）** —— **（重跑盲审新增，Minor，后果重）UI 提交路径无失败恢复**：`main.gd:_on_command_submitted` 在 `editable=false` + `_set_buttons_enabled(false)` 之后 `await engine.submit_async(text)`，恢复语句只在正常尾部；`await` 链中任何运行期错误（GDScript 无 `try/catch`）都会让协程提前中止 → 输入与**整排按钮永久禁用，只能重启**。当前 `main` 上 `choices[0]` 类路径已被 `a48f108` 封住，故需要一个尚未封住的运行期错误（如畸形状态让 `PanelFormatter` 报错，见 §8#45）才会触发：概率低、后果重。建议把「提交—恢复」收进**唯一出口**（helper/状态机）；⚠️ **不要**只在 `_on_load` 里补 `editable = true`（按钮同批被禁，读档入口不可达，补那句治不了本）。与 §8#58 同源，本条更锐。
63. ✅ **已闭合（03a T10：`ensure_http`/`dispose` 复用与释放 + `http_timeout_sec` 每次生效）** —— **（重跑盲审新增，Minor）provider 泄漏 `HTTPRequest` 节点 + `timeout` 只生效一次**：`OpenAiCompatProvider.complete()` 懒建 `_http` 并 `add_child(_host)`，从不 `remove_child`/`queue_free`；而每次「开始人生」/「读档」都 `new` 一个 provider（`main.gd:_build_gm`）→ **每切换一次生命周期泄漏 1 个 Node**。另外 `_http.timeout` 只在建节点时按首个请求设一次，后续 `timeout_ms` 变更不生效。建议：复用单例 `HTTPRequest`，或在重建 provider 前释放旧节点。
64. ✅ **已闭合（03a T11：三条均已补/收紧断言）** —— **（重跑盲审新增，Minor，测试可判别性批次）** `tests/llm_test.gd`：①「解析失败 → `build_repair` 再试」**不可判别**（mock 不看请求内容，把 `build_repair` 换成 `build` 仍绿）→ 应断言 `requests[1].system_prompt` 含修复提示；②`res3.narration.length() > 0` **准恒真**（`fallback != null` 时必然非空）→ 应改断言含「本地规则结算」；③`api_key` 脱敏只有正向断言（「头里有 key」），**无**任何「错误串不含 key」的负向断言。可与 §8#8/#40/#43 的测试加固批次合并。
65. ✅ **已闭合（03a T11：`act` 注明可协程 + spec 同步 + 改鸭子类型判定 + blocked 文案）** —— **（重跑盲审新增，Minor）契约文档与类型守卫漂移**：①`src/gm/game_master.gd` 的 `act` 未注明「可协程」（设计 §5 文件表要求）；②实现是 `TurnEngine._resolve`，spec §6.3 写的是 `_post_submit`（读 spec 会找不到符号）；③`submit()` 用 `gm is LlmGameMaster` 这种**具体类型**判断拒绝协程 GM——换任何「协程 `act` 的非 `LlmGameMaster`」就会把协程对象送进 `_resolve` 而崩，且拒绝分支 `narration` 为空（UI 无提示）。建议：spec/注释就地同步 + 改鸭子类型判定（或至少补 blocked 文案）。

### B2 真机 LLM 联调新增（2026-09-20）

> 完整报告（已脱敏，不含 key 与内网域名）：`docs/sdd/plan-02-llm-narrative/b2-live-integration.md`。

66. ~~**🔴（B2，Important）`llm_settings.json` 的 `temperature` / `max_tokens` / `timeout_ms` 三个字段完全不生效**~~ **已修（`3240af6`，2026-09-20）**：`LlmGameMaster` 新增可选 `settings` 参 + `_apply_settings()`，在 `act()` 的 `build` 与 `build_repair` 两处 request 上都覆盖这三个字段；`main.gd:_build_gm()` 同步传参。`[llm]` 65→79（新增「settings 真的进请求」「重试请求同样进」「不传 settings 时沿用类默认值」等断言）；反证：把 `_apply_settings` 变空操作 → 5 条红；真机回归 → 不再降级（叙事 346 字、4 条 ops 落地）。原问题描述：`grep -rn "settings\.\(temperature\|max_tokens\|timeout_ms\)" src/` 零命中——`PromptBuilder.build()` 造出的 `LlmRequest` 带的是 `llm_provider.gd:7-9` 的**类默认值**（0.8 / 1024 / 30000），而 `OpenAiCompatProvider.complete()` 用的是 `request.max_tokens`/`request.timeout_ms`。两处类默认值恰与 `LlmSettings` 默认值相同，所以单测与计划 01/02 都发现不了。**后果**：遇到「始终思考」型模型时思维链吃光 1024 预算 → `content` 恒空 → 每回合降级 `ScriptedGameMaster`，**玩家改配置也救不回来**。
67. ~~**（B2，Minor）LLM 错误串诊断性不足 + 思考模型默认值**~~ **已修（`3240af6`）**：`_parse_http` 现对 `status == 0` 报「请求未到达服务端（HTTP 状态 0：连接失败/超时中断）」（原为 `HTTP 0（）`），对空 `content` 带上 `finish_reason`，并在 `length` 时提示「思考型模型需提高 max_tokens」；`[llm]` 新增 6 条断言（反证：退回含糊版 → 3 条红）。**残留（未改代码，已在 README/B2 报告写明）**：`LlmSettings` 的 `max_tokens` 默认值仍为 1024 —— 思考型模型需使用者显式配 `max_tokens ≥ 8192`、`timeout_ms ≥ 120000`（实测：1024 → `finish_reason=length`/`content` 空；8192 → `stop`/738 字；`timeout=30s` 处临界）。
68. **（复审新增，Minor，范围外）`LlmSettings.provider` 无读取端**：`provider` 字段（`llm_settings.gd:6`）全仓无 `grep settings\.provider` 命中，仅作 JSON 往返保留——当前只有 `openai_compat` 一种实现。等计划 03 做 provider 路由/本地模型时顺手处理（要么消费它，要么从配置里删掉）。
69. ✅ **已闭合（03a T12：把 `:175` 那个无条件的 `assign_house()` 移进非哑炮分支，哑炮固定 `house_id="none"`；B1 探针由观察项改为断言）** —— **（B1 非正式点击新发现，正典保真）哑炮却有学院**：实测存档案（`user://saves/slot1.json`）里 `bloodline_id=squib` 而 `house_id=gryffindor`。根因：`character_creation.gd:175` `p.house_id = assign_house(choices, rng, registry)` 在哑炮分支（`:205` 设 `flags["no_magic"]`）**之前**无条件执行。正典第七章/第二十四章：哑炮不进霍格沃茨（通常被送往麻瓜学校），故「哑炮 + 某学院」疑似违背正典。`data/houses.json` 已有 `none` 可用作候选取值。**待裁定**：哑炮是否应 `house_id="none"`（或标记为“未入学”），还是保留当前行为（把学院当作家世/归属标签）。
    - 2026-09-20 B1 自动验收**再次独立复现并留证**：`bash tools/b1_acceptance.sh` 的哑炮角色 `house_id=gryffindor`（见 `b1-acceptance.md` §5）。
70. ✅ **已闭合（03a T12：姓名框默认空 + 占位提示、新增性别下拉（男/女/未定）并读下拉真实值；姓名留空会被 `validate_choices` 拒绝）** —— **（B1 非正式点击新发现，UX）创建界面的姓名与性别**：`src/ui/main.gd:114` 把姓名框预填「无名者」，`:171` 把 `gender` 硬编码成「未定」——玩家不改名直接开局，就会得到一个“无名者·未定”的角色（实测存档确实如此）。且**创建界面没有性别输入**，全部角色性别恒为“未定”。非 bug，但影响代入感与后续按性别分支的规则（若有）。

71. **（03a T12 审查 Important，范围外）`§8#69` 的读档路径**：`src/model/player_state.gd` 读档时 `p.house_id = str(d.get("house_id", "none"))` —— **原样拷贝、不重判**。于是修复前生成的旧存档（就是 `§8#69` 的原始证据那个 `squib`+`gryffindor`）读进来仍是 `gryffindor`；只有重新建角才得 `none`。
    裁定（控制器，2026-09-20）：**归「存档格式 v2」批次**（与 `§8#26`「载入不重跑 `validate_choices`」同族）。理由：① `from_dict` 的契约是忠实还原，在里面塞内容级归一化会造出一个**隐藏的读时改写**，且无法区分「修复前的脏数据」与「将来某个合法场景」；② 只归一化 `house_id` 一个字段、而校验照旧不跑，是任意且不自洽的；③ 正确入口是存档 v2 的一次性迁移。依据全文见计划「Task 12 范围声明」。
    **零成本缓解**：旧存档属历史数据，**重建角色即得 `none`**（B1 探针每次新建角色，已按 `none` 断言）。创建路径已堵死（`assign_house` 在生产代码里只有 1 个调用点）。
72. ✅ **已闭合（素材线，2026-09-20；素材提交 `d18df0f`，控制器合并 `ea50b91`）** —— 三件均已入库。**保留原文供追溯**：
    - **CJK 正文字体**：Godot 内置字体不含中日韩字形。**已入库** `assets/fonts/body_cjk.ttf`（LXGW WenKai v1.522，25,575,676 B，OFL-1.1）并已由 `fonts.body` 接上；控制器用 Godot `FontFile.has_char()` 实测**缺字=无 / PASS**。既有的 4 个字体对「你」全 `false`。
      **不得子集化**（玩家可输入任意汉字），全字集 10–20MB+ 属正常，**不用 Git LFS**；覆盖自检由控制器用 Godot `FontFile.has_char()` 在合并后做（不需要 Python 包）。
    - **OFL 许可证文本**：`Cinzel-Variable.ttf` / `IMFeENrm28P.ttf`（IM Fell English）/ `MedievalSharp.ttf` 都是 OFL-1.1，**OFL 强制要求再分发时随附许可证原文**，而仓库现在一个都没有（`assets/CREDITS.md` §三 已把它写成义务）。已落盘为 `assets/fonts/OFL-Cinzel.txt` / `OFL-IMFellEnglish.txt` / `OFL-MedievalSharp.txt` / `OFL-LXGWWenKai.txt`（官方原文，逐份做了 header/perm/term/disc 完整性校验）。
    - **`interface.psd` 切片**：Godot 无 PSD 导入器（实测 `ResourceLoader.exists()` = false）⇒ 需切成 PNG（`assets/ui/panel_bg.png` / `button_normal|hover|pressed.png` / `scrollbar_bg|grab.png` / `checkbox_on|off.png` / `logo.png`，**文件名即契约**）。
    - ✅ 两件零代码事**已做完**：① `--import` 生成 14 个 `.import` 并提交；② `data/presentation.json` 加了 `fonts.body` → `body_cjk.ttf`（`ThemeBuilder:47-50` 消费它设 `default_font`）⇒ **中文界面已可读**。
    - ✅ 额外交付：`assets/icons/ICON-MEANINGS.md` —— 15 个 SVG **实际渲染后逐格看图**再写描述（不是猜文件名），
      查出 **2 处文件名与图形不符**（`book-cover` 实为**摊开的书页**、`floating-ghost` 是**戴尖顶帽的幽灵**）；现有映射仍成立，故不改键、只留档。
    - ⏳ **仍留一条**：13 张切片**暂未写进清单**（`panel_bg` 需 `PanelContainer` 包裹；按钮/文本框/滚动条要在 `ThemeBuilder` 里换成 `StyleBoxTexture`）。
      先写清单行而无人消费 = 「声明了但无效」的死旋钮（`§8#16/#21` 同类）⇒ 登记为 **P5b**（`NEXT-STEPS.md` §B8）。
    - 跟踪与流程：`NEXT-STEPS.md` §B6 · 提示词 `docs/sdd/plan-03a-P/assets-handoff-prompt-v2.md` 与 `assets-agent-repair-prompt.md`

> 📝 **修复的复审记录**（`fix/plan-02-llm-settings`，独立只读 reviewer）：`docs/sdd/plan-02-llm-narrative/fix-settings-review.md`（含原文）。结论 **通过 / 0 Critical / 0 Important**；其 3 条 Minor 已分别处置（M-a → 本条 #68 登记；M-b `content:null` 经实证为真缺陷 → 已修 `c9a0c95`；M-c 断言强度 → 已采纳）。

---

## 9. 环境与卫生

- 分支：`main`（交付点）；计划 01/02/03a/03a-P 均已合入，后续计划从 `main` 拉新分支。工作区在交付时应保持干净（`git status --short` 空）。
- 不要提交：`*.exe`（180MB 引擎）、`.godot/`（导入缓存）、`.superpowers/`（工具工作区）、`*.tmp`、`*.bak`、`export/`、`build/`。
- 无外部服务依赖：不起服务器、不调 LLM、不联网（审查/研究工具除外）。
- 换机器后的自检清单：

1. `git log --oneline -1` 是 `main` 顶端的最近一次提交（应含 03a Task 13 的合入记录；**以 `git log` 为准，不要照抄本文里的旧哈希**）
2. 两个 Godot exe 就位，`bash tools/test.sh` → `ALL TESTS PASSED` / `全部通过。` / 退出码 0 / 失败 0（**套件数与断言数见 `NEXT-STEPS.md` §0B**）
3. `tools/test.sh` 会**同时校验两个 stderr 噪音计数**（`SCRIPT ERROR` == 2 且 `ERROR` == 7），不符即退出码 1——见 §2 与 §4 第 16 条
4. `timeout 300 bash tools/b1_acceptance.sh` → 退出码 0、失败 0（人工验收的自动通道；必须带外部 `timeout`，见 §4 第 12 条）
5. `git status --short` 为空（`.godot/` 与 `*.uid` 不应出现新增改动；若 `.uid` 全被改写说明引擎版本不一致，换回 4.7.2）
6. 读 `docs/sdd/plan-03a-factions/progress.md` 末尾，确认与本文 §0/§8 一致；接手前先读 [`NEXT-STEPS.md`](NEXT-STEPS.md) §0（快跑模式）/§0.5（恢复指引）
7. **干完一个任务就 `git push`**（本轮曾攒了 10 个提交才推；新会话请每任务一推）
