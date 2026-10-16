extends Node
## Globaler Zustand eines Runs: Seed, Spieler und gewählte Mutationen.
## Der Host bestimmt den Seed; alle Zufallsentscheidungen laufen über [member rng].

signal run_seed_changed(seed_value: int)

var run_seed: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## true, solange ein Menü offen ist (z. B. Pause). Die Spielfigur nimmt dann keine Eingaben an.
## Das Spiel selbst läuft weiter, weil im Multiplayer niemand allein pausieren kann.
var input_blocked: bool = false
## Im Startmenü gewähltes Merkmal (Pfad zur TraitData, leer = keins). Die eigene Figur übernimmt es beim Spawnen.
var selected_trait_path: String = ""


func set_run_seed(seed_value: int) -> void:
	run_seed = seed_value
	rng.seed = seed_value
	run_seed_changed.emit(seed_value)


func new_random_seed() -> int:
	var fresh := RandomNumberGenerator.new()
	fresh.randomize()
	return fresh.randi()
