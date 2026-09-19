# Task 10 审查记录

审查者：reviewer subagent（只读）　模型：deepseek-flash　范围：`04b0ce7..dbd93d2`

## 结论
- 规格符合：✅（`SaveCodec`/`SaveStore`/`save_test.gd` 与计划当前代码块**逐字节一致**；`run_tests.gd` 仅 +1 行）
- 裁定：**Approved with findings**
- 关键数字：Critical=0，Important=2，Minor=4

## 证据

**提交与范围（`git show --stat dbd93d2`，父 = `04b0ce7`）**
```
 .../2026-09-18-hp-magic-era-01-core-foundation.md  |  21 +++-
 src/persist/save_codec.gd                          |  55 ++++++++++
 src/persist/save_codec.gd.uid                      |   1 +
 src/persist/save_store.gd                          |  47 +++++++++
 src/persist/save_store.gd.uid                      |   1 +
 tests/run_tests.gd                                 |   1 +
 tests/save_test.gd                                 | 111 +++++++++++++++++++++
 tests/save_test.gd.uid                             |   1 +
 8 files changed, 235 insertions(+), 3 deletions(-)
```
无 `src/model/`、`src/gm/`、`src/rules/`、`src/ui/`、`data/` 改动；新增三个 `.gd.uid` 均入库。`git status --short` 提交后仅剩 `?? docs/sdd/plan-01-core-foundation/review-04b0ce7..dbd93d2.diff`（审查包），无实现者诊断脚本残留（`git log --all -- tools/_dbg_*.gd` 为空）。

**逐字照抄核验（自计划当前文本提取代码块，与成品逐字节比对）**
```
tests/save_test.gd          IDENTICAL
src/persist/save_codec.gd   IDENTICAL
src/persist/save_store.gd   IDENTICAL
```
`git show dbd93d2:… | sha256sum` 与工作区文件哈希相同。计划 diff 只有 3 处：强制裁定 2 的端到端块、`expected_draws` 改法、`full_precision` 参数——与报告「计划修正」节的披露**完全一致，无夹带**。`tests/run_tests.gd` 仅在 `"res://tests/selfcheck_test.gd",` 之后追加一条套件路径。
断言数自核：文本 28 处 `a.eq/ne/is_true/is_false/near`，其中 1 处 `a.near` 在 20 次循环内 → **27 + 20 = 47**，与 `[save] 断言=47` 吻合。

**接口签名（对计划 Interfaces）**：`HEADER`/`SAVE_VERSION`/`static checksum(payload:String)->String`/`static encode(world:WorldState)->String`/`static decode(text,registry)->Dictionary`（成功 `{"ok","error","world"}`）一致；`SaveStore` 的 `slot_path/save/load_slot/list_slots/delete_slot` 与计划 Step 4 逐字一致，额外多出的是 Step 4 本有的 `slot_path`。

**独立跑测（`bash tools/test.sh`，单实例，本次复跑原始关键行，退出码 0）**
```
[selfcheck] 断言=26 失败=0
[save] 断言=47 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
== 3/3 主场景冒烟 ==
（跳过：ui/main.tscn 尚未创建，任务 11 将启用）
全部通过。
EXIT=0
```

**独立复核 1：两处偏离**
- **默认精度确实破坏往返**（偏离 A 必要）：自建脚本对同一 2 次 submit 后的状态 `JSON.stringify(d,"",true)`→解析→`from_dict`→`to_dict()`，测得 `world_vars` **6 项**末位不符（如 `war_pressure 0.42157235162258144 → 0.421572351622581`）；报告方向正确。
- **全精度只改数值格式**：`key structure same: true`；`"game_seed":20260918` 仍为整数形式（无 `.0`），`9007199254740993` 亦无小数点；`sort_keys` 仍为默认 `true`，校验和是对同一 payload 串重算，逻辑不变。存档长度 1906→1914 字符（≈+0.4%），单行人可读。
- **`full_precision` 不是精确往返**：`world_vars.secrecy_integrity`（double `0.92107052803039546`）经 `"0.9210705280303955"` 回读变 `0.92107052803039557`，**差 1 ULP**（默认精度下该样本 6 项不符、全精度下剩 1 项）。报告「可精确往返 double / 消除任意 double 隐性丢失」过强。
- **off-by-20 反证**：原写法在第 i 轮比较 `rng_a[20+i]` 与 `rng_b[i]`（同种子同流的不同下标），20 条 `a.near(...,1e-7)` 必然失败，与报告「中间红 21 = 20 随机 + 1 世界状态」一致；改后仍 20 条、容差与文字不变。修正正确且最小。

