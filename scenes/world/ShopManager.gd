class_name ShopManager
extends Node
## Bauelemente-Shop (GDD, „Shop-Regeln“): Jede Schicht 4 zufällige Angebote aus RunData.shop_pool, bezahlt aus der
## Teamkasse, neu würfeln für steigende Kosten. Offen nur in der Bauphase. Gekauftes erscheint als Blaupausen-Kiste
## am Aufzug (Main spawnt sie auf crate_requested). Entscheidungen trifft der Host, Clients sehen den Stand per RPC.

## Auf allen Peers: neuer Stand der Angebote.
signal offers_changed(offers: Array[BuildableData], sold: Array[bool], reroll_cost: int)
## Nur beim Spieler, der das Shop-Terminal benutzt hat.
signal open_requested
## Nur Host: Kiste für ein gekauftes Bauelement spawnen.
signal crate_requested(buildable: BuildableData, at: Vector3)

var offers: Array[BuildableData] = []
var sold: Array[bool] = []
var reroll_cost: int = 0


func _ready() -> void:
	RunManager.round_started.connect(_on_round_started)
	NetworkManager.player_joined.connect(_on_player_joined)


func is_open() -> bool:
	return RunManager.phase == RunManager.Phase.BUILD


## Nur Host: vom Shop-Terminal aufgerufen, öffnet das Menü beim benutzenden Spieler.
func open_for(player: Player) -> void:
	if multiplayer.is_server():
		_open.rpc_id(player.get_multiplayer_authority())


func request_buy(index: int) -> void:
	_buy_on_host.rpc_id(1, index)


func request_reroll() -> void:
	_reroll_on_host.rpc_id(1)


func _on_round_started(_round_number: int) -> void:
	if multiplayer.is_server():
		reroll_cost = RunManager.data.reroll_base_cost
		_roll()


func _roll() -> void:
	var run := RunManager.data
	offers.clear()
	sold.clear()
	for i in run.shop_offer_count:
		offers.append(run.shop_pool[GameState.rng.randi_range(0, run.shop_pool.size() - 1)])
		sold.append(false)
	_broadcast()


@rpc("any_peer", "call_local", "reliable")
func _buy_on_host(index: int) -> void:
	if not multiplayer.is_server() or not is_open() or index < 0 or index >= offers.size() or sold[index]:
		return
	if not Economy.try_spend(offers[index].price):
		return
	sold[index] = true
	var elevator := get_tree().get_first_node_in_group(Elevator.GROUP) as Elevator
	crate_requested.emit(offers[index], elevator.get_crate_point())
	_broadcast()


@rpc("any_peer", "call_local", "reliable")
func _reroll_on_host() -> void:
	if not multiplayer.is_server() or not is_open() or not Economy.try_spend(reroll_cost):
		return
	reroll_cost += RunManager.data.reroll_cost_step
	_roll()


func _on_player_joined(peer_id: int) -> void:
	if multiplayer.is_server() and peer_id != multiplayer.get_unique_id() and not offers.is_empty():
		_sync.rpc_id(peer_id, _offer_paths(), _sold_flags(), reroll_cost)


func _broadcast() -> void:
	_sync.rpc(_offer_paths(), _sold_flags(), reroll_cost)


func _offer_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for offer in offers:
		paths.append(offer.resource_path)
	return paths


func _sold_flags() -> PackedInt32Array:
	var flags := PackedInt32Array()
	for flag in sold:
		flags.append(1 if flag else 0)
	return flags


@rpc("authority", "call_local", "reliable")
func _sync(paths: PackedStringArray, sold_flags: PackedInt32Array, cost: int) -> void:
	offers.clear()
	sold.clear()
	for i in paths.size():
		offers.append(load(paths[i]) as BuildableData)
		sold.append(sold_flags[i] != 0)
	reroll_cost = cost
	offers_changed.emit(offers, sold, reroll_cost)


@rpc("authority", "call_local", "reliable")
func _open() -> void:
	open_requested.emit()
