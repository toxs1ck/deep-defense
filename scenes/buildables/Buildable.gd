class_name Buildable
extends StaticBody3D
## Basis aller Bauelemente. Der Host setzt Lage und Drehung vor dem Spawnen; der BuildableSpawner überträgt sie
## einmalig an alle (Bauelemente bewegen sich nicht).

const GROUP: StringName = &"buildables"

@export var sync_position: Vector3
## Drehung in 90°-Schritten um die Hochachse (0–3).
@export var rotation_steps: int = 0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	global_position = sync_position
	rotation.y = rotation_steps * PI / 2.0
