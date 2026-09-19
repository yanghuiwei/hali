# Task 11 审查记录

审查者：reviewer subagent（只读）　模型：deepseek-flash　范围：16ba34b..70ad341

## 结论
- 规格符合：✅（计划 Step 1–5/7/8 全部落实，4 条强制裁定全部落实；Step 6 人工 GUI 验收未执行，报告已如实标注）
- 裁定：**Approved with findings**
- 关键数字：Critical=0，Important=2，Minor=5

## 证据

**diff 摘要**（`git diff --stat 16ba34b..70ad341`，7 文件 +296/−18，无范围外文件）
```
 README.md                                          |  10 +-
 .../2026-09-18-hp-magic-era-01-core-foundation.md  |  22 +-
 project.godot                                      |   1 +
 src/ui/main.gd                                     | 265 +++++++++++++++++++++
 src/ui/main.gd.uid                                 |   1 +
 src/ui/main.tscn                                   |  11 +
 tools/test.sh                                      |   4 +-
```
`git status --porcelain` 只有 `?? docs/sdd/plan-01-core-foundation/review-16ba34b..70ad341.diff`（控制器生成的审查包，非 worker 产物）；`src/rules/`、`src/core/`、`src/model/`、`tests/` 零改动。

**逐字对照（独立复核）**：用脚本抽取计划 Step 2/Step 3 的代码块与工作区文件做字节比对，结果 `TSCN IDENTICAL`、`IDENTICAL`——`main.tscn`/`main.gd` 确为逐字照抄（仅应用裁定 1/2），报告「无其它偏离」属实。`grep '\\u\|\x'` 无命中（简报其它要求第 2 条满足）。

**冒烟原始关键行（本次亲自执行 `bash tools/test.sh`）**
```
== 3/3 主场景冒烟 ==
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

main scene ready, godot=4.7.2-stable (official)
全部通过。
EXIT=0
```
2/3 段 13 个套件（harness/registry/money/magic_level/model/clock/world_tick/creation/spell/gm/panel/selfcheck/save）全部 `失败=0`，`==== 总计失败=0，失败套件=0 ====`、`ALL TESTS PASSED`。两段 `SCRIPT ERROR`（player_state.gd:97、game_clock.gd:10）位于 `save_test` 故意坏档负例中，该套件仍 `断言=81 失败=0`，与报告描述一致。

**反证「修改前是假绿」**：`git show 16ba34b:tools/test.sh` 第 24 行为 `if [ -f "$ROOT/ui/main.tscn" ]`，而 `git ls-tree -r 16ba34b | grep ui/` 只有 `src/ui/panel_formatter.gd(.uid)`，`ui/main.tscn` 不存在 → 修改前冒烟必然走 else 分支跳过。报告该断言成立。

**API 独立核对**（未发现误用）：
- `Registry.ids()→PackedStringArray`、`entry()→Dictionary`（registry.gd:50/44），`_add_dropdown` 用法正确；
- `CharacterCreation.create(choices,registry,rng)→Result{player,errors}`，`validate_choices` 要求的键（`era_id/bloodline_id/birth_identity_id/house_id/sim_style_id/political_leaning_id/name_text/age_years/birthplace/personality/life_goal/aptitude_id/aptitude_special/wand`）在 `_on_start_pressed` 中**全部提供**；`birthplace="london_muggle"` 存在于 `data/locations.json`；`personality` 经 `_personality_words()` 转为 `Array`（≥3 项）；
- `WorldState.create(era_id,player,seed,registry)` 与 `world.game_seed/rng_state/clock.turn` 均存在；
- `TurnEngine.submit` 返回结构 `{narration:String, op_errors:PackedStringArray, events:Array, audit:String, blocked:bool}`，`as PackedStringArray` 转型对得上（turn_engine.gd:16/44/46/48）；
- `SaveStore.save` 两分支都带 `path`；`SaveStore.load_slot`/`SaveCodec.decode` 所有失败路径都带 `ok=false`+`error`，成功路径保证 `world!=null`，故 `_on_load` 的 `ok=false` 分支与 `world` 取值**安全**（无空引用）；
- `PanelFormatter.player_panel/magic_panel/relation_panel/power_panel/status_line/events_block`、`SelfCheck.report/is_audit_turn` 签名全部匹配。

