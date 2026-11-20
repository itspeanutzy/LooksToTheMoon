extends Area2D

signal destroyed
@export var health: int = 3
@export var speed: float = 100
var target_position: Vector2

func _ready() -> void:
	add_to_group("Enemy")
	input_event.connect(_on_input_event)
	var base = get_tree().get_first_node_in_group("Base")
	
	if base:
		target_position = base.global_position

func _process(delta: float) -> void:
	var direction = (target_position - global_position).normalized()
	global_position += direction * speed * delta
	rotation = direction.angle() + (PI/2)
	
	
	
func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		take_damage(1)
		
func take_damage (amount):
	health -= amount
	
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	if health <= 0:
		destroyed.emit()
		queue_free()
