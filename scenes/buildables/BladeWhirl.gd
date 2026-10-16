class_name BladeWhirl
extends Buildable
## Klingenwirbel: rotierender Flächenschaden auf kurze Distanz (GDD). Trifft alle Gegner im Wirkradius
## in festen Abständen und stößt sie etwas nach außen. Logik nur auf dem Host; die Klingen drehen sich überall.

const SPIN_SPEED: float = 9.0
const MAX_HEIGHT_DIFFERENCE: float = 1.5

@onready var _blades: Node3D = $Blades

var _defense: DefenseData
var _cooldown: float = 0.0


func _ready() -> void:
	super()
	_defense = data as DefenseData


func _process(delta: float) -> void:
	_blades.rotation.y += SPIN_SPEED * delta


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or health.is_dead():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = _defense.interval
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		var away := enemy.global_position - global_position
		if absf(away.y) > MAX_HEIGHT_DIFFERENCE or enemy.health.is_dead():
			continue
		away.y = 0.0
		if away.length() <= _defense.attack_range + Enemy.BODY_RADIUS:
			enemy.take_hit(_defense.damage, away.normalized() * _defense.knockback, null)
