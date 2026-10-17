class_name ModelTint
extends RefCounted
## Färbt ein Modell ein, auch importierte wie die Kenney-GLBs: Jede Fläche bekommt eine eigene Kopie ihres Materials,
## deren Grundfarbe mit der Tönung multipliziert wird. Texturen bleiben erhalten (Kenney-Modelle sind weiß mit
## Farbtextur, dort ergibt die Tönung direkt die Farbe). Andere Instanzen desselben Modells bleiben unberührt.

var _materials: Array[BaseMaterial3D] = []
var _base_colors: Array[Color] = []


func _init(root: Node) -> void:
	for mesh_instance in mesh_instances(root):
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(surface) as BaseMaterial3D
			var material: BaseMaterial3D = source.duplicate() as BaseMaterial3D if source else StandardMaterial3D.new()
			mesh_instance.set_surface_override_material(surface, material)
			_materials.append(material)
			_base_colors.append(material.albedo_color)


## Tönung setzen (Weiß = Originalfarben). Die Deckkraft bleibt die des Originals.
func set_tint(tint: Color) -> void:
	for i in _materials.size():
		var color := _base_colors[i] * tint
		color.a = _base_colors[i].a
		_materials[i].albedo_color = color


## Alle MeshInstance3D unter root (root eingeschlossen).
static func mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		result.append(root as MeshInstance3D)
	for child in root.get_children():
		result.append_array(mesh_instances(child))
	return result
