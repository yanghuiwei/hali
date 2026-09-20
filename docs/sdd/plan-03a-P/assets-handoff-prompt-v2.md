# 素材交接提示词 v2（**取代 v1**，整段复制给**另一个** agent）

> 用途：把 `assets/` 下剩余的素材工作外包给另一个 agent；主会话继续跑 03a-P 的代码线。
> **本版收紧了权限边界：执行者只能改 `assets/` 下的文件。**
> 产出：分支 `assets/cjk-and-ui-slices`（v1 同名分支可继续用），由主会话（控制器）合并，不由执行者 push 到主线。
> v1 的实现记录：`assets-handoff-prompt.md`（已完成的素材落位见 `assets/CREDITS.md` 与 03a-P spec §8.4）。

```text
项目 E:/Hali（Godot 4.7.2 stable，Windows + Git Bash；仓库 https://github.com/yanghuiwei/hali.git，public）。

════════ 权限边界（硬约束，先看这段） ════════
✅ 你**只能**创建/修改 `assets/` 目录下的文件（含 `assets/CREDITS.md`）。
⛔ 严禁改动 `assets/` 以外的任何文件：`src/` `tests/` `data/` `tools/` `docs/` `project.godot` `.gitattributes` `HANDOFF.md` 等一律不许碰。
⛔ 不要运行 Godot（任何 `./Godot*.exe`、`bash tools/test.sh`、`bash tools/b1_acceptance.sh`）：
   headless Godot 会争 `.godot/` 导入缓存，和主会话并发跑会互相破坏（HANDOFF §4 第 5 条）。
   `*.import` 文件由主会话统一生成，**你不用管、不要手工造**。
⛔ `git add` **只写明确路径**。严禁 `git add -A` / `git add .` / `git commit -a`
   （会把主工作区里别人的未提交改动一起扫进来）。
⛔ 不要把任何临时脚本/中间产物写进仓库（用 `python - <<'PY'` 内联，或写到 `/tmp`）。

【隔离做法】主会话正在 E:/Hali 的 plan-03-factions 分支上跑 03a-P。你用独立 worktree：
  cd /e/Hali
  git fetch origin
  git worktree add -B assets/cjk-and-ui-slices /e/hali-assets origin/plan-03-factions
  cd /e/hali-assets
全部工作与提交都在 /e/hali-assets 里做，最后 `git push origin assets/cjk-and-ui-slices`。
⛔ 不要 push plan-03-factions，不要 merge，不要动 E:/Hali 里的文件。

════════ 分工总览（A/B/C 必做，D/E 可选） ════════
A. 补 CJK 正文字体（不含它，中文界面在别的机器上是豆腐块）
B. 补 OFL 许可证文本（**OFL 的强制义务，现在缺失**）
C. 把 interface.psd 切成 PNG 切片
D. （可选）给 15 个 SVG 各写一句话描述，供人类核定图标语义映射
E. （可选）找可商用（CC0 / OFL）的时代背景 / 学院徽记 / 立绘素材
最后统一：在 `assets/CREDITS.md` 登记（见「登记规则」）。

════════ A. CJK 正文字体（必做，硬前提） ════════
背景（已实测）：Godot 4 内置字体不含中日韩字形（`ThemeDB.fallback_font.has_char('你') == false`），
仓库现有 4 个字体（Cinzel / IM Fell English / MedievalSharp / HarryP）CJK 覆盖也全是 0。

要求：
- 放到 `assets/fonts/body_cjk.ttf`（若只拿得到 .otf 就叫 `body_cjk.otf`）。
- **许可证必须可商用 / 可自由分发**，OFL-1.1 优先。推荐优先级：
  1. 霞鹜文楷 LXGW WenKai —— https://github.com/lxgw/LxgwWenKai/releases （取 `LXGWWenKai-Regular.ttf`，OFL-1.1，单文件含全字集）
  2. Noto Serif SC / Noto Sans SC 的**完整静态** TTF/OTF —— https://github.com/notofonts/noto-cjk/releases
  3. 思源宋体 / 思源黑体 Source Han Serif/Sans（OFL-1.1）
- ⛔ **严禁子集化**：玩家可以输入任意汉字、LLM 会产出任意中文文本。
  不许用 `pyftsubset`，也不许用 fonts.google.com 页面上的 woff2（那些是子集）。
  必须是覆盖 **GB 全字集**的完整字体（预期 10–20MB —— 这是正常的，**不要**为了体积砍字集）。
- **自检（必须做，原始输出贴进报告）**：没有 fontTools 就先 `pip install fonttools`：
  ```
  python - <<'PY'
  from fontTools.ttLib import TTFont
  f = TTFont("assets/fonts/body_cjk.ttf")
  cmap = f.getBestCmap()
  test = "你我他她它的了是不在有一个人大中国学生魔法咒语杖霍格沃茨魁地奇格兰芬多斯莱特林拉文克劳"
  test += "赫奇帕奇，。！？：；、「」《》—…·１２ＡＢ〇祢甯龘爨饕餮"
  miss = [c for c in test if ord(c) not in cmap]
  print("总码点数 =", len(cmap))
  print("缺字 =", miss if miss else "无")
  print("判定 =", "PASS" if not miss else "FAIL")
  PY
  ```
  必须 `判定 = PASS`（`缺字 = 无`）才能提交。
  若某个极生僻字确实缺：**不要偷偷改测试串**，如实报告缺哪一个 + 是否可接受。

════════ B. OFL 许可证文本（必做，强制义务） ════════
`assets/fonts/` 下现有 3 个 **OFL-1.1** 字体：`Cinzel-Variable.ttf`、`IMFeENrm28P.ttf`（IM Fell English）、`MedievalSharp.ttf`。
**OFL-1.1 要求再分发时随附许可证文本**，而仓库现在**一个都没有**（`assets/CREDITS.md` §三 已把它写成义务）。

要求：
- 为这 3 个字体各放一份**完整、未被截断**的 OFL-1.1 原文：
  `assets/fonts/OFL-Cinzel.txt`、`assets/fonts/OFL-IMFellEnglish.txt`、`assets/fonts/OFL-MedievalSharp.txt`
  （也可合并成一份 `OFL.txt` 但要**逐字体注明适用哪个文件**）。
- 来源必须是**该字体官方仓库/发布页**的 LICENSE/OFL.txt 原文（Google Fonts 的 `ofl/<family>/OFL.txt` 即为权威），
  ⛔ 不要自己改写、不要只写一行「本字体采用 SIL OFL 1.1」。
- 若你同时为 A 的 CJK 字体取到了许可证，按同样规则放 `OFL-<font>.txt`（或 `LICENSE-<font>.txt`）。
- 报告里列出：每个文件名 → 来源 URL → 字节数。

════════ C. interface.psd 切片（必做） ════════
背景：`assets/ui/interface.psd`（opengameart「RPG Game UI」，CC0，600×800 RGB，4.4MB）**Godot 用不了**
（实测 `ResourceLoader.exists("res://assets/ui/interface.psd") == false`，Godot 没有 PSD 导入器）。

要求：
- 输出到 `assets/ui/`，**文件名小写下划线**（文件名就是契约，见下），PNG-32（RGBA 带透明），不要交错（no interlace）。
- **先看图层结构再切**：`pip install psd-tools`，打印图层树（名称 + bbox），再决定切哪些、边界在哪。
- **文件名必须严格用下面这套**（主会话的清单 `data/presentation.json` 按这些键取值，改名字就得改两边）：
  | 文件名 | 用途 | 要求 |
  | --- | --- | --- |
  | `panel_bg.png` | 面板底 | 要能九宫格拉伸；建议 ≥48×48；**报告里给出建议九宫格边距**（上下左右各多少 px） |
  | `button_normal.png` / `button_hover.png` / `button_pressed.png` | 按钮三态 | **三张必须同尺寸**；建议高度 40–48px |
  | `scrollbar_bg.png` / `scrollbar_grab.png` | 滚动条槽 / 滑块 | 槽要能纵向拉伸 |
  | `checkbox_on.png` / `checkbox_off.png` | 复选框（PSD 里若有） | 同尺寸 |
  | `logo.png` | 标题 Logo（PSD 里若有） | 保留原始宽高比 |
  表里没有、但 PSD 里确实有且明显有用的切片，**按同样风格自取名**并在报告里单独列出（主会话会决定是否入清单）。
- **保留原始 PSD**：已在仓库里，不要删、不要移动、不要重命名。
- 报告里逐个给出：文件名 / 尺寸 / 是否含 alpha / 建议九宫格边距 / 来自哪个图层。
- ⛔ **不要硬猜**：如果图层结构无法判断（例如所有内容合并在一个图层、边界看不出来），
  **停下来**，把图层清单贴进报告并明确写「需要人类指认」，**不要**随便切一堆无意义的图。

════════ D.（可选，成本低、价值不错）图标语义核定 ════════
`assets/icons/` 下 15 个 SVG 现在只按**文件名**被映射到游戏含义（例：`castle`→霍格沃茨、`crown`→纯血/威森加摩、
`dragon-orb`→黑暗势力、`barn-owl`→信件…）。没人看过图形内容，**名字与图形不符就会接错图标**。

要求：逐个读/渲染 SVG，给出**一句话中文描述**（它到底画的是什么），格式：
  `castle.svg —— 一座带城垛的城堡剪影`
如果某个文件名与图形明显不符，**明确指出**并建议更合适的归属。报告里列全 15 条即可，**不需要改文件名**。

════════ E.（可选）时代背景 / 学院徽记 / 立绘 ════════
`assets/backdrops/`、`assets/emblems/`、`assets/portraits/` 目前**完全没有**素材（清单里就没这些键，
代码会走「缺则不画」回退）。若要补：
- 只允许 **CC0 / OFL / 明确标注可商用** 的来源（opengameart.org、kenney.nl、game-icons.net、Wikimedia 公有领域等）。
- ⛔ **严禁**任何《哈利·波特》官方美术/剧照/Logo/字体（版权）；也严禁从搜索引擎随便抓图。
- 命名（键 = 文件 stem，连字符→下划线）：
  `emblems/house_gryffindor.png`（4 个学院：gryffindor/slytherin/ravenclaw/hufflepuff）、
  `backdrops/era_modern.png`（时代 id 见 `data/eras.json`）、
  `portraits/player_default.png`、`portraits/npc_<npc_id>.png`（NPC id 属计划 05，先不做）。
- 尺寸建议：背景 1280×800、立绘 512×768、徽记 128×128；PNG 带透明。
- 每个文件都要在 `assets/CREDITS.md` 登记（见下）。**没把握就跳过 E，只做 A/B/C/D。**

════════ 登记规则（必做，否则主会话的清单对账会失败） ════════
编辑 `assets/CREDITS.md`：
- 「一、素材总表」的**列结构与 6 列保持不变**：
  `| 文件 | 类别 | 作者 / 来源 | 许可证 | 可否商用 | 署名要求 |`
  「文件」列 = **相对 `res://assets/` 的路径**（例：`fonts/body_cjk.ttf`、`ui/panel_bg.png`、`fonts/OFL-Cinzel.txt`）。
  允许用 glob 写一组（现有先例：`icons/*.svg`）。
