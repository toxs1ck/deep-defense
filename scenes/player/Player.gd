class_name Player
extends CharacterBody3D
## Spielfigur: läuft relativ zur Kamera, sprintet und springt.
## Der Node-Name ist die Peer-ID des Besitzers. Nur der Besitzer simuliert die Bewegung (direktes Spielgefühl);
## alle anderen bekommen Position und Blickrichtung über den MultiplayerSynchronizer und glätten sie.
## Der Körper selbst dreht sich nicht; nur „Model“ schaut in Laufrichtung, damit die Kamera unabhängig bleibt.
## Kampf: Linksklick schwingt die Spitzhacke. Visiert man ein Vorkommen an, wird abgebaut, sonst prüft der Host,
## welche Gegner vor der Figur getroffen werden. Bei 0 LP fällt die Figur und erscheint nach respawn_time am Aufzug.

## Nur beim lokalen Spieler: das anvisierte Objekt hat gewechselt (null = nichts im Visier).
signal interaction_target_changed(target: InteractableComponent)
## Nur beim lokalen Spieler sinnvoll: trägt jetzt etwas bzw. nichts mehr. Reicht CarryComponent.carried_changed
## weiter, damit man sich schon vor _ready verbinden kann (z. B. Main beim Hinzufügen der Figur).
signal carrying_changed(is_carrying: bool)
## Reicht HealthComponent.health_changed weiter (aus demselben Grund wie carrying_changed).
signal health_changed(current: int, maximum: int)
## Baumodus an bzw. aus.
signal build_mode_changed(is_active: bool)
## Im Baumodus ein anderes Bauelement gewählt.
signal build_selection_changed(display_name: String)
## Fortschritt beim Halten von E (0–1); 0 = nicht am Halten.
signal hold_progress_changed(fraction: float)
## Gefallen bzw. wieder da; respawn_seconds ist die Wartezeit bis zum Respawn.
signal downed_changed(is_downed: bool, respawn_seconds: float)

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
## Wie viele unpassende Interaktionsflächen der Strahl höchstens durchdringt.
const MAX_INTERACTION_LAYERS: int = 3
## Treffer zählen in diesem Kegel vor der Figur (Skalarprodukt mit der Blickrichtung) …
const ATTACK_CONE_DOT: float = 0.3
## … oder wenn der Gegner ganz nah ist, egal in welcher Richtung.
const ATTACK_POINT_BLANK: float = 0.9
const ATTACK_MAX_HEIGHT_DIFFERENCE: float = 1.5
## Der Host lässt Schläge etwas schneller zu als die Schlagrate (Netzwerk-Schwankungen).
const SWING_RATE_TOLERANCE: float = 0.85
## Ruhe- und Schlagwinkel der Spitzhacke (um die lokale X-Achse) und Dauer des Schlags.
const PICKAXE_REST_DEGREES: float = 35.0
const PICKAXE_STRIKE_DEGREES: float = -95.0
const PICKAXE_STRIKE_TIME: float = 0.09
const PICKAXE_RECOVER_TIME: float = 0.25
const PHYSICS_LAYER: int = 1 << 1
## Kürzer gedrückt gilt bei haltbaren Objekten als Tippen.
const TAP_TIME: float = 0.25

@export var data: PlayerData
## Wie schnell fremde Figuren zur empfangenen Position aufschließen. Höher = direkter, aber ruckeliger.
@export var remote_smoothing: float = 18.0
## Ab dieser Abweichung in Metern springt eine fremde Figur direkt an die Zielposition (z. B. nach Respawn).
@export var remote_snap_distance: float = 3.0

## Vom Besitzer gesetzt und per MultiplayerSynchronizer verteilt.
@export var sync_position: Vector3
@export var sync_yaw: float
## Gewähltes Merkmal (Pfad zur TraitData, leer = keins); vom Besitzer gesetzt, damit auch der Host es kennt.
@export var trait_path: String = "":
	set(value):
		trait_path = value
		trait_data = load(value) as TraitData if not value.is_empty() else null

var trait_data: TraitData = null

@onready var carry: CarryComponent = $Model/CarryComponent
@onready var health: HealthComponent = $HealthComponent
@onready var build: BuildComponent = $BuildComponent
@onready var _pickaxe: Node3D = $Model/Pickaxe
@onready var _camera: PlayerCamera = $PlayerCamera
@onready var _model: Node3D = $Model
@onready var _body: MeshInstance3D = $Model/Body

