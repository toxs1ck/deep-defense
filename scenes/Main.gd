extends Node3D
## Einstiegsszene: Startmenü, Testraum und Spielfiguren.
## Der Host spawnt für jeden Peer eine Figur unter „Players“; der MultiplayerSpawner repliziert sie zu den Clients.
## Zum schnellen Testen per Kommandozeile: „-- --host“ oder „-- --join=127.0.0.1“.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const CHUNK_SCENE: PackedScene = preload("res://scenes/world/OreChunk.tscn")
const SPAWN_ORIGIN: Vector3 = Vector3(0, 0, 4)
const SPAWN_SPACING: float = 1.5

@onready var _players: Node3D = $Players
@onready var _chunks: Node3D = $Chunks
@onready var _menu: MainMenu = $UI/MainMenu
@onready var _help: Label = $UI/Help
@onready var _hud: HUD = $UI/HUD
@onready var _network_status: Label = $UI/NetworkStatus


func _ready() -> void:
	print("Deep Defense gestartet – Godot %s" % Engine.get_version_info().string)
	_help.visible = false
	_hud.visible = false
	_players.child_entered_tree.connect(_on_player_added)
	for deposit: OreDeposit in get_tree().get_nodes_in_group(OreDeposit.GROUP):
		deposit.chunk_broken_off.connect(_on_chunk_broken_off)
	_network_status.visible = false
	_menu.host_requested.connect(_on_host_requested)
	_menu.join_requested.connect(_on_join_requested)
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.connection_succeeded.connect(_on_session_started)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	_apply_command_line()


func _process(_delta: float) -> void:
	if _network_status.visible:
		var role := "Host" if multiplayer.is_server() else "Client"
		_network_status.text = "%s · ID %d · Spieler: %d" % [role, multiplayer.get_unique_id(), _players.get_child_count()]


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
	_hud.visible = true
	_network_status.visible = true
	# Hilft beim Testen mit mehreren Fenstern, sie auseinanderzuhalten.
	var role := "Host" if multiplayer.is_server() else "Client %d" % multiplayer.get_unique_id()
	get_window().title = "Deep Defense – %s" % role


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


## Läuft auf allen Peers, auch für vom MultiplayerSpawner erzeugte Figuren. Nur die eigene Figur speist das HUD.
## Achtung: Die Figur ist hier noch nicht „ready“, @onready-Felder sind leer. Nur Signale der Figur verbinden.
func _on_player_added(node: Node) -> void:
	var player := node as Player
	if player and player.is_multiplayer_authority():
		player.interaction_target_changed.connect(_hud.show_interaction)
		player.carrying_changed.connect(_hud.set_carrying)


## Nur auf dem Host: Brocken spawnen, der ChunkSpawner repliziert sie zu den Clients.
func _on_chunk_broken_off(ore: OreData, spawn_position: Vector3, impulse: Vector3) -> void:
	var chunk := CHUNK_SCENE.instantiate() as OreChunk
	chunk.ore_path = ore.resource_path
	chunk.position = spawn_position
	chunk.sync_position = spawn_position
	_chunks.add_child(chunk, true)
	chunk.apply_central_impulse(impulse * chunk.mass)


func _on_player_left(peer_id: int) -> void:
	var player := _players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
