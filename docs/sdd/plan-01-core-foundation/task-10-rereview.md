# Task 10 修复轮 scoped 复审记录

审查者：reviewer subagent（只读复审）　模型：deepseek-flash　范围：dbd93d2..09661d0

## 结论
- Important #1（畸形载荷契约）：**ADDRESSED**（第一轮列出的 7 类全部覆盖、`_validate_payload` 位于校验和之后 / `from_dict` 之前、失败经 `fail.call` → `world=null`；字段清单无遗漏。但存在若干**范围外/既存逃逸**，其中 `save_version` 顶层逃逸未经简报豁免，见「残余风险」，判为 Important 待办，不构成本轮回退）
- Important #2（随机流测试可判别）：**ADDRESSED**（独立反证：删 `turn_engine.gd:46` 后 `[save]` 失败=3，与控制器实测一致，且 `[gm]` 另有一条既存断言也变红）
- 是否引入新缺陷：**无**（`dbd93d2..09661d0` 仅改 3 个文件；逃逸项在 `dbd93d2` 上行为相同，属既存而非回归）
- 裁定：**通过**

## 证据

### 0. 变更面 / 越界检查
```
$ git diff --name-only dbd93d2..09661d0
docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
src/persist/save_codec.gd
tests/save_test.gd
```
- `src/model/world_state.gd`、`src/model/player_state.gd`、`src/core/game_clock.gd`、`src/persist/save_store.gd`、`src/core/turn_engine.gd` **均未改动**；修复只落在 `save_codec.gd` + `save_test.gd` + 计划同步。
- 工作树最终 `git diff HEAD` 为空（我的临时反证改动已 `git checkout` 还原并复核；`git status` 仅剩两个**复审前就存在**的未跟踪工件 `docs/sdd/plan-01-core-foundation/review-*.diff`，非本次新增）。

### 1. Important #1 复核
调用位置（`src/persist/save_codec.gd`，行号为当前文件）：
- L64–66 校验和比对 → L68–70 JSON 类型 → L71 `int(get("save_version"))` → L74–76 `_validate_payload` → **L78 `WorldState.from_dict`**。
- 失败路径 `return fail.call(malformed)`，`fail` 固定返回 `{"ok":false,"error":msg,"world":null}`（L42–44）。

字段清单完整性（对照 `world_state.gd:157-167` 的 `to_dict`，共 15 键）：
- 对象(8)：`clock player npcs factions locations world_vars flags rng_state` ✔
- 数组(3)：`history pending log` ✔
- 数字(3)：`save_version game_seed era_start_year` ✔（`TYPE_FLOAT`/`TYPE_INT` 双接受，合法存档解析出的 float 不会被误拒）
- 字符串(1)：`era_id` ✔。无顶层字段漏检。

独立复算（自写临时探针脚本，跑完已删除）——第一轮 7 类逐条实测：

| # | 载荷 | decode 结果 |
|---|------|------------|
| 00 | `{"save_version":1,"player":null}` | ok=false world=null err=「player 应为对象」|
| 01 | `{"save_version":1,"clock":123}` | ok=false world=null err=「clock 应为对象」|
| 02 | `{"save_version":1,"world_vars":[]}` | ok=false world=null err=「world_vars 应为对象」|
| 03 | `{"save_version":1,"npcs":123}` | ok=false world=null err=「npcs 应为对象」|
| 04 | `{"save_version":1,"history":{}}` | ok=false world=null err=「history 应为数组」|
| 05 | `{"save_version":1,"flags":[]}` | ok=false world=null err=「flags 应为对象」|
| 06 | `{"save_version":1,"rng_state":[]}` | ok=false world=null err=「rng_state 应为对象」|

7/7 覆盖第一轮清单，且 `player:null` / `clock:null`（JSON null → `TYPE_NIL`）也被拒。合法存档不受影响（往返测试继续通过）。

### 2. Important #2 独立反证
临时把 `src/core/turn_engine.gd:46` 的 `world.rng_state = rng.state_dict()` 换成 `pass`，`bash tools/test.sh`：
```
[gm] 回合引擎把随机流状态写回世界: 期望为真
[gm] 断言=38 失败=1
[save] 存档携带已推进的 work 流（下一次抽数等于第 3 次）: 期望 <9>，实际 <17>
[save] 读档后重建引擎续跑：叙事一致: 期望 <…2西可 10纳特。>，实际 <…2西可 13纳特。>
[save] 读档后重建引擎续跑：世界状态一致: 期望 <{…"money_knuts": 5021…}>，实际 <{…"money_knuts": 5024…}>
[save] 断言=62 失败=3
==== 总计失败=4，失败套件=2 ====   EXIT=1
```
与控制器实测「探针+叙事+世界状态」3 条一致；额外 `[gm]` 1 条（`tests/gm_test.gd:137`，**dbd93d2 已存在**，属纵深防御）。反证后还原并复跑：
```
[save] 断言=62 失败=0 ; 总计失败=0，失败套件=0 ; ALL TESTS PASSED ; EXIT=0
```

