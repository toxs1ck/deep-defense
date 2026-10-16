class_name BlueprintCrate
extends Carryable
## Blaupausen-Kiste (GDD, wie in PlateUp): Gekauftes erscheint als Kiste am Aufzug; ein Spieler trägt sie zum
## Bauplatz und baut sie im Baumodus auf. Abgebaute Bauelemente werden wieder zur Kiste, so lassen sie sich versetzen.

## Getragene Kisten bremsen etwas, Sprinten geht beim Tragen ohnehin nicht.
const CARRY_SPEED_MULTIPLIER: float = 0.85

## Pfad zur BuildableData; wird beim Spawnen mitgeschickt.
@export var buildable_path: String = ""

var buildable: BuildableData

@onready var _label: Label3D = $Label3D


func _setup_item() -> void:
	buildable = load(buildable_path) as BuildableData
	assert(buildable != null, "BlueprintCrate: ungültiger buildable_path '%s'" % buildable_path)
	_label.text = buildable.display_name


func get_display_name() -> String:
	return "Kiste: %s" % buildable.display_name


func get_stack_key() -> Resource:
	return buildable


func get_carry_speed_multiplier() -> float:
	return CARRY_SPEED_MULTIPLIER
