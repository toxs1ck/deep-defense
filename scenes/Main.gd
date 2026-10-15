extends Node3D
## Einstiegsszene. Lädt vorerst nur einen Testraum; Spieler, Mine und HUD kommen in den folgenden Aufgaben dazu.


func _ready() -> void:
	print("Deep Defense gestartet – Godot %s" % Engine.get_version_info().string)


func _unhandled_input(event: InputEvent) -> void:
	# Bis es ein Pausemenü gibt, beendet Esc den Prototyp.
	if event.is_action_pressed("menu"):
		get_tree().quit()
