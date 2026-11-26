extends TextureButton

signal scene_requested(scene_path)
@onready var label = $Label
var target_scene: String = ""

func _ready():
	pass
	
func setup(game_name: String, scene_path: String):
	target_scene = scene_path
	label.text = game_name 

func _on_pressed() -> void:
	if target_scene != "":
		scene_requested.emit(target_scene)
