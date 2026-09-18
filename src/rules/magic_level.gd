class_name MagicLevel
extends RefCounted

enum Tier { SQUIB, PRE_SCHOOL, FIRST_YEAR, OWL, NEWT, ADULT, EXPERT, MASTER, LEGEND, MYTH }

const LABELS: Array[String] = [
	"哑炮", "麻瓜出身未入学", "霍格沃茨新生", "O.W.L水平", "N.E.W.T水平",
	"熟练成年巫师", "专家级", "大师级", "传奇级", "神话级",
]

# 第二十二章施法失败概率，逐字编码为区间
const BANDS: Array[Vector2] = [
	Vector2(1.00, 1.00),   # 哑炮：无法施法
	Vector2(0.60, 0.80),   # 新手/未入学
	Vector2(0.30, 0.50),   # 霍格沃茨低年级
	Vector2(0.15, 0.30),   # O.W.L
	Vector2(0.05, 0.15),   # N.E.W.T
	Vector2(0.02, 0.05),   # 熟练成年巫师
	Vector2(0.02, 0.05),   # 专家级
	Vector2(0.005, 0.02),  # 大师级
	Vector2(0.005, 0.015), # 传奇级
	Vector2(0.005, 0.01),  # 神话级
]

const MODIFIER_KEYS: Array[String] = [
	"combat_stress", "injury", "emotion", "wand_mismatch", "unfamiliar_spell", "dark_magic_interference",
]

const MODIFIER_WEIGHT := 0.15

static func label_of(tier: int) -> String:
	if tier < 0 or tier >= LABELS.size():
		return "未知"
	return LABELS[tier]

static func index_of_label(label: String) -> int:
	return LABELS.find(label)

static func base_rate(tier: int) -> float:
	var band: Vector2 = BANDS[clampi(tier, 0, BANDS.size() - 1)]
	return (band.x + band.y) * 0.5

static func effective_rate(tier: int, modifiers: Dictionary, aptitude_delta: float = 0.0) -> float:
	var clamped_tier := clampi(tier, 0, BANDS.size() - 1)
	if clamped_tier == Tier.SQUIB:
		return 0.95
	var rate := base_rate(clamped_tier) + aptitude_delta
	for key in MODIFIER_KEYS:
		rate += clampf(float(modifiers.get(key, 0.0)), 0.0, 1.0) * MODIFIER_WEIGHT
	return clampf(rate, 0.005, 0.95)
