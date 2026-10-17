class_name CaveModule
extends Node3D
## Baustein der Mine aus Kenneys Cave Kit (assets/kenney-cave-kit, CC0) in Originalgröße: Ein Tile ist 4 m groß,
## also 2 × 2 Baufelder. Über jedes Teil kommt eine senkrecht gespiegelte Kopie, so ist die Höhle 8 m hoch und der
## gespiegelte Boden bildet die Decke. Das Modul baut sich beim Laden aus einem ASCII-Layout auf
## (Zeilen von Norden nach Süden, Spalten von Westen nach Osten, ein Zeichen pro Tile):
##   #  Fels                       .  Boden
##   s  Schlitz: schmaler Spalt (gut 1 m), nur für Spieler passierbar, nicht im Navigationsnetz
##   o  Erzstelle (ore_spawn_points)   N  Gegner-Eingang (enemy_spawns, Name kommt vom Modul: „NestWest“ → „West“)
##   E  Aufzug    T  Würfel-Station   P  zwei Shop-Stellplätze
##   b  Fass      x  Kisten           a  Amboss    r  Felsbrocken    L  zusätzliches Licht
## Alles außer # und s ist begehbarer Boden. Boden- oder Schlitz-Tiles am Rand sind Ausgänge (Marker unter
## „Exits“, −Z zeigt hinaus); daran setzt der Kartengenerator später Module aneinander.
## Sichtbar sind die Kit-Teile: Wände stehen im Fels-Tile hinter der Kante und zeigen ihre Felsseite zum Boden,
## Ecken von Räumen werden abgerundet (template-corner, nur auf leeren Boden-Tiles), Eckpfeiler verdecken Fugen.
## Die Kollision besteht aus einfachen Boxen: eine Bodenplatte, eine Box hinter jeder Wandkante, drei entlang jeder
## abgerundeten Ecke, zwei pro Schlitz.

const TILE_SIZE: float = 4.0
## Höhe einer Kit-Ebene; die gespiegelte zweite Ebene endet bei der doppelten Höhe (Decke).
const TIER_HEIGHT: float = 4.05
## Höhe der Wand-Kollision, bis zur Decke.
const WALL_HEIGHT: float = 8.2
## Die felsige Seite der Kit-Wände liegt etwas hinter der Tile-Kante; so weit beginnt auch die Kollision dahinter.
const WALL_FACE_OFFSET: float = 0.15
const WALL_THICKNESS: float = 1.5
## Halbe lichte Breite eines Schlitzes. Spieler (Radius 0,4 m) passen durch, Gegner (0,525 m) und das
## Navigationsnetz (Agentenradius 0,5 m) nicht.
const SLIT_HALF_WIDTH: float = 0.48
const LIGHT_HEIGHT: float = 5.5
const LIGHT_COLOR: Color = Color(1, 0.82, 0.6)
const NEST_LIGHT_COLOR: Color = Color(1, 0.35, 0.25)
## Deko aus dem Survival Kit ist im Kit winzig; so passt sie zur Spielfigur.
const PROP_SCALE: float = 3.0

const KIT: String = "res://assets/kenney-cave-kit/GLB format/%s.glb"
const SURVIVAL: String = "res://assets/kenney-survival-kit/GLB format/%s.glb"
const FLOOR_PIECES: Array[String] = ["template-floor", "template-floor", "template-floor-detail", "template-floor",
		"template-floor-detail-a"]
const ELEVATOR_SCENE: PackedScene = preload("res://scenes/world/Elevator.tscn")
const SHOP_TERMINAL_SCENE: PackedScene = preload("res://scenes/world/ShopTerminal.tscn")
const SHOP_PAD_COLOR: Color = Color(0.85, 0.6, 0.2)

## Innenseite der abgerundeten Ecke (template-corner, Fels bei +X/+Z), vereinfacht auf drei Kanten.
const CORNER_ARC: Array[Vector2] = [Vector2(1.3, -2.4), Vector2(0.2, -0.7), Vector2(-0.7, 0.15), Vector2(-2.4, 1.1)]

## Himmelsrichtungen als Raster-Schritte: Osten, Süden, Westen, Norden.
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

@export_multiline var layout: String = "#..#\n#..#"
## Lichtfarbe: Nester leuchten rot.
@export var nest_light: bool = false

