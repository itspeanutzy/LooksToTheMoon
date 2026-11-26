extends Node

var intro: AudioStreamPlayer
var loop: AudioStreamPlayer

func _ready():
	intro = AudioStreamPlayer.new()
	loop = AudioStreamPlayer.new()

	add_child(intro)
	add_child(loop)

	intro.stream = preload("res://assets/audio/music/celyne_intro.ogg")
	loop.stream = preload("res://assets/audio/music/celyne_loop.ogg")

	intro.finished.connect(_on_intro_finished)
	loop.finished.connect(_on_loop_finished)


func play_bgm():
	loop.stop()
	intro.stop()
	intro.play()


func _on_intro_finished():
	loop.play()


func _on_loop_finished():
	loop.play()


func stop_bgm():
	intro.stop()
	loop.stop()