var _interaction_target: InteractableComponent = null
## Wartezeit bis zum nächsten Schlag mit der Spitzhacke.
var _swing_cooldown: float = 0.0
## Nur Host: Zeitpunkt des letzten angenommenen Schlags dieses Spielers.
var _last_host_swing: float = -INF
var _downed: bool = false
var _last_health: int = 0
var _pickaxe_tween: Tween = null
## Objekt, auf dem E gerade gehalten wird, und wie lange schon.
var _hold_target: InteractableComponent = null
var _hold_time: float = 0.0

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
	health.setup(data.max_health)
	_last_health = health.current_health
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	_pickaxe.rotation_degrees.x = PICKAXE_REST_DEGREES
	build.active_changed.connect(_on_build_mode_changed)
	build.selection_changed.connect(_on_build_selection_changed)
	if is_multiplayer_authority():
		trait_path = GameState.selected_trait_path
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
	_handle_interact_input(delta)
	# Baumodus genau dann, wenn eine gekaufte Kiste in der Hand liegt.
	build.set_active(build.has_crate())
	_swing_cooldown = maxf(0.0, _swing_cooldown - delta)
	if build.active:
		_handle_build_input()
	# Schlagen: Linksklick, Halten schlägt im Takt weiter. Mit Erz in der Hand wird stattdessen geworfen.
	elif _pressed(&"attack") and _swing_cooldown <= 0.0 and not carry.is_carrying():
		_swing()


## Baumodus (mit Kiste in der Hand): Linksklick baut auf, R / Mausrad dreht, E ohne Ziel legt die Kiste ab.
func _handle_build_input() -> void:
	build.update_aim(_camera.get_view_transform(), global_position)
	if _just_pressed(&"build_rotate_left"):
		build.rotate_selection(-1)
	if _just_pressed(&"build_rotate_right"):
		build.rotate_selection(1)
	if _just_pressed(&"attack"):
		build.try_place()


func _on_build_selection_changed(selection: BuildableData) -> void:
	build_selection_changed.emit(selection.display_name if selection else "")


func _on_build_mode_changed(is_active: bool) -> void:
	_camera.set_build_view(is_active)
	build_mode_changed.emit(is_active)


## E: tippen löst die Interaktion aus. Bei haltbaren Objekten entscheidet erst das Loslassen: kurz = tippen,
## lange genug gehalten = Halte-Aktion (z. B. Kaufen). Wegschauen oder Loslassen bricht das Halten ab.
func _handle_interact_input(delta: float) -> void:
	var target := _interaction_target
	if target and target.action == &"interact" and _just_pressed(&"interact"):
		if target.hold_seconds > 0.0:
			_hold_target = target
			_hold_time = 0.0
		else:
			target.request_interact()
	if _hold_target == null:
		return
	if _hold_target != target or not _pressed(&"interact"):
		if _hold_target == target and _hold_time < TAP_TIME and _hold_target.tap_enabled:
			_hold_target.request_interact()
		_hold_target = null
		hold_progress_changed.emit(0.0)
		return
	_hold_time += delta
	hold_progress_changed.emit(minf(1.0, _hold_time / _hold_target.hold_seconds))
	if _hold_time >= _hold_target.hold_seconds:
		_hold_target.request_hold()
		_hold_target = null
		hold_progress_changed.emit(0.0)


func is_downed() -> bool:
	return _downed


## Schläge pro Sekunde beim Abbauen bzw. im Kampf, mit Merkmal (z. B. Hauer).
func get_mining_rate() -> float:
	return data.swing_rate * (trait_data.mining_speed_multiplier if trait_data else 1.0)


func get_attack_rate() -> float:
	return data.swing_rate * (trait_data.attack_speed_multiplier if trait_data else 1.0)


func get_melee_damage() -> int:
	return roundi(data.attack_damage * (trait_data.melee_damage_multiplier if trait_data else 1.0))


func _swing() -> void:
	var mining := _interaction_target != null and _interaction_target.action == &"attack"
	_swing_cooldown = 1.0 / (get_mining_rate() if mining else get_attack_rate())
	# Zum Schlagen in Kamerarichtung drehen, damit man trifft, wohin man schaut.
	var forward := -_camera.get_yaw_basis().z
	_model.rotation.y = atan2(-forward.x, -forward.z)
	sync_yaw = _model.rotation.y
	_play_swing()
	_play_swing_remote.rpc()
	if _interaction_target and _interaction_target.action == &"attack":
		_interaction_target.request_interact()
	else:
		_melee_on_host.rpc_id(1, forward)


@rpc("authority", "call_remote", "unreliable")
func _play_swing_remote() -> void:
	_play_swing()


