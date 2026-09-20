# Task 3 报告 · 玩家派系接口（`standing` + 三个 op + OpGuard + 存档校验）

- 任务：计划 03a（派系与政治骨架）Task 3
- 分支：`plan-03-factions`｜提交：**`f6bc495`**
- 绿灯：`bash tools/test.sh` → **EXIT=0**，`==== 总计失败=0，失败套件=0 ====`，`全部通过。`
- 原始日志：`task-3-test-red.log`（红）、`task-3-test-green.log`（绿，提交后复跑）

## 1. 改动文件（只动 brief 列出的 9 个，`git diff --stat` = 9 files, +157/-1）

| 文件 | 改了什么 |
| --- | --- |
| `src/model/player_state.gd` | `var standing: Dictionary`、`STANDING_MIN/MAX`、`standing_of()`、`add_standing()`、`to_dict()` 加 `standing`、`from_dict()` 读回并 `JsonUtil.normalize` |
| `src/rules/state_ops.gd` | 三个新 op：`join_faction` / `leave_faction` / `faction_standing_delta`（插在 `relation_delta` 之后，与 brief 一致） |
| `src/rules/factions.gd` | `visible_faction_ids()`（**最终版**，Task 6 只在其旁加 `reveal()`） |
| `src/gm/op_guard.gd` | `MAX_STANDING_DELTA := 20` + 三个 op 的净化/钳制分支（`join_faction`/`leave_faction` 成组，缺 `faction_id` 只警告并丢弃） |
| `src/persist/save_codec.gd` | `_validate_payload` 增 `player.standing` 必须为对象（**未动** `SAVE_VERSION` 与其他分支） |
| `tests/factions_test.gd` | +17 断言（立场/加入/退出/outlaw 留痕） |
| `tests/save_test.gd` | +10 断言（standing 往返 5 条 + 畸形载荷 3 条 + 专属拒绝理由 2 条） |
| `tests/gm_test.gd` | +8 断言（StateOps 层守卫与端到端） |
| `tests/llm_test.gd` | +4 断言（OpGuard 钳制与 `set_faction_*` 透传拒绝） |

## 2. TDD 红步证据（写测试 → 跑出红 → 实现）

`task-3-test-red.log`：`EXIT=1`，`总计失败=4，失败套件=4`，四个套件**都因缺 API 而中止**（未调用 `report()`，运行器据此判失败）：

```
SCRIPT ERROR: Invalid call. Nonexistent function 'standing_of' in base 'RefCounted (PlayerState)'.
套件未正常结束（未调用 report，运行期错误？）: res://tests/gm_test.gd
SCRIPT ERROR: Invalid call. Nonexistent function 'add_standing' in base 'RefCounted (PlayerState)'.
套件未正常结束（未调用 report，运行期错误？）: res://tests/save_test.gd
SCRIPT ERROR: Invalid access to property or key 'standing' on a base object of type 'RefCounted (PlayerState)'.
套件未正常结束（未调用 report，运行期错误？）: res://tests/factions_test.gd
SCRIPT ERROR: Parse Error: Cannot find member "MAX_STANDING_DELTA" in base "OpGuard".
```

红步 `SCRIPT ERROR` 共 6 条 = 基线 2 条（`save_test` 既有坏档负例：`personality` 赋值 / `int` 构造）+ 我引入的 4 条（上表四条，逐条对应缺失 API）→ 证明红是「缺实现」而不是「写错测试」。

## 3. 绿灯原始输出（提交 `f6bc495` 之后复跑，`task-3-test-green.log`）

```
[probe] 断言=1 失败=1        ← 断言库自检探针，故意失败，不在 SUITES 里
[harness] 断言=8 失败=0
[registry] 断言=212 失败=0
[money] 断言=18 失败=0
[magic_level] 断言=48 失败=0
[model] 断言=49 失败=0
[clock] 断言=47 失败=0
[world_tick] 断言=104 失败=0
[creation] 断言=176 失败=0
[spell] 断言=229 失败=0
[gm] 断言=71 失败=0
[panel] 断言=71 失败=0
[selfcheck] 断言=32 失败=0
[save] 断言=107 失败=0
[async_probe] 断言=2 失败=0
[llm] 断言=88 失败=0
[prompt] 断言=13 失败=0
[debug_mirror] 断言=23 失败=0
[factions] 断言=60 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
…（主场景冒烟 + 调试镜像冒烟）…
全部通过。
```

`EXIT=0`（逐字取自 shell `echo "EXIT=$?"`）。`SCRIPT ERROR` 计数 **2 = 基线 2**（无新增噪音）。

## 4. 断言数前后对比（基线 = Task 2 结束 `19654f0`）

| 套件 | 前 | 后 | Δ |
| --- | --- | --- | --- |
| `[factions]` | 43 | **60** | +17 |
| `[save]` | 97 | **107** | +10 |
| `[gm]` | 63 | **71** | +8 |
| `[llm]` | 84 | **88** | +4 |
| `[registry]` | 212 | 212 | 0 |
| 其余 14 套件 | 不变 | 不变 | 0 |
| 全仓总计（含 probe 1 条自检） | 1320 | **1359** | +39 |

## 5. 守卫证据（每个 op 一条断言）

