class_name OreChunk
extends Carryable
## Erzbrocken. Tragen, Physik und Synchronisierung kommen aus Carryable.
## Wird vom ChunkSpawner unter „Chunks“ in Main repliziert.

const GROUP: StringName = &"ore_chunks"

## Pfad zur OreData-Resource; wird beim Spawnen mitgeschickt, damit Clients die Erzart kennen.
@export var ore_path: String = ""

var ore: OreData


func _enter_tree() -> void:
	add_to_group(GROUP)


func _setup_item() -> void:
	ore = load(ore_path) as OreData
	assert(ore != null, "OreChunk: ungültiger ore_path '%s'" % ore_path)
	var material := StandardMaterial3D.new()
	material.albedo_color = ore.color
	_mesh.material_override = material


func get_display_name() -> String:
	return ore.display_name


func get_stack_key() -> Resource:
	return ore


func get_carry_limit() -> int:
	return ore.carry_limit


func get_carry_speed_multiplier() -> float:
	return ore.carry_speed_multiplier
