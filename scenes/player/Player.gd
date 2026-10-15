extends CharacterBody3D
## Spielfigur: läuft relativ zur Kamera, sprintet und springt.
## Nur der Besitzer der Figur verarbeitet Eingaben, damit der Multiplayer (Aufgabe 3) direkt andocken kann.
## Der Körper selbst dreht sich nicht; nur „Model“ schaut in Laufrichtung, damit die Kamera unabhängig bleibt.

@export var data: PlayerData

@onready var _camera: PlayerCamera = $PlayerCamera
@onready var _model: Node3D = $Model


func _ready() -> void:
	assert(data != null, "Player braucht eine PlayerData-Resource")
	if is_multiplayer_authority():
		_camera.activate()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var gravity := get_gravity() * data.gravity_scale
	if not is_on_floor():
		var falling := velocity.y < 0.0
		velocity += gravity * (data.fall_gravity_multiplier if falling else 1.0) * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = sqrt(2.0 * gravity.length() * data.jump_height)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera.get_yaw_basis() * Vector3(input_dir.x, 0.0, input_dir.y)
	var is_sprinting := Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO
	var speed := data.sprint_speed if is_sprinting else data.walk_speed
	var accel := data.air_acceleration
	if is_on_floor():
		accel = data.acceleration if input_dir != Vector2.ZERO else data.deceleration

	var target := Vector2(direction.x, direction.z) * speed
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(target, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	move_and_slide()

	if direction.length_squared() > 0.001:
		var target_yaw := atan2(-direction.x, -direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, minf(1.0, data.turn_speed * delta))
