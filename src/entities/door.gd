class_name Door
extends Node2D
## A door is a plank one cell long, hinged on a grid corner. It always lies on
## exactly one cell edge and blocks only that edge, for movement and for shots.
##
##   closed (0):  on the edge between cell_a and cell_b
##   open (+90):  swung into cell_b, lying on cell_b's edge on the hinge side
##   open (-90):  swung into cell_a, lying on cell_a's edge on the hinge side
##
## Walking across the edge the door currently blocks pushes it 90 degrees in
## the direction of motion; a push that would take it past ±90 is refused.
## Edges the door doesn't lie on are free. 1 HP.

const TEX := preload("res://assets/props/door.png")
const THICKNESS := 14.0

var cell_a: Vector2i  ## left / top cell of the closed edge
var cell_b: Vector2i  ## right / bottom cell of the closed edge
var hinge_side: Vector2i  ## along the closed edge, towards the hinge corner
var rotation_state := 0
var health: Health
var _pivot: Node2D
var _tween: Tween


## `c` is cell_b. `vertical`: the door sits on c's left edge (else its top edge).
## `hinge_far`: hinge at the bottom (vertical) / right (horizontal) end.
func setup(c: Vector2i, vertical: bool, hinge_far := false) -> void:
	cell_b = c
	if vertical:
		cell_a = c + Vector2i.LEFT
		hinge_side = Vector2i.DOWN if hinge_far else Vector2i.UP
	else:
		cell_a = c + Vector2i.UP
		hinge_side = Vector2i.RIGHT if hinge_far else Vector2i.LEFT
	var mid := (Grid.to_world(cell_a) + Grid.to_world(cell_b)) * 0.5
	position = mid + Vector2(hinge_side) * Grid.CELL * 0.5


func _ready() -> void:
	add_to_group("door")
	_pivot = Node2D.new()
	add_child(_pivot)
	var hinge := Sprite2D.new()
	hinge.texture = Fx.soft_circle()
	hinge.modulate = Color(0.15, 0.1, 0.07, 0.8)
	hinge.scale = Vector2(0.28, 0.28)
	add_child(hinge)
	var s := Sprite2D.new()
	s.texture = TEX
	s.scale = Vector2(Grid.CELL / float(TEX.get_width()), THICKNESS / TEX.get_height())
	s.position = Vector2(Grid.CELL * 0.5, 0)  # plank extends from the hinge along +x
	_pivot.add_child(s)
	_pivot.rotation = _angle_for(rotation_state)
	health = Health.new()
	health.max_health = 1.0
	health.current_health = 1.0
	add_child(health)
	health.died.connect(_on_died)


func is_open() -> bool:
	return rotation_state != 0


## The two cells on either side of the edge the door currently lies on.
func edge() -> Array[Vector2i]:
	match rotation_state:
		90: return [cell_b, cell_b + hinge_side]
		-90: return [cell_a, cell_a + hinge_side]
	return [cell_a, cell_b]


func spans(a: Vector2i, b: Vector2i) -> bool:
	var e := edge()
	return (a == e[0] and b == e[1]) or (a == e[1] and b == e[0])


## Can a mover cross the door's edge from `from` to `to`? (Only asked when
## spans(from, to).) Crossing pushes the door one quarter turn.
func can_pass(_from: Vector2i, to: Vector2i) -> bool:
	match rotation_state:
		0: return true
		90: return to == cell_b  # pushed back closed through cell_b
		-90: return to == cell_a
	return false


func pass_through(_from: Vector2i, to: Vector2i) -> void:
	if rotation_state == 0:
		rotation_state = 90 if to == cell_b else -90
	else:
		rotation_state = 0
	Sfx.named("door", 1.0, 0.12)
	if _tween:
		_tween.kill()
	var from_angle := _pivot.rotation
	var to_angle := _angle_for(rotation_state)
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float) -> void:
		_pivot.rotation = lerp_angle(from_angle, to_angle, t), 0.0, 1.0, 0.25)


## World angle of the plank (pointing away from the hinge) for a state.
func _angle_for(state: int) -> float:
	match state:
		90: return Vector2(cell_b - cell_a).angle()
		-90: return Vector2(cell_a - cell_b).angle()
	return Vector2(-hinge_side).angle()


func take_hit(_dir: Vector2i) -> void:
	health.take_damage(1.0, null)


func _on_died() -> void:
	remove_from_group("door")
	var e := edge()
	Fx.debris(get_parent(), (Grid.to_world(e[0]) + Grid.to_world(e[1])) * 0.5, Color(0.55, 0.36, 0.2))
	Sfx.named("crate_break", 0.8)
	queue_free()
