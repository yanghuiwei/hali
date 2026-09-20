# `fix/plan-02-llm-settings` 复审记录（2026-09-20）

> 对应 `NEXT-STEPS.md` B2 的阻塞项 `HANDOFF §8#66` / `§8#67`。修复提交 `3240af6`（+ 复审跟进的 `c9a0c95`）。
> 复审方式：项目约定 §D2「审查者只读」——内置 `reviewer` agent（`read/grep/find/ls`，`deepseek-flash` + thinking high，与主会话同模型），范围 `da77074..3240af6`。**工具集无 bash/git**，其"未验证清单"已如实列出（下面原文 §2）。
> 溯源：async 目录 `C:\Users\yhweix\AppData\Local\Temp\pi-subagents-user-yhweix\async-subagent-runs\5f8c824b-cb52-4c91-9fce-bc80139f3e63`（临时）；会话文件 `~/.pi/agent/sessions/--E--Hali--/2026-09-20T01-38-44-227Z_01a0bc77-.../6adcdb96-f5d9-4f16-ae9f-8860fce447ea/run-0/session.jsonl`。

## 1. 结论与处置

**复审结论：通过（OK with notes）** —— 6 个核对点全部成立，**0 Critical / 0 Important**，3 条 Minor（2 条属范围外/报告项，1 条为断言强度）。

| 复审项 | 内容 | 处置 |
| --- | --- | --- |
| 1 | 两条造 request 的路径（`build` / `build_repair`）是否都覆盖、有无第三条遗漏 | ✅ 覆盖完整（全仓仅 `llm_game_master.gd:31/40` 两处外部调用、`LlmRequest.new()` 仅 `prompt_builder.gd:10` 一处） |
| 2 | 构造函数加可选第三参是否向后兼容 | ✅ 兼容（新参追加末尾默认 `null`；全部调用点核对无误；`settings==null` 与修复前逐字等价） |
| 3 | 三字段覆盖完整性 / 有无副作用越界 | ✅ 三字段全灌；`json_mode` 与提示词未被触碰；附带正向效果：`_http.timeout` 才真正反映配置（此前恒 30000） |
| 4 | `status==0` 是否误伤非 2xx、取值链是否安全、三元写法 | ✅ 互斥（正常状态码恒 ≥100）、前置护栏已保证 `first`/`message` 为字典、语法无陷阱 |
| 5 | 新增断言是否可判别 | ✅ 可判别（逐条对齐：空操作 → 红；`requests[1]` 确为 repair 路径） |
| 6 | 越界 / 夹带 | ⚠️ **只能有限确认**（无 git，无法列真实文件清单） |
| **M-a** | `LlmSettings.provider` 全仓无读取端（只有一种实现） | 📌 **登记** `HANDOFF §8#68`（计划 03 做 provider 路由时顺手） |
| **M-b** | `content` 为 JSON `null` 时 `str(null)` 可能变非空串 → `ok` 误判 | ✅ **复审后实证确认并修复**（见 §3） |
| **M-c** | `[llm]` 的「向后兼容」断言只覆盖 `max_tokens` | ✅ **采纳**，扩为同时断言 `temperature` / `timeout_ms` |

## 2. 复审原文（verbatim）

