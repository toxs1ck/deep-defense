class_name EnemyData
extends Resource
## Werte eines Gegnertyps. Startwerte laut GDD, Abschnitte „Gegnertypen“ und „Startwerte“.

@export var display_name: String = ""
## Kosten im Wellen-Budget und ab welcher Schicht der Typ vorkommt (GDD, „Gegnertypen“ und „Wellen-Design“).
@export var cost: int = 4
@export var first_round: int = 1
## Erzdieb: sucht liegendes Erz, stiehlt es und flieht zum nächsten Eingang. Greift Spieler nie an; ohne
## liegendes Erz geht er wie die anderen zum Aufzug.
@export var steals_ore: bool = false
## Tempo beim Fliehen mit Beute, als Anteil von speed.
@export var loot_speed_multiplier: float = 0.8
## Getroffen lässt der Erzdieb die Beute fallen und flieht so viele Sekunden (zufällig dazwischen) vom
## Verursacher weg, möglichst an einen Platz außer Sicht. Währenddessen stiehlt er nicht.
@export var flee_time_min: float = 3.0
@export var flee_time_max: float = 5.0
## Wie weit er sich dabei ungefähr entfernt, in Metern.
@export var flee_distance: float = 10.0
## Erzdieb: Spielern in diesem Umkreis weicht er im Bogen aus; 0 = gar nicht. Die Stärke gewichtet das Ausweichen
## gegen die Laufrichtung (1 = gleich stark wie der Weg, wenn der Spieler direkt neben ihm steht).
@export var player_avoid_radius: float = 0.0
@export var player_avoid_strength: float = 1.5
## Größe des Modells (die Kollision bleibt gleich).
@export var model_scale: float = 1.0
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
## Schaden pro Angriff an Bauelementen (wenn der Weg zum Aufzug zugebaut ist).
@export var building_damage: int = 10
## Schaden pro Angriff an Spielern.
@export var player_damage: int = 5
## Kommt ein Spieler näher, greift der Gegner ihn statt des Aufzugs an.
@export var aggro_range: float = 3.0
## So viel weiter darf sich der Spieler entfernen, bevor der Gegner von ihm ablässt.
@export var aggro_leash: float = 3.0
## Ab dieser Entfernung (Mitte zu Mitte) trifft der Gegner einen Spieler.
@export var player_attack_range: float = 1.4
@export var color: Color = Color.WHITE
