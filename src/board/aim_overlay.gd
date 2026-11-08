class_name AimOverlay
extends Node2D
## Aim preview: a dashed line to the impact point, the struck cell, and the
## area of effect for explosives. Owned by Board, driven by Player.

var board: Node
var color := Color.WHITE
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _line := false
var _target_cells: Array[Vector2i] = []
var _aoe: Array[Vector2i] = []
var _shield_dir := Vector2i.ZERO
var _shield_at := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	z_index = 10


func show_aim(from: Vector2, to: Vector2, target_cells: Array[Vector2i], aoe: Array[Vector2i], c: Color) -> void:
	_line = from != to
	_from = from
	_to = to
	_target_cells = target_cells
	_aoe = aoe
	_shield_dir = Vector2i.ZERO
	color = c
	queue_redraw()


func show_shield(at: Vector2, dir: Vector2i, c: Color) -> void:
	clear()
	_shield_at = at
	_shield_dir = dir
	color = c
	queue_redraw()


func clear() -> void:
	_line = false
	_target_cells = []
	_aoe = []
	_shield_dir = Vector2i.ZERO
	queue_redraw()


func _process(delta: float) -> void:
	if _line or not _aoe.is_empty() or _shield_dir != Vector2i.ZERO:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var half := Vector2(Grid.CELL, Grid.CELL) * 0.5
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	for c in _aoe:
		if board.is_floor(c):
			draw_rect(Rect2(Grid.to_world(c) - half, half * 2.0), Color(1, 0.3, 0.15, 0.22 + 0.12 * pulse))
	for c in _target_cells:
		var r := Rect2(Grid.to_world(c) - half, half * 2.0).grow(-4)
		draw_rect(r, Color(color, 0.55 + 0.4 * pulse), false, 4.0)
	if _line:
		var dir := (_to - _from).normalized()
		var length := _from.distance_to(_to)
		var dash := 14.0
		var offset := fmod(_t * 60.0, dash * 2.0)
		var s := -dash * 2.0 + offset
		while s < length:
			var a := maxf(s, 0.0)
			var b := minf(s + dash, length)
			if b > a:
				draw_line(_from + dir * a, _from + dir * b, Color(0, 0, 0, 0.4), 6.0)
				draw_line(_from + dir * a, _from + dir * b, color, 3.0)
			s += dash * 2.0
		draw_circle(_to, 6.0 + 2.0 * pulse, color)
	if _shield_dir != Vector2i.ZERO:
		var d := Vector2(_shield_dir)
		var center := _shield_at + d * Grid.CELL * 0.5
		var perp := Vector2(-d.y, d.x)
		draw_line(center - perp * 26, center + perp * 26, Color(color, 0.5 + 0.5 * pulse), 6.0)
