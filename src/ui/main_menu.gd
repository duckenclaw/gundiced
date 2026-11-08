extends Control
## Title screen: pick an arena, read the controls, start a hot-seat duel.

const MATCH_SCENE := "res://src/match/match.tscn"
const P1 := preload("res://assets/players/player1.png")
const P2 := preload("res://assets/players/player2.png")

var _t := 0.0
var _p1: TextureRect
var _p2: TextureRect


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.105, 0.078, 0.071)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var sand := TextureRect.new()
	sand.texture = preload("res://assets/tiles/floor_sand.png")
	sand.stretch_mode = TextureRect.STRETCH_TILE
	sand.set_anchors_preset(Control.PRESET_FULL_RECT)
	sand.modulate = Color(0.45, 0.35, 0.3)
	add_child(sand)

	_p1 = _portrait(P1)
	_p2 = _portrait(P2)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	Hud.place(col, Control.PRESET_CENTER, Vector2(-300, -330), Vector2(600, 660))

	var title := Hud._label(col, 96, Color(1, 0.82, 0.3))
	title.text = "GUNDICED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := Hud._label(col, 20, Hud.CREAM)
	sub.text = "Roll the D6. Spend the AP. Don't get shot."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_spacer(18))

	var first: Button
	for lvl in Match.LEVELS:
		var b := _button(col, lvl["name"])
		b.pressed.connect(_start.bind(lvl["path"]))
		if first == null:
			first = b
	var quit := _button(col, "Quit")
	quit.pressed.connect(get_tree().quit)
	col.add_child(_spacer(14))
	var help := Hud._label(col, 16, Color(Hud.CREAM, 0.8))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.text = "Hot-seat, one keyboard.\nWASD / arrows  move & push  ·  Space / Z  aim, then fire\nQ / X  turn your shield  ·  E  cancel aim  ·  Esc  menu"
	first.grab_focus()


func _process(delta: float) -> void:
	_t += delta
	var vs := get_viewport_rect().size
	_p1.position = Vector2(40, vs.y * 0.5 - 150 + sin(_t * 2.0) * 8.0)
	_p2.position = Vector2(vs.x - 320, vs.y * 0.5 - 150 + sin(_t * 2.0 + 1.5) * 8.0)


func _start(path: String) -> void:
	Match.level_path = path
	get_node("/root/SceneManager").change_scene(MATCH_SCENE)


func _portrait(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(r)
	r.size = Vector2(280, 300)
	return r


func _button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 24)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.14, 0.1)
	normal.border_color = Color(0.55, 0.36, 0.2)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.45, 0.27, 0.14)
	hover.border_color = Color(1, 0.82, 0.3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", Hud.CREAM)
	b.mouse_entered.connect(b.grab_focus)
	parent.add_child(b)
	return b


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
