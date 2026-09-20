# Task 10 报告 · UI 等待期看门狗（§8#58/#62）+ provider 复用/timeout/dispose（§8#63）+ Task 9 三条 Minor

① **任务号与提交哈希**：计划 03a Task 10 ｜ `a6fe196`（`plan-03-factions`）

② **改动文件清单**（10 个，+243 / −21）

| 文件 | 改动 |
| --- | --- |
| `src/ui/main.gd` | `turn_timeout_sec`（默认 180，`HALI_TURN_TIMEOUT_SEC` 覆盖）+ `_turn_state` + `_llm_provider`；`_on_command_submitted` 改为「有上限的等待 + 单一恢复出口」；新增 `_run_turn()` / `_render_turn_result()`；`_build_gm()` 先 `dispose()` 旧 provider |
| `src/gm/providers/openai_compat_provider.gd` | 新增 `ensure_http(timeout_ms)` / `http_timeout_sec()` / `dispose()` / `static mask()`；`complete()` 改用二者 |
| `src/gm/scripted_game_master.gd` | M1 `aliases` 类型守卫；M3 退出派系按「是否真是成员」分流（并携带 `faction_id`） |
| `src/rules/state_ops.gd` | M3 第二道门：`leave_faction` 携带 `faction_id` 且不匹配时警告且不清空 |
| `src/gm/gm_response_parser.gd` | M2 `TAG_WHITELIST` 加 `faction` |
| `src/gm/prompt_builder.gd` | M2 提示词白名单行加 `faction` |
| `tests/llm_test.gd` | provider 复用/timeout/dispose/mask（+8）+ `faction` tag 解析（+1） |
| `tests/gm_test.gd` | M1 畸形 aliases（+4，含 1 条判别性）、M3 退出派系四例（+9） |
| `tests/prompt_test.gd` | 提示词白名单含 `faction`（+1） |
| `tools/b1_acceptance.gd` | `HangProvider` / `BrokenProvider` / `_submit_bounded()`（有限等待）+ Part 11 共 9 条 + 接线 |

③ **`bash tools/test.sh` 原始输出**（`task-10-test-green.log`）

```
[gm] 断言=116 失败=0
[llm] 断言=97 失败=0
[prompt] 断言=35 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/4 主场景冒烟（默认配置：必须与未加调试镜像时逐字一致） ==  … main scene ready
== 4/4 调试镜像冒烟（HALI_DEBUG_LOG=1，B1 人工验收的观测通道） == … 全部通过。
EXIT=0
SCRIPT ERROR = 2 条（= 基线 2 条：save_test 的两条刻意畸形载荷负例，逐字同位）
```

红步（`task-10-test-red.log`，改前）：`EXIT=1`，`总计失败=9，失败套件=3`
```
[gm] 畸形 aliases 不得阻断后续派系的识别（旧实现必红）: 期望 <gringotts>，实际 <>
[gm] 非成员退出某派系：不产出 op: 期望 <0>，实际 <1>
[gm] 原归属不被误清: 期望 <ministry>，实际 <>
[gm] 断言=116 失败=7
套件无法实例化（语法错误？）: res://tests/llm_test.gd      ← 调尚未存在的静态方法 mask()，属预期
[prompt] 提示词 tags 白名单含 faction: 期望为真
```

④ **断言数前后对比**：`[gm] 102→116`｜`[llm] 88→97`｜`[prompt] 34→35`｜其余 15 套件不变；B1 探针 **82→91**（+9 = Part 11 全部 9 条：永不返回×4 + await 链抛错×4 + provider 卫生×1）。

⑤ **看门狗「能失败」证据**（破坏实验；按控制器要求一律**保留 deadline、只删输出/恢复**，保证函数一定返回，不让探针挂死）

| 实验 | 改法 | 结果 |
| --- | --- | --- |
| **A** | 删掉 `_set_input_enabled(true)` + `_set_buttons_enabled(true)` 两行 | 探针 `EXIT=1`，**7 条红**：Part 11 的 5 条（永不返回×2 + 抛错×3）+ **Part 9 的 2 条**（`结束后输入框恢复`/`结束后整排按钮恢复`）⇒ 这两行不仅承重，还同时被慢 provider 路径验证（`task-10-expA.log`） |
| **W2** | 只删超时提示行 | 探针 `EXIT=1`，**恰好 1 条红**：`永不返回时：给出恢复提示`（`task-10-expW2.log`） |
| 对照组 | 正式实现 | 探针 `EXIT=0`，Part 11 **9 条全 PASS**（`task-10-probe-green.log`） |

