# B2 · 真机 LLM 联调报告（2026-09-20）

> 对应 `NEXT-STEPS.md` B2。本文只记录**脱敏**信息：**不含 `api_key`**，也不含内网网关的具体域名（仓库是 **public**，见 §6）；具体地址只存在于本机 `user://llm_settings.json`（在仓库之外）与本机会话记录里。
> 判定：**HTTP 链路 + 提示词 + 解析 + 净化 + StateOps 落地全部实测通过**（§4），但**游戏当前代码无法使用该端点**——被一个 plumbing bug 阻塞（§3.3），故 B2 **未完成**，剩 GUI 实跑与降级路径（§7）。

## 1. 测试环境与方式

| 项 | 值 |
| --- | --- |
| 引擎 | Godot 4.7.2 stable（非 .NET） |
| 配置 | `user://llm_settings.json`（`%APPDATA%\Godot\app_userdata\哈利·波特·魔法纪元\`，**在仓库之外**） |
| 探针 | 一次性脚本 `tests/llm_live_probe.gd`（跑完即删，未入库；`git status` 已确认干净） |
| 探针流程 | `Registry.load_default()` → `CharacterCreation.create()`（张三/麻瓜出身/拉文克劳/11 岁）→ `WorldState.create("modern", …, seed=7)` → `PromptBuilder.build(world, "我去对角巷的丽痕书店，想买一本《标准咒语，初级》。")` → 真实 `HTTPRequest` → `GmResponseParser.parse` → `OpGuard.sanitize_detailed` → `StateOps.apply` |
| 旁证 | 同一请求体的 `curl` 重放（用于看 `finish_reason`/`usage`，因此可读到 provider 不暴露的字段） |

## 2. 端点形态（实测）

1. **基址必须含 `/v1`**：`<网关>/thor/v1`。裸 `<网关>/thor/models` 返回的是 HTML 管理页，`<网关>/v1/models` 是 404。
2. `GET <基址>/models` → `200`，`{"data":[{"id":"glm-5.3-flash","supported_endpoint_types":["openai"]}],…}` ⇒ 模型 id = **`glm-5.3-flash`**，OpenAI 兼容。
3. `_chat_url()`（`base_url.rstrip("/") + "/chat/completions"`）**正好**拼出可用地址 —— provider 的 URL 拼接逻辑对该网关成立。
4. `response_format: {"type":"json_object"}` **被接受**，模型确实只吐 JSON。
5. 中文 UTF-8 往返**正常**（用 Python 写 UTF-8 请求体验证过；早先一次"中文变乱码"是**我方 shell 编码**造成的探针假象，非网关问题 —— 用 `--data-binary @file` 即正常）。

## 3. 关键发现

### 3.1 该模型**始终思考**，无法关闭

`thinking: {"type":"disabled"}` → **HTTP 400**，网关明确回话：

> 该模型始终思考，不支持关闭思考；请使用 low、high 或 max。

并且以下写法**全部无效**（实测 200 但行为不变，或 400）：

| 尝试 | 结果 |
| --- | --- |
| `thinking: {"type":"low"/"high"/"max"}` | **400**（同一条错误信息；提示的档位参数名不是这个） |
| `chat_template_kwargs: {"enable_thinking": false}` | 200，**被忽略**（仍 1024 全为思维） |
| `enable_thinking: false` | 200，**被忽略** |
| `reasoning_effort: "none"` | 200，**被忽略** |

**档位参数名尚未找到**（见 §7）——若要降延迟，这是唯一未试的旋钮。

### 3.2 `max_tokens=1024` 时**必然拿不到叙事**

用**游戏真实提示词**（system 2505 字 + user 1110 字 ≈ 1408 prompt tokens）实测：

| `max_tokens` | `finish_reason` | `content` | `reasoning_content` | reasoning tokens |
| --- | --- | --- | --- | --- |
| 64 / 256 / 1024 | `length` | **空** | 3.6k–4.1k 字 | 1023 / 1024 |
| **8192** | **`stop`** | **738 字（合法 JSON）** | 15092 字 | 4329（总 4822） |

即：**思维链把预算吃光**，`content` 永远为空 → 游戏侧 `ok=false, error="响应内容为空"` → 重试（同样失败）→ 降级 `ScriptedGameMaster`。**在默认配置下，该端点上 LLM 路径 100% 降级**（表现为"游戏能玩，但叙事永远来自本地替身"）。
⇒ 可用配置：`max_tokens ≥ 8192`。

### 3.3 🔴 **BUG：`llm_settings.json` 的 `temperature` / `max_tokens` / `timeout_ms` 完全不生效**

```
$ grep -rn "settings\.\(temperature\|max_tokens\|timeout_ms\)" src/
（无匹配）
```

链路是：`PromptBuilder.build()` 造出的 `LlmProvider.LlmRequest` 带的是**类默认值**（`llm_provider.gd:7-9`：temperature 0.8 / max_tokens 1024 / timeout_ms 30000），`LlmGameMaster.act()` 从不把 settings 灌进去，`OpenAiCompatProvider.complete()` 用的是 `request.max_tokens` / `request.timeout_ms`。

**实证**：把 `llm_settings.json` 改成 `max_tokens=8192` 后，探针 dump 出的请求体仍是 `{"max_tokens": 1024, "temperature": 0.8, "model": …, "response_format": …, }`。只有 `base_url` / `model` / `api_key` 三个字段真正生效。

两个类默认值恰好和 `LlmSettings` 的默认值相同（0.8 / 1024 / 30000），所以单测与计划 01/02 都发现不了 —— 这是**配置层与请求层之间的静默断链**。后果：对本次这个"始终思考"的模型，游戏**改配置也救不回来**，必须改代码。

### 3.4 `timeout_ms=30000` 对思考模型是临界值

同一请求（`max_tokens=8192`）：一次 **29.6s 成功**，一次 **29.94s 被 `HTTPRequest.timeout` 打断**（`http_status=0`）。⇒ 必须放大（建议 **≥120s**）。

### 3.5 诊断性缺口（错误串不可区分病因）

- 超时/传输失败 → `_parse_http(0, "")` → **`error = "HTTP 0（）"`**（空状态码 + 空 body），完全看不出是超时。
- 思维吃光预算 → `error = "响应内容为空"`，**看不到 `finish_reason=length`**，无法区分"模型没吐内容"与"预算被思维吃光"。而 provider 手里其实拿得到完整响应体（只是 `_parse_http` 没读 `finish_reason`）。

## 4. 端到端成功证据（探针 stdout，脱敏）

在探针里**模拟** §3.3 的修复（把 `settings.temperature/max_tokens/timeout_ms` 手动灌进 request），其余代码路径原样：

```
[probe] 玩家：张三 / muggle_born / ravenclaw / london_muggle
[probe] settings.is_configured=true base_url=<网关>/v1 model=glm-5.3-flash key_len=51 max_tokens=8192 temp=0.8
[probe] 注入后 req: temperature=0.8 max_tokens=8192 timeout_ms=180000
[probe] system_prompt 字数=2505 user_prompt 字数=1110
[probe] system_prompt 中文抽样：你是《哈利·波特·魔法纪元》的世界模拟系统（第七十三、七十四章）。你只负责叙事与提出状态变更意图，不直接改变世界。原著设定优先于一切推演。 硬约束： 1) 你只
[probe] text 前 700 字：
{"narration":"九月的风带着雨意。你攥着霍格沃茨的入学信和换好的三枚金加隆，推开查令十字街上那家麻瓜们视而不见的'破釜酒吧'。……（拉文克劳新生、丽痕书店、一个加隆）","ops":[{"op":"set_location","location_id":"diagon_alley"},{"op":"add_money","knuts":-493},{"op":"know_fact","fact_id":"diagon_alley_entrance_leaky_cauldron","source":"破釜酒吧汤姆的指点"},{"op":"know_fact","fact_id":"owns_standard_spells_grade1","source":"丽痕书店购书"}],"tags":["idle"]}
[probe] ok=true http_status=200 latency_ms=29600
[probe] parse.ok=true narration=287 字 ops=4 tags=["idle"]
[probe] OpGuard：清洗后 ops=4 warnings=["支出未经校验（-493 纳特）"]
[probe] StateOps.apply -> errors=[]
[probe] 应用后 location=diagon_alley job= money=986
[probe] DONE
```

值得记下的正面结论：

- **提示词工程有效**：模型正确进入了"世界模拟系统"人格，叙事里出现了玩家真实状态（**拉文克劳**新生），说明 `state_digest` 被读进去了。
- **正典与数值正确**：写的是"一个加隆"= `add_money: -493` 纳特（与设计不变量 1 加隆 = 493 纳特一致）。
- **ops 全部落在白名单内**：`set_location` / `add_money` / `know_fact` 都被 `OpGuard` 通过、被 `StateOps` 接受（`errors=[]`）。
- **反作弊链有反应**：负支出按 spec 记了一条 warning（"支出未经校验"），`warnings → op_errors` 透出链路真实工作。
- **状态真的变了**：`location` 从 `london_muggle` → `diagon_alley`，钱 1479 → 986（−493）。

## 5. 建议的最小修复（待裁定，尚未实施）

只有 §3.3 是"必须改代码"的；§3.4/§3.5 是配置与诊断。

```gdscript
# src/gm/llm_game_master.gd —— 让 GM 持有 settings（构造函数加可选第三参，向后兼容）
var settings: LlmSettings = null
func _init(provider_: LlmProvider = null, fallback_: GameMaster = null, settings_: LlmSettings = null) -> void:
	provider = provider_
	fallback = fallback_
	settings = settings_

