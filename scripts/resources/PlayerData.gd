class_name PlayerData
extends Resource
## Bewegungswerte der Spielfigur. Startwerte laut GDD, Abschnitt „Startwerte“.

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 7.5
## Sprunghöhe in Metern; die Absprunggeschwindigkeit wird daraus berechnet.
@export var jump_height: float = 1.0
## Wie lange nach dem Verlassen einer Kante noch gesprungen werden kann, in Sekunden („Coyote Time“).
@export var coyote_time: float = 0.12
## Wie lange ein zu früh gedrückter Sprung gemerkt wird und bei der Landung ausgelöst wird, in Sekunden.
@export var jump_buffer_time: float = 0.12
## Faktor auf die Projekt-Schwerkraft. Höher = kürzere Zeit in der Luft bei gleicher Sprunghöhe.
@export var gravity_scale: float = 1.5
## Zusätzlicher Faktor beim Fallen, damit Sprünge nicht schweben.
@export var fall_gravity_multiplier: float = 1.3
## Beschleunigung beim Loslaufen und Abbremsen am Boden sowie in der Luft, in m/s².
@export var acceleration: float = 60.0
@export var deceleration: float = 80.0
@export var air_acceleration: float = 30.0
## Wie schnell sich das Modell in Laufrichtung dreht.
@export var turn_speed: float = 20.0
## Reichweite für Interaktionen in Metern, gemessen ab Augenhöhe.
@export var interaction_range: float = 1.25
## Schläge pro Sekunde mit der Spitzhacke, beim Abbauen wie im Kampf (GDD: 1,5).
@export var swing_rate: float = 1.5
## Schaden der Spitzhacke pro Treffer (GDD: 15).
@export var attack_damage: int = 15
## Reichweite eines Schlags in Metern, gemessen von der Mitte der Figur.
@export var attack_range: float = 1.8
## Wie stark getroffene Gegner zurückgestoßen werden, in m/s.
@export var attack_knockback: float = 6.0
@export var max_health: int = 100
## Sekunden bis zum Respawn am Aufzug (GDD: 10).
@export var respawn_time: float = 10.0
## Wurfgeschwindigkeit für getragene Brocken in m/s.
@export var throw_speed: float = 8.0
