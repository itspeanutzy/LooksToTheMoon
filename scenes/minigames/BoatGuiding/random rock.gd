extends Node2D

@onready var rock_scene = preload("res://scenes/minigames/BoatGuiding/rock thing.tscn")
@onready var wave_scene = preload("res://scenes/minigames/BoatGuiding/wave.tscn")

const WaveScript = preload("res://scenes/minigames/BoatGuiding/wave.gd")

var boat
var timer
var wave_timer

var last_y = -1000.0
var min_distance = 250.0

# DIFFICULTY
var elapsed_time = 0.0

var starting_speed = 350.0
var max_speed = 750.0

var starting_spawn_time = 0.65
var min_spawn_time = 0.25

# WAVE SETTINGS
var starting_wave_spawn_time = 5.0
var min_wave_spawn_time = 3.0

var min_wave_y = 100.0
var max_wave_y = 500.0

# ROCK-TO-WAVE SPACING
var min_wave_rock_distance = 600.0


func _ready():
	randomize()

	boat = get_tree().get_first_node_in_group("boat")

	# ROCK TIMER
	timer = Timer.new()
	timer.wait_time = starting_spawn_time
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)

	# WAVE TIMER
	wave_timer = Timer.new()
	add_child(wave_timer)
	wave_timer.timeout.connect(_spawn_wave)
	wave_timer.start(starting_wave_spawn_time)


func _process(delta):
	elapsed_time += delta


# CHECK WHETHER A ROCK WOULD SPAWN TOO CLOSE TO A WAVE
func is_rock_too_close_to_wave(rock_position: Vector2) -> bool:
	for wave in get_tree().get_nodes_in_group("waves"):
		if not is_instance_valid(wave):
			continue

		if abs(rock_position.x - wave.global_position.x) < min_wave_rock_distance:
			return true

	return false


# ROCK SPAWNING
func _on_timer_timeout():
	if boat and boat.is_knocked_back:
		timer.start(0.1)
		return

	var difficulty = min(elapsed_time / 90.0, 1.0)
	var current_speed = lerp(starting_speed, max_speed, difficulty)

	var random_y = randf_range(100.0, 3000.0)

	while abs(random_y - last_y) < min_distance:
		random_y = randf_range(100.0, 3000.0)

	var spawn_position = Vector2(1650, random_y)

	# WAIT IF A WAVE IS TOO CLOSE
	if is_rock_too_close_to_wave(spawn_position):
		timer.start(0.2)
		return

	var rock = rock_scene.instantiate()

	rock.speed = randf_range(
		current_speed * 0.85,
		current_speed * 1.15
	)

	var random_scale = randf_range(0.65, 1.5)
	rock.scale = Vector2(random_scale, random_scale)

	rock.position = spawn_position
	last_y = random_y

	add_child(rock)

	var current_spawn_time = lerp(
		starting_spawn_time,
		min_spawn_time,
		difficulty
	)

	timer.start(randf_range(
		current_spawn_time * 0.85,
		current_spawn_time * 1.15
	))


# WAVE SPAWNING
func _spawn_wave():
	#if boat and boat.is_knocked_back:
	#	wave_timer.start(0.1)
	#	return

	var difficulty = min(elapsed_time / 90.0, 1.0)
	var current_wave_speed = lerp(starting_speed, max_speed, difficulty)

	var wave = wave_scene.instantiate()
	wave.set_script(WaveScript)

	# WAVES ALWAYS MOVE FASTER THAN ROCKS
	wave.speed = randf_range(
		max_speed * 1.2,
		max_speed * 1.35
	)

	wave.position = Vector2(
		get_viewport_rect().size.x + 100,
		randf_range(min_wave_y, max_wave_y)
	)

	wave.add_to_group("waves")
	add_child(wave)

	var current_wave_spawn_time = lerp(
		starting_wave_spawn_time,
		min_wave_spawn_time,
		difficulty
	)

	wave_timer.start(randf_range(
		current_wave_spawn_time * 0.85,
		current_wave_spawn_time * 1.15
	))
