class_name EnemyData
extends Resource
## Werte eines Gegnertyps. Startwerte laut GDD, Abschnitte „Gegnertypen“ und „Startwerte“.

@export var display_name: String = ""
@export var max_health: int = 30
## Laufgeschwindigkeit in m/s.
@export var speed: float = 4.0
## Schaden pro Angriff am Aufzug.
@export var elevator_damage: int = 5
## Sekunden zwischen zwei Angriffen am Aufzug.
@export var attack_interval: float = 1.0
@export var color: Color = Color.WHITE
