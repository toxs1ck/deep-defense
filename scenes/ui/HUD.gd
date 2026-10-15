class_name HUD
extends Control
## Spiel-HUD: Fadenkreuz und Interaktions-Prompt („E: Abbauen“), beim Tragen der Hinweis zum Ablegen/Werfen.
## Die angezeigte Taste kommt aus der Input Map und wechselt zwischen Tastatur und Controller,
## je nachdem, was zuletzt benutzt wurde.

## Namen der Controller-Tasten nach Xbox-Belegung (SDL-Indizes), wie in der Steuerungstabelle im GDD.
const JOY_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
}
## Mindestausschlag, ab dem ein Stick als Controller-Nutzung zählt (gegen Stick-Drift).
const JOY_MOTION_THRESHOLD: float = 0.5
const JOY_AXIS_NAMES: Dictionary = { JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT" }
const MOUSE_BUTTON_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "Linksklick", MOUSE_BUTTON_RIGHT: "Rechtsklick", MOUSE_BUTTON_MIDDLE: "Mittelklick",
}

@onready var _prompt_label: Label = %PromptLabel

var _target: InteractableComponent = null
var _carrying: bool = false
var _using_gamepad: bool = false


func _ready() -> void:
	_prompt_label.visible = false


func _input(event: InputEvent) -> void:
	var gamepad := _using_gamepad
	if event is InputEventJoypadButton:
		gamepad = true
	elif event is InputEventJoypadMotion:
		gamepad = gamepad or absf((event as InputEventJoypadMotion).axis_value) > JOY_MOTION_THRESHOLD
	elif event is InputEventKey or event is InputEventMouseButton:
		gamepad = false
	if gamepad != _using_gamepad:
		_using_gamepad = gamepad
		_refresh_prompt()


func show_interaction(target: InteractableComponent) -> void:
	_target = target
	_refresh_prompt()


func set_carrying(carrying: bool) -> void:
	_carrying = carrying
	_refresh_prompt()


func _refresh_prompt() -> void:
	_prompt_label.visible = _target != null or _carrying
	if _target:
		_prompt_label.text = "%s: %s" % [_action_key_name(&"interact"), _target.prompt_text]
	elif _carrying:
		_prompt_label.text = "%s: Ablegen · %s: Werfen" % [_action_key_name(&"interact"), _action_key_name(&"attack")]


func _action_key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if _using_gamepad and event is InputEventJoypadButton:
			var index := (event as InputEventJoypadButton).button_index
			return str(JOY_BUTTON_NAMES.get(index, "Taste %d" % index))
		if _using_gamepad and event is InputEventJoypadMotion:
			var axis := (event as InputEventJoypadMotion).axis
			return str(JOY_AXIS_NAMES.get(axis, "Achse %d" % axis))
		if not _using_gamepad and event is InputEventMouseButton:
			var button := (event as InputEventMouseButton).button_index
			return str(MOUSE_BUTTON_NAMES.get(button, "Maustaste %d" % button))
		if not _using_gamepad and event is InputEventKey:
			var key_event := event as InputEventKey
			var keycode := DisplayServer.keyboard_get_keycode_from_physical(key_event.physical_keycode)
			return OS.get_keycode_string(keycode)
	return "?"
