class_name Player
extends CharacterBody3D
## Spielfigur: läuft relativ zur Kamera, sprintet und springt.
## Der Node-Name ist die Peer-ID des Besitzers. Nur der Besitzer simuliert die Bewegung (direktes Spielgefühl);
## alle anderen bekommen Position und Blickrichtung über den MultiplayerSynchronizer und glätten sie.
## Der Körper selbst dreht sich nicht; nur „Model“ schaut in Laufrichtung, damit die Kamera unabhängig bleibt.

## Nur beim lokalen Spieler: das anvisierte Objekt hat gewechselt (null = nichts im Visier).
signal interaction_target_changed(target: InteractableComponent)
## Nur beim lokalen Spieler sinnvoll: trägt jetzt etwas bzw. nichts mehr. Reicht CarryComponent.carried_changed
## weiter, damit man sich schon vor _ready verbinden kann (z. B. Main beim Hinzufügen der Figur).
signal carrying_changed(is_carrying: bool)

const GROUP: StringName = &"players"
## Augenhöhe über den Füßen; Startpunkt für die Reichweite von Interaktionen.
const EYE_HEIGHT: float = 1.6
## Physik-Ebenen, die der Interaktions-Raycast trifft: world (1), buildable (4), interactable (6).
## Wände blockieren damit die Sicht auf Objekte dahinter.
const INTERACTION_MASK: int = (1 << 0) | (1 << 3) | (1 << 5)
## Anteil nach oben, der beim Werfen zur Blickrichtung kommt, damit Brocken einen Bogen fliegen.
const THROW_LIFT: float = 0.25
## Obergrenze für InteractableComponent.extra_range; so lang wird der Raycast mindestens verlängert.
const MAX_EXTRA_RANGE: float = 2.0

@export var data: PlayerData
## Wie schnell fremde Figuren zur empfangenen Position aufschließen. Höher = direkter, aber ruckeliger.
@export var remote_smoothing: float = 18.0
## Ab dieser Abweichung in Metern springt eine fremde Figur direkt an die Zielposition (z. B. nach Respawn).
@export var remote_snap_distance: float = 3.0

## Vom Besitzer gesetzt und per MultiplayerSynchronizer verteilt.
@export var sync_position: Vector3
@export var sync_yaw: float

@onready var carry: CarryComponent = $Model/CarryComponent
@onready var _camera: PlayerCamera = $PlayerCamera
@onready var _model: Node3D = $Model
@onready var _body: MeshInstance3D = $Model/Body

var _interaction_target: InteractableComponent = null
## Wartezeit bis zur nächsten wiederholten Interaktion beim Gedrückthalten.
var _interact_cooldown: float = 0.0

## Restzeit, in der ein Sprung noch erlaubt ist; am Boden immer voll.
var _coyote_timer: float = 0.0
## Restzeit, in der ein gedrückter Sprung noch auf Bodenkontakt wartet.
var _jump_buffer_timer: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)
	# Läuft vor _ready und auf allen Peers, damit die Autorität überall gleich gesetzt ist.
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())


func _ready() -> void:
	assert(data != null, "Player braucht eine PlayerData-Resource")
	# Der Host setzt sync_position vor dem Spawnen; sie kommt auch bei den Clients mit an.
	global_position = sync_position
	_model.rotation.y = sync_yaw
	_apply_player_color()
	carry.carried_changed.connect(func(is_carrying: bool) -> void: carrying_changed.emit(is_carrying))
	if is_multiplayer_authority():
		_camera.activate()


func _process(delta: float) -> void:
	if is_multiplayer_authority():
		return
	if global_position.distance_to(sync_position) > remote_snap_distance:
		global_position = sync_position
	else:
		var weight := 1.0 - exp(-remote_smoothing * delta)
		global_position = global_position.lerp(sync_position, weight)
	_model.rotation.y = lerp_angle(_model.rotation.y, sync_yaw, 1.0 - exp(-remote_smoothing * delta))


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var gravity := get_gravity() * data.gravity_scale
	if is_on_floor():
		_coyote_timer = data.coyote_time
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
		var falling := velocity.y < 0.0
		velocity += gravity * (data.fall_gravity_multiplier if falling else 1.0) * delta

	if _just_pressed(&"jump"):
		_jump_buffer_timer = data.jump_buffer_time
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = sqrt(2.0 * gravity.length() * data.jump_height)
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0

	var input_dir := _move_input()
	var direction := _camera.get_yaw_basis() * Vector3(input_dir.x, 0.0, input_dir.y)
	var is_carrying := carry.is_carrying()
	var is_sprinting := _pressed(&"sprint") and input_dir != Vector2.ZERO and not is_carrying
	var speed := data.sprint_speed if is_sprinting else data.walk_speed
	speed *= carry.get_speed_multiplier()
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

	sync_position = global_position
	sync_yaw = _model.rotation.y

	_update_interaction_target()
	_handle_carry_input()
	_interact_cooldown = maxf(0.0, _interact_cooldown - delta)
	if _interaction_target and _interact_cooldown <= 0.0:
		var held := _interaction_target.allow_hold and _pressed(&"interact")
		if held or _just_pressed(&"interact"):
			_interaction_target.request_interact()
			_interact_cooldown = 1.0 / data.mining_rate if _interaction_target.allow_hold else 0.0


## Jeder Spieler bekommt eine eigene Farbe aus seiner Peer-ID, damit man Figuren unterscheiden kann.
## Der Host (ID 1) behält das Orange aus der Szene.
func _apply_player_color() -> void:
	var peer_id := get_multiplayer_authority()
	if peer_id == 1:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.from_hsv(fposmod(peer_id * 0.618034, 1.0), 0.65, 0.85)
	_body.material_override = material


## Beim Tragen: Angreifen wirft in Blickrichtung, Interagieren ohne Ziel legt ab.
func _handle_carry_input() -> void:
	if not carry.is_carrying():
		return
	if _just_pressed(&"attack"):
		var forward := -_camera.get_view_transform().basis.z
		carry.request_drop((forward + Vector3.UP * THROW_LIFT).normalized())
	elif _interaction_target == null and _just_pressed(&"interact"):
		carry.request_drop()


## Raycast von der Kamera durch die Bildmitte. Getroffen zählt nur, was vor der Figur und in Reichweite liegt.
func _update_interaction_target() -> void:
	var view := _camera.get_view_transform()
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var forward := -view.basis.z
	var reach := view.origin.distance_to(eye) + data.interaction_range + MAX_EXTRA_RANGE
	var query := PhysicsRayQueryParameters3D.create(view.origin, view.origin + forward * reach, INTERACTION_MASK, [get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var target: InteractableComponent = null
	if not hit.is_empty():
		var hit_position: Vector3 = hit["position"]
		var candidate := hit["collider"] as InteractableComponent
		var in_front := (hit_position - eye).dot(forward) > 0.0
		if candidate and candidate.enabled and in_front and eye.distance_to(hit_position) <= data.interaction_range + candidate.extra_range:
			target = candidate

	if target != _interaction_target:
		_interaction_target = target
		interaction_target_changed.emit(target)


## Eingabe-Abfragen laufen über diese Helfer, damit ein offenes Menü die Figur sperrt.
func _pressed(action: StringName) -> bool:
	return not GameState.input_blocked and Input.is_action_pressed(action)


func _just_pressed(action: StringName) -> bool:
	return not GameState.input_blocked and Input.is_action_just_pressed(action)


func _move_input() -> Vector2:
	if GameState.input_blocked:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")
