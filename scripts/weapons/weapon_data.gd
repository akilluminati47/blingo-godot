extends Node
class_name WeaponData

# Mirror of the original BLINGO WEAPONS table
# cqc = extra close-range damage (fades to 0 by 8 metres)
# weak = weapon too puny to reliably pop a healthy head (far/weak headshots expose brain instead)
# dismember = base chance to sever a limb on a hit
# gib = head bursts on any headshot (insta-kill)
# melee: swung, infinite ammo
# execute = any hit (limb, chest, head) detonates the target in an instant kill
# slot = which inventory group the weapon sorts into

const DATA = {
	"fists": {
		"id": "fists", "name": "Fists",
		"melee": true, "slot": "melee", "dmg": 6, "range": 2.4, "rpm": 150,
		"mag": -1, "kick": 0.02, "cqc": 0.0, "weak": true, "dismember": 0.12
	},
	"jelly": {
		"id": "jelly", "name": "Good Jelly",
		"melee": true, "slot": "consumable", "consumable": true, "dmg": 6, "range": 2.4,
		"rpm": 150, "mag": -1, "kick": 0.02, "cqc": 0.0, "weak": true, "dismember": 0.12
	},
	"chili": {
		"id": "chili", "name": "Red's Chili",
		"melee": true, "slot": "consumable", "consumable": true, "dmg": 6, "range": 2.4,
		"rpm": 150, "mag": -1, "kick": 0.02, "cqc": 0.0, "weak": true, "dismember": 0.12
	},
	"pipe": {
		"id": "pipe", "name": "Lead Pipe",
		"melee": true, "slot": "melee", "dmg": 16, "range": 3.1, "rpm": 150,
		"mag": -1, "kick": 0.03, "cqc": 0.0, "dismember": 0.28, "color": Color(0.545, 0.565, 0.600)
	},
	"bat": {
		"id": "bat", "name": "Slugger Bat",
		"melee": true, "slot": "melee", "dmg": 19, "range": 3.4, "rpm": 130,
		"mag": -1, "kick": 0.04, "cqc": 0.0, "dismember": 0.34, "color": Color(0.541, 0.353, 0.165)
	},
	"machete": {
		"id": "machete", "name": "Machete",
		"melee": true, "slot": "melee", "dmg": 23, "range": 3.2, "rpm": 155,
		"mag": -1, "kick": 0.03, "cqc": 0.0, "dismember": 0.82, "color": Color(0.718, 0.737, 0.769)
	},
	"katana": {
		"id": "katana", "name": "Katana",
		"melee": true, "slot": "melee", "dmg": 27, "range": 3.7, "rpm": 175,
		"mag": -1, "kick": 0.03, "cqc": 0.0, "dismember": 0.95, "gib": true, "color": Color(0.847, 0.867, 0.898)
	},
	"sledge": {
		"id": "sledge", "name": "Sledgehammer",
		"melee": true, "slot": "melee", "dmg": 39, "range": 3.1, "rpm": 72,
		"mag": -1, "kick": 0.09, "cqc": 0.0, "dismember": 0.6, "gib": true, "color": Color(0.361, 0.376, 0.408)
	},
	"axe": {
		"id": "axe", "name": "Fire Axe",
		"melee": true, "slot": "melee", "dmg": 31, "range": 3.2, "rpm": 96,
		"mag": -1, "kick": 0.06, "cqc": 0.0, "dismember": 0.9, "gib": true, "color": Color(0.761, 0.227, 0.165)
	},
	"pistol": {
		"id": "pistol", "name": "Pistol",
		"slot": "gun", "dmg": 5, "mag": 18, "rpm": 320, "auto": false,
		"spread": 0.012, "ammo": 90, "color": Color(0.333, 0.353, 0.400),
		"kick": 0.025, "cqc": 0.45, "weak": true, "dismember": 0.14,
		"fRange": 14.0, "oneHand": true
	},
	"smg": {
		"id": "smg", "name": "SMG",
		"slot": "gun", "dmg": 2, "mag": 50, "rpm": 800, "auto": true,
		"spread": 0.038, "ammo": 200, "color": Color(0.227, 0.247, 0.290),
		"kick": 0.015, "cqc": 0.5, "weak": true, "dismember": 0.1,
		"fRange": 9.0, "oneHand": true
	},
	"rifle": {
		"id": "rifle", "name": "Assault Rifle",
		"slot": "gun", "dmg": 5, "mag": 40, "rpm": 560, "auto": true,
		"spread": 0.022, "ammo": 160, "color": Color(0.318, 0.267, 0.180),
		"kick": 0.02, "cqc": 0.5, "dismember": 0.32,
		"armSever": true, "skullcrack": true, "fRange": 30.0
	},
	"shotgun": {
		"id": "shotgun", "name": "Shotgun",
		"slot": "gun", "dmg": 2, "mag": 10, "rpm": 300, "auto": false,
		"spread": 0.11, "ammo": 60, "pellets": 12, "color": Color(0.431, 0.239, 0.122),
		"kick": 0.09, "cqc": 2.0, "dismember": 0.75, "gib": true, "fRange": 7.0
	},
	"magnum": {
		"id": "magnum", "name": "Magnum",
		"slot": "gun", "dmg": 10, "mag": 10, "rpm": 160, "auto": false,
		"spread": 0.008, "ammo": 60, "color": Color(0.541, 0.561, 0.604),
		"kick": 0.05, "cqc": 0.6, "dismember": 0.6, "gib": true, "fRange": 18.0, "oneHand": true
	},
	"sniper": {
		"id": "sniper", "name": "Sniper Rifle",
		"slot": "gun", "dmg": 22, "mag": 8, "rpm": 45, "auto": false,
		"spread": 0.002, "ammo": 40, "color": Color(0.184, 0.290, 0.208),
		"kick": 0.11, "cqc": 0.2, "dismember": 1.0, "gib": true, "execute": true
	},
}

const SLOT_ORDER = [
	"fists", "jelly", "chili",
	"pipe", "bat", "machete", "katana", "sledge", "axe",
	"pistol", "smg", "rifle", "shotgun", "magnum", "sniper"
]

const COMBO_WINDOW: float = 0.75
const MELEE_REST: float = -2.45

enum LimbKind { ARM, LEG }
enum HitResult { NONE, BODY, HEAD, LIMB, WEAKSPOT }


static func get_weapon(id: String) -> Dictionary:
	return DATA.get(id, DATA["fists"])


static func slot_rank(id: String) -> int:
	var i = SLOT_ORDER.find(id)
	return i if i >= 0 else 99


static func close_bonus(w: Dictionary, d: float) -> float:
	return 1.0 + w.get("cqc", 0.0) * clampf(1.0 - d / 8.0, 0.0, 1.0)


static func range_factor(w: Dictionary, d: float) -> float:
	if w.get("melee", false):
		return 1.0
	var fr: float = w.get("fRange", -1.0)
	if fr <= 0.0 or d <= fr:
		return 1.0
	return maxf(0.4, 1.0 - (d - fr) * 0.035)


class HitInfo:
	var target: Node3D
	var distance: float
	var is_head: bool = false
	var limb: Dictionary = {}
	var weakspot: bool = false
	var crow: bool = false

	func _init(p_target: Node3D = null, p_distance: float = 0.0) -> void:
		target = p_target
		distance = p_distance
