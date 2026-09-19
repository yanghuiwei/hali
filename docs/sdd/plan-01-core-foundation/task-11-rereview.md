# Task 11 修复轮 scoped 复审记录

审查者：independent reviewer subagent（只读）　模型：deepseek-flash　范围：`70ad341..ecf523c`
仓库 `E:/Hali`，分支 `plan-01-core-foundation`，增量提交 `ecf523c`（父 `70ad341`）

## 结论
- Important #1（创建失败错误写入不可见的 `log_view`）：**ADDRESSED**
- Important #2（重启后创建界面无读档入口）：**ADDRESSED**
- 新缺陷：**无**（无可判定为 Critical/Important 的新问题；仅 2 条非阻塞残余，见末节）
- 裁定：**通过**

## 证据

### 0. 审查范围与提交事实
- `git diff --name-only 70ad341..ecf523c` → 仅 2 个文件：`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`、`src/ui/main.gd`（`git show --stat ecf523c`：2 files changed, 58 insertions(+), 4 deletions(-)）。无 `src/rules/`、`src/core/`、`tools/`、`README.md`、`project.godot` 等范围外改动。
- `ecf523c` 的父确为 `70ad341`（`git log -1 --format="%H %P"`）。
- 工作区**受跟踪文件干净**（`git status --porcelain` 无 ` M`/`A` 行）；仅存在未跟踪的复审过程产物 `docs/sdd/plan-01-core-foundation/review-*.diff`（含本轮新增 `review-70ad341..ecf523c.diff`，controller 生成，非实现改动，不计入夹带）。

### 1. Important #1 —— ADDRESSED
关键 diff（`git diff 70ad341..ecf523c -- src/ui/main.gd`）：

```
+var creation_error: Label = null                                        # main.gd:22
@@ func _show_creation()
+	creation_error = Label.new()                                        # :94
+	creation_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART       # :95
+	creation_error.custom_minimum_size = Vector2(0, 48)                 # :96
+	creation_box.add_child(creation_error)                              # :97
@@ func _on_start_pressed()
-		log_view.text = "创建失败：\n%s" % "\n".join(result.errors)
+		_show_creation_error("创建失败：\n%s" % "\n".join(result.errors))  # :186
+func _show_creation_error(message: String) -> void:                      # :212
+	if creation_error != null:                                          # :213
+		creation_error.text = message                                    # :214
+	push_warning(message)                                               # :215
+	if log_view != null:                                                # :216
+		log_view.append_text(message + "\n")                            # :217
```

- **`creation_error` 确实在 `_show_creation` 中创建并 add 到 `creation_box`**（:94–97）。`creation_box` 是 `root_box` 子节点、`_ready → _build_ui` 后默认 `visible=true`，且仅在**成功**路径（:190 / :278）才被置为不可见。因此创建失败分支（:186 后立即 `return`，不改可见性）必然落在可见的 `creation_box` 内。
- 失败时错误**同屏可见**：`creation_error.text` 写入 + `push_warning` 双通道；`log_view` 只是附带（已加 `log_view != null` 守卫）。
- 原缺陷的“不可见”根因（`log_view` 挂在 `play_box`，而 `play_box.visible=false`，:47）不再被创建失败路径依赖。
- 可达性确认（非死代码）：UI 允许选择冲突组合（如 `squib` 血统 + `excellent` 资质），`tests/creation_test.gd:85–92` 证明 `CharacterCreation.validate_choices/create` 会对该类组合产出 `errors`，故 :186 分支真实可达。

### 2. Important #2 —— ADDRESSED
关键 diff：

```
+	# 重启后允许直接读档，不必先创建角色（否则「先创建再点读档」会覆盖刚创建的世界）
+	var load_btn := Button.new()                              # main.gd:155
+	load_btn.text = "读取存档"                                 # :156
+	load_btn.pressed.connect(_on_load)                         # :157
+	creation_box.add_child(load_btn)                           # :158
@@ func _on_load()
-		_append("读档失败：%s" % str(result["error"]))
+		var msg := "读档失败：%s" % str(result["error"])          # :269
+		if creation_box != null and creation_box.visible:       # :270
+			_show_creation_error(msg)                           # :271
+		else:
+			_append(msg)                                        # :273
...
 	creation_box.visible = false                                # :278
 	play_box.visible = true                                     # :279
+	status_label.text = PanelFormatter.status_line(world) + " ｜ 回合 %d" % world.clock.turn   # :280
+	if creation_error != null:                                  # :281
+		creation_error.text = ""                                # :282
```

