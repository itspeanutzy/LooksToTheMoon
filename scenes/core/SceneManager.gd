extends Node

const MAP_SCENE := "res://scenes/core/map.tscn"

@onready var overlay = $CanvasLayer/TransitionOverlay

var timeline_sequence = {
	1: ["prologue"],
	2: ["cycle1", "cycle2intro"],
	3: ["cycle2end", "cycle3intro"],
	4: ["cycle3end", "cycle3end2", "cycle4intro"],
	5: ["cycle4end"]
}

var _timeline_queue: Array = []

func _ready() -> void:
	overlay.visible = true

	var current_level = GameState.prosperity
	_timeline_queue = timeline_sequence.get(current_level, []).duplicate()

	if _timeline_queue.is_empty():
		get_tree().change_scene_to_file.call_deferred(MAP_SCENE)
		return

	_play_next()

func _play_next() -> void:
	if _timeline_queue.is_empty():
		get_tree().change_scene_to_file.call_deferred(MAP_SCENE)
		return

	var next_timeline = _timeline_queue.pop_front()

	Dialogic.timeline_ended.connect(_on_timeline_ended, CONNECT_ONE_SHOT)
	Dialogic.start(next_timeline)

	await get_tree().process_frame
	overlay.visible = false

func _on_timeline_ended() -> void:
	overlay.visible = true
	_play_next.call_deferred()
