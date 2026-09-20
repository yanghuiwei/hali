# 计划 03a-P · 表现层与素材接线 设计（Draft Spec · 待评审）

> 状态：**已评审 · 首批素材已落位**（§8.3 的 8 条决策已于 2026-09-20 拍板并执行，落位记录见 §8.4；剩余缺口见 §8.5）。本文件是人类与代码之间的**契约**。
> 日期：2026-09-20 ｜ 依据：计划 03a Task 1–11 已交付（纯逻辑 + 文本面板），仓库当前**零表现层代码**
> 目标读者：素材提供者（人类）+ 零上下文的实现者
> 结论先行：**「加素材 = 放文件 + 改一行 JSON」，永不改代码；缺素材永远不崩；每条表现层规则都有 headless 断言兜底。**

---

## 0. 现状审计（2026-09-20 实测）

| 项 | 现状 | 对素材是否友好 |
| --- | --- | --- |
| `assets/` 目录 | **已存在**（首批素材已入库 `d67bbb1`，见 §8.4） | ✅ 只剩「清单 + 校验」（P1） |
| `.gitattributes` | 已补 `*.jpeg/*.mp3/*.wav/*.otf/*.psd/*.zip/*.svg binary` | ✅ 已做完，不必再改 |
| `project.godot` | 无 `theme` / `icon` / `font` / `boot_splash` / 音频配置 | 需加 1 行主题（本计划第 3 个任务） |
| `grep -rn "Theme\|FontFile\|AudioStream\|TextureRect\|ColorRect\|res://assets" src/ tools/` | **零命中** | 需新建 theme/asset/audio 三个小模块 |
| UI 构建方式 | 全部在 `src/ui/main.gd` 里用代码建 `VBox/HBox/Label/RichTextLabel/LineEdit/OptionButton/SpinBox/Button` | ✅ **挂一个 `Theme` 即整体生效**，不需要重做场景 |
| 面板内容 | `src/ui/panel_formatter.gd` 产出**纯文本**（`《…》`/`【…】` 契约，有 102 条断言） | ✅ 图标化可后续用 BBCode/前缀映射增量做，不必重写 |
| 内容表 | 全在 `data/*.json`（17 张表） | ✅ 新增 `data/presentation.json` / `data/audio_cues.json` 顺理成章 |

**唯一"必须先解决"的硬问题（不是可选美化）**：Godot 4 的内置默认字体是 **Open Sans 子集，不含中日韩字形**（官方 UI 字体文档；第三方分析称仅约 1010 个码点）。本游戏**全部玩家可见文本是中文** ⇒ 当前窗口在缺字体时很可能整屏豆腐块；Windows 上靠"系统字体回退"可能侥幸显示，但**导出到他人机器/其它平台不可靠**。⇒ **CJK 字体是"能不能读"的前提**，应作为本计划第 1 优先项。
**已实测（2026-09-20，一次性探针，跑完即删）**：

```
CJK-PROBE class=FontFile      ← ThemeDB.fallback_font
CJK-PROBE U+4F60 has_char=false   （你）   CJK-PROBE U+9B54 has_char=false   （魔）
CJK-PROBE U+6CD5 has_char=false   （法）   CJK-PROBE U+0041 has_char=true    （A）
CJK-PROBE U+3042 has_char=false   （あ）   CJK-PROBE U+D55C has_char=false  （한）
```

⇒ **内置字体确实不含中文/日文/韩文字形**（拉丁字母有）。
⚠️ 两点细化：① Godot 4 在**渲染期**还会尝试**系统字体回退**（官方文档），所以 Windows 上未必立刻看到豆腐块——但那是**平台相关**行为，导出到其它机器、或系统无对应字体时即失效；② 因此本游戏（玩家可见文本 100% 中文）**必须自带 CJK 字体**，这是 P3 的验收前提。
建议把这条也做成**可持续的断言**（`tests/presentation_test.gd`：若 `data/presentation.json` 未配置 CJK 字体，则该测试**失败**并提示「中文界面需要自带字体」——把"能不能读"钉进 CI，而不是靠肉眼）。

