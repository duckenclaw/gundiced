class_name Player
extends Node2D
## A gunslinger on the grid. The match hands control over with
## set_controllable(); every successful action ends with `action_performed`,
## which is what spends AP. Failed actions never emit it, so they cost nothing.

signal action_performed
signal died(player: Player)
signal changed  ## weapon, ammo or shield changed (HUD refresh)

enum State { IDLE, BUSY, AIMING, SHIELD_AIM, DEAD }

const SFX_STEP := preload("res://assets/sfx/step.wav")
const SFX_READY := preload("res://assets/sfx/ready-shot.wav")
const SFX_SHOT := preload("res://assets/sfx/shot.wav")
const SFX_PICKUP := preload("res://assets/sfx/pickup.wav")
const BODY_PX := 80.0
const BODY_Y := -14.0
const MOVE_TIME := 0.13

@export var index := 0
@export var color := Color.WHITE
@export var texture: Texture2D
## True if the art faces left by default (player2 holds the gun on the left).
@export var art_faces_left := false

var board: Board
var cell: Vector2i
var state := State.IDLE
var controllable := false
var facing := Vector2i.RIGHT
var weapon: int = Weapons.Kind.REVOLVER
var ammo := -1
var has_shield := false
var shield_dir := Vector2i.RIGHT
var health: Health

var _aim_dir := Vector2i.RIGHT
var _throw_cell := Vector2i.ZERO
var _throw_dir := Vector2i.RIGHT
var _body: Sprite2D
var _weapon_sprite: Sprite2D
var _shield_sprite: Sprite2D
var _ring: Sprite2D
var _anim: Tween
var _tilt := 1.0


func _ready() -> void:
	add_to_group("player")
	add_to_group("occupant")
	var shadow := Sprite2D.new()
	shadow.texture = Fx.soft_circle()
	shadow.modulate = Color(0, 0, 0, 0.45)
	shadow.scale = Vector2(0.75, 0.3)
	shadow.position = Vector2(0, 24)
	add_child(shadow)
	_ring = Sprite2D.new()
	_ring.texture = Fx.soft_circle()
	_ring.modulate = Color(color, 0.0)
	_ring.scale = Vector2(1.1, 0.5)
	_ring.position = Vector2(0, 22)
	add_child(_ring)
	_shield_sprite = Sprite2D.new()
	_shield_sprite.texture = load(Weapons.SHIELD_TEX)
	_shield_sprite.visible = false
	add_child(_shield_sprite)
	_body = Sprite2D.new()
	_body.texture = texture
	var k := BODY_PX / texture.get_height()
	_body.scale = Vector2(k, k)
	_body.position = Vector2(0, BODY_Y)
	add_child(_body)
	_weapon_sprite = Sprite2D.new()
	_weapon_sprite.z_index = 1
	add_child(_weapon_sprite)
	health = Health.new()
	health.max_health = 1.0
	health.current_health = 1.0
	add_child(health)
	health.died.connect(_die)
	_refresh_visuals()


func place(c: Vector2i, face: Vector2i) -> void:
	cell = c
	position = Grid.to_world(c)
	facing = face
	shield_dir = face
	_refresh_visuals()


func is_dead() -> bool:
	return state == State.DEAD


func set_controllable(v: bool) -> void:
	controllable = v
	if not v and (state == State.AIMING or state == State.SHIELD_AIM):
		_exit_aim()
	var t := create_tween()
	t.tween_property(_ring, "modulate:a", 0.55 if v else 0.0, 0.2)


# --- Input ---------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not controllable or Engine.is_editor_hint():
		return
	match state:
		State.IDLE: _idle_input()
		State.AIMING: _aim_input()
		State.SHIELD_AIM: _shield_input()


func _pressed_dir() -> Vector2i:
	if Input.is_action_just_pressed("move_right"): return Vector2i.RIGHT
	if Input.is_action_just_pressed("move_left"): return Vector2i.LEFT
	if Input.is_action_just_pressed("move_up"): return Vector2i.UP
	if Input.is_action_just_pressed("move_down"): return Vector2i.DOWN
	return Vector2i.ZERO


func _idle_input() -> void:
	if Input.is_action_just_pressed("shoot"):
		enter_aim()
		return
	if Input.is_action_just_pressed("shield"):
		enter_shield_aim()
		return
	var d := _pressed_dir()
	if d != Vector2i.ZERO:
		try_move(d)


