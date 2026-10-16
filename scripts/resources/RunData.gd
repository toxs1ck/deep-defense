class_name RunData
extends Resource
## Ablauf eines Runs. Startwerte laut GDD, Abschnitt „Core Gameplay Loop“.

@export var rounds_per_run: int = 15
@export var boss_rounds: Array[int] = [5, 10, 15]

## Geld in der Teamkasse zu Beginn eines Runs.
@export var starting_money: int = 60

@export_group("Shop")
## Woraus der Bauelemente-Shop jede Schicht zieht (GDD: 4 Angebote, neu würfeln 20 $, jedes weitere Mal +10 $).
@export var shop_pool: Array[BuildableData] = []
@export var shop_offer_count: int = 4
@export var reroll_base_cost: int = 20
@export var reroll_cost_step: int = 10

@export_group("Wellen")
## Punkte-Budget pro Welle: wave_budget_base × Schicht ^ wave_budget_exponent (GDD: 20 × Runde^1,2).
## Jeder Gegner kostet EnemyData.cost.
@export var wave_budget_base: float = 20.0
@export var wave_budget_exponent: float = 1.2
## Gegnertypen, aus denen eine Welle ausgewählt wird (GDD: 1–2 Haupttypen pro Welle).
@export var enemy_types: Array[EnemyData] = []
@export var max_main_types: int = 2
## Aus wie vielen Eingängen eine Welle höchstens kommt (GDD: 1–3).
@export var max_entrances: int = 3
## Zum Beginn der Kampfphase kommt ein Pulk: dieser Anteil der Welle (mindestens burst_min_count Gegner).
## Danach folgen Gruppen von group_size_min bis group_size_max Gegnern im zufälligen Abstand von group_interval_min
## bis group_interval_max Sekunden, bis die Welle aufgebraucht ist. Innerhalb von Pulk und Gruppe liegen
## burst_interval Sekunden zwischen zwei Gegnern. Ein Zeitlimit gibt es nicht: Die Kampfphase endet, wenn alle weg sind.
@export_range(0.0, 1.0) var burst_fraction: float = 0.3
@export var burst_min_count: int = 3
@export var burst_interval: float = 0.4
@export var group_size_min: int = 2
@export var group_size_max: int = 5
@export var group_interval_min: float = 5.0
@export var group_interval_max: float = 12.0
## Sind nur noch so wenige Gegner übrig (Anteil der Welle, mindestens 1), werden die Adern instabil.
@export_range(0.0, 1.0) var unstable_fraction: float = 0.05

@export_group("Erz")
@export var ore_spawn: OreSpawnData

@export_group("Skalierung nach Spielerzahl")
## Index = Spielerzahl - 1 (GDD-Tabelle): Faktor auf die Gegner-Anzahl (über das Budget) und auf die Gegner-LP.
@export var count_multiplier_by_players: Array[float] = [1.0, 1.5, 2.0, 2.5]
@export var health_multiplier_by_players: Array[float] = [1.0, 1.15, 1.3, 1.45]
