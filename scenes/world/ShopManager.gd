class_name ShopManager
extends Node
## Bauelemente-Shop wie in PlateUp: Zu Beginn jeder Bauphase stehen 4 zufällige Angebote (RunData.shop_pool) als
## Kisten auf den Stellplätzen (Gruppe „shop_pads“). Gekauft wird an der Kiste selbst (R halten, BlueprintCrate),
## nicht gekaufte Angebote verschwinden, wenn die Kampfphase beginnt. An der Würfel-Station ersetzt E halten alle
## übrigen Angebote, für steigende Kosten (GDD: 20 $, jedes weitere Mal +10 $). Entscheidungen trifft der Host.
## Zufall aus dem Seed-Strom „shop“ der Schicht: Gleicher Seed, gleiche Angebote, auch nach gleich vielen Rerolls.

## Nur Host: Angebots-Kiste auf einem Stellplatz spawnen (Main spawnt sie mit is_offer).
signal offer_crate_requested(buildable: BuildableData, at: Vector3)
## Auf allen Peers: neue Kosten fürs Neu-Würfeln (für die Anzeige an der Station).
signal reroll_cost_changed(cost: int)

const PAD_GROUP: StringName = &"shop_pads"
## Die Kiste erscheint etwas über dem Stellplatz und fällt darauf.
const SPAWN_HEIGHT: float = 0.6

var reroll_cost: int = 0
## Nur Host: Zufallsstrom der laufenden Bauphase.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	RunManager.phase_changed.connect(_on_phase_changed)
	NetworkManager.player_joined.connect(_on_player_joined)


## Nur Host: von der Würfel-Station nach dem Halten aufgerufen.
func reroll(_player: Player) -> void:
	if not multiplayer.is_server() or RunManager.phase != RunManager.Phase.BUILD:
		return
	if not Economy.try_spend(reroll_cost):
		return
	_set_reroll_cost.rpc(reroll_cost + RunManager.data.reroll_cost_step)
	_roll()


func _on_phase_changed(phase: int) -> void:
	if not multiplayer.is_server():
		return
	if phase == RunManager.Phase.BUILD:
		_set_reroll_cost.rpc(RunManager.data.reroll_base_cost)
		_rng = GameState.stream_rng(&"shop", RunManager.current_round)
		_roll()
	else:
		# Der Shop schließt, sobald die Welle startet: übrige Angebote verschwinden, auch getragene.
		_clear_offers()


func _roll() -> void:
	_clear_offers()
	var pool := RunManager.data.shop_pool
	var pads := get_tree().get_nodes_in_group(PAD_GROUP)
	for i in mini(RunManager.data.shop_offer_count, pads.size()):
		var pad := pads[i] as Node3D
		var offer := pool[_rng.randi_range(0, pool.size() - 1)]
		offer_crate_requested.emit(offer, pad.global_position + Vector3.UP * SPAWN_HEIGHT)


func _clear_offers() -> void:
	for crate in get_tree().get_nodes_in_group(BlueprintCrate.OFFER_GROUP):
		crate.queue_free()


func _on_player_joined(peer_id: int) -> void:
	if multiplayer.is_server() and peer_id != multiplayer.get_unique_id():
		_set_reroll_cost.rpc_id(peer_id, reroll_cost)


@rpc("authority", "call_local", "reliable")
func _set_reroll_cost(cost: int) -> void:
	reroll_cost = cost
	reroll_cost_changed.emit(cost)
