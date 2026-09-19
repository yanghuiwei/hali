# Tasks 3–5 合并审查简报（reviewer，只读）
只读 read/bash；禁止改文件/写 git。仓库 `E:/Hali`，分支 `plan-02-llm-narrative`。
对象：`a33a33a..HEAD`（Task3 `2544bec` LlmSettings、Task4 `b0d2258` GmResponseParser、Task5 `d888989` PromptBuilder），diff `docs/sdd/plan-02-llm-narrative/review-a33a33a..HEAD.diff`；计划 `### Task 3/4/5`。
核对：
1. `LlmSettings`：`load_from` 默认回退、env `HALI_LLM_API_KEY` 覆盖、`is_configured`、`save_to` 往返；不泄露密钥到日志。
2. `GmResponseParser`：围栏剥离、缺 narrative/非法 JSON/ops 非数组 → 结构化错误；tags 白名单；超长截断到 `MAX_NARRATION`；绝不崩。
3. `PromptBuilder`：**同一 world 两次 build 逐字节相同**；玩家输入被定界；系统提示声明忽略；摘要不含内部 `_` flag、不含密钥；截断阈值与计划一致（log>200→5, >400→0, >800→history2, >1600→0）；`build_repair` 带错误原因。
4. 计划 Task 5 的两处测试修正（system prompt 字面量 `<玩家行动>`、flag 前缀 `_`）是否为唯一正确修法、无夹带。
5. `.uid` 入库；`run_tests.gd` 只追加；无越界改动。
6. 自跑 `bash tools/test.sh`：`[llm] 断言=26`、`[prompt] 断言=11`、17 套件失败=0、`main scene ready`、EXIT=0。
**反证（至少 1 条）**：改动某处（如把 tags 白名单删一项、或把 `MAX_NARRATION` 调小、或把摘要里 `_` 过滤去掉），确认对应断言变红，再还原。
输出：`# Tasks 3–5 审查记录` → 结论（规格✅/裁定/Critical=n Important=n Minor=n）/ 证据（含反证）/ 发现表 / 未验证。
