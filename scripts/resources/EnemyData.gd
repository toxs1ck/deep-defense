class_name EnemyData
extends Resource
## Werte eines Gegnertyps. Startwerte laut GDD, Abschnitte „Gegnertypen“ und „Startwerte“.

@export var display_name: String = ""
@export var max_health: int = 30
## Laufgeschwindigkeit in m/s.
@export var speed: float = 4.0
## Schaden pro Angriff am Aufzug.
@export var elevator_damage: int = 5
## Sekunden zwischen zwei Angriffen (nach dem Zuschlagen bis zum nächsten Ausholen).
@export var attack_interval: float = 1.0
## Ausholphase vor jedem Schlag in Sekunden: Der Gegner zeigt den Angriff an, man kann ausweichen.
@export var attack_windup: float = 0.6
## Tempo während des Ausholens, als Anteil von speed: Er rückt weiter nach, man muss also aktiv ausweichen.
@export var windup_speed_multiplier: float = 0.5
## Beim Zuschlagen trifft er Spieler noch bis player_attack_range plus diesen Spielraum.
@export var attack_hit_margin: float = 0.3
## So lange braucht er nach einem Treffer, der sein Ausholen unterbricht, bis er neu ansetzt.
@export var stagger_time: float = 0.4
## Schaden pro Angriff an Spielern.
@export var player_damage: int = 5
## Kommt ein Spieler näher, greift der Gegner ihn statt des Aufzugs an.
@export var aggro_range: float = 3.0
## So viel weiter darf sich der Spieler entfernen, bevor der Gegner von ihm ablässt.
@export var aggro_leash: float = 3.0
## Ab dieser Entfernung (Mitte zu Mitte) trifft der Gegner einen Spieler.
@export var player_attack_range: float = 1.4
@export var color: Color = Color.WHITE
