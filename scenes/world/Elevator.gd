class_name Elevator
extends Node3D
## Aufzug, Kern der Mine. Erz kommt in den Korb: getragen per E („Erz einladen“) oder geworfen/abgelegt.
## Der Host führt die Ladung (begrenzt auf data.capacity) und zahlt sie zu Beginn jeder Schicht
## (RunManager.round_started) in die Teamkasse aus. Fällt seine Lebenspunkte auf 0, ist der Run verloren.

const GROUP: StringName = &"elevator"
## Hier erscheinen gefallene Spieler wieder: vor der offenen Seite des Korbs (lokal).
const RESPAWN_POINT: Vector3 = Vector3(0, 0, -3.0)
## Hier erscheinen gekaufte Blaupausen-Kisten: links vor dem Korb (lokal), leicht gestreut.
const CRATE_POINT: Vector3 = Vector3(-2.4, 0.6, -2.2)
const CRATE_SCATTER: float = 0.6

@export var data: ElevatorData

@onready var health: HealthComponent = $HealthComponent
@onready var _basket: Area3D = $Basket
@onready var _load_interactable: InteractableComponent = $LoadInteractable
@onready var _load_label: Label3D = $LoadLabel

## Nur Host: die geladenen Erzarten, ein Eintrag pro Brocken.
var _cargo: Array[OreData] = []
## Auf allen Peers für die Anzeige.
var _item_count: int = 0
var _cargo_value: int = 0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	assert(data != null, "Elevator braucht eine ElevatorData-Resource")
	health.setup(data.max_health)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_basket.monitoring = multiplayer.is_server()
	_basket.body_entered.connect(_on_basket_body_entered)
	_load_interactable.interacted.connect(_on_load_interacted)
	RunManager.round_started.connect(_on_round_started)
	NetworkManager.player_joined.connect(_on_player_joined)
	_update_label()


## Nur Host: Ladung auszahlen und Korb leeren. Gibt den ausgezahlten Betrag zurück.
func pay_out() -> int:
	if _cargo.is_empty():
		return 0
	var total := float(_cargo_value)
	if _qualifies_for_bonus():
		total *= 1.0 + data.load_bonus
	var amount := roundi(total)
	Economy.add_money(amount)
	_cargo.clear()
	_broadcast_cargo()
	return amount


## Kurzes rotes Aufblitzen der Anzeige, wenn der Aufzug Schaden nimmt.
func _on_health_changed(current: int, maximum: int) -> void:
	_update_label()
	if current < maximum:
		_load_label.modulate = Color(1, 0.3, 0.3)
		create_tween().tween_property(_load_label, "modulate", Color.WHITE, 0.3)


func _on_died() -> void:
	if multiplayer.is_server():
		RunManager.fail_run()


func get_crate_point() -> Vector3:
	var rng := GameState.rng
	return to_global(CRATE_POINT + Vector3(rng.randf_range(-CRATE_SCATTER, CRATE_SCATTER), 0, rng.randf_range(-CRATE_SCATTER, CRATE_SCATTER)))


func get_respawn_point() -> Vector3:
	return to_global(RESPAWN_POINT)


## Schichtbeginn: Der Aufzug fährt hoch und zahlt aus (GDD, „Ablauf einer Schicht“).
func _on_round_started(_round_number: int) -> void:
	if multiplayer.is_server():
		pay_out()


func is_full() -> bool:
	return _item_count >= data.capacity


func _qualifies_for_bonus() -> bool:
	if _cargo.size() >= data.capacity:
		return true
	var ore_types := {}
	for ore in _cargo:
		ore_types[ore] = true
	return ore_types.size() >= data.mixed_ore_types_for_bonus


## Nur Host: geworfene oder abgelegte Brocken, die im Korb landen.
func _on_basket_body_entered(body: Node3D) -> void:
	var chunk := body as OreChunk
	if chunk and chunk.carrier_id == 0:
		_try_load(chunk)


## Nur Host: alles einladen, was der Spieler trägt, solange Platz ist.
func _on_load_interacted(player: Player) -> void:
	for item: Carryable in player.carry.carried.duplicate():
		var chunk := item as OreChunk
		if chunk and not _try_load(chunk):
			break


func _try_load(chunk: OreChunk) -> bool:
	if not multiplayer.is_server() or chunk.is_queued_for_deletion() or _cargo.size() >= data.capacity:
		return false
	_cargo.append(chunk.ore)
	# Der ChunkSpawner entfernt den Brocken auch bei den Clients.
	chunk.queue_free()
	_broadcast_cargo()
	return true


func _broadcast_cargo() -> void:
	var value := 0
	for ore in _cargo:
		value += ore.value
	_sync_cargo.rpc(_cargo.size(), value)


func _on_player_joined(peer_id: int) -> void:
	if multiplayer.is_server() and peer_id != multiplayer.get_unique_id():
		_sync_cargo.rpc_id(peer_id, _item_count, _cargo_value)


@rpc("authority", "call_local", "reliable")
func _sync_cargo(item_count: int, value: int) -> void:
	_item_count = item_count
	_cargo_value = value
	_update_label()


func _update_label() -> void:
	var full_note := "\nVOLL" if is_full() else ""
	_load_label.text = "Aufzug · %d/%d LP\nLadung: %d/%d · %d $%s" % [
		health.current_health, health.max_health, _item_count, data.capacity, _cargo_value, full_note]
