# 素材交接提示词（整段复制给**另一个** agent）

> 用途：把「补 CJK 正文字体 + 切 `interface.psd`」这两件**纯素材**的事交给另一个 agent，
> 主会话继续跑 Task 12 / 03a-P 的代码线。两边**必须隔离**，否则会互相打坏（见下方「硬性隔离」）。
> 产出：分支 `assets/cjk-and-ui-slices`，由主会话（控制器）合并，不由执行者 push 到主线。

```text
项目 E:/Hali（Godot 4.7.2 stable，Windows + Git Bash；仓库 https://github.com/yanghuiwei/hali.git，public）。

你的任务：只做两件「素材」的事。**不碰任何代码**，做完把结果交回。

════════ 硬性隔离（必读，否则会打坏主线） ════════
1. **不要直接在 E:/Hali 里干活**。主会话（控制器）正在同一仓库的 plan-03-factions 分支上跑 Task 12。
   用独立 worktree，全部工作与提交都在那里做：
     cd /e/Hali
     git fetch origin
     git worktree add /e/hali-assets -b assets/cjk-and-ui-slices origin/plan-03-factions
     cd /e/hali-assets
   最后 `git push origin assets/cjk-and-ui-slices`。
   ⛔ **不要 push plan-03-factions，不要 merge，不要动 E:/Hali 里的任何文件。**
2. **绝对不要运行 Godot**（任何 `./Godot*.exe`、`bash tools/test.sh`、`bash tools/b1_acceptance.sh`）。
   原因：headless Godot 会争 `.godot/` 导入缓存，和主线并发跑会互相破坏（HANDOFF §4 第 5 条）。
   `*.import` 文件由主线后续统一生成——**你不用管、不要手工造**。
3. `git add` **只写明确路径**。严禁 `git add -A` / `git add .` / `git commit -a`（会把主线的未提交改动一起扫进来）。

════════ 任务 1：补 CJK 正文字体（硬前提，不是美化） ════════
背景（已实测）：Godot 4 内置字体不含中日韩字形（`ThemeDB.fallback_font.has_char('你') == false`），
仓库现有 4 个字体（Cinzel / IM Fell English / MedievalSharp / HarryP）CJK 覆盖也全是 0
⇒ 全中文界面在别的机器上是**豆腐块**。这是「能不能读」的前提。

要求：
- 放到 `assets/fonts/body_cjk.ttf`（若只拿得到 .otf，就叫 `body_cjk.otf`）。
- **许可证必须可商用 / 可自由分发**，OFL-1.1 优先。推荐优先级：
  1. 霞鹜文楷 LXGW WenKai —— https://github.com/lxgw/LxgwWenKai/releases （取 `LXGWWenKai-Regular.ttf`，OFL-1.1，单文件含全字集）
  2. Noto Serif SC / Noto Sans SC 的**完整静态** TTF/OTF —— https://github.com/notofonts/noto-cjk/releases
  3. 思源宋体 / 思源黑体 Source Han Serif/Sans（OFL-1.1）
- ⛔ **严禁子集化**：玩家可以输入任意汉字、LLM 会产出任意中文文本。
  不许用 `pyftsubset`，也不许用 fonts.google.com 页面上的 woff2（那些是子集）。
  必须是覆盖 **GB 全字集**的完整字体（预期 10–20MB —— 这是正常的，**不要**为了体积砍字集）。
- 把该字体的许可证文本一并放到 `assets/fonts/OFL.txt`（或 `LICENSE-<font>.txt`）。
- **自检（必须做，并把原始输出贴进报告）**：用 Python 检查字形覆盖。没有 fontTools 就先 `pip install fonttools`：
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

════════ 任务 2：把 interface.psd 切成 PNG 切片 ════════
背景：`assets/ui/interface.psd`（opengameart「RPG Game UI」，CC0，600×800 RGB，4.4MB）
**Godot 用不了**（实测 `ResourceLoader.exists("res://assets/ui/interface.psd") == false`，Godot 没有 PSD 导入器）。需要切成 PNG。

要求：
- 输出到 `assets/ui/`，**文件名小写下划线**，PNG-32（RGBA，带透明通道），不要交错（no interlace）。
- **先看图层结构再切**：`pip install psd-tools`，然后打印图层树（名称 + bbox），再决定切哪些、边界在哪。
- 按此表命名；表里没有但 PSD 里确实有的，按同样风格自取名并在报告里说明：
  | 文件名 | 用途 | 要求 |
  | --- | --- | --- |
  | `panel_bg.png` | 面板底 | 要能九宫格拉伸；建议 ≥48×48；**报告里给出建议九宫格边距**（上下左右各多少 px） |
  | `button_normal.png` / `button_hover.png` / `button_pressed.png` | 按钮三态 | **三张必须同尺寸**；建议高度 40–48px |
  | `scrollbar_bg.png` / `scrollbar_grab.png` | 滚动条槽 / 滑块 | 槽要能纵向拉伸 |
  | `checkbox_on.png` / `checkbox_off.png` | 复选框（若有） | 同尺寸 |
  | `logo.png` | 标题 Logo（若有） | 保留原始宽高比 |
- **保留原始 PSD**：已在仓库里，不要删、不要移动、不要重命名。
- 报告里逐个给出：文件名 / 尺寸 / 是否含 alpha / 建议九宫格边距 / 来自哪个图层。
- ⛔ **不要硬猜**：如果图层结构无法判断（例如所有内容都合并在一个图层、或切片边界看不出来），
  **停下来**，把图层清单贴进报告并明确写「需要人类指认」，**不要**随便切一堆无意义的图。

════════ 任务 3：登记授权台账（必做，否则后续校验会失败） ════════
编辑 `assets/CREDITS.md`：
- 在「一、素材总表」里为**每个新文件**加一行，**列结构与 6 列保持不变**：
  `| 文件 | 类别 | 作者 / 来源 | 许可证 | 可否商用 | 署名要求 |`
  「文件」列 = 相对 `res://assets/` 的路径（例：`fonts/body_cjk.ttf`、`ui/panel_bg.png`）。
  字体必须写明来源 URL 与 OFL-1.1；PSD 切片沿用 `ui/interface.psd` 那行的来源（CC0 / opengameart RPG Game UI），
  可以合并成一行 `ui/*.png`，也可以逐文件列。
