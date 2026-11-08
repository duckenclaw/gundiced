class_name SpecialCell
extends Node2D
## Floor plate that changes AP when a player ends a turn on it.
## AP_BONUS: +2 AP on your own next turn. AP_DRAIN: -1 AP on the next player's turn.

enum Effect { AP_BONUS, AP_DRAIN }

var cell: Vector2i
var effect := Effect.AP_BONUS


func _ready() -> void:
	add_to_group("special_cell")
	var tex: Texture2D = load("res://assets/props/plate_bonus.png" if effect == Effect.AP_BONUS else "res://assets/props/plate_drain.png")
	var s := Props.make_sprite(self, tex, Grid.CELL - 6.0, false)
	s.modulate = Color(1, 1, 1, 0.92)


func place(c: Vector2i) -> void:
	cell = c
	position = Grid.to_world(c)
