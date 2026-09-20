# Task 10 审查与修复轮记录 · a36faab..0f11aaf

## A. 首轮审查（审查包 `review-35f43ca..a6fe196.diff`）

> 第 1 次派出的审查者（run 3b253a36）**超上下文/输出上限失败**（150s、输出 29.6k tokens、`windowPeak=64244`、`exitCode=1`）——不是发现不了问题。
> 控制器处置：① 重生成只含代码提交的包（排除控制器 docs）；② 重派时**精简指令**（只判 3 件关键事、其余简答）并限定阅读预算（1 次 diff、≤4 次 grep、报告 ≤120 行）。
> 第 2 次（run 652777a4）成功，结论：**Approved**，Critical 0 / **Important 1（plan-mandated）** / Minor 4。

**Spec ✅**：`turn_timeout_sec`（180 + `HALI_TURN_TIMEOUT_SEC` 覆盖）、`_run_turn`/`_render_turn_result`/`_turn_state`、M1 `aliases` 守卫、M2 两处白名单含 `faction`、M3 三道语义（非成员不出 op + 成员带 `faction_id` + StateOps 指定别的派系警告不清空）、既有 `[gm]`/`[llm]` 断言全保留（`gres.ops[0..3]`/`size()==5` 未受影响）、未改 `data/`/存档格式。
**审查者确认**：`mask()` 覆盖 `complete()` 全部返回路径（含 body 回显；两条提前 return 的串内不含 key）；`dispose()` 同步置 null ⇒ 不存在对已释放节点 `request`；`_build_gm()` 先 dispose 再赋值。

### Important 1（plan-mandated，控制器计划写错）
`src/ui/main.gd:288,304-306`：看门狗与 `_run_turn()` 共用成员字典 `_turn_state`，而 `_turn_state["done"] = true` 是 `await` **之后**的独立语句 ⇒ 超时后迟到恢复的旧协程会把 `done=true` 写进**新一轮**字典 ⇒ 新一轮看门狗提前退出 → 要么渲染上一回合叙事（错位），要么空字典 `result["narration"]` 抛错 → **恢复两行被跳过、输入永久禁用（§8#62 回归）**。
可达性：需「看门狗先触发（>180s）且旧请求之后才返回」（用户把 `timeout_ms` 调到 >180s 或网关慢返回）。

### Minor
- 恢复两行建议前置到渲染/状态行之前（单行级重排，代价为零）。
- `engine == null` 且 `world != null` 时 `_run_turn` 的 `engine.submit_async` 会 nil 崩溃、恢复要等满 180s。
- `ensure_http` 在 `_host == null` 时不入树（旧代码同）。
- 超时后旧请求仍会 `StateOps.apply` 改世界（Godot 无取消语义）。

**控制器**：已改计划 `f97f2fc`（本轮私有 `round_state` + 恢复前置 + engine 空守卫 + `.get` 兜底）→ 修复轮 1。

## B. 修复轮 1（提交 `0f11aaf`，2 files）

> 控制器复核：`bash tools/test.sh` → `EXIT=0`；`timeout 300 bash tools/b1_acceptance.sh` → `EXIT=0`、探针 **101→105 断言 / 0 失败**。
> 控制器另提交 `b257c54`（计划补 `engine==null` 的**立即恢复**分支——实现者发现原稿守卫不够）。

**R1 四处落地**：① 本轮私有 `round_state`（判定只读它，成员 `_turn_state` 仅作调试镜像）；② 恢复三行**前置**于 `_render_turn_result`/`_set_status`；③ `engine == null` 早退（`_run_turn` 内 + `_on_command_submitted` 的立即恢复分支）；④ `_render_turn_result` 全用 `.get()` 兜底。
**R2 红→绿证据（本轮唯一有判别力的一组 = M-b）**：改前 `[FAIL] engine 为空时输入框恢复/恢复是立即的、不等满 30s 超时（实际 5010 ms）/整排按钮恢复` → 改后三条 `[PASS]`（**3 ms**）。

