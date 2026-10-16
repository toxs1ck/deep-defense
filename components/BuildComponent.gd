class_name BuildComponent
extends Node
## Baumodus des lokalen Spielers: Vorschau auf dem Raster (grün = frei, rot = belegt), drehen, platzieren, entfernen.
## Prüft lokal für die Vorschau; platziert wird über den BuildManager auf dem Host.

signal active_changed(is_active: bool)

## Bis wohin der Zielstrahl von der Kamera aus reicht.
const AIM_DISTANCE: float = 20.0
## Der Strahl trifft Welt und Bauelemente.
const AIM_MASK: int = (1 << 0) | (1 << 3)
const VALID_COLOR: Color = Color(0.3, 1.0, 0.4, 0.45)
const INVALID_COLOR: Color = Color(1.0, 0.25, 0.2, 0.45)

## Vorerst gibt es nur Mauern; mit dem Shop (Aufgabe 14) wird hier das gekaufte Element gewählt.
@export var selected: BuildableData = preload("res://data/buildables/wall.tres")

var active: bool = false
var _rotation_steps: int = 0
var _cell: Vector2i = Vector2i.ZERO
var _valid: bool = false
var _aimed_buildable: Buildable = null
var _ghost: MeshInstance3D = null
var _ghost_material: StandardMaterial3D = null


func set_active(value: bool) -> void:
	if value == active:
		return
	active = value
	if active:
		_create_ghost()
	elif _ghost:
		_ghost.queue_free()
		_ghost = null
	active_changed.emit(active)


func rotate_selection(steps: int) -> void:
	_rotation_steps = posmod(_rotation_steps + steps, 4)


## Jeden Physik-Tick vom Spieler aufgerufen: Ziel bestimmen und Vorschau aktualisieren.
func update_aim(view: Transform3D, player_position: Vector3) -> void:
	if not active:
		return
	var space := get_viewport().get_world_3d().direct_space_state
	var from := view.origin
	var to := from - view.basis.z * AIM_DISTANCE
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, AIM_MASK))
	_aimed_buildable = null
	if hit.is_empty():
		_valid = false
		_ghost.visible = false
		return
	_aimed_buildable = hit["collider"] as Buildable
	var hit_position: Vector3 = hit["position"]
	var manager := _manager()
	_cell = manager.world_to_cell(hit_position)
	var check := manager.can_place(selected, _cell, _rotation_steps, player_position)
	var position: Vector3 = check["position"]
	_valid = check["ok"] and position.distance_to(player_position) <= BuildManager.MAX_BUILD_DISTANCE
	_ghost.visible = true
	_ghost.global_transform = Transform3D(Basis(Vector3.UP, _rotation_steps * PI / 2.0), position + Vector3.UP * selected.size.y / 2.0)
	_ghost_material.albedo_color = VALID_COLOR if _valid else INVALID_COLOR


func try_place() -> void:
	if active and _valid:
		_manager().request_place(selected, _cell, _rotation_steps)


## Entfernt das anvisierte Bauelement (zum Testen; später gegen Erstattung oder gar nicht).
func try_remove() -> void:
	if active and is_instance_valid(_aimed_buildable):
		_manager().request_remove(_aimed_buildable)


func _create_ghost() -> void:
	var mesh := BoxMesh.new()
	mesh.size = selected.size
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost = MeshInstance3D.new()
	_ghost.mesh = mesh
	_ghost.material_override = _ghost_material
	_ghost.visible = false
	# Unabhängig von der Spielfigur positionieren.
	_ghost.top_level = true
	add_child(_ghost)


func _manager() -> BuildManager:
	return get_tree().get_first_node_in_group(BuildManager.GROUP) as BuildManager
