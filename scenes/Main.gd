extends Node3D
## Einstiegsszene: Startmenü, Testraum und Spielfiguren.
## Der Host spawnt für jeden Peer eine Figur unter „Players“; der MultiplayerSpawner repliziert sie zu den Clients.
## Zum schnellen Testen per Kommandozeile: „-- --host“ oder „-- --join=127.0.0.1“.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const SPAWN_ORIGIN: Vector3 = Vector3(0, 0, 4)
const SPAWN_SPACING: float = 1.5

@onready var _players: Node3D = $Players
@onready var _menu: MainMenu = $UI/MainMenu
@onready var _help: Label = $UI/Help


func _ready() -> void:
	print("Deep Defense gestartet – Godot %s" % Engine.get_version_info().string)
	_help.visible = false
	_menu.host_requested.connect(_on_host_requested)
	_menu.join_requested.connect(_on_join_requested)
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.connection_succeeded.connect(_on_session_started)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	_apply_command_line()


func _unhandled_input(event: InputEvent) -> void:
	# Bis es ein Pausemenü gibt, beendet Esc den Prototyp.
	if event.is_action_pressed("menu"):
		get_tree().quit()


func _apply_command_line() -> void:
	# Beide Listen prüfen, damit es mit und ohne „--“-Trenner funktioniert.
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg: String in args:
		if arg == "--host":
			_on_host_requested()
			return
		if arg.begins_with("--join"):
			var address := arg.get_slice("=", 1) if "=" in arg else "127.0.0.1"
			_on_join_requested(address)
			return


func _on_host_requested() -> void:
	var error := NetworkManager.host_game()
	if error != OK:
		_menu.show_status("Hosten fehlgeschlagen: %s" % error_string(error))
		return
	_on_session_started()


func _on_join_requested(address: String) -> void:
	var error := NetworkManager.join_game(address)
	if error != OK:
		_menu.show_status("Beitreten fehlgeschlagen: %s" % error_string(error))
		return
	_menu.set_busy(true)
	_menu.show_status("Verbinde mit %s …" % address)


func _on_session_started() -> void:
	_menu.visible = false
	_help.visible = true


func _on_connection_failed() -> void:
	_menu.set_busy(false)
	_menu.show_status("Verbindung fehlgeschlagen.")


func _on_server_disconnected() -> void:
	# Einfachster sauberer Zustand: Szene neu laden, das Menü erscheint wieder.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


func _on_player_joined(peer_id: int) -> void:
	var player := PLAYER_SCENE.instantiate() as Node3D
	player.name = str(peer_id)
	var spawn := SPAWN_ORIGIN + Vector3(SPAWN_SPACING * _players.get_child_count(), 0, 0)
	player.set("sync_position", spawn)
	_players.add_child(player, true)


func _on_player_left(peer_id: int) -> void:
	var player := _players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
