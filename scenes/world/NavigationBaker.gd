extends NavigationRegion3D
## Backt das Navigationsnetz beim Laden aus allen Knoten der Gruppe „nav_source“ (z. B. dem ganzen Testraum).
## Quelle sind die Kollisionsformen auf Ebene „world“, nicht die sichtbaren Meshes: Die liegen auf der GPU und
## auszulesen bremst. Radius und Steighöhe im NavigationMesh sind Vielfache der Zellgröße (0,25 m).
## Später (Aufgabe 11) wird nach dem Bauen neu gebacken.


func _ready() -> void:
	# CSG-Formen bauen ihr Mesh erst verzögert auf; einen Frame warten, sonst ist das Netz leer.
	await get_tree().process_frame
	bake_navigation_mesh(false)
