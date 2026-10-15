extends Node
## Globaler Zustand eines Runs: Seed, Spieler und gewählte Mutationen.
## Der Host bestimmt den Seed; alle Zufallsentscheidungen laufen über [member rng].

signal run_seed_changed(seed_value: int)

var run_seed: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func set_run_seed(seed_value: int) -> void:
	run_seed = seed_value
	rng.seed = seed_value
	run_seed_changed.emit(seed_value)


func new_random_seed() -> int:
	var fresh := RandomNumberGenerator.new()
	fresh.randomize()
	return fresh.randi()
