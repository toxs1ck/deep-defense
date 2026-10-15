class_name OreData
extends Resource
## Werte einer Erzart. Startwerte laut GDD, Abschnitt „Erzarten“.

@export var display_name: String = ""
## Verkaufswert pro Brocken in $.
@export var value: int = 0
## Schläge mit der Spitzhacke, bis ein Brocken herausfällt.
@export var hits_per_chunk: int = 1
## Wie viele Brocken ein Vorkommen hergibt, bevor es erschöpft ist.
@export var chunks_per_deposit: int = 1
## Wie viele Brocken dieser Art ein Spieler gleichzeitig tragen kann (leicht = 2).
@export var carry_limit: int = 1
## Laufgeschwindigkeit beim Tragen (schwer 0,7, sehr schwer 0,5). Sprinten geht beim Tragen nie.
@export var carry_speed_multiplier: float = 1.0
## Farbe für Vorkommen und Brocken (Low-Poly, flache Farben).
@export var color: Color = Color.WHITE