```text
# fix/plan-02-llm-settings 复审记录

> 方式：只读静态复审。已用 `read` 逐字读取 4 个改动文件当前内容，并交叉读取其依赖（`llm_provider.gd`、`llm_settings.gd`、`prompt_builder.gd`、`mock_provider.gd`、`game_master.gd`、`tests/assert.gd`、`tests/run_tests.gd`）与历史 diff 归档以确认"改动前"基线。**工具集无 bash/git，未实跑任何测试、未做 `git diff`。**

## 结论（通过 / 不通过）
**通过（OK with notes）**：6 个核对点全部成立，未发现阻断性缺陷；仅有 3 条 report-only 备注（2 条为既有/范围外，1 条为断言强度）。

## 逐项核对

### 1. 两条造 request 的路径是否都覆盖，有无第三条遗漏 —— ✅ 覆盖完整
- 首次：`src/gm/llm_game_master.gd:31` `var request := _apply_settings(PromptBuilder.build(world, action_text))`
- 修复重试：`src/gm/llm_game_master.gd:40` `request = _apply_settings(PromptBuilder.build_repair(world, action_text, parsed.error))`
- `build_repair` 内部虽再次调用 `build()`（`src/gm/prompt_builder.gd:26`），但其返回值仍经 `:40` 的 `_apply_settings` 包裹，故覆盖。
- 第三条路径排查（全仓搜索）：
  - `provider.complete(` 仅 `src/gm/llm_game_master.gd:35` 一处调用（`grep` 命中：`src` 下唯一调用点）。
  - `LlmRequest.new()` 仅 `src/gm/prompt_builder.gd:10` 一处构造。
  - `PromptBuilder.build` 在 `src` 下仅 `llm_game_master.gd:31/40` 两处外部调用（其余为 `prompt_builder.gd` 内部 `build_repair→build` 与测试 `tests/prompt_test.gd`）。
  ⇒ `src` 内没有第三条进入真实请求的构造点，无遗漏。

### 2. 构造函数加可选第三参的向后兼容 —— ✅ 兼容
- 签名 `src/gm/llm_game_master.gd:12` `_init(provider_ = null, fallback_ = null, settings_ = null)`：新参**追加在末尾且默认 `null`**，2 参调用不受影响。
- 全部调用点核对（`grep LlmGameMaster.new`，`src`/`tests` 内）：
  - `src/ui/main.gd:210` → 3 参，位置正确 `(provider, ScriptedGameMaster, settings)`。
  - `tests/llm_test.gd:121/130/134/173` → 2 参；`:148` → 3 参 `(sp, ScriptedGameMaster, cfg)`，位置均与形参顺序一致。
  - `src/gm/*.gd` 内无其它 `LlmGameMaster` 实例化点。
- `settings == null` 行为：`_apply_settings`（`:21-25`）在 `settings != null` 才赋值，否则原样返回 `req`，`act()` 逻辑其余分支未变 ⇒ 与修复前逐字等价（`_fallback`、重试、`OpGuard` 全部未动，`:27-56`）。

### 3. 字段覆盖完整性 / 副作用边界 —— ✅ 完整且无越界
- `temperature` / `max_tokens` / `timeout_ms`：`src/gm/llm_game_master.gd:23-25` 三行全灌。
- `json_mode`：`_apply_settings` 未触碰；`PromptBuilder.build` 不设 `json_mode`（`prompt_builder.gd:9-14`），保持 `LlmRequest` 默认 `true`（`llm_provider.gd:12`），`OpenAiCompatProvider._build_body` 据此写 `response_format`（`openai_compat_provider.gd:38-39`）⇒ `json_mode` 与提示词内容均不受 settings 影响（测试 `tests/llm_test.gd:204` 仍验证 `json_mode` 生效）。
- `LlmSettings` 其余字段：`base_url`/`model`/`api_key` 由 `main.gd:210` 的 `OpenAiCompatProvider.from_settings` 消费（`openai_compat_provider.gd:16-17`）；`provider` 字段全仓无读取（`grep 'settings\.provider'` 零命中）——见新发现 M2（既有、范围外）。
- 附带正向效果：`timeout_ms` 灌入后，`complete()` 首建 `HTTPRequest` 时 `_http.timeout`（`openai_compat_provider.gd:84`）才真正反映配置（此前恒为 30000）。

### 4. `openai_compat_provider.gd` 新错误串 —— ✅ 无误伤、不崩、三元写法安全
- `status == 0` 分支（`openai_compat_provider.gd:45-47`）在通用非 2xx 判定（`:48`）**之前** `return`，两者互斥：`status` 取 `result[1]`（HTTP `response_code`），正常 HTTP 响应码恒 ≥100，故非 2xx（如 500）走 `:48` 不会被 `status==0` 截走（测试 `llm_test.gd:211-212` 仍验证含 `500`）。`status==0` 只对应"无响应/连接失败/超时"，语义正确。
- 空 `content` 分支取值链安全：`:67` `str((first as Dictionary).get("finish_reason", ""))` 之前，`:60-62` 已对 `first` 做 `typeof(first) != TYPE_DICTIONARY` 护栏并 `return`；`:63-66` 对 `message` 同样护栏。故 `first`/`message` 均为合法 `Dictionary`，`.get(...)` 不会崩（畸形响应：`llm_test.gd:216` `{"choices":[123]}` 已验证不崩）。
- 三元写法：`:73` `finish if not finish.is_empty() else "未知"`、`:74` `"…" if finish == "length" else ""`——GDScript `A if cond else B` 语法合法；两处均位于 `% [...]` 数组字面量元素内，逗号分隔，无优先级陷阱；`finish` 非保留字。

### 5. 新增 `[llm]` 断言可判别性 —— ✅ 可判别、对象正确
- 计数自证：`tests/llm_test.gd` 断言调用共 **79** 条（逐行清点 `a.eq/is_true/...` 命中行号 14…226），与文档"65→79"一致；新增块 `:150-159`（8 条）+ `:218-226`（6 条）= 14 条，`79-14=65` 吻合基线。
- 判别力（非恒真）：
  - `:151-153` 断言 `sp`（带 `cfg` 4321/0.42/55555）的**首次**请求字段；若 `_apply_settings` 空操作则得到类默认 0.8/1024/30000 → 红（与"反证① → 5 条红"一致）。
  - `:155-156` 针对 `sp.requests[1]`，而 `sp.queue[0]="不是 JSON"` 触发解析失败 → 第 2 次走 `build_repair`（`llm_game_master.gd:40`），故这两条**真实验证了 repair 路径**也带 settings（若只覆盖首路径则 `requests[1]` 为默认值 → 红）。
  - `:219-226` 针对 `_parse_http` 的 `status==0` / `finish_reason=length` / `stop`，均对**实际返回对象**断言 error 串内容，非恒真（"反证② → 3 条红"与只回退含糊文案时恰有 3 条 content 相关断言变红吻合）。
- `:159` 的"向后兼容"断言：对象是 **`provider`**——即 `tests/llm_test.gd` 前半段 `LlmGameMaster` 块里的 `MockLlmProvider`（`:121` 处 `LlmGameMaster.new(provider, scripted)`，**2 参、无 settings**），其 `requests[0]` 正是 `gm.act` 首次 `build` 请求。故该断言确在验证"未传 settings → 沿用类默认 1024"。断言对象正确，非错位。

### 6. 越界 / 夹带 —— ⚠️ 只能有限确认（见"未验证清单"）
- 无法执行 `git diff da77074..3240af6`；仓库内亦无该范围的 diff 归档（`find **/*.diff` 无匹配此 range）。
- 可就 4 个文件当前内容判断：改动集中且自洽（GM 加 `settings` 注入、`main.gd:210` 单行传参、provider 两处 `_parse_http` 错误串、测试 +14 断言）；4 个已读文件中未发现与本修复无关的逻辑改动。
- 其它文件（`HANDOFF.md:334-335`、`NEXT-STEPS.md:94/129-130`、`.git/COMMIT_EDITMSG`）含 `3240af6` 字样，属提交后/文档性更新，非本次 4 文件范围（提交本身是否夹带这些文档我无法判定）。

## 新发现（标 Critical/Important/Minor）
- **Minor（报告项，范围外）**：`LlmSettings.provider`（`llm_settings.gd:6`）全仓无读取端（`grep settings\.provider` 零命中），仅作 JSON 往返保留。当前只有一种 provider 实现，故非本 bug 范畴，也与"三字段"无关，仅登记。
- **Minor（报告项，范围外、既有行为）**：`openai_compat_provider.gd:68` `r.text = str((message).get("content", ""))`——若 `content` 为 JSON `null`（键存在值为 null），`str(null)` 可能为非空串而使 `:69` `r.ok=true`。该行**属既有代码、不在本 diff 新增**，且不同网关通常以 `""` 或缺键表示空内容。我未能实跑确认 `str(null)` 的确切返回，故仅作提示，不作为本提交的问题。
- **Minor（本 diff 相关，仅强度）**：`tests/llm_test.gd:159` 向后兼容断言只覆盖 `max_tokens`，未同时断言 `temperature`/`timeout_ms` 的默认值；且该断言在"修复态"与"空操作态"下都通过，属**护栏**而非修复判别器（真正判别修复的是 `:151-156`）。最小改进：把 `:159` 扩为同时断言 `temperature==0.8` 与 `timeout_ms==30000`。不阻塞。

均无 Critical / Important。

## 未验证清单
1. **无 bash/git：未实跑 `bash tools/test.sh`，未执行任何 `git` 命令。** 因此对运行期行为（`_apply_settings` 实际注入、`_parse_http` 实际返回串、`[llm] 79` 真实输出、反证红数）的结论**全部为静态推理**，仅与控制器提供的证据（16 套件失败=0、`[llm]`79、反证①②的红数）**一致/不矛盾**，而非我复现。
2. **未能独立核对提交范围**：无法列出 `da77074..3240af6` 的真实文件清单，故"除 4 文件外无无关改动"结论仅基于"任务声明 + 4 文件内容自洽"，未做 `git diff --name-only` 验证。
3. **真机回归**未复现（无内网网关、无网络）；`content` 恒空 → 降级、settings 生效后不再降级 等真机现象未验证。
4. **`str(null)` 语义**未实跑确认（见新发现 M-b）。
5. **GDScript 语法/类型检查**未运行 `godot --check-only`；三元表达式与 `.get()` 类型安全为人工判读。
6. **UI 路径**（`main.gd:_build_gm` 在 `_on_start_pressed`/`_on_load` 的实际调用）未 headless 实测。

**Merge verdict: OK with notes**（3 条均为 Minor/report-only，无阻断项）。
```

## 3. 复审 M-b 的实证与修复（`c9a0c95`）

复审说"未能实跑确认 `str(null)`"——控制器用一次性探针实测，**确认它是真缺陷**：

```
str(null) = [<null>]  len=6
typeof(null)==TYPE_NIL ? true
JSON null -> typeof=0 str=<null>
_parse_http(content:null)   -> ok=true  text=[<null>] error=[]          ← 误判成功
_parse_http(缺 content)     -> ok=false text=[]       error=[响应内容为空（finish_reason=stop）]
```

即 `{"content": null}` 会被判为**成功**，并把 `"<null>"` 送去 `GmResponseParser`（必然解析失败 → 触发一次 `build_repair` 重试 → 在思考型模型上白烧 30–50s）。修复：

```gdscript
var raw_content = (message as Dictionary).get("content", "")
r.text = raw_content if typeof(raw_content) == TYPE_STRING else ""
```

落地为 `[llm]` 新增断言（`content: null` → 失败且 `text` 为空；`content: 123` → 失败），反证：把它退回 `str(...)` → **3 条红**。

## 4. 控制器侧的其它验证（供交叉核对）

- `bash tools/test.sh`：16 套件失败=0、EXIT=0；`[llm]` **65 → 79 → 84**（含复审跟进）。
- 反证①（`_apply_settings` 空操作）→ 5 条红；反证②（错误串退回含糊版）→ 3 条红；反证③（`str()` 守卫退回）→ 3 条红。
- 真机回归（内网 OpenAI 兼容网关 + `glm-5.3-flash`，settings 由 GM 自动灌入、零手工注入）：未降级、叙事 346 字、4 条 ops 经 `OpGuard`/`StateOps` 全部落地（`errors=[]`）、`location=diagon_alley`、`money=986`、wall 49.7s。详见 `b2-live-integration.md` §7.0。

## 5. 残余

- `HANDOFF §8#68`（复审 M-a）：`LlmSettings.provider` 无读取端 → 留给计划 03 的 provider 路由。
- 复审的未验证清单第 2 条（无法自行枚举提交范围）属工具限制；控制器已用 `git show --stat` 确认本修复只改 4 个文件（`llm_game_master.gd` / `main.gd` / `openai_compat_provider.gd` / `llm_test.gd`），文档提交另计。
- UI 路径、真实网关的降级行为仍需 `NEXT-STEPS.md` B1/B2 的人工验收。
