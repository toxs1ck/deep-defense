class_name InteractableComponent
extends Area3D
## Macht ein Objekt interagierbar: Spieler sehen es per Raycast, das HUD zeigt den Prompt.
## Braucht eine CollisionShape3D als Kind. Liegt auf Physik-Ebene 6 („interactable“).
## Ablauf: Spieler ruft request_interact() → RPC an den Host → Host prüft die Entfernung → Signal interacted.

## Wird nur auf dem Host gesendet. Das Objekt entscheidet dann selbst, was passiert, und verteilt das Ergebnis.
signal interacted(player: Player)

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
## Gedrückt halten wiederholt die Interaktion im Takt der Abbaurate des Spielers (z. B. Abbauen).
@export var allow_hold: bool = false


func _ready() -> void:
	collision_layer = INTERACTABLE_LAYER if enabled else 0
	collision_mask = 0
	monitoring = false


## Vom lokalen Spieler aufgerufen. Läuft immer über den Host, auch wenn der Host selbst interagiert.
func request_interact() -> void:
	_interact_on_host.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _interact_on_host() -> void:
	if not multiplayer.is_server() or not enabled:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = multiplayer.get_unique_id()
	var player := _find_player(peer_id)
	if player == null:
		return
	var max_distance := player.data.interaction_range + extra_range + HOST_RANGE_TOLERANCE
	if player.global_position.distance_to(global_position) > max_distance:
		return
	interacted.emit(player)


func _find_player(peer_id: int) -> Player:
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		if node.name == str(peer_id):
			return node as Player
	return null
