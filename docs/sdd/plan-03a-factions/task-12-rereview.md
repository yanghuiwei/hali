# Task 12 修复轮 1 · scoped 复审记录（独立只读 reviewer）

> 来源：reviewer run `c715071e-9939-4adb-b1ac-11b89dee55e4` 的返回原文。
> 控制器仅做排版整理，**未增删任何结论**。
> 审查范围：`review-ebd426f..ce1594d.diff`（修复轮 1，只含 1 个代码提交，11KB）。
> 阅读预算：只读 1 次 diff、≤3 次 grep、报告 ≤80 行。

## 1. 结论：**Accepted with notes**

无 Critical / Important 新问题；仅 1 条 Minor 残留文档不精确 + 2 条 P2 说明。

## 2. 逐条回答

**Q1 `_pick_by_roll` 拆分对「全正权重」是否结果等价？——是（除累积边界测度零集合）**
- 旧 `roll <= acc_k` 命中 `roll ∈ (acc_{k-1}, acc_k]`；新 `roll < acc_k` 命中 `roll ∈ [acc_{k-1}, acc_k)`。
  对**所有非边界** roll 两者命中的 k 相同；不同仅发生在 `roll == acc_k` 恰好相等（即允许排除的极边界）⇒ 分布等价。
- 兜底可达性/一致性：`total` 与 `_pick_by_roll` 的 `acc` 是**同一顺序、同一被加项**上的浮点求和
  （非字典条目两处都被跳过，`w<=0` 项加 0.0 是精确运算）⇒ 两者**逐位相等**。
  故 `total>0` 时 `roll = f*total < acc_final` 恒成立（即便 `f==1.0` 也只落到兜底 `last_positive` = 末个正权重项 = 旧的 `entries[size-1]`）。
  全正权重下新兜底不会给出比旧实现不同的条目。

**Q2 随机流消耗是否未变？——未变（本轮最关键回归面，已确认）**
- 旧：`var roll := stream_float(name) * total`（`total<=0` 分流之后）；新：`return _pick_by_roll(entries, weight_key, stream_float(name) * total)`。
  **每次加权路径调用仍恰好 1 次 `stream_float`**，位置相同（空表早退与 `total<=0` 分流都在其前，未改动），期间无其它流消耗
  ⇒ 固定种子的既有断言不会漂移。`stream_pick` 的 `randi_range` 仍只在空表/全零路径走。
- 注：`_weight_of` 只是把原来的 `maxf(...)` 提成 static，不触碰流。

**Q3 `_pick_by_roll` 返回 `null` 是否可达？——从 `stream_pick_weighted` 不可达；`_picked_id` 达成「红而非中止」**
- 推理成立：`total>0` ⇒ 存在 `typeof==DICTIONARY` 且 `_weight_of>0` 的条目 ⇒ 该条目必过 `w<=0` 过滤并赋值 `last_positive`
  ⇒ 兜底分支为真，`return null` 不可达。两条路径的条目分类（typeof 检查 + 同一 `_weight_of`）完全一致。
- `tests/world_tick_test.gd` 的 `_picked_id`：`null → "<null>"`、非字典 → `"<非字典:…>"`、否则 `.get("id", "<无 id>")`；
  断言经 `assert.gd:10 func eq(actual, expected, msg: String = "")`（**无类型**参数）比较字符串
  ⇒ 破坏实现时是「断言计数红」而非运行期中止其余断言。这正是 Task 9 M7 / Task 12 首轮 personality 同源问题的正确处置。

**Q4 worker 的 F2b 诚实声明——成立；F1b 的「可判别」成立；但有一处需补强**
- F2b 声明成立：空木材表时，旧写法（有类型接收）在赋值处运行期报错并**中止 `generate_wand`**，函数返回 Dictionary 默认值 `{}`；
  新写法显式 `return {}`。`a.eq(generate_wand(...), {})` 在两种写法下都拿到 `{}` ⇒ **确实不是判别器**，唯一通道是外部 `SCRIPT ERROR` 计数。声明逻辑自洽。
- **补强**：该断言对「守卫存在 vs 守卫被删」同样不敏感——若删掉守卫而保留无类型接收，
  `(null as Dictionary).get(...)` 报错中止后仍返回 `{}` ⇒ 依然绿。所以它连同 D6 的结论一起说明：
  这条路径的**全部判别力都在 `SCRIPT ERROR` 计数上**，worker 只声明了 typed/untyped 一轴，实质更弱一点
  （不构成矛盾，但**别把它当回归网**）。
- F1b「可判别」成立（**从 diff 中旧代码可直接推演**，无需跑）：把新写法还原为旧写法后——
  断言①（`z` weight 0 在首、`roll=0.0`）旧式返回 `z` → 红；断言②（`roll=999`、`z` 在末）旧式兜底 `entries[size-1]`=`z` → 红；
  断言③（非字典在首、`roll=0.0`）旧式也 `continue` 非字典 → 得 `o` → **绿**。⇒ 恰好 2 红，与 D5 报告一致。
