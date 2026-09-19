# Task 11 简报：主界面与运行说明（计划 01 收尾）

> 给实现者（worker）的完整作业书。仓库根 = `E:/Hali`（Windows + Git Bash），分支 `plan-01-core-foundation`，
> 起点应为 `16ba34b`（Task 10 收尾提交），工作区干净。
> **先读** `HANDOFF.md`（第 3、4、6 节，尤其 §8#34 的共享 RNG 要求）与计划原文
> `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 11`（约第 4193–4640 行，Step 1–8）。
> 本简报与计划冲突时以本简报为准。

## 目标

- 新建 `src/ui/main.tscn`、`src/ui/main.gd`
- 修改 `project.godot`（指定主场景）
- 修改 `tools/test.sh`（冒烟检查路径）
- 修改 `README.md`（按最终状态收尾）
- **不新增单元测试套件**；交付验收主要靠 `tools/test.sh` 的「3/3 场景冒烟」+ 人工窗口验收。

## 强制裁定 1：主场景路径统一为 `src/ui/`（计划里有 `ui/` 与 `src/ui/` 两套写法，必须统一）

计划自相矛盾：`Files` 写 `Create: src/ui/main.tscn`，但 Step 1/4/5 又写 `ui/main.tscn`；
而 `tools/test.sh:27` 实际检查的是 `$ROOT/ui/main.tscn`（不存在 → 冒烟被跳过），`project.godot` 也还没设主场景。
不修会导致：冒烟永远跳过（假绿）、且 `run/main_scene` 指向不存在的场景（程序起不来）。

**统一裁定（按 `src/ui/`）**：
1. 场景与脚本放 `src/ui/main.tscn`、`src/ui/main.gd`（与既有 `src/ui/panel_formatter.gd` 同目录）。
2. `project.godot` 的 `[application]` 段加 `run/main_scene="res://src/ui/main.tscn"`。
3. `tools/test.sh` 第 27 行改为 `if [ -f "$ROOT/src/ui/main.tscn" ]; then`，并把跳过提示里的 `ui/main.tscn` 改为 `src/ui/main.tscn`。
4. 同步计划原文上述三处（Step 1 的 `ls`、Step 4 的 ini、Step 5 的错误提示；`### 完成后验收` 段若有 `ui/main.tscn` 也一并改）。

## 强制裁定 2：GM 与 TurnEngine 必须共享同一个 `RngService`（保 §8#34）

计划 Step 3 的 `_on_start_pressed`/`_on_load` 写成：
```gdscript
engine = TurnEngine.new(world, ScriptedGameMaster.new(RngService.new(world.game_seed + 1)), rng)
```
即 GM 用另一个新建 RNG，而 `TurnEngine.submit` 把 `rng.state_dict()` 写进 `world.rng_state`——两者不是同一个对象，
读档后叙事随机流不会恢复（正是 Task 10 刚修好的 §8#34）。
改为**始终共享同一个 `rng` 实例**：
```gdscript
engine = TurnEngine.new(world, ScriptedGameMaster.new(rng), rng)
```
- `_on_start_pressed`：保留前面的 `rng = RngService.new(SEED_SALT + Time.get_ticks_msec() % 100000)`，把它同时交给 GM 与引擎。
- `_on_load`：保留 `rng = RngService.new(world.game_seed)`，把它同时交给 GM 与引擎；`TurnEngine._init` 会用 `world.rng_state` 覆盖它的流状态（这是 Task 10 端到端测试验证过的链路）。
同步计划 Step 3 的两处。

## 强制裁定 3：提交必须含 `src/ui/main.gd.uid`

新脚本会自动生成 `.uid`，HANDOFF §4 第 5 条要求入库。`src/ui/main.tscn` 不产生 `.uid`，无需管。

## 强制裁定 4：README 用「增量收尾」，不要整篇覆盖