# act() 内，两处 build 之后各补三行：
var req := PromptBuilder.build(world, action_text)
if settings != null:
	req.temperature = settings.temperature
	req.max_tokens = settings.max_tokens
	req.timeout_ms = settings.timeout_ms
# build_repair 分支同样处理
```

`src/ui/main.gd:_build_gm()` 改为 `LlmGameMaster.new(OpenAiCompatProvider.from_settings(self, settings), ScriptedGameMaster.new(rng), settings)`。
需补的运动测试：`[llm]` 断言"settings 的 temp/max_tokens/timeout 真的进了 `provider.requests[i]`"（`MockLlmProvider` 已记录完整 request，可直接断言）——这条断言同时也就是 §3.3 的回归护栏。

**§3.5 的便宜改法**（可选，与上面同批做）：`_parse_http` 在 `status == 0` 时报"请求被超时/传输中断"；`content` 为空时把 `finish_reason` 一起写进 `error`。

## 6. 安全（重要）

- ✅ **key 未入库**：`grep -rn "sk-…" .` 与 `git log --all -S "sk-…"` 均为 **0 命中**；内网域名同样 0 命中（工作区 + 全历史）。
- ⚠️ **仓库是 public**（`api.github.com/repos/yanghuiwei/hali` → `visibility: public`），故本文与后续提交**故意不写内网域名**（用 `<网关>` 占位）。具体地址请查本机 `user://llm_settings.json` 或向维护者索取。
- ⚠️ **建议轮换该 key**：它已出现在本次会话记录里（本机 `~/.pi/agent/sessions/...`）。若这些记录会被分享/同步，请先轮换。
- 本机配置（**仓库外**，不入库）：`%APPDATA%\Godot\app_userdata\哈利·波特·魔法纪元\llm_settings.json`，当前为 `max_tokens=8192`、`timeout_ms=180000`。**注意：在 §3.3 修复前，这两个字段不会被游戏读取。**

