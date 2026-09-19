# Task 11 修复轮 scoped 复审简报（reviewer）

> 只读审查。可用工具：read、bash（仅只读命令 + `bash tools/test.sh`）。禁止修改文件、禁止 git 写操作。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。

## 背景

第一轮审查（`docs/sdd/plan-01-core-foundation/task-11-review.md`）判 **Approved with findings**：
Critical=0 / **Important=2** / Minor=5。控制器已做修复轮，提交 `ecf523c`（父 `70ad341`）。本次只审这个增量。

## 两条 Important（对照）

1. 创建失败时错误写进隐藏的 `log_view`（`play_box` 隐藏）→ 点「开始人生」看似无反应（该分支可达）。
   修复：新增 `creation_error` Label 挂在 `creation_box`，`_show_creation_error()` 写可见标签 + `push_warning`。
2. 「读档」按钮只在 `play_box`（启动隐藏）→ 重启后无法直接读档，与计划 Step 6 第 7 条冲突。
   修复：`creation_box` 增加「读取存档」按钮，直接连 `_on_load`；`_on_load` 失败时若 `creation_box` 可见则写 `creation_error`，
   成功时刷新 `status_label` 并清空 `creation_error`。

## 必须核对

1. 两条 Important 是否真的 ADDRESSED（贴出关键 diff 行；说明 `creation_error` 在 `_show_creation` 中被创建并 add 到可见的 `creation_box`，
   `_on_start_pressed` 失败分支与 `_on_load` 失败分支都走可见路径）。
2. 是否引入新缺陷：`creation_error` 可能为 null 的调用点是否有守卫；`_show_creation_error` 在 `_show_creation` 之前被调用是否可能；
   「读取存档」按钮复用 `_on_load` 是否与 `play_box` 内的同名按钮冲突；读档成功后 `status_label`/`creation_error` 更新是否正确。
3. **冒烟仍绿**：跑 `bash tools/test.sh`，确认 3/3 出现 `main scene ready, godot=4.7.2-stable (official)`、13 套件失败=0、
   `全部通过。`、退出码 0。
4. 计划 Step 3 的 `main.gd` 代码块与 `src/ui/main.gd` 是否仍**逐字节一致**（可脚本复算）；
   `git diff --name-only 70ad341..ecf523c` 是否仅 `src/ui/main.gd` + 计划文档；无范围外改动；工作区干净。
5. 说明第 2 条修复后，「重启 → 直接读档」在 UI 上现在是否可达（静态论证：`_ready` 建 `creation_box` → 有「读取存档」按钮 → 成功后切到 `play_box`）。
   第一轮发现的 5 条 Minor（`_turn_count` 死变量、`_on_audit` 一键 ack、冒烟不校验输出行、HANDOFF 陈旧等）本轮未修，确认无回归即可。

## 输出格式（直接返回文本；controller 转存为 task-11-rereview.md）

```markdown
# Task 11 修复轮 scoped 复审记录

审查者：<reviewer subagent>　模型：deepseek-flash　范围：70ad341..ecf523c

## 结论
- Important #1：ADDRESSED / PARTIAL / NOT ADDRESSED
- Important #2：ADDRESSED / PARTIAL / NOT ADDRESSED
- 新缺陷：无 / 有
- 裁定：**通过** / **不通过**

## 证据
## 残余风险 / 建议
## 未验证/存疑
```
