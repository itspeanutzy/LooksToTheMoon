extends Control

@onready var arrow = $ArrowButton

var minimized := false
var original_position: Vector2

const MOVE_DISTANCE := 278.0
const ANIMATION_DURATION := 0.3

func _ready():
	original_position = position
	arrow.pressed.connect(toggle_sidebar)

func toggle_sidebar():
	minimized = !minimized

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	if minimized:
		tween.tween_property(
			self,
			"position:x",
			original_position.x + MOVE_DISTANCE,
			ANIMATION_DURATION
		)
	else:
		tween.tween_property(
			self,
			"position:x",
			original_position.x,
			ANIMATION_DURATION
		)
