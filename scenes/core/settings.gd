extends CanvasLayer

@onready var anim = $Control/Sprite2D/AnimationPlayer
@onready var bgm_slider = $Control/Sprite2D/BGM
@onready var sfx_slider = $Control/Sprite2D/SFX

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	bgm_slider.value = 1.0
	sfx_slider.value = 1.0

func open_settings():
	show()
	anim.play("slide_up")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_settings():
	anim.play("slide_down")
	await anim.animation_finished
	hide()
	get_tree().paused = false

func _on_bgm_value_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("BGM")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

func _on_sfx_value_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

func _on_return_pressed() -> void:
	close_settings()
	
func _on_backtomenu_pressed() -> void:
	hide()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/core/main_menu.tscn")

func _on_save_pressed() -> void:
	pass

func _on_load_pressed() -> void:
	pass