## 1. 素材目录约定（人类放文件的地方）

```
assets/
  fonts/        正文/标题字体（TTF/OTF），如 serif_body.ttf、display_title.ttf
  ui/           界面贴图：panel_bg.png、button_normal.png、scrollbar.png、logo.png …
  emblems/      徽记：faction_<faction_id>.png、house_<house_id>.png
  backdrops/    背景/插画：era_<era_id>.png、location_<location_id>.png
  portraits/    立绘：player_default.png、npc_<npc_id>.png（NPC id 属计划 05）
  audio/
    bgm/        时代/场景循环音乐（OGG）
    sfx/        短音效（WAV/OGG）：turn_submit、turn_done、audit_start、level_up …
    ambient/    环境音（雨声、城堡走廊…）
  credits.md    素材来源与授权（**必须**，public 仓库）
```

* **全部可选**：缺任何一个文件，游戏必须照常运行（回退到默认主题/无图/静音）。
* 命名建议：**逻辑键 = 文件名（小写下划线）**，与 `data/*.json` 的 id 对齐（`faction_ministry.png` ↔ `ministry`）。

## 2. 清单契约：`data/presentation.json`（内容进 data 的铁律）

一个**扁平**的「逻辑键 → 素材条目」表；键名稳定，路径可随时换（换素材只改这一行）。

```json
{
  "fonts": {
    "body":    {"path": "res://assets/fonts/serif_body.ttf",  "size": 16, "fallbacks": []},
    "title":   {"path": "res://assets/fonts/display_title.ttf", "size": 28},
    "numbers": {"path": "res://assets/fonts/mono_digits.ttf",  "size": 15}
  },
  "ui": {
    "panel_bg":     {"path": "res://assets/ui/panel_bg.png", "nine_patch": [12,12,12,12]},
    "button_normal":{"path": "res://assets/ui/button_normal.png"},
    "logo":         {"path": "res://assets/ui/logo.png"}
  },
  "emblems":  {"faction.ministry": "res://assets/emblems/faction_ministry.png"},
  "backdrops":{"era.modern": "res://assets/backdrops/era_modern.png"},
  "portraits":{"player.default": "res://assets/portraits/player_default.png"},
  "palette":  {"text": "#e8e2d0", "accent": "#c8a24a", "panel_bg": "#1c1a17cc", "danger": "#b04a3a"}
}
```

约定：
1. **路径缺失/为空/文件不存在 ⇒ 回退**（`body` 缺失 → Godot 默认字体；`palette` 缺失 → 内置配色；贴图缺失 → 不画）。
2. 键的**命名空间点号**（`faction.ministry`）让「内容 id」与「素材键」自动对齐，不必逐个写代码分支。
3. `palette` 是**唯一**允许把"颜色"写进配置的地方——所有 `StyleBoxFlat`/字体色都从它取，代码里不许出现魔法颜色常量。

> 🔒 **接口冻结（控制器裁定，2026-09-20）——P1–P5 一律照此实现，不得改形状。**
>
> 1. **`data/presentation.json` / `data/audio_cues.json` 不注册进 `Registry.TABLE_FILES`。**
>    依据（实测读码 `src/core/registry.gd`）：`Registry` 的契约是「**Array of `{id,label}`**，且每表非空」——
>    `from_tables()`（`:28-42`）对**非数组**表直接 `continue` ⇒ 该表在 `_tables` 里不存在 ⇒
>    `validate()`（`:75-82`）报「缺少数据表」，`load_default()`（`:45-52`）也把非数组替成 `[]` ⇒ 报「数据表为空」。
>    本清单是**嵌套字典**，塞进去会当场把 `registry.validate()` 弄红、并污染 `registry_test` 的既有断言。
>    ⇒ 两张清单的加载与校验归**表现层**：`src/ui/presentation.gd`（安全加载/缓存/回退）+ `tests/presentation_test.gd`（形状 + 回退 + 与 CREDITS 对账）。
>    「内容进 `data/`」这条铁律**不受影响**：清单确实在 `data/` 下，只是它不是「内容表」。
> 2. 键名与嵌套层次按本节与 §3 的示例**逐字**实现：
>    顶层只有 `fonts` / `ui` / `emblems` / `backdrops` / `portraits` / `palette`；
>    `audio_cues.json` 顶层只有 `cues` / `bgm_by_era` / `bgm_by_location` / `master_volume`。
> 3. 点号命名空间：`faction.<faction_id>` / `house.<house_id>` / `era.<era_id>` / `location.<location_id>` / `player.default`。
> 4. 所有路径一律以 `res://assets/` 开头；**清单里出现的每条路径都必须能在 `assets/CREDITS.md` 总表里查到**
>    （缺失则 `presentation_test` 红）。

