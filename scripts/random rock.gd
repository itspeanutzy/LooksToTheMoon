extends Node2D

@onready var rock_scene = preload("res://scenes/minigames/rock thing.tscn")

var last_y = -1000
var min_distance = 250
var boat
var timer

# DIFFICULTY
var elapsed_time = 0.0

var starting_speed = 350.0
var max_speed = 750.0

var starting_spawn_time = 0.65
var min_spawn_time = 0.25

func _ready():
	boat = get_tree().get_first_node_in_group("boat")

	timer = Timer.new()
	timer.wait_time = starting_spawn_time
	timer.one_shot = false
	timer.autostart = true

	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)


func _process(delta):
	elapsed_time += delta


func _on_timer_timeout():
	if boat and boat.is_knocked_back:
		return

	var rock = rock_scene.instantiate()

	# DIFFICULTY PROGRESSION
	var difficulty = min(elapsed_time / 90.0, 1.0)

	var current_speed = lerp(starting_speed, max_speed, difficulty)

	# RANDOM SPEED
	rock.speed = randf_range(
		current_speed * 0.85,
		current_speed * 1.15
	)

	# RANDOM SIZE
	var random_scale = randf_range(0.65, 1.5)
	rock.scale = Vector2(random_scale, random_scale)

	# RANDOM POSITION
	var random_y = randf_range(100, 3000)

	while abs(random_y - last_y) < min_distance:
		random_y = randf_range(100, 3000)

	rock.position.x = 1650
	rock.position.y = random_y

	last_y = random_y

	add_child(rock)

	# SPAWN INTERVAL PROGRESSION
	var current_spawn_time = lerp(
		starting_spawn_time,
		min_spawn_time,
		difficulty
	)

	timer.start(randf_range(
		current_spawn_time * 0.85,
		current_spawn_time * 1.15
	))
