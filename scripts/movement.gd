extends CharacterBody2D

@export var speed: float = 600.0
@export var max_tilt_degrees: float = 30.0  # max rotation up/down
@export var tilt_smoothing: float = 10.0    # higher = snappier rotation

func _physics_process(delta: float) -> void:
	var target_y: float = get_global_mouse_position().y
	var diff: float = target_y - global_position.y

	# Move toward the cursor on Y only
	velocity = Vector2(0, clamp(diff / delta, -speed, speed))
	move_and_slide()

	# Rotate based on movement direction (-1 = full up, 1 = full down)
	var tilt_ratio: float = velocity.y / speed
	var target_rotation: float = deg_to_rad(max_tilt_degrees) * tilt_ratio
	rotation = lerp_angle(rotation, target_rotation, tilt_smoothing * delta)
