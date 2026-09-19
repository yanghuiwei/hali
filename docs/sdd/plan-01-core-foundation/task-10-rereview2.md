# Task 10 第二轮修复 scoped 复审记录

审查者：reviewer subagent（只读复审）　模型：deepseek-flash　范围：09661d0..4729352

## 结论
- save_version 逃逸：**ADDRESSED**
- 毒对象兜底：**ADDRESSED**（null 型毒对象类已闭合；非 null 的嵌套静默降级仍在，登记为残余，非本轮回归）
- 新缺陷：**无**
- 裁定：**通过**

## 证据

### 0. 变更面 / 越界
```
$ git diff --name-only 09661d0..4729352
docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md
src/persist/save_codec.gd
tests/save_test.gd
$ git diff --name-only 09661d0..4729352 -- src/model src/core/turn_engine.gd data | wc -l
0
```
仅简报声明的 3 个文件；`src/model/`、`src/core/turn_engine.gd`、`data/` 未动。计划文档只有 2 个 hunk（save_test 与 save_codec 两个代码块），无夹带。

### 1. save_version 逃逸关闭（独立复现，自建临时探针，审完已删）
载荷校验和正确前提下，`SaveCodec.decode` 实测：
```
{"save_version":null}  → type=TYPE_DICTIONARY keys=["ok","error","world"] ok=false world=null err=「save_version 应为数字」
{"save_version":[]}    → keys=["ok","error","world"] ok=false world=null err=「save_version 应为数字」
{"save_version":{}}    → keys=["ok","error","world"] ok=false world=null err=「save_version 应为数字」
```
三者均为结构化失败字典（含 `ok`/`error`/`world` 三键），不再是空字典 `{}`；`SaveStore.load_slot` 追加 `path` 后语义仍正确。逃逸确实关闭。

### 2. 毒对象兜底（独立复现）
`WorldState.from_dict` 之后的新守卫对 `player/clock` 为 null 一律 `fail`：
```
{"save_version":1,"player":{"personality":123}} → ok=false world=null err=「存档载荷结构不完整…」（stderr 有 Script Error）
{"save_version":1,"clock":{"year":[]}}          → ok=false world=null err=「存档载荷结构不完整…」
```
补充构造（均 `ok=false`，全部被守卫接住）：`player.age_months:[]`、`player.money_knuts:[]`、`player.magic:[]`、`player.wand:"x"`、`player.skills:[]`、`player.flags:[]`、`player.known_facts:[]` —— 机制是错误中断 `PlayerState.from_dict` 使其返回 null，再被守卫判失败。因此**「`ok=true` 且 `world.player==null` / `world.clock==null`」这一类 null 型毒对象已无已知可构造路径**（`world` 其余字段为无类型容器，`normalize` 不会产生 null）。

### 3. 无回归
- 合法往返：JSON 解析出的 `save_version` 实测 `typeof==3 (TYPE_FLOAT)`，`_validate_payload` 前移后仍被接受，`decode(encode(w)).ok==true`；`SaveStore` 读写槽、`rng_state` work 流、端到端续跑断言全部保持。
- 全量测试（清理临时文件后复跑）：
```
[save] 断言=81 失败=0
==== 总计失败=0，失败套件=0 ====
ALL TESTS PASSED
全部通过。   EXIT=0
```

### 4. 测试断言确为判别性（反证后已还原）
临时把 `src/persist/save_codec.gd` 校验顺序改回 `int(save_version)` 在前（去掉前移），仅跑 save 套件：
```
[save] 畸形载荷 #7 必须返回结构化结果（不能是空字典）: 期望为真
[save] 畸形载荷 #7 必须被拒绝: 期望为假
[save] 畸形载荷 #8 必须返回结构化结果（不能是空字典）: 期望为真
[save] 畸形载荷 #8 必须被拒绝: 期望为假
[save] 断言=81 失败=4   SAVE_FAILURES=4
```
`#7`(null) 与 `#8`([]) 均变红，且正是 `res.has("ok")` / `res.get("ok", true)` 两条新断言捕获（`world==null` 那条因缺键取 null 而侥幸通过）。还原后 `git diff --quiet` 为空，`sha256(src/persist/save_codec.gd)==git show 4729352:…`（5db7606c…）。反证也证实 null 同样触发 `int()` 错误（`Nothing` 构造失败），第一轮「null/[] 都会退化为 `{}`」的描述成立。

### 5. 计划文档逐字节一致（复算）
抽出计划 Task 10 三个代码块与工作区文件比对：
```
tests/save_test.gd        plan L3910-4053  IDENTICAL  sha=8cc128541dce9edb
src/persist/save_codec.gd plan L4072-4155  IDENTICAL  sha=5db7606c5a77a254
src/persist/save_store.gd plan L4163-4209  IDENTICAL  sha=27de9705147fd78f
```

### 6. 收尾
临时探针与 runner 已删除（`find . -name "_zz*"` 无结果）；`git status --short` 仅剩 3 个**复审前既存**的未跟踪工件 `docs/sdd/plan-01-core-foundation/review-*.diff`，无新增/未还原改动。

## 残余风险 / 建议
1. **【Minor–Important，既存，非本轮范围】** 嵌套「值」畸形不再产生 null 毒对象，但仍是 `ok=true` 的静默降级（正确容器、错误内层类型）：
   - `player.magic:{"known_spells":123}`、`player.wand:{"wood":123}`、`player.skills:{"a":"x"}`、`player.relations:{"npc":123}`、`player.personality:[123]`、`player.flags:{"a":[]}` 均 `ok=true`；后续 `skill()` / `knows_spell()` 等在使用点才可能报错。
   - `npcs:{"n":123}`、`history:[123]`、`rng_state:{"streams":123}`（`streams` 为 int，`RngService.load_state` 的 `keys()` 使用点有风险）。
   - `clock:{"year":1e400}` → `int(inf)==-9223372036854775808`，`ok=true`，时钟年份为极值。
   建议后续改为「嵌套白名单校验」或在 `from_dict` 内逐字段类型化校验，而非依赖赋值错误。以上第一轮已登记，本轮未扩大。
2. **【Minor】** 被守卫拒绝的畸形载荷（如 `player.personality:123`、`clock.year:[]`）仍向 stderr 打印 `SCRIPT ERROR`。功能契约（返回 `ok=false`、不中断进程）满足，但错误日志噪音会留在正式日志中；根因是 `from_dict` 在守卫前已执行。彻底修法同上（前置嵌套校验）。
3. **【Minor，语义顺序】** `_validate_payload` 前移后，「版本不符 + 字段畸形」同时存在时错误信息优先报字段类型（原为版本不符）。两者都是 `ok=false`，仅影响错误文案优先级，非契约问题。

## 未验证/存疑
- 未做模糊/随机结构遍历；上述残余为定点构造枚举，可能仍有未穷尽的深层类型组合（如 `factions/locations/world_vars` 的内层值、`log` 元素类型、超长/极值数字），未逐一验证。
- 未逐块复算计划中 Task 10 以外的其它代码块（仅按简报复算本任务 3 个成品文件）；也未验证计划文档在 `09661d0` 之前的其它段落是否与既有文件一致。
- 未以真实内存/磁盘 IO 之外的方式验证 `SaveStore` 在极端路径名下的行为（本轮只跑既有测试覆盖的路径）。