var _rows: PackedStringArray = PackedStringArray()
var _width: int = 0
var _height: int = 0
var _kit: Node3D
var _collision: StaticBody3D
var _shapes: Dictionary = {}
var _counter: int = 0


func _ready() -> void:
	_parse()
	_kit = _add(Node3D.new(), self, "Kit") as Node3D
	_collision = _add(StaticBody3D.new(), self, "Collision") as StaticBody3D
	_add_box(Vector3(0, -0.25, 0), 0.0, Vector3(_width * TILE_SIZE, 0.5, _height * TILE_SIZE))
	for j in _height:
		for i in _width:
			_build_tile(Vector2i(i, j))
			_build_rock_floor(Vector2i(i, j))
	for j in _height + 1:
		for i in _width + 1:
			_build_vertex(Vector2i(i, j))
	_build_exits()


## Größe in Tiles.
func get_footprint() -> Vector2i:
	if _rows.is_empty():
		_parse()
	return Vector2i(_width, _height)


## Ausgänge des Moduls; −Z jedes Markers zeigt nach außen.
func get_exits() -> Array[Marker3D]:
	var exits: Array[Marker3D] = []
	var parent := get_node_or_null(^"Exits")
	if parent:
		for child in parent.get_children():
			if child is Marker3D:
				exits.append(child as Marker3D)
	return exits


func _parse() -> void:
	_rows = PackedStringArray()
	for line in layout.split("\n"):
		if not line.strip_edges().is_empty():
			_rows.append(line.strip_edges())
	_height = _rows.size()
	_width = 0
	for row in _rows:
		_width = maxi(_width, row.length())


## Zeichen an einer Rasterstelle. Außerhalb des Moduls: Boden bzw. Schlitz direkt vor einem Ausgang, sonst Fels.
func _at(cell: Vector2i) -> String:
	if cell.x >= 0 and cell.x < _width and cell.y >= 0 and cell.y < _height:
		var row := _rows[cell.y]
		return row[cell.x] if cell.x < row.length() else "#"
	var inside := Vector2i(clampi(cell.x, 0, _width - 1), clampi(cell.y, 0, _height - 1))
	if absi(inside.x - cell.x) + absi(inside.y - cell.y) != 1:
		return "#"
	var edge := _at(inside)
	return "." if _is_floor(edge) else edge


static func _is_floor(c: String) -> bool:
	return c != "#" and c != "s"


func _is_rock(cell: Vector2i) -> bool:
	return not _is_floor(_at(cell))


func _tile_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - (_width - 1) / 2.0) * TILE_SIZE, 0.0, (cell.y - (_height - 1) / 2.0) * TILE_SIZE)


func _build_tile(cell: Vector2i) -> void:
	var c := _at(cell)
	var center := _tile_center(cell)
	if c == "#":
		return
	if c == "s":
		_build_slit(cell, center)
		return
	var walled: Array[int] = []
	var slit: Array[int] = []
	for d in 4:
		var neighbor := _at(cell + DIRECTIONS[d])
		if neighbor == "#":
			walled.append(d)
		elif neighbor == "s":
			slit.append(d)
	var corner := _corner_direction(cell, walled, slit)
	if corner >= 0:
		# Abgerundete Ecke: im Kit liegt der Fels bei +X/+Z, also zwischen Osten (0) und Süden (1).
		var angle := -corner * PI / 2.0
		_add_piece(KIT % "template-corner", center, angle)
		var turn := Basis(Vector3.UP, angle)
		for k in CORNER_ARC.size() - 1:
			var a := turn * Vector3(CORNER_ARC[k].x, 0, CORNER_ARC[k].y)
			var b := turn * Vector3(CORNER_ARC[k + 1].x, 0, CORNER_ARC[k + 1].y)
			var outward := turn * Vector3(1, 0, 1)
			_add_wall_segment(center + a, center + b, outward)
		# Wo die Rundung auf die geraden Wände der Nachbarn trifft, bleibt sonst ein Spalt.
		var along_a := Vector3(DIRECTIONS[corner].x, 0, DIRECTIONS[corner].y)
		var along_b := Vector3(DIRECTIONS[(corner + 1) % 4].x, 0, DIRECTIONS[(corner + 1) % 4].y)
		var toward := Vector2(along_a.x + along_b.x, along_a.z + along_b.z)
		for end: Vector3 in [along_a - along_b, along_b - along_a]:
			_add_piece(KIT % "template-wall-corner", center + end * TILE_SIZE / 2.0, _quadrant_angle(toward))
	else:
		var piece := FLOOR_PIECES[posmod(cell.x * 31 + cell.y * 17, FLOOR_PIECES.size())] if c == "." else "template-floor"
		_add_piece(KIT % piece, center, 0.0)
		for d in walled:
			_build_wall(center, d)
		for d in slit:
			_build_slit_edge(center, d)
	_build_content(c, cell, center)


