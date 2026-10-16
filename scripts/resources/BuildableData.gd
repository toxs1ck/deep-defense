class_name BuildableData
extends Resource
## Ein Bauelement (Mauer, später Türme, Fallen …). Platziert wird auf dem 2-m-Raster (GDD, „Platzierung“).

@export var display_name: String = ""
## Szene des Bauelements; muss in der Spawnliste des BuildableSpawners in Main stehen.
@export var scene: PackedScene
## Abmessungen in Metern (Breite entlang lokal X, Höhe, Tiefe entlang lokal Z) für Vorschau und Platzprüfung.
@export var size: Vector3 = Vector3(2, 2, 2)
