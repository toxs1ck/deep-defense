class_name Enemy
extends CharacterBody3D
## Basis für alle Gegner; Typen unterscheiden sich über EnemyData.
## Die KI läuft nur auf dem Host: per Navigationsnetz zum Aufzug laufen, dort in Abständen angreifen.
## Jeder Gegner sucht sich einen eigenen Angriffspunkt rund um den Aufzug, und die Agenten weichen einander aus
## (Avoidance), damit sich keine Schlange bildet. Spieler, die einen Gegner berühren, schieben ihn weg.
## Kommt ein Spieler auf dem Weg näher als data.aggro_range, greift der Gegner stattdessen ihn an, bis er gefallen
## ist oder sich weiter als aggro_range + aggro_leash entfernt. Hat der Gegner schon ein Angriffsziel (Aufzug,
## Bauelement, anderer Spieler), wechselt er nur, wenn ihn ein Spieler trifft.
## Erreicht der Weg den Aufzug nicht (zugebaut), greift der Gegner das Bauelement am Wegende an (GDD, „Platzierung“).
## Erzdiebe (data.steals_ore) suchen stattdessen liegendes Erz, stehlen es und fliehen zum nächsten Eingang; dort
## verschwinden sie mit der Beute. Bei jedem Treffer (auch von Verteidigungen) lassen sie das Erz fallen und fliehen
## einige Sekunden vom Verursacher weg, bevorzugt an einen Platz außer Sicht. Spielern weichen sie unterwegs im Bogen
## aus. Ohne liegendes Erz verhalten sie sich wie die anderen, greifen aber nie Spieler an.
## Jeder Angriff hat eine Ausholphase (data.attack_windup), in der man ausweichen kann; unterbrechen lässt sie sich
## nur im ersten Teil (data.interruptible_fraction). Dabei rückt er mit
## verringertem Tempo nach; einmal ausgeholt, schlägt er zu, auch wenn das Ziel schon weg ist. Ein Treffer während
## des Ausholens bricht den Angriff ab.
## Clients bekommen Position und Blickrichtung über den MultiplayerSynchronizer und glätten sie.

## Nur Host: Ein Gegner lässt Erz fallen (besiegter Erzdieb). Der WaveSpawner reicht es an Main weiter.
signal ore_dropped(ore: OreData, drop_position: Vector3, impulse: Vector3)

