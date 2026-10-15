extends Node3D
## Einstiegsszene. Lädt vorerst einen Testraum mit einer Spielfigur; Mine, Netzwerk und HUD folgen in den nächsten Aufgaben.


func _ready() -> void:
	print("Deep Defense gestartet – Godot %s" % Engine.get_version_info().string)


func _unhandled_input(event: InputEvent) -> void:
	# Bis es ein Pausemenü gibt, beendet Esc den Prototyp.
	if event.is_action_pressed("menu"):
		get_tree().quit()
