class_name HUD
extends Control
## Spiel-HUD: Teamkasse, Schicht und Phase, Fadenkreuz und Interaktions-Prompt („E: Abbauen“), beim Tragen der Hinweis zum Ablegen/Werfen.
## Die angezeigte Taste kommt aus der Input Map und wechselt zwischen Tastatur und Controller,
## je nachdem, was zuletzt benutzt wurde.

## Namen der Controller-Tasten nach Xbox-Belegung (SDL-Indizes), wie in der Steuerungstabelle im GDD.
const JOY_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
}
## Mindestausschlag, ab dem ein Stick als Controller-Nutzung zählt (gegen Stick-Drift).
const JOY_MOTION_THRESHOLD: float = 0.5
const JOY_AXIS_NAMES: Dictionary = { JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT" }
const MOUSE_BUTTON_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "Linksklick", MOUSE_BUTTON_RIGHT: "Rechtsklick", MOUSE_BUTTON_MIDDLE: "Mittelklick",
}

@onready var _prompt_label: Label = %PromptLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _run_label: Label = %RunLabel
@onready var _elevator_label: Label = %ElevatorLabel
@onready var _health_label: Label = %HealthLabel
@onready var _downed_label: Label = %DownedLabel
@onready var _hold_bar: ProgressBar = %HoldBar
@onready var _banner_label: Label = %BannerLabel

var _target: InteractableComponent = null
var _carrying: bool = false
var _build_mode: bool = false
var _build_selection: String = ""
## Vorschau der nächsten Welle (GDD: Typen und Eingänge, nicht die Anzahl).
var _wave_preview: String = ""
## Zuletzt angezeigter Betrag; -1 = noch keiner, dann ohne Aufleuchten.
var _money: int = -1
var _banner_tween: Tween = null
## Restzeit bis zum Respawn; > 0 heißt gefallen.
var _respawn_left: float = 0.0
var _using_gamepad: bool = false


func _ready() -> void:
	_prompt_label.visible = false
	set_money(Economy.team_money)
	_banner_label.visible = false
	_downed_label.visible = false
	_hold_bar.visible = false
	RunManager.phase_changed.connect(_on_phase_changed)
	RunManager.ready_changed.connect(func(_peers: PackedInt32Array, _count: int) -> void: _refresh_run_label())
	_refresh_run_label()


func _process(delta: float) -> void:
	# Countdowns der Kampfphase und bis zum Respawn laufen lokal.
	if RunManager.phase == RunManager.Phase.COMBAT:
		_refresh_run_label()
	if _respawn_left > 0.0:
		_respawn_left = maxf(0.0, _respawn_left - delta)
		_downed_label.text = "Gefallen – zurück am Aufzug in %d s" % ceili(_respawn_left)


func _input(event: InputEvent) -> void:
	var gamepad := _using_gamepad
	if event is InputEventJoypadButton:
		gamepad = true
	elif event is InputEventJoypadMotion:
		gamepad = gamepad or absf((event as InputEventJoypadMotion).axis_value) > JOY_MOTION_THRESHOLD
	elif event is InputEventKey or event is InputEventMouseButton:
		gamepad = false
	if gamepad != _using_gamepad:
		_using_gamepad = gamepad
		_refresh_prompt()


func show_interaction(target: InteractableComponent) -> void:
	_target = target
	_refresh_prompt()