**共享 RNG 静态论证（裁定 2）**：见下方裁定节。

## 发现

| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|
| 1 | Important | src/ui/main.gd:174（配合 :46、:52） | 创建失败时把错误写进 `log_view`，但 `log_view` 是 `play_box` 的子节点，而 `play_box.visible=false` 且 `creation_box` 仍在前台 → **错误对玩家完全不可见**，点「开始人生」看起来毫无反应 | `play_box.visible = false`（:46）→ `log_view` 挂到 `play_box`（:52）→ 失败分支只写 `log_view.text`（:174）就 `return`。且该分支**可达**：`bloodlines` 含 `squib`(无魔法) 而 `aptitudes` 含 `squib/special/normal/...`（`data/aptitudes.json`），选「哑炮血统+非哑炮资质」或「非哑炮血统+哑炮资质」或「特殊资质不填具体天赋」都会命中 `character_creation.gd:66-73/85-92` 的校验错误 | 失败时改为写入 `creation_box` 可见的 Label（或先 `play_box.visible=true` 再写、或弹 `AcceptDialog`）；并把错误文本同时 `push_warning` |
| 2 | Important | src/ui/main.gd:60-63、:46、:85-150 | 「读档」按钮位于 `play_box` 内，而 `play_box` 启动即隐藏；`creation_box` 里没有任何读档入口 → **重启后无法直接点「读档」**，计划 Step 6 第 7 条（关掉程序重开→点读档→世界恢复）按字面无法执行 | 启动路径 `_ready → _build_ui → _show_creation`，按钮行 `play_box.add_child(button_row)`；只有 `_on_start_pressed`/`_on_load` 成功后才 `play_box.visible=true`。存在绕行：先随便创建一个有效角色再看得到「读档」按钮 | 在 `creation_box` 放一个「读取存档」按钮（或让 `play_box` 常驻、用禁用态区分），使读档不依赖先创建角色 |
| 3 | Minor | src/ui/main.gd:254-258 | `_on_load` 成功后不刷新 `status_label`、也不重置 `_turn_count` → 读档后顶部状态行仍显示读档前的回合数（与计划 Step 6 第 6 条「状态行回合数与存档前一致」的判读冲突；下一次输入后才自愈） | `status_label.text` 仅在 `_on_command_submitted`（:221）里更新；`_on_load` 只 `_append` 面板 | 读档成功后补 `status_label.text = PanelFormatter.status_line(world) + " ｜ 回合 %d" % world.clock.turn`，并 `_turn_count = world.clock.turn` |
| 4 | Minor | src/ui/main.gd:210 | `_turn_count += 1` 在 `submit` 被拒（`awaiting_audit_ack`/已死亡）时也执行，且该变量**从未被读取** → 死状态 + 潜在误导 | `TurnEngine.submit` 在 `blocked` 时直接返回（turn_engine.gd:22-32），回合数并未推进会；`:194` 声明后全文仅 `:210` 使用 | 删除该变量，或仅在 `not bool(result["blocked"])` 时累加 |
| 5 | Minor | src/ui/main.gd:261-264 | `_on_audit` 一键先打印报告再**立即** `acknowledge_audit()`，「必须读完再确认」的自检语义被弱化为一次点击（第 72 章不变量仍在引擎侧成立，故非功能缺陷） | 同一函数内 `_append(SelfCheck.report(world))` 紧接 `engine.acknowledge_audit()`，'（已确认自检…）' 同屏输出 | 若想保留「确认」仪式感，改为打印报告后仅提示输入「确认自检」，由 `_on_command_submitted` 完成 ack（按钮路径可保留为显式二次确认） |
| 6 | Minor | tools/test.sh:24-33 | 冒烟只判 `smoke=$?`，**不校验 `main scene ready` 输出行**；脚本加载失败但 Godot 退出码为 0 时仍会「全绿」 | 脚本无 `grep` 断言；本次「执行到了」的结论依赖人工读 stdout | 用 `"$GODOT" ... 2>&1 | tee` 后 `grep -q "main scene ready"`，未命中即 `exit 1` |
| 7 | Minor | HANDOFF.md:63、:90、:192 | HANDOFF 仍写 `ui/main.tscn`、仍称「任务 11 之前不存在会打印跳过」，且 §6 的「下一步 Task 11」指针已过期 → 交接文档陈旧 | 简报未把 HANDOFF 列入 Step 7/8，故属未披露但预期之外的收尾遗留；不影响运行/测试 | 下次文档提交时把 HANDOFF §3/§6/§8 指向 `src/ui/main.tscn` 并标记 Task 11 完成 |

