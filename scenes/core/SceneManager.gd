extends Node

const MAP_SCENE := "res://scenes/core/map.tscn"

var timeline_sequence = {
	1: "prologue",
	2: "cycle1",
	3: "cycle2intro",
	4: "cycle2end",
	5: "cycle3intro",
	6: "cycle3end",
	7: "cycle3end2", 
	8: "cycle4intro",
	9: "cycle4end"
}

func _ready() -> void:
	var current_level = GameState.prosperity
	var next_timeline = timeline_sequence.get(current_level, "prologue")
	
	Dialogic.timeline_ended.connect(_on_timeline_ended, CONNECT_ONE_SHOT)
	Dialogic.start(next_timeline)

func _on_timeline_ended() -> void:
	get_tree().change_scene_to_file.call_deferred(MAP_SCENE)