⑥ **provider 卫生的证据**

| 实验 | 改法 | 结果 |
| --- | --- | --- |
| **B** | `ensure_http` 每次新建节点 + `dispose()` 改 no-op | `[llm]` 2 条红：`第二次不重复建（不泄漏）: 期望 <1>，实际 <2>`、`dispose 释放节点: 期望 <0>，实际 <2>` |
| **B2** | 恢复复用，但 timeout 只在建节点时设一次 | `[llm]` 1 条红：`timeout 每次请求都更新: 期望 60.000000 ± 0.001，实际 30.000000` |
| 探针 (c) | — | `[PASS] 切换 provider 不净增 HTTPRequest（dispose 生效）`（`queue_free` 后等一帧再数） |

⑦ **三条 Minor 的断言与能失败证据**

- **M1**：`[gm]` 4 条（畸形 aliases → `_detect_faction` 返回 `""`、label 仍可匹配、`deltas` 为空、**畸形派系不得阻断后续派系的识别**）。红步证实第 4 条在旧实现下必红：`期望 <gringotts>，实际 <>`。
  ⚠️ **对审查诊断的订正（实测）**：`"黑市" as Array` **不是**返回 `null`，而是 `SCRIPT ERROR: Invalid cast: could not convert value to 'Array'` 并**中止 `_detect_faction` 自身**；因为它的返回类型是 `String`，调用方拿到类型默认值 `""` ⇒ **套件并不会中止**，真实后果是「静默降级为未命中 + 每次调用一条 stderr 噪音 + id 靠后的派系被跳过」。第三、四条断言分别钉住「静默降级」与「跳过后续派系」。
- **M2**：`[llm]` 1 条（`faction` tag 不再被过滤）+ `[prompt]` 1 条（白名单行含 `faction`）。实验 C（两处一起回退）→ 两条各红 1 条。
- **M3**：`[gm]` 9 条（非成员退出不产出 op + 旁白说明 + 当前归属 + 原归属不被误清；成员退出产出 op + 清空；StateOps 侧指定别的派系 → 警告且不清空；不带 `faction_id` 的旧调用仍兼容清空）。红步里 6 条在旧实现下必红。

⑧ **未验证项 / 残余**

1. **真机 LLM 等待期**未测（属 B2，用户已裁定暂不做）：看门狗只用 `HangProvider`/`BrokenProvider` 验证逻辑路径；真实 `HTTPRequest` 超时是 30–180 秒级、且 `timeout_ms` 变更现在每请求生效（单测覆盖），但端到端未跑。
2. **超时后后台协程仍在跑**：看门狗只保证 UI 恢复，不取消 in-flight 请求（Godot 无取消语义）。
   ⚠️ **本条已在修复轮 1 订正**：原写法（共享成员 `_turn_state`）下，迟到写一旦发生**不是"被丢弃"而是"污染新一轮"**——`_turn_state["done"] = true` 读的是**成员**，会把 `done=true`（以及上一回合的 result）写进新一轮的字典（机制见修复轮 1 §R3 的语言级实验）。修复后语义才变清晰：迟到只写进**自己那本** `round_state` ⇒ 既不污染新一轮、也不渲染 ⇒ 结果确实被丢弃。至于"迟到请求仍会 `StateOps.apply` 改世界"（M-d）：本轮**实测未发生**（迟到链根本没恢复），保留登记为设计上限。
3. `turn_timeout_sec` 默认 180s 是拍数：思考型模型实测单回合 30–50s，故余量充足；但对「网关挂死」场景要等 3 分钟才恢复（可调 `HALI_TURN_TIMEOUT_SEC`）。
4. `BrokenProvider` 会在探针里产生 1 条 `SCRIPT ERROR`（刻意的 nil 访问），因此 B1 探针的 stderr 条数不再等于基线 —— 探针不参与 `tools/test.sh`，不影响单测噪音基线（`test.sh` 仍为 2 条）。若要彻底干净，可把该 provider 换成「返回 error 响应」的形态，但那样测不到「await 链内部抛错」这一真实场景。
5. `state_ops.leave_faction` 现在在「指定别的派系」时给一条 `errors`（旧行为是静默清空）；对 LLM 路径而言这是**新增提示**，未跑真实 LLM 回归（与 1 同属 B2 范围）。

