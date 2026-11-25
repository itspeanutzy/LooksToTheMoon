class_name IntroLoopMusicPlayer
extends Node

## A music player that handles intro + looping section playback integrated with AudioManager.
## If intro_music is provided, plays it once via AudioManager.play_music, then seamlessly transitions to loop_music.
## If only loop_music is provided, plays loop_music directly via AudioManager.play_music.

signal intro_started()
signal intro_finished()
signal loop_started()
signal playback_finished() ## Only emitted if loop is disabled and playback ends

enum Phase {
	STOPPED,
	INTRO,
	LOOP,
}

@export_group("Music Tracks")
@export var intro_music: StringName = &"" ## Optional intro music key (scanned by AudioManager, plays once)
@export var loop_music: StringName = &"" ## Main looping music key (scanned by AudioManager, required)

@export_group("Playback Settings")
@export var bus: StringName = &"Music" ## Audio bus to use
@export var volume_db: float = 0.0 ## Volume offset in decibels
@export var autoplay: bool = false ## Start playing automatically when ready
@export var enable_loop: bool = true ## If false, loop plays once and stops

@export_group("Crossfade Settings")
@export var intro_to_loop_crossfade: float = 0.0 ## Crossfade time from intro to loop (in seconds)
@export var fade_in_time: float = 0.0 ## Optional fade-in time for start (in seconds)

var _current_phase: Phase = Phase.STOPPED
var _transition_timer: Timer
var _intro_stream_fallback: AudioStream = null
var _loop_stream_fallback: AudioStream = null


func _ready() -> void:
	_setup_timer()
	Utils.safe_connect(AudioManager.music_finished, _on_audio_manager_music_finished)

	if autoplay:
		play()


func _exit_tree() -> void:
	Utils.safe_disconnect(AudioManager.music_finished, _on_audio_manager_music_finished)
	if is_instance_valid(_transition_timer):
		_transition_timer.stop()


func _setup_timer() -> void:
	_transition_timer = Timer.new()
	_transition_timer.name = "IntroTransitionTimer"
	_transition_timer.one_shot = true
	_transition_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	add_child(_transition_timer)
	Utils.safe_connect(_transition_timer.timeout, _on_intro_transition_timeout)


## Starts playback from the beginning.
func play(from_position: float = 0.0) -> void:
	stop()

	var loop_track: Variant = _get_loop_track()
	if loop_track == null or (loop_track is StringName and (loop_track as StringName).is_empty()):
		push_warning("[IntroLoopMusicPlayer] Cannot play: loop_music is not assigned.")
		return

	var intro_track: Variant = _get_intro_track()
	var has_intro: bool = intro_track != null and (not (intro_track is StringName) or not (intro_track as StringName).is_empty())

	if has_intro:
		_current_phase = Phase.INTRO
		AudioManager.play_music(intro_track, fade_in_time, false, volume_db, bus)
		if from_position > 0.0:
			var active: AudioStreamPlayer = AudioManager.get_active_music_player()
			if is_instance_valid(active):
				active.seek(from_position)
		intro_started.emit()
		_setup_intro_transition(from_position)
	else:
		_start_loop(from_position, fade_in_time)


## Stops all playback immediately.
func stop() -> void:
	if is_instance_valid(_transition_timer):
		_transition_timer.stop()

	if _current_phase != Phase.STOPPED:
		_current_phase = Phase.STOPPED
		if _is_our_music_playing():
			AudioManager.stop_music(false, 0.0)


## Pauses playback at the current position.
func pause() -> void:
	if is_instance_valid(_transition_timer) and not _transition_timer.is_stopped():
		_transition_timer.paused = true
	if _is_our_music_playing():
		var active: AudioStreamPlayer = AudioManager.get_active_music_player()
		if is_instance_valid(active):
			active.stream_paused = true


## Resumes paused playback.
func resume() -> void:
	if is_instance_valid(_transition_timer) and _transition_timer.paused:
		_transition_timer.paused = false
	if _is_our_music_playing():
		var active: AudioStreamPlayer = AudioManager.get_active_music_player()
		if is_instance_valid(active):
			active.stream_paused = false


## Returns true if currently playing (intro or loop).
func is_playing() -> bool:
	return _current_phase != Phase.STOPPED and _is_our_music_playing()


## Returns the current playback phase.
func get_phase() -> Phase:
	if not _is_our_music_playing() and _current_phase != Phase.STOPPED:
		_current_phase = Phase.STOPPED
	return _current_phase


## Sets the volume in decibels.
func set_volume_db_value(new_volume_db: float) -> void:
	volume_db = new_volume_db
	if _is_our_music_playing():
		var active: AudioStreamPlayer = AudioManager.get_active_music_player()
		if is_instance_valid(active):
			active.volume_db = new_volume_db