const GROUP: StringName = &"enemies"
## Erzdieb: ab dieser Entfernung (waagerecht) greift er einen Brocken bzw. ist am Eingang entkommen.
const STEAL_RANGE: float = 1.2
const ESCAPE_RANGE: float = 1.2
## So weit sucht ein Erzdieb nach liegendem Erz.
const LOOT_SEARCH_RADIUS: float = 40.0
## Flucht: so viele Richtungen in einem Fächer weg vom Verursacher werden geprüft …
const FLEE_SAMPLES: int = 12
const FLEE_FAN_ANGLE: float = PI * 0.65
## … und Punkte außer Sicht (Welt oder Bauelement dazwischen) bekommen diesen Bonus auf ihre Entfernung.
const FLEE_HIDDEN_BONUS: float = 20.0
const FLEE_SIGHT_MASK: int = (1 << 0) | (1 << 3)
const FLEE_EYE_HEIGHT: float = 1.2
## Beim Ausweichen um Spieler: Anteil, mit dem der Dieb zusätzlich vom Spieler weg lenkt.
const AVOID_AWAY_SHARE: float = 0.4
## So oft wird der Weg neu berechnet (GDD: KI in festen Ticks statt jeden Frame).
const REPATH_INTERVAL: float = 0.5
## Ein Wegpunkt gilt als erreicht, wenn er waagerecht so nah ist. Bewusst ohne Höhe: Auf Rampen liegt das Netz
## etwas über oder unter dem Boden, mit 3D-Abstand würde der Punkt nie „erreicht“ und der Gegner pendeln.
const WAYPOINT_REACHED: float = 0.5
## Ab dieser Entfernung (Mitte zu Mitte, waagerecht) schlägt der Gegner ein Bauelement.
const BUILDABLE_ATTACK_RANGE: float = 1.9
## Um das Wegende herum wird so weit nach dem Bauelement gesucht, das den Weg versperrt.
const BLOCKER_SEARCH_RADIUS: float = 3.5
## Ab dieser Entfernung zur Mitte des Aufzugs greift der Gegner an.
const ATTACK_RANGE: float = 2.8
## Wer angreift, hört erst auf, wenn er so viel weiter weg gedrückt wird (gegen Flackern an der Grenze).
const ATTACK_HYSTERESIS: float = 0.6
## Wie schnell sich die Geschwindigkeit an die gewünschte anpasst, in m/s². Glättet Richtungswechsel
## von Avoidance, Wegpunkten und Schieben, die sonst gegeneinander arbeiten und ruckeln.
const ACCELERATION: float = 18.0
## Erst ab diesem Tempo dreht sich das Modell mit, damit es im Stehen nicht zittert.
const MIN_FACING_SPEED: float = 0.6
## Kommt so lange kein Ergebnis der Avoidance, läuft der Gegner ohne Ausweichen weiter, statt stehen zu bleiben.
const AVOIDANCE_TIMEOUT: float = 0.2
const HIT_FLASH_TIME: float = 0.18
## Aussehen beim Ausholen: breiter und flacher, Warnfarbe.
## Faktor auf die Grundgröße beim Ausholen.
const WINDUP_SCALE: Vector3 = Vector3(1.2, 0.85, 1.2)
const WINDUP_COLOR: Color = Color(1.0, 0.55, 0.1)
## Ab hier lässt sich der Angriff nicht mehr unterbrechen.
const COMMITTED_COLOR: Color = Color(1.0, 0.1, 0.05)
## So lange schrumpft ein besiegter Gegner, bevor er verschwindet.
const DEATH_TIME: float = 0.25
## Abstand der Angriffspunkte zur Mitte des Aufzugs (knapp außerhalb der Korbwände).
const ATTACK_POINT_RADIUS: float = 2.3
## Radien für das Wegschieben durch Spieler: Gegner (Kollision) und Spieler (Kapsel) plus etwas Spielraum.
const BODY_RADIUS: float = 0.525
const PLAYER_RADIUS: float = 0.4
const PUSH_MARGIN: float = 0.15
## Wie schnell ein berührter Gegner vom Spieler weggeschoben wird, in m/s.
const PUSH_SPEED: float = 2.5
const TURN_SPEED: float = 10.0

## Pfad zur EnemyData-Resource; wird beim Spawnen mitgeschickt.
@export var data_path: String = ""
@export var remote_smoothing: float = 15.0

## Vom Host gesetzt und per MultiplayerSynchronizer verteilt.
@export var sync_position: Vector3
@export var sync_yaw: float
## Faktor auf die LP nach Spielerzahl; vom Host vor dem Spawnen gesetzt und beim Spawnen mitgeschickt.
@export var health_multiplier: float = 1.0
## Erzdieb: Pfad der gestohlenen Erzart, leer = keine Beute. Vom Host gesetzt, an alle verteilt (Anzeige).
@export var loot_path: String = "":
	set(value):
		loot_path = value
		if is_node_ready():
			_update_loot_visual()

var data: EnemyData

@onready var health: HealthComponent = $HealthComponent
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _model: Node3D = $Model
@onready var _body: MeshInstance3D = $Model/Body
@onready var _loot: MeshInstance3D = $Model/Loot

