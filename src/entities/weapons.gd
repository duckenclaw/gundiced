class_name Weapons
## Weapon table. Everyone starts with an endless revolver; pickups swap in a
## special weapon with limited ammo, and you fall back to the revolver when it
## runs dry. The shield is a separate pickup (see Player.has_shield).

enum Kind { REVOLVER, SNIPER, RPG, MOLOTOV, GRENADE }

## ammo < 0 means unlimited.
const DATA := {
	Kind.REVOLVER: {"name": "Revolver", "ammo": -1, "tex": "res://assets/weapons/revolver.png",
		"hint": "First thing in the line takes the hit."},
	Kind.SNIPER: {"name": "Sniper", "ammo": 2, "tex": "res://assets/weapons/sniper-rifle.png",
		"hint": "Pierces crates and doors."},
	Kind.RPG: {"name": "RPG", "ammo": 1, "tex": "res://assets/weapons/rpg.png",
		"hint": "Explodes in a + on impact. Mind the splash."},
	Kind.MOLOTOV: {"name": "Molotov", "ammo": 1, "tex": "res://assets/weapons/molotov.png",
		"hint": "Thrown. Sets a + on fire until your next turn."},
	Kind.GRENADE: {"name": "Grenade", "ammo": 1, "tex": "res://assets/weapons/grenade.png",
		"hint": "Thrown. Explodes at the start of your next turn."},
}

const SHIELD_TEX := "res://assets/weapons/shield.png"


static func display_name(kind: int) -> String:
	return DATA[kind]["name"]


static func ammo(kind: int) -> int:
	return DATA[kind]["ammo"]


static func texture(kind: int) -> Texture2D:
	return load(DATA[kind]["tex"])


static func is_thrown(kind: int) -> bool:
	return kind == Kind.MOLOTOV or kind == Kind.GRENADE
