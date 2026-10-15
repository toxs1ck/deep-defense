extends NavigationRegion3D
## Backt das Navigationsnetz beim Laden aus allen Knoten der Gruppe „nav_source“ (z. B. dem ganzen Testraum).
## Später (Aufgabe 11) wird nach dem Bauen neu gebacken.


func _ready() -> void:
	# CSG-Formen bauen ihr Mesh erst verzögert auf; einen Frame warten, sonst ist das Netz leer.
	await get_tree().process_frame
	bake_navigation_mesh(false)
