# Task 10 修复轮 scoped 复审简报（reviewer）

> 只读审查。可用工具：read、bash（仅只读命令 + `bash tools/test.sh`）。禁止修改文件、禁止 git 写操作。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。

## 背景

第一轮审查（记录 `docs/sdd/plan-01-core-foundation/task-10-review.md`）判 **Approved with findings**：
Critical=0 / **Important=2** / Minor=4。控制器已就两条 Important 做修复轮，提交 `09661d0`（父 `dbd93d2`）。
本复审**只针对修复轮**，范围 `dbd93d2..09661d0`，确认两条 Important 是否 ADDRESSED、是否引入新缺陷、是否越界。

## 第一条 Important（对照）

> `SaveCodec.decode` 对「校验和正确但字段结构畸形」的载荷返回 `{"ok":true,"error":"","world":null}`，
> `WorldState.from_dict` 在类型化赋值处运行期报错，违反计划 Interfaces 的「所有失败路径都 `ok=false` 且 `world=null`，绝不崩溃」。

修复：`src/persist/save_codec.gd` 新增 `_validate_payload()`，在校验和通过后、`from_dict` 之前做顶层类型检查。
`tests/save_test.gd` 新增 7 组畸形载荷（手工构造、校验和正确）的负例，断言 `ok=false` 且 `world==null`。

请复核：
- 这 7 组是否覆盖第一轮报告列出的 `player:null` / `clock:123` / `world_vars:[]` / `npcs:123` / `history:{}` / `flags:[]` / `rng_state:[]`；
- `_validate_payload` 是否真的在校验和之后、`from_dict` 之前调用；失败时是否走 `fail.call`（即 `world=null`）；
- 是否存在**未覆盖的顶层字段**或**可绕过**（如 `player` 是 Dictionary 但内部字段类型错、`clock` 是 Dictionary 但 `year` 为字符串等嵌套畸形）——
  若能构造出仍崩溃或仍返回 `ok=true, world=null` 的载荷，请给出严重度与最小复现（嵌套层如实登记为残余风险即可，不要求本轮再修）；
- 修复是否只作用于 `save_codec.gd`，未改 `WorldState.from_dict` / 其它模型文件。

## 第二条 Important（对照）

> 强制端到端块与随机流对比块**测不出** §8#34：首动作「上课」不消耗引擎 RNG，检查点 `rng_state` 只有空转 `world` 流；
> 清空 `rng_state` 后断言仍全绿。

修复：两处动作改为「打工→打工」（消费 `work` 流）；随机流对比块改用 `stream_int("work",0,20)`；
并新增一条「存档携带已推进的 work 流（下一次抽数等于第 3 次）」的探针断言。

请复核并**独立反证**（可临时改代码后 `git checkout` 还原，或在仓库外沙箱做；不要留改动）：
- 删掉 `src/core/turn_engine.gd:46` 的 `world.rng_state = rng.state_dict()`，`[save]` 是否变红（控制器实测 3 条失败：探针 + 叙事 + 世界状态）；
- 修复后两处随机断言是否**语义正确**（仍 20 条、容差/含义是否合理；`stream_int("work",0,20)` 是否确实消费同一个已被推进的流）；
- 是否引入 flaky（同一种子下确定性；`expected_third` 与读档后的抽数依赖 seed 20260918 的具体值是否会偶发相等 → 空转，请评估首两次 draw 与第三次是否可能相等并提出更强写法若有）。

## 其它

- 计划文档 `docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md` 的 Task 10 Step 1/3 代码块是否已同步为修复后的实现
  （控制器已用脚本核验 `tests/save_test.gd`、`src/persist/save_codec.gd`、`src/persist/save_store.gd` 与计划代码块逐字节一致，
  可独立复算）；有无夹带其它改动。
- 是否有 Task 10 范围外文件被改（尤其 `src/core/turn_engine.gd` 是否只是被临时改了又还原、最终 diff 应为空）。
- 跑一次 `bash tools/test.sh`（单实例）确认 `[save] 断言=62 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、退出码 0。

## 输出格式（直接返回文本；controller 转存为 task-10-rereview.md）

```markdown
# Task 10 修复轮 scoped 复审记录

审查者：<reviewer subagent>　模型：deepseek-flash　范围：dbd93d2..09661d0

## 结论
- Important #1（畸形载荷契约）：ADDRESSED / PARTIAL / NOT ADDRESSED
- Important #2（随机流测试可判别）：ADDRESSED / PARTIAL / NOT ADDRESSED
- 是否引入新缺陷：无 / 有（列明）
- 裁定：**通过** / **不通过**

## 证据
<独立反证、测试原始行、逐字节核验>

## 残余风险 / 建议
<嵌套畸形、strength 等>

## 未验证/存疑
```

严重度沿用：Critical=数据损坏/崩溃/规格实质违背；Important=明确缺陷但影响可控；Minor=风格/测试强度/文档。
