class_name PlayerData
extends Resource
## Bewegungswerte der Spielfigur. Startwerte laut GDD, Abschnitt „Startwerte“.

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 7.5
## Sprunghöhe in Metern; die Absprunggeschwindigkeit wird daraus berechnet.
@export var jump_height: float = 1.0
## Beschleunigung am Boden und in der Luft in m/s².
@export var acceleration: float = 40.0
@export var air_acceleration: float = 10.0
## Wie schnell sich das Modell in Laufrichtung dreht.
@export var turn_speed: float = 12.0