## 3. 音频线索表：`data/audio_cues.json`

```json
{
  "cues": {
    "turn_submit":      {"sfx": "res://assets/audio/sfx/turn_submit.ogg", "volume_db": -6},
    "turn_done":        {"sfx": "res://assets/audio/sfx/turn_done.ogg"},
    "audit_start":      {"sfx": "res://assets/audio/sfx/audit_start.ogg"},
    "audit_ack":        {"sfx": "res://assets/audio/sfx/audit_ack.ogg"},
    "save_ok":          {"sfx": "res://assets/audio/sfx/save_ok.ogg"},
    "load_ok":          {"sfx": "res://assets/audio/sfx/load_ok.ogg"},
    "faction_revealed": {"sfx": "res://assets/audio/sfx/reveal.ogg"},
    "llm_fallback":     {"sfx": "res://assets/audio/sfx/fallback.ogg"}
  },
  "bgm_by_era":     {"modern": "res://assets/audio/bgm/modern.ogg", "witch_hunts": "…"},
  "bgm_by_location":{"hogwarts": "…", "diagon_alley": "…"},
  "master_volume": 0.8
}
```

约定：cue 的**触发点**由代码固定（下表 §4），**素材映射**由这张表决定；表里没有的 cue = 静音；文件缺失 = 静音（不报错、不阻塞回合）。

> **实际已有的 BGM（2026-09-20 已入库，见 §8.4）**：`res://assets/audio/bgm/` 下 4 个真 OGG，
> `bg_main.ogg`（211.88s）· `bg_dark_winds.ogg`（128.25s）· `bg_fantasy_theme.ogg`（98.12s）· `bg_woodland_fantasy.ogg`（150.05s），
> 且 4 个 `.import` 已设 `loop=true`（实测 `AudioStreamOggVorbis.loop == true`）⇒ **P4 只要 `play()`**。
> `bgm_by_era` / `bgm_by_location` 可以直接填这四个；**sfx / ambient 目前无素材**（缺则静音，不阻塞）。

## 4. 代码 seam（只新增，不改逻辑）

| 新文件 | 职责 | 关键 API（草案） |
| --- | --- | --- |
| `src/ui/presentation.gd` | 读写 `data/presentation.json` + `data/audio_cues.json`，**安全加载 + 缓存 + 回退** | `load_default() -> Presentation`、`font(key) -> Font`、`texture(key) -> Texture2D`、`palette(name, fallback) -> Color`、`has(key) -> bool` |
| `src/ui/theme_builder.gd` | 用 `Presentation` 造一个 `Theme`（default_font/size、Button/Label/RichTextLabel/LineEdit/OptionButton 的 `StyleBoxFlat`、颜色） | `build(presentation) -> Theme` |
| `src/ui/audio_director.gd` | 按 `audio_cues` 播 SFX / 切 BGM，尊重 `master_volume`，缺素材静音 | `play_cue(id)`、`set_bgm(key)`、`stop_all()` |
| `src/ui/main.gd`（改） | ① `_ready` 里 `theme = ThemeBuilder.build(...)` 应用到 `root_box`；② 在既有触发点调 `AudioDirector.play_cue(...)`；③ 背景/Logo/徽记的**可选**插槽（`TextureRect`，缺图自动 `visible=false`） | — |
| `tests/presentation_test.gd`（新） | **headless 可测**：清单 schema/键唯一性/路径"存在或显式容忍"、回退行为、主题构建不崩、cue 映射完整、缺素材时 `has()` 为假且调用不报错 | 追加进 `tests/run_tests.gd` 的 `SUITES` |

