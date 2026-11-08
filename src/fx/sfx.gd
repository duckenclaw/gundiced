class_name Sfx
## Routes one-shots through the core AudioManager autoload (Effects bus).
## Looked up at runtime so scripts also compile in headless --script runs.
## The synthesized sounds come from tools/synth_sfx.py.

const SOUNDS := {
	"step": preload("res://assets/sfx/step.wav"),
	"ready": preload("res://assets/sfx/ready-shot.wav"),
	"pickup": preload("res://assets/sfx/pickup.wav"),
	"revolver": preload("res://assets/sfx/shot.wav"),
	"sniper": preload("res://assets/sfx/sniper.wav"),
	"rpg": preload("res://assets/sfx/rpg_launch.wav"),
	"explosion": preload("res://assets/sfx/explosion.wav"),
	"throw": preload("res://assets/sfx/throw.wav"),
	"molotov": preload("res://assets/sfx/molotov.wav"),
	"shield_block": preload("res://assets/sfx/shield_block.wav"),
	"crate_break": preload("res://assets/sfx/crate_break.wav"),
	"door": preload("res://assets/sfx/door.wav"),
	"dice_tick": preload("res://assets/sfx/dice_tick.wav"),
	"dice_land": preload("res://assets/sfx/dice_land.wav"),
	"turn": preload("res://assets/sfx/turn.wav"),
	"bump": preload("res://assets/sfx/bump.wav"),
}


static func play(stream: AudioStream, pitch := 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var am := tree.root.get_node_or_null("AudioManager") if tree else null
	if am:
		am.play_sfx(stream, pitch)


## Play a named sound with a little random pitch variation.
static func named(id: String, pitch := 1.0, jitter := 0.05) -> void:
	play(SOUNDS[id], pitch * randf_range(1.0 - jitter, 1.0 + jitter))
