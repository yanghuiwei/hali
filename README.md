# 哈利·波特·魔法纪元

魔法世界沙盘·超高自由度人生模拟器。

以《哈利·波特》原著七部小说为正典：原著世界观、设定、人物、事件、时间线优先于一切自定义、随机推演与剧情扩展。玩家不是「大难不死的男孩」，只是这个魔法世界里出生的一个人。

- 正典规格（唯一事实来源）：[`哈利·波特·魔法纪元.md`](哈利·波特·魔法纪元.md)
- 实现计划：[`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`](docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md)；计划 02：[`docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md`](docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md)
- 计划 02 设计（spec）：[`docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md`](docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md)
- **换机器 / 交接 / 续做：先读 [`HANDOFF.md`](HANDOFF.md)**（分支、Godot 引擎获取、当前进度、待裁定项、踩过的坑）
- 执行过程台账：[`docs/sdd/plan-01-core-foundation/progress.md`](docs/sdd/plan-01-core-foundation/progress.md) · [`docs/sdd/plan-02-llm-narrative/progress.md`](docs/sdd/plan-02-llm-narrative/progress.md)

> 计划 01 / 计划 02 / 计划 03a（含 03a-P 表现层）均已合入 `main`；**后续计划从 `main` 拉新分支**（见 [`NEXT-STEPS.md`](NEXT-STEPS.md) 队列 B）。

## 当前进度

**计划 01 · 核心模拟地基 已完成**（11/11 任务）。交付物：读正典内容表 → 创建角色 → 按月推进世界 → 提交行动得到结果 → 状态面板 → 存档读档，核心逻辑全部可在无头模式自动化测试，并可通过 `src/ui/main.tscn` 窗口程序实际游玩。**计划 02 · LLM 叙事引擎 已完成**（12/12 任务）；**计划 03a · 派系与政治骨架 已完成**（13/13 任务）；**计划 03a-P · 表现层与素材接线 已完成**（P1–P5）。详见下。

| 任务 | 内容 | 状态 |
| --- | --- | --- |
| 1 | 仓库引导 + Godot 工程 + 无头测试骨架 | ✅ 完成 |
| 2 | 内容注册表 + 正典内容表 | ✅ 完成 |
| 3 | 货币 + 魔法等级与失败率 | ✅ 完成 |
| 4 | 玩家与世界数据模型 | ✅ 完成 |
| 5 | 确定性随机 + 月度世界演化 | ✅ 完成 |
| 6 | 角色创建流水线 | ✅ 完成 |
| 7 | 魔咒解析器与反漏洞守卫 | ✅ 完成 |
| 8 | 叙事接口 + 状态操作 + 反刷成长 + 回合引擎 | ✅ 完成 |
| 9 | 状态面板格式化 + 强制自检 | ✅ 完成 |
| 10 | 存档与读档 | ✅ 完成 |
| 11 | 主界面与运行说明 | ✅ 完成 |

后续计划：**03b 经济骨架 · 03c 社会与法律**（计划 03 的两个子计划，边界见 [03a spec §14](docs/superpowers/specs/2026-09-20-hp-magic-era-03-factions-design.md)）；04 神奇生物生态与区域危险度；05 NPC 自主系统与信息可信度；06 多世代传承与世界记忆；另有独立小计划：设置界面、流式输出、长期记忆、存档格式 v2。

### 计划 02 · LLM 叙事引擎（已完成，已合入 `main`）

12/12 任务完成；实现计划 [`docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md`](docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md)，设计 spec [`docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md`](docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md)，台账 [`docs/sdd/plan-02-llm-narrative/progress.md`](docs/sdd/plan-02-llm-narrative/progress.md)。

用 provider 无关、可离线测试的 `LlmGameMaster` 替换离线替身 `ScriptedGameMaster`：LLM 只产出叙事与 `ops`，一切世界变更仍由 `StateOps` 校验/钳制/审计（`OpGuard` 净化数值）。回合接口异步化（`TurnEngine.submit_async` + UI `await`），provider 未配置/超时/解析失败时降级回 `ScriptedGameMaster`。默认实现是 OpenAI 兼容 HTTP provider；`MockLlmProvider` 供离线测试。

### 计划 03a · 派系与政治骨架（已完成，已合入 `main`）

13/13 任务完成；实现计划 [`docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md`](docs/superpowers/plans/2026-09-20-hp-magic-era-03-factions.md)，设计 spec [`docs/superpowers/specs/2026-09-20-hp-magic-era-03-factions-design.md`](docs/superpowers/specs/2026-09-20-hp-magic-era-03-factions-design.md)，台账 [`docs/sdd/plan-03a-factions/progress.md`](docs/sdd/plan-03a-factions/progress.md)。

