class_name Crate
extends Node2D
## Pushable cover. 1 HP (a components_kit Health), blocks movement and shots,
## and is pushed in chains by Board.try_push.

const TEX := preload("res://assets/props/crate.png")

var cell: Vector2i
var health: Health
var _sprite: Sprite2D
var _move_tween: Tween


func _ready() -> void:
	add_to_group("crate")
	add_to_group("occupant")
	_sprite = Props.make_sprite(self, TEX, 60.0)
	health = Health.new()
	health.max_health = 1.0
	health.current_health = 1.0
	add_child(health)
	health.died.connect(_on_died)


func place(c: Vector2i) -> void:
	cell = c
	position = Grid.to_world(c)


func slide_to(c: Vector2i) -> void:
	cell = c
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position", Grid.to_world(c), 0.12)


func take_hit(_dir: Vector2i) -> void:
	health.take_damage(1.0, null)
	if not health.is_dead():
		Fx.flash(_sprite)


func _on_died() -> void:
	remove_from_group("occupant")
	remove_from_group("crate")
	Fx.debris(get_parent(), position, Color(0.62, 0.42, 0.22))
	Sfx.named("crate_break")
	queue_free()
