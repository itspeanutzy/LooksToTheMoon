extends Node

const MAP_SCENE := "res://scenes/core/map.tscn"

# Stack: tiap level punya array timeline, dimainin berurutan
var timeline_sequence = {
	1: ["prologue"],
	2: ["cycle1", "cycle2intro"],
	3: ["cycle2end", "cycle3intro"],
	4: ["cycle3end", "cycle3end2", "cycle4intro"],
	5: ["cycle4end"]
}

var _timeline_queue: Array = []

func _ready() -> void:
	
	var current_level = GameState.prosperity
	_timeline_queue = timeline_sequence.get(current_level, []).duplicate()
	
	if _timeline_queue.is_empty():
		open_map()
		return
	
	_play_next()

func _play_next() -> void:
	if _timeline_queue.is_empty():
		open_map()
		return
	
	var next_timeline = _timeline_queue.pop_front()
	Dialogic.timeline_ended.connect(_on_timeline_ended, CONNECT_ONE_SHOT)
	Dialogic.start(next_timeline)

func _on_timeline_ended() -> void:
	_play_next()  # mainin timeline berikutnya di queue, atau balik ke map kalau habis

func open_map() -> void:
	get_tree().change_scene_to_file.call_deferred(MAP_SCENE)
