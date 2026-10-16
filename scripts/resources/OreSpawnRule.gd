class_name OreSpawnRule
extends Resource
## Wo und wie oft eine Erzart auf den Erzstellen erscheint. Tiefe 0 = Stelle mit dem kürzesten Weg zum Aufzug,
## 1 = mit dem längsten (Weglänge über das Navigationsnetz, GDD: wertvolleres Erz liegt tiefer).

@export var ore: OreData
@export_range(0.0, 1.0) var min_depth: float = 0.0
@export_range(0.0, 1.0) var max_depth: float = 1.0
## Relatives Gewicht unter allen Erzarten, die für eine Stelle in Frage kommen.
@export var weight: float = 1.0
## Ab welcher Schicht diese Erzart vorkommt (GDD: Kristall ab Runde 6).
@export var first_round: int = 1
