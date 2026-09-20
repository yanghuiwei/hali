class_name AudioDirector
extends Node

# 计划 03a-P P4：按 `data/audio_cues.json` 播 SFX / 切 BGM。
#
# 契约（spec §3 + §4）：
#   * **传 null / 空清单 / 畸形清单 / 缺 cue / 缺素材 / 路径不存在 ⇒ 静音**，不报错、不阻塞回合。
#   * 未知 cue id、未知 BGM key 同样安全（静音）——这样「加素材 = 改一行 JSON」永不改代码。
#   * `play_cue()` 返回「**真的出声了吗**」，`last_cue_id()` 记的是「**被要求播什么**」。两者故意分开：
#     验证**触发点接线**看后者（没有 sfx 素材也必须能观测到「被调用过」），验证**素材接线**看前者。
#   * **不管循环**：`assets/audio/bgm/*.ogg` 的 `.import` 已设 `loop=true`（spec §8.4 实测），这里只 `play()`。
#
# ⚠️ **为什么把纯逻辑做成 `static`（设计要点，别改回去）**：
#   `AudioStreamPlayer` 只能在场景树上 `play()`（树外调 `play()` 会打
#   `ERROR: Playback can only happen when a node is inside the scene tree`）；
#   而实测在 headless `-s` 模式下**连创建 AudioStreamPlayer 节点**都会在退出时打
#   `ERROR: N resources still in use at exit`。这两条都会撞 `tools/test.sh` 的 stderr 噪音门禁。
#   ⇒ 分工：**纯解析/音量/换算逻辑做成 static**（单元测试直接调，不创建任何 Node）；
#     **真实播放路径由 B1 在真场景里验证**（`tools/b1_acceptance.gd`，那里界面真的在树上）。
#
# ⚠️ 资源加载这里按与 `Presentation` **同一套规矩**重写了一遍（先 `ResourceLoader.exists()` 再 `load()`）：
#    因为 `Presentation` 的加载器是私有的，而它公开的 `font()`/`texture()` 只认 Font/Texture2D，
#    拿不到 AudioStream。**按任务约束不许改 `Presentation` 的 API** ⇒ 宁可重复这几行也不动冻结接口。

const LOCATION_NS := "bgm_by_location"
const ERA_NS := "bgm_by_era"
# master_volume 为 0 时的 dB 下限（linear_to_db(0) 是 -inf，会让 volume_db 变成非法值）。
const SILENCE_DB := -60.0

var _presentation: Presentation = null
var _sfx: AudioStreamPlayer = null
var _bgm: AudioStreamPlayer = null
var _bgm_path: String = ""
var _last_cue: String = ""
# 本次会话里**被要求播过**的全部 cue（去重、按首次调用顺序）。
# 用途：B1 从外部断言「触发点真的接上了」——即使没有 sfx 素材（那时 `play_cue` 返回 false）也能判。
var _seen_cues: PackedStringArray = PackedStringArray()


# 工厂：建两个播放器子节点。`presentation` 允许为 null（= 全静音，不报错）。
static func create(presentation: Presentation) -> AudioDirector:
	var director := AudioDirector.new()
	director._presentation = presentation if presentation != null else Presentation.from_dicts({}, {})
	director._sfx = AudioStreamPlayer.new()
	director._sfx.name = "SfxPlayer"
	director.add_child(director._sfx)
	director._bgm = AudioStreamPlayer.new()
	director._bgm.name = "BgmPlayer"
	director.add_child(director._bgm)
	return director


# ---- 纯逻辑（static：单元测试直接调，不需要建 Node/进场景树） ----

# BGM key 的两种写法（spec §4「BGM 在换地点 / 时代变更时切」）：
#   1. 带命名空间：`bgm_by_location.hogwarts` / `bgm_by_era.modern`（main.gd 用这种，语义最明确）
#   2. 裸 key：先试 `bgm_by_location.<key>`，再试 `bgm_by_era.<key>`（**地点优先、时代兜底**）
static func resolve_bgm_path(presentation: Presentation, key: String) -> String:
	if presentation == null or key.is_empty():
		return ""
	if key.begins_with(LOCATION_NS + ".") or key.begins_with(ERA_NS + "."):
		return presentation.path(key)
	var by_location := presentation.path("%s.%s" % [LOCATION_NS, key])
	if not by_location.is_empty():
		return by_location
	return presentation.path("%s.%s" % [ERA_NS, key])


