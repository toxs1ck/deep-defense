class_name CaveModule
extends Node3D
## Baustein der Mine aus Kenneys Cave Kit (assets/kenney-cave-kit, CC0). Unter „Kit“ liegen die Modelle, doppelt so
## groß wie im Kit: Ein Rasterfeld ist dort 4 m, hier 8 m, damit Gänge zu Spielfigur und Gegnern passen.
## Dazu kommen Marker wie Erzstellen (ore_spawn_points), Gegner-Eingänge (enemy_spawns) und Lichter.
## Ausgänge liegen als Marker3D unter „Exits“ auf der Modulkante, −Z zeigt aus dem Modul hinaus. Daran setzt später
## der Kartengenerator die Module zusammen; in einer handgebauten Karte müssen sich die Ausgänge genau treffen.
## Die Modelle selbst haben keine Kollision. Unter „Collision“ liegen stattdessen einfache Formen: eine flache Box als
## Boden, Boxen entlang des vereinfachten Wandumrisses und grobe Formen für die Deko. Das hält Physik und
## Navigationsnetz glatt (nichts bleibt an Felsnasen oder Bodensteinen hängen); die Formen lassen sich im Editor
## nachjustieren.

## Kantenlänge eines Rasterfelds in Metern.
const CELL_SIZE: float = 8.0

## Größe in Rasterfeldern (für den Generator).
@export var footprint: Vector2i = Vector2i.ONE


## Ausgänge des Moduls; −Z jedes Markers zeigt nach außen.
func get_exits() -> Array[Marker3D]:
	var exits: Array[Marker3D] = []
	var parent := get_node_or_null(^"Exits")
	if parent:
		for child in parent.get_children():
			if child is Marker3D:
				exits.append(child as Marker3D)
	return exits
