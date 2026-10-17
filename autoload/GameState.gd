extends Node
## Globaler Zustand eines Runs: Seed, Spieler und gewählte Mutationen.
## Der Host bestimmt den Seed; alle Zufallsentscheidungen laufen über ihn.
## Was mit demselben Seed gleich sein soll (Erzstellen, Shop-Angebote, Wellen), zieht aus einem eigenen Strom pro
## System und Schicht ([method stream_rng]). Sonst würde z. B. jeder Erzbrocken, der beim Abbauen fliegt, die
## späteren Angebote verschieben. Für alles Übrige (Flugbahnen, Gegnerverhalten) gibt es [member rng].

signal run_seed_changed(seed_value: int)

var run_seed: int = 0
## Allgemeiner Zufall ohne festen Ablauf; hängt davon ab, was im Spiel passiert.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Im Startmenü eingegebener Seed (Zahl oder beliebiger Text); leer = zufällig.
var requested_seed_text: String = ""
## true, solange ein Menü offen ist (z. B. Pause). Die Spielfigur nimmt dann keine Eingaben an.
## Das Spiel selbst läuft weiter, weil im Multiplayer niemand allein pausieren kann.
var input_blocked: bool = false
## Im Startmenü gewähltes Merkmal (Pfad zur TraitData, leer = keins). Die eigene Figur übernimmt es beim Spawnen.
var selected_trait_path: String = ""


func set_run_seed(seed_value: int) -> void:
	run_seed = seed_value
	rng.seed = seed_value
	run_seed_changed.emit(seed_value)


## Eigener Zufallsstrom für ein System in einer Schicht, nur aus dem Run-Seed abgeleitet.
func stream_rng(stream: StringName, round_number: int) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = hash([run_seed, String(stream), round_number])
	return result


## Seed aus der Eingabe im Startmenü: eine Zahl wird direkt genommen, anderer Text gehasht, leer = zufällig.
func seed_from_text(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return new_random_seed()
	if trimmed.is_valid_int():
		return trimmed.to_int()
	return hash(trimmed)


func new_random_seed() -> int:
	var fresh := RandomNumberGenerator.new()
	fresh.randomize()
	return fresh.randi()
