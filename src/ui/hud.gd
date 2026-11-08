class_name Hud
extends CanvasLayer
## Match HUD, built in code: a panel per player (portrait, weapon + ammo, shield,
## AP pips), the turn banner, a context hint line and the game-over card.

const BG := Color(0.1, 0.07, 0.06, 0.82)
const INK := Color(0.08, 0.05, 0.04)
const CREAM := Color(1, 0.94, 0.82)
const GOLD := Color(1, 0.82, 0.25)
const RED := Color(1, 0.3, 0.25)

var _panels: Array[PlayerPanel] = []
var _banner: Label
var _banner_tween: Tween
var _hint: Label
var _level_label: Label
var _over: Control
var _over_title: Label


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_banner = _label(root, 56, CREAM)
	place(_banner, Control.PRESET_CENTER, Vector2(-450, -230), Vector2(900, 80))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0

	_hint = _label(root, 18, Color(CREAM, 0.85))
	place(_hint, Control.PRESET_CENTER_BOTTOM, Vector2(-550, -40), Vector2(1100, 30))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_level_label = _label(root, 18, Color(CREAM, 0.6))
	place(_level_label, Control.PRESET_CENTER_TOP, Vector2(-200, 16), Vector2(400, 30))
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_over = ColorRect.new()
	(_over as ColorRect).color = Color(0, 0, 0, 0.55)
	_over.visible = false
	root.add_child(_over)
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over_title = _label(_over, 72, CREAM)
	place(_over_title, Control.PRESET_CENTER, Vector2(-500, -90), Vector2(1000, 100))
	_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(_over, 24, Color(CREAM, 0.85))
	sub.text = "R  rematch      Esc  menu"
	place(sub, Control.PRESET_CENTER, Vector2(-500, 20), Vector2(1000, 40))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func setup(players: Array, level_name: String) -> void:
	_level_label.text = level_name.to_upper()
	var root := get_child(0)
	for i in players.size():
		var p: Player = players[i]
		var panel := PlayerPanel.new()
		panel.player = p
		panel.right_side = i % 2 == 1
		root.add_child(panel)
		_panels.append(panel)
		p.changed.connect(panel.refresh)
		p.died.connect(func(_pl: Player) -> void: panel.refresh())
		panel.refresh()


## Screen position of a player's AP row (where their die flies to).
func ap_anchor(i: int) -> Vector2:
	return _panels[i].ap_anchor() if i < _panels.size() else Vector2.ZERO


func set_ap(i: int, left: int, base: int, bonus: int, penalty: int) -> void:
	for j in _panels.size():
		_panels[j].set_ap(left, base, bonus, penalty, j == i)


## Highlights the AP the current action would spend (e.g. 1 while aiming).
func set_preview_cost(i: int, cost: int) -> void:
	if i < _panels.size():
		_panels[i].set_preview(cost)


func clear_ap() -> void:
	for p in _panels:
		p.set_ap(0, 0, 0, 0, false)


func banner(text: String, color := CREAM, hold := 1.0) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	if _banner_tween:
		_banner_tween.kill()
	_banner.scale = Vector2(0.85, 0.85)
	_banner.pivot_offset = _banner.size * 0.5
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.12)
	_banner_tween.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		_banner_tween.tween_interval(hold)
		_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.25)


func hint(text: String) -> void:
	_hint.text = text


func game_over(text: String, color: Color) -> void:
	_over_title.text = text
	_over_title.add_theme_color_override("font_color", color)
	_over.visible = true
	_over.modulate.a = 0.0
	create_tween().tween_property(_over, "modulate:a", 1.0, 0.4)
	_hint.text = ""


## Anchor `ctrl` to `preset` and give it an explicit rect relative to that anchor.
static func place(ctrl: Control, preset: int, offset: Vector2, rect_size: Vector2) -> void:
	ctrl.set_anchors_preset(preset)
	ctrl.offset_left = offset.x
	ctrl.offset_top = offset.y
	ctrl.offset_right = offset.x + rect_size.x
	ctrl.offset_bottom = offset.y + rect_size.y


static func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", maxi(6, size / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


