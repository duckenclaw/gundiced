class_name TurnGhost
extends Node2D
## Replays what the previous player did on their turn: footprints along their
## path and the lines of their shots, in their colour. Shown while the next
## player rolls, faded out once that player acts.

var _path: Array = []   ## Array of [from: Vector2i, to: Vector2i]
var _shots: Array = []  ## Array of [from: Vector2, to: Vector2]
var _color := Color.WHITE
var _reveal := 0.0
var _tween: Tween


func _ready() -> void:
	z_index = 2
	modulate.a = 0.0


func show_turn(path: Array, shots: Array, color: Color) -> void:
	_path = path.duplicate()
	_shots = shots.duplicate()
	_color = color
	if _path.is_empty() and _shots.is_empty():
		return
	if _tween:
		_tween.kill()
	modulate.a = 1.0
	_reveal = 0.0
	# Draw the path step by step so the order of events reads.
	_tween = create_tween()
	_tween.tween_method(_set_reveal, 0.0, 1.0, clampf(0.15 * (_path.size() + _shots.size()), 0.4, 1.4))


func fade() -> void:
	if modulate.a <= 0.0:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)


func _set_reveal(v: float) -> void:
	_reveal = v
	queue_redraw()


func _draw() -> void:
	var total := _path.size() + _shots.size()
	if total == 0:
		return
	var shown := int(ceil(_reveal * total))
	var col := Color(_color.lightened(0.15), 0.95)
	var ink := Color(0.08, 0.05, 0.04, 0.6)
	var i := 0
	for step in _path:
		if i >= shown:
			return
		var a := Grid.to_world(step[0])
		var b := Grid.to_world(step[1])
		var d := (b - a).normalized()
		var mid := a.lerp(b, 0.5)
		var perp := Vector2(-d.y, d.x)
		draw_circle(a + Vector2(0, 10), 9.0, ink)
		draw_circle(a + Vector2(0, 10), 7.0, col)
		# Chevron on the cell edge pointing the way.
		var chev := PackedVector2Array([mid - d * 9 + perp * 12, mid + d * 9, mid - d * 9 - perp * 12])
		draw_polyline(chev, ink, 8.0)
		draw_polyline(chev, col, 5.0)
		i += 1
	for s in _shots:
		if i >= shown:
			return
		draw_line(s[0], s[1], Color(0, 0, 0, 0.4), 6.0)
		draw_line(s[0], s[1], Color(_color.lightened(0.3), 0.85), 3.0)
		draw_circle(s[1], 7.0, Color(1, 0.9, 0.6, 0.9))
		i += 1
