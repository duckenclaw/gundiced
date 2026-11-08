class_name Fx
## Fire-and-forget juice: projectiles, flashes, particles, popups, screen shake.
## Everything here is cosmetic; damage is applied by the caller.

const BULLET := preload("res://assets/fx/bullet.png")
const ROCKET := preload("res://assets/fx/rocket.png")

static var _circle: Texture2D


static func soft_circle() -> Texture2D:
	if _circle == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_circle = t
	return _circle


static func shake(node: Node, amount: float) -> void:
	var cam := node.get_tree().get_first_node_in_group("game_camera")
	if cam and cam.has_method("shake"):
		cam.shake(amount)


## Straight shot; await the returned signal to know when it lands.
static func projectile(parent: Node, tex: Texture2D, from: Vector2, to: Vector2, px := 26.0, speed := 2200.0) -> Signal:
	var p := Sprite2D.new()
	p.texture = tex
	var k := px / maxf(tex.get_width(), tex.get_height())
	p.scale = Vector2(k, k)
	p.position = from
	p.rotation = (to - from).angle()
	p.z_index = 5
	parent.add_child(p)
	var trail := Line2D.new()
	trail.width = 3.0
	trail.default_color = Color(1, 0.95, 0.7, 0.6)
	trail.z_index = 4
	trail.add_point(from)
	trail.add_point(from)
	parent.add_child(trail)
	var dur := maxf(from.distance_to(to) / speed, 0.06)
	var t := p.create_tween()
	t.tween_method(func(v: Vector2) -> void:
		p.position = v
		trail.set_point_position(1, v), from, to, dur)
	t.tween_callback(p.queue_free)
	var tt := trail.create_tween()
	tt.tween_interval(dur)
	tt.tween_property(trail, "modulate:a", 0.0, 0.15)
	tt.tween_callback(trail.queue_free)
	return t.finished


## Lobbed throw: spins and grows/shrinks to fake an arc.
static func lob(parent: Node, tex: Texture2D, from: Vector2, to: Vector2) -> Signal:
	var p := Sprite2D.new()
	p.texture = tex
	var k := 34.0 / maxf(tex.get_width(), tex.get_height())
	p.scale = Vector2(k, k)
	p.position = from
	p.z_index = 5
	parent.add_child(p)
	var dur := clampf(from.distance_to(to) / 900.0, 0.25, 0.6)
	var t := p.create_tween()
	t.tween_property(p, "position", to, dur)
	t.parallel().tween_property(p, "rotation", TAU * 1.5, dur)
	t.parallel().tween_property(p, "scale", Vector2(k, k) * 1.7, dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(p, "scale", Vector2(k, k), dur * 0.5).set_delay(dur * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(p.queue_free)
	return t.finished


static func flash(item: CanvasItem) -> void:
	if item == null:
		return
	var t := item.create_tween()
	item.modulate = Color(3, 3, 3)
	t.tween_property(item, "modulate", Color.WHITE, 0.15)


static func muzzle(parent: Node, pos: Vector2, dir: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = soft_circle()
	s.modulate = Color(1, 0.85, 0.4)
	s.position = pos + dir * 10.0
	s.scale = Vector2(0.7, 0.45)
	s.rotation = dir.angle()
	s.z_index = 6
	parent.add_child(s)
	var t := s.create_tween()
	t.tween_property(s, "scale", Vector2(0.1, 0.1), 0.1)
	t.tween_callback(s.queue_free)


static func _burst(parent: Node, pos: Vector2, color: Color, amount: int, speed: float, life: float, size: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 6
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 600)
	p.damping_min = 80.0
	p.damping_max = 160.0
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func debris(parent: Node, pos: Vector2, color: Color) -> void:
	_burst(parent, pos, color, 18, 320.0, 0.6, 7.0)
	shake(parent, 6.0)


static func sparks(parent: Node, pos: Vector2, color: Color) -> void:
	_burst(parent, pos, color, 8, 260.0, 0.3, 3.0)


static func explosion(parent: Node, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = soft_circle()
	s.modulate = Color(1, 0.6, 0.2, 0.9)
	s.position = pos
	s.scale = Vector2(0.3, 0.3)
	s.z_index = 6
	parent.add_child(s)
	var t := s.create_tween().set_parallel()
	t.tween_property(s, "scale", Vector2(1.6, 1.6), 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(s.queue_free)
	_burst(parent, pos, Color(1, 0.75, 0.3), 14, 380.0, 0.45, 5.0)


static func fire(parent: Node, pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos + Vector2(0, 16)
	p.amount = 16
	p.lifetime = 0.7
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(24, 6)
	p.direction = Vector2.UP
	p.spread = 15.0
	p.gravity = Vector2(0, -120)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 50.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.9, 0.3, 1))
	ramp.add_point(0.5, Color(1, 0.4, 0.1, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.3, 0.1, 0.05, 0))
	p.color_ramp = ramp
	parent.add_child(p)


static func popup(parent: Node, pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.04))
	l.add_theme_constant_override("outline_size", 8)
	l.z_index = 20
	l.position = pos + Vector2(-60, -90)
	l.size = Vector2(120, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", l.position.y - 36.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	t.tween_callback(l.queue_free)