class PlayerPanel extends Control:
	const W := 300.0
	const H := 92.0
	var player: Player
	var right_side := false
	var _ap_left := 0
	var _base := 0
	var _bonus := 0
	var _penalty := 0
	var _active := false
	var _preview := 0
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if right_side:
			Hud.place(self, Control.PRESET_TOP_RIGHT, Vector2(-W - 16, 12), Vector2(W, H))
		else:
			Hud.place(self, Control.PRESET_TOP_LEFT, Vector2(16, 12), Vector2(W, H))

	func refresh() -> void:
		queue_redraw()

	func set_preview(cost: int) -> void:
		if cost != _preview:
			_preview = cost
			queue_redraw()

	func _process(delta: float) -> void:
		if _preview > 0 and _active:
			_t += delta
			queue_redraw()

	func set_ap(left: int, base: int, bonus: int, penalty: int, active: bool) -> void:
		_ap_left = left
		_base = base
		_bonus = bonus
		_penalty = penalty
		_active = active
		queue_redraw()

	func ap_anchor() -> Vector2:
		return global_position + Vector2(W * 0.5, 72)

	func _draw() -> void:
		if player == null:
			return
		var font := ThemeDB.fallback_font
		var col := player.color
		var box := StyleBoxFlat.new()
		box.bg_color = Hud.BG
		box.set_corner_radius_all(12)
		box.border_color = col if _active else Color(col, 0.35)
		box.set_border_width_all(3 if _active else 2)
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		# Portrait
		var tex := player.texture
		var k := 72.0 / tex.get_height()
		var psize := tex.get_size() * k
		var px := W - psize.x - 10.0 if right_side else 10.0
		draw_texture_rect(tex, Rect2(Vector2(px, 10), psize), false, Color(1, 1, 1, 0.45) if player.is_dead() else Color.WHITE)
		var x0 := 12.0 if right_side else 92.0
		# Name
		var title := "PLAYER %d" % (player.index + 1)
		if player.is_dead():
			title += "  ✕"
		draw_string_outline(font, Vector2(x0, 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Hud.INK)
		draw_string(font, Vector2(x0, 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col.lightened(0.25))
		# Weapon + ammo + shield
		var wt := Weapons.texture(player.weapon)
		var wk := 34.0 / maxf(wt.get_width(), wt.get_height())
		var wsize := wt.get_size() * wk
		draw_texture_rect(wt, Rect2(Vector2(x0, 38 + (20 - wsize.y) * 0.5), wsize), false)
		var ammo := "∞" if player.ammo < 0 else "x%d" % player.ammo
		draw_string(font, Vector2(x0 + 40, 56), ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Hud.CREAM)
		if player.has_shield:
			var st: Texture2D = load(Weapons.SHIELD_TEX)
			var sk := 26.0 / st.get_height()
			draw_texture_rect(st, Rect2(Vector2(x0 + 84, 34), st.get_size() * sk), false)
		# AP pips: normal (player colour), bonus (gold), drained (red, stay all turn)
		if not _active:
			return
		var normal := maxi(_base - _penalty, 0)
		var active_total := normal + _bonus
		var total := active_total + _penalty
		for i in total:
			var c := Vector2(x0 + 8 + i * 22, 76)
			var n := i + 1
			if n <= _ap_left:
				var fill := col if n <= normal else Hud.GOLD
				draw_circle(c, 8, Hud.INK)
				if n > _ap_left - _preview:
					# The pip this action will spend: blinks between full and hollow.
					var blink := 0.5 + 0.5 * sin(_t * 10.0)
					draw_circle(c, 6.5, Color(fill.lightened(0.15), 0.25 + 0.5 * blink))
					draw_arc(c, 10.5, 0, TAU, 20, Hud.CREAM, 2.0)
				else:
					draw_circle(c, 6.5, fill.lightened(0.15))
			elif n > active_total:
				draw_circle(c, 8, Hud.INK)
				draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), Hud.RED, 3)
				draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), Hud.RED, 3)
			else:
				draw_arc(c, 6.5, 0, TAU, 16, Color(col, 0.4), 2)