var _elevator: Elevator = null
var _repath_timer: float = 0.0
## Nur Host: aktueller Weg vom NavigationServer und Index des nächsten Wegpunkts.
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _attack_timer: float = 0.0
var _body_rest_position: Vector3 = Vector3.ZERO
var _attack_tween: Tween = null
## Grundgröße des Modells (EnemyData.model_scale); alle Animationen rechnen relativ dazu.
var _base_scale: Vector3 = Vector3.ONE
## Nur Host: eigener Angriffspunkt als Winkel um den Aufzug und die von der Avoidance berechnete Geschwindigkeit.
var _attack_angle: float = 0.0
var _safe_velocity: Vector3 = Vector3.ZERO
## Sekunden seit dem letzten Ergebnis der Avoidance.
var _since_safe_velocity: float = INF
var _attacking: bool = false
## Restzeit des Ausholens; > 0 heißt, der Schlag kommt gleich.
var _windup_left: float = 0.0
## Nur Host: aktuell verfolgter Spieler, null = Aufzug.
var _target_player: Player = null
## Nur Host: Bauelement, das den Weg zum Aufzug versperrt und deshalb angegriffen wird.
var _target_buildable: Buildable = null
var _dying: bool = false
## Nur Host, Erzdieb: Brocken, den er gerade holen will.
var _target_chunk: OreChunk = null
## Nur Host, Erzdieb: Restzeit der Flucht nach einem Treffer und das gewählte Versteck.
var _flee_left: float = 0.0
var _flee_point: Vector3 = Vector3.ZERO
## Nur Host, Erzdieb: Seite (+1 / -1), auf der er Spielern ausweicht, wenn er genau auf sie zuläuft.
var _avoid_side: float = 1.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	data = load(data_path) as EnemyData
	assert(data != null, "Enemy: ungültiger data_path '%s'" % data_path)
	var material := StandardMaterial3D.new()
	material.albedo_color = data.color
	_body.material_override = material
	_body_rest_position = _body.position
	health.setup(roundi(data.max_health * health_multiplier))
	_base_scale = Vector3.ONE * data.model_scale
	_model.scale = _base_scale
	_update_loot_visual()
	health.died.connect(_on_died)
	global_position = sync_position
	_model.rotation.y = sync_yaw
	if multiplayer.is_server():
		_attack_angle = GameState.rng.randf_range(0.0, TAU)
		_avoid_side = 1.0 if GameState.rng.randf() < 0.5 else -1.0
		_agent.max_speed = data.speed
		_agent.avoidance_enabled = true
		_agent.velocity_computed.connect(_on_velocity_computed)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		var weight := 1.0 - exp(-remote_smoothing * delta)
		global_position = global_position.lerp(sync_position, weight)
		_model.rotation.y = lerp_angle(_model.rotation.y, sync_yaw, weight)
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	if not is_instance_valid(_elevator):
		_elevator = get_tree().get_first_node_in_group(Elevator.GROUP) as Elevator

	var desired := Vector3.ZERO
	_update_target_player()
	if _target_buildable != null and not is_instance_valid(_target_buildable):
		# Zerstört: weiter zum Aufzug, Weg gleich neu berechnen.
		_target_buildable = null
		_attacking = false
		_repath_timer = 0.0
	if _windup_left > 0.0 and not _dying:
		# Beim Ausholen bringt er den Schlag zu Ende und rückt langsamer nach; dicht am Spieler bleibt er stehen.
		_attack(delta)
		if _target_player and _horizontal_distance_to(_target_player.global_position) > data.player_attack_range * 0.8:
			desired = _move_direction(delta) * data.speed * data.windup_speed_multiplier
	elif data.steals_ore and not _dying and _thief_has_goal():
		desired = _thief_step(delta)
	elif _elevator and not _dying:
		# Spieler: Abstand Mitte zu Mitte, waagerecht. Aufzug: Abstand zur Mitte des Korbs.
		var distance := global_position.distance_to(_elevator.global_position)
		var attack_range := ATTACK_RANGE
		if _target_player:
			distance = _horizontal_distance_to(_target_player.global_position)
			attack_range = data.player_attack_range
		elif _target_buildable:
			distance = _horizontal_distance_to(_target_buildable.global_position)
			attack_range = BUILDABLE_ATTACK_RANGE
		if _attacking:
			_attacking = distance <= attack_range + ATTACK_HYSTERESIS
		else:
			_attacking = distance <= attack_range
		if _attacking:
			_attack(delta)
		else:
			desired = _move_direction(delta) * data.speed
	# Die Avoidance liefert ihr Ergebnis per Signal; verwendet wird das aus dem letzten Tick.
	_agent.velocity = desired
	_since_safe_velocity += delta
	var steering := Vector3.ZERO
	if desired != Vector3.ZERO:
		steering = _safe_velocity if _since_safe_velocity < AVOIDANCE_TIMEOUT else desired
	steering.y = 0.0
	var target := steering + _player_push()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, ACCELERATION * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	# Laufrichtung nur, solange er läuft; beim Angreifen schaut er zum Aufzug.
	var facing := horizontal if horizontal.length() > MIN_FACING_SPEED else Vector3.ZERO
	if _attacking and _windup_left <= 0.0:
		facing = _goal_position() - global_position
		facing.y = 0.0
	if facing.length_squared() > 0.01:
		var target_yaw := atan2(-facing.x, -facing.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, minf(1.0, TURN_SPEED * delta))
	sync_position = global_position
	sync_yaw = _model.rotation.y


