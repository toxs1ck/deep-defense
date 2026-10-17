class_name BuildableData
extends Resource
## Ein Bauelement (Mauer, später Türme, Fallen …). Platziert wird auf dem 2-m-Raster (GDD, „Platzierung“).

@export var display_name: String = ""
## Szene des Bauelements; muss in der Spawnliste des BuildableSpawners in Main stehen.
@export var scene: PackedScene
## Abmessungen in Metern (Breite entlang lokal X, Höhe, Tiefe entlang lokal Z) für Vorschau und Platzprüfung.
@export var size: Vector3 = Vector3(2, 2, 2)
## Lebenspunkte; Gegner greifen Bauelemente an, wenn sie den Aufzug sonst nicht erreichen.
@export var max_health: int = 150
## Preis im Shop in $.
@export var price: int = 20
## Ob das Bauelement den Weg versperrt (Mauer, Turm). Fallen tun das nicht und werden nie angegriffen.
@export var blocks_path: bool = true
## Darf in den Fels ragen (nur die Mitte muss frei sein), damit man Gänge bis an die Höhlenwand schließen kann.
@export var embeds_in_rock: bool = false
