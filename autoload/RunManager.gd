extends Node
## Steuert den Ablauf eines Runs: Schichten, Bau- und Kampfphase, Sieg und Niederlage.
## Die eigentliche Logik folgt in Aufgabe 8 des Prototyp-Plans.

enum Phase { LOBBY, BUILD, COMBAT, RUN_OVER }

signal phase_changed(new_phase: Phase)
signal round_started(round_number: int)

const ROUNDS_PER_RUN: int = 15
const BOSS_ROUNDS: Array[int] = [5, 10, 15]

var phase: Phase = Phase.LOBBY
var current_round: int = 0


func is_boss_round(round_number: int) -> bool:
	return round_number in BOSS_ROUNDS


func set_phase(new_phase: Phase) -> void:
	if new_phase == phase:
		return
	phase = new_phase
	phase_changed.emit(phase)