## Richtung der abgerundeten Ecke (0 = Fels im Osten und Süden, dann im Uhrzeigersinn), oder −1.
func _corner_direction(cell: Vector2i, walled: Array[int], slit: Array[int]) -> int:
	# Der Fels der Rundung reicht bis zur Tile-Mitte; Marker und Deko brauchen dort freien Boden.
	if _at(cell) != "." or walled.size() != 2 or not slit.is_empty():
		return -1
	for d in 4:
		var e := (d + 1) % 4
		if d in walled and e in walled and _is_rock(cell + DIRECTIONS[d] + DIRECTIONS[e]):
			return d
	return -1


## Wand an einer Tile-Kante. template-wall liegt hinter der Kante (Richtung −Z im Kit).
func _build_wall(center: Vector3, d: int) -> void:
	var dir := Vector3(DIRECTIONS[d].x, 0, DIRECTIONS[d].y)
	var edge := center + dir * TILE_SIZE / 2.0
	# template-wall gehört in die Mitte des Fels-Tiles; seine Felsseite (−Z) zeigt zum Boden.
	_add_piece(KIT % "template-wall", center + dir * TILE_SIZE, _facing_angle(-dir))
	_add_box(edge + dir * (WALL_FACE_OFFSET + WALL_THICKNESS / 2.0) + Vector3.UP * WALL_HEIGHT / 2.0, _facing_angle(dir),
			Vector3(TILE_SIZE, WALL_HEIGHT, WALL_THICKNESS))


## Boden unter Fels-Tiles am Rand, damit zwischen Boden und Wandfuß keine Lücke klafft.
func _build_rock_floor(cell: Vector2i) -> void:
	if _at(cell) != "#":
		return
	for dz: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			var neighbor := cell + Vector2i(dx, dz)
			if neighbor.x >= 0 and neighbor.x < _width and neighbor.y >= 0 and neighbor.y < _height and _at(neighbor) != "#":
				_add_piece(KIT % "template-floor", _tile_center(cell), 0.0)
				return


## Kante zu einem Schlitz: links und rechts der 2 m breiten Öffnung je eine halbe Wand. Die Kollision dort liefert
## der Schlitz selbst.
func _build_slit_edge(center: Vector3, d: int) -> void:
	var dir := Vector3(DIRECTIONS[d].x, 0, DIRECTIONS[d].y)
	var side := Vector3(-dir.z, 0, dir.x)
	for side_sign: float in [-1.0, 1.0]:
		_add_piece(KIT % "template-wall-half", center + dir * TILE_SIZE + side * 2.0 * side_sign, _facing_angle(-dir))


## Schlitz: das schmale Gang-Teil des Kits, ausgerichtet auf die offenen Nachbarn.
func _build_slit(cell: Vector2i, center: Vector3) -> void:
	var north_south := not _is_rock(cell + Vector2i(0, -1)) or not _is_rock(cell + Vector2i(0, 1)) \
			or _at(cell + Vector2i(0, -1)) == "s" or _at(cell + Vector2i(0, 1)) == "s"
	var angle := PI / 2.0 if north_south else 0.0
	_add_piece(KIT % "corridor", center, angle)
	var turn := Basis(Vector3.UP, angle)
	var side_width := TILE_SIZE / 2.0 - SLIT_HALF_WIDTH
	for side_sign: float in [-1.0, 1.0]:
		var offset := turn * Vector3(0, 0, side_sign * (SLIT_HALF_WIDTH + side_width / 2.0))
		_add_box(center + offset + Vector3.UP * WALL_HEIGHT / 2.0, angle, Vector3(TILE_SIZE, WALL_HEIGHT, side_width))


