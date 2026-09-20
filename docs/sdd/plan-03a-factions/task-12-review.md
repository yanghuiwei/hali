# Task 12 审查记录（独立只读 reviewer）

> 来源：reviewer run `f1b82873-29f8-4079-9e28-71a41489c4e7` 的返回原文。
> 控制器仅做排版整理，**未增删任何结论**。
> 审查范围：`review-d5a56d8..973eea8.diff`（只含代码提交，BASE `d5a56d8` → HEAD `973eea8`）。
> 阅读预算（HANDOFF §4 第 14 条）：只读 1 次 diff、≤4 次 grep、报告 ≤120 行、不许整文件打印源码。

## 1. 结论：**Approved with findings**

核心修复（哑炮 `house_id="none"`、`stream_pick_weighted` 接线、性别/姓名 UI）方向正确、无既有断言被放宽或删除、回归面干净；
余下均为 Minor（含 1 条判为 Important 但取决于计划 scope 的**读档路径未修**）。

## 2. 发现表

| # | 严重度 | 位置 | 问题 | 依据 |
| --- | --- | --- | --- | --- |
| 1 | Important（若计划只要求创建路径→降 Minor） | `src/model/player_state.gd:107` `p.house_id = str(d.get("house_id", "none"))` | 修复只覆盖 `create()`。**读档路径原样拷贝** `house_id`，没有归一化 ⇒ §8#69 的原始证据（`user://saves/slot1.json` 里 squib+`gryffindor`，HANDOFF:369 / `docs/sdd/plan-02-llm-narrative/b1-acceptance.md:76`）在**旧存档**上仍然复现；只有重新建角才会变 `none`。最小修：`from_dict` 中若 `aptitude_id=="squib"` 或 `bloodline_id=="squib"` 或 `flags.no_magic` 为真则强制 `"none"`（或在计划里显式声明读档不在范围内） | src 内 `house_id` 的全部写入点：`character_creation.gd:219/221`、`player_state.gd:15`（默认 `"none"`）、`:107`（读档拷贝）；`assign_house` 在 src 中唯二调用点是 `character_creation.gd:221`（+ tests 直调静态方法）⇒ 无第二入口，但读档不重判 |
| 2 | Minor | `src/core/rng_service.gd:47-49` | `roll <= acc` 在 **`roll==0.0` 且首条权重为 0** 时会把权重 0 的条目返回，违反同函数第 28 行自己的契约「权重非正（≤0）的条目**永不**被抽中」。触发概率 ≈ 2⁻³²（需 `stream_float` 精确返回 0.0）。修：选择循环里 `if w<=0: continue`（或在累加前先 `roll < acc` 判定 + 跳过 0 权重） | diff 代码：`acc += maxf(...); if roll <= acc: return e`，首条 `maxf(0.0,0.0)=0.0` ⇒ `0.0<=0.0` 成立 |
| 3 | Minor | `src/core/rng_service.gd:28-30`（文档） vs `:36-37`（实现） | 注释自相矛盾：头部说「≤0 永不被抽中」，实现里 `total<=0.0` 整体回退 `stream_pick` ⇒ **全零条目全部可被均匀抽中**。新测试 `t12_all_zero` 把回退钉成期望值，说明行为是有意的，但文档与行为不一致；另外非字典条目在加权路径被完全跳过（贡献 0 权重份额），在回退路径却可被抽中，两条路径语义不对称 | diff 中 `if total <= 0.0: return stream_pick(name, entries)` 与新增断言「全零权重回退到均匀抽取，不返回 null」。当前生产数据无 ≤0 权重（data 抽查：`wand_cores` 6/1、`rumors` 1–20），实害为零 |
| 4 | Minor | `src/rules/character_creation.gd` `generate_wand` 新增块（diff `@@ -100,10 +100,20 @@`，约 L104–119） | 把 `stream_pick_weighted` 的返回值（**空表时是 `null`**）直接赋给有类型的 `var wood_entry_pick: Dictionary` / `core_entry_pick: Dictionary`——正是同一提交在 `rng_service.gd:29-31` 刚警告过的「null 赋给有类型变量」隐患；旧代码 `str(stream_pick(...))` 在空表时只是产生退化字符串，**新代码会抛运行期脚本错误**。修：去掉这两处类型标注（`var wood_entry_pick = ...`）并 `if x == null: return {}`。当前数据下不可达（控制器 400 次 `generate_wand` 全绿） | 见 diff；`world_state.gd:118` 同型写法为**既有**模式（`stream_pick` 也返回 null），非本提交引入 |
| 5 | Minor（仅报告，供 parent 记账） | `tools/b1_acceptance.gd:232` | worker 声称「既有断言一条都没改」不精确：`_dropdown_count(node) == 7` 被改成 `== 8`（必要，非放宽），且 §8#69/#70 两条 `note()` 观察项被 `check()` 取代。无任何既有断言被放宽/删除/改期望值 | 断言计数自洽：`1746 + 8(creation_test 新增) + 6(world_tick 新增) = 1760` ✅；b1 `105 + 6(新 check) + 1(key 列表加 gender) = 112` ✅——若删除过断言，计数不会精确吻合 |

