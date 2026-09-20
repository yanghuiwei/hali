# 计划 03a-P · P3 + P4 实现报告

> 模式：**快跑模式**（不做多组破坏实验 → 只 1 组；不写长 brief/report；不 push）
> BASE：`7f7e803`（开工基线：19 套件 / 1848 断言 / `SCRIPT ERROR=2` / `^ERROR:=7`）
> P5（槽位）**故意未做**——等 UI 切片素材到场，避免尺寸/九宫格返工。

---

## 1. 两个 commit（按要求分 P3 / P4）

### `05abb0d` —— P3（主题）
```
 data/presentation.json                |   3 +--      ← 删掉无消费者的 fonts.numbers
 src/ui/main.gd                        |  10 +++-      ← 运行期挂主题 + 标题字体
 src/ui/theme_builder.gd               |  +109（新）
 src/ui/theme_builder.gd.uid           |    +1（新）
 tests/run_tests.gd                    |    +1
 tests/theme_audio_test.gd             |  +138（新，本 commit 只含主题段）
 tests/theme_audio_test.gd.uid         |    +1（新）
```

### `2518183` —— P4（音频）
```
 src/ui/audio_director.gd        | 176 +++++（新）
 src/ui/audio_director.gd.uid    |   1 +（新）
 src/ui/main.gd                  |  79 ++++-     ← 8 个触发点 + BGM 同步 + 2 个 static 纯函数
 tests/theme_audio_test.gd       | 117 ++++-     ← 音频解析/音量/边界 + 接线纯函数
 tools/b1_acceptance.gd          |  49 ++-       ← 新增「清单 12」
```

> **拆分做法**（说明为什么中间态是可信的）：`main.gd` 与共享测试套件同时承载 P3/P4 两件事，
> 所以先把它们**精确还原成只有 P3 的版本**（脚本替换 + 结构门禁 `grep -c AudioDirector == 0`），
> 单独跑一次 `test.sh` 拿到**中间态 EXIT=0**（19 套件 / `[presentation]=81` / `[theme_audio]=29`）后提交 P3；
> 再把完整版本还原（`md5sum` 校验）提交 P4。中间态不引用未提交的模块 ⇒ 两个 commit 各自可独立构建。

---

## 2. 三条门禁（最终态，重跑于已校验还原的树上）

```
$ bash tools/test.sh
[presentation] 断言=81 失败=0
[theme_audio] 断言=76 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
全部通过。
EXIT=0
SCRIPT ERROR = 2   ^ERROR: = 7        ← 与基线一致，新加的 stderr 噪音门禁通过（无门禁报文）
套件数 19 → 20；断言数 1848 → 1924

$ timeout 300 bash tools/b1_acceptance.sh
  B1 自动验收最终：断言 131 条，失败 0 条
B1 自动验收：全部通过。
EXIT=0
断言数 112 → 131（新增 19 条全 PASS）

$ git status --short
（我改动的 src/ tests/ tools/ data/ 全部入库，`git diff HEAD` 为空）
⚠️ 仓库根另有 **5 个不是我建的** `.ps_*.txt`（`.ps_probe/.ps_probe2/.ps_ref/.ps_setup/.ps_wt`，
   时间戳 17:08~ 持续增长、内容是 git/文件清单探针的 PowerShell 输出）⇒ 见 §5 残余。
```

新增的 **清单 12** 断言（B1，真场景、真处理器）关键几条：
```
[PASS] 根节点挂了 Theme（ThemeBuilder.build 真的被应用）
[PASS] 主题里 Button 的 normal 槽位来自 ThemeBuilder（不是 Godot 默认）
[PASS] cue「turn_submit」被真实流程触发过（seen=["turn_submit","turn_done","faction_revealed","save_ok","load_ok"]）
[PASS] cue「turn_done」被真实流程触发过        ← 同上，由既有流程触发，本函数没自己调过
[PASS] cue「save_ok」被真实流程触发过
[PASS] cue「load_ok」被真实流程触发过
[PASS] cue「audit_ack」由清单 8 的「确认自检」提交触发（重开后的实例）
[PASS] 点「自检」触发 audit_start cue
[PASS] 开局/读档时真的切了 BGM（path=res://assets/audio/bgm/bg_fantasy_theme.ogg）
[PASS] 当前 BGM 指向真实存在的素材 / 是 loop=true 的音频流
[PASS] 未知 BGM key ⇒ 返回 false 且不改变当前 BGM（不切、不停）
[PASS] 8 个 cue 在无 sfx 素材时全部静音返回 false（实际 8/8）
```
⇒ 8 个 cue 里 **6 个由真实流程覆盖**（turn_submit / turn_done / faction_revealed / save_ok / load_ok / audit_ack），
剩 2 个（audit_start / llm_fallback）：audit_start 用「像真点按钮一样」驱动一次；
llm_fallback 的真触发需要一条真降级回合（B2 真机范畴），故只用 `is_fallback_result` 的 static 断言覆盖检测逻辑。

---

## 3. 破坏实验（**只做 1 组**，按快跑模式）

**D1**：把 `load_stream` 的 `ResourceLoader.exists()` 守卫拆掉（让缺素材路径直接进 `load()`）。

