extends CharacterBody2D

signal health_changed(current_health)
signal boat_destroyed()

@export_group("Health")
@export var max_health: int = 3
var current_health: int

@export_group("Movement")
@export var speed: float = 600.0
@export var max_speed: float = 450.0
@export var follow_strength: float = 4.0
@export var acceleration: float = 900.0
@export var friction: float = 700.0
@export var max_tilt_degrees: float = 30.0
@export var tilt_smoothing: float = 10.0

@export_group("Knockback & Recovery")
@export var knockback_distance: float = 100.0
@export var knockback_duration: float = 0.35
@export var recovery_duration: float = 0.4
@export var return_duration: float = 0.5
@export var left_border: float = -150.0

@export_group("Wave Interaction")
@export var wave_speed_multiplier: float = 0.5
@export var flash_duration: float = 0.15

@onready var camera = get_node("../Camera2D")
@onready var sprite = $Sprite2D

var original_x: float
var is_knocked_back = false
var is_returning = false
var wave_slowing = false
var is_wave_pushing = false


func _ready():
	add_to_group("boat")
	original_x = position.x
	current_health = max_health


func _physics_process(delta: float) -> void:
	var min_x = 50
	if global_position.x <= min_x:
		global_position.x = min_x
		
	# DON'T INTERRUPT TWEENS
	if is_knocked_back or is_returning:
		return

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

func get_pushed_by_wave():
	if is_knocked_back or is_returning or is_wave_pushing:
		return
		
	is_wave_pushing = true
	velocity.x = -400
	wave_slowing = true
	
	await get_tree().create_timer(0.3).timeout
	wave_slowing = false
	is_wave_pushing = false

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
	if is_knocked_back or current_health <= 0:
		return
	current_health -= 1
	health_changed.emit(current_health)
	
	if current_health <= 0:
		boat_destroyed.emit()
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
	sprite.self_modulate = Color(3.265, 0.0, 0.0, 1.0)
	flash_tween.tween_property(
		sprite,
		"self_modulate",
		Color.WHITE,
		flash_duration
	)