- 「读取存档」按钮挂在 `creation_box`（:158），启动即可见，不再依赖先创建角色 → 与计划 Step 6 第 7 条（关掉程序重开 → 点「读档」→ 世界恢复）字面一致。
- 失败分支按前台盒子路由：`creation_box.visible` → 可见 `creation_error`；否则（`play_box` 内的「读档」按钮路径）→ `_append` 到 `log_view`。两条失败路径都可见，无静默。
- 成功分支：切 `play_box`、刷新 `status_label`（含当前回合数，格式与 `_on_command_submitted` :241 完全一致，签名 `PanelFormatter.status_line(world)->String`（panel_formatter.gd:127）匹配）、清空 `creation_error`。

### 3. 新缺陷核查（逐条）
| 核查点 | 结论 | 依据 |
|---|---|---|
| `creation_error` 可能为 null 的调用点是否有守卫 | ✅ | `_show_creation_error` 内 :213 守卫；`_on_load` 成功分支 :281 守卫；`_on_load` 失败分支先判 `creation_box != null`（:270）才调用，而 `creation_error` 在 `_show_creation` 中先于该按钮创建，可达时必非 null |
| `_show_creation_error` 是否可能在 `_show_creation` 之前被调用 | ❌ 不可能 | 仅 2 个调用点（:186、:271）。:186 由 :151 的「开始人生」按钮触发，:271 由 :157（创建界面）或 :58-63（`play_box` 按钮行）触发；三者的宿主节点均在 `_show_creation` 之后才存在，`play_box` 更是只有成功创建/读档后才可见。另有 null 守卫兜底 |
| 创建界面「读取存档」复用 `_on_load` 是否与 `play_box` 内同名按钮冲突 | ❌ 无冲突 | 两个独立 Button 各自 `pressed.connect(_on_load)`，单次点击仅一次回调；两盒子的可见性在 :190–191 与 :278–279 同函数成对翻转，互斥，不存在同时生效或互相覆盖 |
| 读档成功后 `status_label` / `creation_error` 更新是否正确 | ✅ | :280 用 `world.clock.turn` 生成状态行（与命令路径同源公式），:281–282 清空错误标签；`creation_error` 为隐藏节点上的残留文本被清掉，不会在下次 `creation_box` 复用时误显（该函数仅 `_ready` 调用一次） |
| 是否夹带范围外改动 | ❌ 无 | 仅 `main.gd` + 计划文档；`tools/test.sh`、`README.md`、`HANDOFF.md`、源码其余部分本提交未触碰 |
| 死状态/空引用回归 | ❌ 无新增 | 新增代码只读 `creation_box/creation_error/log_view/status_label`，全部为 `_build_ui`/`_show_creation` 已赋值成员；`push_warning`、`Label.new()`、`Vector2`、`TextServer.AUTOWRAP_WORD_SMART` 均为合法 API（冒烟加载无脚本错误） |

### 4. 冒烟仍绿（独立复跑）
命令 `bash tools/test.sh`，标准输出关键行：

```
== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/3 单元测试 ==
[harness] 断言=8 失败=0 / [registry]=26 / [money]=15 / [magic_level]=22 / [model]=49 / [clock]=47
[world_tick]=104 / [creation]=176 / [spell]=227 / [gm]=38 / [panel]=65 / [selfcheck]=26 / [save]=81  失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
main scene ready, godot=4.7.2-stable (official)
全部通过。
EXIT=0
```

- 3/3 段确为真实执行（无「跳过」字样，`grep -c "跳过"` = 0）；13 套件全部 `失败=0`（`grep -c "失败=0"` = 14 = 13 套件 + 总计行）；`全部通过。`；退出码 **0**。
- 两段 `SCRIPT ERROR` 来自 `save_test` 的故意坏档负例（Task 10 既有，非本轮引入），该套件仍 `断言=81 失败=0`，不影响裁定。

### 5. 计划 Step 3 与源码逐字节一致（脚本复算）
- 提取 `sed -n '4279,4570p' plan.md > /tmp/plan_main.gd`（计划文件 :4278 = ```gdscript，:4571 = ```，块内容 292 行）与 `src/ui/main.gd` 比较：
  - `diff` 空 → **BYTE-IDENTICAL**；
  - `wc -c` 均为 `10106`；`md5sum` 均为 `d97a0f4dfe8eb4454ca1ab110f0cffcc`。
- 计划的 31 行改动与代码一一对应（6 个 hunk：成员声明、`creation_error` 构建、`读取存档` 按钮、`_show_creation_error`、创建失败改写、`_on_load` 失败/成功分支），无“只改代码不改计划”或反向的不同步。

