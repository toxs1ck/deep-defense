class_name CaveModule
extends Node3D
## Baustein der Mine aus Kenneys Cave Kit (assets/kenney-cave-kit, CC0). Unter „Kit“ liegen die Modelle, doppelt so
## groß wie im Kit: Ein Rasterfeld ist dort 4 m, hier 8 m, damit Gänge zu Spielfigur und Gegnern passen.
## Dazu kommen Marker wie Erzstellen (ore_spawn_points), Gegner-Eingänge (enemy_spawns) und Lichter.
## Ausgänge liegen als Marker3D unter „Exits“ auf der Modulkante, −Z zeigt aus dem Modul hinaus. Daran setzt später
## der Kartengenerator die Module zusammen; in einer handgebauten Karte müssen sich die Ausgänge genau treffen.
## Die Kit-Modelle haben keine Kollision. Das Modul erzeugt sie beim Laden aus den Meshes (Welt-Layer 1), damit
## Spieler, Gegner, Kamera und das Navigationsnetz sie sehen.

## Kantenlänge eines Rasterfelds in Metern.
const CELL_SIZE: float = 8.0

## Größe in Rasterfeldern (für den Generator).
@export var footprint: Vector2i = Vector2i.ONE


func _ready() -> void:
	_build_collision()


## Ausgänge des Moduls; −Z jedes Markers zeigt nach außen.
func get_exits() -> Array[Marker3D]:
	var exits: Array[Marker3D] = []
	var parent := get_node_or_null(^"Exits")
	if parent:
		for child in parent.get_children():
			if child is Marker3D:
				exits.append(child as Marker3D)
	return exits


func _build_collision() -> void:
	var kit := get_node_or_null(^"Kit")
	if kit == null:
		return
	var body := StaticBody3D.new()
	body.name = "KitCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var to_local := global_transform.affine_inverse()
	for mesh_instance in _mesh_instances(kit):
		# Skalierung in die Dreiecke übernehmen, die Form selbst bleibt unskaliert (verträgt die Physik besser).
		var relative := to_local * mesh_instance.global_transform
		var scale_basis := Basis.from_scale(relative.basis.get_scale())
		var faces := mesh_instance.mesh.get_faces()
		for i in faces.size():
			faces[i] = scale_basis * faces[i]
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = Transform3D(relative.basis.orthonormalized(), relative.origin)
		body.add_child(collision)


func _mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		result.append_array(_mesh_instances(child))
	return result