| 行为 | 断言（文件:行） | 证据 |
| --- | --- | --- |
| `join_faction` 未知 id 拒绝且**不写状态** | `factions_test.gd`「加入未知派系被拒」「被拒的加入不写状态」；`gm_test.gd`「join_faction 未知 id 被拒」 | `StateOps` 返回 `未知派系: …`；`player.faction_id` 仍为 `""` |
| `join_faction` 未揭示派系拒绝（第四十三/五十七章） | `factions_test.gd`「未揭示的派系不能加入」；`gm_test.gd`「未揭示的派系不能加入（第四十三/五十七章）」 | `death_eaters`（`secrecy=secret` → 初始 `revealed=false`）被 `visible_faction_ids()` 挡下 |
| `join_faction` 合法 → 写入所属 | `factions_test.gd`「加入已揭示派系无错误」「所属写入」；`gm_test.gd` 同 | `errors.size()==0` 且 `faction_id=="ministry"` |
| outlaw 加入 → 成功但留痕 + 警告 | `factions_test.gd`「已揭示的 outlaw 派系可以加入」「非法所属被记录进 flags」「非法所属给出警告」 | `flags["illegal_affiliation"]=="death_eaters"` 且返回值含「非法」（不是 rollback） |
| `leave_faction` 清所属、**不清立场** | `factions_test.gd`「退出后无所属」「退出不清立场」 | `faction_id==""` 且 `standing_of("ministry")==100` |
| 立场钳制（StateOps 层） | `factions_test.gd`「立场钳到 100」 | `delta:500` → `standing_of==100` |
| 立场钳制（OpGuard 层） | `llm_test.gd`「standing 增量被钳到上限」 | `delta:999` → `OpGuard.MAX_STANDING_DELTA`(20) |
| 立场反向影响派系态度 | `factions_test.gd`「玩家立场反向影响派系对玩家的态度」；`gm_test.gd`「派系态度反向变化」 | `stance_to_player > 0`（`delta/2`，钳 ±100） |
| LLM 不能动实力/揭示 | `llm_test.gd`「未知 set_faction_* 透传给 StateOps 拒绝，不静默丢弃」+「StateOps 最终拒绝 set_faction_power」 | `OpGuard` 不静默丢弃未知 op，`StateOps` 返回 `未知操作: set_faction_power` |

## 6. 存档证据

- 往返（`save_test.gd`）：`faction_id` / `standing_of("ministry")==42` / `flags["government_type"]` / `factions.size()==17` 四条全过 → `ok=true`。
- 类型守卫负例（**brief 未要求，我补的**，见 §8）：
  - 把 `'{"save_version":1,"player":{"standing":123}}'` 加进既有的 `malformed_payloads` 列表 → 复用原有 3 条契约断言（结构化结果 / `ok=false` / `world=null`）。
  - 另加一条专属断言「拒绝理由指向 standing」：解码返回 `存档载荷字段类型错误：player.standing 应为对象`。
  - 反证：把 `save_codec.gd` 里新增的 5 行注释掉，该载荷会走到 `PlayerState.from_dict` 的 `p.standing = JsonUtil.normalize(123)`（类型化赋值 `Dictionary`）→ 运行期报错；补回后 `ok=false` 且进程不崩。已实测（注释/恢复后 `git diff` 为空）。

## 7. 未验证项 / 残余（诚实登记）

1. `faction_standing_delta` 的**非数值** `delta`（如 `"x"`/`{}`）→ `StateOps` 内联类型判断视为 0，**无断言**（`OpGuard` 侧由 `_to_int` 兜底）。行为安全但未钉住。
2. `stance_to_player += delta / 2` 用的是 GDScript 整数除法（**向零截断**）：`-5/2 = -2` 而非 `-3`。方向正确，奇数列有 1 点不对称；brief 原文如此，未改动。
3. `StateOps` 层的 `delta` **不钳制**（只有 `OpGuard` 钳 20）：手工构造的 ops 数组可一步 `+100`。这是控制器裁定 2 的既定语义（OpGuard 是 LLM 边界），但意味着「可信调用方」才有更强约束——登记为信任边界。
4. `standing` 与 `illegal_affiliation` 目前**没有读取端**（面板/提示词/后果都在 Task 7/8 与 03c）；`illegal_affiliation` 是 write-only。
5. `join_faction` 缺 `faction_id` 时 `OpGuard` 的警告分支（`忽略缺 faction_id 的 join_faction`）**未被断言覆盖**。
6. `leave_faction` 在「本来无所属」时无错误、无提示，未断言（语义为幂等 no-op）。
7. 未做「`standing` 边界端到端」：如 `-100/100` 两端的 `stance_to_player` 符号（当前只覆盖正向）。

## 8. 是否触碰 brief 未列出的文件

**否**。9 个文件全在 brief 的 Files 列表内；`git status` 提交后干净；未新建脚本（无 `.gd.uid` 变更需要入库）。

**唯一超出 brief 逐字片段的两处**（都在 brief 列出的 `tests/save_test.gd` 内、为满足报告契约 ⑥ 的「类型错误被 decode 拒绝」证据）：`malformed_payloads` 数组 +1 条、其后 +2 条专属理由断言。不改变任何生产代码范围。
