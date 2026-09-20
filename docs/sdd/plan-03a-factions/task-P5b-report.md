# 03a-P · B8（P5b）报告 —— 把 UI 切片接进主题

- BASE：`main@06913c1` ｜ 分支 `main` ｜ 快跑模式（1 组破坏实验、报告从简、**不 push**）
- 提交：见文末 `git show --stat`（**只提交不 push**）
- 范围声明：只接**有真实消费者**的键；`panel_bg` / `frame_*` / `emblem_ring` / `panel_slot` / `button_close` **有意不接**（见 §5）

---

## 1. 门禁（逐条关键行）

```
bash tools/test.sh                        → EXIT=0
[presentation] 断言=83 失败=0   [theme_audio] 断言=114 失败=0   [asset_slots] 断言=59 失败=0
==== 总计失败=0，失败套件=0 ====      ALL TESTS PASSED / 全部通过。
stderr 噪音门禁：SCRIPT ERROR=2   ^ERROR:=7      ← 与基线逐字相同（门禁未触发）
（[theme_audio] 76 → 114；全仓 1985 → 2023 断言）

timeout 300 bash tools/b1_acceptance.sh   → EXIT=0；B1 自动验收最终：断言 151 条，失败 0 条

git status --short                        → 只有本次改的 4 个文件 + 外来的 .workbuddy/（未 add、未删）
tasklist | grep -i godot                  → (none) 无残留进程
```

## 2. 破坏实验（1 组）

**D1：打掉「缺键 ⇒ 回退扁平」**（`_pick()` 的 else 分支由 `fallback` 改成 `StyleBoxTexture.new()`）：

```
[theme_audio] 断言=112 失败=7       影响套件=1，其余 20 套件不变，EXIT=1
  Button normal 是 StyleBoxFlat（来自 ThemeBuilder）        : 期望为真   ← 既有断言（P3）也一起红（交叉印证）
  Button hover 是 StyleBoxFlat（来自 ThemeBuilder）         : 期望为真   ← 同上
  只配 hover ⇒ normal 仍回退扁平（逐键独立）                 : 期望为真
  只配 hover ⇒ pressed 仍回退扁平                           : 期望为真
  只配 hover ⇒ disabled 仍回退扁平                          : 期望为真
  无 ui.* ⇒ Button 回退扁平                                 : 期望为真
  路径指向不存在的贴图 ⇒ 回退扁平（不崩）                     : 期望为真
stderr 噪音计数：SCRIPT ERROR=2 / ^ERROR:=7（破坏未引入噪音）
```

7 红全部是「缺键/坏路径 ⇒ 扁平回退」类断言，方向精准、无套件中止。
还原：`cp` 备份 + `cp` 还原 + `md5sum -c` = OK（**未用** `git checkout --`）；实验后无残留 godot 进程。

## 3. 九宫格边距：**逐件取值与理由**（全部来自实测，不是猜）

先量每张切片的**帽厚**（沿中行/中列从两端扫「alpha 变成持续不透明」的位置）：

| 切片 | 尺寸 | 中行 lCap/rCap | 中列 tCap/bCap | 不透明占比 |
| --- | --- | --- | --- | --- |
| `button_normal` / `button_hover` / `button_pressed` / `button_neutral` | 160×44 | 5 / 7 | 7 / 7 | 63% |
| `textfield` | 134×28 | 4 / 3 | 4 / 3 | 71% |
| `scrollbar_bg` | 36×134 | 3 / 3 | 4 / 3 | 76% |
| `scrollbar_grab` | 30×48 | **0 / 0** | **0 / 0** | 97% |
| `panel_bg` | 244×366 | 1 / 1 | 0 / 0 | 99%（且全行/全列**可拉伸**） |

**取值 = 实测帽厚 + 1（1px 抗锯齿余量）**，顺序 `[上,右,下,左]`（spec §2 约定 4）：

| 清单键 | 取值 | 理由 |
| --- | --- | --- |
| `ui.button_normal` / `button_hover` / `button_pressed` / `button_neutral` | `[8, 8, 8, 6]` | 上=7+1、右=7+1、下=7+1、左=5+1。160×44 减去 `8+8 / 8+6` 仍有 **144×28** 可拉伸中段；按钮横向伸缩时两侧圆角帽与上下边不变形 |
| `ui.textfield` | `[5, 4, 4, 5]` | 上=4+1、右=3+1、下=3+1、左=4+1。134×28 减 `5+5 / 4+3` 后中段 **124×13** |
| `ui.scrollbar_bg` | `[5, 4, 4, 4]` | 上=4+1、右=3+1、下=3+1、左=3+1。纵向长条：**上下帽保住**、中段纵向拉伸；横向 4+4=8 正好等于绘制宽度 ⇒ 帽**不被压缩** |
| `ui.scrollbar_grab` | **不写 `nine_patch`** | 实测帽厚 **0/0**（97% 不透明的平坦块）⇒ 没有需要固定的帽区，整张拉伸即可。**不写没有实测依据的数字** |

