# Task 10 第二轮修复 scoped 复审简报（reviewer）

> 只读审查。可用工具：read、bash（仅只读命令 + `bash tools/test.sh`）。禁止修改文件、禁止 git 写操作。
> 仓库根 `E:/Hali`，分支 `plan-01-core-foundation`。

## 背景

第一轮复审（`docs/sdd/plan-01-core-foundation/task-10-rereview.md`，范围 `dbd93d2..09661d0`）结论**通过**，
但列出残余 Important：`save_version` 为 `null`/`[]`/`{}` 时在 `int()` 处运行期报错、`decode` 返回空字典 `{}`；
并提到嵌套畸形会产生「毒对象」（`world.player`/`world.clock` 为 null 但 `ok=true`）。
控制器提交 `4729352`（父 `09661d0`）做小修。本次复审只针对这个增量，范围 `09661d0..4729352`。

## 变更内容

- `src/persist/save_codec.gd`：把 `_validate_payload()` 调用**前移到** `int(save_version)` 之前；
  `WorldState.from_dict` 之后新增 `world == null or world.player == null or world.clock == null` 失败兜底。
- `tests/save_test.gd`：畸形载荷列表从 7 组扩到 11 组（新增 `save_version:null`、`save_version:[]`、
  `player.personality:123`、`clock.year:[]`）；断言改为 `res.has("ok")` + `res.get("ok", true)` + `res.get("world", null)`，
  以捕获「返回空字典」的情形。
- 计划文档同步。

## 必须核对

1. **`save_version` 逃逸是否真的关闭**：`{"save_version":null}` / `[]` / `{}` 现在是否返回
   `{"ok":false,"error":...,"world":null}`（而非 `{}`）。请独立复现（自建临时脚本，审完删除）。
2. **毒对象兜底是否生效**：`{"save_version":1,"player":{"personality":123}}`、
   `{"save_version":1,"clock":{"year":[]}}` 现在是否 `ok=false`（而不是 `ok=true, world.player/clock=null`）。
   是否仍有其它可构造的毒对象路径未被兜底（嵌套 `player.magic/wand/skills` 等），如实登记为残余。
3. **是否引入回归**：合法存档往返、`SaveStore` 读写槽、端到端续跑断言是否仍然通过；
   `_validate_payload` 前移后，合法载荷（`save_version` 为 JSON 数字 → `TYPE_FLOAT`）是否仍被接受。
4. **测试断言是否真的判别**：`res.has("ok")` 是否能在 `decode` 返回 `{}` 时失败（即反证一次：
   临时把校验顺序改回 `int()` 在前、去掉前移，确认 `#7/#8` 变红，再还原）。
5. **越界/夹带**：`git diff --name-only 09661d0..4729352` 是否只有上述 3 个文件；
   `src/model/`、`src/core/turn_engine.gd`、`data/` 是否未动；计划代码块与三个成品文件是否仍逐字节一致（可复算）。
6. 跑一次 `bash tools/test.sh`：`[save] 断言=81 失败=0`、`总计失败=0`、`ALL TESTS PASSED`、退出码 0。

## 输出格式（直接返回文本；controller 转存为 task-10-rereview2.md）

```markdown
# Task 10 第二轮修复 scoped 复审记录

审查者：<reviewer subagent>　模型：deepseek-flash　范围：09661d0..4729352

## 结论
- save_version 逃逸：ADDRESSED / PARTIAL / NOT ADDRESSED
- 毒对象兜底：ADDRESSED / PARTIAL / NOT ADDRESSED
- 新缺陷：无 / 有
- 裁定：**通过** / **不通过**

## 证据
## 残余风险 / 建议
## 未验证/存疑
```