**触发点（代码固定，不随素材变）**：`turn_submit`（提交后、等待前）、`turn_done`（渲染完成）、`audit_start`/`audit_ack`（第七十二章自检）、`save_ok`/`load_ok`（存档/读档）、`faction_revealed`（`WorldFactions.reveal()` 成功时）、`llm_fallback`（`LlmGameMaster._fallback()` 触发时，**与 `§8#61` 的 warnings 同源**）；BGM 在「开始人生 / 读档 / 换地点 / 时代变更」时切。

## 5. 与现有改动的兼容性（审计结论：**无阻塞**）

1. UI 全代码构建 ⇒ 挂 `Theme` 即整体生效，不需要重做 `.tscn`。
2. 面板是文本契约（102 条断言钉住格式）⇒ 图标/配色走**增量**（BBCode 前缀映射、`TextureRect` 插槽），**不重写 `PanelFormatter`**。
3. `data/*.json` 是唯一内容入口 ⇒ 两张新表零冲突。
4. `.gitattributes` 已有 png/jpg/ogg/ttf 二进制规则 ⇒ 不必改。
5. 测试文化（1711+ 断言、`tools/test.sh` 4 步、B1 验收探针 105 断言）⇒ 表现层必须**可 headless 断言**，否则无法回归；本计划把「缺素材回退」做成断言，保证你随时加文件都不会打破绿灯。

## 6. 任务草案（5 个任务，插在 Task 12 之后、Task 13 收尾之前）

| # | 任务 | 交付 |
| --- | --- | --- |
| P1 | ~~目录骨架~~（**已落位**，见 §8.4）+ 两张清单表（**不注册进 Registry**，见 §2 接口冻结）+ `Presentation` 加载 + 校验（CREDITS 已建） | 可加载的清单；清单形状断言通过；**清单里每条路径都能在 `assets/CREDITS.md` 查到** |
| P2 | `Presentation`（安全加载/缓存/回退）+ `presentation_test`（含"缺文件必须优雅回退"的断言） | 无素材也全绿 |
| P3 | `ThemeBuilder` + `main.gd` 应用主题 + `project.godot` 设默认主题（**含 CJK 字体**） | 中文字面可读、配色统一 |
| P4 | `AudioDirector` + 8 个 cue 触发点接线 + BGM 切换 + 音量 | 有素材就有声、无素材静音 |
| P5 | 插槽：背景/Logo/徽记（派系、学院）/立绘（玩家）+ B1 探针补「素材缺失不崩」断言 | 素材可视化落地 |

（**若素材先到**，P1–P3 可提到 Task 12 之前先做：文件重叠几乎为零。）

## 7. 待人类回答（决定 manifest 形状，越早定越不返工）

1. **字体**：TTF 还是 OTF？几套（正文/标题/数字）？是否含繁体与生僻字（`你/祢/甯` 这类）？字号基准？
2. **图片**：PNG（带透明）？尺寸约定（建议：背景 1280×800、立绘 512×768、图标 64×64、徽记 128×128）？是否需要 9-slice 面板底与按钮三态（normal/hover/pressed）？
3. **音频**：OGG 还是 WAV？BGM 是否可无缝循环？SFX 时长上限？命名用中文/英文/拼音？
4. **命名策略**：用「逻辑键 = 文件名」（`faction_ministry.png`）还是你自己一套命名 + 我在 `presentation.json` 里写映射？
5. **要哪些槽位**：时代背景 / 学院徽记 / 派系徽记 / 地点插图 / 玩家立绘 / NPC 立绘（NPC id 属计划 05）/ UI 皮肤（面板底、按钮、滚动条、光标）/ 标题 Logo？——**列清单给我，我按清单定键名**。
6. **大文件**：>10MB 的音频/背景是否走 Git LFS（还是直接入库）？public 仓库要不要放素材（授权与体积）？
7. **授权与署名**：`assets/credits.md` 的必填字段（作者/来源/许可证/是否允许商用）？我会在清单校验里加一条「有素材条目则 credits 必须提到它」。

