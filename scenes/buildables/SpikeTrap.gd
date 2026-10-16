class_name SpikeTrap
extends Buildable
## Stachelfalle: flach im Boden, versperrt nichts. Betreten Gegner sie und ist sie bereit, schießen die Stacheln
## hoch und treffen alle Gegner darauf; danach lädt sie data.interval Sekunden nach.
## Erkennung nur auf dem Host; das Hochschnellen zeigt ein RPC bei allen.

const SPIKES_DOWN_Y: float = -0.35
const SPIKES_UP_Y: float = 0.0

@onready var _trigger: Area3D = $Trigger
@onready var _spikes: Node3D = $Spikes

var _defense: DefenseData
var _cooldown: float = 0.0


func _ready() -> void:
	super()
	_defense = data as DefenseData
	_trigger.monitoring = multiplayer.is_server()
	_spikes.position.y = SPIKES_DOWN_Y


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or health.is_dead():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var victims: Array[Enemy] = []
	for body in _trigger.get_overlapping_bodies():
		var enemy := body as Enemy
		if enemy and not enemy.health.is_dead():
			victims.append(enemy)
	if victims.is_empty():
		return
	_cooldown = _defense.interval
	for enemy in victims:
		enemy.take_hit(_defense.damage, Vector3.ZERO, null, global_position)
	_play_trigger.rpc()


@rpc("authority", "call_local", "unreliable")
func _play_trigger() -> void:
	var tween := create_tween()
	tween.tween_property(_spikes, "position:y", SPIKES_UP_Y, 0.05)
	tween.tween_interval(0.35)
	tween.tween_property(_spikes, "position:y", SPIKES_DOWN_Y, 0.3)