```
[theme_audio] 断言=76 失败=0          ← ★ 套件内**完全抓不到**，全部照绿
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
stderr 噪音门禁失败：ERROR=8，期望 7（新增噪音通常是真 bug：JSON 解析失败 / 资源加载失败 / 类型错误）
测试失败：单测=1 冒烟=0 镜像=0
EXIT=1
SCRIPT ERROR=2   ^ERROR:=8
ERROR: Resource file not found: res://assets/audio/bgm/__nope__.ogg (expected type: unknown)
```

**结论（两条都值得记）**：
1. `exists` 守卫承重；缺素材的「静默回退」契约**在断言层不可判别**（连新写的 `load_stream(...) == null` 断言都照绿——
   因为 `load()` 对坏路径仍返回 `null`，差别只在 **stderr 多一行噪音**）。
2. ⇒ **自动噪音门禁不可省**。这是第三次独立证据（P1+P2 的 S2、Task 12 的 D6、本次 D1）。
3. 还原：`cp` 备份 + `md5sum -c` = **OK**（未使用 `git checkout --`）；实验后 `tasklist | grep -i godot` = 无残留。

---

## 4. 授权偏离（与 spec/任务文本不一致处，均写明依据）

| # | spec/任务原文 | 实际做法 | 依据 |
| --- | --- | --- | --- |
| 1 | spec §6 P3「`project.godot` 设默认主题」 | **不改 `project.godot`**，改为 `main.gd:_ready` 运行期挂主题 | 清单是唯一事实来源；提交 `.tres` 会让「改一行 JSON」变成「还要重新生成资源」= 返工 |
| 2 | spec §4「`llm_fallback` 在 `LlmGameMaster._fallback()` 触发时」 | 在 **UI 层**用回合结果的 `op_errors` 里的 §8#61 标记触发；**未改 `src/gm/`** | 任务明确要求：GM 层零改动 ⇒ 不牵动计划 02 既有断言、避开 `_fallback()` 内部接线风险 |
| 3 | 任务：P3 断言「空清单/畸形清单下 `ThemeBuilder.build()` 不崩」 | 已做（含 `null` / `{}` / `"not-a-dict"` 三种） | 与 spec §2 约定 1 一致 |
| 4 | 任务：P5 不在本次范围 | **未做**（已按指示） | 等 UI 切片素材，避免尺寸/九宫格返工 |
| 5 | —（我自己发现的） | **删掉 `data/presentation.json` 的 `fonts.numbers`** | 它没有任何消费者（面板/状态行都是普通 Label/RichTextLabel，Godot 没有「数字字体」主题槽位）。留着就是制造第二个「声明了但无效」的旋钮（§8#16/#21 同类） |
| 6 | 任务：分两个 commit | 已分（见 §1），中间态实测 EXIT=0 | 需要把 `main.gd` 与共享测试套件按 P3/P4 切开；做法与结构门禁见 §1 |

---

## 5. 残余 / 未验证（不偷偷修，如实登记）

1. **仓库根有 5 个非本任务的临时文件**：`.ps_probe.txt` `.ps_probe2.txt` `.ps_ref.txt` `.ps_setup.txt` `.ps_wt.txt`
   （PowerShell 探针输出，时间戳 17:08 起持续新增）。**不是本次任务创建、我也没有删除**（可能属于另一个正在跑的 agent）。
   影响：① `git status --short` 不干净（撞「工作区干净」门禁）；② 有被 `git add -A` 误收的风险。
   建议：让那个进程把临时文件写到 `/tmp` 或仓库外；或给这批前缀加 `.gitignore`。
2. **`AudioDirector` 与 `Presentation` 的安全加载规则重复**（`exists` → `load` → 类型检查各一份）。
   正解是给 `Presentation` 加 `audio(key)`，但**任务明确不许改其冻结 API** ⇒ 保留重复并在两边注释互换指向。
3. **B1 进程退出时多 1 条 `ERROR: N resources still in use at exit`**（变更前 0 条）。
   根因：真场景里播了音频，Godot 在退出时的资源清理噪音。**B1 不在噪音门禁内、EXIT 仍为 0**，故不影响门禁；
   但这是「真播放」的代价，登记备查（若将来想消掉，需要在 B1 退出前显式释放播放器与 stream 引用）。
4. **`llm_fallback` 的真触发路径未在真实降级回合上验证**（需真机 LLM，属 B2 真机联调范畴）；
   本次只覆盖了检测逻辑（`is_fallback_result` 的 7 条断言，含形态异常不崩）。
5. **`fonts.body`（CJK 字体）仍未配置** ⇒ 主题不设 `default_font`，中文可读性仍依赖系统字体回退。
   这是 P3 的已知前置缺口（素材线在做）；`presentation_test` 的条件式硬断言会在字体到场后自动生效。
6. **`ui` / `emblems` / `backdrops` / `portraits` 命名空间仍为空**（对应素材未到场）⇒ P5 未做，槽位不画。
7. **主题只覆盖「界面级」样式**，未做 9-slice 面板底/按钮三态贴图（需 UI 切片素材，属 P5）。
8. **BGM 映射是「全覆盖但复用 4 首」的占位策略**（8 era + 21 location 都指向这 4 个 ogg）。
   人类可直接改 `data/audio_cues.json` 调，**零代码**。`cues` 仍为空表（无 sfx 素材）。
9. **`data/presentation.json` 里删掉的 `fonts.numbers`** 若将来真的需要「数字字体」（如等宽数字对齐），
   需要先有真实消费者（Godot 侧没有对应主题槽位）再把它加回来。
