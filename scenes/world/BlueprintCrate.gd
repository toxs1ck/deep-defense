class_name BlueprintCrate
extends Carryable
## Blaupausen-Kiste (wie in PlateUp). Als Shop-Angebot (is_offer) steht sie mit Preis auf einem Stellplatz:
## E tippen trägt sie herum, E halten kauft sie aus der Teamkasse, in der Hand kauft R halten. Nicht gekaufte Angebote verschwinden, wenn die
## Kampfphase beginnt. Gekauft baut man sie im Baumodus auf; abgebaute Bauelemente werden wieder zu solchen Kisten.

const OFFER_GROUP: StringName = &"shop_offers"
## So lange muss man E halten, um ein Angebot zu kaufen.
const BUY_HOLD_SECONDS: float = 2.0
## Getragene Kisten bremsen etwas, Sprinten geht beim Tragen ohnehin nicht.
const CARRY_SPEED_MULTIPLIER: float = 0.85

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
## Angebote stehen als Truhe im Shop, gekaufte Bauelemente als einfache Kiste (Kenney Survival Kit).
@onready var _box: Node3D = $Mesh/Box
@onready var _chest: Node3D = $Mesh/Chest


func _setup_item() -> void:
	buildable = load(buildable_path) as BuildableData
	assert(buildable != null, "BlueprintCrate: ungültiger buildable_path '%s'" % buildable_path)
	_interactable.hold_completed.connect(_on_hold_completed)
	_update_offer_state()


func get_display_name() -> String:
	return "Kiste: %s" % buildable.display_name


func get_stack_key() -> Resource:
	return buildable


func get_carry_speed_multiplier() -> float:
	return CARRY_SPEED_MULTIPLIER


## Vom lokalen Spieler, der die Kiste trägt und R lange genug gehalten hat.
func request_purchase() -> void:
	_purchase_carried_on_host.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _purchase_carried_on_host() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	# Nur wer die Kiste trägt, kauft sie so.
	if sender == carrier_id:
		_try_purchase(_find_player(sender))


## Nur Host: am Stellplatz lange genug E gehalten.
func _on_hold_completed(player: Player) -> void:
	_try_purchase(player)


## Nur Host: kaufen, sofern Bauphase und genug Geld. Mit freien Händen landet die Kiste direkt beim Käufer
## (und damit im Baumodus).
func _try_purchase(player: Player) -> void:
	if player == null or not is_offer or RunManager.phase != RunManager.Phase.BUILD:
		return
	if not Economy.try_spend(buildable.price):
		return
	is_offer = false
	if carrier_id == 0 and not player.carry.is_carrying():
		carrier_id = player.get_multiplayer_authority()


func _update_offer_state() -> void:
	_box.visible = not is_offer
	_chest.visible = is_offer
	if is_offer:
		_label.text = "%s\n%d $" % [buildable.display_name, buildable.price]
		_interactable.hold_seconds = BUY_HOLD_SECONDS
		_interactable.hold_prompt = "Kaufen (%d $)" % buildable.price
	else:
		_label.text = buildable.display_name
		_interactable.hold_seconds = 0.0
		_interactable.hold_prompt = ""

