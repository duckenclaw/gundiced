class_name Pickup
extends Node2D
## Floor pickup, collected by stepping onto its cell (no extra AP).
## kind is a Weapons.Kind, or SHIELD.

const SHIELD := 100

var cell: Vector2i
var kind := Weapons.Kind.SNIPER
var _sprite: Sprite2D
var _outline: Sprite2D


func _ready() -> void:
	add_to_group("pickup")
	var tex: Texture2D = load(Weapons.SHIELD_TEX) if kind == SHIELD else Weapons.texture(kind)
	var glow := Sprite2D.new()
	glow.texture = Fx.soft_circle()
	glow.modulate = Color(1, 0.85, 0.35, 0.55)
	glow.scale = Vector2(1.0, 0.5)
	glow.position = Vector2(0, 16)
	add_child(glow)
	var gt := create_tween().set_loops()
	gt.tween_property(glow, "modulate:a", 0.25, 0.6).set_trans(Tween.TRANS_SINE)
	gt.tween_property(glow, "modulate:a", 0.6, 0.6).set_trans(Tween.TRANS_SINE)
	# Dark outline copy behind the icon so thin guns read on busy floors.
	var outline := Props.make_sprite(self, tex, 54.0, false)
	outline.modulate = Color(0.08, 0.05, 0.04, 0.9)
	outline.scale *= 1.12
	_sprite = Props.make_sprite(self, tex, 54.0, false)
	_outline = outline
	var t := create_tween().set_loops()
	t.tween_property(_sprite, "position:y", -6.0, 0.6).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_outline, "position:y", -6.0, 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(_sprite, "position:y", 2.0, 0.6).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_outline, "position:y", 2.0, 0.6).set_trans(Tween.TRANS_SINE)


func place(c: Vector2i) -> void:
	cell = c
	position = Grid.to_world(c)


func label() -> String:
	return "Shield" if kind == SHIELD else Weapons.display_name(kind)


func collect() -> void:
	remove_from_group("pickup")
	var t := create_tween().set_parallel()
	t.tween_property(self, "scale", Vector2(1.6, 1.6), 0.18)
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.chain().tween_callback(queue_free)
