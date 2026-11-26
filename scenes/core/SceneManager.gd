extends Node

const PROLOGUE_TIMELINE := "prologue"          # timeline name, or full path e.g. "res://dialogic/timelines/prologue.dtl"
const MAP_SCENE := "res://scenes/core/map.tscn"

func _ready() -> void:
	start_prologue()

func start_prologue() -> void:
	# CONNECT_ONE_SHOT so it doesn't fire again for later timelines
	Dialogic.timeline_ended.connect(_on_prologue_ended, CONNECT_ONE_SHOT)
	Dialogic.start(PROLOGUE_TIMELINE)

func _on_prologue_ended() -> void:
	change_scene(MAP_SCENE)

func change_scene(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)
