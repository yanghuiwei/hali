# Tasks 8–11 审查记录

> ⚠️ **本文件是重建版，不是 reviewer 原文。**
> 原始 reviewer log（`.superpowers/sdd/2026-09-19-hp-magic-era-02-llm-narrative/task-811-reviewer.log`，约 11.7KB）**已随旧机器丢失**，本机已逐处排除：该 `.superpowers` 目录不存在（本机只有计划 01 的 `2026-09-18-...` 目录）、`~/.pi/agent/sessions/--E--Hali--/subagent-artifacts/` 只有 2026-09-18 的计划 01 worker/oracle/reviewer 工件、`git log --all` 从未入库、`git stash list` 为空。
> **重建依据**：`task-811-review-brief.md`（核对项 7 条 + 要求反证 3 条）、提交 `a48f108` 的修复 diff（`review-15c1ff0..a48f108.diff`）、`task-8/9/10/11-report.md`、`NEXT-STEPS.md` A3、`task-811-rereview-brief.md`（它逐条复述了首轮修复项），以及 **2026-09-20 在 `main` 上实测复跑的反证**（§D，属本次实测，非首轮 reviewer 原始记录）。
> 凡重建素材无法确证之处，本文都显式标注（主要是 F2 的严重度标签与结论措辞）。

---

## 范围与对象

| 项 | 值 |
| --- | --- |
| 分支 | `plan-02-llm-narrative` |
| 对象提交 | `fed4767`(Task 8 `LlmGameMaster`+`warnings`)、`878e9e3`(Task 9 `submit_async`)、`c87959e`(Task 10 `OpenAiCompatProvider`)、`15c1ff0`(Task 11 UI 异步接线) |
| 审查包 | `review-fed4767^..15c1ff0.diff` |
| 依据 | 计划 `### Task 8/9/10/11`；spec §6/§7/§9 |
| 核对项 | 7 条（LLM 绝不直接改 world / `LlmGameMaster.act` 重试与降级 / `TurnEngine` 守卫共用与 warnings 透传 / provider 结构化失败与密钥脱敏 / UI `await` 与等待期禁用 / 越界文件 / 自跑 `tools/test.sh`） |
| 要求反证 | ①删 `_resolve` 的 warnings 追加 → 是否变红；②`OpGuard.sanitize_detailed` 换成直接透传 `parsed.ops` → 净化断言是否变红；③（可选）`_build_gm` 强制走 Scripted → 冒烟是否仍绿 |

## 结论

**Approved with findings** —— Critical=0 / **Important=1（F3）** / Minor=5（F1/F2/F4/F5/F6）。

> 重建说明：6 条发现与「F3 是唯一 Important」来自 `NEXT-STEPS.md` A3 与 `task-811-rereview-brief.md`（后者逐条列出 F1–F6 的修复内容）；**聚合计数 Critical=0 / Important=1 / Minor=5 系由这两处反推**（F2 未在素材中单列严重度，按 Minor 计才能与「6 条中含 1 条 Important」自洽）。

## 发现表

| ID | 严重度 | 位置 | 内容 | 证据 |
| --- | --- | --- | --- | --- |
| F1 | Minor | `src/core/turn_engine.gd:_resolve` / `tests/llm_test.gd` | `GmResult.warnings`（`OpGuard` 的钳制/拒绝警告）虽已追加进 `op_errors`，但**无任何断言可判别**，等于该透传无回归保护 | 修复轮 `a48f108` 补断言（`tests/llm_test.gd` + `# F1：OpGuard warning 必须进 op_errors`） |
| F2 | Minor（重建推定） | `src/gm/providers/openai_compat_provider.gd:_parse_http` | `choices[0]` 非对象时 `(choices[0] as Dictionary).get(...)` 硬错 → `_parse_http` 返回 nil → `LlmGameMaster` 的「解析失败重试 + 降级」链断 | 修复轮加 `typeof(first) != TYPE_DICTIONARY` 护栏 + 断言 `_parse_http(200, '{"choices":[123]}')` |
| **F3** | **Important** | `src/ui/main.gd` | 等待 LLM 期间只禁用了 `command_edit`，**整排按钮仍可点**——「读档」可在 in-flight 回合中替换 `world`/`engine` | 修复轮把 `button_row` 升为成员、新增 `_set_buttons_enabled()` 并在 `_on_command_submitted` 首尾调用 |
| F4 | Minor | `src/ui/main.gd:_on_load` / `_build_gm` | `_build_gm()` 写入的「未配置 LLM」提示被紧随其后的 `status_label.text = PanelFormatter.status_line(...)` 整体覆盖 | 修复轮改 `+=`（部分）；`18eaa5c` 调整顺序后才真正闭合 |
| F5 | Minor | `tests/llm_test.gd` | 同步 `submit()` 对 `LlmGameMaster` 的 `push_error` + `blocked` + 不推进回合这一分支**无断言** | 修复轮补「submit() 拒绝异步 GM」「被拒的同步提交不推进回合」 |
| F6 | Minor | `src/gm/providers/openai_compat_provider.gd:complete` | 失败 `error` 可能回显服务端 body（非 2xx 会拼 `body.substr(0,200)`），未脱敏 `api_key` | 修复轮补 `resp.error = resp.error.replace(api_key, "***")` |

## D. 反证表

**注意：以下为 2026-09-20 在 `main` 上由控制器实测复跑的结果（每条跑完即还原，`git status --short` 为空），不是首轮 reviewer 的原始反证记录。**

| # | 操作 | 预期 | 实测 | 判定 |
| --- | --- | --- | --- | --- |
| ① | 注释掉 `turn_engine.gd:_resolve` 的 `for warning in result.warnings: errors.append(...)` | `[llm]` 变红 | `[llm] 断言=65 失败=1`、`==== 总计失败=1，失败套件=1 ====`、EXIT=1 | ✅ 修复承重 |
| ② | `llm_game_master.gd` 改 `r.deltas = parsed.ops`（绕过 `OpGuard.sanitize_detailed`） | `[llm]` 净化断言变红 | `[llm] 断言=65 失败=1`、EXIT=1 | ✅ 修复承重 |
| ③ | `main.gd:_build_gm()` 强制 `return ScriptedGameMaster.new(rng)` | 冒烟仍绿（UI/LLM 接线不可观测） | `main scene ready`、EXIT=0 | ✅ 证明 headless 盲区（见未验证清单） |

## 未验证清单（首轮即存在，重建后仍成立）

1. **真实 `HTTPRequest` 链路**：`await request_completed`、`add_child`、`HTTPRequest.timeout`、4xx/5xx 的实际行为（单测只覆盖 `_build_body`/`_build_headers`/`_parse_http` 纯函数）。
2. **`api_key` 掩码的端到端执行**：只有静态论证，无「真实错误串带 key → 被掩码」的实跑证据。
3. **提示注入的实际绕过率**：定界 + 系统提示声明 + `OpGuard` + `StateOps` 四层防御未做对抗性实测。
4. **UI 等待期状态**：headless 不可观测（反证 ③ 已证），F3 的最终确认只能靠人工 GUI 验收。
5. **UI 协程卡死边界**：`submit_async` 若永不恢复，输入与按钮停在禁用态（无 UI 层看门狗）。

## 修复与后续

- 修复轮：`a48f108`（F1/F2/F3/F5/F6 + F4 部分）→ 见 `task-811-rereview.md`。
- F4 最终闭合：`18eaa5c`（先写状态行、再建 GM）→ 见 `task-811-rereview.md` 附录（含 2026-09-20 独立只读 reviewer 的 scoped 复审）。