- 多个同源切片可以合并成一行（例：`ui/*.png` 沿用 `ui/interface.psd` 那行的来源），也可以逐文件列。
- 「四、待补素材」表里**已解决的行**把状态从 ⛔ 改成 ✅ 并注明文件名；**不要删表、不要改别的行**。
- ⛔ 不要重排/重写别人已写的行；只**追加**新行 + 只改「四、待补素材」的状态列。

════════ 交付 ════════
- 一个 commit（在 /e/hali-assets 的 assets/cjk-and-ui-slices 分支上），`git add` 只写明确路径：
  ```
  git add assets/fonts/body_cjk.ttf assets/fonts/OFL-*.txt assets/ui/<你切出来的>.png assets/CREDITS.md
  git commit -m "assets: CJK 正文字体 + OFL 许可证文本 + interface.psd 切片（03a-P P3/P5 前置）"
  git push origin assets/cjk-and-ui-slices
  ```
- 一份报告（贴在你的回复里，**≤100 行**）：
  1. 分支名 + commit 哈希 + `git show --stat` 的文件清单
  2. A：文件名 / 来源 URL / 许可证 / 体积（MB）/ **覆盖自检的原始输出**
  3. B：逐个 `OFL-*.txt` → 来源 URL → 字节数
  4. C：逐条 `文件名 + 尺寸 + alpha + 九宫格建议 + 来源图层`
  5. D（若做）：15 条一句话描述
  6. E（若做）：文件清单 + 来源 + 许可证
  7. `assets/CREDITS.md` 的改动摘要
  8. 未完成项与原因（缺字 / 图层不可分辨 / 拿不到可商用素材）

