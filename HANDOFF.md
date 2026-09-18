# 交接文档 · 哈利·波特·魔法纪元

> 用途：换机器后凭这份文档 + 仓库源码即可继续执行。**先读第 1～3 节。**
> 最后更新：2026-09-18（Task 9 完成时）。交付点 = 分支 `plan-01-core-foundation` 顶端（Task 9 交付时为 `d9135ab`；每次交接文档自身提交都会把这个哈希往后推，所以以「分支顶端」为准）。

---

## 0. 一句话状态

**计划 01「核心模拟地基」（共 11 个任务）已完成 Task 1–9 并通过独立审查（Task 4/5/6/7 含修复轮；Task 8 的 3 条 Important 均为计划级/架构级，已登记 §8 待后续裁定）。** 下一步是 Task 10「存档与读档」（Task 9 已用完整实现替换 Task 8 的 `SelfCheck` 最小桩，并落地第六十二至六十五章面板）。

- 计划全文（唯一执行依据）：`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`（4450 行，Task 1–11）
- 正典规格（唯一事实来源）：`哈利·波特·魔法纪元.md`（仓库根，勿移动、勿改名）
- 过程台账 / 简报 / 报告 / 审查包：`docs/sdd/plan-01-core-foundation/`（见第 7 节）

---

## 1. 代码在哪里、要拿哪个分支

| 项 | 值 |
| --- | --- |
| 远端 | `https://github.com/yanghuiwei/hali.git`（`origin`） |
| 执行分支 | **`plan-01-core-foundation`** ← 必须用这个 |
| `main` | 已被 PR #1 合并到 `eccc871`，**已包含 Task 1–3 代码**；`plan-01-core-foundation` 现与 main 同一祖先 |
| 当前 HEAD | `plan-01-core-foundation` 顶端 `d9135ab`（Task 9），下次从 `git log` 看即可 |

```bash
git clone https://github.com/yanghuiwei/hali.git
cd hali
git checkout plan-01-core-foundation
git log --oneline -5     # 顶部应是最新的 docs(handoff) 提交，其下依次 d9135ab / 463a73d / 432adc8 / 79d15aa
```

`main` 已通过 PR #1 合并到 `eccc871`（含 Task 1–3 代码）；本地 `plan-01-core-foundation` 已在 Task 4 开工时 fast-forward 到同一提交，之后的新提交仍落在执行分支上，先不合回 `main`。

---

## 2. 新机器上跑起来（唯一测试入口）

前置：**Windows + Git Bash**；**Godot 4.7.2 stable，Windows 64-bit，非 .NET 构建**。不需要 Python / Node / 任何包管理器，测试完全离线。

Godot 可执行文件约 180MB，**不入库**（`.gitignore` 里的 `*.exe`）。三种放法，任选：

```bash
# 放法 A（推荐，与工具默认值一致）：把两个 exe 放到仓库根目录，文件名必须完全一致
#   Godot_v4.7.2-stable_win64.exe
#   Godot_v4.7.2-stable_win64_console.exe
bash tools/test.sh

# 放法 B：放在别处，用 GODOT= 覆盖
GODOT=/d/tools/Godot_v4.7.2-stable_win64_console.exe bash tools/test.sh

# 放法 C：已在 PATH 中
GODOT=godot bash tools/test.sh
```

