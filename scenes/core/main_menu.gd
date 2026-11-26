extends Control

@onready var fade_rect = $FadeLayer/ColorRect
@export var buttons: Control

func _ready():
	HUD.hide()
	fade_rect.color.a = 0.0
	for button: Button in buttons.get_children():
		button.mouse_entered.connect(func():
			AudioManager.play_sfx(&"hover_big")
		)

func _change_scene_with_fade(scene_path: String):
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
	
	await tween.finished
	
	get_tree().change_scene_to_file(scene_path)

# Audio




func _on_start_pressed():
	_change_scene_with_fade("res://scenes/core/scene_manager.tscn")
	AudioManager.play_sfx(&"click")

func _on_load_pressed():
	pass

func _on_settings_pressed():
	Settings.open_settings()
#	_change_scene_with_fade("res://scenes/core/settings.tscn")
	AudioManager.play_sfx(&"open_settings")

func _on_credit_pressed():
	AudioManager.play_sfx(&"click")
	pass

func _on_quit_pressed():
	AudioManager.play_sfx(&"click")
	get_tree().quit()
