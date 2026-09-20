class_name WorldFactions
extends RefCounted

# 机构 id 枚举：顺序即势力面板的展示顺序（第六十五章）。代码只硬编码 id，中文标签进 data/factions.json 的 institutions。
const INSTITUTIONS: Array[String] = ["law_enforcement", "auror_office", "wizengamot", "mysteries",
	"hogwarts", "gringotts", "daily_prophet", "international"]

# 派系类别枚举（第十二章权力四角 + 第六/二十六章）
const KINDS: Array[String] = ["ministry", "institution", "pureblood", "school", "commerce",
	"media", "resistance", "dark", "foreign", "society"]
const LEGAL_STATUS: Array[String] = ["legal", "shadow", "outlaw"]
const SECRECY: Array[String] = ["public", "semi", "secret"]

# kind → 权力四角（第十二章）。不在表里的 kind（resistance/dark/foreign/society）不进四角，
# 它们通过 control 与政体判定体现影响力。
const CORNERS: Dictionary = {
	"ministry": ["ministry", "institution"],
	"pureblood": ["pureblood"],
	"hogwarts": ["school"],
	"commerce": ["commerce", "media"],
}

const MINISTRY_ID := "ministry"
const RESISTANCE_ID := "order_of_phoenix"

# 状态键（都存在既有容器里：tension 进 world.flags，政体进 world.flags，派系状态进 world.factions）
const TENSION_FLAG := "social_tension"
const GOVERNMENT_FLAG := "government_type"
