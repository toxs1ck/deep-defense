class_name BladeWhirl
extends Buildable
## Klingenwirbel: rotierender Flächenschaden auf kurze Distanz (GDD). Trifft alle Gegner im Wirkradius
## in festen Abständen und stößt sie etwas nach außen.
## Läuft mit Brennstoff (Kohle, E während man sie trägt): Ein Brocken gibt DefenseData.fuel_seconds_per_load Sekunden
## volle Leistung. Die Zeit läuft nur in der Kampfphase ab, in der Bauphase pausiert sie. Ohne Brennstoff dreht er
## langsamer und trifft schwächer (DefenseData.unloaded_*), wie der Geschützturm ohne Munition.
## Logik nur auf dem Host; die Restlaufzeit kommt per MultiplayerSynchronizer, die Klingen drehen sich überall.

const SPIN_SPEED: float = 9.0
const MAX_HEIGHT_DIFFERENCE: float = 1.5

## Restlaufzeit in ganzen Sekunden (aufgerundet), vom Host gesetzt und verteilt. Nur bei Änderung, nicht pro Frame.
@export var fuel: int = 0:
	set(value):
		fuel = value
		if is_node_ready():
			_update_fuel_bar()

@onready var _blades: Node3D = $Blades
@onready var _fuel_fill: Sprite3D = $FuelBar/Fill
@onready var _load_interactable: InteractableComponent = $LoadInteractable

var _defense: DefenseData
var _cooldown: float = 0.0
## Nur Host: genaue Restlaufzeit.
var _fuel_left: float = 0.0


func _ready() -> void:
	super()
	_defense = data as DefenseData
	_fuel_left = maxf(_fuel_left, fuel)
	_load_interactable.prompt_text = "%s nachlegen (%d s)" % [_defense.fuel_ore.display_name, roundi(_defense.fuel_seconds_per_load)]
	_load_interactable.interacted.connect(_on_load_interacted)
	_update_fuel_bar()


func _process(delta: float) -> void:
	# Ohne Brennstoff dreht er im Verhältnis der Trefferabstände langsamer.
	var speed := SPIN_SPEED if fuel > 0 else SPIN_SPEED * _defense.interval / _defense.unloaded_interval
	_blades.rotation.y += speed * delta


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or health.is_dead():
		return
	if _fuel_left > 0.0 and RunManager.phase == RunManager.Phase.COMBAT:
		_set_fuel_left(_fuel_left - delta)
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var fueled := _fuel_left > 0.0
	_cooldown = _defense.interval if fueled else _defense.unloaded_interval
	var amount := _defense.damage if fueled else _defense.unloaded_damage
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		var away := enemy.global_position - global_position
		if absf(away.y) > MAX_HEIGHT_DIFFERENCE or enemy.health.is_dead():
			continue
		away.y = 0.0
		if away.length() <= _defense.attack_range + Enemy.BODY_RADIUS:
			enemy.take_hit(amount, away.normalized() * _defense.knockback, null, global_position)


func get_state() -> Dictionary:
	var state := super()
	state["fuel"] = _fuel_left
	return state


func apply_state(state: Dictionary) -> void:
	super(state)
	_fuel_left = state.get("fuel", 0.0)
	fuel = ceili(_fuel_left)


## Nur Host: Kohle aus den Händen des Spielers nehmen, solange noch Platz ist.
func _on_load_interacted(player: Player) -> void:
	for item: Carryable in player.carry.carried.duplicate():
		var chunk := item as OreChunk
		if chunk and chunk.ore == _defense.fuel_ore and _fuel_left + _defense.fuel_seconds_per_load <= _defense.max_fuel_seconds + 0.01:
			chunk.queue_free()
			_set_fuel_left(_fuel_left + _defense.fuel_seconds_per_load)


func _set_fuel_left(value: float) -> void:
	_fuel_left = clampf(value, 0.0, _defense.max_fuel_seconds)
	var whole := ceili(_fuel_left)
	if whole != fuel:
		fuel = whole


func _update_fuel_bar() -> void:
	var fraction := float(fuel) / _defense.max_fuel_seconds if _defense and _defense.max_fuel_seconds > 0.0 else 0.0
	_fuel_fill.visible = fraction > 0.0
	_fuel_fill.scale.x = fraction
