class_name setting_button extends Button

@onready var settings: Node2D = $"../settings"
@onready var anim: AnimationPlayer = $AnimationPlayer

func _on_pressed() -> void:
	settings.show()
	anim.play("open")
	get_tree().paused = true
	
