class_name OreSpawnData
extends Resource
## Verteilung der Erzvorkommen. Zu Beginn jeder Kampfphase brechen auf einem Teil der Erzstellen neue Adern auf;
## am Ende der Kampfphase stürzen sie wieder ein.

@export var rules: Array[OreSpawnRule] = []

@export_group("Belegung")
## Anteil der Erzstellen, die belegt werden: Start plus Zuwachs pro Schicht, gedeckelt.
@export_range(0.0, 1.0) var occupancy_start: float = 0.4
@export var occupancy_per_round: float = 0.06
@export_range(0.0, 1.0) var occupancy_max: float = 1.0

@export_group("Sonderschichten")
## Chance pro Schicht (ab special_from_round) auf „Reiche Ader“ oder „Taube Schicht“, je zur Hälfte.
@export_range(0.0, 1.0) var special_chance: float = 0.2
@export var special_from_round: int = 3
## Reiche Ader: mehr Stellen belegt, und die Erze verhalten sich, als lägen sie tiefer (seltener).
@export var rich_occupancy_bonus: float = 0.3
@export var rich_depth_bonus: float = 0.25
## Taube Schicht: weniger Stellen belegt.
@export var barren_occupancy_malus: float = 0.25