## Der NavigationAgent3D dient nur dem Ausweichen (er bekommt das Ziel trotzdem, sonst rechnet er nicht);
## den Weg holt und verfolgt der Gegner selbst.
func _move_direction(delta: float) -> Vector3:
	var target := _goal_position()
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = REPATH_INTERVAL
		_path = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, target, true)
		_path_index = 0
		# Der Agent braucht ein Ziel, sonst reicht er die Geschwindigkeit nicht an die Avoidance weiter.
		_agent.target_position = target
		var heading_for_elevator := _target_chunk == null and loot_path.is_empty() and _flee_left <= 0.0
		if heading_for_elevator and _target_player == null and _target_buildable == null:
			_check_path_blocked()
	while _path_index < _path.size() and _horizontal_distance_to(_path[_path_index]) < WAYPOINT_REACHED:
		_path_index += 1
	# Ohne Weg (Netz noch nicht fertig) oder am Wegende, aber noch nicht in Reichweite: direkt aufs Ziel zu.
	var next := _path[_path_index] if _path_index < _path.size() else target
	var to_next := next - global_position
	to_next.y = 0.0
	var direction := to_next.normalized() if to_next.length_squared() > 0.0001 else Vector3.ZERO
	# Erzdiebe lenken um Spieler herum (bei anderen Gegnern ist der Radius 0).
	return _avoid_players(direction)


## Wohin der Gegner gerade will: Spieler, versperrendes Bauelement oder sein Angriffspunkt am Aufzug.
func _goal_position() -> Vector3:
	if _flee_left > 0.0:
		return _flee_point
	if not loot_path.is_empty():
		return _nearest_entrance()
	if _target_chunk != null and is_instance_valid(_target_chunk):
		return _target_chunk.global_position
	if _target_player:
		return _target_player.global_position
	if _target_buildable:
		return _target_buildable.global_position
	var around := Vector3(sin(_attack_angle), 0.0, cos(_attack_angle)) * ATTACK_POINT_RADIUS
	return _elevator.global_position + around


## Endet der Weg zum Aufzug außerhalb der Angriffsreichweite, ist er zugebaut: das Bauelement am Wegende angreifen.
func _check_path_blocked() -> void:
	var path_end := _path[_path.size() - 1] if not _path.is_empty() else global_position
	var end_to_elevator := Vector2(path_end.x - _elevator.global_position.x, path_end.z - _elevator.global_position.z)
	if end_to_elevator.length() <= ATTACK_RANGE:
		return
	var nearest: Buildable = null
	var nearest_distance := BLOCKER_SEARCH_RADIUS
	for node in get_tree().get_nodes_in_group(Buildable.GROUP):
		var buildable := node as Buildable
		if not buildable.data.blocks_path:
			continue
		var distance := Vector2(buildable.global_position.x - path_end.x, buildable.global_position.z - path_end.z).length()
		if distance <= nearest_distance:
			nearest = buildable
			nearest_distance = distance
	if nearest:
		_target_buildable = nearest
		_attacking = false
		_repath_timer = 0.0


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	_safe_velocity = safe_velocity
	_since_safe_velocity = 0.0


