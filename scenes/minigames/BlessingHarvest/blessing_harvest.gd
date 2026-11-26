extends Node2D

var fish_caught = 0
var time_left: float = 0

@export var total_fish_needed = 10
@export var total_fish_to_spawn = 25
@export var fish_scene : PackedScene
@export var time_limit: float = 30

@onready var score_label = $HUD/FishCounter
@onready var overlay = $OverlayLayer
@onready var message_label = $OverlayLayer/ColorRect/Message

enum MinigameState {INTRO, COUNTDOWN, PLAYING, END}
var current_state = MinigameState.INTRO

func _ready() -> void:
	HUD.hide()
	$HUD.hide()
	
	var level_scale = GameState.prosperity - 1
	total_fish_needed += level_scale * 5
	
	show_message("Click anywhere to continue")

func _input(event: InputEvent) -> void:
	if current_state == MinigameState.INTRO  and event.is_pressed() and event is InputEventMouseButton:
		start_countdown()

func start_countdown() -> void:
	current_state = MinigameState.COUNTDOWN
	_do_countdown()
	
func _do_countdown():
	for i in range(3, 0, -1):
		show_message(str(i))
		await get_tree().create_timer(1.0).timeout
	
	show_message("GO!")
	await get_tree().create_timer(0.5).timeout
	
	overlay.hide()
	$HUD.show()
	time_left = time_limit
	current_state = MinigameState.PLAYING
	spawn_fish()

func show_message(text: String) -> void:
	overlay.show()
	message_label.text = text

func spawn_fish() -> void:
	for i in range(total_fish_to_spawn):
		var new_fish = fish_scene.instantiate()
		
		var random_x = randf_range(200,1000)
		var random_y = randf_range(400,650)
		new_fish.position = Vector2(random_x, random_y)
		
		add_child(new_fish)

func _process(delta: float) -> void:
	if current_state == MinigameState.PLAYING:
		time_left -= delta
		$HUD/Timer.text = "Time: " + str(int(time_left))
		
		if time_left <= 0:
			time_left = 0
			end_minigame(false)

func _on_boat_area_entered(area: Area2D) -> void:
	if area.is_in_group("Fish"):
		area.queue_free()
		fish_caught += 1
		score_label.text = "Fish : " + str(fish_caught) + "/" + str(total_fish_needed)
		
		if fish_caught >= total_fish_needed:
			end_minigame(true)

func end_minigame(is_win: bool) -> void:
	if current_state == MinigameState.END: return
	current_state = MinigameState.END
	$HUD.hide()
	
	var prev_level = GameState.prosperity 
	
	if is_win:
		show_message("The Harvest was Bountiful!")
		GameState.add_rewards(100, 50)
	else:
		show_message("And the Sea stay still")
		GameState.add_rewards(50, 10)
	
	for fish in get_tree().get_nodes_in_group("Fish"):
		fish.queue_free()
		
	await get_tree().create_timer(2.0).timeout
	
	if GameState.prosperity > prev_level:
		get_tree().change_scene_to_file("res://scenes/core/scene_manager.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/core/map.tscn")
