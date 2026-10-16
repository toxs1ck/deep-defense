class_name HealthComponent
extends Node
## Lebenspunkte. Nur der Host verursacht Schaden; der neue Stand geht per RPC an alle.
## Der RPC ist bewusst „any_peer“ mit eigener Absenderprüfung: Bei Spielfiguren gehört der Knoten dem Client,
## mit „authority“ dürfte der Host die Lebenspunkte dort gar nicht setzen.
## sync_on_join: für Objekte, die fest in der Szene stehen (z. B. Aufzug), bekommen später Beitretende den Stand.
## Gespawnte Objekte (Gegner) brauchen das nicht, sie sind ohnehin kurzlebig.

signal health_changed(current: int, maximum: int)
## Auf allen Peers, einmal beim Übergang auf 0.
signal died

@export var max_health: int = 100
@export var sync_on_join: bool = false

var current_health: int = 0


func _ready() -> void:
	current_health = max_health
	if sync_on_join:
		NetworkManager.player_joined.connect(_on_player_joined)


## Maximum setzen und voll heilen, z. B. aus einer Daten-Resource. Lokal auf jedem Peer aufrufen.
## current > 0 setzt einen anderen Startwert, z. B. für ein versetztes, beschädigtes Bauelement.
func setup(maximum: int, current: int = 0) -> void:
	max_health = maximum
	current_health = clampi(current, 1, maximum) if current > 0 else maximum
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return current_health <= 0


## Nur Host.
func damage(amount: int) -> void:
	if not multiplayer.is_server() or is_dead() or amount <= 0:
		return
	_set_health.rpc(maxi(0, current_health - amount))


## Nur Host: voll heilen, z. B. beim Respawn.
func revive() -> void:
	if multiplayer.is_server():
		_set_health.rpc(max_health)


func _on_player_joined(peer_id: int) -> void:
	if multiplayer.is_server() and peer_id != multiplayer.get_unique_id():
		_set_health.rpc_id(peer_id, current_health)


@rpc("any_peer", "call_local", "reliable")
func _set_health(value: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	var was_alive := current_health > 0
	current_health = value
	health_changed.emit(current_health, max_health)
	if was_alive and current_health <= 0:
		died.emit()
