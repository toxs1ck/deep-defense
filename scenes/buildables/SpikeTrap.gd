class_name SpikeTrap
extends Buildable
## Stachelfalle: flach im Boden, versperrt nichts. Betritt ein Gegner sie, während sie gespannt ist, klickt sie
## (Stacheln zucken ein Stück hoch) und schnappt nach DefenseData.trigger_delay zu: Alle Gegner, die dann darauf
## stehen, bekommen hohen Schaden – aber nur einmal. Danach bleiben die Stacheln
## oben, bis ein Spieler sie neu spannt (R halten, DefenseData.reset_hold_seconds).
## Erkennung nur auf dem Host; ob sie gespannt ist, kommt per MultiplayerSynchronizer.

const SPIKES_DOWN_Y: float = -0.35
const SPIKES_UP_Y: float = 0.0
## So weit zucken die Stacheln beim Klicken hoch (Warnung, dass die Falle gleich zuschnappt).
const SPIKES_PRIMED_Y: float = -0.25

## Gespannt = bereit zum Auslösen. Vom Host gesetzt und verteilt.
@export var armed: bool = true:
	set(value):
		var triggered := armed and not value
		armed = value
		if is_node_ready():
			_update_armed(triggered)

@onready var _trigger: Area3D = $Trigger
@onready var _spikes: Node3D = $Spikes

var _defense: DefenseData
var _spikes_tween: Tween = null
## Nur Host: Restzeit bis zum Zuschnappen; < 0 = nicht ausgelöst.
var _snap_left: float = -1.0


func _ready() -> void:
	super()
	_defense = data as DefenseData
	_trigger.monitoring = multiplayer.is_server()
	_dismantle.secondary_hold_completed.connect(_on_reset)
	_spikes.position.y = SPIKES_DOWN_Y if armed else SPIKES_UP_Y
	_update_armed(false)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or health.is_dead() or not armed:
		return
	var victims := _victims()
	if _snap_left < 0.0:
		if victims.is_empty():
			return
		_snap_left = _defense.trigger_delay
		_play_primed.rpc()
	_snap_left -= delta
	if _snap_left > 0.0:
		return
	_snap_left = -1.0
	for enemy in victims:
		enemy.take_hit(_defense.damage, Vector3.ZERO, null, global_position)
	armed = false


func _victims() -> Array[Enemy]:
	var victims: Array[Enemy] = []
	for body in _trigger.get_overlapping_bodies():
		var enemy := body as Enemy
		if enemy and not enemy.health.is_dead():
			victims.append(enemy)
	return victims


func get_state() -> Dictionary:
	var state := super()
	state["armed"] = armed
	return state


func apply_state(state: Dictionary) -> void:
	super(state)
	armed = state.get("armed", true)


@rpc("authority", "call_local", "reliable")
func _play_primed() -> void:
	if _spikes_tween:
		_spikes_tween.kill()
	_spikes_tween = create_tween()
	_spikes_tween.tween_property(_spikes, "position:y", SPIKES_PRIMED_Y, 0.08)


## Nur Host: R lange genug gehalten.
func _on_reset(_player: Player) -> void:
	armed = true


func _update_armed(triggered: bool) -> void:
	# Neu spannen geht nur, wenn sie ausgelöst ist; der Prompt erscheint dann neben „Abbauen“.
	_dismantle.secondary_hold_seconds = 0.0 if armed else _defense.reset_hold_seconds
	_dismantle.secondary_hold_prompt = "" if armed else "Falle spannen"
	if _spikes_tween:
		_spikes_tween.kill()
	_spikes_tween = create_tween()
	if armed:
		_spikes_tween.tween_property(_spikes, "position:y", SPIKES_DOWN_Y, 0.3)
	elif triggered:
		_spikes_tween.tween_property(_spikes, "position:y", SPIKES_UP_Y, 0.05)
	else:
		_spikes.position.y = SPIKES_UP_Y
