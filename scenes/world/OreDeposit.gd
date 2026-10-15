class_name OreDeposit
extends StaticBody3D
## Erzvorkommen: Nach ore.hits_per_chunk Schlägen fällt ein Brocken heraus, nach ore.chunks_per_deposit
## Brocken ist es erschöpft. Der Host zählt und verteilt den Stand; jeder Treffer gibt Feedback bei allen.
## Brocken spawnt das Vorkommen nicht selbst, es meldet sie per Signal nach oben.

## Nur auf dem Host: ein Brocken ist abgebrochen und soll an spawn_position mit impulse erscheinen.
signal chunk_broken_off(ore: OreData, spawn_position: Vector3, impulse: Vector3)

const GROUP: StringName = &"ore_deposits"
## Der Host lässt Schläge etwas schneller zu als die Schlagrate, damit Netzwerk-Schwankungen nicht schlucken.
const HIT_RATE_TOLERANCE: float = 0.85
## Varianz beim Herausspringen: seitliche Abweichung in Grad, Steigung (Anteil nach oben) und Wucht in m/s.
const LAUNCH_SPREAD_DEGREES: float = 40.0
const LAUNCH_LIFT_MIN: float = 1.1
const LAUNCH_LIFT_MAX: float = 2.0
const LAUNCH_SPEED_MIN: float = 1.6
const LAUNCH_SPEED_MAX: float = 2.8

@export var ore: OreData

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _sparks: CPUParticles3D = $Sparks

var _hits: int = 0
var _chunks_left: int = 0
var _mesh_scale: Vector3 = Vector3.ONE
var _scale_tween: Tween = null
## Nur Host: Zeitpunkt des letzten angenommenen Schlags pro Spieler (Node-Name → Sekunden).
var _last_hit_time: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	assert(ore != null, "OreDeposit braucht eine OreData-Resource")
	_chunks_left = ore.chunks_per_deposit
	var material := StandardMaterial3D.new()
	material.albedo_color = ore.color
	_mesh.material_override = material
	_interactable.prompt_text = "%s abbauen" % ore.display_name
	_interactable.interacted.connect(_on_interacted)
	NetworkManager.player_joined.connect(_on_player_joined)
	_apply_state()


func _on_interacted(player: Player) -> void:
	# Wer trägt, hat die Hände voll und kann nicht abbauen.
	if _chunks_left <= 0 or player.carry.is_carrying():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var min_interval := HIT_RATE_TOLERANCE / player.data.mining_rate
	var last_hit: float = _last_hit_time.get(player.name, -INF)
	if now - last_hit < min_interval:
		return
	_last_hit_time[player.name] = now

	_hits += 1
	if _hits >= ore.hits_per_chunk:
		_hits = 0
		_chunks_left -= 1
		# Der Brocken springt in Richtung des Spielers heraus, damit er nicht hinter dem Vorkommen landet.
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		var direction := to_player.normalized() if to_player.length_squared() > 0.01 else Vector3.FORWARD
		chunk_broken_off.emit(ore, global_position + Vector3.UP * 1.2 + direction * 0.5, _random_launch_velocity(direction))
	_on_hit.rpc(_hits, _chunks_left)


## Grob in Richtung des Spielers, aber jedes Mal etwas anders. Zufall über GameState.rng, nur auf dem Host.
func _random_launch_velocity(toward: Vector3) -> Vector3:
	var rng := GameState.rng
	var spread := deg_to_rad(rng.randf_range(-LAUNCH_SPREAD_DEGREES, LAUNCH_SPREAD_DEGREES))
	var horizontal := toward.rotated(Vector3.UP, spread)
	var lift := rng.randf_range(LAUNCH_LIFT_MIN, LAUNCH_LIFT_MAX)
	return (horizontal + Vector3.UP * lift) * rng.randf_range(LAUNCH_SPEED_MIN, LAUNCH_SPEED_MAX)


## Später beitretende Spieler bekommen den aktuellen Stand direkt vom Host.
func _on_player_joined(peer_id: int) -> void:
	if multiplayer.is_server() and peer_id != multiplayer.get_unique_id():
		_sync_state.rpc_id(peer_id, _hits, _chunks_left)


@rpc("authority", "call_local", "reliable")
func _sync_state(hits: int, chunks_left: int) -> void:
	_hits = hits
	_chunks_left = chunks_left
	_apply_state()


## Zustand und Feedback in einer Nachricht, damit die Wackel-Animation schon auf der neuen Größe endet.
@rpc("authority", "call_local", "reliable")
func _on_hit(hits: int, chunks_left: int) -> void:
	_sync_state(hits, chunks_left)
	if _chunks_left <= 0:
		return
	_sparks.restart()
	_scale_tween = create_tween()
	_mesh.scale = _mesh_scale * 1.08
	_scale_tween.tween_property(_mesh, "scale", _mesh_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Das Vorkommen schrumpft mit jedem Brocken und verschwindet, wenn es erschöpft ist.
func _apply_state() -> void:
	if _scale_tween:
		_scale_tween.kill()
	var depleted := _chunks_left <= 0
	_mesh.visible = not depleted
	_collision.disabled = depleted
	_interactable.enabled = not depleted
	var fullness := float(_chunks_left) / float(ore.chunks_per_deposit)
	_mesh_scale = Vector3.ONE * lerpf(0.6, 1.0, fullness)
	_mesh.scale = _mesh_scale
