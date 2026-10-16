extends Node3D
## Einstiegsszene: Startmenü, Welt (Testmine; der alte Testraum lässt sich unter „World“ wieder einsetzen) und Spielfiguren.
## Jede Welt braucht: Elevator, ShopTerminal, Stellplätze (Gruppe shop_pads), Gegner-Eingänge (enemy_spawns) und
## eine NavigationRegion3D mit NavigationBaker.
## Der Host spawnt für jeden Peer eine Figur unter „Players“; der MultiplayerSpawner repliziert sie zu den Clients.
## Zum schnellen Testen per Kommandozeile: „-- --host“ oder „-- --join=127.0.0.1“.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const CHUNK_SCENE: PackedScene = preload("res://scenes/world/OreChunk.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/world/BlueprintCrate.tscn")
## Höchster Drall herausspringender Brocken pro Achse in rad/s.
const CHUNK_MAX_SPIN: float = 8.0
const SPAWN_ORIGIN: Vector3 = Vector3(0, 0, 4)
const SPAWN_SPACING: float = 1.5

@onready var _players: Node3D = $Players
@onready var _chunks: Node3D = $Chunks
@onready var _menu: MainMenu = $UI/MainMenu
@onready var _help: Label = $UI/Help
@onready var _hud: HUD = $UI/HUD
@onready var _pause_menu: PauseMenu = $UI/PauseMenu
@onready var _build_manager: BuildManager = $BuildManager
@onready var _wave_spawner: WaveSpawner = $WaveSpawner
@onready var _shop_manager: ShopManager = $ShopManager
@onready var _reroll_station: InteractableComponent = $World/ShopTerminal/InteractableComponent
@onready var _navigation: NavigationBaker = $World/NavigationRegion3D
@onready var _network_status: Label = $UI/NetworkStatus


func _ready() -> void:
	print("Deep Defense gestartet – Godot %s" % Engine.get_version_info().string)
	_help.visible = false
	_hud.visible = false
	_players.child_entered_tree.connect(_on_player_added)
	for deposit: OreDeposit in get_tree().get_nodes_in_group(OreDeposit.GROUP):
		deposit.chunk_broken_off.connect(_on_chunk_broken_off)
	# Besiegte Erzdiebe lassen ihre Beute fallen; gespawnt wird wie bei abgebauten Brocken.
	_wave_spawner.ore_dropped.connect(_on_chunk_broken_off)
	_wave_spawner.preview_changed.connect(_hud.set_wave_preview)
	# Shop: Angebote stehen als Kisten auf den Stellplätzen; die Würfel-Station ersetzt sie gegen Geld.
	_shop_manager.offer_crate_requested.connect(_spawn_offer_crate)
	_shop_manager.reroll_cost_changed.connect(_on_reroll_cost_changed)
	_reroll_station.hold_completed.connect(_shop_manager.reroll)
	_build_manager.crate_requested.connect(_spawn_crate)
	_network_status.visible = false
	_menu.host_requested.connect(_on_host_requested)
	_menu.join_requested.connect(_on_join_requested)
	_menu.quit_requested.connect(get_tree().quit)
	_pause_menu.leave_requested.connect(_return_to_menu)
	_pause_menu.quit_requested.connect(get_tree().quit)
	Economy.money_changed.connect(_hud.set_money)
	# Nach dem Bauen weichen Gegner neuen Mauern aus; das Netz braucht nur der Host.
	_build_manager.layout_changed.connect(_navigation.request_bake)
	var elevator := get_tree().get_first_node_in_group(Elevator.GROUP) as Elevator
	elevator.health.health_changed.connect(_hud.set_elevator_health)
	_hud.set_elevator_health(elevator.health.current_health, elevator.health.max_health)
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
	# Esc öffnet bzw. schließt im Spiel das Pausenmenü; im Startmenü passiert nichts.
	if event.is_action_pressed("menu") and not _menu.visible:
		_pause_menu.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ready") and not _menu.visible and not GameState.input_blocked:
		RunManager.request_toggle_ready()
		get_viewport().set_input_as_handled()


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
	RunManager.start_run()


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
	_return_to_menu()


## Verbindung trennen und Szene neu laden; das ist der einfachste saubere Zustand, das Menü erscheint wieder.
## Verlässt der Host das Spiel, landen alle Clients über server_disconnected ebenfalls hier.
func _return_to_menu() -> void:
	NetworkManager.leave_game()
	GameState.input_blocked = false
	Economy.reset()
	RunManager.reset()
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
		player.health_changed.connect(_hud.set_player_health)
		player.downed_changed.connect(_hud.set_downed)
		player.build_mode_changed.connect(_hud.set_build_mode)
		player.build_selection_changed.connect(_hud.set_build_selection)
		player.hold_progress_changed.connect(_hud.set_hold_progress)
		player.carried_offer_changed.connect(_hud.set_carried_offer)


## Nur auf dem Host: Brocken spawnen, der ChunkSpawner repliziert sie zu den Clients.
func _on_chunk_broken_off(ore: OreData, spawn_position: Vector3, impulse: Vector3) -> void:
	var chunk := CHUNK_SCENE.instantiate() as OreChunk
	chunk.ore_path = ore.resource_path
	chunk.position = spawn_position
	chunk.sync_position = spawn_position
	_chunks.add_child(chunk, true)
	chunk.apply_central_impulse(impulse * chunk.mass)
	# Zufälliger Drall, damit die Brocken unterschiedlich trudeln und landen.
	var rng := GameState.rng
	chunk.angular_velocity = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * CHUNK_MAX_SPIN


## Nur auf dem Host: Blaupausen-Kiste spawnen (abgebautes Bauelement bzw. Shop-Angebot).
func _spawn_crate(buildable: BuildableData, at: Vector3, state: Dictionary = {}, carrier_peer: int = 0, offer: bool = false) -> void:
	var crate := CRATE_SCENE.instantiate() as BlueprintCrate
	crate.buildable_path = buildable.resource_path
	crate.is_offer = offer
	crate.stored_state = state
	crate.carrier_id = carrier_peer
	crate.position = at
	crate.sync_position = at
	_chunks.add_child(crate, true)


func _spawn_offer_crate(buildable: BuildableData, at: Vector3) -> void:
	_spawn_crate(buildable, at, {}, 0, true)


func _on_reroll_cost_changed(cost: int) -> void:
	_reroll_station.hold_prompt = "Angebote neu würfeln (%d $)" % cost


func _on_player_left(peer_id: int) -> void:
	var player := _players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
