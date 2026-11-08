class_name Props
## Small shared helpers for building entity visuals in code.


## Adds a Sprite2D fitted into a `px` box, standing on the bottom of its cell
## (so y-sorting reads correctly). Returns the sprite.
static func make_sprite(parent: Node2D, tex: Texture2D, px: float, standing := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	if tex:
		var size := tex.get_size()
		var k := px / maxf(size.x, size.y)
		s.scale = Vector2(k, k)
		if standing:
			s.position = Vector2(0, Grid.CELL * 0.5 - 4.0 - size.y * k * 0.5)
	parent.add_child(s)
	return s
