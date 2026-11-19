extends Camera2D

var shake_strength = 0.0
var shake_decay = 25.0

func _process(delta):
	if shake_strength > 0:
		offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)

		shake_strength = move_toward(
			shake_strength,
			0.0,
			shake_decay * delta
		)
	else:
		offset = Vector2.ZERO


func shake():
	shake_strength = 10.0
