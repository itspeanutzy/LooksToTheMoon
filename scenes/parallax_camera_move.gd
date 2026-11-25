extends Camera2D

## Turn the mouse-follow effect on/off (does not affect the camera itself)
@export var mouse_follow: bool = true

## Max distance (pixels) the camera shifts when the mouse is at the screen edge
@export var amount: Vector2 = Vector2(150, 100)

## How fast the camera follows (higher = snappier)
@export var smoothing: float = 8.0

## Ignore mouse movement near the center (0 to 1)
@export_range(0.0, 0.9) var dead_zone: float = 0.0

# How much of the current offset comes from this script
var _applied := Vector2.ZERO

func _process(delta: float) -> void:
	var target := Vector2.ZERO

	if mouse_follow:
		var viewport := get_viewport()
		var size := viewport.get_visible_rect().size
		var mouse := viewport.get_mouse_position()

		var n := (mouse - size * 0.5) / (size * 0.5)
		n = n.clamp(Vector2(-1, -1), Vector2(1, 1))

		if dead_zone > 0.0:
			n.x = _apply_dead_zone(n.x)
			n.y = _apply_dead_zone(n.y)

		target = n * amount

	var weight := 1.0 - exp(-smoothing * delta)
	var new_applied := _applied.lerp(target, weight)

	# Add only the change in our contribution, so anything else
	# (like an AnimationPlayer) that sets offset is left intact
	offset += new_applied - _applied
	_applied = new_applied

func _apply_dead_zone(v: float) -> float:
	var a := absf(v)
	if a <= dead_zone:
		return 0.0
	return signf(v) * (a - dead_zone) / (1.0 - dead_zone)
