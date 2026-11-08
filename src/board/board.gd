@tool
class_name Board
extends Node2D
## A level. Built from an ASCII `layout` (also previewed in the editor) and the
## single source of truth for grid rules: walkability, pushing, doors, shot
## tracing and explosions.
##
## Legend
##   #  wall              .  plank floor        ,  sand floor
##   (space) void
##   1 2  player spawns (on default floor)
##   B  crate             b barrel  c cactus  r rock  h hay  t trough
##   +  bonus plate (+2 AP next turn)   -  drain plate (-1 AP for next player)
##   S sniper  R rpg  M molotov  G grenade  D shield   (pickups)
##   |  floor cell with a door on its LEFT edge, hinged at the top end
##   !  same, hinged at the bottom end
##   _  floor cell with a door on its TOP edge, hinged at the left end
##   ~  same, hinged at the right end
## Doors block only the edge they lie on and swing a quarter turn around the
## hinge corner when pushed (see Door).
## Props, pickups, plates, spawns and doors stand on `default_floor`.

const TILE_PLANKS := preload("res://assets/tiles/floor_planks.png")
const TILE_SAND := preload("res://assets/tiles/floor_sand.png")
const TILE_WALL := preload("res://assets/tiles/wall.png")
const OBSTACLES := {
	"b": "res://assets/props/barrel.png",
	"c": "res://assets/props/cactus.png",
	"r": "res://assets/props/rock.png",
	"h": "res://assets/props/hay.png",
	"t": "res://assets/props/trough.png",
}
const PICKUPS := {
	"S": Weapons.Kind.SNIPER, "R": Weapons.Kind.RPG, "M": Weapons.Kind.MOLOTOV,
	"G": Weapons.Kind.GRENADE, "D": Pickup.SHIELD,
}
enum Src { PLANKS, SAND, WALL }
const ATLAS_SPAN := 4

@export var level_name := "Untitled"
@export_enum("Planks", "Sand") var default_floor := 0:
	set(v):
		default_floor = v
		_rebuild_if_ready()
@export_multiline var layout := "":
	set(v):
		layout = v
		_rebuild_if_ready()

var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var props: Node2D  ## y-sorted: crates, obstacles, players, doors
var ground: Node2D  ## under props: plates, pickups, hazards
var overlay: Node2D  ## aim preview, drawn above props
var ghost: TurnGhost  ## replay of the previous player's turn
var spawns: Array[Vector2i] = []
var _walls := {}
var _floors := {}
var _built := false


func _ready() -> void:
	_build()


func _rebuild_if_ready() -> void:
	if is_inside_tree():
		_build()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_walls.clear()
	_floors.clear()
	spawns.clear()

	var ts := _make_tileset()
	floor_layer = TileMapLayer.new()
	floor_layer.name = "Floor"
	floor_layer.tile_set = ts
	add_child(floor_layer)
	var shadow := WallShadow.new()
	shadow.board = self
	add_child(shadow)
	var grid_lines := GridLines.new()
	grid_lines.board = self
	add_child(grid_lines)
	ground = Node2D.new()
	ground.name = "Ground"
	add_child(ground)
	ghost = TurnGhost.new()
	ghost.name = "TurnGhost"
	add_child(ghost)
	wall_layer = TileMapLayer.new()
	wall_layer.name = "Walls"
	wall_layer.tile_set = ts
	add_child(wall_layer)
	props = Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	add_child(props)
	overlay = AimOverlay.new()
	overlay.name = "Overlay"
	overlay.board = self
	add_child(overlay)

	var rows := layout.split("\n")
	var spawn_map := {}
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			_build_cell(Vector2i(x, y), row[x], spawn_map)
	var keys := spawn_map.keys()
	keys.sort()
	for k in keys:
		spawns.append(spawn_map[k])
	_built = true
	grid_lines.queue_redraw()
	shadow.queue_redraw()


