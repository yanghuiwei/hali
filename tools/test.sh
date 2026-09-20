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

echo "== 1/4 导入资源（生成 .godot 缓存，class_name 全局类依赖它） =="
"$GODOT" --headless --path . --import >/dev/null 2>&1

echo "== 2/4 单元测试 =="
unit_log="$(mktemp)"
"$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1 | tee "$unit_log"
unit=${PIPESTATUS[0]}

# ---- stderr 噪音门禁（这两个数字是「健康指标」，不是失败）----
#   SCRIPT ERROR == 2：save_codec 的坏档负例（HANDOFF §8#48）
#   ERROR        == 7：5 条 save_codec 的畸形 JSON 负例 + 2 条 gm_test 的「submit() 不能驱动协程 GM」负例
# 只有**故意**增删负例时才改这两个常量，并在提交信息里写明原因。
# 为什麽必须有这道门禁：“解析 JSON 失败 / 资源加载失败 / 类型赋值错误”这类噪音，
# **套件内的断言抓不到**（03a-P P1+P2 破坏实验 S2 实测：拆掉守卫后套件 81/0 全绿，而外部 ERROR: 由 7 → 12）。
# 临时实验可用 EXPECTED_SCRIPT_ERRORS= / EXPECTED_PLAIN_ERRORS= 覆盖。
EXPECTED_SCRIPT_ERRORS="${EXPECTED_SCRIPT_ERRORS:-2}"
EXPECTED_PLAIN_ERRORS="${EXPECTED_PLAIN_ERRORS:-7}"
script_errors="$(grep -c 'SCRIPT ERROR' "$unit_log" || true)"
plain_errors="$(grep -c '^ERROR:' "$unit_log" || true)"
if [ "$script_errors" != "$EXPECTED_SCRIPT_ERRORS" ]; then
	echo "stderr 噪音门禁失败：SCRIPT ERROR=$script_errors，期望 $EXPECTED_SCRIPT_ERRORS" >&2
	unit=1
fi
if [ "$plain_errors" != "$EXPECTED_PLAIN_ERRORS" ]; then
	echo "stderr 噪音门禁失败：ERROR=$plain_errors，期望 $EXPECTED_PLAIN_ERRORS（新增噪音通常是真 bug：JSON 解析失败 / 资源加载失败 / 类型错误）" >&2
	unit=1
fi
rm -f "$unit_log"

echo "== 3/4 主场景冒烟（默认配置：必须与未加调试镜像时逐字一致） =="
smoke=0
if [ -f "$ROOT/src/ui/main.tscn" ]; then
	smoke_log="$(mktemp)"
	trap 'rm -f "$smoke_log"' EXIT
	"$GODOT" --headless --path . --quit-after 5 2>&1 | tee "$smoke_log"
	smoke=${PIPESTATUS[0]}
	# 只看退出码不够：脚本加载失败但引擎返回 0 时会假绿，必须确认场景真的 _ready 了
	if ! grep -q "main scene ready" "$smoke_log"; then
		echo "主场景冒烟未出现 'main scene ready'（脚本可能未加载）" >&2
		smoke=1
	fi
	# 反向断言：没设 HALI_DEBUG_LOG 时一行镜像都不许出现（默认行为不变）
	if grep -q -F '[HALI]' "$smoke_log"; then
		echo "主场景冒烟在未设置 HALI_DEBUG_LOG 时出现了镜像输出（默认行为被改变）" >&2
		smoke=1
	fi
	rm -f "$smoke_log"
else
	echo "（跳过：src/ui/main.tscn 尚未创建，任务 11 将启用）"
fi

echo "== 4/4 调试镜像冒烟（HALI_DEBUG_LOG=1，B1 人工验收的观测通道） =="
probe=0
if [ -f "$ROOT/tools/ui_debug_probe.gd" ]; then
	probe_log="$(mktemp)"
	trap 'rm -f "$probe_log"' EXIT
	HALI_DEBUG_LOG=1 "$GODOT" --headless --path . --script res://tools/ui_debug_probe.gd 2>&1 | tee "$probe_log"
	probe=${PIPESTATUS[0]}
	for marker in '[HALI] 调试镜像已启用' '[HALI] PROBE-APPEND-MARK' '[HALI] [状态行] PROBE-STATUS-MARK' \
			'[HALI] [输入框] editable=false' '[HALI] [按钮] 整排 禁用'; do
		if ! grep -q -F "$marker" "$probe_log"; then
			echo "调试镜像未输出预期行: $marker" >&2
			probe=1
		fi
	done
	rm -f "$probe_log"
else
	echo "（跳过：tools/ui_debug_probe.gd 不存在）"
fi

if [ "$unit" -ne 0 ] || [ "$smoke" -ne 0 ] || [ "$probe" -ne 0 ]; then
	echo "测试失败：单测=$unit 冒烟=$smoke 镜像=$probe" >&2
	exit 1
fi
echo "全部通过。"
