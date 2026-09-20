# 计划 03a-P · 表现层与素材接线 设计（Draft Spec · 待评审）

> 状态：**草稿，待人类评审**（人类正在整理字体/美术/声音素材；本文件是他与代码之间的**契约**）
> 日期：2026-09-20 ｜ 依据：计划 03a Task 1–11 已交付（纯逻辑 + 文本面板），仓库当前**零表现层代码**
> 目标读者：素材提供者（人类）+ 零上下文的实现者
> 结论先行：**「加素材 = 放文件 + 改一行 JSON」，永不改代码；缺素材永远不崩；每条表现层规则都有 headless 断言兜底。**

---

## 0. 现状审计（2026-09-20 实测）

| 项 | 现状 | 对素材是否友好 |
| --- | --- | --- |
| `assets/` 目录 | **不存在** | 需新建（本计划第 1 个任务） |
| `.gitattributes` | **已有** `*.png/*.jpg/*.ogg/*.ttf binary` 规则 | ✅ 已预留二进制位，不必改 |
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
| P1 | 目录骨架 + 两张清单表 + Registry 注册与校验（含 `assets/credits.md` 模板） | 可加载的空清单；`validate` 通过 |
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