⑨ **是否触碰 brief 未列出的文件**：是，且都是控制器点名的：`src/gm/scripted_game_master.gd`、`src/gm/gm_response_parser.gd`、`src/gm/prompt_builder.gd`（三条 Minor）；另 **`src/rules/state_ops.gd`** 是 M3 的第二道门所必需（brief 原文即写明「`StateOps` 会忽略未知键、向前兼容」，故在其内加校验属该条授权的范围）；`tests/prompt_test.gd` 为新断言所在（brief 只列了 `llm_test`，但 M2 的提示词侧断言自然归属它）。**未触碰**任何 `data/`、存档格式、`SAVE_VERSION`、第三方依赖。

## 教训（控制器要求写成一行）

**我踩到过一次死锁**：用一个 scratch 脚本验证 `as Array` 语义时，该脚本在 `Invalid cast` 处中止了 `_initialize`、于是**没走到 `quit()`**，引擎空转成孤儿进程（被控制器杀掉）。教训有两条：① 任何 scratch Godot 脚本都必须保证走到 `quit()`，否则用 `timeout` 包住；② 探针/破坏实验本身的**等待必须有上限**（本任务的 `_submit_bounded()` 就是为此设计：不 `await` 被测协程，只轮询「输入框是否恢复」这一可观测信号，并带 5s 上限）——这样即使被测代码没有看门狗，探针也能**干净变红并退出**，而不是把 bash 挂死。破坏实验一律采用「保留 deadline、只删恢复/提示」的形式，绝不让 deadline 变成永不触发。


---

# 修复轮 1（Task 10 审查 Important 1 + 4 条 Minor）

**提交**：`0f11aaf`（只含 `src/ui/main.gd` + `tools/b1_acceptance.gd`，受限 `git add`）

## R1 按计划 `f97f2fc` 落地的四处改动

1. **本轮私有 `round_state`**：主流程 `var round_state := {"done": false, "result": {}}`，`_turn_state = round_state` 仅作调试镜像；**所有判定只读 `round_state`**；`_run_turn(text, state)` 接参并只写自己那本。
2. **恢复两行前置于渲染**：`_set_buttons_enabled(true)` / `_set_input_enabled(true)` / `command_edit.text = ""` 现在排在 `_render_turn_result` 与 `_set_status` **之前**（渲染层任何运行期错误都不得吞掉恢复，§8#62 / M-a）。
3. **`engine == null`**：`_run_turn` 开头早退（不进 await）；另在 `_on_command_submitted` 加**立即恢复**的早退分支。
   ⚠️ 计划文本只写了 `_run_turn` 里的守卫 —— 实测那**不够**：`return` 不置 `done`，看门狗仍要等满 `turn_timeout_sec` 才恢复（首次实测 5010 ms = 探针上限）。故补了 `_on_command_submitted` 的早退分支（`engine == null` → 说明一行 + 立即恢复），实测 **3 ms** 恢复。
4. **`_render_turn_result` 一律 `.get(...)` 兜底**（`narration`/`events`/`op_errors`/`audit`）。

## R2 验收（绿灯）

```
bash tools/test.sh              → EXIT=0；总计失败=0，失败套件=0；全部通过。；SCRIPT ERROR 2 = 基线
timeout 300 bash tools/b1_acceptance.sh → EXIT=0；101 → 105 断言，失败 0（Part 11b 8 条 + Part 11c 3 条全 PASS）
```
（`task-10-fix1-test-green.log` / `task-10-fix1-probe-green.log`；两轮运行后 `tasklist | grep -i godot` 均为 0。）

**M-b 的红→绿证据（3 条断言，本轮唯一有真实判别力的一组）**
- 红（改前，`task-10-fix1-probe-red.log`）：`[FAIL] engine 为空时输入框恢复`、`[FAIL] 恢复是立即的、不等满 30s 超时（实际 5010 ms）`、`[FAIL] engine 为空时整排按钮恢复`
- 绿（改后）：`[PASS] engine 为空时输入框恢复`、`[PASS] 恢复是立即的、不等满 30s 超时（实际 3 ms）`、`[PASS] engine 为空时整排按钮恢复`

## R3 ⚠️ I1 的黑盒可复现性：**实测不可达**（本轮最重要的发现，请控制器裁定如何登记）

**破坏实验结果**（把 `round_state` 改回共享成员 `_turn_state`，其余保持修复版）：

