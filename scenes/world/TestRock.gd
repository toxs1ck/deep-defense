extends StaticBody3D
## Platzhalter zum Testen der Interaktion, bis in Aufgabe 5 echte Erzvorkommen (OreDeposit) kommen.
## Der Host zählt die Schläge und verteilt den Stand an alle.

@onready var _interactable: InteractableComponent = $InteractableComponent
@onready var _label: Label3D = $Label3D

var _hits: int = 0


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(player: Player) -> void:
	_hits += 1
	_show_hits.rpc(_hits, String(player.name))


@rpc("authority", "call_local", "reliable")
func _show_hits(hits: int, peer_name: String) -> void:
	_label.text = "Schläge: %d\n(zuletzt Spieler %s)" % [hits, peer_name]
