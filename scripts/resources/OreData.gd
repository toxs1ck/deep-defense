class_name OreData
extends Resource
## Werte einer Erzart. Startwerte laut GDD, Abschnitt „Erzarten“.

## Gewichtsklasse beim Tragen (Aufgabe 6): leicht = 2 tragbar, schwer und sehr schwer verlangsamen.
enum Weight { LIGHT, MEDIUM, HEAVY, VERY_HEAVY }

@export var display_name: String = ""
## Verkaufswert pro Brocken in $.
@export var value: int = 0
## Schläge mit der Spitzhacke, bis ein Brocken herausfällt.
@export var hits_per_chunk: int = 1
## Wie viele Brocken ein Vorkommen hergibt, bevor es erschöpft ist.
@export var chunks_per_deposit: int = 1
@export var weight: Weight = Weight.LIGHT
## Farbe für Vorkommen und Brocken (Low-Poly, flache Farben).
@export var color: Color = Color.WHITE
