# SDD ledger — plan-02：LLM 叙事引擎

分支 `plan-02-llm-narrative`（从 main 拉出）。计划 `docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md`（12 任务）。
流程同计划 01：brief → worker（deepseek-flash）→ 绿灯 → 报告 → 只读 reviewer → 修复轮 + scoped 复审 → 台账。

## Task 1（协程探针 + 运行器 async 化）
- brief `task-1-brief.md`；worker 提交 `ccd08ef`（3 files）：`tests/async_probe_test.gd`(+uid)、`tests/run_tests.gd`（`_initialize`/`_run_suite` 改 await；SUITES +async_probe）。未走备份方案：`SceneTree._initialize` 可 await，实测一次跑绿。
- 绿灯：`[async_probe] 断言=2 失败=0`、13 套件失败=0、`main scene ready`、EXIT=0。
- 审查 `task-1-review.md`：**Approved with findings**，Critical=0/**Important=1**/Minor=1。
  Important：async 化后若套件协程永不恢复，`_initialize` 永久挂起，`quit()` 保证失效（反证：注入 6000s await → timeout 强杀 EXIT=124）。
- 修复 `632ff2e`：`run_tests.gd` 加全局看门狗 `create_timer(SUITE_TIMEOUT_SEC=300)` → `quit(1)`；计划 Task 1 同步。
  反证：看门狗临时改 2s + 注入挂死 → 打印「测试总超时」+ EXIT=1。
- scoped 复审 `task-1-rereview.md`：**通过**。残余 Minor：看门狗是整轮预算非逐套件；不覆盖同步死循环；test.sh 的 import/冒烟无超时。
- 交付点：分支顶端 `632ff2e`。

## Task 2（LlmProvider + MockLlmProvider）
- worker 提交 `a33a33a`（7 files）：`src/gm/llm_provider.gd`、`src/gm/providers/mock_provider.gd`、`tests/llm_test.gd`（各 +.uid）、`run_tests.gd` +1 行。
- 绿灯：`[llm] 断言=9 失败=0`、14 套件失败=0、EXIT=0。
- 审查 `task-2-review.md`：无 Critical/Important；Minor：我的 brief 期望「断言=10」实为 9（计划 Step 1 逐字只有 9 条），worker 如实记录、无需改码。
- 交付点 `a33a33a`。

## Task 3（LlmSettings）`2544bec`
`src/gm/llm_settings.gd`（+uid）；`[llm] 断言=16 失败=0`；审查并入 Tasks 3–5。

## Task 4（GmResponseParser）`b0d2258`
`src/gm/gm_response_parser.gd`（+uid）；`[llm] 断言=26`。

## Task 5（PromptBuilder）`d888989`
`src/gm/prompt_builder.gd`（+uid）、`tests/prompt_test.gd`（+uid）、SUITES +1；`[prompt] 断言=11`。
worker 发现计划测试 2 处自相矛盾并最小修正（系统提示含字面量 `<玩家行动>`；内部 flag 需 `_` 前缀），计划已同步。

## Tasks 3–5 合并审查 `task-345-review.md`
无 Critical/Important；Minor 8 条。修复轮（本提交）：M1 断言不再自指（字面量 4000，反证 MAX_NARRATION=100 会红）、M4 narration 必须字符串 + tags 非数组报错、M5 玩家输入剥离定界符（加注入断言）。
未修（登记）：M2 截断 200/800/1600 分支未测；M3 settings env/坏 JSON 未测；M7 台账类工件混入提交；M8 摘要只截条数不截字节（留 Task 8）。
修复后 `[llm] 28/0`、`[prompt] 13/0`、全绿。

## Task 6（StateOps.train_skill + §8#33）`0a86471`
`[gm] 63/0`、`[spell] 229/0`。

## Task 7（OpGuard）`38589b4`
`[llm] 39/0`。

## Tasks 6–7 合并审查 `task-67-review.md`
无 Critical/Important；Minor：F1 负支出未记警告、F2 spec 措辞与钳制不符、F3/F4 测试覆盖、以及未验证项「OpGuard 对畸形内层类型可能 `int({})` 崩溃」。
修复轮：`_to_int` 让畸形字段回退 0 不崩（反证：去掉后 `[llm]` 套件崩溃、哨兵捕获）、负支出加警告、spec §8 `set_magic_tier` 改为「钳到 ±1」、补 `_gm_rng_counter` 存档往返断言。
修复后 `[llm] 41/0`、`[save] 97/0`、全绿。