计划 Step 7 给了一份较短的 README 全文。**不要**用它覆盖现有 README（现有版本含进度表、HANDOFF/台账链接、目录约定、设计不变量，信息更全）。
改为：在现有 `README.md` 上把进度表 11 个任务全部标为 ✅、把「当前进度」措辞改为「计划 01 已完成」，
并确保「运行」「目录约定」「存档位置」「设计不变量」四节与最终代码一致（`src/persist/`、`src/ui/` 已就位，主场景可用）。
计划 Step 7 的「创建 README.md」一句在计划里改为「收尾 README.md」。

## 其它必须遵守的点

1. `src/ui/main.tscn`、`src/ui/main.gd` 逐字按计划 Step 2/3 照抄（应用强制裁定 1/2 的替换）；`project.godot`、`tools/test.sh` 见强制裁定 1。
2. GDScript 字符串里**不要**写 `\u` / `\x` 转义。
3. 测试唯一入口 `bash tools/test.sh`；**不要并发跑两个 Godot 实例**。
4. 主场景冒烟会真正执行 `--headless --quit-after 5` 跑 `_ready` + `_build_ui()` + `_show_creation()`。
   预期输出里应出现 `main scene ready, godot=4.7.2-stable (official)`，且 13 个单测套件仍全绿，退出码 0。
   若出现 `Failed to load script "res://src/ui/main.gd"`，先单独跑一次
   `./Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` 再重试（`class_name` 依赖导入缓存）。
5. **人工窗口验收（计划 Step 6）本机无法自动做**：worker 只需完成 Step 1–5、7、8，并在报告里明确写「人工 GUI 验收（Step 6 的 8 项）待人类执行」。
6. 若逐字照抄的代码报错（例如 headless 下某控件 API、`Callable(self, ...)`、类型推断），**先停下来在报告里记录**，做**最小**修正，并在报告「偏离」节写明。不要顺手重构 UI。

## 执行步骤

1. 确认起点：`git status --short` 为空，`git log --oneline -1` = `16ba34b`。
2. Step 1：确认 `src/ui/main.tscn` 尚不存在、`project.godot` 尚未指定主场景（`grep run/main_scene project.godot`）。
3. Step 2/3：创建 `src/ui/main.tscn`、`src/ui/main.gd`（应用强制裁定 1/2/3）。
4. Step 4：改 `project.godot`；改 `tools/test.sh` 冒烟路径。
5. Step 5：`bash tools/test.sh` 到绿（含 `main scene ready` 与 `全部通过。`），记录原始输出（先确认「修改前冒烟被跳过」的状态也可记为对照）。
6. Step 7：增量收尾 `README.md`。
7. Step 8：提交：

```bash
cd /e/Hali
git add src/ui/main.tscn src/ui/main.gd src/ui/main.gd.uid project.godot tools/test.sh README.md \
        docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
git commit -m "feat(ui): 主界面、创建流程与运行说明"
```

8. **提交后立刻**写报告：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-11-report.md`。

## 报告格式（task-11-report.md）

```markdown
# Task 11 报告

## 结果
一句话：完成/未完成，测试（含冒烟）是否全绿，退出码。

## 提交
<commit hash> <commit message>

## 文件
- 新建：...
- 修改：...

## 计划修正
- 路径统一（`ui/` → `src/ui/`）：改了哪几处（含计划原文）
- 共享 RNG：改了哪两处
- README 收尾方式
- 其它逐字照抄之外的偏离（若无写「无」）

## 测试原始输出
<粘贴 bash tools/test.sh 的完整原始输出（1/3、2/3、3/3），含 `main scene ready` 行与 EXIT 码>
<并注明：Step 6 人工 GUI 验收的 8 项待人类执行>

## 遇到的问题 / 偏离
如实记录；没有就写「无」。
```

## 完成后返回

最终输出：commit hash、改动文件清单、`bash tools/test.sh` 结论行（13 套件失败数、冒烟是否执行到 `main scene ready`、
`全部通过。`、退出码）、报告路径。不要贴大段 diff。
