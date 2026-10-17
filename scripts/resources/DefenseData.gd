class_name DefenseData
extends BuildableData
## Werte einer Verteidigung (Geschützturm, Klingenwirbel, Falle). Nicht jede nutzt alle Felder.
## Startwerte laut GDD, Abschnitte „Shop & Bauelemente“ und „Startwerte“.

## Reichweite bzw. Wirkradius in Metern.
@export var attack_range: float = 15.0
## Schaden pro Treffer und Sekunden zwischen zwei Treffern.
@export var damage: int = 10
@export var interval: float = 0.5
## Rückstoß getroffener Gegner in m/s.
@export var knockback: float = 1.0

@export_group("Munition")
## 0 = braucht keine Munition.
@export var max_ammo: int = 0
## Schuss pro geladenem Item.
@export var ammo_per_load: int = 30
## Womit geladen wird. Vorläufig ein Erzbrocken, bis es die Munitionswerkbank gibt.
@export var ammo_ore: OreData
## Schaden und Abstand ohne Munition bzw. Brennstoff (GDD: 25 % Schaden, halbe Feuerrate).
@export var unloaded_damage: int = 3
@export var unloaded_interval: float = 1.0

@export_group("Brennstoff")
## Laufzeit statt Schuss (Klingenwirbel): Ein Brocken fuel_ore gibt fuel_seconds_per_load Sekunden volle Leistung,
## gespeichert werden höchstens max_fuel_seconds (0 = braucht keinen Brennstoff). Die Zeit läuft nur in der
## Kampfphase ab. Ohne Brennstoff gelten unloaded_damage und unloaded_interval.
@export var fuel_ore: OreData
@export var fuel_seconds_per_load: float = 15.0
@export var max_fuel_seconds: float = 0.0

@export_group("Einmal-Auslösung")
## > 0: löst nur einmal aus und muss dann so viele Sekunden mit R neu gespannt werden (Stachelfalle).
@export var reset_hold_seconds: float = 0.0
## Sekunden zwischen dem ersten Gegner auf der Falle und dem Zuschnappen, damit Nachrückende mit erwischt werden.
@export var trigger_delay: float = 0.0
