extends CharacterBody2D

@export var speed: float = 600.0
@export var max_tilt_degrees: float = 30.0
@export var tilt_smoothing: float = 10.0

# KNOCKBACK
var is_knocked_back = false
var original_x: float

@export var knockback_distance: float = 100.0
@export var knockback_duration: float = 0.35
@export var recovery_duration: float = 0.4
@onready var camera = get_node("../Camera2D")
@export var flash_duration: float = 0.15
@onready var sprite = $Sprite2D


func _ready():
	add_to_group("boat")
	original_x = position.x


func _physics_process(delta: float) -> void:

	if is_knocked_back:
		return

	# Normal mouse movement
	var target_y: float = get_global_mouse_position().y
	var diff: float = target_y - global_position.y

	velocity = Vector2(0, clamp(diff / delta, -speed, speed))

	move_and_slide()

	# Boat tilt
	var tilt_ratio: float = velocity.y / speed
	var target_rotation: float = deg_to_rad(max_tilt_degrees) * tilt_ratio

	rotation = lerp_angle(rotation, target_rotation, tilt_smoothing * delta)


func take_damage():

	if is_knocked_back:
		return

	is_knocked_back = true

	# WHITE FLASH
	flash_white()
	camera.shake()

	# KNOCKBACK + RECOVERY
	var tween = create_tween()

	# Move backwards with ease out
	tween.tween_property(
		self,
		"position:x",
		original_x - knockback_distance,
		knockback_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Return with ease in
	tween.tween_property(
		self,
		"position:x",
		original_x,
		recovery_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tween.finished

	is_knocked_back = false


func flash_white():

	var flash_tween = create_tween()
	sprite.self_modulate = Color(5, 5, 5, 1)
	flash_tween.tween_property(
		sprite,
		"self_modulate",
		Color.WHITE,
		flash_duration
	)