func _play_swing() -> void:
	if _pickaxe_tween:
		_pickaxe_tween.kill()
	_pickaxe_tween = create_tween()
	_pickaxe_tween.tween_property(_pickaxe, "rotation_degrees:x", PICKAXE_STRIKE_DEGREES, PICKAXE_STRIKE_TIME)
	_pickaxe_tween.tween_property(_pickaxe, "rotation_degrees:x", PICKAXE_REST_DEGREES, PICKAXE_RECOVER_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Nur Host: Treffer bestimmen. Getroffen wird jeder Gegner in Reichweite im Kegel vor der Figur.
@rpc("any_peer", "call_local", "reliable")
func _melee_on_host(forward: Vector3) -> void:
	if not multiplayer.is_server() or _downed:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if sender != get_multiplayer_authority():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_host_swing < SWING_RATE_TOLERANCE / get_attack_rate():
		return
	_last_host_swing = now

	forward.y = 0.0
	forward = forward.normalized()
	var hits := 0
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy.health.is_dead():
			continue
		var to_enemy := enemy.global_position - global_position
		if absf(to_enemy.y) > ATTACK_MAX_HEIGHT_DIFFERENCE:
			continue
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance > data.attack_range + Enemy.BODY_RADIUS:
			continue
		var direction := to_enemy / distance if distance > 0.001 else forward
		if distance > ATTACK_POINT_BLANK and direction.dot(forward) < ATTACK_CONE_DOT:
			continue
		enemy.take_hit(get_melee_damage(), direction * data.attack_knockback, self, global_position)
		hits += 1
	if hits > 0:
		_confirm_hit.rpc_id(sender)


## Beim Angreifer: Treffer bestätigt, kurzes Kamerawackeln für mehr Wucht.
@rpc("any_peer", "call_local", "unreliable")
func _confirm_hit() -> void:
	if _from_host():
		_camera.shake(0.08)


func _on_health_changed(current: int, maximum: int) -> void:
	# Erlittener Schaden: die eigene Kamera wackelt etwas stärker als bei eigenen Treffern.
	if is_multiplayer_authority() and current < _last_health:
		_camera.shake(0.15)
	_last_health = current
	health_changed.emit(current, maximum)


## Auf allen Peers. Der Host lässt fallen, was die Figur trägt, und plant den Respawn.
func _on_died() -> void:
	_set_downed(true)
	if multiplayer.is_server():
		carry.drop_all()
		get_tree().create_timer(data.respawn_time).timeout.connect(_respawn_on_host)


func _respawn_on_host() -> void:
	if not is_inside_tree():
		return
	var elevator := get_tree().get_first_node_in_group(Elevator.GROUP) as Elevator
	var spawn := elevator.get_respawn_point() if elevator else global_position
	health.revive()
	_respawned.rpc(spawn)


@rpc("any_peer", "call_local", "reliable")
func _respawned(spawn: Vector3) -> void:
	if not _from_host():
		return
	if is_multiplayer_authority():
		global_position = spawn
		velocity = Vector3.ZERO
		sync_position = spawn
	_set_downed(false)


func _set_downed(downed: bool) -> void:
	_downed = downed
	if downed:
		build.set_active(false)
	_model.visible = not downed
	# Gefallene Figuren sind für Gegner und Kollisionen nicht da.
	collision_layer = 0 if downed else PHYSICS_LAYER
	if downed and _interaction_target:
		_interaction_target = null
		interaction_target_changed.emit(null)
	downed_changed.emit(downed, data.respawn_time)


func _from_host() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	return sender == 0 or sender == 1


## Jeder Spieler bekommt eine eigene Farbe aus seiner Peer-ID, damit man Figuren unterscheiden kann.
## Der Host (ID 1) behält das Orange aus der Szene.
func _apply_player_color() -> void:
	var peer_id := get_multiplayer_authority()
	if peer_id == 1:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.from_hsv(fposmod(peer_id * 0.618034, 1.0), 0.65, 0.85)
	_body.material_override = material


## Beim Tragen: Angreifen wirft in Blickrichtung (nicht im Baumodus, dort baut es auf), Interagieren ohne Ziel legt ab.
func _handle_carry_input() -> void:
	if not carry.is_carrying():
		return
	if _just_pressed(&"attack") and not build.active:
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
	var exclude: Array[RID] = [get_rid()]
	var target: InteractableComponent = null
	# Trifft der Strahl eine Fläche, die gerade nicht passt (z. B. „Abbauen“ mit Erz in der Hand), sucht er dahinter
	# weiter; so können sich zwei Flächen am selben Objekt nicht gegenseitig verdecken.
	for attempt in MAX_INTERACTION_LAYERS:
		if _downed:
			break
		var query := PhysicsRayQueryParameters3D.create(view.origin, view.origin + forward * reach, INTERACTION_MASK, exclude)
		query.collide_with_areas = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var hit_position: Vector3 = hit["position"]
		var candidate := hit["collider"] as InteractableComponent
		if candidate == null:
			break
		var in_front := (hit_position - eye).dot(forward) > 0.0
		var in_reach := eye.distance_to(hit_position) <= data.interaction_range + candidate.extra_range
		var hands_ok := not (candidate.requires_carrying and not carry.is_carrying()) \
				and not (candidate.requires_empty_hands and carry.is_carrying())
		if candidate.enabled and in_front and in_reach and hands_ok:
			target = candidate
			break
		exclude.append(candidate.get_rid())

	if target != _interaction_target:
		_interaction_target = target
		interaction_target_changed.emit(target)


## Eingabe-Abfragen laufen über diese Helfer, damit ein offenes Menü oder der Tod die Figur sperrt.
func _accepts_input() -> bool:
	return not GameState.input_blocked and not _downed


func _pressed(action: StringName) -> bool:
	return _accepts_input() and Input.is_action_pressed(action)


func _just_pressed(action: StringName) -> bool:
	return _accepts_input() and Input.is_action_just_pressed(action)


func _move_input() -> Vector2:
	if not _accepts_input():
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")
