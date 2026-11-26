extends Node

signal stats_changed
signal prosperity_leveled_up(new_level)
signal level_up_triggered

var faith: int = 0 # Currency
var prosperity: int = 1 # Level (Milestone)
var current_xp: int = 0

func get_xp_needed() -> int:
	return prosperity * 100 

func add_rewards(currency_amount: int, xp_amount: int):
	faith += currency_amount
	current_xp += xp_amount
	
	var needed = get_xp_needed()
	while current_xp >= needed:
		current_xp -= needed
		prosperity += 1
		needed = get_xp_needed()
		level_up_triggered.emit() 
		
	stats_changed.emit()
