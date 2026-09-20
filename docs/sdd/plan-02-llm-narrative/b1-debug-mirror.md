# B1 观测通道 · `HALI_DEBUG_LOG` 调试镜像（2026-09-20）

> 目的：消除 `NEXT-STEPS.md` B1 的阻塞点——「人工 GUI 验收只能靠存档反推」。
> 性质：小改动（2 个新脚本 + 1 处 UI 接线 + 1 个测试套件 + `tools/test.sh` 第 4 步），**不是**计划任务，无 brief/reviewer 工件。
> 提交：`be9cddc`（实现 + 文档 + 本文件同批入库；随后一次 docs 提交补记哈希）。

---

## 1. 问题（为什么非做不可）

`NEXT-STEPS.md` B1 的实测结论：游戏内的**叙事、面板、玩家输入、创建界面选项、状态行、等待期置灰状态**既不 `print` 也不进存档（存档只记 `world.log` 的 rumor/mundane）。因此 2026-09-20 那次非正式点击里，控制器只能从 `user://saves/slot1.json` 反推出「哑炮无魔法、4 回合推进、存档生成」这点信息；**以下全部无痕**：

- 叙事来自 LLM 还是 `ScriptedGameMaster` 替身
- 四个面板（状态/魔法/关系/势力）的实际输出
- 读档路径、第 15 回合自检挂起与「确认自检」
- 等待 LLM 期间置灰与结束恢复（§8#58 的观测面）
- 未配置 LLM 的提示（F4 的读档路径）

⇒ 人工验收无法闭环，B1/B2 的 GUI 项长期挂着。

## 2. 设计约束（默认行为必须逐字不变）

1. **唯一开关**：环境变量 `HALI_DEBUG_LOG`；`""` / 空白 / `0` / `false` / `off` / `no`（大小写与首尾空白不敏感）一律视为**关闭**，`1` / `true` / `yes` / `on` / 其它任意非空值视为开启。
2. **关闭时一行都不输出**：所有镜像调用点都过 `_mirror()`，关闭时它是空操作；`print` 只出现在 `_mirror` 内部与 `_ready` 的启用横幅内。
3. 镜像**只读**界面文本，不改 UI 逻辑、不改游戏状态、不新增存档字段。
4. 前缀固定 `[HALI] `，便于 `grep`（人工验收与 `tools/test.sh` 都依赖它）。

## 3. 实现

| 文件 | 内容 |
| --- | --- |
| `src/ui/debug_mirror.gd`（新，`class_name DebugMirror`） | `enabled(raw)` 开关语义、`from_env()`、`format(text)` 加前缀。纯函数，可单测。 |
| `src/ui/main.gd` | 新增 `_debug_mirror`（`_ready` 里读环境变量）、`_mirror()` 唯一出口；`_append()`、`_set_status()`、`_set_input_enabled()`、`_set_buttons_enabled()` 全部经过它；`_show_creation()` 额外镜像 7 个下拉的选项数与当前值；`_on_start_pressed()` 镜像创建参数与成败；`_show_creation_error()` 镜像创建界面错误。 |
| `tests/debug_mirror_test.gd`（新，`[debug_mirror]`=23 断言） | 开关真值表（10 开启态 + 9 关闭态）、前缀/格式化稳定性、`from_env()` 与本进程环境变量一致。 |
| `tools/ui_debug_probe.gd`（新，探针，非测试套件） | headless 实例化 `main.tscn`，`await process_frame` 等 `_ready` 跑完后驱动 `_append` / `_set_status` / `_set_input_enabled` / `_set_buttons_enabled` 四条真实路径并退出。 |
| `tools/test.sh` | 扩为 **4 步**：`3/4` 默认冒烟**反向断言**输出里不得出现 `[HALI]`；`4/4` 以 `HALI_DEBUG_LOG=1` 跑探针并逐条 grep 5 个预期标记。 |

镜像覆盖的文本（对应 B1 清单）：

