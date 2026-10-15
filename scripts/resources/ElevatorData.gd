class_name ElevatorData
extends Resource
## Werte des Aufzugs. Startwerte laut GDD, Abschnitt „Aufzug und Auszahlung“.

## Wie viele Items pro Runde in den Korb passen.
@export var capacity: int = 20
## Bonus auf die Auszahlung bei voller oder gemischter Ladung (0,1 = +10 %). Gilt einmal, nicht doppelt.
@export var load_bonus: float = 0.1
## Ab so vielen verschiedenen Erzarten zählt eine Ladung als gemischt.
@export var mixed_ore_types_for_bonus: int = 3