---

## 8. 素材实测盘点（2026-09-20，首批素材已入库）

> 首批素材已落位并提交（`d67bbb1`，53 files）：目录已改名为 **`assets/`**，音频统一 OGG 进 `assets/audio/bgm/`，
> 授权台账 `assets/CREDITS.md` 已建（由人类原有的 `asssets/README.md` 全量升级而来，无信息丢失）。
> **本节是「素材 → 代码」的实测事实，P1–P5 一律按 §8.4 写实现，不要凭 §1–§3 的示例路径猜。**

### 8.1 字体：**全部不含中文**（实测，Godot `FontFile.has_char()`）

```
FONT Cinzel-Variable.ttf   CJK=0/5  LATIN=1
FONT IMFeENrm28P.ttf       CJK=0/5  LATIN=1   （IM Fell English）
FONT MedievalSharp.ttf     CJK=0/5  LATIN=1
FONT HARRYP__.TTF          CJK=0/5  LATIN=1   （Harry P，dafont）
（另：Godot 内置 `ThemeDB.fallback_font` 对 你/魔/法 亦为 false）
```

⇒ 这 4 个字体**只能用于拉丁文标题/数字/Logo**（Cinzel / IM Fell English / MedievalSharp 都是 OFL-1.1 可商用 ✓；Harry P 是粉丝字体，`100% Free · 个人免费，商用需授权`，且模仿 HP 官方 Logo 字体，public 仓库有 IP 风险 ⚠️）。
⇒ **缺一个覆盖中文的正文字体**（这是当前唯一"没它就没法读"的缺口）。候选（OFL/可商用）：Noto Sans SC、Source Han Sans（思源黑体）、LXGW WenKai（霞鹜文楷）、思源宋体。

### 8.2 其余素材清单（已落盘）

| 类别 | 文件 | 体积 | 许可（人类 README） | 可用性判断 |
| --- | --- | --- | --- | --- |
| audio | `audio/bgm/bg_main.ogg` | 7.4MB | **未授权**（John Williams 电影原声） | ⚠️ 人类决定**保留入库**（个人非商用学习用）；版权声明见 `assets/CREDITS.md` §二 |
| audio | `audio/bgm/bg_dark_winds.ogg` | 2.0MB | CC-BY-SA 3.0 | ✅ 可作 BGM；⚠️ **SA 是 copyleft**，改编版须同样 SA（原样打包播放一般不触发，人类已接受条款） |
| audio | `audio/bgm/bg_woodland_fantasy.ogg` | 2.9MB | CC-BY 3.0（Matthew Pablo） | ✅ 已由 320kbps mp3 转 OGG（`libvorbis -q:a 5`） |
| audio | `audio/bgm/bg_fantasy_theme.ogg` | 2.0MB | CC0 | ✅ 已由 **17.3MB 未压缩 PCM** 转 OGG（-88%） |
| icons | `icons/*.svg` ×15 | ~20KB | CC-BY 3.0（game-icons.net） | ✅ **实测可导入**为 `CompressedTexture2D` **512×512**（ThorVG）；**CC-BY 必须署名** |
| fonts | `fonts/*.ttf` ×4 | 496KB | OFL-1.1 ×3 + HarryP | ✅ 仅覆盖拉丁；CJK 覆盖全为 0（见 §8.1） |
| ui | `ui/interface.psd` | 4.4MB | CC0 | ⚠️ **实测 Godot 无 PSD 导入器**（`ResourceLoader.exists()` = false）⇒ **惰性文件**，仅作切片源存档，不产生 `.import` |
| textures | `textures/runic_codex.png` | 39KB | CC0 | ✅ 448×384，可直接用作贴图 |
| — | ~~`fonts/harry_p.zip`~~ | ~~15KB~~ | 同 HarryP | ✅ **已删除**：与 `fonts/HarryP/HARRYP__.TTF` **md5 完全相同**（`181ef9a7aee45c119e68f294e8426a3a`） |

