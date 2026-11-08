class_name Sfx
## Routes one-shots through the core AudioManager autoload (Effects bus).
## Looked up at runtime so scripts also compile in headless --script runs.


static func play(stream: AudioStream, pitch := 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var am := tree.root.get_node_or_null("AudioManager") if tree else null
	if am:
		am.play_sfx(stream, pitch)
