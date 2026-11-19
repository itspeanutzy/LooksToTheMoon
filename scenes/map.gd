extends Node2D

@onready var fade: ColorRect = $CanvasGroup/fade
@onready var settings: Node2D = $CanvasGroup/settings

func _ready() -> void:
	fade.color.a = 0
	settings.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
