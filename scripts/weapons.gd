class_name Weapons
extends RefCounted
## Weapon definitions. Tweak numbers here to change how each gun feels.

const MG := 0
const SHOTGUN := 1
const ROCKET := 2
const RAIL := 3

const LIST := [
	{"name": "MACHINEGUN", "short": "MG", "type": "hitscan", "fx": "tracer", "cooldown": 0.09,
		"damage": 7.0, "pellets": 1, "spread": 0.018, "range": 250.0,
		"color": Color(1.0, 0.8, 0.35), "sfx": "mg", "vol": -7.0, "kick": 0.3},
	{"name": "SHOTGUN", "short": "SG", "type": "hitscan", "fx": "tracer", "cooldown": 0.95,
		"damage": 7.0, "pellets": 12, "spread": 0.075, "range": 120.0,
		"color": Color(1.0, 0.55, 0.2), "sfx": "shotgun", "vol": -1.0, "kick": 1.25},
	{"name": "ROCKET LAUNCHER", "short": "RL", "type": "rocket", "fx": "", "cooldown": 0.8,
		"damage": 100.0, "pellets": 0, "spread": 0.0, "range": 0.0,
		"color": Color(1.0, 0.3, 0.2), "sfx": "rocket_fire", "vol": -2.0, "kick": 0.8},
	{"name": "RAILGUN", "short": "RG", "type": "hitscan", "fx": "rail", "cooldown": 1.5,
		"damage": 90.0, "pellets": 1, "spread": 0.0, "range": 400.0,
		"color": Color(0.3, 1.0, 0.6), "sfx": "rail", "vol": -1.0, "kick": 1.35},
]
