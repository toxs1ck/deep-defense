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
## Kleine Steine auf dem Kit-Boden bekommen keine Kollision, sonst bleiben Gegner daran hängen: Dreiecke des Kit-Teils,
## die ganz unter dieser Höhe liegen und nicht zum flachen Boden gehören, fallen weg (gilt nicht für Deko).
const FLOOR_DETAIL_HEIGHT: float = 0.7
const FLOOR_HEIGHT: float = 0.05

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
	var inverse := global_transform.affine_inverse()
	var piece := kit.get_node_or_null(^"Model")
	for mesh_instance in ModelTint.mesh_instances(kit):
		# Skalierung in die Dreiecke übernehmen, die Form selbst bleibt unskaliert (verträgt die Physik besser).
		var relative := inverse * mesh_instance.global_transform
		var scale_basis := Basis.from_scale(relative.basis.get_scale())
		var faces := mesh_instance.mesh.get_faces()
		for i in faces.size():
			faces[i] = scale_basis * faces[i]
		if piece and (piece == mesh_instance or piece.is_ancestor_of(mesh_instance)):
			faces = _without_floor_detail(faces, relative.origin.y)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = Transform3D(relative.basis.orthonormalized(), relative.origin)
		body.add_child(collision)


## Entfernt Dreiecke, die komplett knapp über dem Boden liegen, außer dem flachen Boden selbst.
## Die Flächen sind schon skaliert, aber noch nicht gedreht; Drehungen der Kit-Teile gehen nur um die Hochachse.
func _without_floor_detail(faces: PackedVector3Array, base_height: float) -> PackedVector3Array:
	var kept := PackedVector3Array()
	for i in range(0, faces.size() - 2, 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		var top := maxf(a.y, maxf(b.y, c.y)) + base_height
		var flat_floor := top < FLOOR_HEIGHT
		if top < FLOOR_DETAIL_HEIGHT and not flat_floor:
			continue
		kept.append(a)
		kept.append(b)
		kept.append(c)
	return kept