### 6. 「重启 → 直接读档」静态可达性论证
`_ready`（:24）→ `_build_ui`（:31，`play_box.visible=false` :47）→ `_show_creation`（:32）→ `creation_box` 内先建 `creation_error`（:94–97）再建「读取存档」按钮（:155–158，`pressed.connect(_on_load)`）→ 玩家点击 → `_on_load`（:266）→ `SaveStore.load_slot("slot1", registry)` 成功 → `creation_box.visible=false` / `play_box.visible=true`（:278–279）→ `status_label` 刷新、错误清空 → `log_view` 追加成功信息与玩家面板。整条路径不依赖任何“先创建角色”的前置，与计划 Step 6 第 7 条一致。失败时停在创建界面并把原因写进可见 `creation_error`（:271 + :214），玩家可立即改选重试。

### 7. 第一轮 5 条 Minor 的回归确认（本轮未修，无回归）
- `git diff 70ad341..ecf523c -- src/ui/main.gd` 中不包含 :206 `var _turn_count := 0` / :230 `_turn_count += 1` / `_on_audit`（:285–291）/ `push_warning` 相关日志策略的任何改动 → Minor「`_turn_count` 死变量」「`_on_audit` 一键 ack」状态与父提交**完全一致**。
- `tools/test.sh` 本提交未修改（不在 `--name-only` 列表）→ Minor「冒烟不校验 `main scene ready` 输出行」保持原状，未回归也未修（本次“冒烟真跑到了”的结论由人工读 stdout 得出，与首轮同一强度）。
- `HANDOFF.md` 本提交未修改 → Minor「HANDOFF 陈旧（`ui/main.tscn`、§6 指针过期）」保持原状，属已知待办。
- 需更正简报一处表述：首轮 Minor「`_on_load` 成功后不刷新 `status_label`」在本轮**顺带修掉了**（:280；首轮建议中的 `_turn_count = world.clock.turn` 未做，但该变量本身是死变量，无可观测影响）。其余 4 条 Minor 未修、无回归。

## 残余风险 / 建议
1. （建议，非阻塞）从创建界面读档成功后未 `command_edit.grab_focus()`（对照 `_on_start_pressed` :198）。焦点可能仍停留在已隐藏的「读取存档」按钮上，玩家首次键入可能不进输入框。非回归（旧 `_on_load` 同样不抢焦点），但既然新增了这条入口，顺手补一行更稳。
2. （建议，非阻塞）`_show_creation_error` 会同时往隐藏的 `log_view` 追加一行（:216–217）。若玩家在创建界面先失败一次、随后读档成功，日志里会残留一条「读档失败：…」再接成功信息。纯观感问题，且保留失败痕迹也有可取之处，是否清理由控制者决定。
3. （沿用首轮、仍未闭环）真正的人工 GUI 验收（计划 Step 6 全 8 项：点击创建、下拉/SpinBox 交互、存档/读档按钮、重启读档、第 15 回合自检挂起与「确认自检」）在 headless 下依然**未被任何自动化覆盖**。本轮的 Important #1/#2 修复同样只做了静态论证 + 场景可加载冒烟，未有一次真实点击验证；建议在计划 01 收尾前由人类至少跑一遍第 2/6/7 项。
4. （沿用首轮）`tools/test.sh` 仍只看退出码，不 `grep` 关键输出行；若将来 Godot 在脚本加载失败时返回 0，冒烟可能假绿。属首轮 Minor #6，未修。

## 未验证/存疑
- **未执行任何 GUI 交互**（无窗口环境）：`creation_error` 的实际渲染（`autowrap_mode` + `custom_minimum_size(Vector2(0,48))` 在真实窗口中的换行/高度表现）、按钮布局拥挤程度、读档后输入框焦点、`push_warning` 在导出模板下的可见性，均只做了静态/编译层验证。
- «逐字节一致» 的结论基于 `sed` 行区间抽取（以 :4278/:4571 的围栏为界），已确认该区域内仅此一个 `gdscript` 块，无第二个同名代码副本干扰；未逐行核对计划中是否有描述 UI 控件的非代码文本需要同步（已 grep「开始人生/读档/读取存档/play_box」，Step 6 清单第 1 项「7 个下拉框」等描述与新增按钮不冲突，无需改动）。
- 工作区并非字面“零未跟踪文件”：`docs/sdd/plan-01-core-foundation/` 下有 16 个未跟踪的 `review-*.diff`（含本轮 2 个）。判定为 controller 的复审过程产物而非实现夹带，但严格按“工作区干净”字面口径，此项不满足——由控制者决定是否纳入 `.gitignore` 或随任务收尾一并入库。
- 未复核提交签名/作者等元数据，未复核 `.godot` 缓存与 `main.gd.uid`（本提交未涉及，`main.gd` 路径未变，`load_steps`/`ext_resource` 无需更新）。
