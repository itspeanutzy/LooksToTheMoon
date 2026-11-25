extends Node

signal stats_changed
signal cycle_advanced

var faith: int = 0
var prosperity: int = 1
var faith_needed: int = 100

func add_faith(amount: int):
	faith += amount
	stats_changed.emit()
	
	if faith >= faith_needed:
		faith -= faith_needed
		prosperity += 1
		faith_needed += 50
		stats_changed.emit()
		cycle_advanced.emit()
