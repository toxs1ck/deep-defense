class_name BuildManager
extends Node
## Raster und Platzierung der Bauelemente (GDD: 2-m-Zellen). can_place() läuft auf jedem Peer, damit die
## Vorschau sofort grün oder rot zeigt; platziert und entfernt wird nur auf dem Host, der dabei erneut prüft.
## Nach jeder Änderung meldet layout_changed, dass die Navigation neu gebacken werden muss.

## Nur auf dem Host: Bauelemente wurden hinzugefügt oder entfernt.
signal layout_changed

const GROUP: StringName = &"build_manager"
const CELL_SIZE: float = 2.0
## Was einen Platz belegt: Welt, Spieler, Gegner, Bauelemente, Erzbrocken.
const BLOCKING_MASK: int = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4)
## Etwas kleiner prüfen als das Bauelement, damit Nachbarn auf dem Raster sich nicht gegenseitig blockieren.
const OVERLAP_SHRINK: float = 0.9
## Boden wird von so weit über dem Zielpunkt nach unten gesucht.
const FLOOR_PROBE_HEIGHT: float = 3.0
const FLOOR_PROBE_DEPTH: float = 6.0
## Maximale Entfernung zwischen Spieler und Bauplatz (Host-Prüfung, mit Spielraum).
const MAX_BUILD_DISTANCE: float = 12.0

## Container, unter den Bauelemente kommen; der BuildableSpawner repliziert ihn.
@export var buildables: Node3D


func _enter_tree() -> void:
	add_to_group(GROUP)


func world_to_cell(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / CELL_SIZE), roundi(point.z / CELL_SIZE))


## Ergebnis: { "ok": bool, "position": Vector3 } mit Bodenhöhe an der Zelle.
func can_place(data: BuildableData, cell: Vector2i, rotation_steps: int, near: Vector3) -> Dictionary:
	var result := { "ok": false, "position": Vector3.ZERO }
	var space := get_viewport().get_world_3d().direct_space_state
	var center := Vector3(cell.x * CELL_SIZE, near.y, cell.y * CELL_SIZE)

	var probe := PhysicsRayQueryParameters3D.create(center + Vector3.UP * FLOOR_PROBE_HEIGHT,
			center + Vector3.DOWN * FLOOR_PROBE_DEPTH, 1 << 0)
	var floor_hit := space.intersect_ray(probe)
	if floor_hit.is_empty():
		return result
	var floor_position: Vector3 = floor_hit["position"]
	center.y = floor_position.y
	result["position"] = center

	var shape := BoxShape3D.new()
	shape.size = data.size * OVERLAP_SHRINK
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = BLOCKING_MASK
	query.transform = Transform3D(Basis(Vector3.UP, rotation_steps * PI / 2.0), center + Vector3.UP * data.size.y / 2.0)
	result["ok"] = space.intersect_shape(query, 1).is_empty()
	return result


## Vom lokalen Spieler.
func request_place(data: BuildableData, cell: Vector2i, rotation_steps: int) -> void:
	_place_on_host.rpc_id(1, data.resource_path, cell, rotation_steps)


## Vom lokalen Spieler: das getroffene Bauelement entfernen.
func request_remove(buildable: Buildable) -> void:
	_remove_on_host.rpc_id(1, String(buildable.name))


@rpc("any_peer", "call_local", "reliable")
func _place_on_host(data_path: String, cell: Vector2i, rotation_steps: int) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	var data := load(data_path) as BuildableData
	if player == null or player.is_downed() or data == null:
		return
	var check := can_place(data, cell, posmod(rotation_steps, 4), player.global_position)
	var position: Vector3 = check["position"]
	if not check["ok"] or position.distance_to(player.global_position) > MAX_BUILD_DISTANCE:
		return
	var buildable := data.scene.instantiate() as Buildable
	buildable.data_path = data.resource_path
	buildable.sync_position = position
	buildable.rotation_steps = posmod(rotation_steps, 4)
	buildables.add_child(buildable, true)
	layout_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func _remove_on_host(buildable_name: String) -> void:
	if not multiplayer.is_server():
		return
	var player := _sender_player()
	var buildable := buildables.get_node_or_null(buildable_name) as Buildable
	if player == null or buildable == null:
		return
	if buildable.global_position.distance_to(player.global_position) > MAX_BUILD_DISTANCE:
		return
	destroy(buildable)


## Nur Host: Bauelement entfernen, z. B. wenn Gegner es zerstört haben.
func destroy(buildable: Buildable) -> void:
	if not multiplayer.is_server() or buildable.get_parent() != buildables:
		return
	# Erst aus dem Baum nehmen, damit das Neu-Backen das Bauelement schon nicht mehr sieht.
	buildables.remove_child(buildable)
	buildable.queue_free()
	layout_changed.emit()


func _sender_player() -> Player:
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		if node.name == str(peer_id):
			return node as Player
	return null
