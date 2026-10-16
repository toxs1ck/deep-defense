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
## Schaden und Abstand ohne Munition (GDD: 25 % Schaden, halbe Feuerrate).
@export var unloaded_damage: int = 3
@export var unloaded_interval: float = 1.0
