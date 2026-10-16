extends NavigationRegion3D
## Backt das Navigationsnetz beim Laden aus allen Knoten der Gruppe navigation_mesh.geometry_source_group_name.
## Die Geometrie wird selbst gesammelt, und zwar aus Kollisionen auf den Ebenen navigation_mesh.geometry_collision_mask:
## - CSG-Formen über bake_collision_shape() (Godots eigener Parser liest CSG über die GPU aus, das bremst),
## - Kollisionsformen von StaticBody3D über CPU-seitig erzeugte Mesh-Daten.
## Später (Aufgabe 11) wird nach dem Bauen neu gebacken.


func _ready() -> void:
	# CSG-Formen bauen ihre Geometrie erst verzögert auf; einen Frame warten, sonst ist das Netz leer.
	await get_tree().process_frame
	bake()


func bake() -> void:
	var source := NavigationMeshSourceGeometryData3D.new()
	for root in get_tree().get_nodes_in_group(navigation_mesh.geometry_source_group_name):
		_collect(root, source)
	# Eine Kopie backen und zuweisen, damit die Region das neue Netz sicher übernimmt.
	var baked := navigation_mesh.duplicate() as NavigationMesh
	NavigationServer3D.bake_from_source_geometry_data(baked, source)
	navigation_mesh = baked


func _collect(node: Node, source: NavigationMeshSourceGeometryData3D) -> void:
	var mask := navigation_mesh.geometry_collision_mask
	if node is CSGShape3D:
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