- 「四、待补素材」表里已解决的两行，状态从 ⛔ 改成 ✅ 并注明文件名。**不要删表、不要改别的行。**

════════ 交付 ════════
- 一个 commit（在 `/e/hali-assets` 的 `assets/cjk-and-ui-slices` 分支上）：
  ```
  git add assets/fonts/body_cjk.ttf assets/fonts/OFL.txt assets/ui/<你切出来的>.png assets/CREDITS.md
  git commit -m "assets: 补 CJK 正文字体 + interface.psd 切片（03a-P P3/P5 前置）"
  git push origin assets/cjk-and-ui-slices
  ```
- 一份报告（贴在你的回复里，≤80 行）：
  1. 分支名 + commit 哈希 + `git show --stat` 的文件清单
  2. 字体：文件名 / 来源 URL / 许可证 / 体积 / **覆盖自检的原始输出**
  3. 切片：逐条 `文件名 + 尺寸 + alpha + 九宫格建议 + 来源图层`
  4. `assets/CREDITS.md` 的改动摘要
  5. 未完成项与原因（缺字 / PSD 图层不可分辨 / 拿不到可商用字体）

════════ 边界 ════════
⛔ 不要动 `src/`、`tests/`、`data/`、`tools/`、`docs/`、`project.godot`、`.gitattributes`。
你的改动**只能**出现在 `assets/` 下（含 `assets/CREDITS.md`）。
```

---

## 主会话（控制器）收到分支后的合并流程

```bash
cd /e/Hali
git fetch origin
git log --oneline origin/plan-03-factions..origin/assets/cjk-and-ui-slices   # 只看新增提交
git show --stat origin/assets/cjk-and-ui-slices
# 核对：只动 assets/ 下文件、无 .import、无手工造的假文件
git merge --no-ff origin/assets/cjk-and-ui-slices
timeout 180 ./Godot_v4.7.2-stable_win64_console.exe --headless --path . --import   # 生成新 PNG/字体的 .import
git add assets/*/*.import assets/*/*/*.import 2>/dev/null
bash tools/test.sh                               # 必须仍是 EXIT=0 / 1746 断言
git commit -m "chore(assets): 生成新增素材的 .import（CJK 字体 + UI 切片）"
```

⚠️ 合并后**必须**复跑 `--import` 并把生成的 `.import` 提交，否则工作区会留下未跟踪文件、且工作区干净检查（HANDOFF §9）会失败。
