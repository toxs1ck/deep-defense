class_name InputNames
extends RefCounted
## Lesbare Namen für Eingaben aus der Input Map, für HUD-Prompts und die Steuerungsübersicht im Pausenmenü.
## Controller-Tasten nach Xbox-Belegung, wie in der Steuerungstabelle im GDD.

const JOY_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Steuerkreuz ↑", JOY_BUTTON_DPAD_DOWN: "Steuerkreuz ↓",
	JOY_BUTTON_DPAD_LEFT: "Steuerkreuz ←", JOY_BUTTON_DPAD_RIGHT: "Steuerkreuz →",
}
const JOY_AXIS_NAMES: Dictionary = {
	JOY_AXIS_LEFT_X: "Linker Stick", JOY_AXIS_LEFT_Y: "Linker Stick",
	JOY_AXIS_RIGHT_X: "Rechter Stick", JOY_AXIS_RIGHT_Y: "Rechter Stick",
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
}
const MOUSE_BUTTON_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "Linksklick", MOUSE_BUTTON_RIGHT: "Rechtsklick", MOUSE_BUTTON_MIDDLE: "Mittelklick",
	MOUSE_BUTTON_WHEEL_UP: "Mausrad ↑", MOUSE_BUTTON_WHEEL_DOWN: "Mausrad ↓",
}


## Name einer einzelnen Eingabe; leer, wenn sie nicht zum Gerät passt (gamepad = Controller, sonst Tastatur/Maus).
static func event_name(event: InputEvent, gamepad: bool) -> String:
	if gamepad and event is InputEventJoypadButton:
		var index := (event as InputEventJoypadButton).button_index
		return str(JOY_BUTTON_NAMES.get(index, "Taste %d" % index))
	if gamepad and event is InputEventJoypadMotion:
		var axis := (event as InputEventJoypadMotion).axis
		return str(JOY_AXIS_NAMES.get(axis, "Achse %d" % axis))
	if not gamepad and event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		return str(MOUSE_BUTTON_NAMES.get(button, "Maustaste %d" % button))
	if not gamepad and event is InputEventKey:
		var keycode := DisplayServer.keyboard_get_keycode_from_physical((event as InputEventKey).physical_keycode)
		return OS.get_keycode_string(keycode)
	return ""


## Erste passende Belegung einer Aktion, z. B. für „E: Aufheben“.
static func first(action: StringName, gamepad: bool) -> String:
	for event in InputMap.action_get_events(action):
		var label := event_name(event, gamepad)
		if not label.is_empty():
			return label
	return "?"


## Alle Belegungen einer oder mehrerer Aktionen, ohne Doppelte, z. B. „W / A / S / D“.
static func all(actions: Array[StringName], gamepad: bool) -> String:
	var labels := PackedStringArray()
	for action in actions:
		for event in InputMap.action_get_events(action):
			var label := event_name(event, gamepad)
			if not label.is_empty() and not label in labels:
				labels.append(label)
	return " / ".join(labels) if not labels.is_empty() else "–"