func _aim_input() -> void:
	if Input.is_action_just_pressed("shoot"):
		fire()
		return
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("shield"):
		_exit_aim()
		return
	var d := _pressed_dir()
	if d != Vector2i.ZERO:
		aim(d)


func _shield_input() -> void:
	if Input.is_action_just_pressed("shield") or Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("shoot"):
		_exit_aim()
		return
	var d := _pressed_dir()
	if d != Vector2i.ZERO:
		shield_dir = d
		Sfx.play(SFX_STEP, 1.6)
		_refresh_visuals()
		board.overlay.show_shield(position, shield_dir, color)


# --- Movement ------------------------------------------------------------------

## Returns true if the move happened (and AP was spent).
func try_move(dir: Vector2i) -> bool:
	var to := cell + dir
	var door := board.door_between(cell, to)
	var o := board.occupant_at(to)
	var ok := board.is_floor(to)
	if ok and door and not door.can_pass(cell, to):
		ok = false
	if ok and o is Crate:
		ok = board.can_push(o, dir)
	elif ok and o != null:
		ok = false
	if not ok:
		_bump(dir)
		return false

	if door:
		door.pass_through(cell, to)
	if o is Crate:
		board.push(o, dir)
	_face(dir)
	cell = to
	state = State.BUSY
	Sfx.play(SFX_STEP, randf_range(0.9, 1.1))
	_tilt = -_tilt
	if _anim:
		_anim.kill()
	_anim = create_tween()
	_anim.tween_property(self, "position", Grid.to_world(to), MOVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim.parallel().tween_property(_body, "position:y", BODY_Y - 10.0, MOVE_TIME * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim.parallel().tween_property(_body, "rotation_degrees", 10.0 * _tilt, MOVE_TIME * 0.5)
	_anim.chain().tween_property(_body, "position:y", BODY_Y, MOVE_TIME * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_anim.parallel().tween_property(_body, "rotation_degrees", 0.0, MOVE_TIME * 0.5)
	await _anim.finished

	var p := board.pickup_at(cell)
	if p:
		_collect(p)
	if board.is_deadly(cell):
		Fx.popup(board, position, "BURNED", Color(1, 0.5, 0.2))
		kill()
	if state != State.DEAD:
		state = State.IDLE
	action_performed.emit()
	return true


func _bump(dir: Vector2i) -> void:
	if state != State.IDLE:
		return
	if _anim:
		_anim.kill()
	_anim = create_tween()
	_anim.tween_property(_body, "position", Vector2(dir) * 6.0 + Vector2(0, BODY_Y), 0.05)
	_anim.tween_property(_body, "position", Vector2(0, BODY_Y), 0.08)
	Sfx.play(SFX_STEP, 0.6)


func _face(dir: Vector2i) -> void:
	facing = dir
	_refresh_visuals()


func _collect(p: Pickup) -> void:
	if p.kind == Pickup.SHIELD:
		if has_shield:
			return
		has_shield = true
		shield_dir = facing
	else:
		weapon = p.kind
		ammo = Weapons.ammo(p.kind)
	Fx.popup(board, position, "+" + p.label(), Color(1, 0.9, 0.4))
	Sfx.play(SFX_PICKUP)
	p.collect()
	_refresh_visuals()
	changed.emit()


# --- Aiming & firing -----------------------------------------------------------

func enter_aim() -> void:
	state = State.AIMING
	Sfx.play(SFX_READY)
	if Weapons.is_thrown(weapon):
		_throw_dir = facing
		var first := cell + facing
		_throw_cell = first if _throwable(first) else cell
		_aim_dir = facing
		_refresh_visuals()
		_update_preview()
		return
	aim(facing)


func aim(dir: Vector2i) -> void:
	if Weapons.is_thrown(weapon):
		var cand := _throw_cell + dir if dir == _throw_dir and _throw_cell != cell else cell + dir
		if _throwable(cand):
			_throw_dir = dir
			_throw_cell = cand
		_aim_dir = dir
	else:
		_aim_dir = dir
	if dir.x != 0:
		_face(dir)
	else:
		facing = dir
	_refresh_visuals()
	_update_preview()


func _throwable(c: Vector2i) -> bool:
	if not board.is_floor(c) or board.occupant_at(c) is Crate or board.occupant_at(c) is Obstacle:
		return false
	# The arc can't pass a closed door on the way.
	var step := cell
	while step != c:
		var nxt := step + Grid.dir_towards(step, c)
		var d := board.door_between(step, nxt)
		if d and not d.is_open():
			return false
		step = nxt
	return true


func _update_preview() -> void:
	var origin := _muzzle()
	if Weapons.is_thrown(weapon):
		var aoe := Grid.cross(_throw_cell)
		board.overlay.show_aim(origin, Grid.to_world(_throw_cell), [_throw_cell] as Array[Vector2i], aoe, color)
		return
	var res := board.trace(cell, _aim_dir, weapon == Weapons.Kind.SNIPER)
	var to := board.impact_point(cell, _aim_dir, res)
	var targets: Array[Vector2i] = []
	var aoe: Array[Vector2i] = []
	if weapon == Weapons.Kind.RPG:
		aoe = Grid.cross(res["blast"])
	elif weapon == Weapons.Kind.SNIPER:
		for h in res["hits"]:
			targets.append(_cell_of(h))
	elif res["stop"] != null:
		targets.append(_cell_of(res["stop"]))
	board.overlay.show_aim(origin, to, targets, aoe, color)


func _cell_of(n: Node) -> Vector2i:
	if n is Door:
		# Highlight the door's cell on the far side of the shooter.
		return n.cell_a if n.cell_b == cell or (n.cell_b - cell).length_squared() < (n.cell_a - cell).length_squared() else n.cell_b
	return n.cell


func _muzzle() -> Vector2:
	return position + Vector2(0, BODY_Y)


func _exit_aim() -> void:
	if state == State.AIMING or state == State.SHIELD_AIM:
		state = State.IDLE
	board.overlay.clear()
	_refresh_visuals()


func fire() -> void:
	state = State.BUSY
	board.overlay.clear()
	var origin := _muzzle()
	var dir := _aim_dir
	var fdir := Vector2(dir)
	Sfx.play(SFX_SHOT, 1.0 if weapon == Weapons.Kind.REVOLVER else (0.7 if weapon == Weapons.Kind.SNIPER else 0.85))
	Fx.muzzle(board, origin + fdir * 30.0, fdir)
	_recoil(fdir)
	match weapon:
		Weapons.Kind.REVOLVER:
			var res := board.trace(cell, dir)
			Fx.shake(self, 4.0)
			await Fx.projectile(board, Fx.BULLET, origin, board.impact_point(cell, dir, res))
			var stop: Node = res["stop"]
			if stop and is_instance_valid(stop) and stop.has_method("take_hit"):
				stop.take_hit(dir)
		Weapons.Kind.SNIPER:
			var res := board.trace(cell, dir, true)
			Fx.shake(self, 7.0)
			await Fx.projectile(board, Fx.BULLET, origin, board.impact_point(cell, dir, res), 30.0, 3600.0)
			for h in res["hits"]:
				if is_instance_valid(h) and h.has_method("take_hit"):
					h.take_hit(dir)
		Weapons.Kind.RPG:
			var res := board.trace(cell, dir)
			var blast: Vector2i = res["blast"]
			await Fx.projectile(board, Fx.ROCKET, origin, Grid.to_world(blast), 40.0, 1400.0)
			board.explode(blast, dir)
		Weapons.Kind.MOLOTOV, Weapons.Kind.GRENADE:
			var kind := weapon
			await Fx.lob(board, Weapons.texture(kind), origin, Grid.to_world(_throw_cell))
			_spawn_hazard(kind)

	if ammo > 0:
		ammo -= 1
		if ammo == 0:
			Fx.popup(board, position, "Out of ammo", Color(0.85, 0.85, 0.85))
			weapon = Weapons.Kind.REVOLVER
			ammo = -1
	changed.emit()
	if state == State.DEAD:
		return
	state = State.IDLE
	_refresh_visuals()
	action_performed.emit()


func _spawn_hazard(kind: int) -> void:
	var h := Hazard.new()
	h.board = board
	h.thrower = self
	h.cells = Grid.cross(_throw_cell)
	h.type = Hazard.Type.FIRE if kind == Weapons.Kind.MOLOTOV else Hazard.Type.GRENADE
	board.ground.add_child(h)
	if h.type == Hazard.Type.FIRE:
		Fx.shake(self, 6.0)
		for p in get_tree().get_nodes_in_group("player"):
			if not p.is_dead() and p.cell in h.cells:
				Fx.popup(board, p.position, "BURNED", Color(1, 0.5, 0.2))
				p.kill()


func _recoil(fdir: Vector2) -> void:
	var t := create_tween()
	t.tween_property(_body, "position", Vector2(0, BODY_Y) - fdir * 6.0, 0.04)
	t.tween_property(_body, "position", Vector2(0, BODY_Y), 0.12)


# --- Shield --------------------------------------------------------------------

func enter_shield_aim() -> void:
	if not has_shield:
		Fx.popup(board, position, "No shield", Color(0.8, 0.8, 0.8))
		return
	state = State.SHIELD_AIM
	Sfx.play(SFX_READY, 1.3)
	board.overlay.show_shield(position, shield_dir, color)


# --- Damage --------------------------------------------------------------------

## `dir` is the direction the damage travels. A shield facing into it absorbs
## the hit once. ZERO (fire, a grenade on your own cell) can't be blocked.
func take_hit(dir: Vector2i) -> void:
	if is_dead():
		return
	if has_shield and dir != Vector2i.ZERO and shield_dir == -dir:
		has_shield = false
		Fx.popup(board, position, "BLOCKED!", Color(0.7, 0.9, 1.0))
		Fx.debris(board, position + Vector2(shield_dir) * 24.0, Color(0.6, 0.65, 0.75))
		_refresh_visuals()
		changed.emit()
		return
	health.take_damage(1.0, null)


func kill() -> void:
	if not is_dead():
		health.take_damage(health.current_health, null)


func _die() -> void:
	state = State.DEAD
	controllable = false
	remove_from_group("occupant")
	board.overlay.clear()
	Fx.flash(_body)
	Fx.shake(self, 16.0)
	Fx.debris(board, position, color)
	_weapon_sprite.visible = false
	_shield_sprite.visible = false
	var t := create_tween().set_parallel()
	t.tween_property(_body, "rotation_degrees", 90.0 * (1.0 if facing.x >= 0 else -1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_body, "modulate", Color(0.4, 0.4, 0.4, 0.7), 0.6)
	t.tween_property(_ring, "modulate:a", 0.0, 0.2)
	died.emit(self)


# --- Visuals -------------------------------------------------------------------

func _refresh_visuals() -> void:
	if _body == null:
		return
	if facing.x != 0:
		_body.flip_h = (facing.x < 0) != art_faces_left
	# Held weapon: orbits in the aim direction while aiming, otherwise a small
	# badge over the head for anything better than the revolver.
	var tex := Weapons.texture(weapon)
	_weapon_sprite.texture = tex
	var longest := maxf(tex.get_width(), tex.get_height())
	if state == State.AIMING:
		var k := 46.0 / longest
		_weapon_sprite.visible = true
		_weapon_sprite.scale = Vector2(k, k)
		_weapon_sprite.position = Vector2(0, BODY_Y) + Vector2(_aim_dir) * 40.0
		_weapon_sprite.rotation = Vector2(_aim_dir).angle()
		_weapon_sprite.flip_v = _aim_dir.x < 0
		_weapon_sprite.z_index = 1 if _aim_dir != Vector2i.UP else -1
	else:
		var k := 30.0 / longest
		_weapon_sprite.visible = weapon != Weapons.Kind.REVOLVER
		_weapon_sprite.scale = Vector2(k, k)
		_weapon_sprite.position = Vector2(0, BODY_Y - BODY_PX * 0.5 - 14.0)
		_weapon_sprite.rotation = 0.0
		_weapon_sprite.flip_v = false
		_weapon_sprite.z_index = 1
	_shield_sprite.visible = has_shield and not is_dead()
	if has_shield:
		var st: Texture2D = _shield_sprite.texture
		var sk := 44.0 / st.get_height()
		_shield_sprite.scale = Vector2(sk, sk)
		var d := Vector2(shield_dir)
		_shield_sprite.position = Vector2(0, BODY_Y + 6.0) + d * 28.0
		_shield_sprite.rotation = 0.0 if shield_dir.x != 0 else PI * 0.5
		_shield_sprite.flip_h = shield_dir.x < 0
		_shield_sprite.z_index = -1 if shield_dir == Vector2i.UP else 1
