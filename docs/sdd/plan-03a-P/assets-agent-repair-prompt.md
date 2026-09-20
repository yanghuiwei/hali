# 素材 agent 修复提示词（**环境修复 + 继续**，整段复制）

> 背景：那个 agent 用 PowerShell 驱动 git 失败多次，随后**手工 `mkdir .git/refs/heads/assets` 造分支**，
> 导致 `assets/cjk-and-ui-slices` 的 worktree 引用悬空（`git worktree list` 显示 `0000000`、分支 ref 不存在、
> 在 `/e/hali-assets` 里 `git status` 会把**整个仓库**看成「全新未跟踪」）。
> 危险点：若它当时执行了 `git add -A` + commit，会在该分支上造出一个「把整个仓库当初始提交」的巨型 commit。
> **控制器已就地修复**（`git branch assets/cjk-and-ui-slices 05abb0d`，指向它实际检出的提交，**没有动它的工作树内容**）。
> 实测修复后：`git -C /e/hali-assets status --short` 只剩它自己的临时文件 ⇒ 它可以正常提交了。

```text
项目 E:/Hali（Godot 4.7.2 stable，Windows + Git Bash；仓库 https://github.com/yanghuiwei/hali.git，public）。

════════ 一、先看：主会话已经帮你修好了环境 ════════
你之前用 PowerShell 跑 git 失败了几次（`fatal: invalid reference: assets/cjk-and-ui-slices`），
随后手工 `mkdir` 了 `.git/refs/heads/assets` 来造分支。后果是 worktree 引用**悬空**：
  - `git worktree list` 显示 E:/hali-assets 的 HEAD 是 0000000、分支 ref 根本不存在
  - 在 /e/hali-assets 里 `git status` 会把**整个仓库**看成「全新未跟踪」（几百个 ??）
  - 如果那时你执行过 `git add -A` + `git commit`，会在该分支上造出一个「把整个仓库当初始提交」的巨型 commit

**主会话已就地修复**：`git branch assets/cjk-and-ui-slices 05abb0d`
（指向你实际检出的那个提交，**没有动你工作树里的任何内容**）。修复后那边 `git status` 只剩你自己的文件。

════════ 二、第一步：确认环境现在是对的（逐条跑，把输出贴出来） ════════
  cd /e/hali-assets
  git branch --show-current        # 期望：assets/cjk-and-ui-slices
  git log --oneline -1             # 期望：05abb0d feat(03a-P): P3 —— ThemeBuilder ...
  git status --short               # 期望：只看到你自己的文件（.dl/ 与几个 .ps_*.txt）

⚠️ 如果 `git status --short` 里出现成百上千个条目（例如 `?? src/`、`?? docs/`、`?? assets/audio/...`），
   **立刻停下**：不要 add、不要 commit、不要手工修 .git，把完整输出贴出来问主会话。

════════ 三、四条禁令（这次事故的根因，务必遵守） ════════
1. **不要用 PowerShell 跑 git**。用 Git Bash（`bash -lc '...'`）或 `cmd /c`。
   PowerShell 会把 git 正常的 stderr 输出当成 error record；更要命的是 `>` / `Out-File` 会加 **UTF-8 BOM**，
   把 BOM 写进 `.git/` 下的文件会直接弄坏引用（这正是这次坏掉的原因之一）。
2. **绝对不要手工创建或修改 `.git/` 下的任何文件**：不要 `mkdir refs/...`、不要写 HEAD、不要改 config。
   需要分支就用 `git branch` / `git switch -c`；命令失败就把**完整原始输出**贴出来问，不要再手工绕路。
3. **不要把临时文件/探针输出写进仓库**。一律写到 `/tmp`（Git Bash 下可用）或仓库外目录。
   你现在已经留下：`E:/Hali/.ps_probe.txt` `.ps_probe2.txt` `.ps_ref.txt` `.ps_setup.txt` `.ps_wt.txt`
   和 `/e/hali-assets/.ps_dl.txt` `.ps_env.txt` `.ps_npm.txt` `.ps_ofl.txt` `.ps_ofl2.txt` `.ps_pip.txt`。
   请清掉这些探针文件：
     rm -f /e/Hali/.ps_*.txt /e/hali-assets/.ps_*.txt
   （`.dl/` 是工作目录，留着或挪到 /tmp 随你，但**不要提交它**。）
4. `git add` **只写明确路径**，永远不要 `git add -A` / `git add .` / `git commit -a`
   （E:/Hali 主工作区里有别的并行工作，一次 `-A` 就会把它们全扫进来）。

════════ 四、第二步：继续任务（A/B/C 必做；D 已降级；E 本轮不做） ════════
完整要求在你 worktree 里的 `docs/sdd/plan-03a-P/assets-handoff-prompt-v2.md`。要点与**最新调整**：

A. **CJK 正文字体** → `assets/fonts/body_cjk.ttf`
   你已经下载了 `LXGWWenKai-Regular.ttf`（25,575,676 字节，sha256 `39AD71264B588165B469E35E6AFB162A378DACD1F95348160240BA9038AC3009`），很好。
   ✅ **覆盖自检取消**：你的 pip 走不通代理（`files.pythonhosted.org` ReadTimeout），**不要再折腾 pip / fontTools**。
   改为：把字体放到位，报告里给 **sha256 + 字节数 + 来源 URL + 版本号** 即可。
   覆盖自检（`你/魔/法` 等字形是否齐全）**由主会话在合并后用 Godot 的 `FontFile.has_char()` 自己做** ——
   那比 fontTools 更权威（就是真正渲染它的引擎），而且不需要你在环境上花钱。
   体积 25.6MB **可以接受**（全字集、不子集化是硬要求），**不用 Git LFS**。

B. **OFL 许可证文本** → `assets/fonts/`
   你已经抓到了 `OFL-Cinzel.txt` / `OFL-MedievalSharp.txt` / `OFL-IMFellEnglish.txt`，还做了完整性校验
   （header/perm/term/disc 全 True），很好。按 v2 的命名放进去：`OFL-Cinzel.txt`、`OFL-MedievalSharp.txt`、
   `OFL-IMFellEnglish.txt`，另加一份 LXGW 的许可证 `OFL-LXGWWenKai.txt`（你抓到的 alt 版即可）。
   报告里逐个给「文件名 → 来源 URL → 字节数」。

C. **`interface.psd` 切片** → `assets/ui/*.png`
   文件名严格按 v2 的清单（`panel_bg.png` / `button_normal|hover|pressed.png` / `scrollbar_bg|grab.png` /
   `checkbox_on|off.png` / `logo.png`；PSD 里有的才切）。
   优先用你已经装好的工具；`pip install psd-tools` 若因代理失败，就换 npm 侧的等价库（你能装 npm 包，这条路通）。
   **装不上任何工具 → 如实报告「切不了」**并把你已经拿到的图层信息贴出来，**不要硬猜**。

D.（**已降级，可选**）图标语义核定：**只有当你的工具真的能看图时才做**
   （例如先用 `resvg-js` 把 SVG 渲染成 PNG，再由能读图的你自己描述）。
   若看不到图就**直接跳过 D**，不要在报告里编描述。

E. **本轮不做**（不要去找新的背景/徽记/立绘素材）。专注 A/B/C/D。

════════ 五、第三步：交付 ════════
- 一个 commit（`git add` 写明确路径），push 到 origin 的 `assets/cjk-and-ui-slices`：
    git add assets/fonts/body_cjk.ttf assets/fonts/OFL-*.txt assets/ui/*.png assets/CREDITS.md
    git commit -m "assets: CJK 正文字体 + OFL 许可证文本 + interface.psd 切片（03a-P P3/P5 前置）"
    git push origin assets/cjk-and-ui-slices
  ⚠️ 若 `assets/ui/*.png` 一个都没切出来，就别写那条 glob。
- 报告 ≤80 行：
  1. 三个环境确认命令的输出（见第二节）
  2. commit 哈希 + `git show --stat`
  3. A：文件名 / sha256 / 字节数 / 来源 URL / 版本号
  4. B：4 个 `OFL-*.txt` → 来源 URL → 字节数
  5. C：文件清单 + 每个的尺寸 + 是否含 alpha + 建议九宫格边距 + 来源图层（或「切不了」的原因）
  6. D 做没做（做了就给 15 条一句话描述；没做就写「跳过」）
  7. `assets/CREDITS.md` 改动摘要 + 未完成项

════════ 六、边界（不変） ════════
✅ 你**只能**创建/修改 `assets/` 下的文件（含 `assets/CREDITS.md`）。
⛔ 不要动 `src/` `tests/` `data/` `tools/` `docs/` `project.godot` `.gitattributes`；不要动 E:/Hali 里的任何文件。
⛔ 不要运行 Godot（会与主会话的 headless 实例争 `.godot/` 导入缓存）；`.import` 由主会话统一生成。
```

---

## 主会话（控制器）合并时的校验（与 v2 相同，已实测可用）

```bash
cd /e/Hali
git fetch origin
git log --oneline origin/plan-03-factions..origin/assets/cjk-and-ui-slices
git diff --name-only origin/plan-03-factions..origin/assets/cjk-and-ui-slices | grep -v '^assets/' \
  && echo "⚠️ 有 assets/ 之外的改动，拒绝合并" || echo "✅ 只动 assets/"
git merge --no-ff origin/assets/cjk-and-ui-slices
timeout 180 ./Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
git add assets/**/*.import 2>/dev/null || true
bash tools/test.sh          # EXIT=0 / 20+ 套件 / SCRIPT ERROR==2 且 ERROR==7
```

合并后控制器补的两件事（**都是零代码**）：
1. 用 Godot 的 `FontFile.has_char()` 做字体覆盖自检（代替被代理挡住的 fontTools）
2. 在 `data/presentation.json` 加 `fonts.body` → `res://assets/fonts/body_cjk.ttf`，以及切片到场后的 `ui.*` 行
