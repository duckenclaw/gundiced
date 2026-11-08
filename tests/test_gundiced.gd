extends SceneTree

## Headless rule tests: levels, movement, pushing, doors, every weapon, the
## shield, hazards, pickups, special cells and a scripted match turn.
## Run: godot --headless --path . --script tests/test_gundiced.gd

var _failures := 0
var _actions := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: " + msg)
	else:
		_failures += 1
		print("FAIL: " + msg)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	await _test_levels()
	await _test_move_and_walls()
	await _test_push()
	await _test_doors()
	await _test_revolver_and_shield()
	await _test_sniper()
	await _test_rpg()
	await _test_thrown()
	await _test_pickups()
	await _test_match_turn()
	print("RESULT: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)


func _wait(t: float) -> void:
	await create_timer(t).timeout


func _board(layout: String) -> Board:
	var b := Board.new()
	b.layout = layout
	root.add_child(b)
	await process_frame
	return b


func _player(b: Board, c: Vector2i, i := 0, face := Vector2i.RIGHT) -> Player:
	var p := Player.new()
	p.index = i
	p.texture = load("res://assets/players/player%d.png" % (i + 1))
	p.board = b
	b.props.add_child(p)
	p.place(c, face)
	p.action_performed.connect(func() -> void: _actions += 1)
	return p


func _done(b: Board) -> void:
	b.queue_free()
	await process_frame
	await process_frame


func _test_levels() -> void:
	for lvl in Match.LEVELS:
		var b: Board = (load(lvl["path"]) as PackedScene).instantiate()
		root.add_child(b)
		await process_frame
		check(b.spawns.size() == 2, "%s: two spawns" % lvl["name"])
		check(b.is_floor(b.spawns[0]) and b.is_floor(b.spawns[1]), "%s: spawns on floor" % lvl["name"])
		check(b.used_rect().size.x > 0, "%s: has a footprint" % lvl["name"])
		check(b.get_tree().get_nodes_in_group("pickup").size() >= 2, "%s: has pickups" % lvl["name"])
		await _done(b)


func _test_move_and_walls() -> void:
	var b := await _board("#####\n#...#\n#####")
	var p := _player(b, Vector2i(1, 1))
	_actions = 0
	check(not await p.try_move(Vector2i.UP), "move into wall refused")
	check(_actions == 0, "refused move costs no AP")
	check(await p.try_move(Vector2i.RIGHT), "move onto floor")
	check(p.cell == Vector2i(2, 1) and _actions == 1, "moved one cell, one action")
	var q := _player(b, Vector2i(3, 1), 1)
	check(not await p.try_move(Vector2i.RIGHT), "can't walk into another player")
	q.queue_free()
	await _done(b)


func _test_push() -> void:
	var b := await _board("#######\n#.BB..#\n#######")
	var p := _player(b, Vector2i(1, 1))
	check(await p.try_move(Vector2i.RIGHT), "push chain of two crates")
	check(b.occupant_at(Vector2i(4, 1)) is Crate and b.occupant_at(Vector2i(3, 1)) is Crate, "both crates moved")
	await _wait(0.2)
	check(await p.try_move(Vector2i.RIGHT), "push chain again")
	check(not await p.try_move(Vector2i.RIGHT), "chain against wall refused")
	check(p.cell == Vector2i(3, 1), "player stayed put")
	await _done(b)


func _test_doors() -> void:
	var b := await _board("#####\n#.|.#\n#####")
	var d: Door = b.get_tree().get_nodes_in_group("door")[0]
	check(d.cell_a == Vector2i(1, 1) and d.cell_b == Vector2i(2, 1), "door spans the right edge")
	var p := _player(b, Vector2i(1, 1))
	var res := b.trace(Vector2i(1, 1), Vector2i.RIGHT)
	check(res["stop"] == d, "closed door stops shots")
	check(await p.try_move(Vector2i.RIGHT), "walk through door")
	check(d.rotation_state == 90, "door swung +90")
	check(await p.try_move(Vector2i.RIGHT) and p.cell == Vector2i(3, 1), "walk on")
	check(await p.try_move(Vector2i.LEFT) and await p.try_move(Vector2i.LEFT), "walk back through (closes it)")
	check(d.rotation_state == 0, "door back to closed")
	check(await p.try_move(Vector2i.RIGHT), "through again")
	await p.try_move(Vector2i.RIGHT)
	check(not await p.try_move(Vector2i.LEFT) or d.rotation_state <= 90, "door never exceeds its limit")
	await _done(b)


func _test_revolver_and_shield() -> void:
	var b := await _board("#########\n#.....B.#\n#########")
	var a := _player(b, Vector2i(1, 1), 0)
	var v := _player(b, Vector2i(4, 1), 1, Vector2i.LEFT)
	a.enter_aim()
	a.aim(Vector2i.RIGHT)
	await a.fire()
	check(v.is_dead(), "revolver kills the first thing in line")
	var c := b.occupant_at(Vector2i(6, 1))
	check(c is Crate, "crate behind the target untouched")
	v.queue_free()
	await process_frame

	var w := _player(b, Vector2i(3, 1), 1, Vector2i.LEFT)
	w.has_shield = true
	w.shield_dir = Vector2i.LEFT
	a.enter_aim()
	a.aim(Vector2i.RIGHT)
	await a.fire()
	check(not w.is_dead() and not w.has_shield, "front shield absorbs one shot and breaks")
	a.enter_aim()
	a.aim(Vector2i.RIGHT)
	await a.fire()
	check(w.is_dead(), "second shot kills")

	var z := _player(b, Vector2i(5, 1), 1)
	z.has_shield = true
	z.shield_dir = Vector2i.RIGHT
	z.take_hit(Vector2i.RIGHT)
	check(z.is_dead(), "shield facing away does not help")
	await _done(b)


func _test_sniper() -> void:
	var b := await _board("##########\n#..B.|..#.\n##########")
	var a := _player(b, Vector2i(1, 1))
	var v := _player(b, Vector2i(7, 1), 1)
	a.weapon = Weapons.Kind.SNIPER
	a.ammo = 2
	a.enter_aim()
	a.aim(Vector2i.RIGHT)
	await a.fire()
	await _wait(0.1)
	check(v.is_dead(), "sniper pierces crate and door")
	check(b.occupant_at(Vector2i(3, 1)) == null, "pierced crate destroyed")
	check(a.ammo == 1, "sniper used one round")
	a.enter_aim()
	await a.fire()
	check(a.weapon == Weapons.Kind.REVOLVER and a.ammo < 0, "empty special falls back to revolver")
	await _done(b)


func _test_rpg() -> void:
	var b := await _board("#########\n#.......#\n#.......#\n#.......#\n#########")
	var a := _player(b, Vector2i(1, 2))
	var v := _player(b, Vector2i(6, 2), 1, Vector2i.LEFT)
	v.has_shield = true
	v.shield_dir = Vector2i.LEFT
	var crate := Crate.new()
	crate.place(Vector2i(6, 1))
	b.props.add_child(crate)
	await process_frame
	a.weapon = Weapons.Kind.RPG
	a.ammo = 1
	a.enter_aim()
	a.aim(Vector2i.RIGHT)
	await a.fire()
	await _wait(0.1)
	check(not v.is_dead() and not v.has_shield, "shield blocks a direct RPG hit")
	check(b.occupant_at(Vector2i(6, 1)) == null, "RPG splash breaks adjacent crate")
	b.explode(Vector2i(5, 2), Vector2i.ZERO)
	check(v.is_dead(), "unshielded splash kills")
	await _done(b)


func _test_thrown() -> void:
	var b := await _board("#########\n#.......#\n#.......#\n#.......#\n#########")
	var a := _player(b, Vector2i(1, 2))
	var v := _player(b, Vector2i(6, 1), 1)
	a.weapon = Weapons.Kind.GRENADE
	a.ammo = 1
	a.enter_aim()
	for i in 3:
		a.aim(Vector2i.RIGHT)
	await a.fire()
	var hz := b.get_tree().get_nodes_in_group("hazard")
	check(hz.size() == 1 and hz[0].cells[0] == Vector2i(5, 2), "grenade lands where aimed")
	hz[0].on_turn_started(v)
	check(not v.is_dead(), "grenade waits through the opponent's turn")
	hz[0].on_turn_started(a)
	check(not v.is_dead(), "diagonal cell is outside the +")
	await _wait(0.1)

	a.weapon = Weapons.Kind.MOLOTOV
	a.ammo = 1
	a.enter_aim()
	for i in 3:
		a.aim(Vector2i.RIGHT)
	await a.fire()
	check(b.is_deadly(Vector2i(5, 1)), "molotov fire covers the +")
	_actions = 0
	await v.try_move(Vector2i.LEFT)
	check(v.is_dead(), "walking into fire kills")
	await _done(b)


func _test_pickups() -> void:
	var b := await _board("######\n#.SD.#\n######")
	var p := _player(b, Vector2i(1, 1))
	await p.try_move(Vector2i.RIGHT)
	check(p.weapon == Weapons.Kind.SNIPER and p.ammo == 2, "step on sniper pickup")
	await p.try_move(Vector2i.RIGHT)
	check(p.has_shield and p.shield_dir == Vector2i.RIGHT, "step on shield pickup, faces walk direction")
	p.enter_shield_aim()
	check(p.state == Player.State.SHIELD_AIM, "shield aim mode")
	await _done(b)


func _test_match_turn() -> void:
	Match.level_path = "res://src/levels/saloon.tscn"
	var m: Match = (load("res://src/match/match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	var t := 0.0
	while m.phase != Match.Phase.ACTIVE and t < 10.0:
		await _wait(0.1)
		t += 0.1
	check(m.phase == Match.Phase.ACTIVE, "match reaches an active turn after the rolls")
	check(m.ap >= 1 and m.ap <= 6, "turn AP comes from a D6")
	var p: Player = m.players[m.current]
	check(p.controllable, "active player has control")
	var before := m.ap
	for d in Grid.DIRS:
		if await p.try_move(d):
			break
	await _wait(0.05)
	check(m.ap == before - 1 or m.current != p.index, "a move spends one AP")
	m.queue_free()
	await process_frame