**独立复核 2：`decode` 失败契约（重点）** — 逐条实测
| 输入 | 结果 |
|---|---|
| 内容过短 `"x"` | ok=false，error 含「内容过短」 |
| 缺标题 / 版本不符（头部） | ok=false，error 含「标题」/「版本不符」 |
| 缺 `checksum:` 行 / 缺 `payload:` 标记 | ok=false |
| 校验和不符（含空串、非 hex `zzz`） | ok=false，error 含「校验」 |
| 载荷非法 JSON（顶层数组、标量 `12.5`） | ok=false，「载荷不是合法 JSON」 |
| 载荷版本 `save_version:99` | ok=false |
| **校验和正确、`player:null`** | **ok=true + world=null**（打印 `SCRIPT ERROR … Cannot convert argument 1 from Nil to Dictionary`，`world_state.gd:177`） |
| **`clock:123` / `clock:[]`** | **ok=true + world=null**（`world_state.gd:176`） |
| **`world_vars:[]` / `npcs:123` / `history:{}` / `flags:[]` / `rng_state:[]`** | **ok=true + world=null**（`world_state.gd:183/178/181/185/186`） |

即：`decode` 本身不中断进程，但对「校验和正确的畸形载荷」返回了 `ok=true, error="", world=null`，`SaveStore.load_slot` 原样透传 `ok=true`。

**独立复核 3：端到端块对 §8#34 的强度（重点反证）**
- 静态：`TurnEngine.submit`（`src/core/turn_engine.gd:46`）才写 `world.rng_state = rng.state_dict()`；`ScriptedGameMaster` 的 `work` 分支用 `rng.stream_int("work",0,20)` 决定收入并写进旁白。
- 实测：`engine.submit("我要去上课")` 后 `rng_state` 只有从未抽数的 `world` 流（train 分支不用 RNG）。
- 反证（等价模拟「删掉第 46 行」：解码后置 `w3r.rng_state = {}` 再重建）：
```
first=我要去上课 / second=我要去对角巷打工赚钱
  cleared narration match: true   | 你忙了一个月，赚到 0加隆 2西可 13纳特。
  cleared to_dict  match: true
```
- 对照：把动作对换成**同一随机流**后，反证生效：
```
first=我要去对角巷打工赚钱 / second=我要去对角巷打工赚钱
  cleared narration match: false  | 13 纳特（应为 10 纳特）
  cleared to_dict  match: false
first=我要去打听消息 / second=我要去打听消息
  cleared narration match: false  | 「对方只是敷衍了几句」vs 原「听人说了一些事」
```
`TurnEngine._init` 确实把 `world.rng_state` 载入**同一个** `RngService` 对象（GM 持的是同一引用），注入链路本身没问题——问题在于检查点里存的是空转 RNG，所以断言测不出缺陷。

**独立复核 4：`SaveStore` 路径与 IO**
```
../../evil -> user://saves/.._.._evil.json      （无逃逸）
..         -> user://saves/...json               （文件名，非上级目录）
<空>/<空白> -> user://saves/slot.json
a/b\c:d    -> user://saves/a_b_c_d.json          （/ \ : 均被替换）
list_slots(缺失目录)=0；delete_slot(缺失)=false；load_slot(缺失): ok=false, world=null（key 存在）
save 返回 {"ok":true,"path":"user://test_saves/rev_diag_slot.json"}；重复 save 覆盖 ok=true
```
`make_dir_recursive_absolute("user://test_saves")`、`DirAccess.remove_absolute` 在本机 4.7.2 正常。无目录遍历/越界写风险。

**`full_precision` 与既有断言（第 6 点）**：`text.contains('"game_seed":20260918')` 为 `true` → 篡改用例仍命中，`SaveCodec.decode` 返回「存档校验失败：内容已被修改」✅。