func _build_cell(c: Vector2i, ch: String, spawn_map: Dictionary) -> void:
	match ch:
		" ":
			return
		"#":
			_walls[c] = true
			wall_layer.set_cell(c, Src.WALL, _atlas(c))
			return
		".":
			_set_floor(c, Src.PLANKS)
			return
		",":
			_set_floor(c, Src.SAND)
			return
	_set_floor(c, Src.PLANKS if default_floor == 0 else Src.SAND)
	if ch == "1" or ch == "2" or ch == "3" or ch == "4":
		spawn_map[ch] = c
	elif ch == "B":
		var crate := Crate.new()
		crate.place(c)
		props.add_child(crate)
	elif OBSTACLES.has(ch):
		var o := Obstacle.new()
		o.texture = load(OBSTACLES[ch])
		o.place(c)
		props.add_child(o)
	elif PICKUPS.has(ch):
		var p := Pickup.new()
		p.kind = PICKUPS[ch]
		p.place(c)
		ground.add_child(p)
	elif ch == "+" or ch == "-":
		var s := SpecialCell.new()
		s.effect = SpecialCell.Effect.AP_BONUS if ch == "+" else SpecialCell.Effect.AP_DRAIN
		s.place(c)
		ground.add_child(s)
	elif ch in ["|", "!", "_", "~"]:
		var d := Door.new()
		d.setup(c, ch == "|" or ch == "!", ch == "!" or ch == "~")
		props.add_child(d)
	else:
		push_warning("Board '%s': unknown layout char '%s' at %s" % [level_name, ch, c])


func _set_floor(c: Vector2i, src: int) -> void:
	_floors[c] = true
	floor_layer.set_cell(c, src, _atlas(c))


## Tile textures are 256 px and span 4x4 cells, so each cell picks its slice.
func _atlas(c: Vector2i) -> Vector2i:
	return Vector2i(posmod(c.x, ATLAS_SPAN), posmod(c.y, ATLAS_SPAN))


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(Grid.CELL, Grid.CELL)
	for tex in [TILE_PLANKS, TILE_SAND, TILE_WALL]:
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(Grid.CELL, Grid.CELL)
		for ax in ATLAS_SPAN:
			for ay in ATLAS_SPAN:
				src.create_tile(Vector2i(ax, ay))
		ts.add_source(src)
	return ts


# --- Queries -----------------------------------------------------------------

func is_wall(c: Vector2i) -> bool:
	return _walls.has(c)


func is_floor(c: Vector2i) -> bool:
	return _floors.has(c) and not _walls.has(c)


## Floor with nothing solid standing on it (players count as solid).
func is_open_floor(c: Vector2i) -> bool:
	return is_floor(c) and occupant_at(c) == null


func used_rect() -> Rect2:
	var r := Rect2i()
	var first := true
	for c in _floors.keys() + _walls.keys():
		if first:
			r = Rect2i(c, Vector2i.ONE)
			first = false
		else:
			r = r.expand(c).expand(c + Vector2i.ONE)
	return Rect2(Vector2(r.position) * Grid.CELL, Vector2(r.size) * Grid.CELL)


func floor_cells() -> Array:
	return _floors.keys()


## Crate, obstacle or living player on `c`.
func occupant_at(c: Vector2i) -> Node:
	for n in get_tree().get_nodes_in_group("occupant"):
		if n.cell == c and not n.is_queued_for_deletion():
			return n
	return null


func door_between(a: Vector2i, b: Vector2i) -> Door:
	for d in get_tree().get_nodes_in_group("door"):
		if d.spans(a, b):
			return d
	return null


func doors_touching(cells: Array) -> Array:
	var out := []
	for d in get_tree().get_nodes_in_group("door"):
		var e: Array[Vector2i] = d.edge()
		if e[0] in cells or e[1] in cells:
			out.append(d)
	return out


func pickup_at(c: Vector2i) -> Pickup:
	for p in get_tree().get_nodes_in_group("pickup"):
		if p.cell == c:
			return p
	return null


func special_at(c: Vector2i) -> SpecialCell:
	for s in get_tree().get_nodes_in_group("special_cell"):
		if s.cell == c:
			return s
	return null


