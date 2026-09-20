# 03a-P P1+P2 实现报告（worker）

- BASE: `3e79940` ｜ 提交: **`cc9eb15`** ｜ 分支 `plan-03-factions` ｜ **未 push**（按快跑模式由控制器统一推）
- 交付：`data/presentation.json`、`data/audio_cues.json`、`src/ui/presentation.gd`（+ `.uid`）、
  `tests/presentation_test.gd`（+ `.uid`）、`tests/run_tests.gd`（SUITES 追加 1 行）

## 1. 绿步（原始输出）

```
cc9eb15  7 files changed, 584 insertions(+)      # 无删除、未触碰任何既有源码
[harness]=8  [registry]=244  [money]=18  [magic_level]=48  [model]=49  [clock]=47
[world_tick]=189  [creation]=188  [spell]=229  [gm]=128  [panel]=102  [selfcheck]=32
[save]=112  [async_probe]=2  [llm]=106  [prompt]=38  [debug_mirror]=23  [factions]=204
[presentation]=81        ← 新增（全部失败=0）
==== 总计失败=0，失败套件=0 ====   ALL TESTS PASSED    全部通过。
```

- `bash tools/test.sh` → **EXIT=0**（4 步全过：导入 / 单测 / 默认冒烟 / 调试镜像冒烟）
- **18 套件 / 1767 断言 → 19 套件 / 1848 断言**（`+81`，其余 18 个套件**一条都没动**）
- `SCRIPT ERROR` = **2 条**（= 基线，`save` 的坏档负例）
- `ERROR:` 行 = **7 条 = 基线逐字相同**（见 §4 的通道缺口；我实现里零新增噪音）
- `git status --porcelain`：提交后**干净**；无残留 godot 进程

## 2. `bgm_by_era` / `bgm_by_location` 的映射选择（内容决策，人类可直接改一行）

只有 4 首真 BGM，所以**全部按一条可审计的规则**分配，而不是逐键随手编：

| 用途 | 音轨 | 依据 |
| --- | --- | --- |
| 黑暗/危险/动荡 | `bg_dark_winds.ogg`（128s，暗色管弦） | 紧张感 |
| 户外/日常/家宅 | `bg_woodland_fantasy.ogg`（150s，林地） | 轻快 |
| 学院主调/主场 | `bg_main.ogg`（212s，主题曲） | 最有辨识度 ⇒ 留给霍格沃茨与自定义时代 |
| 中性/事务/其余 | `bg_fantasy_theme.ogg`（98s，CC0 短主题） | 最短 ⇒ 当默认底 |

- **`bgm_by_era` 8/8 全覆盖**：`witch_hunts`/`grindelwald`/`first_wizarding_war`/`second_wizarding_war` → dark_winds；
  `hogwarts_founding`/`reconstruction` → fantasy_theme；`modern` → woodland；`custom` → bg_main
- **`bgm_by_location` 21/21 全覆盖**：
  - dark_winds：`knockturn_alley`·`forbidden_forest`·`chamber_of_secrets`·`gringotts_deep_vaults`·`azkaban`·`malfoy_manor`·`grimmauld_place`
  - woodland：`diagon_alley`·`hogsmeade`·`godrics_gollow`·`spinners_end`·`the_burrow`
  - bg_main：`hogwarts`·`room_of_requirement`
  - fantasy_theme：`london_muggle`·`ministry_of_magic`·`st_mungos`·`gringotts`·`beauxbatons`·`durmstrang`·`ilvermorny`
- `cues` 留 `{}`：**sfx 一个素材都没有**，按 spec「表里没有的 cue = 静音」，**不往清单里写不存在的路径**
  （这是刻意的：清单只登记真实存在的文件 ⇒ 与 CREDITS 的对账才是硬断言）。

## 3. `fonts.title` / `fonts.numbers` 的选择与理由

| 键 | 值 | 理由 |
| --- | --- | --- |
| `fonts.title` | `fonts/Cinzel-Variable.ttf`，size 28 | 拉丁标题字，OFL-1.1 可商用；spec §8.1 把它列为拉丁标题候选 |
| `fonts.numbers` | `fonts/IMFeENrm28P.ttf`，size 15 | IM Fell English 的**旧式数字**贴合「魔法纪元」年代感，且与标题同为 OFL |
| `fonts.body` | **不写** | CJK 正文字体尚未入场（spec §8.5 的硬缺口）；写入不存在的路径会让「与 CREDITS 对账」失去意义 |
| `ui` / `emblems` / `backdrops` / `portraits` | **不写** | 无素材；缺命名空间合法（spec §2 接口冻结允许） |
| HarryP | **不在清单引用**（`MedievalSharp.ttf` 与 `HARRYP__.TTF` 都未引用） | 粉丝字体、模仿官方 Logo、IP 风险 ⇒ 仅保留在 `assets/CREDITS.md` 登记。MedievalSharp 留作备选标题字 |

