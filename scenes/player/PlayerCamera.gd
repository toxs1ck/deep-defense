class_name PlayerCamera
extends Node3D
## 3rd-Person-Kamera hinter der Spielfigur.
## Dieser Knoten dreht um die Hochachse (Gier), „Pitch“ neigt. Zwei SpringArm3D verhindern Clipping:
## „ShoulderArm“ prüft den Schulterversatz zur Seite, „BackArm“ den Abstand nach hinten.

@export var distance: float = 3.0
## Abstand im Baumodus (GDD: 7 m), damit man den Bauplatz überblickt.
@export var build_distance: float = 7.0
## Versatz über die Schulter in Metern.
@export var shoulder_offset: float = 0.6
## Startseite: true = rechte Schulter. Mit „camera_switch_shoulder“ wechselbar.
@export var right_shoulder: bool = true
## Dauer des Schulterwechsels in Sekunden.
@export var shoulder_switch_time: float = 0.15
@export var fov: float = 75.0
## Grad pro Pixel Mausbewegung.
@export var mouse_sensitivity: float = 0.15
## Grad pro Sekunde bei voll ausgelenktem rechten Stick.
@export var stick_sensitivity: float = 180.0
@export var min_pitch: float = -70.0
@export var max_pitch: float = 60.0

## Wie schnell das Wackeln abklingt, in Metern pro Sekunde.
const SHAKE_DECAY: float = 0.6

@onready var _pitch: Node3D = $Pitch
@onready var _shoulder_arm: SpringArm3D = $Pitch/ShoulderArm
@onready var _back_arm: SpringArm3D = $Pitch/ShoulderArm/BackArm
@onready var _camera: Camera3D = $Pitch/ShoulderArm/BackArm/Camera3D

## Aktuelle Stärke des Kamerawackelns in Metern; klingt von selbst ab.
var _shake: float = 0.0
## Fortschritt des Schulterwechsels von -1 (links) bis 1 (rechts); läuft linear, angezeigt wird er mit Easing.
var _shoulder_side: float = 1.0


func _ready() -> void:
	_back_arm.spring_length = distance
	_shoulder_side = 1.0 if right_shoulder else -1.0
	_apply_shoulder()
	_camera.fov = fov
	# Bis activate() aufgerufen wird, verarbeitet die Kamera keine Eingaben (z. B. Figuren anderer Spieler).
	set_process(false)
	set_process_unhandled_input(false)


## Macht diese Kamera zur aktiven Kamera und nimmt Maus und Stick entgegen.
func activate() -> void:
	_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_process(true)
	set_process_unhandled_input(true)


## Globale Transformation der eigentlichen Kamera, z. B. für Raycasts durch die Bildmitte.
func get_view_transform() -> Transform3D:
	return _camera.global_transform


## Basis nur mit der Gier der Kamera, um Eingaben relativ zur Blickrichtung umzurechnen.
func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, global_rotation.y)


func set_build_view(enabled: bool) -> void:
	var target := build_distance if enabled else distance
	create_tween().tween_property(_back_arm, "spring_length", target, 0.3).set_trans(Tween.TRANS_SINE)


## Kurzes Wackeln, z. B. bei eigenen Treffern oder erlittenem Schaden.
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, SHAKE_DECAY * delta)
		_camera.h_offset = randf_range(-_shake, _shake)
		_camera.v_offset = randf_range(-_shake, _shake)
	var target_side := 1.0 if right_shoulder else -1.0
	if _shoulder_side != target_side:
		_shoulder_side = move_toward(_shoulder_side, target_side, 2.0 / shoulder_switch_time * delta)
		_apply_shoulder()

	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if look != Vector2.ZERO and not GameState.input_blocked:
		_rotate_view(-look * stick_sensitivity * delta)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.input_blocked:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Nach Alt-Tab o. Ä. fängt ein Klick die Maus wieder ein.
		if event is InputEventMouseButton and event.is_pressed():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("camera_switch_shoulder"):
		right_shoulder = not right_shoulder
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_rotate_view(-motion.screen_relative * mouse_sensitivity)


func _rotate_view(degrees: Vector2) -> void:
	rotation_degrees.y += degrees.x
	_pitch.rotation_degrees.x = clampf(_pitch.rotation_degrees.x + degrees.y, min_pitch, max_pitch)


## Dreht den Schulterarm zur aktuellen Seite und gleicht den hinteren Arm aus, damit die Kamera nach vorne schaut.
## Der Seitenwechsel läuft über die Armlänge, die Richtung springt nur bei Länge 0 um.
func _apply_shoulder() -> void:
	# smoothstep sorgt für sanftes Anfahren und Abbremsen statt einer linearen Bewegung.
	var eased := smoothstep(-1.0, 1.0, _shoulder_side) * 2.0 - 1.0
	var side_sign := 1.0 if eased >= 0.0 else -1.0
	_shoulder_arm.basis = Basis(Vector3.UP, side_sign * PI / 2.0)
	_back_arm.basis = Basis(Vector3.UP, -side_sign * PI / 2.0)
	_shoulder_arm.spring_length = shoulder_offset * absf(eased)