## 对 4 条强制裁定的裁定

**强制裁定 1（路径统一 `src/ui/`）——✅ 落实，无夹带。**
- `src/ui/main.tscn`、`src/ui/main.gd` 存在且 `main.gd` 已入库；`project.godot` `[application]` 段为 `run/main_scene="res://src/ui/main.tscn"`（行 8）。
- `tools/test.sh:24` 为 `if [ -f "$ROOT/src/ui/main.tscn" ]`，跳过提示同步为 `src/ui/main.tscn`。
- 计划原文同步 5 处：Task 1 内嵌 test.sh 片段（计划 :356/:360）、Task 11 `Produces`（:4242）、Step 1 说明两处 + `ls`（:4246/:4252）、Step 4 ini（:4552）；「完成后验收」段确无该字样（已核）。
- 全仓功能性残留扫描：`grep -rn "ui/main.tscn"`（排除 `.godot`/`.git`）在 README/计划/源码/脚本中**零命中**；命中项全部落在历史报告、reviewer.log、`docs/sdd/.../progress.md`、旧 review diff 与 **HANDOFF.md**（见发现 7）。不存在「冒烟永远跳过 / 主场景指向不存在场景」的活引用。

**强制裁定 2（GM 与 TurnEngine 共享同一 `RngService`）——✅ 落实，§8#34 保住。**
- `main.gd:177` `engine = TurnEngine.new(world, ScriptedGameMaster.new(rng), rng)`（`_on_start_pressed`，`rng = RngService.new(SEED_SALT + Time.get_ticks_msec() % 100000)` 保留在 :172）；
- `main.gd:252` `engine = TurnEngine.new(world, ScriptedGameMaster.new(rng), rng)`（`_on_load`，`rng = RngService.new(world.game_seed)` 保留在 :251）。
- 计划同步两处：:4455、:4531 均已从 `ScriptedGameMaster.new(RngService.new(world.game_seed + 1))` 改为 `ScriptedGameMaster.new(rng)`。
- **静态论证（不共享则读档后叙事流错误）**：`TurnEngine.submit` 只把 `rng.state_dict()` 写入 `world.rng_state`（turn_engine.gd:46），而真正抽数的 `work/social/spell_roll` 在 `ScriptedGameMaster.rng` 上（scripted_game_master.gd:80/88、spell 分支）。若 GM 另持一个 RNG，则存档快照仅含引擎那个「空转」RNG 的流，GM 已消费的流位置丢失；读档后新建 GM RNG 从头开始 → 同一「打工」收益恒定、社交掷骰重放，正是 HANDOFF §8#34（HANDOFF.md:261）登记的缺陷。共享同一实例后，`state_dict()` 会遍历**同一个 `_streams` 字典**并物化全部命名流（rng_service.gd:33-44），因此 GM 的 `work/social/...` 流位置一并入档；读档时 `TurnEngine._init` 用 `world.rng_state` 调 `rng.load_state()`「替换」`_streams`（turn_engine.gd:11-12、rng_service.gd:46-55），GM 因持有同一对象而自动续上原流。对照组即 Task 10 `tests/save_test.gd:99-141` 的端到端块（同款 `ScriptedGameMaster.new(rng), rng`，断言「读档后重建引擎续跑：叙事一致 + 世界状态一致」），共享写法的语义与该绿灯测试一致。残余说明（非缺陷）：若在**首次 submit 之前**存档，`world.rng_state` 仍为 `{}`，读档后 RNG 以 `game_seed` 重播；因角色创建消费的是 `wand_*/aptitude/capacity/...` 等独立命名流、GM 叙事流此时尚未被消费，行为等价，无可观测偏差。

