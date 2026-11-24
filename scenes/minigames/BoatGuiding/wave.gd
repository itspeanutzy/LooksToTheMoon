extends Area2D
var speed: float = 350.0
var gap_y: float = 540.0

var wave_width = 100.0
var gap_height = 250.0
var wave_height = 1080.0

var pushed_rocks = {}


func _ready():
	add_to_group("waves")
	wave_height = get_viewport_rect().size.y
	generate_wave()
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("boat"):
		body.get_pushed_by_wave()

func _process(delta):
	#var boat = get_tree().get_first_node_in_group("boat")

	#if boat and boat.is_knocked_back:
	#	return

	#push_rocks()
	position.x -= speed * delta

	if position.x + wave_width / 2 < 0:
		queue_free()


func push_rocks():
	var rocks = get_tree().get_nodes_in_group("rocks")

	for rock in rocks:
		if not is_instance_valid(rock):
			continue

		var distance = global_position.x - rock.global_position.x

		if distance >= 0 and distance <= wave_width + 50:
			if not pushed_rocks.has(rock):
				pushed_rocks[rock] = rock.speed

			rock.speed = speed


func _exit_tree():
	for rock in pushed_rocks:
		if is_instance_valid(rock):
			rock.speed = pushed_rocks[rock]


func generate_wave():
	var top_height = gap_y - gap_height / 2
	var bottom_start = gap_y + gap_height / 2
	var bottom_height = wave_height - bottom_start

	create_section(0, top_height)
	create_section(bottom_start, bottom_height)


func create_section(start_y, section_height):
	if section_height <= 0:
		return

	var collision = CollisionShape2D.new()
	var rectangle = RectangleShape2D.new()

	rectangle.size = Vector2(wave_width, section_height)

	collision.shape = rectangle
	collision.position.y = start_y + section_height / 2

	add_child(collision)
