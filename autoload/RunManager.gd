extends Node
## Ablauf eines Runs: Schichten mit Bau- und Kampfphase, Ready-Check, Sieg nach der letzten Schicht,
## Niederlage, wenn der Aufzug zerstört ist.
## Der Host entscheidet alles und verteilt den Stand per RPC; später Beitretende bekommen ihn beim Beitritt.
## Zu Beginn jeder Schicht wird round_started gesendet; der Aufzug zahlt dabei auf dem Host aus.

enum Phase { LOBBY, BUILD, COMBAT, RUN_OVER }

signal phase_changed(new_phase: Phase)
## Auf allen Peers zu Beginn jeder Schicht, vor phase_changed.
signal round_started(round_number: int)
signal ready_changed(ready_peers: PackedInt32Array, player_count: int)

const DEFAULT_RUN_DATA: RunData = preload("res://data/run/default_run.tres")

var data: RunData = DEFAULT_RUN_DATA
var phase: Phase = Phase.LOBBY
var current_round: int = 0
var ready_peers: PackedInt32Array = PackedInt32Array()
var player_count: int = 0
## Nur in RUN_OVER sinnvoll: geschafft oder Aufzug zerstört.
var victory: bool = false

## Nur Host: verbundene Peers (inkl. Host) → bereit ja/nein.
var _players: Dictionary = {}
## Zuletzt gemeldete Phase. Der Host setzt „phase“ schon vor dem Broadcast, daher wird der Wechsel hiergegen
## erkannt und nicht gegen „phase“, sonst würde phase_changed auf dem Host nie gesendet.
var _announced_phase: Phase = Phase.LOBBY


func _ready() -> void:
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)


func is_boss_round(round_number: int) -> bool:
	return round_number in data.boss_rounds


func is_local_player_ready() -> bool:
	return multiplayer.get_unique_id() in ready_peers


## Nur Host: neuen Run beginnen, mit dem Seed aus dem Startmenü oder einem zufälligen.
func start_run() -> void:
	assert(multiplayer.is_server(), "Den Run startet der Host")
	_sync_seed.rpc(GameState.seed_from_text(GameState.requested_seed_text))
	Economy.add_money(data.starting_money)
	_start_round(1)


## Nur Host: Kampfphase beenden. Ruft der WaveSpawner auf, sobald alle Gegner der Welle weg sind.
func end_combat() -> void:
	if not multiplayer.is_server() or phase != Phase.COMBAT:
		return
	if current_round >= data.rounds_per_run:
		phase = Phase.RUN_OVER
		victory = true
		_broadcast(false)
	else:
		_start_round(current_round + 1)


## Nur Host: Der Aufzug ist zerstört, der Run ist verloren.
func fail_run() -> void:
	if not multiplayer.is_server() or phase == Phase.RUN_OVER or phase == Phase.LOBBY:
		return
	phase = Phase.RUN_OVER
	victory = false
	_broadcast(false)


## Vom lokalen Spieler: bereit melden bzw. zurücknehmen (nur in der Bauphase).
func request_toggle_ready() -> void:
	_toggle_ready_on_host.rpc_id(1)


## Lokal zurücksetzen, z. B. beim Verlassen eines Spiels.
func reset() -> void:
	_players.clear()
	_apply_state(Phase.LOBBY, 0, PackedInt32Array(), 0, false, false)


@rpc("any_peer", "call_local", "reliable")
func _toggle_ready_on_host() -> void:
	if not multiplayer.is_server() or phase != Phase.BUILD:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id == 0:
		peer_id = multiplayer.get_unique_id()
	if not _players.has(peer_id):
		return
	_players[peer_id] = not _players[peer_id]
	_check_all_ready()


func _start_round(round_number: int) -> void:
	current_round = round_number
	phase = Phase.BUILD
	for peer_id: int in _players:
		_players[peer_id] = false
	_broadcast(true)


func _start_combat() -> void:
	phase = Phase.COMBAT
	_broadcast(false)


func _check_all_ready() -> void:
	if phase == Phase.BUILD and not _players.is_empty() and not (false in _players.values()):
		_start_combat()
	else:
		_broadcast(false)


func _on_player_joined(peer_id: int) -> void:
	_players[peer_id] = false
	if peer_id != multiplayer.get_unique_id():
		_sync_seed.rpc_id(peer_id, GameState.run_seed)
		_sync_state.rpc_id(peer_id, phase, current_round, _ready_list(), _players.size(), victory, false)
	_check_all_ready()


## Wer geht, zählt nicht mehr; waren alle anderen schon bereit, startet die Welle.
func _on_player_left(peer_id: int) -> void:
	_players.erase(peer_id)
	_check_all_ready()


func _ready_list() -> PackedInt32Array:
	var list := PackedInt32Array()
	for peer_id: int in _players:
		if _players[peer_id]:
			list.append(peer_id)
	return list


func _broadcast(round_began: bool) -> void:
	if phase == Phase.LOBBY:
		return
	_sync_state.rpc(phase, current_round, _ready_list(), _players.size(), victory, round_began)


## Alle kennen den Seed, damit er im Menü steht; gewürfelt wird trotzdem nur auf dem Host.
@rpc("authority", "call_local", "reliable")
func _sync_seed(seed_value: int) -> void:
	GameState.set_run_seed(seed_value)


@rpc("authority", "call_local", "reliable")
func _sync_state(new_phase: int, round_number: int, ready_list: PackedInt32Array, players: int, won: bool,
		round_began: bool) -> void:
	_apply_state(new_phase as Phase, round_number, ready_list, players, won, round_began)


func _apply_state(new_phase: Phase, round_number: int, ready_list: PackedInt32Array, players: int, won: bool,
		round_began: bool) -> void:
	var phase_differs := new_phase != _announced_phase
	_announced_phase = new_phase
	phase = new_phase
	victory = won
	current_round = round_number
	ready_peers = ready_list
	player_count = players
	if round_began:
		round_started.emit(current_round)
	if phase_differs or round_began:
		phase_changed.emit(phase)
	ready_changed.emit(ready_peers, player_count)
