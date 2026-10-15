class_name OreChunk
extends RigidBody3D
## Erzbrocken. Der Host simuliert die Physik, Clients zeigen die übertragene Lage geglättet an.
## Wird vom MultiplayerSpawner unter „Chunks“ in Main repliziert; Aufheben und Tragen folgen in Aufgabe 6.

## Pfad zur OreData-Resource; wird beim Spawnen mitgeschickt, damit Clients die Erzart kennen.
@export var ore_path: String = ""
@export var remote_smoothing: float = 20.0

## Vom Host gesetzt und per MultiplayerSynchronizer verteilt.
@export var sync_position: Vector3
@export var sync_rotation: Vector3

var ore: OreData

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	ore = load(ore_path) as OreData
	assert(ore != null, "OreChunk: ungültiger ore_path '%s'" % ore_path)
	var material := StandardMaterial3D.new()
	material.albedo_color = ore.color
	_mesh.material_override = material
	if multiplayer.is_server():
		_store_sync_state()
	else:
		# Auf Clients bewegt sich der Brocken nur über die übertragene Lage, nicht über eigene Physik.
		freeze = true
		global_position = sync_position
		global_rotation = sync_rotation


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_store_sync_state()
		return
	var weight := 1.0 - exp(-remote_smoothing * delta)
	global_position = global_position.lerp(sync_position, weight)
	var target := Quaternion.from_euler(sync_rotation)
	global_basis = Basis(global_basis.get_rotation_quaternion().slerp(target, weight))


func _store_sync_state() -> void:
	# Nur bei echten Änderungen schreiben, damit ruhende Brocken keinen Netzwerkverkehr erzeugen.
	if not global_position.is_equal_approx(sync_position):
		sync_position = global_position
	if not global_rotation.is_equal_approx(sync_rotation):
		sync_rotation = global_rotation
