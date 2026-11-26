extends Node2D

@onready var overlay = $OverlayLayer
@onready var message_label = $OverlayLayer/ColorRect2/Message
@onready var time_label = $HUD/TimeLabel
@onready var health_bar = $HUD/BaseHealthBar
@export var enemy_scene: PackedScene
@export var survive_timer: float = 30
var time_left: float
var climax_triggered = false

enum MinigameState {INTRO, COUNTDOWN, PLAYING, END}
var current_state = MinigameState.INTRO

func _ready() -> void:
	HUD.hide()
	$HUD.hide()
	
	var level_scale = GameState.prosperity - 1
	survive_timer += level_scale * 5.0
	$SpawnTimer.wait_time = max(0.4, $SpawnTimer.wait_time - (level_scale * 0.1))
	
	$SurviveTimer.wait_time = survive_timer
	$SurviveTimer.timeout.connect(_on_survive_timer_timeout)
	$SpawnTimer.timeout.connect(_on_spawn_timer_timeout)
	$Coast.add_to_group("Base")
	$Coast.base_destroyed.connect(_on_base_destroyed)
	
	show_message("Click anywhere to continue")

func _input(event: InputEvent) -> void:
	if current_state == MinigameState.INTRO and event.is_pressed() and event is InputEventMouseButton:
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
	time_left = survive_timer
	current_state = MinigameState.PLAYING
	
	$SurviveTimer.start()
	$SpawnTimer.start()

func show_message(text: String) -> void:
	overlay.show()
	message_label.text = text

func _process(_delta: float) -> void:
	if current_state == MinigameState.PLAYING:
		time_left = $SurviveTimer.time_left
		time_label.text = str(int(time_left))
		if $Coast:
			health_bar.value = $Coast.health
		
		if time_left <= 10.0 and not climax_triggered:
			climax_triggered = true
			$SpawnTimer.wait_time = $SpawnTimer.wait_time / 2.0

func _on_spawn_timer_timeout() -> void:
	if current_state != MinigameState.PLAYING: return
	var new_boat = enemy_scene.instantiate()
	var random_y = randf_range(100, 600)
	new_boat.global_position = Vector2(1100, random_y)
	add_child(new_boat)

func _on_survive_timer_timeout() -> void:
	end_minigame(true)

func _on_base_destroyed() -> void:
	end_minigame(false)

func end_minigame(is_win: bool) -> void:
	if current_state == MinigameState.END: return
	current_state = MinigameState.END
	$HUD.hide()
	$SpawnTimer.stop()
	$SurviveTimer.stop()
	
	var prev_level = GameState.prosperity
	
	if is_win:
		show_message("The Coast is Clear")
		GameState.add_rewards(100, 50)
	else:
		show_message("Krishark Coast has Fallen!!")
		GameState.add_rewards(50, 10)
		
	for enemy in get_tree().get_nodes_in_group("Enemy"):
		enemy.queue_free()
		
	await get_tree().create_timer(2.0).timeout
	
	if GameState.prosperity > prev_level:
		get_tree().change_scene_to_file("res://scenes/core/scene_manager.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/core/map.tscn")