## 4. 两条「不改变现有布局」的实测证据（B8 的主要风险面）

1. **控件最小尺寸逐字不变**（扁平主题 vs 接上贴图后的主题，同字串同控件）：

   | 控件 | 扁平 | 贴图 | 差异 |
   | --- | --- | --- | --- |
   | `Button("开始人生")` | (72, 31) | (72, 31) | **(0, 0)** |
   | `Button("读取存档")` | (72, 31) | (72, 31) | **(0, 0)** |
   | `LineEdit("输入你的行动")` | (68.5, 31) | (68.5, 31) | **(0, 0)** |

   原因：贴图盒与扁平盒**共用** `ThemeBuilder.CONTENT_MARGIN_*`（8/4），且 Godot 的 `StyleBoxTexture.get_minimum_size()`
   在显式设了 content margin 时用的是 content margin（不是 texture margin）⇒ 换素材不会让文字/按钮尺寸跳一下。
2. **滚动条宽度无回归**：接上贴图后 `VScrollBar` 的合并最小尺寸 = **(8, 8)**；
   实测 **Godot 内置默认主题也是 (8, 8)** ⇒ 宽度由 `ScrollBar` 自身常量决定，与九宫格边距无关 ⇒ **本次接入不改变滚动条宽度**。

## 5. 有意**不接**的件（附原因）

| 切片 | 为什么不接 |
| --- | --- |
| `panel_bg`（244×366） | 是「整块面板」而不是九宫格底；要用它得给 `creation_box` / 日志区加 `PanelContainer` 包裹 =**新增布局分支**，会打掉 B1 的反返工断言（「槽位贡献的可见子节点 == 0」「可见子节点仍为 2」）⇒ 归 03b 界面改版 |
| `frame_horizontal` / `frame_vertical` | 同上，需要明确的落点（边框叠在哪个容器上） |
| `emblem_ring` / `panel_slot` | 需要设计落点（学院徽记环、物品格），本仓库当前没有对应控件 |
| `button_close`（60×58） | 没有「关闭」按钮（本界面无弹窗） |
| `button_neutral` | **接了**，用作 `disabled`（+ `muted` 调制保留「变暗」信号）——不是「不接」 |

⇒ 这 5 件**没有**写进 `data/presentation.json`（没消费者的行 = 死旋钮，`§8#16/#21` 同类）。

## 6. 一处**既有断言是假绿**（B8 暴露，已修）

`tools/b1_acceptance.gd:234` 原写 `check(theme.get_stylebox("normal","Button") is StyleBoxFlat, "…来自 ThemeBuilder（不是 Godot 默认）")`。
实测 **Godot 内置默认主题的 `Button.normal` 也是 `StyleBoxFlat`**（`content_margin` 4/4/4/4）
⇒ 这条代理**从来没有判别力**，只是恰好一直为真。B8 把我们的 normal 换成 `StyleBoxTexture` 后它才变红。

改成真判别器：**内容边距 == `ThemeBuilder.CONTENT_MARGIN_H`**（我们 8 / 内置默认 4）；
该值对**扁平盒与贴图盒都成立**（`_box()` 与 `_textured()` 共用同一常量）⇒ 以后在两者之间切换素材，这条断言既不假红也不假绿。
（`theme.has_stylebox(...)` **也不能**当判别器：实测内置默认主题同样为 `true`。）

## 7. 残余与未验证项

1. **视觉观感未验**（无头环境看不到像素）：① 按钮贴图与文字的贴合度；② 8px 宽滚动条里 30px 宽 grabber 的压缩观感；
   ③ 禁用态「中性贴图 + muted 调制」是否够暗。⇒ **留待人类目视确认**（改观感只需改 `data/presentation.json` 的 `nine_patch`，零代码）。
2. **`OptionButton` 也套了按钮贴图**（任务原文只点名 `Button`）：创建界面上 7 个下拉框是最显眼的控件，
   只给 `Button` 贴图会让两类控件当场不一致。**已登记为授权扩大**，若人类认为下拉不该有按钮底，删 3 行即可。
3. **`focus` / `panel` / `RichTextLabel.normal` / `CheckBox` 仍是扁平**（有意：焦点环必须能叠在按钮之上；
   `panel_bg` 未接；无 CheckBox 实例）。
4. **`[theme_audio]` ① 有一条「缺 fonts.body ⇒ 用内置字号回退」的既有断言在真实清单上恒真**（真实清单已配 `fonts.body`，
   字号恰等于 `DEFAULT_BODY_SIZE`）⇒ 它现在是**假绿**（靠 16==16 通过）。属既有测试强度问题，**未在本任务修**（范围外，登记）。
5. 未跑真机 LLM / 真实鼠标点击（属 B2 与人工验收）。
6. 仓库根的外来目录 `.workbuddy/` **未 add、未删、未提交**（非本任务产物）。