### 8.3 待决策 8 条的裁定结果（2026-09-20 人类拍板 + 执行）

| # | 事项 | 裁定 | 执行状态 |
| --- | --- | --- | --- |
| 1 | 目录改名 `asssets/` → `assets/` | ✅ **改名** | 人类手工改名；本 spec 及后续契约一律用 `assets/` |
| 2 | 补 CJK 正文字体（**必须**） | ⛔ **仍未提供** | 见 §8.5；`presentation_test` 的「未配置 CJK 即失败」断言**照原计划加** |
| 3 | 体积策略（转 OGG / 删 zip / LFS） | ✅ **选 A：音频全部 OGG** | 已执行：音频 32.4MB → 14.4MB，`assets/` 共 **19MB**；`harry_p.zip` 已删；**不上 Git LFS** |
| 4 | HarryP 字体是否进 public 仓库 | ⏳ **未拍板** | 当前**保留入库**（27KB）；`CREDITS.md` §一/§三 已记明「个人免费、商用需授权 + 粉丝字体模仿官方 Logo 的 IP 风险」，并写明不用于对外发布物主标题 |
| 5 | CC-BY-SA 音乐（DarkWinds） | ✅ **接受** | `CREDITS.md` §三 写明 SA 义务（仅原样播放不触发；若剪辑/混音则成片须 CC-BY-SA 分发） |
| 6 | `interface.psd` 切图 | ⏳ **未拍板**（控制器切 / 人类导出） | 本机**无** PIL / psd_tools / ImageMagick ⇒ 待定，见 §8.5 |
| 7 | credits 落位 + 清单校验 | ✅ **同意** | `assets/CREDITS.md` 已建（含机器可读总表）；`presentation_test` 增加「清单路径必须在 CREDITS 有登记」断言 |
| 8 | 图标语义映射草案 | ⏳ **未拍板** | 下面的草案保留为 P5 的**默认映射**，人类可随时改 |

**图标语义映射草案（P5 默认，未拍板）**：`castle`→霍格沃茨、`cauldron`/`round-potion`→魔药、`bolt-spell-cast`→施法、`lunar-wand`→魔杖、`book-cover`/`scroll-quill`→学业、`crown`→纯血/威森加摩、`dragon-orb`→黑暗势力、`floating-ghost`→幽灵/死亡、`barn-owl`→信件、`rune-stone`→如尼/古物、`tarot-01-the-magician`→预言、`wizard-face`→人物面板、`crystal-earrings`→首饰/财富。

### 8.4 首批素材落位执行记录（2026-09-20，提交 `d67bbb1`）

1. **音频最终形态**（`assets/audio/bgm/`，4 个全是**真 OGG Vorbis**，实测 `load()` 得 `AudioStreamOggVorbis`）：

   | 文件 | 时长 | 码率 | 来源 / 处理 |
   | --- | --- | --- | --- |
   | `bg_main.ogg` | 211.88s | 281kbps | 主题曲，人类自行转换；本次**未再编码**（见下方 ⚠️） |
   | `bg_dark_winds.ogg` | 128.25s | 128kbps | DarkWinds，原样改名归位 |
   | `bg_fantasy_theme.ogg` | 98.12s | 164kbps | ← `FantasyWav.wav`（44.1kHz，`libvorbis -q:a 5`） |
   | `bg_woodland_fantasy.ogg` | 150.05s | 157kbps | ← 320kbps mp3（保持 48kHz，`libvorbis -q:a 5`） |

