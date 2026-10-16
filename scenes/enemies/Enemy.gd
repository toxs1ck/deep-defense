class_name Enemy
extends CharacterBody3D
## Basis für alle Gegner; Typen unterscheiden sich über EnemyData.
## Die KI läuft nur auf dem Host: zum Aufzug laufen (NavigationAgent3D), dort in Abständen angreifen.
## Jeder Gegner sucht sich einen eigenen Angriffspunkt rund um den Aufzug, und die Agenten weichen einander aus
## (Avoidance), damit sich keine Schlange bildet. Spieler, die einen Gegner berühren, schieben ihn weg.
## Clients bekommen Position und Blickrichtung über den MultiplayerSynchronizer und glätten sie.

const GROUP: StringName = &"enemies"
## So oft wird der Weg neu berechnet (GDD: KI in festen Ticks statt jeden Frame).
const REPATH_INTERVAL: float = 0.5
## Ab dieser Entfernung zur Mitte des Aufzugs greift der Gegner an.
const ATTACK_RANGE: float = 2.8
## Abstand der Angriffspunkte zur Mitte des Aufzugs (knapp außerhalb der Korbwände).
const ATTACK_POINT_RADIUS: float = 2.3
## Radien für das Wegschieben durch Spieler: Gegner (Kollision) und Spieler (Kapsel) plus etwas Spielraum.
const BODY_RADIUS: float = 0.525
const PLAYER_RADIUS: float = 0.4
const PUSH_MARGIN: float = 0.15
## Wie schnell ein berührter Gegner vom Spieler weggeschoben wird, in m/s.
const PUSH_SPEED: float = 2.5
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
## Nur Host: eigener Angriffspunkt als Winkel um den Aufzug und die von der Avoidance berechnete Geschwindigkeit.
var _attack_angle: float = 0.0
var _safe_velocity: Vector3 = Vector3.ZERO


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
	if multiplayer.is_server():
		_attack_angle = GameState.rng.randf_range(0.0, TAU)
		_agent.max_speed = data.speed
		_agent.avoidance_enabled = true
		_agent.velocity_computed.connect(func(safe_velocity: Vector3) -> void: _safe_velocity = safe_velocity)


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

	var desired := Vector3.ZERO
	if _elevator and not health.is_dead():
		if global_position.distance_to(_elevator.global_position) <= ATTACK_RANGE:
			_attack(delta)
		else:
			desired = _move_direction(delta) * data.speed
	# Die Avoidance liefert ihr Ergebnis per Signal; verwendet wird das aus dem letzten Tick.
	_agent.velocity = desired
	var horizontal := _safe_velocity if desired != Vector3.ZERO else Vector3.ZERO
	horizontal.y = 0.0
	var facing := horizontal
	horizontal += _player_push()
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	if facing.length_squared() > 0.01:
		var target_yaw := atan2(-facing.x, -facing.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, minf(1.0, TURN_SPEED * delta))
	sync_position = global_position
	sync_yaw = _model.rotation.y


func _move_direction(delta: float) -> Vector3:
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = REPATH_INTERVAL
		var around := Vector3(sin(_attack_angle), 0.0, cos(_attack_angle)) * ATTACK_POINT_RADIUS
		_agent.target_position = _elevator.global_position + around
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	var to_next := _agent.get_next_path_position() - global_position
	to_next.y = 0.0
	return to_next.normalized() if to_next.length_squared() > 0.0001 else Vector3.ZERO


## Spieler, die den Gegner berühren, schieben ihn von sich weg. Positionen fremder Spieler sind auf dem Host
## die geglätteten, das reicht für ein leichtes Schieben.
func _player_push() -> Vector3:
	var push := Vector3.ZERO
	var contact := BODY_RADIUS + PLAYER_RADIUS + PUSH_MARGIN
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		var away := global_position - player.global_position
		away.y = 0.0
		var distance := away.length()
		if distance < contact and distance > 0.001:
			push += away / distance * PUSH_SPEED
	return push


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
