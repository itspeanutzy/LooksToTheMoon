extends TextureButton

const HOVER_MULTIPLIER := 1.1
const TWEEN_TIME := 0.1

var normal_scale: Vector2
var is_hovering := false
var _tween: Tween

func _ready():
	normal_scale = scale
	_update_pivot()
	resized.connect(_update_pivot)

func _update_pivot() -> void:
	pivot_offset = size / 2.0

func _process(_delta):
	# Local space, so the rect starts at (0, 0), not at the button's position
	var hovered := Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())

	if hovered and not is_hovering:
		is_hovering = true
		change_scale(normal_scale * HOVER_MULTIPLIER)
	elif not hovered and is_hovering:
		is_hovering = false
		change_scale(normal_scale)

func change_scale(target_scale: Vector2) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", target_scale, TWEEN_TIME)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