### R3 ⚠️ I1 的黑盒可复现性：**实测不可达（No Repro）**
破坏实验（把 `round_state` 改回共享成员 `_turn_state`）→ **探针仍全绿**（第二轮等到自己的结果、渲染本轮叙事、`turn` 只推进 1）。
两条独立实验：① 被超时那轮的迟到提交**从未落地**（provider 延迟 1.5s vs 看门狗 0.4s；此后 `turn` 稳定不变 ⇒ 既没渲染也没结算）；② 即便探针故意持有外层协程引用（`hold_ref=true`）仍全绿——因为 `_run_turn` 是 **fire-and-forget 内层协程**，外层返回后内层挂起链失去唯一引用、被 Godot 丢弃 ⇒ `await` 永不恢复；探针持有的只是**已完成的**外层句柄。
**但机制成立**：语言级最小实验（`tools/_tmp_late.gd`，跑完即删）证明「只要迟到写真的执行」就会污染——`旧写法：A 收到 result? false；B 收到 result? true；B[done]=true`；`新写法：own_b 收到 result? true；当前成员 C 未被写? true`。

### 控制器裁定（记账口径）
**保留修复**（把「依赖协程 GC 时序」的隐含假设变成显式不变量，成本为零），但把 I1 登记为「**机制已证实 / 黑盒不可达（No Repro）/ 防御性加固**」，并**明确写出那组新断言不是 I1 的回归护栏**（它们钉的是可观测契约）。
**条件性风险（登记）**：将来若有人 `await _run_turn(...)`、或引擎改变挂起链持有语义，缺陷**立刻变可达**——这正是保留修复的核心理由。
另：M-d（超时后旧请求仍改世界）本轮**实测未发生**（同因：迟到链不恢复），保留为设计上限登记。

### R5 实现者教训（一行）
「破坏实验全绿」不等于「断言判别力没问题」、也不等于「缺陷不存在」：正确做法不是把断言改弱凑红、也不是假装红，而是追到最后一环（Godot 对无引用挂起链的丢弃），用语言级最小实验把机制钉死，再如实上报「机制成立 / 黑盒不可达 / 断言无判别力」。

## C. scoped 复审（修复包 `review-f97f2fc..0f11aaf.diff`，审查者 run 5d0e2a5b）

> 结论：**Fix round 1 = Accepted**；四处改动全部落地且判定路径收口到本轮私有 `round_state`；新引入 0 功能问题 + 2 条 P2。

1. **落地且无害** ✅：`round_state` 覆盖全部判定（`:299/303/309/312`）；`_run_turn(text, state)` 只写自己的字典；`.get()` 覆盖 `narration/events/op_errors/audit`（`:323/325/327/329-330`）；恢复三行（`:306-308`）确在渲染（`:312`）与状态行（`:313`）之前。**输入恢复提前无实际影响**（渲染改写 `log_view`、`_set_status` 只读 `world`、三者同步执行无中间帧；唯一语义差异是"渲染抛错时输入仍恢复"，正是本轮意图）。
2. **控制流无漏渲染** ✅：实际是「`engine==null` 早退（`:282-288`）+ 其后完整二分 `if not done / else render`」，不存在"engine 非空且已完成却漏渲染"的路径。
3. **同意「机制成立但黑盒不可达」** ✅：生产路径无任何持有 `_run_turn` 内层句柄的地方（唯一调用点 `:301` 是 fire-and-forget，返回的 FunctionState 立即丢弃）；`_submit_bounded` 的 `_held_co` 持有的是**已完成的**外层。⇒ 应登记为「机制已证实 / No Repro / 防御性加固」。
4. **断言未被伪装成 I1 护栏 — 一处措辞过强（P2-1）**：`tools/b1_acceptance.gd:133`「持有引用才能让『迟到的旧协程』真的恢复」与 `:461`「…（I1：本轮私有 round_state）」与同函数 `:500-501` 的自我否认冲突。最小修：把 `:133` 改为「持有外层句柄仍救不回内层链（见 `_part11b` 注）」，`:461` 标题去掉「（I1：…）」→「（可观测契约，非 I1 护栏）」。
   **P2-2**：`_turn_state` 现为**只写死状态**（`:31` 声明 + `:300` 写），易误认为仍在参与判定 → 可选删除或加 `# write-only mirror` 注记。
