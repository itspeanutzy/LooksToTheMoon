
extends CharacterBody2D

@export var speed: float = 600.0
@export var max_tilt_degrees: float = 30.0
@export var tilt_smoothing: float = 10.0

# MOVEMENT FEEL
@export var max_speed: float = 450.0
@export var follow_strength: float = 4.0
@export var acceleration: float = 900.0
@export var friction: float = 700.0

# KNOCKBACK
var is_knocked_back = false

@export var knockback_distance: float = 100.0
@export var knockback_duration: float = 0.35
@export var recovery_duration: float = 0.4

# POSITION RETURN
var is_returning = false

@export var return_duration: float = 0.5
@export var left_border: float = -150.0

@onready var camera = get_node("../Camera2D")
@export var flash_duration: float = 0.15
@onready var sprite = $Sprite2D

var original_x: float
var wave_slowing = false

@export var wave_speed_multiplier: float = 0.5


func _ready():
	add_to_group("boat")
	original_x = position.x


func _physics_process(delta: float) -> void:

	#i gotta edit this one into you get slimed if u hit border
	if global_position.x <= left_border:
		if not is_returning and not is_knocked_back:
			return_to_normal_position()
		return

	# DON'T INTERRUPT TWEENS
	if is_knocked_back or is_returning:
		return

	# MOUSE MOVEMENT
	var target_position = get_global_mouse_position()
	var diff = target_position - global_position
	var desired_velocity = Vector2.ZERO

	if diff.length() > 5.0:
		var current_max_speed = max_speed
		
		if wave_slowing:
			current_max_speed *= wave_speed_multiplier
			
		desired_velocity = diff.normalized() * min(
			diff.length() * follow_strength,
			current_max_speed
		)

	var rate = acceleration if desired_velocity.length() > velocity.length() else friction
	
	velocity = velocity.move_toward(
		desired_velocity,
		rate * delta
	)
	
	move_and_slide()
	
	var tilt_ratio = velocity.y / max_speed
	var target_rotation = deg_to_rad(max_tilt_degrees) * tilt_ratio
	
	rotation = lerp_angle(
		rotation,
		target_rotation,
		tilt_smoothing * delta
	)


func return_to_normal_position():
	if is_returning or is_knocked_back:
		return

	is_returning = true
	velocity = Vector2.ZERO

	var tween = create_tween()

	tween.tween_property(
		self,
		"position:x",
		original_x,
		return_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tween.finished

	is_returning = false


func take_damage():
	if is_knocked_back:
		return

	is_knocked_back = true

	flash_white()
	camera.shake()

	var tween = create_tween()

	tween.tween_property(
		self,
		"position:x",
		position.x - knockback_distance,
		knockback_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
