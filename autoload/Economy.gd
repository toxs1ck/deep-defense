extends Node
## Gemeinsame Teamkasse. Später auch Shop-Angebote und Reroll-Kosten (Aufgabe 7 und 14).
## Änderungen am Geld laufen nur über den Host.

signal money_changed(amount: int)

var team_money: int = 0


func add_money(amount: int) -> void:
	assert(amount >= 0, "add_money erwartet einen positiven Betrag")
	team_money += amount
	money_changed.emit(team_money)


func can_afford(cost: int) -> bool:
	return team_money >= cost


func try_spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	team_money -= cost
	money_changed.emit(team_money)
	return true


func reset() -> void:
	team_money = 0
	money_changed.emit(team_money)
