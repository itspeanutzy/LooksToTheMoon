extends Node2D

var rock_scene = preload("res://scenes/minigames/rock thing.tscn")

var last_y = -1000
var min_distance = 250

func _ready():
	var timer = Timer.new()
	timer.wait_time = 0.4
	timer.one_shot = false
	timer.autostart = true

	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)


func _on_timer_timeout():
	var rock = rock_scene.instantiate()

	var random_y = randf_range(100, 3000)

	# Keep rocks from spawning too close vertically
	while abs(random_y - last_y) < min_distance:
		random_y = randf_range(100, 3000)

	rock.position.x = 1650
	rock.position.y = random_y

	last_y = random_y

	add_child(rock)