**强制裁定 3（`.uid` 入库）——✅ 落实。** `src/ui/main.gd.uid`（内容 `uid://br7t3krpq1nid`）已入库（`git show --stat` 含该文件、`git ls-files src/ui/` 可见）；计划 Step 8 的 `git add` 已同步补上 `src/ui/main.gd.uid`（:4637）。未给 `.tscn` 造多余 `.uid`。

**强制裁定 4（README 增量收尾）——✅ 落实，未被短版覆盖。** 对照 `git diff 16ba34b..70ad341 -- README.md`：只改 4 处——「当前进度」措辞改为「计划 01 · 核心模拟地基 已完成」并补可游玩说明、任务 11 `下一步`→`✅ 完成`、运行节去掉两处占位说明并注明主场景、`src/ui/` 目录条目改为「Godot 主场景与主界面 + 面板格式化」。README 现有的正典规格/计划/HANDOFF/**台账**链接、11 行进度表、目录约定、存档位置、8 条设计不变量全部保留，与最终代码一致（含 `src/persist/`、`src/ui/`、`slot1.json`）。计划 Step 7 标题已由「写运行说明/创建 README.md」改为「收尾 README.md（不要整篇覆盖…）」，但**计划正文仍内嵌那份短版 README 代码块**——该块现与仓库 README 不一致，属计划历史文本而非交付物，不构成夹带。

## 未验证/存疑（含人工 GUI 验收缺口）

- **计划 Step 6 的 8 项人工 GUI 验收全部未执行**，headless 下 `--quit-after 5` 只跑到 `_ready → _build_ui → _show_creation`（冒烟确认的唯一事实是「主场景与脚本能加载、7 个下拉框与表单能构建、无脚本错误」）。报告已按要求明确写「待人类执行」，标注属实。
- **未被任何自动化覆盖的关键路径**（残余风险清单）：
  1. `_on_start_pressed` 点击路径：`_selected()` 取 metadata、`_personality_words()` 转换、`WorldState.create` 参数传递、`creation_box/play_box` 切换——冒烟从不点击按钮；
  2. 创建表单交互（下拉选择/年龄 SpinBox/姓名与目标输入），尤其**发现 1 的不可见错误分支**只有人工点击才会暴露；
  3. 存档/读档按钮路径（`SaveStore.save/load_slot` 接线、`user://saves/slot1.json` 实际落盘）——单测用的是 `test_dir`，未走 UI；
  4. **发现 2 的「重启后读档」**在 UI 上按字面不可达，必须在人工验收时确认是「需要先创建角色」还是判定为缺陷；
  5. 第 15 回合挂起交互（`awaiting_audit_ack`）：UI 提示文案、继续输入被拒、输入「确认自检」解禁、`自检` 按钮一键 ack（发现 5）——回合是 `world.tick` 内部推进，单测覆盖引擎侧，UI 侧提示/解禁流程未被自动化；
  6. 「练习收益递减」「打工加钱」「魔法/关系/势力面板」在真实窗口中的可读性与渲染（`RichTextLabel.scroll_following`、按钮行布局）。
- **存疑（不影响裁定）**：`_on_load` 在 `ok=true` 时依赖 `SaveCodec` 保证 `world!=null`（已核 save_codec.gd:78-83）；这一「调用方不再防御」与 HANDOFF §6 第 1 条「调用方仍需防御」的字面要求略有张力，但当前契约下无空引用风险。