- 新增假绿：**无**。断言③在新旧两种实现下都绿（它钉的是契约③前半，并非本次修复的判别器），但它**并非恒真**
  ——若有人让非字典条目占区间，`roll=0.0` 会返回 `"裸字符串"` → 会红。
  `creation_test.gd` 的三条夹具前置断言（默认木材表非空 / 夹具表确为空 / 杖芯表仍 ≥6）有效阻断「空夹具冒充」这类假绿。

## 3. 新引入问题

- **Minor（残留文档不精确，非回归）**：`rng_service.gd:30` 契约①「权重 ≤ 0 的条目**永不被抽中**」，
  但 `total<=0` 时 `:45 return stream_pick(name, entries)` 会**均匀抽中零权重字典条目**；
  契约③只点名了「非字典条目」的这层不对称，漏了同性质的「零权重字典条目」。
  证据：`world_tick_test.gd` 既有断言明确「全零权重回退到均匀抽取」。最小修法：把①改成「在加权路径中永不被抽中」，
  或在③补一句「同理，全零回退时零权重（字典）条目也可被抽中」。**这正是首轮 #3 的同一类不对称，F1 补了三维、漏了一维。**
- **P2（非本 diff 引入）**：`character_creation.gd` 的 `(pick as Dictionary).get(...)` 未防 `pick` 为非 Dictionary。
  若某表项不是字典（`total<=0` 分流 → `stream_pick` 可返回非字典项），`as Dictionary` 得 `null`，`.get` 在 null 上运行期报错中止
  ——与旧写法行为**等价**，故不算回归；仅在「契约①③声称的退化路径」上守卫不完整（只挡 `null`，没挡「非字典」）。
  可达性需注册表含非字典项，实际数据下不可达。
- Critical / Important：**无**。

## 4. 未验证清单（老实交代）

1. **D5（2 红）/ D6（`SCRIPT ERROR` 2→3）没有实跑**：「2 红」是从 diff 中旧代码逐行推演的；D6 的计数依赖 worker 报告 + 控制器只核对过的基线 2 条。
2. `tests/assert.gd` 只看了签名（`eq/is_true/report` 三行），**没读函数体**——假定 `eq` 对 String/Dictionary 失配计红而非静默通过。
3. Godot 运行期语义「可空赋给有类型变量 → 报错并中止函数、返回返回类型默认值」**未由复审者复现**，采信 worker/控制器实测。
4. **未检查真实数据文件**是否确实「所有权重 > 0」（Q1 的前提由 parent 给出）。
5. 未读 `world_tick_test.gd` / `creation_test.gd` 全文，故 `_picked_id` 是否与既有同名函数冲突只靠「21 套件 0 失败」间接确认；
   `Registry.from_tables` 对「全表复制 + 置空一表」是否返回结构完好注册表，靠夹具前置断言间接确认。

## 5. 对 finding #1（读档路径）裁定的意见

**无实质异议。** `player_state.gd` 不在本次 diff 范围内、也未读该文件，没有可用于反驳的证据；
「`from_dict` 忠实还原 + 只归一化单字段而不跑 `validate_choices` 不自洽」这一理由在逻辑上站得住，
归入「存档格式 v2」批次可接受。

**Merge verdict: OK with notes**（Minor 文档条目可与 v2 批次合并处理；若要本轮收口，改 `rng_service.gd:30/32` 两行注释即可。）

---

## 控制器处置（附于本记录，非 reviewer 原文）

- **Minor（契约①措辞）**：**当轮收口**（`aefd612`）——契约①改为「在**加权路径**中永不被抽中」并加一句
  「全零权重（`total ≤ 0`）时整体回退 `stream_pick`，此时零权重条目仍会被均匀抽中（见 ③）」；③ 补「同理」一维。
  **纯注释、无行为变化**（`test.sh` 逐项与修复轮 1 完全一致）⇒ 按快跑模式「注释改动免复审」，由控制器直接改（非派 worker）。
- **P2**：登记为残余，不改（当前数据不可达，且行为与旧写法等价）。
- **控制器独立数值验证**（补上「未验证 #1」的空白，实测非推理）：真实杖芯表 20 万次随机 roll 新旧差异 **0**；
  300 组随机全正权重表 × 500 次差异 **0**；与「恰好一次 `stream_float`」手工路径不一致 **0**（⇒ 流消耗未变）；
  仅累积边界 5 处不同（测度零点，与复审者纯静态推演**逐字吻合**）；真实表 6000 次 rare=834（13.9%，期望 14.3%）。
