extends Area2D

var speed = 200
var boat

func _ready():
	add_to_group("rocks")
	body_entered.connect(_on_body_entered)
	boat = get_tree().get_first_node_in_group("boat")


func _process(delta):
	#if boat != null and boat.is_knocked_back:
	#	return

	position.x -= speed * delta


func _on_body_entered(body):
	if body.name == "boat":
		body.take_damage()
		queue_free()