## 发现
| # | 严重度 | 文件:行 | 问题 | 依据 | 建议 |
|---|--------|---------|------|------|------|
| 1 | Important | `src/persist/save_codec.gd:55`（触发 `src/model/world_state.gd:176-186`） | 校验和正确但字段结构畸形的载荷令 `WorldState.from_dict` 运行期报错，`decode` 返回 `{"ok":true,"error":"","world":null}`，违反计划 Interfaces「所有失败路径都 `ok=false` 且 `world=null`」；`load_slot` 透传 `ok=true`，调用方按 `ok` 解引用 `world` 会空引用崩溃 | 7 组畸形载荷实测均打印 `SCRIPT ERROR: Invalid type/assignment…` 后 `ok=true world=null err=`（进程不中断）。对应 HANDOFF §8#9 / #26 | 在 `decode:55` 前对 `parsed` 关键字段做 `typeof` 校验（失败即 `fail.call`），或把 `from_dict` 调用包进守卫。**最迟在 Task 11 接线「恢复存档」UI 前落地**；否则须显式把契约收窄为「只接受本实现产出的存档」并登记必修债 |
| 2 | Important | `tests/save_test.gd:97-109`（同源 `:88-95`） | 强制裁定 2 的端到端块**测不出** §8#34：首个动作「上课」不消耗引擎 RNG，检查点 `rng_state` 只有空转 `world` 流；「打工」流在两引擎里都首次派生，故删掉 `turn_engine.gd:46` 后断言仍全绿。第 88-95 行 20 次随机流对比同理空转（两边都从同种子新建 `continue` 流） | 反证见上：清空 `rng_state` 后 narration/to_dict 仍相等；改 `work→work`、`social→social` 后立即变红 | 把两次动作改为同一随机流（`打工→打工` 或 `打听→打听`），或先 submit 消耗该流再存档；随机流对比改比 `work`/`social` 等已抽过的流或与参考引擎对比。因该块为简报强制逐字内容，建议由 controller/human 裁定后作为补丁 |
| 3 | Minor | `src/persist/save_codec.gd:12`；`task-10-report.md` 偏离 3.A | `full_precision=true` **不保证** double 精确往返（16 位有效数字）：`secrecy_integrity` 差 1 ULP；报告「精确往返 double / 消除任意 double 隐性丢失」过强，可能误导 §8#19/#20 族债务的关闭判断（另报告把该行写成「第 14 行」，实为 `:12`） | 独立脚本：默认精度 6 项不符、全精度仍 1 项不符；`0.1`、`1/3`、`0.42…` 可往返 | 报告/计划改述为「大幅降低、非保证」；如需硬保证，double 用 17 位或字符串无损序列化；残余风险登记进 §8#19/#20 |
| 4 | Minor | `tests/save_test.gd:63-75` | 测试强度缺口：`slot_path` 净化（`../`、`\`、`:`、空串）、`list_slots` 空目录、`delete_slot` 缺失槽、`checksum("")`、非 hex checksum、多行 payload、CRLF、`save` 覆盖写均无断言；`a.is_true(str(saved["path"]).contains("slot1"))` 只断言子串，未断言完整路径/文件存在 | 静态阅读 + 自建负例（实现里这些分支都存在，测试零覆盖） | 与 §8#8/#40/#43 的测试加固批次合并补负例 |
| 5 | Minor | `src/persist/save_codec.gd:50-55` | 载荷字段缺失/类型宽松：`{"save_version":1}`（无其它字段）返回 `ok=true` 的默认世界；`era_start_year:"x"`、`game_seed:"x"` 静默变 0，无必填字段校验 | 实测 `only save_version ok=true world_is_null=false`、`era_start_year="x" ok=true` | 明确「存档只由 `to_dict()` 产出」，或加最小必填字段校验；随 §8#26 一并裁定 |
| 6 | Minor | `src/persist/save_store.gd:10-21,32-40` | `save` 用 `FileAccess.WRITE` 直接覆盖，无 temp+rename，写盘中断留下半截槽（校验和能兜住载入，但旧档已被毁）；`list_slots` 对名为 `.json` 的文件会 `append("")`，`.JSON` 大小写不识别 | 静态阅读 | 可选：写临时文件再 rename；`trim_suffix` 后判空；大小写归一 |

## 对两处偏离的裁定
- **A. `JSON.stringify(world.to_dict(), "", true, true)`（`full_precision`）**：**必要、最小、无夹带**。独立复现证明默认精度确实使 `to_dict()` 往返失败（本样本 6/7 项末位不符），报告方向正确；该参数只改变数值格式化，**不改字段结构/键序**（`key structure same: true`），**不影响 int**（`game_seed` 仍输出 `20260918`，不是 `20260918.0`），**不改校验和逻辑**（编解码对同一 payload 串重算）；未触碰 `WorldState`/`RngService` 序列化，符合简报第 1 条。**唯一保留**：全精度并非数学意义上的精确，仍存在 1 ULP 反例（发现 #3），故报告「精确往返」表述应改为「大幅降低、非保证」。
- **B. 随机流块 `expected_draws` 修正**：**正确、最小、无夹带**。原写法必然失败（`rng_a[20+i]` vs `rng_b[i]` 同流不同下标），修正后语义严格回归断言文字「读档后第 i 次随机数一致」，仍是 20 条、仍用 `a.near(..., 0.0000001)`，与 `tests/clock_test.gd` 既有模式一致。**但**：该块与强制端到端块一样，对「`rng_state` 是否真的被持久化」是空转（发现 #2）。
- 两处均**已同步进计划原文**；三个成品文件与计划当前代码块逐字节一致，计划 diff 仅披露的 3 处，**无其它未披露偏离**。

## 未验证/存疑
- 未做源码级反证（只读约束），以「解码后清空 `rng_state`」等价模拟删除 `turn_engine.gd:46`；两者在「`w3.rng_state` 初始为 `{}`」这一点上等价，结论可靠。
- `DirAccess.make_dir_recursive_absolute("user://…")` / `remove_absolute` 仅在 Windows + Godot 4.7.2 实测；未跨平台验证。
- `full_precision` 的位数行为限于本机 4.7.2；未验证其它版本是否同样剩 1 ULP。
- `decode` 对 CRLF、多行 payload、超大 payload 的行为未实测（静态推断可工作），也无断言。
- §8#19（`game_seed` int64 >2^53 经 JSON 丢失）按简报本轮未修，仍开放；我未复测大种子。
- 临时诊断脚本（`tools/_rev_diag*.gd` 及其 `.uid`）已删除；`git status --short` 现仅剩审查包，未改动任何仓库文件。