派系内容表（17 派系 / 4 政体 / 5 政治事件）→ `WorldFactions` 规则层（初始化 / **机构控制权** / **权力四角** / 政体推导 / 月度演化 / 社会矛盾 `tension` / 政治事件）→ 玩家所属与立场（`standing` + 3 个 op + `OpGuard` + 存档校验）→ **信息保护**（`reveal()` + 传闻揭示，未揭示的派系不进提示词、面板显示「未知势力」）→ 势力面板重写 → 离线替身派系关键词。

**玩法**：可以直接用自然语言加入 / 支持 / 反对派系（例：`我要加入魔法部`、`我公开支持凤凰社`、`我讨厌食死徒`）。未揭示的派系不会因为你猜名字而变得可用。

### 计划 03a-P · 表现层与素材接线（已完成，已合入 `main`）

设计 spec [`docs/superpowers/specs/2026-09-20-hp-magic-era-03a-P-presentation-design.md`](docs/superpowers/specs/2026-09-20-hp-magic-era-03a-P-presentation-design.md)（含 §2 接口冻结、§8 素材实测盘点）。
交付 4 个表现层模块 + 2 张清单表：

- `data/presentation.json`（字体 / 界面 / 图标 / 贴图 / 徽记 / 背景 / 立绘 / 配色）与 `data/audio_cues.json`（时代/地点 BGM 映射 8 era + 21 location + `master_volume`；
  **短音效 `cues` 暂为空**——`sfx` 素材未入库 ⇒ 对应 cue 静音，代码侧 8 个触发点均已接好）
- `Presentation`（安全加载 / 缓存 / **缺素材回退**）· `ThemeBuilder`（用清单造 `Theme`，暗色主题）· `AudioDirector`（8 个触发点接线 + BGM 随地点/时代切换）· `AssetSlots`（背景 / Logo / 学院徽记 / 立绘槽位，**缺素材不可见且不占位**）
- **清单驱动**：换素材 = 改一行 JSON，**零代码**；缺任何素材都照常运行。素材台账见 [`assets/CREDITS.md`](assets/CREDITS.md)。

⚠️ **已知缺口**：CJK 正文字体与 `interface.psd` 切片尚未入库（见 NEXT-STEPS §B6）。Godot 内置字体**不含中日韩字形**，因此在自带字体到位前，中文界面依赖系统字体回退（平台相关）。

## 运行

```bash
# 启动游戏窗口（主场景 src/ui/main.tscn）
./Godot_v4.7.2-stable_win64_console.exe --path .

# 运行全部测试：导入 → 单元测试 → 主场景冒烟 → 调试镜像冒烟（四步，任一步失败即非零退出）
bash tools/test.sh
```

当前基线（套件数与断言数的**唯一维护点**）：见 [`NEXT-STEPS.md`](NEXT-STEPS.md) §0B。
本文件不再重复维护具体数字（避免两处漂移）。
第 `2/4` 步还会校验 **stderr 噪音计数**：`SCRIPT ERROR` 必须恰好 **2** 条、`ERROR` 必须恰好 **7** 条，不符即判失败——
「解析 JSON 失败 / 资源加载失败 / 类型赋值错误」这类噪音**套件内的断言抓不到**，只有这个外部计数能守（详见 HANDOFF §2/§4）。
B1 人工验收的自动通道：`timeout 300 bash tools/b1_acceptance.sh` → **失败 0 / 退出码 0**（断言数见 `NEXT-STEPS.md` §0B；它写 `user://`，故不进 `test.sh`）。

Windows 上 `bash` 来自 Git Bash。Godot 可执行文件不入库，请放在仓库根目录；若路径不同，用 `GODOT=/path/to/godot bash tools/test.sh` 覆盖。

引擎版本：Godot **4.7.2 stable**（GDScript，非 .NET 构建）。仅使用 GDScript，不引入第三方插件与外部素材。

### LLM 配置（计划 02）

默认走离线替身；要启用真实 LLM，把配置写到 `user://llm_settings.json`（在仓库之外，不入库）：

```json
{"provider":"openai_compat","base_url":"https://api.example.com/v1","model":"...","api_key":"...","temperature":0.8,"max_tokens":8192,"timeout_ms":120000}
```

`HALI_LLM_API_KEY` 环境变量可覆盖 `api_key`。未配置时窗口会用 `ScriptedGameMaster` 并在状态行提示。四个字段全部**真正进入请求**（`temperature`/`max_tokens`/`timeout_ms` 由 `LlmGameMaster` 灌入，`§8#66` 已修）；只有 `base_url`/`model`/`api_key` 三者齐全才算已配置。

需要注意的几点（都是真机联调实测得出，见 [`docs/sdd/plan-02-llm-narrative/b2-live-integration.md`](docs/sdd/plan-02-llm-narrative/b2-live-integration.md)）：

