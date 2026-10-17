class_name Carryable
extends RigidBody3D
## Basis für alles, was Spieler tragen können (Erzbrocken, Blaupausen-Kisten).
## Der Host simuliert die Physik, Clients zeigen die übertragene Lage geglättet an. Getragen: carrier_id ist die
## Peer-ID des Trägers; dann folgt das Item auf jedem Peer lokal dem Haltepunkt des Trägers (ohne Netzwerkverkehr).
## Unterklassen legen fest, was gestapelt werden darf, wie schwer es ist und wie es aussieht.

const ITEM_LAYER: int = 1 << 4

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

## Aufgelöster Träger; wird erst gesucht, wenn er da ist (später Beitretende bekommen Items evtl. vor der Figur).
var _carrier: Player = null

## Sichtbares Modell (Container um das importierte Modell).
@onready var mesh: Node3D = $Mesh
@onready var _interactable: InteractableComponent = $InteractableComponent


func _ready() -> void:
	_setup_item()
	_interactable.prompt_text = "%s aufheben" % get_display_name()
	_interactable.interacted.connect(_on_interacted)
	if multiplayer.is_server():
		_store_sync_state()
	else:
		# Auf Clients bewegt sich das Item nur über die übertragene Lage, nicht über eigene Physik.
		freeze = true
		global_position = sync_position
		global_rotation = sync_rotation
	_on_carrier_changed()


## Für Unterklassen: Daten laden und Aussehen einrichten (vor allem anderen in _ready).
func _setup_item() -> void:
	pass


func get_display_name() -> String:
	return "Item"


## Nur Items mit gleichem Schlüssel werden gestapelt, höchstens bis get_carry_limit().
func get_stack_key() -> Resource:
	return null


func get_carry_limit() -> int:
	return 1


func get_carry_speed_multiplier() -> float:
	return 1.0


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
	# Nur bei echten Änderungen schreiben, damit ruhende Items keinen Netzwerkverkehr erzeugen.
	if not global_position.is_equal_approx(sync_position):
		sync_position = global_position
	if not global_rotation.is_equal_approx(sync_rotation):
		sync_rotation = global_rotation


func _find_player(peer_id: int) -> Player:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		if node.name == str(peer_id):
			return node as Player
	return null
