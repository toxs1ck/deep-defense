class_name InteractableComponent
extends Area3D
## Macht ein Objekt interagierbar: Spieler sehen es per Raycast, das HUD zeigt den Prompt.
## Braucht eine CollisionShape3D als Kind. Liegt auf Physik-Ebene 6 („interactable“).
## Ablauf: Spieler ruft request_interact() → RPC an den Host → Host prüft die Entfernung → Signal interacted.

## Wird nur auf dem Host gesendet. Das Objekt entscheidet dann selbst, was passiert, und verteilt das Ergebnis.
signal interacted(player: Player)
## Nur Host: Der Spieler hat die Taste hold_seconds lang gehalten (z. B. Kaufen im Shop).
signal hold_completed(player: Player)

## Spielraum für die Entfernungsprüfung auf dem Host, weil der Raycast die Oberfläche trifft,
## geprüft aber zur Mitte des Objekts wird; dazu kommt Netzwerk-Verzögerung.
const HOST_RANGE_TOLERANCE: float = 2.0
const INTERACTABLE_LAYER: int = 1 << 5

## Text im Prompt, z. B. „Abbauen“ → „E: Abbauen“.
@export var prompt_text: String = "Benutzen"
## Deaktiviert nimmt die Komponente auch die Physik-Ebene weg, damit der Raycast hindurchgeht
## (z. B. bei getragenen Brocken oder erschöpften Vorkommen).
@export var enabled: bool = true:
	set(value):
		enabled = value
		collision_layer = INTERACTABLE_LAYER if enabled else 0
## Zusätzliche Reichweite zu PlayerData.interaction_range, z. B. für Brocken am Boden, die von Augenhöhe weiter weg sind.
@export var extra_range: float = 0.0
## Nur anvisierbar, wenn der Spieler etwas trägt (z. B. „Erz einladen“ am Aufzug) bzw. nichts trägt (Abbauen).
@export var requires_carrying: bool = false
@export var requires_empty_hands: bool = false
## false: Nur Halten tut etwas (z. B. Abbauen); der Prompt zeigt dann nur die Halte-Aktion.
@export var tap_enabled: bool = true
## > 0: Halten löst nach so vielen Sekunden hold_completed aus; kurzes Tippen löst weiterhin interacted aus.
@export var hold_seconds: float = 0.0
## Text für das Halten, z. B. „Kaufen (60 $)“ → „E halten: Kaufen (60 $)“.
@export var hold_prompt: String = ""
## Mit welcher Aktion interagiert wird. „interact“ (E) für Aufheben, Einladen usw.; „attack“ (Linksklick) für
## Abbauen: Dann löst jeder Schlag mit der Spitzhacke die Interaktion aus, Halten schlägt im Takt weiter.
@export var action: StringName = &"interact"


func _ready() -> void:
	collision_layer = INTERACTABLE_LAYER if enabled else 0
	collision_mask = 0
	monitoring = false


## Vom lokalen Spieler aufgerufen. Läuft immer über den Host, auch wenn der Host selbst interagiert.
func request_interact() -> void:
	_interact_on_host.rpc_id(1)


## Vom lokalen Spieler, nachdem er die Taste hold_seconds lang gehalten hat.
func request_hold() -> void:
	_hold_on_host.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _hold_on_host() -> void:
	var player := _validated_sender()
	if player and hold_seconds > 0.0:
		hold_completed.emit(player)


@rpc("any_peer", "call_local", "reliable")
func _interact_on_host() -> void:
	var player := _validated_sender()
	if player:
		interacted.emit(player)


## Nur Host: Spieler hinter dem RPC, sofern die Komponente aktiv ist und er nah genug steht; sonst null.
func _validated_sender() -> Player:
	if not multiplayer.is_server() or not enabled:
		return null
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = multiplayer.get_unique_id()
	var player := _find_player(peer_id)
	if player == null:
		return null
	var max_distance := player.data.interaction_range + extra_range + HOST_RANGE_TOLERANCE
	if player.global_position.distance_to(global_position) > max_distance:
		return null
	return player


func _find_player(peer_id: int) -> Player:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		if node.name == str(peer_id):
			return node as Player
	return null
