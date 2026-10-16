class_name Enemy
extends CharacterBody3D
## Basis für alle Gegner; Typen unterscheiden sich über EnemyData.
## Die KI läuft nur auf dem Host: zum Aufzug laufen (NavigationAgent3D), dort in Abständen angreifen.
## Clients bekommen Position und Blickrichtung über den MultiplayerSynchronizer und glätten sie.

const GROUP: StringName = &"enemies"
## So oft wird der Weg neu berechnet (GDD: KI in festen Ticks statt jeden Frame).
const REPATH_INTERVAL: float = 0.5
## Ab dieser Entfernung zur Mitte des Aufzugs greift der Gegner an.
const ATTACK_RANGE: float = 3.0
const TURN_SPEED: float = 10.0

## Pfad zur EnemyData-Resource; wird beim Spawnen mitgeschickt.
@export var data_path: String = ""
@export var remote_smoothing: float = 15.0

## Vom Host gesetzt und per MultiplayerSynchronizer verteilt.
@export var sync_position: Vector3
@export var sync_yaw: float

var data: EnemyData

@onready var health: HealthComponent = $HealthComponent
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _model: Node3D = $Model
@onready var _body: MeshInstance3D = $Model/Body

var _elevator: Elevator = null
var _repath_timer: float = 0.0
var _attack_timer: float = 0.0
var _body_rest_position: Vector3 = Vector3.ZERO


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	data = load(data_path) as EnemyData
	assert(data != null, "Enemy: ungültiger data_path '%s'" % data_path)
	var material := StandardMaterial3D.new()
	material.albedo_color = data.color
	_body.material_override = material
	_body_rest_position = _body.position
	health.setup(data.max_health)
	health.died.connect(_on_died)
	global_position = sync_position
	_model.rotation.y = sync_yaw


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		var weight := 1.0 - exp(-remote_smoothing * delta)
		global_position = global_position.lerp(sync_position, weight)
		_model.rotation.y = lerp_angle(_model.rotation.y, sync_yaw, weight)
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	if not is_instance_valid(_elevator):
		_elevator = get_tree().get_first_node_in_group(Elevator.GROUP) as Elevator

	var horizontal := Vector3.ZERO
	if _elevator and not health.is_dead():
		if global_position.distance_to(_elevator.global_position) <= ATTACK_RANGE:
			_attack(delta)
		else:
			horizontal = _move_direction(delta) * data.speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	if horizontal.length_squared() > 0.01:
		var target_yaw := atan2(-horizontal.x, -horizontal.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, minf(1.0, TURN_SPEED * delta))
	sync_position = global_position
	sync_yaw = _model.rotation.y


func _move_direction(delta: float) -> Vector3:
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = REPATH_INTERVAL
		_agent.target_position = _elevator.get_attack_point()
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	var to_next := _agent.get_next_path_position() - global_position
	to_next.y = 0.0
	return to_next.normalized() if to_next.length_squared() > 0.0001 else Vector3.ZERO


func _attack(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	_attack_timer = data.attack_interval
	_elevator.health.damage(data.elevator_damage)
	_play_attack.rpc()


## Kurzer Ruck nach vorne, damit man sieht, wer gerade angreift.
@rpc("authority", "call_local", "unreliable")
func _play_attack() -> void:
	_body.position = _body_rest_position
	var tween := create_tween()
	tween.tween_property(_body, "position", _body_rest_position + Vector3.FORWARD * 0.3, 0.08)
	tween.tween_property(_body, "position", _body_rest_position, 0.15)


## Nur der Host entfernt den Gegner; der EnemySpawner entfernt ihn dann auch bei den Clients.
func _on_died() -> void:
	if multiplayer.is_server():
		queue_free()
