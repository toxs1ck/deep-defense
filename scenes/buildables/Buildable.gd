class_name Buildable
extends StaticBody3D
## Basis aller Bauelemente. Der Host setzt Lage, Drehung und Datenpfad vor dem Spawnen; der BuildableSpawner
## überträgt sie einmalig an alle (Bauelemente bewegen sich nicht).
## Hat Lebenspunkte: Gegner greifen Bauelemente an, wenn der Weg zum Aufzug zugebaut ist. Mit sinkenden LP wird
## das Bauelement dunkler; bei 0 LP entfernt es der BuildManager.
## Beim Versetzen packt der BuildManager es in eine Kiste: get_state() liefert alles, was erhalten bleiben soll,
## apply_state() setzt es vor dem nächsten Spawnen wieder (wird dann mit den Spawn-Eigenschaften verteilt).
## Unterklassen mit eigenem Zustand (z. B. Munition) ergänzen beide Funktionen.

const GROUP: StringName = &"buildables"
## Farbanteil, der bei 0 LP noch übrig ist.
const DAMAGED_BRIGHTNESS: float = 0.35

@export var data_path: String = ""
@export var sync_position: Vector3
## Drehung in 90°-Schritten um die Hochachse (0–3).
@export var rotation_steps: int = 0
## Lebenspunkte beim Spawnen, 0 = voll. Für versetzte Bauelemente; wird beim Spawnen mitgeschickt.
@export var initial_health: int = 0

var data: BuildableData

@onready var health: HealthComponent = $HealthComponent
@onready var _mesh: MeshInstance3D = $Mesh

var _material: StandardMaterial3D = null
var _base_color: Color = Color.WHITE


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	global_position = sync_position
	rotation.y = rotation_steps * PI / 2.0
	data = load(data_path) as BuildableData
	assert(data != null, "Buildable: ungültiger data_path '%s'" % data_path)
	# Eigene Materialkopie, damit nur dieses Bauelement dunkler wird.
	var mesh_material := _mesh.mesh.surface_get_material(0) as StandardMaterial3D
	_material = mesh_material.duplicate() as StandardMaterial3D
	_base_color = _material.albedo_color
	_mesh.material_override = _material
	health.setup(data.max_health, initial_health)
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_on_health_changed(health.current_health, health.max_health)


## Nur Host: Zustand, der beim Versetzen erhalten bleibt.
func get_state() -> Dictionary:
	return { "health": health.current_health }


## Nur Host, vor dem Spawnen: Zustand aus der Kiste übernehmen.
func apply_state(state: Dictionary) -> void:
	initial_health = state.get("health", 0)


func _on_health_changed(current: int, maximum: int) -> void:
	var fraction := float(current) / float(maximum)
	_material.albedo_color = _base_color * lerpf(DAMAGED_BRIGHTNESS, 1.0, fraction)
	_material.albedo_color.a = 1.0


func _on_died() -> void:
	if multiplayer.is_server():
		var manager := get_tree().get_first_node_in_group(BuildManager.GROUP) as BuildManager
		manager.destroy(self)
