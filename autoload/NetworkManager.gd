extends Node
## Host/Join über ENet und Spieler-Verwaltung. Später wird hier GodotSteam (Lobbys, P2P-Relay) angebunden.
## Der Host ist Server und selbst Spieler 1. Nur auf dem Host werden player_joined und player_left gesendet,
## denn nur der Host spawnt und entfernt Spielfiguren.

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
## Client: Verbindung zum Host steht.
signal connection_succeeded
## Client: Host nicht erreichbar.
signal connection_failed
## Client: Host hat das Spiel beendet oder die Verbindung ist abgerissen.
signal server_disconnected

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	# Der Host zählt selbst als Spieler, daher ein Client-Platz weniger.
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	print("[Netzwerk] Host gestartet auf Port %d" % port)
	player_joined.emit(multiplayer.get_unique_id())
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	print("[Netzwerk] Verbinde mit %s:%d …" % [address, port])
	return OK


## Darf mehrfach aufgerufen werden; ohne aktive Verbindung passiert nichts.
func leave_game() -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _on_peer_connected(peer_id: int) -> void:
	print("[Netzwerk] Peer verbunden: %d" % peer_id)
	if multiplayer.is_server():
		player_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("[Netzwerk] Peer getrennt: %d" % peer_id)
	if multiplayer.is_server():
		player_left.emit(peer_id)


func _on_connected_to_server() -> void:
	print("[Netzwerk] Mit Host verbunden, eigene ID: %d" % multiplayer.get_unique_id())
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	print("[Netzwerk] Verbindung fehlgeschlagen")
	leave_game()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	print("[Netzwerk] Verbindung zum Host verloren")
	leave_game()
	server_disconnected.emit()
