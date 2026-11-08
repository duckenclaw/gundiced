class_name Hazard
extends Node2D
## Lingering effect from a thrown weapon. The match calls on_turn_started(player)
## at every turn start.
##   FIRE: deadly to anyone on or entering its cells; burns out at the start of
##         the thrower's next turn.
##   GRENADE: inert until the thrower's next turn starts, then explodes in a +.

enum Type { FIRE, GRENADE }

var type := Type.FIRE
var cells: Array[Vector2i] = []
var thrower: Node
var board: Node
var _t := 0.0


func _ready() -> void:
	add_to_group("hazard")
	z_index = 1
	if type == Type.FIRE:
		for c in cells:
			if board.is_open_floor(c):
				Fx.fire(self, Grid.to_world(c))
	else:
		var icon := Props.make_sprite(self, Weapons.texture(Weapons.Kind.GRENADE), 34.0, false)
		icon.position = Grid.to_world(cells[0])


func is_deadly(cell: Vector2i) -> bool:
	return type == Type.FIRE and cell in cells


func on_turn_started(player: Node) -> void:
	if player != thrower:
		return
	if type == Type.GRENADE:
		board.explode(cells[0], Vector2i.ZERO)
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var half := Vector2(Grid.CELL, Grid.CELL) * 0.5
	for c in cells:
		if not board.is_open_floor(c):
			continue
		var r := Rect2(Grid.to_world(c) - half, half * 2.0)
		if type == Type.FIRE:
			var a := 0.28 + 0.08 * sin(_t * 9.0 + c.x * 1.7 + c.y)
			draw_rect(r, Color(1.0, 0.45, 0.1, a))
		else:
			var a := 0.35 + 0.25 * sin(_t * 6.0)
			draw_rect(r.grow(-3), Color(1.0, 0.2, 0.15, a), false, 3.0)