════════ 额外提醒（避免返工） ════════
- **替换已有素材时保持文件名不变**（例：将来换掉 `audio/bgm/bg_main.ogg` 就还用这个名字）。
  清单是按逻辑键→路径查表的，**换文件不改名 = 零代码改动**；改名就要同步改清单。
- `assets/README.md` 是指向 `CREDITS.md` 的短指针，**不要删**。
- 不要重排目录结构（`audio/bgm/`、`fonts/`、`icons/`、`textures/`、`ui/` 已定；新增目录用 `backdrops/`、`emblems/`、`portraits/`、
  `audio/sfx/`、`audio/ambient/` 这几个已约定的名字）。
- 体积：`assets/` 现在约 19MB，**不用 Git LFS**；单文件若 >25MB 请先在报告里提出来。
```

---

## 主会话（控制器）收到分支后的合并流程

```bash
cd /e/Hali
git fetch origin
git log --oneline origin/plan-03-factions..origin/assets/cjk-and-ui-slices
git show --stat origin/assets/cjk-and-ui-slices
git diff --name-only origin/plan-03-factions..origin/assets/cjk-and-ui-slices | grep -v '^assets/' && echo "⚠️ 有 assets/ 之外的改动，拒绝合并" || echo "✅ 只动 assets/"
git merge --no-ff origin/assets/cjk-and-ui-slices
timeout 180 ./Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
git status --short                      # 新素材会产生新的 *.import，必须提交
git add 'assets/**/*.import'
git add -A assets
bash tools/test.sh                      # 必须仍是 EXIT=0 / 1767 断言 / SCRIPT ERROR 2 条
git commit -m "chore(assets): 生成新增素材的 .import（CJK 字体 + UI 切片）"
```

⚠️ 合并后**必须**复跑 `--import` 并提交生成的 `.import`，否则工作区会留未跟踪文件、HANDOFF §9 的「工作区干净」门禁会挂。
⚠️ 合并后要把 `data/presentation.json` 补上新键（`fonts.body` → `body_cjk.ttf`、`ui.*` → 切片），这是控制器的活，**不是执行者的**。
