class_name Grid
## One grid for everything: a cell is one 64 px tile. Cell (x, y) covers
## [x*64, x*64+64) and its centre is where entities stand.

const CELL := 64
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]


static func to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5


static func to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))


## The four cells of a "+" around `center`, centre first.
static func cross(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [center]
	for d in DIRS:
		cells.append(center + d)
	return cells


## Cardinal direction from `from` towards `to` (largest axis wins); ZERO if equal.
static func dir_towards(from: Vector2i, to: Vector2i) -> Vector2i:
	var d := to - from
	if d == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(d.x) >= absi(d.y):
		return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))