2. **BGM 循环已在「导入层」设好**：4 个 `.ogg.import` 的 `loop=true`（Godot 默认 `false`），并已实测 `AudioStreamOggVorbis.loop == true`。
   ⇒ **P4 不必自己管循环，只要 `play()`**。这是「先落位再写代码」的典型收益：换到 P4 才发现不循环，就要回头改导入设置 + 重导。
3. **`.import` 文件必须入库**（本项目已定）：它们是 Godot 4 导入设置的载体（`loop`、`svg/scale`、字体参数都在里面），不提交则换机器后设置丢失。
   **实测**：提交后重跑 `--import`，`git status` **干净**（`.import` 稳定，不会造成脏工作区，不违反 HANDOFF §9 的「工作区必须干净」）。
4. **`.gitattributes` 已补**：`*.jpeg/*.mp3/*.wav/*.otf/*.psd/*.zip/*.svg` 一律 `binary`。
   SVG 虽是 XML 文本，但 game-icons.net 出品是**单行压缩**形式，按二进制处理可避免无意义 diff（已在文件里写明理由）。
5. **PSD 是惰性文件**：实测 `ResourceLoader.exists("res://assets/ui/interface.psd") == false` ⇒ 在 `assets/` 里只是**切片源存档**，不产生 `.import`、不影响导入耗时。（仍按 CC0 入库，人类已同意保留原始素材。）
6. **SVG 图标可用**：15 个 `.svg` 均导入为 `CompressedTexture2D` **512×512**。`.import` 里有 `svg/scale=1.0` 旋钮——**要别的尺寸改它，不要改 SVG 文件本身**。
7. **素材原件已备份到仓库外**：`E:/Hali-asset-originals/`（4 个音频原件 + 原 `README.md` + `harry_p.zip`）⇒ 转码与删除**都可逆**。
8. **字体导入参数含 `allow_system_fallback=true`**（Godot 4 默认）：Windows 上中文可能靠系统字体回退**侥幸**显示——这正是「不可依赖」的原因（换机器/换平台即失效）。CJK 字体仍必须自带。
9. ⚠️ **待人类确认的异常**：`bg_main.ogg` 时长 **211.88s**，而原始 mp3 是 **309.09s**（`ffprobe` 实测）——**少了 97 秒**。若不是有意剪辑，需重新转一次。
10. **`assets/CREDITS.md` 的结构**（P2 的校验器按此解析）：§一 是机器可读总表，列 `文件 | 类别 | 作者/来源 | 许可证 | 可否商用 | 署名要求`，
    其中「文件」列 = 相对 `res://assets/` 的路径（例：`audio/bgm/bg_main.ogg`）⇒ 校验器可直接用 `presentation.json` 里的路径去掉 `res://assets/` 前缀去查表。

### 8.5 仍缺的素材（阻塞 P3 / P5，**不阻塞** P1 / P2 / P4）

| 缺口 | 阻塞谁 | 说明 |
| --- | --- | --- |
| **CJK 正文字体** | **P3**（主题与字体） | 全中文界面「能不能读」的硬前提。两条路：① 人类给文件；② 控制器取 OFL 字体（霞鹜文楷 LXGW WenKai / Noto Serif SC）。⚠️ **不能子集化**——玩家可输入任意汉字、LLM 可产出任意文本 ⇒ 必须**全字集**（10–20MB），建议命名 `assets/fonts/body_cjk.ttf` |
| **`interface.psd` 切片 PNG** | **P5**（UI 皮肤插槽） | 本机无 PIL / psd_tools / ImageMagick。两条路：① 控制器 `pip install psd-tools` 自己切（需联网）；② 人类导出 PNG（面板底九宫格 / 按钮三态 / 滚动条） |
| 短音效 SFX、环境音 ambient | P4（**可选**） | `data/audio_cues.json` 的 cue 触发点已规划；缺素材 = 静音，可接受 |