```
timeout 300 bash tools/b1_acceptance.sh → EXIT=0，101 → 105 断言、失败 0（全绿）
[PASS] 第二轮等到自己的结果才结束、没有被旧协程提前判完（实际 3006 ms，期望 ≥2500）
[PASS] 第二轮渲染的是**本轮**的叙事 / 不得混入上一回合的叙事
[PASS] 第二轮真的结算了自己的回合（turn 17 → 18，至少推进 1）
```
即：**共享字典版与修复版在探针里逐条 PASS 一致 ⇒ 我加的这组断言对 I1 无判别力。**

**为什么不可达（两条独立实验）**
1. **观测**：被超时那一轮的迟到提交**从未落地** —— 它的 provider 延迟是 1.5s，而看门狗在 0.4s 就返回；此后 turn 一直稳定（第二轮返回时 18、再等 1.2s 仍 18），说明它既没渲染也没结算（否则 turn 会 +1 到 19）。
2. **即便探针故意持有外层协程引用**（`_submit_bounded(..., hold_ref=true)`）仍然全绿、turn 依旧不动。
   原因：`_run_turn` 是 **fire-and-forget 内层协程**；外层 `_on_command_submitted` 到点返回后，内层挂起链失去唯一引用，被 Godot 丢弃 ⇒ `await` 永不恢复。探针持有的只是**已完成的**外层协程句柄，救不回内层链。

**机制本身成立（语言级实验，`tools/_tmp_late.gd`，跑完即删）**

```
旧写法（await 之后写**成员**字典）：挂起期间成员被换成新字典 B ⇒ 恢复后「A 收到 result? false；B 收到 result? true；B[done]=true」
新写法（显式传参 state）：恢复后「own_b 收到 result? true；当前成员 C 未被写? true」
```
⇒ 审查者的推理链在**语言层面完全正确**：只要迟到写真的执行，共享成员字典版就会污染新一轮。缺的一环只是「它执行不到」——这是 Godot 协程生命周期的实现细节，**不是设计保证**（例如未来若有人 `await _run_turn(...)`、或引擎版本改变持有语义，缺陷立刻可达）。

**我的建议（等控制器裁定）**：修复**保留**（它把「不依赖协程 GC 时序」从隐含假设变成显式不变量，成本为零、语义更清晰；同批的恢复前置 / engine 守卫 / `.get` 兜底都有实测价值），但把 I1 在台账里登记为「机制已证实、**黑盒不可达**（No Repro）」，并**明确写出这组断言不是 I1 的回归护栏**（它们钉的是可观测契约，红步证据只在 M-b）。若控制器认为「不可达就不该按 Important 处理」，可把该条从 Important 降为「已修复的防御性加固 + No Repro」，我不需要再改动代码。

## R4 Minor 处置

| Minor | 处置 |
| --- | --- |
| **M-a** 渲染/状态行与恢复的顺序 | ✅ 已前置（见 R1-2）；**注**：该顺序的可观测差异需要渲染层真的抛错才显现，而 `.get` 兜底后已无已知抛错路径 ⇒ 属**前瞻性护栏**，无红步证据（如实登记） |
| **M-b** `engine == null` 守卫 + 立即恢复断言 | ✅ 见 R1-3 与 R2 的红→绿证据（本轮唯一有判别力的一组） |
| **M-c** `ensure_http` 在 `_host == null` 时不入树 | ✅ **登记备查、未改**（与旧代码一致；`_host == null` 只出现在单测里） |
| **M-d** 超时后旧请求仍会 `StateOps.apply` 改世界 | ✅ **登记备查、未改**；并补一条实测：本轮**未观察到**迟到请求改世界（turn 不变），与 R3 同因 |
| §8.2 结论订正 | ✅ 见页首第 2 条残余的订正段 |

## R5 本轮新增教训（一行）

**"破坏实验全绿"不等于"断言的判别力没问题"，也不等于"缺陷不存在"**：我先把 I1 的断言写成可失败的形状，破坏实验却全绿 —— 正确做法不是把断言改弱凑红、也不是假装红，而是**追到上帝视角的最后一个环节**（这里是 Godot 对无引用挂起链的丢弃），再用一个语言级最小实验把机制本身钉死，最后如实上报「机制成立 / 黑盒不可达 / 断言无判别力」。另外：探针里任何"等待"都必须有上限（`_submit_bounded`），否则破坏实验会把 bash 挂死（本轮再次靠它才敢把 `HangProvider` 放开跑）。
