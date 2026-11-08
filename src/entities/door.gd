class_name Door
extends Node2D
## A door sits on the edge between two cells and pivots on that edge's midpoint.
## rotation_state is the offset from closed, one of {-90, 0, +90}. Every pass
## through rotates it 90 degrees in the direction of motion; going past ±90 is
## refused. Closed doors block the edge; open doors lie across cell_a/cell_b and
## stop shots that cross them side-on. 1 HP.

const TEX := preload("res://assets/props/door.png")

var cell_a: Vector2i  ## left / top cell
var cell_b: Vector2i  ## right / bottom cell
var vertical_edge := false  ## true: between left/right cells (blocks E-W when closed)
var rotation_state := 0
var health: Health
var _sprite: Sprite2D
var _closed_deg := 0.0
var _tween: Tween


## `c` is cell_b; `vertical` picks the edge on c's left (true) or top (false).
func setup(c: Vector2i, vertical: bool) -> void:
	vertical_edge = vertical
	cell_b = c
	cell_a = c + (Vector2i.LEFT if vertical else Vector2i.UP)
	var mid := (Grid.to_world(cell_a) + Grid.to_world(cell_b)) * 0.5
	position = mid
	_closed_deg = 90.0 if vertical else 0.0
	rotation_degrees = _closed_deg


func _ready() -> void:
	add_to_group("door")
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	var size := TEX.get_size()
	_sprite.scale = Vector2(Grid.CELL / size.x, 16.0 / size.y)
	add_child(_sprite)
	health = Health.new()
	health.max_health = 1.0
	health.current_health = 1.0
	add_child(health)
	health.died.connect(_on_died)


func is_open() -> bool:
	return rotation_state != 0


func spans(a: Vector2i, b: Vector2i) -> bool:
	return (a == cell_a and b == cell_b) or (a == cell_b and b == cell_a)


## Would passing from `from` to `to` be allowed?
func can_pass(from: Vector2i, to: Vector2i) -> bool:
	var next := rotation_state + (90 if to == cell_b else -90)
	return next >= -90 and next <= 90 and from != to


func pass_through(_from: Vector2i, to: Vector2i) -> void:
	rotation_state += 90 if to == cell_b else -90
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation_degrees", _closed_deg + rotation_state, 0.22)


## An open door lies across both of its cells, so a shot moving along the
## door's edge axis (vertical shots for a vertical-edge door) runs into it there.
func blocks_shot_in(cell: Vector2i, dir: Vector2i) -> bool:
	if not is_open() or (cell != cell_a and cell != cell_b):
		return false
	return dir.y != 0 if vertical_edge else dir.x != 0


func take_hit(_dir: Vector2i) -> void:
	health.take_damage(1.0, null)


func _on_died() -> void:
	remove_from_group("door")
	Fx.debris(get_parent(), position, Color(0.55, 0.36, 0.2))
	queue_free()
