extends Control

@onready var fade_rect = $FadeLayer/ColorRect

func _ready():
	fade_rect.color.a = 0.0

func _change_scene_with_fade(scene_path: String):
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
	
	await tween.finished
	
	get_tree().change_scene_to_file(scene_path)


func _on_start_pressed():
	_change_scene_with_fade("res://scenes/core/map.tscn")

func _on_load_pressed():
	pass

func _on_settings_pressed():
	Settings.open_settings()

func _on_credit_pressed():
	pass

func _on_quit_pressed():
	get_tree().quit()
