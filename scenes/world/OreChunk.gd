class_name OreChunk
extends RigidBody3D
## Erzbrocken. Der Host simuliert die Physik, Clients zeigen die übertragene Lage geglättet an.
## Wird vom MultiplayerSpawner unter „Chunks“ in Main repliziert.
## Getragen: carrier_id ist die Peer-ID des Trägers. Dann folgt der Brocken auf jedem Peer lokal dem Haltepunkt
## des Trägers; dafür wird keine Position übertragen.

## Pfad zur OreData-Resource; wird beim Spawnen mitgeschickt, damit Clients die Erzart kennen.
@export var ore_path: String = ""
@export var remote_smoothing: float = 20.0

## Vom Host gesetzt und per MultiplayerSynchronizer verteilt.
@export var sync_position: Vector3
@export var sync_rotation: Vector3
## 0 = liegt frei. Vom Host gesetzt, per MultiplayerSynchronizer verteilt.
@export var carrier_id: int = 0:
	set(value):
		if value == carrier_id:
			return
		carrier_id = value
		_on_carrier_changed()

const ITEM_LAYER: int = 1 << 4
const GROUP: StringName = &"ore_chunks"

var ore: OreData

## Aufgelöster Träger; wird erst gesucht, wenn er da ist (später Beitretende bekommen Brocken evtl. vor der Figur).
var _carrier: Player = null

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _interactable: InteractableComponent = $InteractableComponent


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	ore = load(ore_path) as OreData
	assert(ore != null, "OreChunk: ungültiger ore_path '%s'" % ore_path)
	var material := StandardMaterial3D.new()
	material.albedo_color = ore.color
	_mesh.material_override = material
	_interactable.prompt_text = "%s aufheben" % ore.display_name
	_interactable.interacted.connect(_on_interacted)
	if multiplayer.is_server():
		_store_sync_state()
	else:
		# Auf Clients bewegt sich der Brocken nur über die übertragene Lage, nicht über eigene Physik.
		freeze = true
		global_position = sync_position
		global_rotation = sync_rotation
	_on_carrier_changed()


func _exit_tree() -> void:
	if is_instance_valid(_carrier):
		_carrier.carry.unregister(self)
	_carrier = null


func _physics_process(delta: float) -> void:
	if carrier_id != 0:
		_follow_carrier()
		return
	if multiplayer.is_server():
		_store_sync_state()
		return
	var weight := 1.0 - exp(-remote_smoothing * delta)
	global_position = global_position.lerp(sync_position, weight)
	var target := Quaternion.from_euler(sync_rotation)
	global_basis = Basis(global_basis.get_rotation_quaternion().slerp(target, weight))


## Nur Host: von einem Spieler aufgehoben werden.
func _on_interacted(player: Player) -> void:
	if carrier_id == 0 and player.carry.can_pick_up(self):
		carrier_id = player.get_multiplayer_authority()


## Nur Host: loslassen an einer Position, optional mit Wurfgeschwindigkeit.
func release(at: Vector3, release_velocity: Vector3) -> void:
	carrier_id = 0
	global_position = at
	linear_velocity = release_velocity
	angular_velocity = Vector3.ZERO
	_store_sync_state()


func _on_carrier_changed() -> void:
	if not is_node_ready():
		return
	if is_instance_valid(_carrier):
		_carrier.carry.unregister(self)
	_carrier = null
	var carried := carrier_id != 0
	_interactable.enabled = not carried
	collision_layer = 0 if carried else ITEM_LAYER
	if multiplayer.is_server():
		freeze = carried
	if carried:
		_follow_carrier()


func _follow_carrier() -> void:
	if not is_instance_valid(_carrier):
		_carrier = _find_player(carrier_id)
		if _carrier == null:
			return
		_carrier.carry.register(self)
	global_transform = _carrier.carry.get_hold_transform(self)


func _store_sync_state() -> void:
	# Nur bei echten Änderungen schreiben, damit ruhende Brocken keinen Netzwerkverkehr erzeugen.
	if not global_position.is_equal_approx(sync_position):
		sync_position = global_position
	if not global_rotation.is_equal_approx(sync_rotation):
		sync_rotation = global_rotation


func _find_player(peer_id: int) -> Player:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		if node.name == str(peer_id):
			return node as Player
	return null