func set_money(amount: int) -> void:
	var changed := _money >= 0 and amount != _money
	_money = amount
	_money_label.text = "Teamkasse: %d $" % amount
	if changed:
		# Kurzes Aufleuchten, damit man die Auszahlung bemerkt.
		_money_label.pivot_offset = _money_label.size / 2.0
		_money_label.scale = Vector2.ONE * 1.25
		create_tween().tween_property(_money_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_phase_changed(phase: int) -> void:
	_refresh_run_label()
	var round_number := RunManager.current_round
	match phase:
		RunManager.Phase.BUILD:
			var boss_note := " – Boss-Schicht!" if RunManager.is_boss_round(round_number) else ""
			_show_banner("Schicht %d – Bauphase%s" % [round_number, boss_note])
		RunManager.Phase.COMBAT:
			_show_banner("Kampfphase!")
		RunManager.Phase.RUN_OVER:
			_show_banner("Run geschafft!" if RunManager.victory else "Der Aufzug ist zerstört!")


func _refresh_run_label() -> void:
	var run := RunManager
	var header := "Schicht %d/%d" % [run.current_round, run.data.rounds_per_run]
	match run.phase:
		RunManager.Phase.BUILD:
			var own := "bereit" if run.is_local_player_ready() else "%s: bereit" % _action_key_name(&"ready")
			_run_label.text = "%s · Bauphase · Bereit %d/%d (%s)" % [header, run.ready_peers.size(), run.player_count, own]
			if not _wave_preview.is_empty():
				_run_label.text += "\n" + _wave_preview
		RunManager.Phase.COMBAT:
			var seconds := ceili(run.combat_time_left)
			_run_label.text = "%s · Kampfphase · %d:%02d" % [header, floori(seconds / 60.0), seconds % 60]
		RunManager.Phase.RUN_OVER:
			if run.victory:
				_run_label.text = "Run geschafft – alle %d Schichten überstanden" % run.data.rounds_per_run
			else:
				_run_label.text = "Run verloren in Schicht %d · Esc: Spiel verlassen" % run.current_round
		_:
			_run_label.text = ""


func _show_banner(text: String) -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner_label.text = text
	_banner_label.visible = true
	_banner_label.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(1.8)
	_banner_tween.tween_property(_banner_label, "modulate:a", 0.0, 0.6)
	_banner_tween.tween_callback(func() -> void: _banner_label.visible = false)


func set_elevator_health(current: int, maximum: int) -> void:
	_elevator_label.text = "Aufzug: %d/%d LP" % [current, maximum]
	# Rot, sobald weniger als ein Drittel übrig ist.
	_elevator_label.modulate = Color(1, 0.35, 0.3) if current * 3 < maximum else Color.WHITE


## Fortschritt beim Halten von E (z. B. Kaufen); 0 blendet den Balken aus.
func set_hold_progress(fraction: float) -> void:
	_hold_bar.visible = fraction > 0.0
	_hold_bar.value = fraction * 100.0


func set_player_health(current: int, maximum: int) -> void:
	_health_label.text = "LP %d/%d" % [current, maximum]
	_health_label.modulate = Color(1, 0.35, 0.3) if current * 3 < maximum else Color.WHITE


func set_downed(downed: bool, respawn_seconds: float) -> void:
	_downed_label.visible = downed
	_respawn_left = respawn_seconds if downed else 0.0
	_refresh_prompt()


func set_wave_preview(enemy_names: PackedStringArray, entrance_names: PackedStringArray) -> void:
	_wave_preview = "Nächste Welle: %s · aus %s" % [", ".join(enemy_names), ", ".join(entrance_names)]
	_refresh_run_label()


func set_build_selection(display_name: String) -> void:
	_build_selection = display_name
	_refresh_prompt()


func set_build_mode(active: bool) -> void:
	_build_mode = active
	_refresh_prompt()


func set_carrying(carrying: bool) -> void:
	_carrying = carrying
	_refresh_prompt()


func _refresh_prompt() -> void:
	_prompt_label.visible = (_target != null or _carrying or _build_mode) and _respawn_left <= 0.0
	if _build_mode:
		if _build_selection.is_empty():
			_prompt_label.text = "Baumodus · keine Kiste in der Hand\n%s: abbauen (wird zur Kiste) · %s: beenden" % [
				_action_key_name(&"aim"), _action_key_name(&"build_mode")]
		else:
			_prompt_label.text = "Baumodus: %s\n%s: aufbauen · %s: drehen · %s: abbauen · %s: beenden" % [
				_build_selection, _action_key_name(&"attack"), _action_key_name(&"build_rotate_right"),
				_action_key_name(&"aim"), _action_key_name(&"build_mode")]
	elif _target:
		var key := _action_key_name(_target.action)
		_prompt_label.text = "%s: %s" % [key, _target.prompt_text]
		if _target.hold_seconds > 0.0:
			_prompt_label.text += " · %s halten: %s" % [key, _target.hold_prompt]
	elif _carrying:
		_prompt_label.text = "%s: Ablegen · %s: Werfen · %s: Baumodus (Kisten aufbauen)" % [
			_action_key_name(&"interact"), _action_key_name(&"attack"), _action_key_name(&"build_mode")]


func _action_key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if _using_gamepad and event is InputEventJoypadButton:
			var index := (event as InputEventJoypadButton).button_index
			return str(JOY_BUTTON_NAMES.get(index, "Taste %d" % index))
		if _using_gamepad and event is InputEventJoypadMotion:
			var axis := (event as InputEventJoypadMotion).axis
			return str(JOY_AXIS_NAMES.get(axis, "Achse %d" % axis))
		if not _using_gamepad and event is InputEventMouseButton:
			var button := (event as InputEventMouseButton).button_index
			return str(MOUSE_BUTTON_NAMES.get(button, "Maustaste %d" % button))
		if not _using_gamepad and event is InputEventKey:
			var key_event := event as InputEventKey
			var keycode := DisplayServer.keyboard_get_keycode_from_physical(key_event.physical_keycode)
			return OS.get_keycode_string(keycode)
	return "?"
