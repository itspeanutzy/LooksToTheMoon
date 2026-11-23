extends Area2D

var speed = 450.0

func _ready():
	add_to_group("finish_line")
	body_entered.connect(_on_body_entered)

func _process(delta):
	position.x -= speed * delta

func _on_body_entered(body):
	if body.is_in_group("boat"):
		get_tree().call_group("game_manager", "win_game")
		queue_free()
