
extends DialogicLayoutLayer

@onready var blur_rect: ColorRect = $BlurRect
@onready var top_lid: ColorRect = $TopLid
@onready var bottom_lid: ColorRect = $BottomLid

const BLUR_MAX := 12.0
const LID_BLUR_MAX := 0.1


func _ready() -> void:
	_set_closed(0.0)
	_set_blur(0.0)
	_set_lid_blur(0.0)
	Dialogic.signal_event.connect(_on_signal)


func _on_signal(argument: String) -> void:
	match argument:
		"lids_close":
			_set_closed(1.0)
			_set_blur(BLUR_MAX)
			_set_lid_blur(0.0)

		"lids_blink":
			_blink()


# 1.0 = fully shut, 0.0 = fully open
func _set_closed(amount: float) -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var half: float = screen.y / 2.0

	top_lid.size = Vector2(screen.x, half)
	top_lid.position = Vector2(0, -half * (1.0 - amount))

	bottom_lid.size = Vector2(screen.x, half)
	bottom_lid.position = Vector2(0, screen.y - half * amount)


# Background blur
func _set_blur(value: float) -> void:
	var mat := blur_rect.material as ShaderMaterial

	if mat == null:
		push_warning("BlurRect has no ShaderMaterial")
		return

	mat.set_shader_parameter("radius", value)


# Eyelid edge blur
func _set_lid_blur(value: float) -> void:
	for lid in [top_lid, bottom_lid]:
		var mat := lid.material as ShaderMaterial

		if mat == null:
			push_warning(lid.name + " has no ShaderMaterial")
			continue

		mat.set_shader_parameter("blur_amount", value)


func _blink() -> void:
	var t := create_tween()

	# First blink: slowly peek open
	t.tween_method(_set_closed, 1.0, 0.75, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_set_blur, BLUR_MAX, 9.0, 0.55)
	t.parallel().tween_method(_set_lid_blur, 0.0, LID_BLUR_MAX * 0.5, 0.55)

	t.tween_interval(0.12)

	t.tween_method(_set_closed, 0.75, 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_method(_set_lid_blur, LID_BLUR_MAX * 0.5, 0.0, 0.25)

	# Second blink: vision becoming clearer
	t.tween_interval(0.2)

	t.tween_method(_set_closed, 1.0, 0.3, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_set_blur, 9.0, 4.0, 0.75)
	t.parallel().tween_method(_set_lid_blur, 0.0, LID_BLUR_MAX, 0.75)

	t.tween_interval(0.18)

	t.tween_method(_set_closed, 0.3, 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_method(_set_lid_blur, LID_BLUR_MAX, 0.0, 0.22)

	# Final opening: gradually regain full vision
	t.tween_interval(0.3)

	t.tween_method(_set_closed, 1.0, 0.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_set_blur, 4.0, 0.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_set_lid_blur, 0.0, LID_BLUR_MAX, 0.4)
	t.parallel().tween_method(_set_lid_blur, LID_BLUR_MAX, 0.0, 1.4)
