class_name PauseMenu
extends Control
## Esc-Menü während des Spiels. Zeigt den Mauszeiger und sperrt die Eingaben der Spielfigur;
## das Spiel läuft im Hintergrund weiter. Meldet die Wahl per Signal nach oben, Main führt sie aus.

signal leave_requested
signal quit_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _leave_button: Button = %LeaveButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	visible = false
	_resume_button.pressed.connect(close)
	_leave_button.pressed.connect(func() -> void: leave_requested.emit())
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())


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
