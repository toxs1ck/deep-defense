class_name Turret
extends Buildable
## Geschützturm: schießt auf den nächsten Gegner in Reichweite mit freier Schusslinie (Treffer sofort).
## Mit Munition voller Schaden und volle Feuerrate, ohne nur ein Bruchteil (DefenseData.unloaded_*).
## Geladen wird vorläufig mit einem Eisenbrocken (E, während man ihn trägt), bis es die Munitionswerkbank gibt.
## Logik nur auf dem Host; Schüsse zeigt ein RPC bei allen, der Munitionsstand kommt per MultiplayerSynchronizer.

## Schusslinie: Welt und Bauelemente verdecken Gegner.
const LINE_OF_SIGHT_MASK: int = (1 << 0) | (1 << 3)
## Zielpunkt über den Füßen des Gegners.
const AIM_HEIGHT: float = 0.5
const TRACER_TIME: float = 0.05
const LOADED_TRACER_COLOR: Color = Color(1.0, 0.85, 0.3)
const UNLOADED_TRACER_COLOR: Color = Color(0.6, 0.6, 0.6)

## Vom Host gesetzt und per MultiplayerSynchronizer verteilt.
@export var ammo: int = 0:
	set(value):
		ammo = value
		if is_node_ready():
			_update_ammo_bar()

@onready var _head: Node3D = $Head
@onready var _muzzle: Marker3D = $Head/Muzzle
@onready var _tracer: MeshInstance3D = $Tracer
@onready var _ammo_fill: Sprite3D = $AmmoBar/Fill
@onready var _load_interactable: InteractableComponent = $LoadInteractable

var _defense: DefenseData
var _cooldown: float = 0.0
var _tracer_material: StandardMaterial3D


func _ready() -> void:
	super()
	_defense = data as DefenseData
	_tracer_material = (_tracer.mesh as BoxMesh).material as StandardMaterial3D
	_tracer.visible = false
	_load_interactable.prompt_text = "%s laden (Munition)" % _defense.ammo_ore.display_name
	_load_interactable.interacted.connect(_on_load_interacted)
	_update_ammo_bar()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or health.is_dead():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	var loaded := ammo > 0
	_cooldown = _defense.interval if loaded else _defense.unloaded_interval
	if loaded:
		ammo -= 1
	var aim := target.global_position + Vector3.UP * AIM_HEIGHT
	var push := (aim - global_position)
	push.y = 0.0
	var amount := _defense.damage if loaded else _defense.unloaded_damage
	target.take_hit(amount, push.normalized() * _defense.knockback, null, global_position)
	_play_shot.rpc(aim, loaded)


func _find_target() -> Enemy:
	var space := get_world_3d().direct_space_state
	var from := _muzzle.global_position
	var best: Enemy = null
	var best_distance := _defense.attack_range
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy.health.is_dead():
			continue
		var aim := enemy.global_position + Vector3.UP * AIM_HEIGHT
		var distance := from.distance_to(aim)
		if distance > best_distance:
			continue
		var ray := PhysicsRayQueryParameters3D.create(from, aim, LINE_OF_SIGHT_MASK, [get_rid()])
		if not space.intersect_ray(ray).is_empty():
			continue
		best = enemy
		best_distance = distance
	return best


## Nur Host: passendes Erz aus den Händen des Spielers nehmen und Munition auffüllen.
func _on_load_interacted(player: Player) -> void:
	if ammo >= _defense.max_ammo:
		return
	for chunk: OreChunk in player.carry.carried.duplicate():
		if chunk.ore == _defense.ammo_ore and ammo < _defense.max_ammo:
			chunk.queue_free()
			ammo = mini(_defense.max_ammo, ammo + _defense.ammo_per_load)


@rpc("authority", "call_local", "unreliable")
func _play_shot(aim: Vector3, loaded: bool) -> void:
	var flat := aim - _head.global_position
	flat.y = 0.0
	if flat.length_squared() > 0.001:
		_head.global_rotation = Vector3(0.0, atan2(-flat.x, -flat.z), 0.0)
	var from := _muzzle.global_position
	var length := from.distance_to(aim)
	if length < 0.01:
		return
	_tracer_material.albedo_color = LOADED_TRACER_COLOR if loaded else UNLOADED_TRACER_COLOR
	_tracer.global_transform = Transform3D(Basis.looking_at(aim - from) * Basis.from_scale(Vector3(1, 1, length)), (from + aim) / 2.0)
	_tracer.visible = true
	create_tween().tween_callback(func() -> void: _tracer.visible = false).set_delay(TRACER_TIME)


func _update_ammo_bar() -> void:
	var fraction := float(ammo) / float(_defense.max_ammo) if _defense and _defense.max_ammo > 0 else 0.0
	_ammo_fill.visible = fraction > 0.0
	_ammo_fill.scale.x = fraction
