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
@onready var _trait_select: OptionButton = %TraitSelect
@onready var _trait_description: Label = %TraitDescription
@onready var _seed_edit: LineEdit = %SeedEdit

## Wählbare Merkmale; zum Start sind laut GDD die Start-Knoten freigeschaltet (Prototyp: Hauer, Raufbold).
const TRAIT_PATHS: Array[String] = ["res://data/traits/miner.tres", "res://data/traits/brawler.tres"]


func _ready() -> void:
	_host_button.pressed.connect(func() -> void: host_requested.emit())
	# Der Seed gilt nur beim Hosten; wer beitritt, spielt den Seed des Hosts.
	_seed_edit.text = GameState.requested_seed_text
	_seed_edit.text_changed.connect(func(text: String) -> void: GameState.requested_seed_text = text)
	_seed_edit.text_submitted.connect(func(_text: String) -> void: host_requested.emit())
	_join_button.pressed.connect(_request_join)
	_address_edit.text_submitted.connect(func(_text: String) -> void: _request_join())
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())
	_trait_select.add_item("Kein Merkmal")
	for path in TRAIT_PATHS:
		_trait_select.add_item((load(path) as TraitData).display_name)
	_trait_select.item_selected.connect(_on_trait_selected)
	_on_trait_selected(0)
	_host_button.grab_focus()


func show_status(text: String) -> void:
	_status_label.text = text


func set_busy(busy: bool) -> void:
	_host_button.disabled = busy
	_join_button.disabled = busy


func _request_join() -> void:
	var address := _address_edit.text.strip_edges()
	join_requested.emit(address if not address.is_empty() else "127.0.0.1")


func _on_trait_selected(index: int) -> void:
	if index <= 0:
		GameState.selected_trait_path = ""
		_trait_description.text = "Ohne Vor- und Nachteile."
	else:
		GameState.selected_trait_path = TRAIT_PATHS[index - 1]
		_trait_description.text = (load(GameState.selected_trait_path) as TraitData).description
