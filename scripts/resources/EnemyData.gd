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
## Schaden pro Angriff an Spielern.
@export var player_damage: int = 5
## Kommt ein Spieler näher, greift der Gegner ihn statt des Aufzugs an.
@export var aggro_range: float = 3.0
## So viel weiter darf sich der Spieler entfernen, bevor der Gegner von ihm ablässt.
@export var aggro_leash: float = 3.0
## Ab dieser Entfernung (Mitte zu Mitte) trifft der Gegner einen Spieler.
@export var player_attack_range: float = 1.4
@export var color: Color = Color.WHITE
