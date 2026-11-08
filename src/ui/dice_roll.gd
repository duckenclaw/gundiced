class_name DiceRoll
extends Control
## On-screen dice. Every roll in the game goes through roll(): each die is
## tinted in its player's colour, tumbles in from below, settles on its value
## with a pop, and stays until dismiss() flies it off to a target point.
##   await dice.roll([4], [p1_color], ["P1"])
##   await dice.dismiss([hud_ap_position])

const SFX_TICK := preload("res://assets/sfx/step.wav")
const SFX_LAND := preload("res://assets/sfx/ready-shot.wav")
const SPACING := 170.0
const TUMBLE_TIME := 0.85

var _dice: Array[Die] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func roll(values: Array, colors: Array, labels: Array = []) -> void:
	_clear()
	var center := size * 0.5 + Vector2(0, -20)
	var n := values.size()
	for i in n:
		var d := Die.new()
		d.color = colors[i]
		d.label = labels[i] if i < labels.size() else ""
		d.face = randi_range(1, 6)
		d.target = center + Vector2((i - (n - 1) * 0.5) * SPACING, 0)
		d.position = d.target + Vector2(randf_range(-120, 120), 420)
		d.rotation = randf_range(-PI, PI)
		d.modulate.a = 0.0
		add_child(d)
		_dice.append(d)
		var t := d.create_tween().set_parallel()
		t.tween_property(d, "position", d.target, TUMBLE_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		t.tween_property(d, "rotation", randf_range(-0.15, 0.15) + TAU * (2.0 if i % 2 == 0 else -2.0), TUMBLE_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		t.tween_property(d, "modulate:a", 1.0, 0.15)

	# Faces flicker fast, then slow down as the dice settle.
	var elapsed := 0.0
	var interval := 0.04
	while elapsed < TUMBLE_TIME - 0.08:
		await get_tree().create_timer(interval).timeout
		elapsed += interval
		interval *= 1.18
		for d in _dice:
			d.face = _other_face(d.face)
			d.queue_redraw()
		Sfx.play(SFX_TICK, randf_range(1.6, 2.0))

	for i in n:
		var d := _dice[i]
		d.face = values[i]
		d.settled = true
		d.queue_redraw()
		var t := d.create_tween()
		t.tween_property(d, "scale", Vector2(1.35, 1.35), 0.07)
		t.tween_property(d, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(d, "rotation", 0.0, 0.2)
		d.flash()
	Sfx.play(SFX_LAND, 1.2)
	await get_tree().create_timer(0.45).timeout


## Shrinks the dice into `targets` (screen positions); fades if none given.
func dismiss(targets: Array = []) -> void:
	if _dice.is_empty():
		return
	var last: Tween
	for i in _dice.size():
		var d := _dice[i]
		last = d.create_tween().set_parallel()
		if i < targets.size():
			last.tween_property(d, "position", targets[i], 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			last.tween_property(d, "scale", Vector2(0.25, 0.25), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			last.tween_property(d, "scale", Vector2(0.6, 0.6), 0.25)
		last.tween_property(d, "modulate:a", 0.0, 0.35)
	await last.finished
	_clear()


func _clear() -> void:
	for d in _dice:
		d.queue_free()
	_dice.clear()


func _other_face(f: int) -> int:
	var n := randi_range(1, 5)
	return n if n < f else n + 1


class Die extends Node2D:
	const SIZE := 96.0
	const PIPS := {
		1: [Vector2(0, 0)],
		2: [Vector2(-1, -1), Vector2(1, 1)],
		3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
		4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
		5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
		6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
	}
	var color := Color.WHITE
	var label := ""
	var face := 1
	var settled := false
	var target := Vector2.ZERO
	var _flash := 0.0

	func flash() -> void:
		_flash = 1.0
		var t := create_tween()
		t.tween_method(func(v: float) -> void:
			_flash = v
			queue_redraw(), 1.0, 0.0, 0.3)

	func _draw() -> void:
		var half := SIZE * 0.5
		var body := StyleBoxFlat.new()
		body.set_corner_radius_all(18)
		# Drop shadow
		body.bg_color = Color(0, 0, 0, 0.35)
		draw_style_box(body, Rect2(Vector2(-half + 6, -half + 10), Vector2(SIZE, SIZE)))
		# Side (darker) and face (player colour with a lighter top)
		body.bg_color = color.darkened(0.45)
		draw_style_box(body, Rect2(Vector2(-half, -half + 6), Vector2(SIZE, SIZE)))
		body.bg_color = color.lerp(Color.WHITE, _flash * 0.7)
		body.border_color = color.darkened(0.6)
		body.set_border_width_all(4)
		draw_style_box(body, Rect2(Vector2(-half, -half), Vector2(SIZE, SIZE)))
		var hl := StyleBoxFlat.new()
		hl.set_corner_radius_all(12)
		hl.bg_color = Color(1, 1, 1, 0.18)
		draw_style_box(hl, Rect2(Vector2(-half + 10, -half + 8), Vector2(SIZE - 20, SIZE * 0.32)))
		var pip_col := Color(0.1, 0.07, 0.06) if color.get_luminance() > 0.6 else Color(1, 0.97, 0.9)
		for p in PIPS[face]:
			draw_circle(p * SIZE * 0.26 + Vector2(1, 2), 9.0, Color(0, 0, 0, 0.25))
			draw_circle(p * SIZE * 0.26, 9.0, pip_col)
		if label != "" and settled:
			var font := ThemeDB.fallback_font
			draw_string_outline(font, Vector2(-half, half + 34), label, HORIZONTAL_ALIGNMENT_CENTER, SIZE, 24, 8, Color(0.08, 0.05, 0.04))
			draw_string(font, Vector2(-half, half + 34), label, HORIZONTAL_ALIGNMENT_CENTER, SIZE, 24, color.lightened(0.2))
