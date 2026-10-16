class_name PauseMenu
extends Control
## Esc-Menü während des Spiels. Zeigt den Mauszeiger und sperrt die Eingaben der Spielfigur;
## das Spiel läuft im Hintergrund weiter. Meldet die Wahl per Signal nach oben, Main führt sie aus.
## Daneben steht die Steuerung; die Tasten kommen aus der Input Map, stimmen also auch nach dem Umbelegen.

signal leave_requested
signal quit_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _leave_button: Button = %LeaveButton
@onready var _quit_button: Button = %QuitButton
@onready var _controls_grid: GridContainer = %ControlsGrid

## Zeilen der Steuerungsübersicht: Beschreibung und die Aktionen dazu. Ohne „actions“ gelten feste Texte
## (Maus und Sticks laufen nicht über die Input Map).
const CONTROLS: Array[Dictionary] = [
	{ "label": "Laufen", "actions": [&"move_forward", &"move_left", &"move_back", &"move_right"] },
	{ "label": "Kamera", "keyboard": "Maus", "gamepad": "Rechter Stick" },
	{ "label": "Springen", "actions": [&"jump"] },
	{ "label": "Sprinten", "actions": [&"sprint"] },
	{ "label": "Spitzhacke: abbauen, kämpfen (halten: weiter)", "actions": [&"attack"] },
	{ "label": "Aufheben, einladen, Munition laden (tippen)", "actions": [&"interact"] },
	{ "label": "Kaufen, abbauen, neu würfeln (halten)", "actions": [&"interact"] },
	{ "label": "Getragenes: ablegen", "actions": [&"interact"] },
	{ "label": "Getragenes: werfen", "actions": [&"attack"] },
	{ "label": "Angebot in der Hand kaufen (halten)", "actions": [&"purchase_carried"] },
	{ "label": "Kiste in der Hand: aufbauen", "actions": [&"attack"] },
	{ "label": "Kiste in der Hand: drehen", "actions": [&"build_rotate_left", &"build_rotate_right"] },
	{ "label": "Bereit (Bauphase)", "actions": [&"ready"] },
	{ "label": "Kamera-Schulter wechseln", "actions": [&"camera_switch_shoulder"] },
	{ "label": "Menü", "actions": [&"menu"] },
]


func _ready() -> void:
	visible = false
	_resume_button.pressed.connect(close)
	_leave_button.pressed.connect(func() -> void: leave_requested.emit())
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())
	_fill_controls()


func open() -> void:
	visible = true
	GameState.input_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resume_button.grab_focus()


func close() -> void:
	visible = false
	GameState.input_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _fill_controls() -> void:
	for header: String in ["Aktion", "Tastatur & Maus", "Controller"]:
		var label := Label.new()
		label.text = header
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
		_controls_grid.add_child(label)
	for row in CONTROLS:
		var keyboard: String
		var gamepad: String
		if row.has("actions"):
			var actions: Array[StringName] = []
			actions.assign(row["actions"])
			keyboard = InputNames.all(actions, false)
			gamepad = InputNames.all(actions, true)
		else:
			keyboard = str(row["keyboard"])
			gamepad = str(row["gamepad"])
		for text: String in [str(row["label"]), keyboard, gamepad]:
			var label := Label.new()
			label.text = text
			label.add_theme_font_size_override("font_size", 14)
			_controls_grid.add_child(label)