```
[HALI] [状态行] …（含「未配置 LLM，使用本地叙事替身」——创建与读档两条路径）
[HALI] <叙事/面板/事件块/op_errors/自检报告>          ← _append 的全部调用点
[HALI] >>> <玩家输入>
[HALI] [创建界面] <key> 选项数=N 当前=<id>              ← 7 行
[HALI] [创建] <7 个下拉值> / 姓名/性别/年龄/目标/性格 / 成功:<名>（种子 N）
[HALI] [输入框] editable=true|false
[HALI] [按钮] 整排 可用|禁用
[HALI] [创建界面错误] <消息>
[HALI] 存档：成功|失败（<路径>）  /  读档成功：<路径>  /  读档失败：<原因>
```

## 4. 证据（`bash tools/test.sh`，EXIT=0）

```text
[llm] 断言=84 失败=0
[prompt] 断言=13 失败=0
[debug_mirror] 断言=23 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/4 主场景冒烟（默认配置：必须与未加调试镜像时逐字一致） ==
main scene ready, godot=4.7.2-stable (official)      ← 且全篇无 [HALI]（反向断言通过）
== 4/4 调试镜像冒烟（HALI_DEBUG_LOG=1，B1 人工验收的观测通道） ==
[HALI] 调试镜像已启用：界面文本将镜像到 stdout（user://logs/*.log）；内容表问题 0 条
[HALI] [状态行] 《哈利·波特·魔法纪元》魔法世界沙盘·超高自由度人生模拟器
[HALI] [创建界面] era_id 选项数=8 当前=custom
[HALI] [创建界面] bloodline_id 选项数=12 当前=custom
[HALI] [创建界面] birth_identity_id 选项数=11 当前=auror_family
[HALI] [创建界面] aptitude_id 选项数=6 当前=excellent
[HALI] [创建界面] house_id 选项数=6 当前=gryffindor
[HALI] [创建界面] political_leaning_id 选项数=6 当前=blood_equality
[HALI] [创建界面] sim_style_id 选项数=6 当前=brutal_realism
[HALI] PROBE-APPEND-MARK
[HALI] [状态行] PROBE-STATUS-MARK
[HALI] [输入框] editable=false
[HALI] [按钮] 整排 禁用
全部通过。
```

反证强度说明：`4/4` 不是「横幅打印了就算过」——它对 `_append`、`_set_status`、`_set_input_enabled`、`_set_buttons_enabled` 四条路径各断言一条精确标记；任何一条不再镜像即失败。`3/4` 则封住「默认行为被改动」这一类回归（§8 的 Minor 抱怨模式：只做正向断言）。

## 5. 残余 / 未验证（诚实登记）

1. ~~**未在真实窗口 + `user://logs/*.log` 上实跑**~~ **已实测（2026-09-20，见 `b1-acceptance.md` §3）**：`HALI_DEBUG_LOG=1 ./Godot_…_console.exe --path . --quit-after 60` 真实开窗（OpenGL/Intel Arc），`user://logs/godot.log` 内含 `[HALI]` 行。
2. ~~**`[创建] 成功：…` 与存档/读档/自检行未在冒烟中驱动**~~ **已覆盖（2026-09-20）**：`tools/b1_acceptance.gd` 真的调界面处理器走完创建/练药/打工/存档/读档/自检全流程，逐条断言日志文本（见 `b1-acceptance.md`）。
3. **`_show_creation_error` 走独立的 `_mirror` 调用**（不经过 `_append`，因为它在 `log_view` 可能为空时也要写 `creation_error`）。行为正确，但破坏了「唯一出口」的字面整洁——已在代码注释说明。
4. **不解决 §8#58/#62**：等待期仍无超时/取消，UI 提交路径仍无失败恢复。镜像只是让「卡住」这件事**可观测**（能看到 `editable=false` 后没有恢复行），修复仍留给计划 03。
5. 镜像内容是**未经脱敏的界面文本**：若配置了真实 LLM，叙事会进 stdout/日志文件。key 本身不在镜像里（它只在 `LlmSettings` 与请求头中），但**日志文件仍应按敏感数据对待**，不要贴进公开仓库（仓库是 public）。

## 6. B1 的用法（人工验收）

```bash
cd /e/Hali
HALI_DEBUG_LOG=1 ./Godot_v4.7.2-stable_win64_console.exe --path .
# 点窗口做完 8+2 项；随后控制器读 user://logs/*.log（%APPDATA%\Godot\app_userdata\哈利·波特·魔法纪元\logs\）
```

B1 完成后，把逐项结论写进 `NEXT-STEPS.md` B1 条目并把方框打勾。