func is_deadly(c: Vector2i) -> bool:
	for h in get_tree().get_nodes_in_group("hazard"):
		if h.is_deadly(c):
			return true
	return false


# --- Movement ------------------------------------------------------------------

## Can `crate` (and the chain behind it) move one cell along `dir`? Does not move.
func can_push(crate: Crate, dir: Vector2i) -> bool:
	var to := crate.cell + dir
	if not is_floor(to) or door_between(crate.cell, to):
		return false
	var o := occupant_at(to)
	if o == null:
		return true
	return o is Crate and can_push(o, dir)


## Moves the whole chain; call only after can_push() returned true.
func push(crate: Crate, dir: Vector2i) -> void:
	var o := occupant_at(crate.cell + dir)
	if o is Crate:
		push(o, dir)
	crate.slide_to(crate.cell + dir)


# --- Shots ---------------------------------------------------------------------

## Walks a straight shot from `from` (exclusive) along `dir`.
## Returns {hits: [nodes hit in order], end: last cell reached, stop: Node|null,
## blast: cell an explosive detonates in}. With `pierce`, crates and doors are
## hit but do not stop the shot.
func trace(from: Vector2i, dir: Vector2i, pierce := false, max_cells := 40) -> Dictionary:
	var hits := []
	var cell := from
	var stop: Node = null
	var blast := from
	for i in max_cells:
		var next := cell + dir
		var door := door_between(cell, next)
		if door:
			hits.append(door)
			if not pierce:
				stop = door
				blast = cell
				break
		if not is_floor(next):
			blast = cell
			break
		var o := occupant_at(next)
		cell = next
		if o:
			hits.append(o)
			var passes := pierce and (o is Crate)
			if not passes:
				stop = o
				blast = next
				break
		blast = cell
	return {"hits": hits, "end": cell, "stop": stop, "blast": blast}


## Where a shot along `dir` from `from` visually ends, in world space.
func impact_point(from: Vector2i, dir: Vector2i, result: Dictionary) -> Vector2:
	var end: Vector2i = result["end"]
	var stop: Node = result["stop"]
	var p := Grid.to_world(end)
	if stop == null or stop is Door:
		p += Vector2(dir) * Grid.CELL * 0.5  # wall face / door on the edge
	if from == end and stop == null:
		p = Grid.to_world(from) + Vector2(dir) * Grid.CELL * 0.5
	return p


## A + explosion centred on `center`. `center_dir` is the travel direction used
## for whoever stands on the centre cell (ZERO = can't be shielded).
func explode(center: Vector2i, center_dir: Vector2i) -> void:
	var cells := Grid.cross(center)
	for c in cells:
		if is_floor(c):
			Fx.explosion(ground, Grid.to_world(c))
	Fx.shake(self, 14.0)
	Sfx.named("explosion", 1.0, 0.08)
	for d in doors_touching(cells):
		d.take_hit(Vector2i.ZERO)
	for c in cells:
		var o := occupant_at(c)
		if o == null or not o.has_method("take_hit"):
			continue
		var dir := center_dir if c == center else Grid.dir_towards(center, c)
		o.take_hit(dir)


# --- Inner drawing helpers ---------------------------------------------------------

class WallShadow extends Node2D:
	var board: Board

	func _draw() -> void:
		for c in board._walls.keys():
			var below: Vector2i = c + Vector2i.DOWN
			if board._floors.has(below) and not board._walls.has(below):
				var r := Rect2(Vector2(below) * Grid.CELL, Vector2(Grid.CELL, 14))
				draw_rect(r, Color(0, 0, 0, 0.35))
				draw_rect(Rect2(r.position + Vector2(0, 14), Vector2(Grid.CELL, 8)), Color(0, 0, 0, 0.15))


class GridLines extends Node2D:
	var board: Board

	func _draw() -> void:
		var col := Color(0, 0, 0, 0.12)
		for c in board._floors.keys():
			var r := Rect2(Vector2(c) * Grid.CELL, Vector2(Grid.CELL, Grid.CELL))
			draw_rect(r, col, false, 1.0)
