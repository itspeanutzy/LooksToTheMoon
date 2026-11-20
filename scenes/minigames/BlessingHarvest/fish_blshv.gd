extends Area2D

@export var speed : float = 150
@export var panic : float = 150

func _ready() -> void:
	add_to_group("Fish")
	
func _process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var distance = global_position.distance_to(mouse_pos)
	
	if distance < panic:
		var direction = (global_position - mouse_pos).normalized()
		global_position += direction * speed * delta
		
		rotation = direction.angle() + (PI/2)
		
	var screen_size = get_viewport_rect().size
	var margin = 50
	
	global_position.x = clamp(global_position.x, margin, screen_size.x - margin)
	global_position.y = clamp(global_position.y, margin, screen_size.y - margin)
