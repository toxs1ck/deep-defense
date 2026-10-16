class_name WaveSpawner
extends Node
## Nur Host: plant zu Beginn jeder Bauphase die nächste Welle aus einem Punkte-Budget (GDD, „Wellen-Design“),
## zeigt allen die Vorschau (Typen und Eingänge, nicht die Anzahl) und spawnt sie in der Kampfphase.
## Die Kampfphase endet, sobald alle Gegner gespawnt und besiegt (oder entkommen) sind.
## Zufall über GameState.rng, damit ein Run mit demselben Seed gleich abläuft.

## Nur Host: ein Gegner hat Erz fallen lassen (z. B. ein besiegter Erzdieb); Main spawnt den Brocken.
signal ore_dropped(ore: OreData, drop_position: Vector3, impulse: Vector3)
## Auf allen Peers: Vorschau der nächsten Welle.
signal preview_changed(enemy_names: PackedStringArray, entrance_names: PackedStringArray)

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/Enemy.tscn")
const SPAWN_GROUP: StringName = &"enemy_spawns"
## Namenspräfix der Eingangs-Marker; der Rest des Namens erscheint in der Vorschau (z. B. „EnemySpawnWest“ → „West“).
const SPAWN_NAME_PREFIX: String = "EnemySpawn"
## Zufälliger Versatz um den Eingang, damit Gegner nicht exakt aufeinander erscheinen.
const SPAWN_JITTER: float = 1.0

## Container, unter den die Gegner kommen; der EnemySpawner repliziert ihn.
@export var enemies: Node3D

## Nur Host: geplante Welle als Liste von EnemyData in Spawn-Reihenfolge und die gewählten Eingänge.
var _queue: Array[EnemyData] = []
var _entrances: Array[Node3D] = []
var _spawn_timer: float = 0.0
var _spawn_index: int = 0


func _ready() -> void:
	RunManager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: int) -> void:
	if not multiplayer.is_server():
		return
	match phase:
		RunManager.Phase.BUILD:
			_clear_enemies()
			_plan_wave(RunManager.current_round)
		RunManager.Phase.COMBAT:
			_spawn_timer = 0.0
		_:
			_queue.clear()
			_clear_enemies()


## Budget = Basis × Schicht^Exponent, mal Faktor für die Spielerzahl. 1–2 Haupttypen, 1–3 Eingänge.
func _plan_wave(round_number: int) -> void:
	var run := RunManager.data
	var rng := GameState.rng
	var players := clampi(RunManager.player_count, 1, run.count_multiplier_by_players.size())
	var budget := run.wave_budget_base * pow(round_number, run.wave_budget_exponent) * run.count_multiplier_by_players[players - 1]

	var available: Array[EnemyData] = []
	for enemy_data in run.enemy_types:
		if enemy_data.first_round <= round_number:
			available.append(enemy_data)
	var main_types: Array[EnemyData] = []
	var type_count := mini(rng.randi_range(1, run.max_main_types), available.size())
	while main_types.size() < type_count:
		var pick := available[rng.randi_range(0, available.size() - 1)]
		if not pick in main_types:
			main_types.append(pick)

	_queue.clear()
	var cheapest := 1 << 30
	for enemy_data in main_types:
		cheapest = mini(cheapest, enemy_data.cost)
	while budget >= cheapest and not main_types.is_empty():
		var pick := main_types[rng.randi_range(0, main_types.size() - 1)]
		if pick.cost <= budget:
			_queue.append(pick)
			budget -= pick.cost

	var points: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(SPAWN_GROUP):
		points.append(node as Node3D)
	_entrances.clear()
	var entrance_count := mini(rng.randi_range(1, run.max_entrances), points.size())
	while _entrances.size() < entrance_count:
		var point := points[rng.randi_range(0, points.size() - 1)]
		if not point in _entrances:
			_entrances.append(point)
	_spawn_index = 0

	var enemy_names := PackedStringArray()
	for enemy_data in main_types:
		enemy_names.append(enemy_data.display_name)
	var entrance_names := PackedStringArray()
	for point in _entrances:
		entrance_names.append(String(point.name).trim_prefix(SPAWN_NAME_PREFIX))
	_show_preview.rpc(enemy_names, entrance_names)


@rpc("authority", "call_local", "reliable")
func _show_preview(enemy_names: PackedStringArray, entrance_names: PackedStringArray) -> void:
	preview_changed.emit(enemy_names, entrance_names)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or RunManager.phase != RunManager.Phase.COMBAT:
		return
	if not _queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = RunManager.data.spawn_interval
			_spawn(_queue.pop_front())
	elif _alive_enemy_count() == 0:
		RunManager.end_combat()


func _spawn(enemy_data: EnemyData) -> void:
	if _entrances.is_empty():
		push_warning("WaveSpawner: keine Gegner-Eingänge in Gruppe '%s'" % SPAWN_GROUP)
		_queue.clear()
		return
	var point := _entrances[_spawn_index % _entrances.size()]
	_spawn_index += 1
	var run := RunManager.data
	var players := clampi(RunManager.player_count, 1, run.health_multiplier_by_players.size())
	var rng := GameState.rng
	var offset := Vector3(rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER), 0, rng.randf_range(-SPAWN_JITTER, SPAWN_JITTER))
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.data_path = enemy_data.resource_path
	enemy.health_multiplier = run.health_multiplier_by_players[players - 1]
	enemy.position = point.global_position + offset
	enemy.sync_position = enemy.position
	enemy.ore_dropped.connect(ore_dropped.emit)
	enemies.add_child(enemy, true)


func _clear_enemies() -> void:
	for enemy in enemies.get_children():
		enemy.queue_free()


func _alive_enemy_count() -> int:
	var count := 0
	for enemy in enemies.get_children():
		if not enemy.is_queued_for_deletion():
			count += 1
	return count
