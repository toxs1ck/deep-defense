class_name TraitData
extends Resource
## Passives Merkmal mit Vorteil und Nachteil (GDD, „Merkmale, Fähigkeiten & Skillbäume“). Werte sind Faktoren,
## 1,0 = unverändert.

@export var display_name: String = ""
@export_multiline var description: String = ""
## Schläge pro Sekunde beim Abbauen bzw. im Kampf.
@export var mining_speed_multiplier: float = 1.0
@export var attack_speed_multiplier: float = 1.0
## Schaden mit Nahkampf- bzw. Fernkampfwaffen (Fernkampf gibt es noch nicht).
@export var melee_damage_multiplier: float = 1.0
@export var ranged_damage_multiplier: float = 1.0
