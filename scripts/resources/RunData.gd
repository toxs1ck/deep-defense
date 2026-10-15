class_name RunData
extends Resource
## Ablauf eines Runs. Startwerte laut GDD, Abschnitt „Core Gameplay Loop“.

@export var rounds_per_run: int = 15
@export var boss_rounds: Array[int] = [5, 10, 15]
## Dauer der Kampfphase in Sekunden (GDD: 2–3 Minuten). Solange es keine Gegner gibt (Aufgabe 9 und 13),
## endet die Kampfphase nur über diese Zeit; später endet sie, wenn alle Gegner besiegt sind.
@export var combat_duration: float = 150.0
