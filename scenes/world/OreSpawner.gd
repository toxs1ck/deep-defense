class_name OreSpawner
extends Node
## Nur Host: Erzvorkommen auf den Erzstellen (Gruppe „ore_spawn_points“). Zu Beginn jeder Kampfphase brechen neue
## Adern auf, am Ende stürzen sie wieder ein: Die anrückenden Gegner graben sich durch den Fels und legen dabei Erz
## frei. So muss in der Kampfphase verteidigt und geschürft werden.
## Welche Erzart wohin kommt, hängt von der Tiefe ab: der Weglänge zum Aufzug übers Navigationsnetz, gemessen einmal
## nach dem ersten Backen des Netzes (dann stehen noch keine Bauteile). Zufall über GameState.rng.

## Auf allen Peers: kurze Ansage für das HUD (Adern brechen auf, werden instabil, Sonderschicht …).
signal announced(text: String)
## Nur Host: Vorkommen kamen dazu oder fielen weg; das Navigationsnetz muss neu gebacken werden.
signal layout_changed

const SPAWN_POINT_GROUP: StringName = &"ore_spawn_points"
const DEPOSIT_SCENE: PackedScene = preload("res://scenes/world/OreDeposit.tscn")

## Container, unter den Vorkommen kommen; der DepositSpawner repliziert ihn.
@export var deposits: Node3D

## Nur Host: Erzstelle → Tiefe 0–1 (0 = kürzester Weg zum Aufzug).
var _depths: Dictionary = {}


func _ready() -> void:
	RunManager.phase_changed.connect(_on_phase_changed)


## Nach dem ersten Backen des Navigationsnetzes aufrufen (Main). Gemessen wird, sobald der NavigationServer das Netz
## übernommen hat; dann gibt es noch keine Bauteile und keine Vorkommen, die Wege verfälschen.
func measure_when_ready() -> void:
	if not _depths.is_empty():
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	_measure_depths()


## Nur Host: vom WaveSpawner gemeldet, sobald nur noch wenige Gegner der Welle übrig sind.
func warn_unstable() -> void:
	if multiplayer.is_server() and deposits.get_child_count() > 0:
		_announce.rpc("Nur noch wenige Gegner – die Adern werden instabil!")


func _on_phase_changed(phase: int) -> void:
	if not multiplayer.is_server():
		return
	if phase == RunManager.Phase.COMBAT:
		if _depths.is_empty():
			_measure_depths()
		_spawn_deposits(RunManager.current_round)
	elif not deposits.get_children().is_empty():
		for deposit: OreDeposit in deposits.get_children():
			deposit.collapse()
		_announce.rpc("Die Adern stürzen ein!")
		# Nach dem Einsturz ist der Weg wieder frei.
		get_tree().create_timer(OreDeposit.COLLAPSE_TIME + 0.1).timeout.connect(layout_changed.emit)


## Weglänge jeder Erzstelle zum Aufzug, auf 0–1 normiert. Ohne Weg zählt die Luftlinie.
func _measure_depths() -> void:
	_depths.clear()
	var elevator := get_tree().get_first_node_in_group(Elevator.GROUP) as Elevator
	var map := deposits.get_world_3d().navigation_map
	var lengths: Dictionary = {}
	for node in get_tree().get_nodes_in_group(SPAWN_POINT_GROUP):
		var point := node as Node3D
		var path := NavigationServer3D.map_get_path(map, point.global_position, elevator.global_position, true)
		var length := 0.0
		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		if path.size() < 2:
			length = point.global_position.distance_to(elevator.global_position)
		lengths[point] = length
	if lengths.is_empty():
		return
	var shortest: float = lengths.values().min()
	var longest: float = lengths.values().max()
	for point: Node3D in lengths:
		_depths[point] = (lengths[point] - shortest) / maxf(0.001, longest - shortest)


func _spawn_deposits(round_number: int) -> void:
	var data := RunManager.data.ore_spawn
	if data == null or _depths.is_empty():
		return
	var rng := GameState.rng
	var occupancy := minf(data.occupancy_max, data.occupancy_start + data.occupancy_per_round * (round_number - 1))
	var depth_bonus := 0.0
	var message := "Neue Adern brechen auf!"
	if round_number >= data.special_from_round and rng.randf() < data.special_chance:
		if rng.randf() < 0.5:
			occupancy += data.rich_occupancy_bonus
			depth_bonus = data.rich_depth_bonus
			message = "Reiche Ader! Mehr und wertvolleres Erz."
		else:
			occupancy -= data.barren_occupancy_malus
			message = "Taube Schicht – kaum Erz in dieser Welle."
	occupancy = clampf(occupancy, 0.0, 1.0)

	var points: Array = _depths.keys()
	# Zufällige Reihenfolge, dann so viele Stellen wie die Belegung vorgibt.
	for i in range(points.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = points[i]
		points[i] = points[j]
		points[j] = swap
	var count := roundi(points.size() * occupancy)
	for i in count:
		var point := points[i] as Node3D
		if not is_instance_valid(point):
			continue
		var ore := _pick_ore(data, clampf(_depths[point] + depth_bonus, 0.0, 1.0), round_number)
		if ore == null:
			continue
		var deposit := DEPOSIT_SCENE.instantiate() as OreDeposit
		deposit.ore_path = ore.resource_path
		deposit.sync_position = point.global_position
		deposit.position = point.global_position
		deposits.add_child(deposit, true)
	if count > 0:
		layout_changed.emit()
		_announce.rpc(message)


## Gewichteter Zufall unter den Erzarten, die für diese Tiefe und Schicht erlaubt sind.
func _pick_ore(data: OreSpawnData, depth: float, round_number: int) -> OreData:
	var candidates: Array[OreSpawnRule] = []
	var total := 0.0
	for rule in data.rules:
		if rule.first_round <= round_number and depth >= rule.min_depth and depth <= rule.max_depth:
			candidates.append(rule)
			total += rule.weight
	if candidates.is_empty():
		return null
	var roll := GameState.rng.randf() * total
	for rule in candidates:
		roll -= rule.weight
		if roll <= 0.0:
			return rule.ore
	return candidates[candidates.size() - 1].ore


@rpc("authority", "call_local", "reliable")
func _announce(text: String) -> void:
	announced.emit(text)