## 3. 逐条回答（摘要）

- **Q1 哑炮学院**：确定赋值 **是**（`create()` 先 `validate_choices`，此后只有哑炮/非哑炮两个分支，无第三分支、无中途早退）；非哑炮 **未误伤**（`requested` 非空即优先返回；调用点从 `assign_house` 之前移到 aptitude 掷定之后，但二者用**不同命名流** `house_tiebreak` vs `aptitude` ⇒ 同种子结果不变）；**无新入口**（src 中唯一写入非默认 `house_id` 的地方就是 `creation_creation.gd:219/221`）⇒ 见发现 #1（旧存档不归一化，是残留面）。
- **Q2 权重抽取**：分布按权重成正比、负权重被夹到 0 从不被抽、`weight_key` 缺失默认 1.0、空表返回 null、全零回退均匀——均覆盖。**唯一真边界缺陷**是发现 #2。调用键确认是数值字段（`wand_cores.weight` 6/6/1/1/1/6；`rumors.weight` 1–20）；`wand_woods.json` **确无** `weight` ⇒ 分布上等价均匀（但同种子抽中的具体木材会变：`randi_range` → `randf`）。
  ⚠️ 「零条既有断言变红」**结论可信**（计数自洽 + 全绿），但 worker 的**推理前提偏弱**：均匀路径下 `randi_range(0,n-1)` 与 `int(randf()*n)` 多数种子给出相同索引 ⇒ **不能用「没红」反推「不存在钉住抽中项的断言」**（见未验证 #1）。
- **Q3 新断言承重**：承重 = `t12_squib_house=="none"`（旧代码必为 gryffindor）· `t12_normal_house=="gryffindor"` · `common > rare*4` · `rare>0` · `generate_wand 400 支 rare<120` · `saw_zero==0` · `saw_one>0`（E2E 前置守卫）。
  改前就绿/不承重 = `errors.size()==0`（夹具 sanity）· `flags.no_magic`（**未标注为非回归**）· `sys_house=="none"`（**已标注**）· `rumors > 2`（恒真守卫）。
  阈值余量够、**不 flaky**（全部固定种子；3000 次 rare≈429 对阈值 514 ⇒ +4.4σ；400 支≈57 对阈值 120 ⇒ +8σ）。
  b1「观察项→断言」**未丢覆盖**（`check(house_id=="none")` 严于原 `note()`；性别那条覆盖是**增强**）。
- **Q4 回归面 / UI 组合 / 空名文案**：既有断言仅 `_dropdown_count 7→8` 一处必要改动 + 两条 note→check，计数自洽证明无删除/放宽。
  `gender_dropdown` 成员 + 登记 `dropdowns` 的组合**可用且探针路径正确**，`_show_creation()` 重入安全；不一致处：`_on_start_pressed` 走 `get_item_metadata(selected)` 而其它 7 键走 `_selected(key)`——因 metadata==item text 恒等，无实际分歧，但这是**第二套取值约定**（仅报告，非缺陷）；无 null 保护直接解引用 `gender_dropdown`，与同函数既有的 `name_edit/age_spin` 同风险等级，非本提交新增。
  空名文案：`create()` 会因 `validate_choices` 早退，路径本身合理；**文案是否点名「姓名」、`main.gd` 是否把 `out.errors` 呈现给玩家，未在预算内证实**（见未验证 #2），不作 finding。

## 4. 反证表（承重 vs 不承重）