- **`base_url` 要写到 OpenAI 兼容基址**（通常以 `/v1` 结尾）：provider 会拼 `base_url + "/chat/completions"`。
- **思考（reasoning）型模型必须给足预算**：这类模型的思维链与正文**共用** `max_tokens`，且可能**无法关闭思考**。实测某思考型模型在同一提示词下：`max_tokens=1024` → `finish_reason=length`、正文为空（于是每回合都降级）；`8192` → `finish_reason=stop`、正文正常。故建议 **`max_tokens ≥ 8192`**。
- **思考型模型的延迟是几十秒级**（实测单回合 ≈30–50s，新手上路几乎不消耗提示词上下文），`timeout_ms` 请给 **≥120000**，否则请求会被 `HTTPRequest.timeout` 打断（窗口在等待期会置灰输入与按钮，不会卡死）。
- 解析/超时报错会写明病因（`finish_reason=length`、`HTTP 状态 0：连接失败/超时中断`），便于排查。

### 调试镜像（人工验收用，B1）

游戏内的叙事、面板、玩家输入、状态行与等待期置灰状态既不 `print` 也不入档，从窗口外部观测不到。以环境变量开启可选镜像后即可观测：

```bash
HALI_DEBUG_LOG=1 ./Godot_v4.7.2-stable_win64_console.exe --path .
# 界面文本每行带 [HALI] 前缀进入 stdout（Windows 下 Godot 落进 user://logs/*.log）
```

镜像覆盖：叙事与面板（`_append`）、状态行（含未配置 LLM 提示）、玩家输入、创建界面 8 个下拉（含性别）的选项数与当前值、姓名/性别/年龄等创建参数、素材槽位状态（`[素材槽] logo=… backdrop=…`）、音频切换（`[音频] bgm=… volume_db=…`）、`[输入框] editable=…` 与 `[按钮] 整排 可用/禁用`、存档/读档/自检结果与错误。
**不设该变量时一行都不输出**，程序行为与加该功能前逐字一致（`tools/test.sh` 的 `3/4` 会反向断言这一点，`4/4` 用 `HALI_DEBUG_LOG=1` 断言镜像真的生效）。实现：`src/ui/debug_mirror.gd` + `src/ui/main.gd` 的 `_mirror()`。

## 目录约定

- `data/*.json`：内容（时代、血统、出生身份、资质、学院、技能、魔杖、地点、传闻、魔咒）。改内容不需要改代码。
- `data/presentation.json` / `data/audio_cues.json`：表现层清单（素材路径与配色）。**不是内容表**，不进 `Registry`；换素材只改这两张表。
- `src/model/`：数据模型（货币、玩家、世界、时钟）。
- `src/rules/`：规则（魔法等级、角色创建、魔咒解析、成长、状态操作、自检）。
- `src/core/`：内容注册表、确定性随机服务、回合引擎。
- `src/gm/`：叙事接口。`ScriptedGameMaster` 是离线确定性替身；`LlmGameMaster` 接 LLM（计划 02）。`src/gm/providers/` 放 `LlmProvider` 实现（`openai_compat`、`mock`）。
- `src/persist/`：存档编解码与存槽。
- `src/ui/`：Godot 主场景与主界面（`main.tscn` / `main.gd`）＋面板格式化（第六十二至六十五章文本面板）＋`debug_mirror.gd`（人工验收的 `HALI_DEBUG_LOG` 观测通道）＋表现层四件套 `presentation.gd` / `theme_builder.gd` / `audio_director.gd` / `asset_slots.gd`。
- `assets/`：字体 / 图标 / 贴图 / 界面 / 音频（**全部可选**，缺则回退）；授权台账 `assets/CREDITS.md`。
- `tests/`：全部测试。新增套件必须把路径追加到 `tests/run_tests.gd` 的 `SUITES`。

## 存档位置

`%APPDATA%/Godot/app_userdata/哈利·波特·魔法纪元/saves/slot1.json`（即 `user://saves`）。

## 设计不变量（改动前必读）

- 正典优先：原著明确设定 ＞ 模拟器扩展推演；玩家没有默认主角光环。
- 货币 1加隆 = 17西可 = 493纳特。
- 施法失败率按魔法等级区间取值（未入学 60–80%…大师级 低于2%），环境因素与咒语难度会修正它。
- 每回合 = 一个月；世界始终向前推进，不会停下来等玩家。
- 每 15 回合强制自检（剧情快照 + 人设 OOC 报告），未确认前禁止续写剧情。
- 反漏洞：复制稀有资源、无限复活、时间回溯、低阶咒语叠加全部被守卫拦截。
- 重复低难度动作收益递减；成长来自新环境、新问题。
- 死亡真实且不可逆。世界信息不会免费泄露给玩家。
- LLM 只产叙事与 `ops`，**绝不直接改 `world`**；一切变更经 `StateOps`（未知 op/id 拒绝、`OpGuard` 钳制数值）。
- 内容一律进 `data/*.json`（含表现层清单）；**加素材 = 改清单一行 JSON，零代码**；缺任何素材都必须优雅回退，不得报错或阻塞回合。