## An Rasterpunkten, wo Wände über Eck zusammenstoßen, verdeckt ein Eckstück die Fuge.
func _build_vertex(vertex: Vector2i) -> void:
	var quadrants: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]
	var rock: Array[Vector2i] = []
	for q in quadrants:
		if _is_rock(vertex + q):
			rock.append(q)
	var target := Vector2i(-2, -2)
	if rock.size() == 1:
		target = rock[0]
	elif rock.size() == 3:
		for q in quadrants:
			if not q in rock:
				# Der Boden-Tile rundet die Ecke womöglich schon selbst ab.
				var floor_cell := vertex + q
				var walled: Array[int] = []
				var slit: Array[int] = []
				for d in 4:
					var neighbor := _at(floor_cell + DIRECTIONS[d])
					if neighbor == "#":
						walled.append(d)
					elif neighbor == "s":
						slit.append(d)
				if _corner_direction(floor_cell, walled, slit) >= 0:
					return
				target = Vector2i(-1, -1) - q
	if target.x < -1:
		return
	if _at(vertex + target) == "s":
		return
	var point := _tile_center(Vector2i.ZERO) + Vector3(vertex.x - 0.5, 0, vertex.y - 0.5) * TILE_SIZE
	# Im Kit zeigt das Eckstück in den Quadranten −X/−Z.
	var toward := Vector2(target.x * 2 + 1, target.y * 2 + 1)
	_add_piece(KIT % "template-wall-corner", point, _quadrant_angle(toward))


static func _quadrant_angle(toward: Vector2) -> float:
	if toward.x < 0 and toward.y < 0:
		return 0.0
	if toward.x < 0:
		return PI / 2.0
	if toward.y > 0:
		return PI
	return -PI / 2.0


func _build_content(c: String, cell: Vector2i, center: Vector3) -> void:
	match c:
		"o":
			_add_marker(center, &"ore_spawn_points", "OreSpot")
		"N":
			_add_marker(center, &"enemy_spawns", "EnemySpawn")
		"E":
			var elevator := ELEVATOR_SCENE.instantiate() as Node3D
			elevator.position = center
			_add(elevator, self, "Elevator")
		"T":
			var terminal := SHOP_TERMINAL_SCENE.instantiate() as Node3D
			terminal.position = center
			_add(terminal, self, "ShopTerminal")
		"P":
			for side_sign: float in [-1.0, 1.0]:
				_add_shop_pad(center + Vector3(side_sign, 0.02, 0))
		"b":
			_add_prop("barrel", center + Vector3(-0.6, 0, -0.4), 0.0, true)
			_add_prop("barrel-open", center + Vector3(0.7, 0, 0.5), 0.7, true)
		"x":
			_add_prop("box-large", center + Vector3(-0.5, 0, 0), 0.2, false)
			_add_prop("box", center + Vector3(0.9, 0, 0.6), -0.3, false)
		"a":
			_add_prop("workbench-anvil", center, PI / 2.0, false)
		"r":
			_add_prop("rock-a", center, posmod(cell.x * 7 + cell.y * 3, 6) * 1.0, false, 2.0)
	if c == "L" or (cell.x % 3 == 1 and cell.y % 3 == 1) or (c == "N"):
		_add_light(center, NEST_LIGHT_COLOR if nest_light or c == "N" else LIGHT_COLOR)


func _build_exits() -> void:
	var exits := _add(Node3D.new(), self, "Exits")
	for d in 4:
		var dir := DIRECTIONS[d]
		var run: Array[Vector2i] = []
		var cells: Array[Vector2i] = []
		var count := _width if dir.y != 0 else _height
		for k in count:
			var cell := Vector2i(k, 0 if dir.y < 0 else _height - 1) if dir.y != 0 else Vector2i(0 if dir.x < 0 else _width - 1, k)
			cells.append(cell)
		cells.append(Vector2i(-99, -99))
		for cell in cells:
			if cell.x >= 0 and _at(cell) != "#":
				run.append(cell)
				continue
			if not run.is_empty():
				var middle := (_tile_center(run[0]) + _tile_center(run[run.size() - 1])) / 2.0
				var direction := Vector3(dir.x, 0, dir.y)
				var marker := Marker3D.new()
				marker.position = middle + direction * TILE_SIZE / 2.0
				marker.rotation.y = _facing_angle(direction)
				_add(marker, exits, "Exit")
				run.clear()


