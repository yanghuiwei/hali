# Tasks 8–11 修复轮 scoped 复审（reviewer，只读）
只读 read/bash；禁止改文件/写 git。仓库 `E:/Hali`，分支 `plan-02-llm-narrative`。diff `docs/sdd/plan-02-llm-narrative/review-15c1ff0..a48f108.diff`。
修复项（对照首轮 `task-811-review.md`）：
- **F3 Important**：`src/ui/main.gd` 等待 LLM 期间除 `command_edit` 外，整排按钮也禁用——`button_row` 升为成员，新增 `_set_buttons_enabled()`，`_on_command_submitted` 首尾调用。
- **F2**：`OpenAiCompatProvider._parse_http` 对 `choices[0]` 非对象返回结构化错误（不再 `as Dictionary` 硬错→返回 nil→降级链断）。
- **F6**：`complete` 对失败 `error` 做 `api_key` 掩码。
- **F1/F5/F4**：补 `warnings→op_errors` 与 `submit()` 拒绝异步 GM 的断言；`_build_gm` 提示改为 `+=` 不再覆盖状态行。
核对：
1. F3 是否真的覆盖“等待期按钮不可点”，有无遗漏按钮/分支；`_on_start_pressed`/`_on_load` 是否仍共享 rng。
2. F2/F6 实现是否正确；F1/F5 新增断言是否可判别（反证：去掉 `_resolve` 的 warnings 循环 → `[llm]` 变红；还原）。
3. 无新缺陷；`git diff --name-only 15c1ff0..a48f108` 仅 `src/ui/main.gd`、`src/gm/providers/openai_compat_provider.gd`、`tests/llm_test.gd`、计划、审查包。
4. 自跑 `bash tools/test.sh`：`[llm] 65`、全 16 套件失败=0、`main scene ready`、EXIT=0。
输出：`# Tasks 8–11 修复轮 scoped 复审记录` → 结论（各修复 ADDRESSED/否、新缺陷、通过/不通过）/证据/残余/未验证。
