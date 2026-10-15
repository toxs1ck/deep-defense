class_name MainMenu
extends Control
## Startmenü: Host oder Join. Meldet Wünsche nur per Signal nach oben, die Verbindung baut Main auf.

signal host_requested
signal join_requested(address: String)
signal quit_requested

@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _status_label: Label = %StatusLabel
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_host_button.pressed.connect(func() -> void: host_requested.emit())
	_join_button.pressed.connect(_request_join)
	_address_edit.text_submitted.connect(func(_text: String) -> void: _request_join())
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())
	_host_button.grab_focus()


func show_status(text: String) -> void:
	_status_label.text = text


func set_busy(busy: bool) -> void:
	_host_button.disabled = busy
	_join_button.disabled = busy


func _request_join() -> void:
	var address := _address_edit.text.strip_edges()
	join_requested.emit(address if not address.is_empty() else "127.0.0.1")
