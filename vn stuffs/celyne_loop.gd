extends Node

var intro: AudioStreamPlayer
var loop: AudioStreamPlayer

func _ready():
	intro = AudioStreamPlayer.new()
	intro.bus = "BGM"
	add_child(intro)
	
	loop = AudioStreamPlayer.new()
	loop.bus = "BGM"
	add_child(loop)

	intro.stream = preload("res://assets/audio/music/celyne.ogg")
	loop.stream = preload("res://assets/audio/music/celyne_loop.ogg")

	intro.finished.connect(_on_intro_finished)


func play_bgm():
	intro.play()


func _on_intro_finished():
	loop.play()



func stop_bgm():
	intro.stop()
	loop.stop()
