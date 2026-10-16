class_name CarryComponent
extends Node3D
## Hält getragene Erzbrocken vor der Spielfigur. Der Knoten selbst ist der Haltepunkt.
## Wer was trägt, steht in OreChunk.carrier_id (vom Host gesetzt, an alle verteilt); die Brocken melden sich hier
## an und ab. So kennt jeder Peer die Liste, und der Besitzer kann sein Tempo lokal berechnen.
## Ablegen und Werfen fragt der Besitzer beim Host an.

signal carried_changed(is_carrying: bool)

## Abstand nach oben zwischen gestapelten Brocken (z. B. zwei Kohlen).
const STACK_SPACING: float = 0.35
## Wo abgelegte Brocken relativ zum Haltepunkt landen: etwas tiefer, damit sie nicht in Kopfhöhe fallen.
const DROP_OFFSET: Vector3 = Vector3(0, -0.4, 0)

var carried: Array[OreChunk] = []


func is_carrying() -> bool:
	return not carried.is_empty()


## Nur gleiche Erzart wird gestapelt, und nur bis zu deren Traglimit.
func can_pick_up(chunk: OreChunk) -> bool:
	if carried.is_empty():
		return true
	return carried[0].ore == chunk.ore and carried.size() < chunk.ore.carry_limit


func get_speed_multiplier() -> float:
	var multiplier := 1.0
	for chunk in carried:
		multiplier = minf(multiplier, chunk.ore.carry_speed_multiplier)
	return multiplier


func get_hold_transform(chunk: OreChunk) -> Transform3D:
	var index := maxi(0, carried.find(chunk))
	return global_transform.translated(Vector3.UP * STACK_SPACING * index)


## Von OreChunk aufgerufen, wenn sich dessen carrier_id auf diesen Spieler ändert.
func register(chunk: OreChunk) -> void:
	if chunk in carried:
		return
	carried.append(chunk)
	if carried.size() == 1:
		carried_changed.emit(true)


func unregister(chunk: OreChunk) -> void:
	if not chunk in carried:
		return
	carried.erase(chunk)
	if carried.is_empty():
		carried_changed.emit(false)


## Vom Besitzer aufgerufen. Ohne Richtung wird abgelegt, mit Richtung geworfen.
func request_drop(throw_direction: Vector3 = Vector3.ZERO) -> void:
	_drop_on_host.rpc_id(1, throw_direction)


@rpc("any_peer", "call_local", "reliable")
func _drop_on_host(throw_direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if sender != get_multiplayer_authority():
		return
	var player := owner as Player
	var velocity := Vector3.ZERO
	if throw_direction != Vector3.ZERO and player:
		velocity = throw_direction.normalized() * player.data.throw_speed
	_release_all(velocity)


## Nur Host: alles an Ort und Stelle fallen lassen, z. B. wenn der Spieler fällt.
func drop_all() -> void:
	if multiplayer.is_server():
		_release_all(Vector3.ZERO)


## Läuft auf dem Host, wenn ein Spieler das Spiel verlässt: Was er trägt, fällt an Ort und Stelle herunter.
func _exit_tree() -> void:
	# Offline heißt: Szene wird gerade abgebaut (z. B. zurück ins Menü), dann gibt es nichts zu retten.
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer or not multiplayer.is_server():
		return
	_release_all(Vector3.ZERO)


func _release_all(velocity: Vector3) -> void:
	var drop_at := global_position + DROP_OFFSET
	for chunk: OreChunk in carried.duplicate():
		if is_instance_valid(chunk) and not chunk.is_queued_for_deletion():
			chunk.release(drop_at, velocity)
		drop_at += Vector3.UP * STACK_SPACING
