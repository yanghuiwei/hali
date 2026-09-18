#!/usr/bin/env bash
# 唯一测试入口：先做导入（生成 .godot 缓存），再跑单测，最后跑主场景冒烟。
# 用法: bash tools/test.sh   （可用 GODOT=/path/to/godot 覆盖引擎路径）
set -uo pipefail

# 默认引擎在当前目录：Git Bash 的 PATH 不含 "."，必须带 ./ 前缀才能执行
GODOT="${GODOT:-./Godot_v4.7.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "找不到 Godot 可执行文件: $GODOT（用 GODOT=... 指定）" >&2
	exit 2
fi

echo "== 1/3 导入资源（生成 .godot 缓存，class_name 全局类依赖它） =="
"$GODOT" --headless --path . --import >/dev/null 2>&1

echo "== 2/3 单元测试 =="
"$GODOT" --headless --path . --script res://tests/run_tests.gd
unit=$?

echo "== 3/3 主场景冒烟 =="
if [ -f "$ROOT/ui/main.tscn" ]; then
	"$GODOT" --headless --path . --quit-after 5
	smoke=$?
else
	echo "（跳过：ui/main.tscn 尚未创建，任务 11 将启用）"
	smoke=0
fi

if [ "$unit" -ne 0 ] || [ "$smoke" -ne 0 ]; then
	echo "测试失败：单测=$unit 冒烟=$smoke" >&2
	exit 1
fi
echo "全部通过。"
