class_name Obstacle
extends Node2D
## Indestructible decor (barrel, cactus, rock, hay, trough): blocks movement and
## shots like a wall but sits on a floor tile.

var cell: Vector2i
var texture: Texture2D


func _ready() -> void:
	add_to_group("obstacle")
	add_to_group("occupant")
	Props.make_sprite(self, texture, 58.0)


func place(c: Vector2i) -> void:
	cell = c
	position = Grid.to_world(c)


func take_hit(_dir: Vector2i) -> void:
	Fx.sparks(get_parent(), position, Color(1, 0.9, 0.6))
