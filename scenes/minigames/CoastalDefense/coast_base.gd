extends Area2D

signal base_destroyed
@export var max_health: int = 10
var health: int = 10

func _ready() -> void:
	health = max_health
	area_entered.connect(_on_area_entered)

func _on_area_entered(area) -> void:
	if area.is_in_group("Enemy") or area.name.contains("EnemyBoat"):
		take_damage(1)
		area.queue_free()

func take_damage(amount) -> void:
	health -= amount
	if health <= 0:
		base_destroyed.emit()