func _horizontal_distance_to(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


## Spieler, die den Gegner berühren, schieben ihn von sich weg. Positionen fremder Spieler sind auf dem Host
## die geglätteten, das reicht für ein leichtes Schieben.
func _player_push() -> Vector3:
	var push := Vector3.ZERO
	var contact := BODY_RADIUS + PLAYER_RADIUS + PUSH_MARGIN
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		var away := global_position - player.global_position
		away.y = 0.0
		var distance := away.length()
		if distance < contact and distance > 0.001:
			push += away / distance * PUSH_SPEED
	return push


func _attack(delta: float) -> void:
	if _windup_left > 0.0:
		_windup_left -= delta
		if _windup_left <= 0.0:
			_strike()
		return
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	_windup_left = data.attack_windup
	_play_windup.rpc(data.attack_windup, data.attack_windup * data.interruptible_fraction)


## Nur Host: Schlag ausführen. Spieler werden nur getroffen, wenn sie noch nah genug sind.
func _strike() -> void:
	_windup_left = 0.0
	_attack_timer = data.attack_interval
	if _target_player != null:
		var still_valid := is_instance_valid(_target_player) and not _target_player.is_downed()
		var reach := data.player_attack_range + data.attack_hit_margin
		if still_valid and _horizontal_distance_to(_target_player.global_position) <= reach:
			_target_player.health.damage(data.player_damage)
	elif _target_buildable != null:
		# Ziel war ein Bauelement; ist es inzwischen weg, geht der Schlag ins Leere.
		if is_instance_valid(_target_buildable):
			_target_buildable.health.damage(data.building_damage)
	elif _elevator:
		_elevator.health.damage(data.elevator_damage)
	_play_attack.rpc()


## Nur Host: Spieler in der Nähe haben Vorrang vor dem Aufzug, solange der Gegner noch unterwegs ist. Ein Ziel wird
## erst aufgegeben, wenn es fällt oder weit genug weg ist, damit der Gegner nicht zwischen Zielen hin und her springt.
func _update_target_player() -> void:
	if data.steals_ore:
		return
	if _target_player != null:
		var lost := not is_instance_valid(_target_player) or _target_player.is_downed()
		if lost or _horizontal_distance_to(_target_player.global_position) > data.aggro_range + data.aggro_leash:
			_set_target_player(null)
		return
	# Wer schon angreift (Aufzug oder versperrendes Bauelement), lässt sich durch Nähe nicht ablenken,
	# nur durch einen Treffer (take_hit).
	if _attacking or _windup_left > 0.0 or _target_buildable != null:
		return
	var nearest: Player = null
	var nearest_distance := data.aggro_range
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		if player.is_downed():
			continue
		var distance := _horizontal_distance_to(player.global_position)
		if distance <= nearest_distance:
			nearest = player
			nearest_distance = distance
	if nearest:
		_set_target_player(nearest)


func _set_target_player(player: Player) -> void:
	if player == _target_player:
		return
	_target_player = player
	_attacking = false
	# Neues Ziel: Weg sofort neu berechnen.
	_repath_timer = 0.0


## Nur Host: getroffen, von einem Spieler oder (attacker = null) von einer Verteidigung. Nur Spieler lenken die
## Aggro um und unterbrechen das Ausholen; sonst würden Türme Gegner dauerhaft am Angreifen hindern.
## source ist die Position des Verursachers (Erzdiebe fliehen davor).
func take_hit(amount: int, knockback: Vector3, attacker: Player, source: Vector3) -> void:
	if not multiplayer.is_server() or _dying:
		return
	velocity += knockback * (1.0 - data.knockback_resistance)
	if data.steals_ore:
		_drop_loot()
		_start_flee(source)
	if attacker and not data.steals_ore:
		_set_target_player(attacker)
	if attacker and _windup_left > 0.0 and _is_windup_interruptible():
		# Unterbrochen: kein Schlag, kurz taumeln.
		_windup_left = 0.0
		_attack_timer = data.stagger_time
		_play_windup_cancel.rpc()
	_play_hit.rpc()
	health.damage(amount)


## Nur im ersten Teil des Ausholens lässt sich der Angriff noch unterbrechen.
func _is_windup_interruptible() -> bool:
	var elapsed := data.attack_windup - _windup_left
	return elapsed < data.attack_windup * data.interruptible_fraction


## Aufblitzen und kurz zusammenzucken, damit Treffer wuchtig wirken.
@rpc("authority", "call_local", "unreliable")
func _play_hit() -> void:
	var material := _body.material_override as StandardMaterial3D
	material.albedo_color = Color.WHITE
	create_tween().tween_property(material, "albedo_color", data.color, HIT_FLASH_TIME)
	_body.scale = Vector3(1.25, 0.75, 1.25)
	create_tween().tween_property(_body, "scale", Vector3.ONE, HIT_FLASH_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ausholen: nach hinten ducken, breiter werden und orange aufglühen, damit man den Schlag kommen sieht.
@rpc("authority", "call_local", "reliable")
## interruptible_time: bis dahin glüht er orange auf (unterbrechbar), danach springt er auf grelles Rot (der Schlag kommt).
func _play_windup(duration: float, interruptible_time: float) -> void:
	_kill_attack_tween()
	_attack_tween = create_tween().set_parallel()
	_attack_tween.tween_property(_body, "position", _body_rest_position + Vector3.BACK * 0.25, duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_attack_tween.tween_property(_model, "scale", _base_scale * WINDUP_SCALE, duration)
	var material := _body.material_override as StandardMaterial3D
	_attack_tween.tween_property(material, "albedo_color", WINDUP_COLOR, interruptible_time)
	_attack_tween.tween_property(material, "albedo_color", COMMITTED_COLOR, 0.04).set_delay(interruptible_time)


## Zuschlagen: kräftiger Ruck nach vorne, dann zurück in die Ruhelage.
## Zuverlässig gesendet, sonst bliebe der Gegner bei verlorenem Paket in der Ausholpose stehen.
@rpc("authority", "call_local", "reliable")
func _play_attack() -> void:
	_kill_attack_tween()
	var material := _body.material_override as StandardMaterial3D
	material.albedo_color = data.color
	_model.scale = _base_scale
	_attack_tween = create_tween()
	_attack_tween.tween_property(_body, "position", _body_rest_position + Vector3.FORWARD * 0.45, 0.06)
	_attack_tween.tween_property(_body, "position", _body_rest_position, 0.18)


@rpc("authority", "call_local", "reliable")
func _play_windup_cancel() -> void:
	_kill_attack_tween()
	var material := _body.material_override as StandardMaterial3D
	material.albedo_color = data.color
	_attack_tween = create_tween().set_parallel()
	_attack_tween.tween_property(_body, "position", _body_rest_position, 0.15)
	_attack_tween.tween_property(_model, "scale", _base_scale, 0.15)


func _kill_attack_tween() -> void:
	if _attack_tween:
		_attack_tween.kill()


## Nur der Host entfernt den Gegner, nach einer kurzen Todesanimation bei allen; der EnemySpawner entfernt ihn
## dann auch bei den Clients. Bis dahin greift er nicht mehr an und blockiert nichts.
func _on_died() -> void:
	if not multiplayer.is_server():
		return
	_dying = true
	collision_layer = 0
	_drop_loot()
	_play_death.rpc()
	get_tree().create_timer(DEATH_TIME).timeout.connect(queue_free)


@rpc("authority", "call_local", "reliable")
func _play_death() -> void:
	_kill_attack_tween()
	create_tween().tween_property(_model, "scale", _base_scale * Vector3(1.3, 0.05, 1.3), DEATH_TIME).set_ease(Tween.EASE_IN)


## Nur Host, Erzdieb: Beute fallen lassen (getroffen oder besiegt).
func _drop_loot() -> void:
	if loot_path.is_empty():
		return
	var ore := load(loot_path) as OreData
	ore_dropped.emit(ore, global_position + Vector3.UP * 0.8, Vector3.UP * 2.0)
	loot_path = ""
	_target_chunk = null
	_repath_timer = 0.0


## Nur Host, Erzdieb: Versteck weg vom Verursacher wählen und für eine zufällige Zeit dorthin fliehen.
## Geprüft wird ein Fächer von Punkten auf dem Navigationsnetz; Punkte, die man vom Verursacher aus nicht sieht,
## werden bevorzugt, danach zählt die Entfernung zum Verursacher.
func _start_flee(source: Vector3) -> void:
	_flee_left = GameState.rng.randf_range(data.flee_time_min, data.flee_time_max)
	_target_chunk = null
	_attacking = false
	_windup_left = 0.0
	_repath_timer = 0.0
	var away := global_position - source
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD.rotated(Vector3.UP, GameState.rng.randf_range(0.0, TAU))
	away = away.normalized()
	var map := get_world_3d().navigation_map
	var space := get_world_3d().direct_space_state
	var eye := source + Vector3.UP * FLEE_EYE_HEIGHT
	var best_score := -INF
	_flee_point = global_position + away * data.flee_distance
	for i in FLEE_SAMPLES:
		var angle := lerpf(-FLEE_FAN_ANGLE, FLEE_FAN_ANGLE, float(i) / float(FLEE_SAMPLES - 1))
		var wanted := global_position + away.rotated(Vector3.UP, angle) * data.flee_distance
		var candidate := NavigationServer3D.map_get_closest_point(map, wanted)
		var sight := PhysicsRayQueryParameters3D.create(eye, candidate + Vector3.UP * 0.5, FLEE_SIGHT_MASK)
		var hidden := not space.intersect_ray(sight).is_empty()
		var score := candidate.distance_to(source) + (FLEE_HIDDEN_BONUS if hidden else 0.0)
		if score > best_score:
			best_score = score
			_flee_point = candidate


## Erzdieb: hat er Beute, flieht er oder gibt es ein erreichbares Ziel-Erz? Sonst verhält er sich wie die anderen.
func _thief_has_goal() -> bool:
	if not loot_path.is_empty() or _flee_left > 0.0:
		return true
	if _target_chunk == null or not is_instance_valid(_target_chunk) or _target_chunk.carrier_id != 0:
		var previous := _target_chunk
		_target_chunk = _find_loot()
		if _target_chunk != previous:
			_repath_timer = 0.0
	return _target_chunk != null


## Nur Host, Erzdieb: zur Beute bzw. mit Beute zum Eingang.
func _thief_step(delta: float) -> Vector3:
	_attacking = false
	if _flee_left > 0.0:
		_flee_left -= delta
		if _horizontal_distance_to(_flee_point) <= WAYPOINT_REACHED:
			# Im Versteck: abwarten, bis die Fluchtzeit um ist.
			return Vector3.ZERO
		return _move_direction(delta) * data.speed
	if not loot_path.is_empty():
		if _horizontal_distance_to(_nearest_entrance()) <= ESCAPE_RANGE:
			# Entkommen: Die Beute ist verloren.
			_dying = true
			queue_free()
			return Vector3.ZERO
		return _move_direction(delta) * data.speed * data.loot_speed_multiplier
	if _horizontal_distance_to(_target_chunk.global_position) <= STEAL_RANGE:
		loot_path = _target_chunk.ore_path
		_target_chunk.queue_free()
		_target_chunk = null
		_repath_timer = 0.0
		return Vector3.ZERO
	return _move_direction(delta) * data.speed


## Lenkt im Bogen um nahe Spieler: Der Anteil der Laufrichtung, der auf einen Spieler zeigt, wird durch die
## Richtung seitlich an ihm vorbei ersetzt (tangential), dazu ein leichter Druck weg vom Spieler. Je näher der Spieler,
## desto stärker. Läuft der Dieb genau auf ihn zu, nimmt er seine feste Ausweichseite, damit er nicht pendelt.
func _avoid_players(direction: Vector3) -> Vector3:
	if data.player_avoid_radius <= 0.0 or direction == Vector3.ZERO:
		return direction
	var steered := direction
	for node in get_tree().get_nodes_in_group(Player.GROUP):
		var player := node as Player
		if player.is_downed():
			continue
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		var distance := to_player.length()
		if distance < 0.001 or distance > data.player_avoid_radius:
			continue
		var toward := to_player / distance
		var heading := steered.dot(toward)
		if heading <= 0.0:
			# Spieler liegt hinter ihm: nur ein wenig zusätzlicher Abstand.
			continue
		var tangent := steered - toward * heading
		if tangent.length_squared() < 0.04:
			tangent = toward.cross(Vector3.UP) * _avoid_side
		tangent = tangent.normalized()
		var weight := clampf((1.0 - distance / data.player_avoid_radius) * data.player_avoid_strength, 0.0, 1.0)
		steered = steered.lerp(tangent - toward * AVOID_AWAY_SHARE, weight)
	steered.y = 0.0
	return steered.normalized() if steered.length_squared() > 0.0001 else direction


## Nächster frei liegender Brocken (nicht getragen, nicht schon von einem anderen Dieb anvisiert).
func _find_loot() -> OreChunk:
	var claimed := {}
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Enemy
		if other != self and other._target_chunk != null and is_instance_valid(other._target_chunk):
			claimed[other._target_chunk] = true
	var best: OreChunk = null
	var best_distance := LOOT_SEARCH_RADIUS
	for node in get_tree().get_nodes_in_group(OreChunk.GROUP):
		var chunk := node as OreChunk
		if chunk.carrier_id != 0 or chunk.is_queued_for_deletion() or claimed.has(chunk):
			continue
		var distance := _horizontal_distance_to(chunk.global_position)
		if distance < best_distance:
			best = chunk
			best_distance = distance
	return best


func _nearest_entrance() -> Vector3:
	var best := global_position
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemy_spawns"):
		var point := (node as Node3D).global_position
		var distance := _horizontal_distance_to(point)
		if distance < best_distance:
			best = point
			best_distance = distance
	return best


func _update_loot_visual() -> void:
	_loot.visible = not loot_path.is_empty()
	if _loot.visible:
		var ore := load(loot_path) as OreData
		var material := StandardMaterial3D.new()
		material.albedo_color = ore.color
		_loot.material_override = material