**引擎版本必须是一致的 4.7.2 stable**。换版本会重新生成 `.godot/` 导入缓存与 `*.uid`，产生无意义 diff，甚至让 `class_name` 解析顺序变化。校验方式：跑测试时输出的横幅应为

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
```

脚本行为（`tools/test.sh`）：`1/3` 先 `--headless --import` 生成 `.godot` 缓存（`class_name` 全局类依赖它，冷机器首次必须做）→ `2/3` 跑单元测试 → `3/3` 主场景冒烟（`ui/main.tscn` 在任务 11 之前不存在，会打印"跳过"且不算失败）。

**退出码语义**：`0` 全绿｜`1` 有失败（单测或冒烟）｜`2` 找不到 Godot 可执行文件。

冷机器上第一次运行的预期输出：

```
== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） ==
== 2/3 单元测试 ==
[probe] 故意失败: 期望 <2>，实际 <1>     ← 这是断言库自检探针，故意失败，不算失败
[probe] 断言=1 失败=1                    ← 同上，probe 套件不在 SUITES 里
[harness] 断言=8 失败=0
[registry] 断言=26 失败=0
[money] 断言=15 失败=0
[magic_level] 断言=22 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=176 失败=0
[spell] 断言=223 失败=0
[gm] 断言=38 失败=0
[panel] 断言=65 失败=0
[selfcheck] 断言=26 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
```

游戏窗口目前还起不来（主场景在任务 11 才建立）。要临时看引擎是否可用：`./Godot_v4.7.2-stable_win64.exe --path .`（会打开空工程编辑器）。

---

## 3. 目录结构与职责

```
哈利·波特·魔法纪元.md   # 正典规格（唯一事实来源）
README.md                # 项目说明、进度表、目录约定
project.godot            # Godot 工程定义（features=4.7，gl_compatibility）
tools/test.sh            # 唯一测试入口
data/*.json              # 内容即数据：改内容不改代码（时代/血统/身份/资质/学院/风格/倾向…）
src/core/                # registry(内容表) · game_clock · rng_service · json_util · turn_engine
src/model/               # money · player_state · world_state（均已完成）
src/rules/               # magic_level(已完成) · character_creation · spell_resolver · progression
                         # · state_ops · self_check
src/gm/                  # game_master(接口) · scripted_game_master(离线确定性替身，计划 02 换 LLM)
src/persist/             # save_codec · save_store
src/ui/                  # panel_formatter(已完成) · main.tscn · main.gd（后两者任务 11）
tests/                   # run_tests.gd(运行器) · assert.gd(零依赖断言库) · *_test.gd(每任务一套件)
docs/superpowers/plans/  # 实现计划
docs/sdd/                # 过程台账/简报/报告/审查包（第 7 节）
```

**铁律：内容一律进 `data/*.json`，代码不硬编码内容。** 新增测试套件必须把路径追加到 `tests/run_tests.gd` 的 `SUITES` 常量，否则不会被运行（缺失路径会直接判失败，不会静默跳过）。

---

## 4. 踩过的坑（改代码前必读）

1. **JSON 没有 int/float 之分**：`JSON.parse_string` 把所有数字读成 float，而 Godot 的 `Dictionary` 深比较**类型严格**（`{"n":493} != {"n":493.0}`）。`to_dict()` 输出前必须过 `JsonUtil.normalize()`（整数值的 float 归一为 int），`from_dict()` 同样处理动态子字典。否则"存读档往返后状态一致"的断言必然失败。
2. **`to_dict()` 只放 JSON 原生类型**（Dictionary / Array / String / int / float / bool / null）。放 `Vector2`、`PackedStringArray`、自定义对象会在存读档往返中变形。
3. **GDScript 字符串里不要写 `\u` / `\x` 转义**（`"\u"` 是解析错误）。需要反斜杠用 `String.chr(92)`。
4. **`*.uid` 文件必须入库**：Godot 4.4+ 用 `.uid` 锁定脚本标识，缺失或换了引擎版本都会造成引用漂移。新脚本提交时连同 `.gd.uid` 一起 `git add`。
5. **测试运行器在任何情况下都必须以 `quit(...)` 结束**（Task 1 曾因套件解析失败而挂住，已修复：损坏的套件被隔离进 `_run_suite` + `can_instantiate()` 守卫）。改动 `tests/run_tests.gd` 时不要破坏这个保证。
6. **不要并发跑两个 headless 实例**（会争 `.godot` 缓存）。曾出现 bash `timeout` 杀掉 shell 但把引擎子进程遗成孤儿、空转烧 CPU 的情况。卡住时这样排查：

```bash
tasklist | grep -i godot
taskkill //PID <PID> //F
```

7. **CRLF/LF 警告是正常的**：`.gitattributes` 强制 `eol=lf`，Windows 上 `git add` 计划文档时会看到 "CRLF will be replaced by LF"，不影响内容。
8. **引擎固定 4.7.2 stable + 纯 GDScript**：不引入第三方插件、外部素材、网络依赖；玩家可见文本用中文，标识符用英文；源码与数据一律 UTF-8。
9. **正典优先**：原著明确设定 ＞ 模拟器推演。每完成一个任务，若发现计划文本与正典冲突（Task 3 就发生过：计划把 510 纳特写成 `[1,0,17]`），**改计划、不要顺着错的计划写实现**，并在报告里写明依据的正典行号。

---

## 5. 进度台账（计划 01 · 11 个任务）

| 任务 | 内容 | 状态 | 提交 |
| --- | --- | --- | --- |
| 1 | 仓库引导 + Godot 工程 + 无头测试骨架 | ✅ 完成（含 1 轮修复） | `04808e2..b2ca0f4` + `52b68ba..281fdd6` |
| 2 | 内容注册表 + 正典内容表 | ✅ 完成 | `b2ca0f4..52b68ba` |
| 3 | 货币 + 魔法等级与失败率 | ✅ 完成（审查 Approved with findings） | `61d4ac1` + `50fc993`（范围 `281fdd6..50fc993`） |
| — | 交接文档 + 台账耐久副本 | ✅ | `055d9ef` |
| 4 | 玩家与世界数据模型 | ✅ 完成（含 1 轮修复 + scoped 复审） | `2e3deb8` + `8264ef9` |
| 5 | 确定性随机 + 月度世界演化 | ✅ 完成（含 2 轮修复 + 2 次 scoped 复审） | `23e67cd` + `f9038ca` + `24d5d43` |
| 6 | 角色创建流水线 | ✅ 完成（含 2 轮修复 + 2 次 scoped 复审） | `f3d8a31` + `2341540` + `61ad053` |
| 7 | 魔咒解析器与反漏洞守卫 | ✅ 完成（含 2 轮修复 + 2 次 scoped 复审） | `f323b55` + `3499881` + `d52ebda` |
| 8 | 叙事接口 + 状态操作 + 反刷成长 + 回合引擎 | ✅ 完成（审查 Approved with findings；3 Important 计划级，已登记 §8） | `432adc8` |
| 9 | 状态面板格式化 + 强制自检 | ✅ 完成（审查 Approved with findings；0 Critical / 0 Important / 6 Minor，已登记 §8） | `d9135ab` |
| 10 | 存档与读档 | ⬜ 下一步 | — |
| 11 | 主界面与运行说明 | ⬜ | — |

逐事件台账（含每次审查的原始结论、发现的严重度、控制器补跑证据）：
**`docs/sdd/plan-01-core-foundation/progress.md`** ← 接手前先通读。

### 已完成任务的关键结论

- **Task 1**：修复过「套件解析失败 → 运行器挂住」的缺陷（违反 Task 1 自身"任何情况下都要 `quit()`"的要求），已 scoped re-review 通过。遗留 minor（deferred）：`tools/test.sh` 丢弃 `--import` 的退出码；空 `SUITES` 会打印 ALL TESTS PASSED。
- **Task 2**：7 张正典内容表 + 注册表完整性校验，review clean。遗留 1 条 Important + minors 在人类批次里。
- **Task 3**：`Money`（值语义、负值、`to_dict`/`from_dict` 往返）+ `MagicLevel`（十级 Tier、失败率区间、六项环境修正、clamp 到 `[0.005, 0.95]`）。审查 **Spec ✅ / Approved with findings**，0 Critical；采用了两处计划修正（见第 4 节第 9 条）。
- **Task 4**：`GameClock`（跨年进位 / `months_between`）+ `JsonUtil`（数值归一，存读档往返一致性的唯一保障）+ `PlayerState`（技能钳制 0..100、魔咒去重、面板骨架、`to_dict`/`from_dict`）+ `WorldState`（时代锚点、世界变量基线、历史/日志、registry 瞬态不入档）。审查第一轮 **Approved with findings**（0 Critical / 2 Important / 6 Minor），当轮修掉其中 1 Important（`create` 与 `from_dict` 的 `world_vars` 类型不对称）+ 1 Minor（键名拼写），并加 3 条回归断言，scoped 复审 **通过**。
- Task 4 的完整审查记录：`docs/sdd/plan-01-core-foundation/task-4-review.md`（含两份独立 reviewer 输出与反证）
- **Task 5**：`RngService`（命名流、同 seed 可复现、`state_dict`/`load_state` 存档恢复且 int64 字符串化防 JSON 精度丢失）+ `WorldState.tick()`（世界变量向时代基线回归并 clamp 到 [0,1]、按地点/身份/年份筛传言、major 双闸门 + 同月去重、日志裁剪）+ `locations`/`rumors` 两张表。第一轮审查 Critical=0 / Important=4 / Minor=9；两轮修复后 scoped 复审 **通过**。
- Task 5 的完整审查记录：`docs/sdd/plan-01-core-foundation/task-5-review.md`（含三轮独立 reviewer 输出与反证）
- **Task 6**：`CharacterCreation`（`choices → PlayerState` 的校验与创建、血统/资质自洽、哑炮无魔法无魔杖、随机资质不掷哑炮、学院判定、技能初始偏置）+ `skills` / 四张魔杖表。第一轮 Critical=0 / Important=3 / Minor=5；两轮修复（封堵 `aptitude_special` 注入、校验 `birthplace`、随机池排除 `special`）后 scoped 复审 **通过**。
- Task 6 的完整审查记录：`docs/sdd/plan-01-core-foundation/task-6-review.md`（含三轮独立 reviewer 输出与反证）
- **Task 7**：`SpellResolver`（等级拦截、失败率 = 等级区间 + 环境 + 资质 + 难度、成功/失败旁白与副作用）+ `data/spells.json`（32 条）+ 五十五条反漏洞守卫（复制/复活/时间回溯/能量叠加/fail-closed 稀有度白名单、终身禁忌、登记与审批）。第一轮 Critical=0 / Important=2 / Minor=4；两轮修复后 scoped 复审 **通过**。
- Task 7 的完整审查记录：`docs/sdd/plan-01-core-foundation/task-7-review.md`（含三轮独立 reviewer 输出与反证）
- **Task 8**：`GameMaster`/`GmResult` 接口 + `ScriptedGameMaster`（确定性关键词裁决）+ `StateOps`（唯一审计状态入口）+ `Progression`（第七十章反刷，同（技能,地点）重复收益递减）+ `TurnEngine`（一回合 = 一月；死亡不可逆、自检挂起、世界照常 `tick()`）+ `SelfCheck` 最小桩。审查 **Approved with findings**（Critical=0 / Important=3 / Minor=5）；3 条 Important 均为计划级/架构级（同回合同掷骰、叙事 RNG 未入档、GM 直改世界），已登记 §8。
- Task 8 的完整审查记录：`docs/sdd/plan-01-core-foundation/task-8-review.md`
- **Task 9**：`PanelFormatter`（第六十二至六十五章文本面板：人生状态 / 魔法能力 / 社会关系 / 势力）+ 完整 `SelfCheck`（第七十二章：`snapshot` 七项 + `ooc_report` 四项 + `report`）替换 Task 8 最小桩，新增 `src/ui/` 目录。审查 **Approved with findings**（Critical=0 / Important=0 / Minor=6）。开工中裁定计划内部矛盾（`player_panel` 不输出姓名 vs 测试断言 `contains("张三")`），作最小修正新增 `【姓名】` 行并同步计划；审查批准该偏离为唯一正确且无夹带。
- Task 9 的完整审查记录：`docs/sdd/plan-01-core-foundation/task-9-review.md`

---

## 6. 下一步怎么执行（Task 10）

> ✅ 第 8 节第 27 条闸门（`energy_loop_count`/`time_rewind_count` 生命周期）已由 Human 裁定并落地（per-turn / 终身一次性，`a0bc1d3`）。
> Task 9 已完成（第六十二至六十五章面板 + 第七十二章完整自检），下一步是 **Task 10「存档与读档」**。

1. 先读计划里 `### Task 10: 存档与读档`（约第 3881 行起，含完整代码块与预期输出）。
   **Task 10 必须同时收口几条存档级 Important/Minor**（见 §8）：#9（`from_dict` 对显式 null/非容器字段的健壮性）、#17/#34（叙事 RNG 未入档，读档后随机流重放）、#19（`game_seed` 裸 int 经 JSON 精度丢失）、#20（`tick → to_dict → JSON → from_dict → tick` 端到端续跑对比缺失）、#26（载入路径不重跑 `validate_choices`）。
2. 按 superpowers 的 **subagent-driven-development** 流程推进：每任务 = 简报（brief）→ 实现（worker）→ 自跑 `bash tools/test.sh` 到绿 → **先写报告文件再返回** → 独立 reviewer 审 diff → 台账记录。
3. **子代理必须使用与主会话相同的大模型**（本机为 `deepseek/deepseek-flash`）：`pi -p --provider deepseek --model deepseek-flash ...`，不要用 harness 默认模型。
4. **提交前必须有绿灯**：`bash tools/test.sh` 输出 + 原始文本留存到报告里。Task 3 的流程教训（实现者没跑 Step 5、没写报告，控制器事后补跑）已在台账登记为 P1 流程发现，Task 4 起未重演。
5. 实现者的报告必须在 commit 之后**立刻**写盘：Task 1 的实现者曾在提交后超时，报告永久缺失。
6. 审查者必须只读（`pi -p --tools read,bash`）；Critical/Important 要么当轮修掉并做 scoped 复审，要么明确登记进人类批次（Task 4 两种都出现过）。

---

## 7. 过程状态怎么跟着源码走（重要）

- 本机 scratch 工作区：`.superpowers/sdd/2026-09-18-hp-magic-era-01-core-foundation/` —— **被 `.gitignore` + 目录内 `.gitignore: *` 双重忽略，不会随源码走**，换机器后是空的。
- 因此**耐久副本**放在仓库内的 `docs/sdd/plan-01-core-foundation/`，内容为：`progress.md`（台账）、`task-N-brief.md`（简报）、`task-N-report.md`（实现者报告）、`task-3-review.md`（审查记录）、`review-<from>..<to>.diff`（审查包：提交列表 + 文件统计 + 完整 diff）。
- **交接规则**：每完成一个任务（提交 + 审查 + 台账更新后），把该任务的四个工件从 `.superpowers/sdd/.../` 同步复制到 `docs/sdd/plan-01-core-foundation/`，与代码一起提交。副本以 `docs/sdd/` 下的为准（它可追溯、可 diff）；`.superpowers/` 只是工具工作区，允许随时清空。
- 注意：`task-3-report.md` **不存在**（Task 3 实现者未写报告），台账里有等价记录，不要误以为文件丢失。

---

## 8. 待人类裁定项（不阻塞 Task 10）

前 3 条是计划预检遗留，其后是逐任务审查产出。**第 1 条（Task 8 故意留 `SelfCheck` 最小桩）已由 Task 9 用完整实现替换而关闭**；**第 2 条（魔杖价矛盾）已在 Task 4 开工前按正典裁定并落地**。其余项均为计划级/文档级，或要到 Task 10–11 才触发。

1. ~~**Task 8 故意留 `SelfCheck` 最小桩**~~ **已关闭（Task 9）**：完整 `SelfCheck`（`snapshot`/`ooc_report`/`report`）已替换最小桩（`d9135ab`），`gm_test` 仍绿。
2. ~~**魔杖价自相矛盾**~~ **已裁定（Task 4）**：按正典 `哈利·波特·魔法纪元.md:223`「一根普通魔杖：7‑10加隆」，测试取价格下限 7 加隆（3451 纳特），期望 `"3加隆 0西可 0纳特"`；计划与测试两处已同步。裁定记录见 `docs/sdd/plan-01-core-foundation/task-4-review.md`。
3. **Task 8 `ScriptedGameMaster` 直接调 `SpellResolver.cast()`**（直接改世界）而不是返回 `cast_spell` delta，与"GM 返回 delta、引擎负责应用"的契约不符 —— 确认是否接受（计划内已文档化）。
4. **哑炮失败率**：`BANDS[0] = (1.00, 1.00)` 但 `effective_rate(SQUIB)` 早退返回 `0.95`，等于哑炮有 5% 施法成功率，与正典「哑炮…无法施展咒语」的严格读法冲突（Task 7 判定直接走 `effective_rate`）。二选一：把 `BANDS[0]` 改成 `(0.95, 0.95)`，或让 `effective_rate` 对 SQUIB 返回 1.0 / 直接拒绝施法。另注 `base_rate(SQUIB)=1.0` 超出 `effective_rate` 文档化的 `[0.005, 0.95]` 值域，是潜在陷阱。
5. **`Money` 负值显示未定义**：`Money.from_knuts(-50)` → `parts() = [0, -2, -16]`，`formatted() = "0加隆 -2西可 -16纳特"`。**Task 9 已落地面板（`player_panel`/`power_panel` 会输出该形态），但仍未定义**：债务场景会显示负值西可/纳特。需裁定债务格式（如「负债 X 加隆」）或在 `Money` 层定义。
6. **大师级失败率上界 0.02** 对正典「低于2%」是开/闭区间歧义，测试用 `<=` 掩盖了它。
7. **（Task 9 已落地，扩展）`power_panel` 标签映射** 把 **7 个标签**映射到 **4 个 `world_vars`**：法律执行→`war_pressure`、傲罗/稳定度→`ministry_stability`、威森加摩/腐败度→`corruption`、国际→`muggle_relations`（与「麻瓜关系」重复）。纯显示问题，确认可接受，或后续补独立的 `international_relations` 等键。
8. **是否先补 Task 3 的测试强度缺口**（审查 Minor）：`magic_level_test` 的 clamp 上下界两条断言实际空转（0.9075 < 0.95、0.01 > 0.005），`BANDS` 只精确断言 5/10 档、`LABELS` 只断言 3/10，`money_test` 的负值只测了 `total_knuts()`。选择：立即补，或作为计划级补测留到后续任务批量处理（注意同型缺口会复制到 Task 5/7/9）。
9. **（Task 4 审查 Important，范围外）** `PlayerState.from_dict` / `WorldState.from_dict` 收到显式 `null`/非容器字段时，可能因类型化赋值运行期报错（仅畸形/手改存档触发，正常 `to_dict→JSON→from_dict` 不触发）。建议 Task 10 加 `typeof` 回退，或明确「存档只由 `to_dict()` 产出」。
10. **（Task 4 Minor）** `JsonUtil.normalize` 未覆盖非有限 float、≥2^53 的整数值 float、Dictionary 键类型；当前游戏数值不触发，建议在计划/注释写明这三条限制。
11. **（Task 4 Minor）** 计划 Interfaces 段（约 1000–1020 行）缺 `era_start_year`、`PlayerState.new_default()`、`normalize -> Variant`，与 Step 代码不一致（纯文档级）。
12. **（Task 4 Minor）** `custom` 时代 `start_year:null` 静默回退 1991、月份固定 9；`WorldState.create()` 无处接收玩家指定年份，与 `data/eras.json` 中 custom「由玩家指定年份」语义不符。
13. **（Task 4 Minor）** `GameClock.advance_months(负数)` 静默 no-op；`GameClock.from_dict` 缺省 `month=1` 与类默认 `month=9` 不一致。
14. **（Task 4 Minor，Task 5 留意）** registry 原值是整数值 float（如 `secrecy_integrity:1.0`），而状态内 `world_vars` 已归一为 int `1`；未来直接比较二者会因 Godot 字典类型严格比较而不等。约定：比较前先 `JsonUtil.normalize`，或 Registry 载入时统一归一。
15. **（Task 4 已局部落实）** 第 8 条的「测试强度」在 Task 4 已加 3 条（JSON 端到端往返 × 2 + `world_vars` 类型一致性），`magic_level` / `money` 的历史缺口仍待批量处理。

### Task 5 审查新增（均不阻塞 Task 6）

16. **（Task 5 Important，计划级）** `data/rumors.json` 的 `weight` 字段声明了但 `tick()` 用 `stream_pick` 均匀抽取，稀有度旋钮失效；二选一：实现加权抽取，或删字段并在契约中说明稀有度由 `major_gate` 负责。建议排入「内容/平衡」任务。
17. **（Task 5 Important，计划级）** `WorldState.rng_state` 是死字段（`to_dict/from_dict` 读写但无人写入），`RngService.state_dict()/load_state()` 在 `src` 中零调用；当前 `tick()` 用 `game_seed + turn*prime` 派生子 RNG，存档本就不需要持久化流状态，故字段冗余。接线前必须定夺：删除字段并把计划改述为「派生式确定性」，或接入长驻 `RngService`。
18. **（Task 5 Minor）** `RngService` 无 schema 版本号，旧扁平 schema 静默不恢复；`String::hash()` 为 32 位有碰撞风险；同月两次 pick 可命中同一条 rumor；`history` 无上限、`log` 三种 schema；`age_months` 无条件推进、与 `clock` 各自计时；信息保护断言仍恒真（`ministry_access` 全仓无人授予）。
19. **（Task 5 Minor，新增 N5）** `WorldState.game_seed` 仍是裸 int，>2^53 经 JSON 往返丢失（与 `RngService` 已字符串化不对称），会让读档后世界演化静默分叉；须与存档系统任务同批解决。
20. **（Task 5 Minor，测试缺口）** 仍无 `tick → to_dict → JSON → from_dict → tick` 的 `WorldState` 级存档续跑对比测试；建议与存档系统任务同批补齐（可同时兜住 17/19）。

### Task 6 审查新增（均不阻塞 Task 7）

21. **（Task 6 Minor，计划级）** `data/wand_cores.json` 的 `rarity` 声明但 `generate_wand` 均匀抽取（与 Task 5 `weight` 同类）；二选一：实现按 rarity 加权，或删/改述该字段。
22. **（Task 6 Minor）** 玩家自带魔杖只校验 `wood/core/flexibility`，**不校验 `length_inches`**（可传任意值）；且「自带魔杖」分支无任何测试。
23. **（Task 6 Minor）** `p.flags["prejudice_level"]` 把 float 写进 bool 语义的 `flags`；建议提为 `PlayerState` 数值字段，`flags` 只留 bool。
24. **（Task 6 Minor）** `create()` 的 `no_magic`/`p.job=""` 与 `new_default()`/squib `default_flags` 重复（`no_magic` 断言部分空转）；`aptitude.grants` 循环因全表 `grants=[]` 恒空转。
25. **（Task 6 Minor）** `assign_house` 双向 `contains` 子串过宽（单字关键词可放大得分），且性格关键词无数量上限。
26. **（Task 6 Minor，须登记）** 存档载入路径（`PlayerState.from_dict` / `WorldState.from_dict`）**不重跑 `validate_choices`**，「无天赋的特殊资质」等非法组合可经手改存档进入状态；建议随存档任务补一次载入校验。

### Task 7 审查新增

27. ~~**（Task 7 Important）**~~ **已裁定并落地（Human，提交 `a0bc1d3`）**：`energy_loop_count` 采用 **per-turn** 语义——`WorldState.tick()` 在 `clock.advance_month()` 后 `flags.erase("energy_loop_count")`，同回合内累计、每回合（月）重置；`time_rewind_count` 维持 **终身一次性**（上限 1，永不重置）。计划 Task 5/7 已同步，`[spell]` 新增 4 条回归断言（223→227）。Task 8 计划测试（同一回合内连续施法 5 次、中间不 `tick()`）不受影响。注意：per-turn 契约绑定在 `WorldState.tick()`，Task 8 回合推进必须统一经 `tick()`（勿直接 `advance_month`）。
28. **（Task 7 Minor）** `illegal_cast_count` 仅成功时自增，非法施法失败（未遂）不计入法律风险台账（Task 8 会读取此计数）。
29. **（Task 7 Minor）** 被拦截的 `Outcome` 沿用 `failure_rate=1.0`、`roll=1.0`，与「未进入掷骰」语义混淆；Task 8 展示层需以 `blocked` 为唯一判据或补 `rolled: bool`。
30. **（Task 7 Minor）** `legilimens`/`confundo` 的 `legal_risk`、计数器「成功时自增」、`last_serious_mishap_turn`、`time_turner` 把「未拦截」当「允许」、确定性用例弱等价等测试缺口；`portkey` 两条只断言 `blocked` 未断言 reason。
31. **（Task 7 Minor，文档级）** `difficulty` 实为**绝对失败率偏移**（0.02–0.30）而非「相对难度」，与计划表述不符；有意则注明，否则改插值/缩放。
32. **（Task 7 Minor）** fail-closed 稀有度白名单的 `常见` 与简体 `传说` 无独立断言；全角空白（U+3000）/全角拉丁会被过度拦截（安全方向，无绕过）；若 Task 8 的 LLM 层可能产出全角字符，需在归一化前加宽度折叠。

### Task 8 审查新增（均不阻塞 Task 9，但需登记）

33. **（Task 8 Important，计划级）** `StateOps.world_gm_rng` 每次调用都新建 RNG（`game_seed + turn*15485863`）→ 同一回合内所有 `cast_spell` 掷出同一个 `spell_roll`、失败副作用也相同（重复施法与不同咒语结果完全相关）。建议改为引擎持有单一 RNG 并注入，或在派生种子里混入 op 序号/盐；属计划级，交计划 02 / Task 10。
34. **（Task 8 Important，计划级，与 §8#17 同源）** `TurnEngine.rng` 全文从不掷数，真正影响叙事的 `ScriptedGameMaster.rng`（work/social/spell_roll）**未入档**；`world.rng_state` 存的是一个空转 RNG。读档后叙事随机流从头开始（同一「打工」收益恒定、社交掷骰重放），破坏「存档往返一致」不变量。测试 `w8.rng_state.size() > 0` 对此零覆盖。**Task 10 必须补 `submit → to_dict → JSON → from_dict → 重建引擎 → submit` 的端到端对比**，并决定「引擎持有唯一 RNG 并注入 GM」还是「改述为派生式确定性并删除 `rng_state`」。
35. **（Task 8 Important，架构，扩展 §8#3）** `ScriptedGameMaster.act` 直接改世界（`SpellResolver.cast` 写能量/时间/非法施法计数，`Progression.gain` 写 `recent_training`），绕过 `StateOps`（计划内已文档化）。审查新增三条后果：(a) 副作用不进 `deltas_applied`，与第七章「所有变更经 StateOps 便于审计」相悖；(b) 被守卫拦截的施法既无 `op_errors` 也无状态痕迹，调用方无法区分「拒绝」与「正常」；(c) `last_cast_success`/`last_cast_narration` 只有 StateOps 路径会写，生产路径恒为陈旧/未设。留待人类裁定。
36. **（Task 8 Minor）** `TurnEngine.submit` 的 `deltas_applied` 实际是「请求的 delta」（被 StateOps 拒绝的 op 也在其中），字段名误导；建议改名或按 `op_errors` 过滤。
37. **（Task 8 Minor）** `StateOps` 输入硬化缺口：`set_flag`/`set_player_flag` 空 key 静默写 `flags[""]`；`know_fact` 空 `fact_id` 静默写入；`add_money` 非数值静默变 0；`relation_delta` 不校验 `npc_id`、增量无上下限。建议补错误与负例测试。
38. **（Task 8 Minor）** `Progression` 窗口 `turn - entry <= WINDOW_TURNS` 是闭区间（实际保留 13 个回合偏移，与「12 回合内」差一）；`gain==0` 也追加记录，同一回合反复调用可无界累积；键从不 GC（换地点即新建）；「换环境重新计算」导致两地点轮换可把惩罚减半。
39. **（Task 8 Minor，文档级）** 计划 Interfaces 少列 `set_player_flag`、`set_magic_tier` 与 `relation_delta.interest`；`GmResult.audit_required` 无消费者；`tags` 未出现在 `submit` 返回字典（UI 拿不到 cast/train 分类）。
40. **（Task 8 Minor，测试强度）** 空转/弱断言：`cast_result.narration.contains("照明咒") or narration.length()>0`（右操作数恒真）、`w5.clock.year >= before_year` 恒真、`money_before` 未使用、cast 循环未验证计数真的到上限、自检只查标题未查内容且未断言第 14 回合 `audit` 为空、`op_errors` 消息内容未断言；另缺 `set_flag`/`set_player_flag`/`set_magic_tier`/`relation_delta`、`know_fact` 空/`system` 来源、非字典条、blocked 提交不推进回合等负例。建议与 Task 9/10 测试加固批次合并。

### Task 9 审查新增（均不阻塞 Task 10，但需登记）

41. **（Task 9 Minor，扩展 §8#7）** `power_panel` 的「国际」与「麻瓜关系」同映射到 `muggle_relations`，连同已登记的映射共 7 标签→4 变量；纯显示，无新误映射（逐字照抄计划）。见上 §8#7。
42. **（Task 9 Minor，计划级）** 第七十二章第 1 项「人物行为偏离设定」依赖 `npcs[*].ooc_violation`，但该字段在 `src/`、`data/` 全库无写入者 → 生产路径恒为「通过」，检查空转。须由叙事层/未来任务写入，或在计划注明为人工/AI 标注项。
43. **（Task 9 Minor，测试强度）** 负例缺口：`events_block` 空数组、`_top_skill`/`_skills_line` 空技能、`_label` 未知/空 id、`relation_panel` 空关系、非哑炮空魔杖、`snapshot` 空 npcs/pending/history、`ooc_report` 空来源泄露/canon 锚点超前、`is_audit_turn` 负数、哑炮分支仅 2 子串。建议与 §8#8/#40 的测试加固批次合并。
44. **（Task 9 Minor，§8#5 触发）** `Money` 负值显示已经由 `player_panel`/`power_panel` 暴露到 UI；见 §8#5。
45. **（Task 9 Minor，§8#9 同类）** `var rel: Dictionary = p.relations[npc_id]`、`var family: Dictionary = flags.get("family", {})`、`float(world_vars[key])` 在畸形/手改状态下可能运行期报错；建议加 `typeof` 回退，或明确「状态只由 `to_dict()` 产出」。
46. **（Task 9 Minor）** `SelfCheck.ooc_report` 的 `timeline_detail` 在「年份早于锚点」与「canon 事实超前」同时成立时被后者覆盖，只报最后一条异常原因（不影响 yes/no 判定）。

---

## 9. 环境与卫生

- 分支：`plan-01-core-foundation`；工作区在交付时应保持干净（`git status --short` 空）。
- 不要提交：`*.exe`（180MB 引擎）、`.godot/`（导入缓存）、`.superpowers/`（工具工作区）、`*.tmp`、`*.bak`、`export/`、`build/`。
- 无外部服务依赖：不起服务器、不调 LLM、不联网（审查/研究工具除外）。
- 换机器后的自检清单：
  1. `git log --oneline -1` 是个 `docs(handoff)` 提交，且其历史里包含 `432adc8` / `79d15aa` / `153487c` / `eccc871`
  2. 两个 Godot exe 就位，`bash tools/test.sh` → `ALL TESTS PASSED` / `全部通过。` / 退出码 0
  3. `git status --short` 为空（`.godot/` 与 `*.uid` 不应出现新增改动；若 `.uid` 全被改写说明引擎版本不一致，换回 4.7.2）
  4. 读 `docs/sdd/plan-01-core-foundation/progress.md` 末尾，确认与本文第 5、8 节一致
