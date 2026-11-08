class_name Match
extends Node2D
## Runs a duel: loads a level, spawns players, and owns the turn loop
##   contested roll -> [hazards -> roll D6 -> banner -> active turn] -> next player
## AP lives here; players only report `action_performed`, so any new action
## type plugs into the loop by emitting it.

enum Phase { ROLLING, ACTIVE, OVER }

const LEVELS := [
	{"name": "Saloon", "path": "res://src/levels/saloon.tscn"},
	{"name": "Main Street", "path": "res://src/levels/main_street.tscn"},
	{"name": "Corral", "path": "res://src/levels/corral.tscn"},
]
const PLAYERS := [
	{"tex": "res://assets/players/player1.png", "color": Color(0.93, 0.55, 0.2), "faces_left": false, "hand": Vector2(0.92, 0.6)},
	{"tex": "res://assets/players/player2.png", "color": Color(0.22, 0.72, 0.8), "faces_left": true, "hand": Vector2(0.09, 0.6)},
]
const BONUS_AP := 2
const DRAIN_AP := 1
const HUD_TOP := 110.0
const HUD_BOTTOM := 50.0

## Set by the main menu before switching to this scene.
static var level_path := "res://src/levels/saloon.tscn"

var board: Board
var players: Array[Player] = []
var current := 0
var phase := Phase.ROLLING
var ap := 0
var _pending_bonus: Array[int] = []
var _pending_penalty: Array[int] = []
var _turn_base := 0
var _turn_bonus := 0
var _turn_penalty := 0
var _camera: ShakeCamera
var hud: Hud
var dice: DiceRoll
var _log_path: Array = []
var _log_shots: Array = []
var _last_color := Color.WHITE


func _ready() -> void:
	randomize()
	board = (load(level_path) as PackedScene).instantiate()
	add_child(board)

	for i in PLAYERS.size():
		var def: Dictionary = PLAYERS[i]
		var p := Player.new()
		p.index = i
		p.color = def["color"]
		p.texture = load(def["tex"])
		p.art_faces_left = def["faces_left"]
		p.hand_uv = def["hand"]
		p.board = board
		board.props.add_child(p)
		var spawn: Vector2i = board.spawns[i] if i < board.spawns.size() else board.spawns[0]
		var other: Vector2i = board.spawns[(i + 1) % board.spawns.size()]
		p.place(spawn, Vector2i(signi(other.x - spawn.x) if other.x != spawn.x else 1, 0))
		p.action_performed.connect(_on_action)
		p.died.connect(_on_died)
		p.changed.connect(_update_hint)
		p.end_turn_requested.connect(_on_end_turn_requested.bind(p))
		p.moved.connect(func(a: Vector2i, b: Vector2i) -> void: _log_path.append([a, b]))
		p.shot.connect(func(a: Vector2, b: Vector2) -> void: _log_shots.append([a, b]))
		players.append(p)
		_pending_bonus.append(0)
		_pending_penalty.append(0)

	_camera = ShakeCamera.new()
	add_child(_camera)
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)

	hud = Hud.new()
	add_child(hud)
	hud.setup(players, board.level_name)
	var dice_layer := CanvasLayer.new()
	dice_layer.layer = 10
	add_child(dice_layer)
	dice = DiceRoll.new()
	dice_layer.add_child(dice)

	_initial_roll.call_deferred()


func _fit_camera() -> void:
	var rect := board.used_rect()
	var view := get_viewport().get_visible_rect().size
	var avail := Vector2(view.x - 40.0, view.y - HUD_TOP - HUD_BOTTOM)
	var z := minf(avail.x / rect.size.x, avail.y / rect.size.y)
	_camera.zoom = Vector2(z, z)
	# Shift so the board sits centred in the space between the HUD bars.
	_camera.position = rect.get_center() + Vector2(0, (HUD_BOTTOM - HUD_TOP) * 0.5 / z)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		get_node("/root/SceneManager").change_scene("res://src/ui/main_menu.tscn")
	elif event.is_action_pressed("rematch") and phase == Phase.OVER:
		get_node("/root/SceneManager").reload_current_scene()


# --- Turn loop -------------------------------------------------------------------

func _initial_roll() -> void:
	phase = Phase.ROLLING
	hud.hint("Contested roll: highest shoots first")
	var colors := players.map(func(p: Player) -> Color: return p.color)
	var labels := players.map(func(p: Player) -> String: return "P%d" % (p.index + 1))
	while true:
		var rolls := []
		for p in players:
			rolls.append(randi_range(1, 6))
		await dice.roll(rolls, colors, labels)
		var best: int = rolls.max()
		if rolls.count(best) == 1:
			current = rolls.find(best)
			break
		hud.banner("TIE! ROLL AGAIN", Hud.CREAM, 0.6)
		await get_tree().create_timer(0.9).timeout
	hud.banner("PLAYER %d SHOOTS FIRST" % (current + 1), players[current].color, 0.9)
	await get_tree().create_timer(0.7).timeout
	await dice.dismiss()
	_start_turn()