语义正确性：
- `"我要去对角巷打工赚钱"` 命中 `WORK_KEYWORDS`（scripted_game_master.gd:6、L79），唯一抽数为 `rng.stream_int("work",0,20)`；两次 submit = 消费同一 work 流 2 次。`world.tick()` 内部另建私有 `RngService`（world_state.gd:80/103），不触碰引擎 rng，故检查点携带的正是「已推进 2 次的 work 流」。
- 反证数据印证：清空持久化时读档侧退回第 1 抽（17），而正确第三抽为 9 → 探针确实在比较「第 3 抽」，且证明检查点前恰好消费 2 次（既非 0 次空转，也非更多）。
- `stream_int` 用 `a.eq`（整数精确）替换了旧的 `near(...,1e-7)`，语义更强；仍 20 条，20 条本身在 `rng_state` 为空时会退化为「两边都从首抽开始」而自洽通过，但其非空转性由紧邻的探针兜底，另有端到端块（叙事 + 全量 `to_dict`）强判别——层次合理。

flaky 评估：种子 `20260918` 硬编码，完全确定性，无 flaky。唯一结构性弱点是探针在「首抽==第三抽」时会空转（概率约 1/21）；本例实测首抽 17、第三抽 9 不相等，故当前非空转。**更强写法建议**：在探针前加一条显式非空转守卫，例如
`a.ne(probe_first, expected_third, "探针非空转（首抽≠第三抽）")`，
或直接断言 `RngService.new(seed).stream("work").state != restored_probe.stream("work").state`。种子一旦改动即可自动暴露空转。

### 3. 计划文档同步（逐字节复算）
从计划 Task 10 代码块抽取后与工作区文件 `diff`：
```
tests/save_test.gd       vs plan L3910-4048  → diff 无输出 IDENTICAL  sha256 e1a317b1fdb82401…
src/persist/save_codec.gd vs plan L4067-4144 → diff 无输出 IDENTICAL  sha256 8b93e9b5a92720c3…
src/persist/save_store.gd vs plan L4152-4198 → diff 无输出 IDENTICAL  sha256 27de9705147fd78f…
```
全计划已无残留 `stream_float("continue")`；L2994/L3016 等 `"我要去上课"` 位于更早任务（gm 段），与 Task 10 无关；`turn_engine.gd` 对应的计划块（L3358）未被本提交触碰。无夹带改动。

### 4. 最终全量测试
```
[probe]=1/1（harness 自测，预期失败）
[save] 断言=62 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED   →  EXIT=0
```
（`[save]` 断言数 62 与简报要求一致；无未跟踪/未还原改动。）

## 残余风险 / 建议

1. **【Important，顶层逃逸，未获简报豁免 —— 建议尽快补一轮】** `save_version` 为 JSON null/数组/对象时，L71 的 `int()` 在 `_validate_payload` **之前**执行并抛运行期错误，`decode` 因返回类型 `-> Dictionary` 而返回**空字典 `{}`**（无 `ok`/`error`/`world` 键）。
   - 最小复现（校验和正确）：载荷 `{"save_version":null}`（或 `[]`、`{}`）→ `SaveCodec.decode(...)` 返回 `{}`；`SaveStore.load_slot` 会把它变成 `{"path":…}`，调用方 `res["ok"]` 触发运行期错误 → 仍违反「所有失败路径 `ok=false` 且 `world=null`，绝不崩溃」。
   - 既存性：`int(parsed.get("save_version",-1))` 在 `dbd93d2` 同位置同写法，非本轮回退。修法很小：把 `_validate_payload` 调用**前移**到 L71 之前（或在 L71 先做 `typeof` 守卫）。
2. **【Important，嵌套逃逸，按简报豁免登记】** 顶层为 Dictionary 但内部类型错时，`from_dict` 会中断并留下**毒对象**：`{"save_version":1,"player":{"personality":123}}` → `player_state.gd:97` 报错 → `w.player = null` → `decode` 返回 `ok=true`，`world.player==null`，随后 `world.to_dict()` 在 `world_state.gd:157` 报错；同理 `{"save_version":1,"clock":{"year":[]}}` → `w.clock==null`。
3. **【Minor–Important，嵌套静默降级】** `player.magic/wand/skills` 传错类型（如 `[]`/`"x"`）时字段保持默认值，`ok=true` 但 stderr 有错误日志；`rng_state:{"streams":123}` 被接受，风险转移到后续 `RngService.load_state`（`streams.keys()` 会报错）；`game_seed:1e400`（JSON inf）通过数字检查。均建议在后续轮改为「嵌套白名单校验」或将 `from_dict` 改成不依赖类型化赋值错误。
4. **【Minor，测试强度】** 探针建议加非空转守卫（见上），并可顺带断言 `w2.rng_state["streams"].has("work")`，使「work 流确实入档」成为显式不变式，而非依赖两个抽数值碰巧不等。

## 未验证/存疑
- 我只以只读方式独立复算了 `tests/save_test.gd`、`src/persist/save_codec.gd`、`src/persist/save_store.gd` 三处与计划代码块的逐字节一致；未逐块复算计划中其它任务代码块。
- `save_version` 逃逸的严重度存在口径分歧：若控制器把「合约=所有畸形载荷」作为验收线，则 Important #1 严格应为 **PARTIAL**；本记录按简报「嵌套层登记为残余风险即可」的口径判 ADDRESSED，并把 `save_version`（非嵌套、未豁免）单列为待办，故仍裁定通过。若要求本轮一次性闭合，请以后续小修验收。
- 未做模糊测试（随机字节/随机 JSON 结构）遍历；上述逃逸来自定点构造，可能仍有其它未枚举路径（如超长/极值数字、`era_start_year` 极大值等），未逐一验证。
