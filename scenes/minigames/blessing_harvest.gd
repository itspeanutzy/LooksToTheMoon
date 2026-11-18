extends Node2D

var fish_caught = 0
@onready var score_label = $HUD/FishCounter
@export var total_fish_needed = 10
@export var total_fish_to_spawn = 15
@export var fish_scene : PackedScene

func _ready() -> void:
	spawn_fish()

func spawn_fish() -> void:
	for i in range(total_fish_to_spawn):
		var new_fish = fish_scene.instantiate()
		
		var random_x = randf_range(200,1000)
		var random_y = randf_range(400,650)
		new_fish.position = Vector2(random_x, random_y)
		
		add_child(new_fish)

func _on_boat_area_entered(area: Area2D) -> void:
	if area.is_in_group("Fish"):
		area.queue_free()
		fish_caught += 1
		score_label.text = "Fish : " + str(fish_caught) + "/" + str(total_fish_needed)
		
		if fish_caught >= total_fish_needed:
			print("The Harvest is Bountiful")
