extends Node2D

@onready var spawner = $Spawner
@onready var boat = $boat
@onready var overlay = $Overlay
@onready var overlay_label = $Overlay/ColorRect2/Message
@onready var ui = $UI

@export var game_duration: float = 30.0
var level_timer: Timer
const FinishLineScene = preload("res://scenes/minigames/BoatGuiding/FinishLine.tscn") # Sesuaikan path-nya!

enum MinigameState {INTRO, PLAYING, GAMEOVER, WIN}
var current_state = MinigameState.INTRO

func _ready():
	add_to_group("game_manager")
	HUD.hide()
	ui.hide()
	
	var level_scale = GameState.prosperity - 1
	game_duration += level_scale * 5.0
	
	spawner.timer.stop()
	spawner.wave_timer.stop()
	spawner.set_process(false)
	boat.set_physics_process(false)
	
	boat.boat_destroyed.connect(_on_boat_destroyed)
	
	level_timer = Timer.new()
	level_timer.wait_time = game_duration
	level_timer.one_shot = true
	level_timer.timeout.connect(_on_level_timer_timeout)
	add_child(level_timer)
	
	show_message("Guide the Ship!\nClick anywhere to start")

func _input(event):
	if current_state == MinigameState.INTRO and event is InputEventMouseButton and event.pressed:
		start_game()

func show_message(text: String) -> void:
	overlay.show()
	overlay_label.text = text

func start_game():
	current_state = MinigameState.PLAYING
	overlay.hide()
	ui.show()
	boat.set_physics_process(true)
	spawner.timer.start()
	spawner.wave_timer.start()
	spawner.set_process(true)
	
	level_timer.start()

func _on_level_timer_timeout():
	spawner.timer.stop()
	spawner.wave_timer.stop()
	
	#for rock in get_tree().get_nodes_in_group("rocks"):
	#	rock.queue_free()
	#for wave in get_tree().get_nodes_in_group("waves"):
	#	wave.queue_free()
		
	var finish_line = FinishLineScene.instantiate()
	finish_line.position = Vector2(1650, 325)
	add_child(finish_line)

func win_game():
	if current_state != MinigameState.PLAYING: return
	current_state = MinigameState.WIN
	end_minigame(true) # Panggil fungsi baru

func _on_boat_destroyed():
	if current_state != MinigameState.PLAYING: return
	current_state = MinigameState.GAMEOVER
	end_minigame(false) # Panggil fungsi baru

func end_minigame(is_win: bool):
	ui.hide()
	boat.set_physics_process(false)
	spawner.timer.stop()
	spawner.wave_timer.stop()
	spawner.set_process(false)
	
	for rock in get_tree().get_nodes_in_group("rocks"): rock.queue_free()
	for wave in get_tree().get_nodes_in_group("waves"): wave.queue_free()
	
	var prev_level = GameState.prosperity
	var level_scale = GameState.prosperity - 1
	
	if is_win:
		show_message("The Ship Sailed Safely!!!")
		GameState.add_rewards(100 + level_scale * 50, 50 + level_scale * 25)
	else:
		show_message("Your Ship Sank!\nGame Over")
		GameState.add_rewards(50 + level_scale * 25, 10 + level_scale * 15)
		
	await get_tree().create_timer(2.0).timeout
	
	if GameState.prosperity > prev_level:
		get_tree().change_scene_to_file("res://scenes/core/scene_manager.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/core/map.tscn")
