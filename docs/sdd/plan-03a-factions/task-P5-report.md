# 03a-P P5 报告（收紧范围版）—— 素材槽位的解析与回退

- **BASE**: `e21b747` ｜ **提交**: `c79996b`（7 files, +414，无删除）
- 范围：按人类约束，素材（UI 切片 / 背景 / 徽记 / 立绘）**尚未到场** ⇒ 只做「解析 + 回退 + 不返工」，
  **不**把 `ui.panel_bg` / `button_*` 的九宫格套到布局上，**不**包裹或重排任何现有容器。
- 未 push（按约束）。

## 1. 改动

| 文件 | 内容 |
| --- | --- |
| `src/ui/asset_slots.gd`（新） | `texture_for` / `apply_to` / `patch_insets` / `stylebox_for` / `backdrop_key` / `house_emblem_key` / `any_visible` |
| `src/ui/main.gd` | 4 个槽位（背景 / 标题 Logo / 学院徽记 / 玩家立绘）+ `_refresh_slots()` |
| `tests/asset_slots_test.gd`（新） | 59 断言（含点号键解析契约、九宫格顺序、回退） |
| `tests/run_tests.gd` | 追加进 `SUITES` |
| `tools/b1_acceptance.gd` | 清单 13：槽位不可见/不占位/不崩 + 反返工断言（+20 断言） |

## 2. 门禁（三条关键行）

```
bash tools/test.sh            → EXIT=0
  [presentation] 断言=81 失败=0   [theme_audio] 断言=76 失败=0   [asset_slots] 断言=59 失败=0
  ==== 总计失败=0，失败套件=0 ====   ALL TESTS PASSED ／ 全部通过。
  套件 20 → 21；断言 1924 → 1983（+59）；SCRIPT ERROR=2、^ERROR:=7（噪音门禁通过）

timeout 300 bash tools/b1_acceptance.sh  → EXIT=0
  B1 自动验收最终：断言 151 条，失败 0 条（131 → 151，清单 13 新增 20 条）

git status --short           → 只有 5 个**外来**文件（见 §6），我自己的改动全部入库
```

## 3. 破坏实验（1 组）

破坏：`apply_to` 改成无条件 `rect.visible = true`（缺素材也占位）
→ `[asset_slots]` **恰好 4 条红**、`test.sh EXIT=1`、**无套件中止**（红得干净）：

```
[asset_slots] 键不存在 ⇒ 槽位不可见（不占位）: 期望为假
[asset_slots] ui.logo 缺失 ⇒ 不可见（这就是「素材没到也不返工」的机制）: 期望为假
[asset_slots] presentation 为 null ⇒ 不可见: 期望为假
[asset_slots] ⇒ 槽位不可见（不占位）: 期望为假
```

还原：`cp` 备份 → `cp` 还原 → `md5sum -c` = `OK`（**未用** `git checkout --`）；实验后 `tasklist | grep -i godot` 无残留。
复绿：`test.sh EXIT=0`、`[asset_slots] 59/0`、噪音 2/7。

## 4. `nine_patch` 四元素顺序的确认依据

- **权威来源**：`src/ui/presentation.gd:165` 的冻结契约注释 —— **上/右/下/左**（CSS `border-image-slice` 同款顺时针）。
  spec §2 的示例是 `[12,12,12,12]`（对称值），**无法**用它判定顺序。
- **我采用的映射**（全项目只此一处翻译，写在 `asset_slots.gd` 头注）：
  清单 `[上, 右, 下, 左]` → Godot `left=arr[3]`, `top=arr[0]`, `right=arr[1]`, `bottom=arr[2]`。
- **钉住方式**：用**非对称**数据 `[1,2,3,4]` 断言
  `patch_insets == Vector4i(4,1,2,3)` 且 `StyleBoxTexture` 的四个 margin 逐个等于 4/1/2/3。
  ⇒ 将来若有人把左右/上下写反，断言必红（对称值测不出来）。
- ⚠️ **与任务书口径的冲突（需控制器确认）**：任务书写 `[左,上,右,下]`，而仓库内冻结的
  `presentation.gd:165` 写 `上/右/下/左`。我**只能选一个**（两者都以同一个 4 元数组编码），
  最终选了**仓库内已有的冻结契约**（改它等于改 `Presentation` 的契约，且会造成文档漂移）。
  ⇒ 控制器写 `ui.*` 清单行时必须按 **上/右/下/左** 给值（或先由控制器统一改两处口径）。

## 5. ⚠️ 实测发现的契约缺陷（本任务最重要的副产品）

`Presentation.resolve()` 是**逐层下钻嵌套字典**：`a.b.c` → `manifest["a"]["b"]["c"]`。
但 **spec §2 的示例**里 `emblems` / `backdrops` / `portraits` 用的是**字面点号键**：

```json
"emblems":  {"faction.ministry": "res://assets/emblems/faction_ministry.png"},
"portraits":{"player.default": "res://assets/portraits/player_default.png"}
```

实测（一次性探针，跑完即删）：

```
字面点号键（spec §2 示例写法） resolve = <null>          ← 永远取不到值
嵌套写法                        resolve = res://assets/icons/castle.svg
```

⇒ 这不是我夹具写错，是**示例本身错了**：照示例加行 = 加了一个**永远不生效的旋钮**
（`§8#16/#21` 同类）。而且 `tests/presentation_test.gd` 对 `resolve` / 点号规则**零断言**，
所以 P1+P2 审查也没抓到这个。

**我的处置**（不改 `Presentation`、不改 docs）：
- 在 `tests/asset_slots_test.gd` 新增 `_test_key_resolution_contract`，把**两种写法的实际行为都钉住**
  （嵌套能解析 / 字面点号键取不到），并断言 `AssetSlots.house_emblem_key()`、`backdrop_key()`
  生成的键**在嵌套清单下真的命中** ⇒ 这是该缺陷的回归护栏。
- **留给控制器**：改 spec §2 的 `emblems` / `backdrops` / `portraits` 三处示例为嵌套形式
  （`{"emblems": {"house": {"gryffindor": "…"}}}`），并考虑在 `presentation_test` 补一条点号规则断言。
  ⚠️ 在改之前，控制器给 `presentation.json` 加这三类行时必须**手工写成嵌套**。

## 6. 残余与未验证项

1. **外来文件**：仓库根有 5 个 `.ps_*.txt`（另一个 agent 的 PowerShell 探针输出），
   我**没有**删/没有 add/没有提交；它们让 `git status` 不干净，但不是本任务的责任。
2. **`ui.panel_bg` / `button_*` 的九宫格套用未做**（有意）：`stylebox_for` 已实现并被断言覆盖，
   切片到场后只需加清单行——但**「套到哪个容器上」的布局决策**要等真实切片尺寸，否则会返工。
3. **`TextureRect` 的期望尺寸**（Logo 48 高、立绘 144 高、徽记 32×32）是我给的**占位尺寸**，
   真实素材到场后可能要调；因为它们只在槽位可见时生效，调整不影响「素材缺失前的布局」。
4. **背景槽的层级**：`backdrop_rect` 在根节点下先于 `root_box` 入树 ⇒ 画在底层。
   未验证「素材到场后是否会被 `root_box` 的不透明 StyleBox 完全盖住」——属素材到场后的视觉验收。
5. 未做真机/像素级视觉验收（属 B1 人工点击与 B2 范畴）。
