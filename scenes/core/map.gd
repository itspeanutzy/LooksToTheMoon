extends Node2D

@onready var fade: ColorRect = $CanvasGroup/fade

func _ready() -> void:
	fade.color.a = 0
	HUD.show()
	
func _process(_delta: float) -> void:
	pass
