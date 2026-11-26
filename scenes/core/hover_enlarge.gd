extends Sprite2D

var normal_scale := Vector2.ONE
var hover_scale := Vector2(1.1, 1.1)

var is_hovering := false
var original_rect: Rect2

func _ready():
	normal_scale = scale
	original_rect = get_rect()

func _process(_delta):
	var mouse_pos = to_local(get_global_mouse_position())

	# Check against original sprite dimensions
	var hovered = original_rect.has_point(mouse_pos)

	if hovered and not is_hovering:
		is_hovering = true
		change_scale(hover_scale)

	elif not hovered and is_hovering:
		is_hovering = false
		change_scale(normal_scale)

func change_scale(target_scale: Vector2):
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.1)