## 7. 未验证 / 待办

### 7.0 修复后复测（2026-09-20，`§8#66` 修复提交 `3240af6` 之后）

同一端点、同一模型、同一提示词，**不再手工注入 settings**（由 `LlmGameMaster` 自己灌）：

```
[probe] settings: configured=true model=glm-5.3-flash max_tokens=8192 timeout_ms=180000 temp=0.8
[probe] GmResult: wall_ms=49674 narration=346 字 deltas=4 warnings=["支出未经校验（-493 纳特）"] last_error=
[probe]   delta[0]={ "op": "set_location", "location_id": "diagon_alley" }
[probe]   delta[1]={ "op": "add_money", "knuts": -493 }
[probe]   delta[2]={ "op": "know_fact", "fact_id": "diagon_alley_entrance_leaky_cauldron", "source": "leaky_cauldron_tom" }
[probe]   delta[3]={ "op": "relation_delta", "npc_id": "leaky_cauldron_tom", "trust": 5, "interest": 5, "hostility": 0 }
[probe] StateOps errors=[]
[probe] 最终 location=diagon_alley money=986
[probe] PASS
```

⇒ **同一路径修复前是 `content` 恒空 → 降级，修复后不再降级**；`settings.max_tokens=8192` 真的进了请求。耗时 49.7s（思考型模型的真实成本）。

### 7.1 仍未做

1. ~~**§3.3 的修复尚未实施**（等裁定）~~ → **已完成**（`3240af6`，见 §7.0 复测）。
2. **GUI 实跑未做**：等待期 `command_edit` + 整排按钮置灰是否正常、结束后是否恢复、窗口是否卡死（`NEXT-STEPS.md` B1/B2 的人工项）。
3. **降级路径未实测**：断网 / 401 / 超时后是否如期降级为 `ScriptedGameMaster` 并给出提示（`LlmGameMaster` 有 2 次尝试 + 降级；本次只验到 `HTTPRequest.timeout` 会打断请求，未验 UI 表现）。
4. **多回合未测**：连续 3–5 回合的延迟/费用/`world.tick()` 叠加；本次单回合 29.6s（思考型模型的实际体验成本）。
5. **思考档位参数名未找到**（§3.1）：`low/high/max` 提示的正确字段名未知；若能降档可显著缩短延迟。
6. **`finish_reason` 其它取值**（`content_filter` 等）未构造。
7. 未测 `GET /models` 之外的端点（embedding 等不涉及）。