static func resolve_cue_path(presentation: Presentation, id: String) -> String:
	if presentation == null or id.is_empty():
		return ""
	return presentation.path("cues.%s" % id)


# cue 自带的 dB 偏移（已入清单的素材常用 `volume_db`）；缺失 / 非数值 ⇒ 0.0。
static func cue_offset_db(presentation: Presentation, id: String) -> float:
	if presentation == null:
		return 0.0
	var raw: Variant = presentation.entry("cues.%s" % id).get("volume_db", null)
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		return float(raw)
	return 0.0


# master_volume（线性 0..1）转 dB，再加 offset。0 ⇒ 压到 SILENCE_DB（-inf 是非法的）。
static func volume_db(master: float, offset_db: float) -> float:
	if master <= 0.0:
		return SILENCE_DB + offset_db
	return linear_to_db(clampf(master, 0.0, 1.0)) + offset_db


# 安全加载音频流：先 exists 再 load（直接 load 不存在的路径会打 `ERROR: Resource file not found`）。
static func load_stream(path_str: String) -> AudioStream:
	if path_str.is_empty() or not path_str.begins_with("res://"):
		return null
	if not ResourceLoader.exists(path_str):
		return null
	var res: Variant = load(path_str)
	if res is AudioStream:
		return res
	return null


# ---- 实例 API（需要场景树；未入树时只记状态、不 start 播放） ----

# 播一个 cue。返回「素材存在、已就绪（在场景树上则已 start）」；**无论是否出声**都记录 `last_cue_id()`，
# 所以「触发点有没有被调到」在没有 sfx 素材时同样可判。
func play_cue(id: String) -> bool:
	_last_cue = id
	if not id.is_empty() and not _seen_cues.has(id):
		_seen_cues.append(id)
	if _sfx == null:
		return false
	var stream := load_stream(resolve_cue_path(_presentation, id))
	if stream == null:
		return false
	_sfx.stream = stream
	_sfx.volume_db = volume_db(_master_volume(), cue_offset_db(_presentation, id))
	if is_inside_tree():
		_sfx.play()
	return true


# 切 BGM。返回「该 key 解析成功且已成为当前 BGM」——**幂等**：同一首重复设置也返回 true（不重启播放）。
# 解析不到 / 素材缺失 / 未入树 ⇒ false，且**不改变**当前 BGM（调用方据此走兜底，见 main.gd `_sync_bgm`）。
func set_bgm(key: String) -> bool:
	if _bgm == null:
		return false
	var path := resolve_bgm_path(_presentation, key)
	if path.is_empty() or not is_inside_tree():
		return false
	if path == _bgm_path:
		return true                      # 已经在放这一首：幂等成功，不重启（避免每回合从头播）
	var stream := load_stream(path)
	if stream == null:
		return false
	_bgm.stream = stream
	_bgm.volume_db = volume_db(_master_volume(), 0.0)
	_bgm.play()
	_bgm_path = path
	return true


func stop_all() -> void:
	if _sfx != null:
		_sfx.stop()
	if _bgm != null:
		_bgm.stop()
	_bgm_path = ""


# ---- 只读状态（供镜像观测与断言；未入树时同样有意义） ----

func last_cue_id() -> String:
	return _last_cue


# 本次会话里被要求播过的全部 cue id（去重、按首次调用顺序；副本）。
func cue_ids_seen() -> PackedStringArray:
	return _seen_cues.duplicate()


func current_bgm_path() -> String:
	return _bgm_path


func bgm_volume_db() -> float:
	return _bgm.volume_db if _bgm != null else SILENCE_DB


func sfx_volume_db() -> float:
	return _sfx.volume_db if _sfx != null else SILENCE_DB


func _master_volume() -> float:
	return _presentation.master_volume() if _presentation != null else 1.0
