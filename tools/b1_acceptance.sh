#!/usr/bin/env bash
# B1 人工 GUI 验收的自动跑法（不进 tools/test.sh：它会写 user://，不适合当常规测试入口）。
#   * 跑之前把用户的 llm_settings.json / saves/slot1.json 备份到临时目录，退出时（含崩溃）一定还原；
#   * 以 HALI_DEBUG_LOG=1 headless 运行 tools/b1_acceptance.gd（该脚本内部也会备份/还原一次，双保险）；
#   * 逐项核对计划 01 Step 6 的 8 项清单 + 计划 02 追加的 2 项，退出码即验收结论。
# 用法: bash tools/b1_acceptance.sh   （GODOT=/path/to/godot 可覆盖引擎）
set -uo pipefail

GODOT="${GODOT:-./Godot_v4.7.2-stable_win64_console.exe}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "找不到 Godot 可执行文件: $GODOT（用 GODOT=... 指定）" >&2
	exit 2
fi

USERDIR="${APPDATA:-}/Godot/app_userdata/哈利·波特·魔法纪元"
BACKUP="$(mktemp -d)"
restore() {
	if [ -f "$BACKUP/llm_settings.json" ]; then
		cp -f "$BACKUP/llm_settings.json" "$USERDIR/llm_settings.json"
	fi
	if [ -f "$BACKUP/slot1.json" ]; then
		mkdir -p "$USERDIR/saves"
		cp -f "$BACKUP/slot1.json" "$USERDIR/saves/slot1.json"
	fi
	rm -rf "$BACKUP"
}
trap restore EXIT

if [ -n "${APPDATA:-}" ] && [ -d "$USERDIR" ]; then
	if [ -f "$USERDIR/llm_settings.json" ]; then
		cp -f "$USERDIR/llm_settings.json" "$BACKUP/llm_settings.json"
		echo "（已备份 llm_settings.json；验收期间临时移走，结束还原）"
	fi
	if [ -f "$USERDIR/saves/slot1.json" ]; then
		cp -f "$USERDIR/saves/slot1.json" "$BACKUP/slot1.json"
		echo "（已备份 saves/slot1.json；结束还原）"
	fi
else
	echo "（警告：找不到 user:// 目录，跳过备份；验收会写入 user://）" >&2
fi

HALI_DEBUG_LOG=1 "$GODOT" --headless --path . --script res://tools/b1_acceptance.gd
code=$?

echo ""
if [ "$code" -eq 0 ]; then
	echo "B1 自动验收：全部通过。"
else
	echo "B1 自动验收：存在失败项，见上方 [FAIL] / [B1-FAIL]。" >&2
fi
exit "$code"