## Drehung um die Hochachse, die −Z (Kit-Vorderseite der Wände: dahinter liegt der Fels) auf dir dreht.
static func _facing_angle(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _add_wall_segment(a: Vector3, b: Vector3, outward: Vector3) -> void:
	var along := b - a
	var normal := Vector3(-along.z, 0, along.x).normalized()
	if normal.dot(outward) < 0.0:
		normal = -normal
	var angle := atan2(-along.z, along.x)
	_add_box((a + b) / 2.0 + normal * WALL_THICKNESS / 2.0 + Vector3.UP * WALL_HEIGHT / 2.0, angle,
			Vector3(along.length(), WALL_HEIGHT, WALL_THICKNESS))


## Kit-Teil samt gespiegelter Kopie darüber (zweite Ebene bis zur Decke).
func _add_piece(path: String, at: Vector3, angle: float) -> void:
	var scene := load(path) as PackedScene
	for upper: bool in [false, true]:
		var piece := scene.instantiate() as Node3D
		piece.position = at + (Vector3.UP * TIER_HEIGHT * 2.0 if upper else Vector3.ZERO)
		piece.rotation.y = angle
		# Negative Skalierung spiegelt; Godot dreht dabei die Flächenausrichtung mit, die Seiten bleiben sichtbar.
		piece.scale = Vector3(1, -1, 1) if upper else Vector3.ONE
		_add(piece, _kit, "Piece")


## Box-Kollision; angle dreht die lokale X-Achse der Box um die Hochachse.
func _add_box(at: Vector3, angle: float, size: Vector3) -> void:
	var key := Vector3(snappedf(size.x, 0.01), snappedf(size.y, 0.01), snappedf(size.z, 0.01))
	if not _shapes.has(key):
		var box := BoxShape3D.new()
		box.size = key
		_shapes[key] = box
	var shape := CollisionShape3D.new()
	shape.shape = _shapes[key]
	shape.position = at
	shape.rotation.y = angle
	_add(shape, _collision, "Shape")


func _add_prop(name_in_kit: String, at: Vector3, angle: float, round_shape: bool, scale_factor: float = PROP_SCALE) -> void:
	var prop := (load(SURVIVAL % name_in_kit) as PackedScene).instantiate() as Node3D
	prop.position = at
	prop.rotation.y = angle
	prop.scale = Vector3.ONE * scale_factor
	_add(prop, _kit, "Prop")
	var bounds := _bounds(prop)
	if bounds.size == Vector3.ZERO:
		return
	var shape := CollisionShape3D.new()
	if round_shape:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = maxf(bounds.size.x, bounds.size.z) / 2.0
		cylinder.height = bounds.size.y
		shape.shape = cylinder
	else:
		var box := BoxShape3D.new()
		box.size = bounds.size * Vector3(0.9, 1.0, 0.9)
		shape.shape = box
	shape.position = to_local(bounds.get_center())
	_add(shape, _collision, "Prop")


## Achsenparallele Hülle aller Meshes unter node, in Weltkoordinaten (Deko dreht sich nur um die Hochachse).
func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh_instance in ModelTint.mesh_instances(node):
		var box := mesh_instance.global_transform * mesh_instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _add_marker(at: Vector3, group: StringName, marker_name: String) -> void:
	var marker := Marker3D.new()
	marker.position = at
	marker.add_to_group(group)
	_add(marker, self, marker_name)


func _add_shop_pad(at: Vector3) -> void:
	var pad := CSGBox3D.new()
	pad.size = Vector3(1.4, 0.04, 1.4)
	var material := StandardMaterial3D.new()
	material.albedo_color = SHOP_PAD_COLOR
	pad.material = material
	pad.position = at
	pad.add_to_group(&"shop_pads")
	_add(pad, self, "ShopPad")


func _add_light(at: Vector3, color: Color) -> void:
	var light := OmniLight3D.new()
	light.position = at + Vector3.UP * LIGHT_HEIGHT
	light.light_color = color
	light.light_energy = 1.4
	light.omni_range = 13.0
	_add(light, self, "Light")


## Kind mit eindeutigem, auf allen Peers gleichem Namen anhängen (wichtig für RPCs, z. B. am Aufzug).
func _add(node: Node, parent: Node, base_name: String) -> Node:
	_counter += 1
	node.name = base_name if base_name in ["Kit", "Collision", "Exits", "Elevator", "ShopTerminal"] \
			else "%s%d" % [base_name, _counter]
	parent.add_child(node)
	return node
