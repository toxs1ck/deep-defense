class_name ShopMenu
extends Control
## Shop-Fenster: zeigt die Angebote der Schicht, Kaufen und Neu würfeln. Sperrt solange die Eingaben der Figur.
## Meldet Wünsche per Signal nach oben; schließt sich von selbst, wenn die Bauphase endet.

signal buy_requested(index: int)
signal reroll_requested

@onready var _offer_list: VBoxContainer = %OfferList
@onready var _reroll_button: Button = %RerollButton
@onready var _close_button: Button = %CloseButton
@onready var _money_label: Label = %ShopMoneyLabel

var _offers: Array[BuildableData] = []
var _sold: Array[bool] = []
var _reroll_cost: int = 0


func _ready() -> void:
	visible = false
	_reroll_button.pressed.connect(func() -> void: reroll_requested.emit())
	_close_button.pressed.connect(close)
	RunManager.phase_changed.connect(_on_phase_changed)
	Economy.money_changed.connect(func(_amount: int) -> void: _refresh())


func open() -> void:
	if RunManager.phase != RunManager.Phase.BUILD:
		return
	visible = true
	GameState.input_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	_reroll_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	GameState.input_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Der Shop schließt, sobald die Welle startet (GDD).
func _on_phase_changed(phase: int) -> void:
	if phase != RunManager.Phase.BUILD:
		close()


func set_offers(offers: Array[BuildableData], sold: Array[bool], reroll_cost: int) -> void:
	_offers = offers.duplicate()
	_sold = sold.duplicate()
	_reroll_cost = reroll_cost
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	_money_label.text = "Teamkasse: %d $" % Economy.team_money
	for child in _offer_list.get_children():
		child.queue_free()
	for i in _offers.size():
		var offer := _offers[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 40)
		if _sold[i]:
			button.text = "%s – gekauft" % offer.display_name
			button.disabled = true
		else:
			button.text = "%s – %d $" % [offer.display_name, offer.price]
			button.disabled = Economy.team_money < offer.price
			button.pressed.connect(func() -> void: buy_requested.emit(i))
		_offer_list.add_child(button)
	_reroll_button.text = "Neu würfeln (%d $)" % _reroll_cost
	_reroll_button.disabled = Economy.team_money < _reroll_cost
