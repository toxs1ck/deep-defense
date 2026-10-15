class_name HUD
extends Control
## Spiel-HUD: Teamkasse, Fadenkreuz und Interaktions-Prompt („E: Abbauen“), beim Tragen der Hinweis zum Ablegen/Werfen.
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
@onready var _money_label: Label = %MoneyLabel

var _target: InteractableComponent = null
var _carrying: bool = false
## Zuletzt angezeigter Betrag; -1 = noch keiner, dann ohne Aufleuchten.
var _money: int = -1
var _using_gamepad: bool = false


func _ready() -> void:
	_prompt_label.visible = false
	set_money(Economy.team_money)


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


func set_money(amount: int) -> void:
	var changed := _money >= 0 and amount != _money
	_money = amount
	_money_label.text = "Teamkasse: %d $" % amount
	if changed:
		# Kurzes Aufleuchten, damit man die Auszahlung bemerkt.
		_money_label.pivot_offset = _money_label.size / 2.0
		_money_label.scale = Vector2.ONE * 1.25
		create_tween().tween_property(_money_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
