extends SettingsManager
## Settings autoload (registered as "GameSettings").
##
## Inherits persistence/apply logic from SettingsManager (addons/settings_kit) and
## exposes the duel's actions to the rebind UI. The default bindings live in
## project.godot's Input Map.

const REBINDABLE: Array[String] = [
	"move_up", "move_down", "move_left", "move_right",
	"shoot", "shield", "cancel", "end_turn", "rematch",
]


func _ready() -> void:
	rebindable_actions = REBINDABLE
	super()
