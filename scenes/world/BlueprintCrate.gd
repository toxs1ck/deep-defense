class_name BlueprintCrate
extends Carryable
## Blaupausen-Kiste (wie in PlateUp). Als Shop-Angebot (is_offer) steht sie mit Preis auf einem Stellplatz:
## E tippen trägt sie herum, E halten kauft sie aus der Teamkasse. Nicht gekaufte Angebote verschwinden, wenn die
## Kampfphase beginnt. Gekauft baut man sie im Baumodus auf; abgebaute Bauelemente werden wieder zu solchen Kisten.

const OFFER_GROUP: StringName = &"shop_offers"
## So lange muss man E halten, um ein Angebot zu kaufen.
const BUY_HOLD_SECONDS: float = 3.0
## Getragene Kisten bremsen etwas, Sprinten geht beim Tragen ohnehin nicht.
const CARRY_SPEED_MULTIPLIER: float = 0.85
const OFFER_COLOR: Color = Color(0.85, 0.7, 0.3)
const OWNED_COLOR: Color = Color(0.62, 0.45, 0.25)

## Pfad zur BuildableData; wird beim Spawnen mitgeschickt.
@export var buildable_path: String = ""
## Noch nicht gekauftes Shop-Angebot. Vom Host gesetzt, an alle verteilt.
@export var is_offer: bool = false:
	set(value):
		is_offer = value
		if value:
			add_to_group(OFFER_GROUP)
		elif is_in_group(OFFER_GROUP):
			remove_from_group(OFFER_GROUP)
		if is_node_ready():
			_update_offer_state()

var buildable: BuildableData
## Nur Host: Zustand eines versetzten Bauelements (Lebenspunkte, Munition …), leer bei neu gekauften Kisten.
var stored_state: Dictionary = {}

@onready var _label: Label3D = $Label3D
var _material: StandardMaterial3D


func _setup_item() -> void:
	buildable = load(buildable_path) as BuildableData
	assert(buildable != null, "BlueprintCrate: ungültiger buildable_path '%s'" % buildable_path)
	_material = (_mesh.mesh as BoxMesh).material.duplicate() as StandardMaterial3D
	_mesh.material_override = _material
	_interactable.hold_completed.connect(_on_hold_completed)
	_update_offer_state()


func get_display_name() -> String:
	return "Kiste: %s" % buildable.display_name


func get_stack_key() -> Resource:
	return buildable


func get_carry_speed_multiplier() -> float:
	return CARRY_SPEED_MULTIPLIER


## Nur Host: lange genug gehalten, also kaufen, sofern Bauphase und genug Geld.
func _on_hold_completed(_player: Player) -> void:
	if not is_offer or RunManager.phase != RunManager.Phase.BUILD:
		return
	if Economy.try_spend(buildable.price):
		is_offer = false


func _update_offer_state() -> void:
	if is_offer:
		_label.text = "%s\n%d $" % [buildable.display_name, buildable.price]
		_interactable.hold_seconds = BUY_HOLD_SECONDS
		_interactable.hold_prompt = "Kaufen (%d $)" % buildable.price
		_material.albedo_color = OFFER_COLOR
	else:
		_label.text = buildable.display_name
		_interactable.hold_seconds = 0.0
		_interactable.hold_prompt = ""
		_material.albedo_color = OWNED_COLOR
