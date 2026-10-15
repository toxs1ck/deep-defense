extends Node
## Nur Host: spawnt in der Kampfphase Gegner an den Eingängen (Gruppe „enemy_spawns“) und beendet die
## Kampfphase, sobald alle gespawnt und besiegt sind. Vorläufig nur Höhlenkrabbler in fester Anzahl
## (RunData.prototype_wave_*); der Budget-Generator mit mehreren Typen folgt in Aufgabe 13.

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/Enemy.tscn")
const CRAWLER: EnemyData = preload("res://data/enemies/cave_crawler.tres")
const SPAWN_GROUP: StringName = &"enemy_spawns"
## Zufälliger Versatz um den Eingang, damit Gegner nicht exakt aufeinander erscheinen.
const SPAWN_JITTER: float = 1.0

## Container, unter den die Gegner kommen; der EnemySpawner repliziert ihn.
@export var enemies: Node3D

var _to_spawn: int = 0
var _spawn_timer: float = 0.0
var _spawn_index: int = 0


func _ready() -> void:
	RunManager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: int) -> void:
	if not multiplayer.is_server():
		return
	if phase == RunManager.Phase.COMBAT:
		var run := RunManager.data
		_to_spawn = run.prototype_wave_base + run.prototype_wave_per_round * (RunManager.current_round - 1)
		_spawn_timer = 0.0
	else:
		# Außerhalb der Kampfphase gibt es keine Gegner (z. B. wenn die Zeit abläuft oder der Run endet).
		_to_spawn = 0
		for enemy in enemies.get_children():
			enemy.queue_free()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or RunManager.phase != RunManager.Phase.COMBAT:
		return
	if _to_spawn > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = RunManager.data.spawn_interval
			_spawn(CRAWLER)
	elif _alive_enemy_count() == 0:
		RunManager.end_combat()


func _spawn(enemy_data: EnemyData) -> void:
	var points := get_tree().get_nodes_in_group(SPAWN_GROUP)
	if points.is_empty():
		push_warning("WaveSpawner: keine Gegner-Eingänge in Gruppe '%s'" % SPAWN_GROUP)
		_to_spawn = 0
		return
	var point := points[_spawn_index % points.size()] as Node3D
	_spawn_index += 1
	var rng := GameState.rng
	var offset := Vector3(rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER), 0, rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER))
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.data_path = enemy_data.resource_path
	enemy.position = point.global_position + offset
	enemy.sync_position = enemy.position
	enemies.add_child(enemy, true)
	_to_spawn -= 1


func _alive_enemy_count() -> int:
	var count := 0
	for enemy in enemies.get_children():
		if not enemy.is_queued_for_deletion():
			count += 1
	return count
