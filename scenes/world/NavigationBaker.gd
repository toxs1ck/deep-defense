class_name NavigationBaker
extends NavigationRegion3D
## Backt das Navigationsnetz beim Laden aus allen Knoten der Gruppe navigation_mesh.geometry_source_group_name.
## Die Geometrie wird selbst gesammelt, und zwar aus Kollisionen auf den Ebenen navigation_mesh.geometry_collision_mask
## (Welt und Bauelemente):
## - CSG-Formen über bake_collision_shape() (Godots eigener Parser liest CSG über die GPU aus, das bremst),
## - Kollisionsformen von StaticBody3D über CPU-seitig erzeugte Mesh-Daten.
## Zellhöhe 0,1 m (genauso im Projekt unter navigation/3d/default_cell_height), damit das Netz auf Rampen und
## Treppen dicht am echten Boden liegt.
## Zwei Gruppen steuern das Backen:
## - „navigation_ignore“: Knoten samt Kindern wird übersprungen (z. B. Deko, die Gegner nicht beachten sollen),
## - „navigation_blocker“: Kollisionsform zählt als Hindernis, egal auf welcher Physik-Ebene (auch Ebene 0,
##   also ohne Wirkung auf die Spielphysik).
## Nach dem Bauen ruft der BuildManager (über Main) request_bake() auf. Neu gebacken wird im Hintergrund;
## kommen währenddessen weitere Änderungen, folgt danach genau ein weiterer Durchgang.

const IGNORE_GROUP: StringName = &"navigation_ignore"
const BLOCKER_GROUP: StringName = &"navigation_blocker"


var _baking: bool = false
var _dirty: bool = false


func _ready() -> void:
	# CSG-Formen bauen ihre Geometrie erst verzögert auf; einen Frame warten, sonst ist das Netz leer.
	await get_tree().process_frame
	request_bake()


func request_bake() -> void:
	if _baking:
		_dirty = true
		return
	_baking = true
	_dirty = false
	var source := NavigationMeshSourceGeometryData3D.new()
	for root in get_tree().get_nodes_in_group(navigation_mesh.geometry_source_group_name):
		_collect(root, source)
	# Eine Kopie backen und zuweisen, damit die Region das neue Netz sicher übernimmt.
	var baked := navigation_mesh.duplicate() as NavigationMesh
	NavigationServer3D.bake_from_source_geometry_data_async(baked, source, _on_bake_finished.bind(baked))


func _on_bake_finished(baked: NavigationMesh) -> void:
	navigation_mesh = baked
	_baking = false
	if _dirty:
		request_bake()


func _collect(node: Node, source: NavigationMeshSourceGeometryData3D) -> void:
	if node.is_in_group(IGNORE_GROUP):
		return
	var mask := navigation_mesh.geometry_collision_mask
	if node is CollisionShape3D and node.is_in_group(BLOCKER_GROUP):
		var blocker := node as CollisionShape3D
		_add_shape(blocker.shape, blocker.global_transform, source)
	elif node is CSGShape3D:
		var csg := node as CSGShape3D
		if csg.is_root_shape() and csg.use_collision and (csg.collision_layer & mask) != 0:
			var shape := csg.bake_collision_shape()
			if shape:
				source.add_faces(shape.get_faces(), csg.global_transform)
	elif node is CollisionShape3D:
		var collision := node as CollisionShape3D
		var body := collision.get_parent() as StaticBody3D
		if body and not collision.disabled and (body.collision_layer & mask) != 0:
			_add_shape(collision.shape, collision.global_transform, source)
	for child in node.get_children():
		_collect(child, source)


func _add_shape(shape: Shape3D, xform: Transform3D, source: NavigationMeshSourceGeometryData3D) -> void:
	var mesh: PrimitiveMesh = null
	if shape is BoxShape3D:
		var box := BoxMesh.new()
		box.size = (shape as BoxShape3D).size
		mesh = box
	elif shape is SphereShape3D:
		var sphere := SphereMesh.new()
		sphere.radius = (shape as SphereShape3D).radius
		sphere.height = sphere.radius * 2.0
		mesh = sphere
	elif shape is CylinderShape3D:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = (shape as CylinderShape3D).radius
		cylinder.bottom_radius = cylinder.top_radius
		cylinder.height = (shape as CylinderShape3D).height
		mesh = cylinder
	elif shape is ConcavePolygonShape3D:
		source.add_faces((shape as ConcavePolygonShape3D).get_faces(), xform)
		return
	else:
		push_warning("NavigationBaker: Form %s wird nicht unterstützt" % shape.get_class())
		return
	# get_mesh_arrays() erzeugt die Daten auf der CPU, ohne Umweg über die GPU.
	source.add_mesh_array(mesh.get_mesh_arrays(), xform)
