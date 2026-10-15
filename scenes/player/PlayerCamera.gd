class_name PlayerCamera
extends Node3D
## 3rd-Person-Kamera hinter der Spielfigur.
## Dieser Knoten dreht um die Hochachse (Gier), „Pitch“ neigt, der SpringArm3D verhindert Clipping durch Wände.

@export var distance: float = 4.0
## Versatz nach rechts über die Schulter in Metern.
@export var shoulder_offset: float = 0.6
@export var fov: float = 75.0
## Grad pro Pixel Mausbewegung.
@export var mouse_sensitivity: float = 0.15
## Grad pro Sekunde bei voll ausgelenktem rechten Stick.
@export var stick_sensitivity: float = 180.0
@export var min_pitch: float = -70.0
@export var max_pitch: float = 60.0

@onready var _pitch: Node3D = $Pitch
@onready var _spring_arm: SpringArm3D = $Pitch/SpringArm3D
@onready var _camera: Camera3D = $Pitch/SpringArm3D/Camera3D


func _ready() -> void:
	_spring_arm.spring_length = distance
	_camera.h_offset = shoulder_offset
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


## Basis nur mit der Gier der Kamera, um Eingaben relativ zur Blickrichtung umzurechnen.
func get_yaw_basis() -> Basis:
	return Basis(Vector3.UP, global_rotation.y)


func _process(delta: float) -> void:
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if look != Vector2.ZERO:
		_rotate_view(-look * stick_sensitivity * delta)


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Nach Alt-Tab o. Ä. fängt ein Klick die Maus wieder ein.
		if event is InputEventMouseButton and event.is_pressed():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_rotate_view(-motion.screen_relative * mouse_sensitivity)


func _rotate_view(degrees: Vector2) -> void:
	rotation_degrees.y += degrees.x
	_pitch.rotation_degrees.x = clampf(_pitch.rotation_degrees.x + degrees.y, min_pitch, max_pitch)