func _start_turn() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.ROLLING
	var p := players[current]
	hud.clear_ap()
	hud.hint("")
	if not _log_path.is_empty() or not _log_shots.is_empty():
		board.ghost.show_turn(_log_path, _log_shots, _last_color)
	_log_path.clear()
	_log_shots.clear()

	# Grenades thrown last turn go off now, fire burns out.
	var exploded := false
	for h in get_tree().get_nodes_in_group("hazard"):
		if h.thrower == p and h.type == Hazard.Type.GRENADE:
			exploded = true
		h.on_turn_started(p)
	if exploded:
		await get_tree().create_timer(0.8).timeout
	if phase == Phase.OVER:
		return

	_turn_base = randi_range(1, 6)
	_turn_bonus = _pending_bonus[current]
	_turn_penalty = _pending_penalty[current]
	_pending_bonus[current] = 0
	_pending_penalty[current] = 0
	ap = maxi(_turn_base + _turn_bonus - _turn_penalty, 0)

	await dice.roll([_turn_base], [p.color], ["P%d" % (current + 1)])
	var text := "PLAYER %d TURN" % (current + 1)
	if _turn_bonus > 0 or _turn_penalty > 0:
		text += "   %d AP" % ap
	hud.banner(text, p.color, 0.8)
	Sfx.named("turn", 1.0, 0.0)
	await get_tree().create_timer(0.35).timeout
	await dice.dismiss([hud.ap_anchor(current)])
	hud.set_ap(current, ap, _turn_base, _turn_bonus, _turn_penalty)
	if phase == Phase.OVER:
		return
	if ap <= 0:
		hud.banner("NO AP — SKIPPED", Hud.RED, 0.8)
		await get_tree().create_timer(1.0).timeout
		_end_turn()
		return
	phase = Phase.ACTIVE
	p.set_controllable(true)
	_update_hint()


func _on_action() -> void:
	if phase != Phase.ACTIVE:
		return
	board.ghost.fade()
	ap -= 1
	hud.set_ap(current, ap, _turn_base, _turn_bonus, _turn_penalty)
	_update_hint()
	if ap <= 0:
		players[current].set_controllable(false)
		phase = Phase.ROLLING
		await get_tree().create_timer(0.35).timeout
		_end_turn()


func _on_end_turn_requested(p: Player) -> void:
	if phase != Phase.ACTIVE or p != players[current]:
		return
	phase = Phase.ROLLING
	p.set_controllable(false)
	board.ghost.fade()
	Fx.popup(board, p.position, "Pass (%d AP left)" % ap, Hud.CREAM)
	await get_tree().create_timer(0.35).timeout
	_end_turn()


func _end_turn() -> void:
	if phase == Phase.OVER:
		return
	players[current].set_controllable(false)
	_last_color = players[current].color
	_apply_special_cell()
	var n := players.size()
	for i in n:
		current = (current + 1) % n
		if not players[current].is_dead():
			break
	_start_turn()


func _apply_special_cell() -> void:
	var p := players[current]
	if p.is_dead():
		return
	var s := board.special_at(p.cell)
	if s == null:
		return
	if s.effect == SpecialCell.Effect.AP_BONUS:
		_pending_bonus[current] += BONUS_AP
		Fx.popup(board, p.position, "+%d AP next turn" % BONUS_AP, Hud.GOLD)
	else:
		var next := _next_alive(current)
		_pending_penalty[next] += DRAIN_AP
		Fx.popup(board, p.position, "P%d -%d AP" % [next + 1, DRAIN_AP], Hud.RED)


func _next_alive(from: int) -> int:
	var i := from
	for k in players.size():
		i = (i + 1) % players.size()
		if not players[i].is_dead():
			return i
	return from


func _on_died(_p: Player) -> void:
	var alive := players.filter(func(pl: Player) -> bool: return not pl.is_dead())
	if alive.size() > 1:
		return
	phase = Phase.OVER
	for pl in players:
		pl.set_controllable(false)
	await get_tree().create_timer(0.9).timeout
	if alive.is_empty():
		hud.game_over("DRAW!", Hud.CREAM)
	else:
		var w: Player = alive[0]
		hud.game_over("PLAYER %d WINS" % (w.index + 1), w.color)


func _update_hint() -> void:
	if phase != Phase.ACTIVE:
		return
	var p := players[current]
	hud.set_preview_cost(current, 1 if p.state == Player.State.AIMING else 0)
	match p.state:
		Player.State.AIMING:
			hud.hint("AIMING %s  ·  arrows: direction  ·  Space: fire (1 AP)  ·  E: cancel" % Weapons.display_name(p.weapon).to_upper())
		Player.State.SHIELD_AIM:
			hud.hint("SHIELD  ·  arrows: face it  ·  Q / Space: done  (free)")
		_:
			var s := "WASD: move / push (1 AP)  ·  Space: aim %s" % Weapons.display_name(p.weapon)
			if p.has_shield:
				s += "  ·  Q: turn shield"
			s += "  ·  Enter: end turn"
			hud.hint(s)


func _process(_delta: float) -> void:
	# Cheap way to keep the hint in sync with aim/shield mode changes.
	if phase == Phase.ACTIVE and Engine.get_process_frames() % 6 == 0:
		_update_hint()


class ShakeCamera extends Camera2D:
	var _trauma := 0.0

	func _ready() -> void:
		add_to_group("game_camera")
		make_current()

	func shake(amount: float) -> void:
		_trauma = minf(_trauma + amount, 24.0)

	func _process(delta: float) -> void:
		if _trauma <= 0.01:
			offset = Vector2.ZERO
			return
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _trauma / zoom.x
		_trauma = lerpf(_trauma, 0.0, minf(delta * 10.0, 1.0))