## Sets the audio bus.
func set_bus_name(new_bus: StringName) -> void:
	bus = new_bus
	if _is_our_music_playing():
		var active: AudioStreamPlayer = AudioManager.get_active_music_player()
		if is_instance_valid(active):
			active.bus = new_bus


## Fades the music volume over fade_time seconds, then stops playback.
func fade_out_and_stop(fade_time: float = 1.0) -> void:
	if _current_phase == Phase.STOPPED:
		return

	if is_instance_valid(_transition_timer):
		_transition_timer.stop()

	_current_phase = Phase.STOPPED
	if _is_our_music_playing():
		AudioManager.stop_music(false, fade_time)


## Fades in from current volume to target volume over fade_time seconds.
func fade_in(target_volume_db: float = 0.0, fade_time: float = 1.0) -> void:
	volume_db = target_volume_db
	if _is_our_music_playing():
		var active: AudioStreamPlayer = AudioManager.get_active_music_player()
		if is_instance_valid(active):
			var tw: Tween = create_tween()
			tw.tween_property(active, "volume_db", target_volume_db, fade_time)


## Returns the active music player from AudioManager.
func get_active_player() -> AudioStreamPlayer:
	return AudioManager.get_active_music_player()


func _get_active_player() -> AudioStreamPlayer:
	return AudioManager.get_active_music_player()


## Current playback position in seconds.
func get_playback_position() -> float:
	var active: AudioStreamPlayer = AudioManager.get_active_music_player()
	return active.get_playback_position() if is_instance_valid(active) and active.playing else 0.0


func _setup_intro_transition(from_position: float) -> void:
	var intro_stream: AudioStream = AudioManager.resolve_stream(_get_intro_track())
	var length: float = intro_stream.get_length() if intro_stream != null else 0.0

	if length > 0.0:
		var time_until_loop: float = (length - intro_to_loop_crossfade) - from_position
		if time_until_loop <= 0.0:
			_trigger_intro_transition()
		else:
			_transition_timer.start(time_until_loop)


func _on_intro_transition_timeout() -> void:
	if _current_phase != Phase.INTRO:
		return
	_trigger_intro_transition()


func _trigger_intro_transition() -> void:
	if is_instance_valid(_transition_timer):
		_transition_timer.stop()
	intro_finished.emit()
	_start_loop(0.0, intro_to_loop_crossfade)


func _start_loop(from_position: float = 0.0, crossfade_time: float = 0.0) -> void:
	_current_phase = Phase.LOOP
	var loop_track: Variant = _get_loop_track()
	AudioManager.play_music(loop_track, crossfade_time, enable_loop, volume_db, bus)
	if from_position > 0.0:
		var active: AudioStreamPlayer = AudioManager.get_active_music_player()
		if is_instance_valid(active):
			active.seek(from_position)
	loop_started.emit()


func _on_audio_manager_music_finished(finished_key: Variant) -> void:
	if _current_phase == Phase.INTRO:
		if _matches_track(finished_key, _get_intro_track()):
			_trigger_intro_transition()
	elif _current_phase == Phase.LOOP:
		if _matches_track(finished_key, _get_loop_track()):
			_current_phase = Phase.STOPPED
			playback_finished.emit()


func _matches_track(key_a: Variant, key_b: Variant) -> bool:
	if key_a == null or key_b == null:
		return false
	if key_a == key_b:
		return true
	if (key_a is StringName or key_a is String) and (key_b is StringName or key_b is String):
		return StringName(key_a) == StringName(key_b)
	return false


func _is_our_music_playing() -> bool:
	var current: Variant = AudioManager.get_current_track()
	if current == null:
		return false
	return _matches_track(current, _get_intro_track()) or _matches_track(current, _get_loop_track())


func _get_intro_track() -> Variant:
	if not intro_music.is_empty():
		return intro_music
	return _intro_stream_fallback


func _get_loop_track() -> Variant:
	if not loop_music.is_empty():
		return loop_music
	return _loop_stream_fallback


func _set(property: StringName, value: Variant) -> bool:
	if property == &"intro_stream" or property == &"intro_track":
		if value is AudioStream:
			_intro_stream_fallback = value
		elif value is StringName:
			intro_music = value
		elif value is String:
			intro_music = StringName(value)
		return true
	elif property == &"loop_stream" or property == &"loop_track":
		if value is AudioStream:
			_loop_stream_fallback = value
		elif value is StringName:
			loop_music = value
		elif value is String:
			loop_music = StringName(value)
		return true
	return false


func _get(property: StringName) -> Variant:
	if property == &"intro_stream" or property == &"intro_track":
		return intro_music if not intro_music.is_empty() else _intro_stream_fallback
	elif property == &"loop_stream" or property == &"loop_track":
		return loop_music if not loop_music.is_empty() else _loop_stream_fallback
	return null