`palette` 给了 7 键：`text`/`muted`/`accent`/`background`/`panel_bg`（8 位带 alpha `#1c1a17cc`）/`danger`/`success`。
前 4 个取自 spec §2 示例；`muted`/`success` 是状态行与面板需要的语义色（不加这两个，P3 就得在代码里写颜色常量，违反 spec 约定 3）。

## 4. 破坏实验（2 组；cp 备份 + cp 还原 + `md5sum -c`，未用 `git checkout --`）

**S1 `has()` 恒真**（把两条 `return not …is_empty()` 改成 `return true`）：
```
[presentation] 值为**空字符串**的条目 ⇒ has() 为假（不是「键存在即为真」）: 期望为假
[presentation] 值为**空对象**的条目 ⇒ has() 为假: 期望为假
[presentation] 断言=81 失败=2      ← 恰好 2 红
```
> ⚠️ **第一版 S1 是 0 红**，这是本次最有价值的发现：**我自己测试有覆盖缺口**——
> 缺失键走的是 `has()` 最后那行 `return false`，而被我改掉的两条 `return` 分支（值为**空字符串** /
> **空对象**）**根本没有任何断言覆盖**。补了 5 条断言（空字符串值 / 空对象值 / 对应 `entry()` `path()` /
> 「对象条目没有任何路径字段 ⇒ path() 空串」）之后重做，才恰好 2 红。
> 教训与台账里 Task 12 的 D3a 同源：**破坏实验不做，就不知道断言是不是承重**。

**S2 拆掉 scheme 守卫 + `ResourceLoader.exists` 前置守卫**（即「自然写法」）：
```
[presentation] 断言=81 失败=0            ← 套件**全绿，套件内抓不到**
ERROR 行 = 12（基线 7）                  ← 唯一判别通道是外部 stderr 计数
  新增样例: ERROR: Resource file not found: res:// (expected type: unknown)   ×4
            ERROR: Resource file not found: res://not-a-path ...             ×1
```
⇒ **「零 stderr 噪音」这条规则在套件内不可判别**，而且现有的 `SCRIPT ERROR == 2` 门禁**也抓不到它**
（这些是 `ERROR:` 不是 `SCRIPT ERROR:`）。已登记为通道缺口（见 §5 残余 #1）。

## 5. 残余 / 偏离

1. **通道缺口（建议控制器处置）**：`tools/test.sh` 只反向断言了 `[HALI]` 不出现，**没有 stderr 噪音基线**。
   实测基线本来就有 **7 条 `ERROR:`**（其中 4 条是 `Parse JSON failed`，来自 `save_codec` 的坏档负例；
   2 条是 `gm_test` 故意的 `submit() 不能驱动协程 GM`）。建议加一条「`ERROR:` 条数 == 基线」的门禁
   （类似既有的 `SCRIPT ERROR == 2`）——**这是本轮唯一需要控制器决策的项**，我未改 `tools/`。
2. **CREDITS 对账的已知放松点**：`assets/CREDITS.md` 的 `icons/*.svg`（15 个）是 **glob 登记项**，
   所以 `icons/<任何>.svg` 都会被判为已登记（我已写成一条显式断言钉住该语义）。
   若将来要**逐文件**审计图标，需把该行拆成 15 行 —— 属素材台账变更，不在本任务。
3. **`has()` 语义**（已在代码注释里写明）：= 「键存在且值非空」，**不是**「能加载成资源」；
   可加载性由 `font()/texture()` 回退成 `null` 表达。所以 `fonts.x = "not-a-path"` 的 `has()` 为真、
   `font()` 为 `null`——这是刻意的（`has()` 无法区分「颜色串」与「坏路径串」，那要按命名空间才知道）。
4. **偏离 spec §8.3 决策表第 2 行**（"`presentation_test` 的「未配置 CJK 即失败」断言照原计划加"）：
   按**本次 dispatch 的明确指示**改成「条件式硬断言」——`fonts.body` 未配置时不阻断；
   一旦配置了文件，则必须 `ResourceLoader.exists` 且 `has_char('你')`。
   理由：P1/P2 必须在字体入场前就能全绿；且「钉在字体到场之后」同样能保证不会静默豆腐块。
   **若控制器更想要「未配置即红」的强约束**，改 2 行即可（我可以补做）。
5. `fonts.numbers` 目前**没有消费方**（P3 才会用 `size_of`），属预留；`MedievalSharp.ttf` 亦未被引用（备选）。
6. 未做：`icon_map`（语义映射，spec §2 冻结条明确「P1 不建」）、P3/P4/P5 的任何接线、`main.gd`、`project.godot`。
7. 运行时实测（本报告依据）：`JSON.parse_string` 遇畸形输入会打 `ERROR: Parse JSON failed…`；
   `JSON.new().parse` 只返回错误码 43；`load()` 打不存在/无导入器路径会打 `ERROR: Resource file not found…`；
   `String.match` 的 glob 可用于 CREDITS 对账；`ResourceLoader.exists("res://assets/ui/interface.psd") == false`。
