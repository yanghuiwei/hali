# Task 4 简报：玩家与世界数据模型

> 给实现者（worker）的完整作业书。你在一台 Windows + Git Bash 机器上，仓库根目录 = `E:/Hali`，
> 当前分支必须是 `plan-01-core-foundation`（已与 `main` 同步到 `eccc871`）。
> **先读** `HANDOFF.md` 第 3、4 节（目录约定 + 踩过的坑），再读计划原文
> `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 `### Task 4: 玩家与世界数据模型`（第 988–1429 行）。
> 本简报与计划冲突时，以本简报为准（本简报含 controller 对正典矛盾的裁定）。

## 目标

按计划 Task 4 Step 1–7 实现并测试：

- 新建 `src/core/game_clock.gd`（`GameClock`）
- 新建 `src/core/json_util.gd`（`JsonUtil`）
- 新建 `src/model/player_state.gd`（`PlayerState`）
- 新建 `src/model/world_state.gd`（`WorldState`）
- 新建 `tests/model_test.gd`（`ModelTest`）
- 修改 `tests/run_tests.gd`：把 `res://tests/model_test.gd` 追加进 `SUITES`

**不要**改其它任务的文件；**不要**新建 `src/gm`、`src/persist`、`src/ui`、`src/rules` 下的任何东西。

## 强制裁定：正典优先，修正计划里的魔杖价矛盾（必须做）

计划第 1060–1061 行的测试把「买魔杖」写成扣 1 加隆（493 纳特）并标注「剩 9 加隆」，
与正典 `哈利·波特·魔法纪元.md:223`「一根普通魔杖：7‑10加隆」矛盾。**正典优先**（HANDOFF 第 4 节第 9 条）。

按下面**逐字**替换 `tests/model_test.gd` 中对应两行：

原：

```gdscript
	p.set_money(p.money().subtract(Money.from_knuts(493)))
	a.eq(p.money().formatted(), "9加隆 0西可 0纳特", "买魔杖后剩 9 加隆")
```

改为：

```gdscript
	# 正典第十八章：一根普通魔杖 7‑10 加隆；取价格下限 7 加隆 = 7 × 493 = 3451 纳特
	p.set_money(p.money().subtract(Money.from_knuts(7 * Money.KNUTS_PER_GALLEON)))
	a.eq(p.money().formatted(), "3加隆 0西可 0纳特", "买 7 加隆普通魔杖后剩 3 加隆（正典第十八章）")
```

（4930 − 3451 = 1479 = 3 × 493，所以期望值必须是 `"3加隆 0西可 0纳特"`。）

同时把**计划原文**第 1060–1061 行改成与上面一致（这是计划级修正，允许只改这两行 + 加一行正典注释）。
在报告里写明：依据正典 `哈利·波特·魔法纪元.md:223`。

## 其它必须遵守的点

1. 其余测试与实现**逐字**按计划 Step 1–5 的代码块照抄（不要自由发挥、不要加功能）。
2. `tests/run_tests.gd` 的 `SUITES` 里追加 `"res://tests/model_test.gd",`（放在 `magic_level_test.gd` 之后即可）。
3. `to_dict()` 一律经 `JsonUtil.normalize()`；这是存读档往返一致性的唯一保障。
4. GDScript 字符串里**不要**写 `\u` / `\x` 转义。
5. 新脚本会生成 `*.gd.uid`，**必须一起提交**（`git add` 要包含 `src/core/game_clock.gd.uid`、
   `src/core/json_util.gd.uid`、`src/model/player_state.gd.uid`、`src/model/world_state.gd.uid`、
   `tests/model_test.gd.uid`；若某个 `.uid` 尚未生成，先跑一次 `bash tools/test.sh` 让它生成）。
6. 测试唯一入口是 `bash tools/test.sh`（Git Bash，仓库根）。**不要并发跑两个 Godot 实例**。
7. **提交前必须有绿灯**：`bash tools/test.sh` 必须出现 `[model] 失败=0`、`总计失败=0`、`ALL TESTS PASSED`，
   且退出码 0。把这段**原始输出**粘进报告。

## 执行步骤

1. 确认起点：`git status --short` 应为空，`git log --oneline -1` 应为 `eccc871`。
2. Step 1：创建 `tests/model_test.gd`（含上面的强制修正）。
3. Step 2：把 `model_test.gd` 加入 `SUITES`，跑 `bash tools/test.sh`，确认是**红**的
   （`套件无法加载（语法错误？）: res://tests/model_test.gd` 之类，`GameClock` 未定义），退出码 1。
4. Step 3–5：依次创建 `game_clock.gd`、`json_util.gd`、`player_state.gd`、`world_state.gd`。
5. Step 6：跑 `bash tools/test.sh` 到**绿**，记录原始输出。
6. Step 7：提交（含 `.uid`）：

```bash
cd /e/Hali
git add src/core/game_clock.gd src/core/json_util.gd src/model/player_state.gd src/model/world_state.gd \
        tests/model_test.gd tests/run_tests.gd \
        src/core/game_clock.gd.uid src/core/json_util.gd.uid src/model/player_state.gd.uid \
        src/model/world_state.gd.uid tests/model_test.gd.uid \
        docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
git commit -m "feat(model): 时钟、玩家与世界状态模型"
```

7. **提交后立刻**写报告文件（不要先去做额外检查，Task 1 的实现者曾因此永久丢报告）：
   `.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/task-4-report.md`。

## 报告格式（task-4-report.md）

```markdown
# Task 4 报告

## 结果
一句话：完成/未完成，测试是否全绿，退出码。

## 提交
<commit hash> <commit message>

## 文件
- 新建：...
- 修改：...

## 计划修正
说明魔杖价两行的修改与正典依据（哈利·波特·魔法纪元.md:223）。

## 测试原始输出
<粘贴 bash tools/test.sh 的完整原始输出，包括 1/3、2/3、3/3 三段与 EXIT 码>

## 遇到的问题 / 偏离
如实记录；没有就写「无」。
```

## 完成后返回

在你的最终输出里给出：commit hash、改动文件清单、`bash tools/test.sh` 的结论行（`总计失败=0` / `ALL TESTS PASSED` / 退出码）、以及报告文件路径。不要贴大段 diff。
