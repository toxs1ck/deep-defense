extends Node
## Gemeinsame Teamkasse. Später auch Shop-Angebote und Reroll-Kosten (Aufgabe 14).
## Nur der Host ändert das Geld; Clients bekommen den Stand per RPC, später Beitretende direkt beim Beitritt.

signal money_changed(amount: int)

var team_money: int = 0


func _ready() -> void:
	NetworkManager.player_joined.connect(_on_player_joined)


## Nur Host.
func add_money(amount: int) -> void:
	assert(multiplayer.is_server(), "Geld ändert nur der Host")
	assert(amount >= 0, "add_money erwartet einen positiven Betrag")
	_set_money.rpc(team_money + amount)


func can_afford(cost: int) -> bool:
	return team_money >= cost


## Nur Host.
func try_spend(cost: int) -> bool:
	assert(multiplayer.is_server(), "Geld ändert nur der Host")
	if not can_afford(cost):
		return false
	_set_money.rpc(team_money - cost)
	return true


## Lokal zurücksetzen, z. B. beim Verlassen eines Spiels.
func reset() -> void:
	_set_money(0)


func _on_player_joined(peer_id: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		_set_money.rpc_id(peer_id, team_money)


@rpc("authority", "call_local", "reliable")
func _set_money(amount: int) -> void:
	team_money = amount
	money_changed.emit(team_money)
