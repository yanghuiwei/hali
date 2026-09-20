# 哈利·波特·魔法纪元

魔法世界沙盘·超高自由度人生模拟器。

以《哈利·波特》原著七部小说为正典：原著世界观、设定、人物、事件、时间线优先于一切自定义、随机推演与剧情扩展。玩家不是「大难不死的男孩」，只是这个魔法世界里出生的一个人。

- 正典规格（唯一事实来源）：[`哈利·波特·魔法纪元.md`](哈利·波特·魔法纪元.md)
- 实现计划：[`docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md`](docs/superpowers/plans/2026-09-18-hp-magic-era-01-core-foundation.md)；计划 02：[`docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md`](docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md)
- 计划 02 设计（spec）：[`docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md`](docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md)
- **换机器 / 交接 / 续做：先读 [`HANDOFF.md`](HANDOFF.md)**（分支、Godot 引擎获取、当前进度、待裁定项、踩过的坑）
- 执行过程台账：[`docs/sdd/plan-01-core-foundation/progress.md`](docs/sdd/plan-01-core-foundation/progress.md) · [`docs/sdd/plan-02-llm-narrative/progress.md`](docs/sdd/plan-02-llm-narrative/progress.md)

> 计划 01 与计划 02 均已合入 `main`；**后续计划从 `main` 拉新分支**（见 [`NEXT-STEPS.md`](NEXT-STEPS.md) 队列 B）。

## 当前进度

**计划 01 · 核心模拟地基 已完成**（11/11 任务）。交付物：读正典内容表 → 创建角色 → 按月推进世界 → 提交行动得到结果 → 状态面板 → 存档读档，核心逻辑全部可在无头模式自动化测试，并可通过 `src/ui/main.tscn` 窗口程序实际游玩。**计划 02 · LLM 叙事引擎 已完成**（12/12 任务，见下）。

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

后续计划：03 派系与政治经济；04 神奇生物生态与区域危险度；05 NPC 自主系统与信息可信度；06 多世代传承与世界记忆；另有独立小计划：设置界面、流式输出、长期记忆。

### 计划 02 · LLM 叙事引擎（已完成，已合入 `main`）

12/12 任务完成；实现计划 [`docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md`](docs/superpowers/plans/2026-09-19-hp-magic-era-02-llm-narrative.md)，设计 spec [`docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md`](docs/superpowers/specs/2026-09-19-hp-magic-era-02-llm-narrative-design.md)，台账 [`docs/sdd/plan-02-llm-narrative/progress.md`](docs/sdd/plan-02-llm-narrative/progress.md)。

用 provider 无关、可离线测试的 `LlmGameMaster` 替换离线替身 `ScriptedGameMaster`：LLM 只产出叙事与 `ops`，一切世界变更仍由 `StateOps` 校验/钳制/审计（`OpGuard` 净化数值）。回合接口异步化（`TurnEngine.submit_async` + UI `await`），provider 未配置/超时/解析失败时降级回 `ScriptedGameMaster`。默认实现是 OpenAI 兼容 HTTP provider；`MockLlmProvider` 供离线测试。

## 运行

```bash
# 启动游戏窗口（主场景 src/ui/main.tscn）
./Godot_v4.7.2-stable_win64_console.exe --path .

# 运行全部测试：导入 → 单元测试 → 主场景冒烟
bash tools/test.sh
```

Windows 上 `bash` 来自 Git Bash。Godot 可执行文件不入库，请放在仓库根目录；若路径不同，用 `GODOT=/path/to/godot bash tools/test.sh` 覆盖。

引擎版本：Godot **4.7.2 stable**（GDScript，非 .NET 构建）。仅使用 GDScript，不引入第三方插件与外部素材。

### LLM 配置（计划 02）

默认走离线替身；要启用真实 LLM，把配置写到 `user://llm_settings.json`（在仓库之外，不入库）：

```json
{"provider":"openai_compat","base_url":"https://api.example.com/v1","model":"...","api_key":"...","temperature":0.8,"max_tokens":1024,"timeout_ms":30000}
```

`HALI_LLM_API_KEY` 环境变量可覆盖 `api_key`。未配置时窗口会用 `ScriptedGameMaster` 并在状态行提示。

## 目录约定

- `data/*.json`：内容（时代、血统、出生身份、资质、学院、技能、魔杖、地点、传闻、魔咒）。改内容不需要改代码。
- `src/model/`：数据模型（货币、玩家、世界、时钟）。
- `src/rules/`：规则（魔法等级、角色创建、魔咒解析、成长、状态操作、自检）。
- `src/core/`：内容注册表、确定性随机服务、回合引擎。
- `src/gm/`：叙事接口。`ScriptedGameMaster` 是离线确定性替身；`LlmGameMaster` 接 LLM（计划 02）。`src/gm/providers/` 放 `LlmProvider` 实现（`openai_compat`、`mock`）。
- `src/persist/`：存档编解码与存槽。
- `src/ui/`：Godot 主场景与主界面（`main.tscn` / `main.gd`）＋面板格式化（第六十二至六十五章文本面板）。
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
