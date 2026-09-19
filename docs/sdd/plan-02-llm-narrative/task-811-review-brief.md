# Tasks 8–11 审查简报（reviewer，只读）
只读 read/bash；禁止改文件/写 git。仓库 `E:/Hali`，分支 `plan-02-llm-narrative`。
对象：`fed4767`(Task8 LlmGameMaster+warnings)、`878e9e3`(Task9 submit_async)、`c87959e`(Task10 OpenAI provider)、`15c1ff0`(Task11 UI)；diff `docs/sdd/plan-02-llm-narrative/review-fed4767^..15c1ff0.diff`；计划 `### Task 8/9/10/11`；spec §6/§7/§9。
核对：
1. **LLM 绝不直接改 world**：`grep` 确认 `LlmGameMaster`/`OpGuard`/`PromptBuilder`/`GmResponseParser`/`OpenAiCompatProvider` 内没有对传入 `world` 的写操作（只读用于构造提示/净化）。指出任何写点。
2. **`LlmGameMaster.act`**：重试 1 次（provider 失败直接重试；解析失败用 `build_repair` 再试）；两次都失败 → 降级 `ScriptedGameMaster` 且 narration 含 `FALLBACK_NOTE`；`OpGuard.sanitize_detailed` 的 warnings 进 `GmResult.warnings`；deltas 是净化后的 ops。
3. **`TurnEngine`**：`submit()` 对 `LlmGameMaster` 是否 push_error + blocked 且不推进；`submit_async()` 与 `submit()` 是否共用 `_pre_submit`/`_resolve`；`_resolve` 是否把 `GmResult.warnings` 追加进 `op_errors`；§8#34 的 rng 共享与 `world.rng_state = rng.state_dict()` 是否保留。
4. **OpenAI provider**：`_build_body` 默认含 `response_format json_object`；`_parse_http` 非 2xx/非 JSON/缺 choices 是否结构化失败；`complete` 的 HTTPRequest 是否设 timeout；**错误串是否会带 api_key**（应脱敏）。
5. **UI**：`_on_command_submitted` 是否 `await engine.submit_async` 且等待期禁用输入、结束后恢复；`_build_gm` 未配置时是否走 Scripted 并有提示；`_on_start_pressed`/`_on_load` 的 rng 是否与引擎共享。
6. 越界：`git diff --name-only fed4767^..15c1ff0` 仅上述文件 + `.uid`；无 `data/`、`src/model/` 改动。
7. 自跑 `bash tools/test.sh`：`[llm] 61`、`[gm] 63`、全 16 套件失败=0、`main scene ready`、EXIT=0。
**反证（至少 2 条）**：①把 `_resolve` 里 warnings 追加删掉 → 含 `OpGuard` warning 的用例是否变红；②把 `LlmGameMaster` 的 `OpGuard.sanitize_detailed` 换成直接透传 `parsed.ops` → `[llm]` 的净化断言是否变红；③（可选）把 `_build_gm` 强制走 Scripted → 冒烟仍绿但功能缺失。逐条还原。
输出：`# Tasks 8–11 审查记录` → 结论/证据（含反证）/发现表/未验证。