| 断言 | 判定 | 理由 |
| --- | --- | --- |
| `t12_squib_house == "none"`（显式 gryffindor） | **承重** | 旧代码此处必为 `gryffindor`，唯一能判别的输入 |
| `t12_normal_house == "gryffindor"` | **承重** | 防过度修正（把非哑炮也置 none） |
| `common > rare*4`（3000 次） | **承重** | 全 1 权重时约 1500:1500，必红 |
| `generate_wand 400 支 rare<120` | **承重** | 均匀≈200，必红；且真正验证 `generate_wand` 传了 `"weight"` |
| `saw_zero==0`（40 tick） | **承重** | 回到 `stream_pick` 时双条目夹具近乎必被抽中 |
| `saw_one>0` | **承重（守卫）** | 无此条则「一次都没抽」会假绿 |
| `t12_squib.errors.size()==0` | 不承重（夹具 guard） | 恒定满足，但为后续断言提供前提 |
| `flags.no_magic` | 不承重 | 血统 `default_flags` 亦写入，改前即绿，**未标注非回归** |
| `sys_house=="none"` | 不承重（**已标注**） | `assign_house` 对 `magic_aptitude=false` 早已返回 `none` |
| `rumors.size() > 2` | 不承重（恒真守卫） | 防夹具偷换，无判别力 |

## 5. 未验证清单（预算内未做，勿当成已覆盖）

1. `tests/` 中**是否存在**断言钉住具体 `wand_core`/`wand_wood`/`rumor_id`：未 grep；结论仅由「控制器全绿 + 计数自洽」间接支持。
2. `validate_choices` 对空名的**具体文案**，以及 `main.gd._on_start_pressed` 是否把 `out.errors` 展示给玩家、空名提交是否形成「点了没反应」的死路。
3. `src/ui/main.gd:231` 处还有一份**未含 `"gender"`** 的 7 键列表（grep 命中），与 L204 已加 `"gender"` 的镜像循环不一致；其用途未确认。
4. `data/houses.json` 是否确有 `id=="none"`（新代码硬编码该 id）：未直读。
5. `Registry.from_tables` 是否对 id 排序（E2E 夹具注释依赖此假设）。
6. `_selected()` 的实现（读 text 还是 metadata）未直读。
7. 未运行任何命令；`test.sh` / `b1` / `git status` 结论均沿用控制器提供的数据。

## 6. 新增风险

- **空名默认**：把「首次点开始即被拒」变成默认体验；若 UI 不展示 `out.errors`，玩家会看到无反馈的按钮——**未证实**。建议免费加固：B1 补一条「空名点开始 ⇒ 不进游戏且可见错误文案」的断言。
- **`generate_wand` 空表路径**由「退化字符串」变成「运行期脚本错误」（发现 #4），虽当前数据不可达，但会污染 `SCRIPT ERROR` 计数基线。
- **发现 #1 的读档残留**：不修则 `§8#69` 在旧存档上仍可被外部观察者复现，容易被误判为「修复无效」。
- 无测试之外的副作用：`data/wand_cores.json` 只增字段，未改 id/label/rarity，兼容既有存档中的 `core` 值。

---

## 控制器对 finding 的处置（附于本记录，非 reviewer 原文）

| # | 处置 |
| --- | --- |
| 1 | **控制器裁定：不在 Task 12 修**，登记进「存档格式 v2」批次（与 `§8#26` 同族）⇒ 后编号 `§8#71`。理由与零成本缓解写在计划「Task 12 范围声明」。**用户可推翻**。 |
| 2 | 修复轮 1 修掉（`ce1594d`）：拆出 `_pick_by_roll`，跳过 `w<=0`、判定改 `roll < acc`、兜底取**最后一个正权重**条目；并加**可判别**断言（旧写法必红，D5 实测恰好 2 红） |
| 3 | 修复轮 1 把契约写全四条（含「全零回退时零权重字典条目可被抽中」这一有意不对称）；scoped 复审指出①措辞仍不准，控制器再订正 2 行注释（`aefd612`，免复审） |
| 4 | 修复轮 1 修掉：`generate_wand` 两处去掉类型标注 + 判空返回 `{}`；**未动** `world_state.gd:118`（被 `if not candidates.is_empty()` 守卫） |
| 5 | 修复轮 1 更正报告措辞 + 页首加「修复轮 1 更正声明」（与 Task 6 同做法） |
