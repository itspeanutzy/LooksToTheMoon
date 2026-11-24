# res://_tools/audio_manager/audio_manager.gd
extends Node

## Standalone AudioManager Autoload
## Automatically scans res://asset/audio/sfx/ and res://asset/audio/music/ recursively at startup.
## Handles global & 2D pooled SFX, handle-based looping SFX, music A/B crossfading, bus volume controls,
## beat timing clock, and specialized effect delegation.

signal beat(beat_index: int)
signal bar(bar_index: int)
signal music_finished(stream_or_key: Variant)

# ---------------------------------------------------------------------------
# Internal Sound Event Data Structure
# ---------------------------------------------------------------------------

class SoundData:
	var name: StringName = &""
	var stream: AudioStream = null
	var volume_db: float = 0.0
	var pitch_scale: float = 1.0
	var pitch_variance: float = 0.0
	var bus_override: StringName = &""

# ---------------------------------------------------------------------------
# Constants & Bus Names
# ---------------------------------------------------------------------------

const SFX_BUS: StringName = &"SFX"
const SFX_LOOP_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"

# ---------------------------------------------------------------------------
# Exported Config Fields
# ---------------------------------------------------------------------------

@export_group("Folder Scan Paths")
@export var sfx_folder_path: String = "res://asset/audio/sfx/"
@export var music_folder_path: String = "res://asset/audio/music/"

@export_group("Pool Configuration")
@export var sfx_pool_size: int = 16

@export_group("Beat Clock Settings")
@export var bpm: float = 120.0
@export var beats_per_bar: int = 4

# ---------------------------------------------------------------------------
# Private Runtime State
# ---------------------------------------------------------------------------

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_2d_pool: Array[AudioStreamPlayer2D] = []
var _sfx_loops: Dictionary = {} # handle: String -> { "player": AudioStreamPlayer, "tween": Tween, "source_stream": AudioStream, "target_db": float, "stopping": bool }
var _periodic_sfx: Dictionary = {} # handle: String -> { "timer": Timer, "stream_or_key": Variant, "source": Node, ... }

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music_slot: int = 0
var _crossfade_tween: Tween
var current_music_key: Variant = null

var _sfx_lookup: Dictionary = {}
var _music_lookup: Dictionary = {}

var _beat_index: int = -1
var _bar_index: int = -1

var _last_playback_position: float = 0.0
var _loop_offset: float = 0.0

var _pending_music: Dictionary = {}
var _pending_stop: Dictionary = {}

var _layers: Dictionary = {}
var _layer_tweens: Dictionary = {}

var specialized_effects: SpecializedAudioEffects
var _current_scene_ref: Node = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Automatically scan filesystem audio directories
	rescan_audio_folders()

	# Create SFX pool nodes
	_create_sfx_pools()

	# Create Music A/B players for crossfading
	_music_a = _create_music_player("MusicA")
	_music_b = _create_music_player("MusicB")

	# Initialize specialized audio effects child component
	specialized_effects = SpecializedAudioEffects.new()
	specialized_effects.name = "SpecializedEffects"
	add_child(specialized_effects)


func _create_sfx_pools() -> void:
	for i in sfx_pool_size:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer_%d" % i
		player.bus = SFX_BUS
		add_child(player)
		_sfx_pool.append(player)

		var player_2d := AudioStreamPlayer2D.new()
		player_2d.name = "SfxPlayer2D_%d" % i
		player_2d.bus = SFX_BUS
		add_child(player_2d)
		_sfx_2d_pool.append(player_2d)


## Removes and frees all SFX pool players (1D and 2D), stops all loops and periodic sounds,
## and recreates fresh clean pools. Called automatically on scene change.
func remove_all_sfx_pools() -> void:
	for player in _sfx_pool:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_sfx_pool.clear()

	for player_2d in _sfx_2d_pool:
		if is_instance_valid(player_2d):
			player_2d.stop()
			player_2d.queue_free()
	_sfx_2d_pool.clear()

	stop_all_sfx_loops(0.0)
	stop_all_periodic_sfx()

	if is_instance_valid(specialized_effects):
		specialized_effects.stop_player_wind()

	_create_sfx_pools()


## Rescans sfx_folder_path and music_folder_path recursively to rebuild sound lookups.
func rescan_audio_folders() -> void:
	_sfx_lookup.clear()
	_music_lookup.clear()
	_scan_folder_recursive(sfx_folder_path, _sfx_lookup)
	_scan_folder_recursive(music_folder_path, _music_lookup)


func _create_music_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = MUSIC_BUS
	player.volume_db = -80.0
	player.finished.connect(_on_music_player_finished.bind(player))
	add_child(player)
	return player


func _on_music_player_finished(player: AudioStreamPlayer) -> void:
	if player == _get_active_music_player():
		var key: Variant = current_music_key
		current_music_key = null
		_reset_music_clock()
		music_finished.emit(key)

# ---------------------------------------------------------------------------
# Directory Scanning Algorithm
# ---------------------------------------------------------------------------

func _scan_folder_recursive(folder_path: String, lookup: Dictionary) -> void:
	if folder_path.is_empty() or not DirAccess.dir_exists_absolute(folder_path):
		return

	var dir := DirAccess.open(folder_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_folder_recursive(folder_path.path_join(file_name), lookup)
		else:
			var clean_name := file_name.trim_suffix(".remap").trim_suffix(".import")
			
			if clean_name.begins_with("."):
				file_name = dir.get_next()
				continue

			var full_path := folder_path.path_join(clean_name)
			var ext := clean_name.get_extension().to_lower()

			if ext in ["ogg", "wav", "mp3"]:
				if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
					var stream := load(full_path) as AudioStream
					if stream != null:
						var raw_name := clean_name.get_basename()
						var sound := SoundData.new()
						sound.name = StringName(raw_name)
						sound.stream = stream
						_register_sound_aliases(lookup, raw_name, sound)

		file_name = dir.get_next()


func _register_sound_aliases(lookup: Dictionary, raw_name: String, sound: SoundData) -> void:
	var name_str := String(raw_name)
	var upper_underscore := StringName(name_str.to_upper().replace(" ", "_"))
	var upper_space := StringName(name_str.to_upper())
	var raw_sn := StringName(name_str)
	var lower_sn := StringName(name_str.to_lower())

	if not lookup.has(upper_underscore): lookup[upper_underscore] = sound
	if not lookup.has(upper_space): lookup[upper_space] = sound
	if not lookup.has(raw_sn): lookup[raw_sn] = sound
	if not lookup.has(lower_sn): lookup[lower_sn] = sound

	var trimmed := name_str.trim_suffix(".")
	while trimmed.ends_with("."):
		trimmed = trimmed.trim_suffix(".")
	if trimmed != name_str and not trimmed.is_empty():
		var trimmed_upper := StringName(trimmed.to_upper().replace(" ", "_"))
		var trimmed_lower := StringName(trimmed.to_lower())
		if not lookup.has(trimmed_upper): lookup[trimmed_upper] = sound
		if not lookup.has(trimmed_lower): lookup[trimmed_lower] = sound

# ---------------------------------------------------------------------------
# Library Inspection Helpers
# ---------------------------------------------------------------------------

## Returns whether a key is registered in the SFX library.
func has_sfx(key: Variant) -> bool:
	if key is StringName or key is String:
		return _sfx_lookup.has(StringName(key))
	return false


## Returns whether a key is registered in the Music library.
func has_music(key: Variant) -> bool:
	if key is StringName or key is String:
		return _music_lookup.has(StringName(key))
	return false

# ---------------------------------------------------------------------------
# Beat Clock Processing
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	_check_scene_change()

	var active_player := _get_active_music_player()
	if (active_player == null or not active_player.playing) and not _layers.is_empty():
		active_player = _layers.values()[0] as AudioStreamPlayer

	if active_player == null or not active_player.playing or bpm <= 0.0:
		return

	var beat_duration := 60.0 / bpm
	var position := active_player.get_playback_position()
	
	if position < _last_playback_position:
		_loop_offset += _last_playback_position
	_last_playback_position = position
	
	var total_time := position + _loop_offset
	var current_beat := int(total_time / beat_duration)

	if current_beat <= _beat_index:
		return

	for new_beat in range(_beat_index + 1, current_beat + 1):
		_beat_index = new_beat
		beat.emit(_beat_index)
		if _beat_index % beats_per_bar == 0:
			_bar_index = _beat_index / beats_per_bar
			bar.emit(_bar_index)
			_on_bar_boundary()


func _check_scene_change() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var active_scene := tree.current_scene
	if active_scene == null or not is_instance_valid(active_scene):
		return
	if _current_scene_ref == null:
		_current_scene_ref = active_scene
		return
	if active_scene != _current_scene_ref:
		_current_scene_ref = active_scene
		remove_all_sfx_pools()


func _on_bar_boundary() -> void:
	if not _pending_music.is_empty():
		_execute_music_transition()
	elif not _pending_stop.is_empty():
		_execute_music_stop()

# ---------------------------------------------------------------------------
# Resource Resolution & File Verification
# ---------------------------------------------------------------------------

## Resolves a key (String/StringName), an Array of keys/streams (randomly picked), URI path (res://, uid://), or AudioStream into a validated SoundData object.
func resolve_sound_event(stream_or_key: Variant, library_dict: Dictionary = _sfx_lookup) -> SoundData:
	if stream_or_key == null:
		push_warning("AudioManager: Attempted to resolve a null audio key/stream.")
		return null

	# Array support: randomly pick one sound from the array using Utils.array_get_random
	if stream_or_key is Array:
		var arr := stream_or_key as Array
		if arr.is_empty():
			push_warning("AudioManager: Attempted to resolve an empty audio array.")
			return null
		var picked: Variant = Utils.array_get_random(arr)
		return resolve_sound_event(picked, library_dict)

	if stream_or_key is SoundData:
		var sound_data := stream_or_key as SoundData
		if sound_data.stream != null and _verify_stream_file_exists(sound_data.stream):
			return sound_data
		return null

	if stream_or_key is StringName or stream_or_key is String:
		var str_val := String(stream_or_key).strip_edges()
		if str_val.is_empty():
			push_warning("AudioManager: Attempted to play an empty sound key.")
			return null

		# Direct URI path or UID URI support (e.g. "uid://..." or "res://...")
		if str_val.begins_with("uid://") or str_val.begins_with("res://"):
			if not (ResourceLoader.exists(str_val) or FileAccess.file_exists(str_val)):
				push_warning("AudioManager: Audio file at URI '%s' does not exist on disk." % str_val)
				return null
			var loaded_res = load(str_val)
			if loaded_res is AudioStream:
				var sound := SoundData.new()
				sound.stream = loaded_res as AudioStream
				return sound
			else:
				push_warning("AudioManager: Resource at '%s' is not a valid AudioStream." % str_val)
				return null

		# Key lookup in scanned library
		var key := StringName(stream_or_key)
		if library_dict.has(key):
			var sound: SoundData = library_dict[key]
			if sound == null or sound.stream == null:
				push_warning("AudioManager: SoundData for key '%s' has a null stream." % key)
				return null
			if _verify_stream_file_exists(sound.stream):
				return sound
			return null

		# Fallback check across music/sfx libraries if passed to the wrong function
		if library_dict == _sfx_lookup and _music_lookup.has(key):
			var music_sound: SoundData = _music_lookup[key]
			if music_sound != null and music_sound.stream != null and _verify_stream_file_exists(music_sound.stream):
				return music_sound
		elif library_dict == _music_lookup and _sfx_lookup.has(key):
			var sfx_sound: SoundData = _sfx_lookup[key]
			if sfx_sound != null and sfx_sound.stream != null and _verify_stream_file_exists(sfx_sound.stream):
				return sfx_sound

		push_warning("AudioManager: Audio key/file '%s' not found in scanned folder libraries." % str_val)
		return null

	if stream_or_key is AudioStream:
		var stream := stream_or_key as AudioStream
		if _verify_stream_file_exists(stream):
			var sound := SoundData.new()
			sound.stream = stream
			return sound
		return null

	push_warning("AudioManager: Invalid audio key/stream argument type: %s" % type_string(typeof(stream_or_key)))
	return null


func _verify_stream_file_exists(stream: AudioStream) -> bool:
	if stream == null:
		return false
	var path := stream.resource_path
	if path.is_empty():
		return true
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		return true
	push_warning("AudioManager: Audio stream resource file '%s' does not exist on disk." % path)
	return false


func resolve_stream(stream_or_key: Variant) -> AudioStream:
	var sound := resolve_sound_event(stream_or_key)
	return sound.stream if sound != null else null


## Helper to resolve a single key or randomly pick from an Array of keys/streams.
func resolve_sfx_key(key: Variant) -> Variant:
	if key is Array:
		var arr := key as Array
		return Utils.array_get_random(arr) if not arr.is_empty() else null
	return key

# ---------------------------------------------------------------------------
# SFX One-Shot API
# ---------------------------------------------------------------------------

## Plays a non-positional global one-shot sound effect.
func play_sfx(stream_or_key: Variant, volume_db_offset: float = 0.0, pitch_scale_offset: float = 1.0) -> void:
	var sound := resolve_sound_event(stream_or_key, _sfx_lookup)
	if sound == null or sound.stream == null:
		return

	var player := _get_free_sfx_player()
	_apply_sound_to_player(player, sound, volume_db_offset, pitch_scale_offset, SFX_BUS)
	player.play()


## Plays a 2D positional one-shot sound effect at global_position.
func play_sfx_at(
	stream_or_key: Variant,
	global_pos: Vector2,
	volume_db_offset: float = 0.0,
	pitch_scale_offset: float = 1.0,
	max_distance: float = 400.0,
	attenuation: float = 1.0,
) -> void:
	var sound := resolve_sound_event(stream_or_key, _sfx_lookup)
	if sound == null or sound.stream == null:
		return
	var player := _get_free_sfx_2d_player()
	player.global_position = global_pos
	player.max_distance = max_distance
	player.attenuation = attenuation
	_apply_sound_to_player(player, sound, volume_db_offset, pitch_scale_offset, SFX_BUS)
	player.play()


func _apply_sound_to_player(player: Node, sound: SoundData, volume_offset: float, pitch_offset: float, default_bus: StringName) -> void:
	player.set("stream", sound.stream)
	var bus_name := sound.bus_override if not sound.bus_override.is_empty() else default_bus
	player.set("bus", bus_name)
	player.set("volume_db", sound.volume_db + volume_offset)

	var final_pitch := sound.pitch_scale * pitch_offset
	if sound.pitch_variance > 0.0:
		final_pitch += randf_range(-sound.pitch_variance, sound.pitch_variance)
	player.set("pitch_scale", maxf(0.01, final_pitch))


func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	return _sfx_pool[0]


func _get_free_sfx_2d_player() -> AudioStreamPlayer2D:
	for player in _sfx_2d_pool:
		if not player.playing:
			return player
	return _sfx_2d_pool[0]

# ---------------------------------------------------------------------------
# SFX Loop API (Uses the SAME Unified SFX Library!)
# ---------------------------------------------------------------------------

## Starts or updates a looping sound under a string handle.
## Contains guards for repeated calls (e.g. from _physics_process) to prevent
## stuttering, stream recreation, or broken fade tweens when called every frame.
func play_sfx_loop(handle: String, stream_or_key: Variant, fade_time: float = 0.3, volume_db_offset: float = 0.0, pitch_scale_offset: float = 1.0) -> void:
	var sound := resolve_sound_event(stream_or_key, _sfx_lookup)
	if sound == null or sound.stream == null:
		return

	var target_pitch: float = sound.pitch_scale * pitch_scale_offset
	var target_db: float = sound.volume_db + volume_db_offset
	var target_bus: StringName = sound.bus_override if not sound.bus_override.is_empty() else SFX_LOOP_BUS

	if _sfx_loops.has(handle):
		var entry: Dictionary = _sfx_loops[handle]
		var existing_player: AudioStreamPlayer = entry.get("player", null)
		var is_stopping: bool = entry.get("stopping", false)
		var source_stream: AudioStream = entry.get("source_stream", null)

		if is_instance_valid(existing_player):
			# Guard: if this exact sound is already looping under this handle and not stopping,
			# do not restart or recreate streams. Smoothly update pitch or volume target if they changed.
			if source_stream == sound.stream and not is_stopping and existing_player.playing:
				if not is_equal_approx(existing_player.pitch_scale, target_pitch):
					existing_player.pitch_scale = target_pitch
				if existing_player.bus != target_bus:
					existing_player.bus = target_bus

				var current_target_db: float = entry.get("target_db", target_db)
				if not is_equal_approx(current_target_db, target_db):
					entry["target_db"] = target_db
					var existing_tween: Tween = entry.get("tween", null)
					if existing_tween and existing_tween.is_valid():
						existing_tween.kill()
					if fade_time > 0.0:
						var tw := existing_player.create_tween()
						tw.tween_property(existing_player, "volume_db", target_db, fade_time)
						entry["tween"] = tw
					else:
						existing_player.volume_db = target_db
						entry["tween"] = null
				return

			# If this handle was in the middle of fading out to stop, cancel the stop and resume/fade back in.
			if source_stream == sound.stream and is_stopping:
				entry["stopping"] = false
				var existing_tween: Tween = entry.get("tween", null)
				if existing_tween and existing_tween.is_valid():
					existing_tween.kill()

				existing_player.bus = target_bus
				existing_player.pitch_scale = target_pitch
				entry["target_db"] = target_db

				if fade_time > 0.0:
					var tw := existing_player.create_tween()
					tw.tween_property(existing_player, "volume_db", target_db, fade_time)
					entry["tween"] = tw
				else:
					existing_player.volume_db = target_db
					entry["tween"] = null

				if not existing_player.playing:
					existing_player.play()
				return

	# If handle already had a tween running, cancel it
	if _sfx_loops.has(handle):
		var old_entry: Dictionary = _sfx_loops[handle]
		var old_tween: Tween = old_entry.get("tween", null)
		if old_tween and old_tween.is_valid():
			old_tween.kill()

	var entry: Dictionary = _sfx_loops.get(handle, {})
	var player: AudioStreamPlayer = entry.get("player", null)

	if player == null or not is_instance_valid(player):
		player = AudioStreamPlayer.new()
		player.name = "SfxLoop_%s" % handle
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(player)

	var stream_copy := _duplicate_looping_stream(sound.stream)
	player.stream = stream_copy
	player.bus = target_bus
	player.pitch_scale = target_pitch

	if fade_time > 0.0:
		if not player.playing:
			player.volume_db = -80.0
			player.play()
		var tw := player.create_tween()
		tw.tween_property(player, "volume_db", target_db, fade_time)
		_sfx_loops[handle] = {
			"player": player,
			"tween": tw,
			"source_stream": sound.stream,
			"target_db": target_db,
			"stopping": false,
		}
	else:
		player.volume_db = target_db
		if not player.playing:
			player.play()
		_sfx_loops[handle] = {
			"player": player,
			"tween": null,
			"source_stream": sound.stream,
			"target_db": target_db,
			"stopping": false,
		}


## Stops a looping sound by handle over fade_time.
func stop_sfx_loop(handle: String, fade_time: float = 0.3) -> void:
	if not _sfx_loops.has(handle):
		return

	var entry: Dictionary = _sfx_loops[handle]
	var player: AudioStreamPlayer = entry.get("player", null)
	var tween: Tween = entry.get("tween", null)

	if player == null or not is_instance_valid(player):
		_sfx_loops.erase(handle)
		return

	# Guard: If already stopping/fading out, ignore redundant stop calls from _physics_process
	if entry.get("stopping", false):
		return

	if tween and tween.is_valid():
		tween.kill()

	if fade_time > 0.0 and player.playing:
		entry["stopping"] = true
		var tw := player.create_tween()
		tw.tween_property(player, "volume_db", -80.0, fade_time)
		tw.tween_callback(func():
			if is_instance_valid(player):
				player.stop()
				player.queue_free()
			if _sfx_loops.get(handle, {}).get("player") == player:
				_sfx_loops.erase(handle)
		)
		entry["tween"] = tw
	else:
		player.stop()
		player.queue_free()
		_sfx_loops.erase(handle)


## Stops all active looping sounds.
func stop_all_sfx_loops(fade_time: float = 0.3) -> void:
	var keys := _sfx_loops.keys()
	for key in keys:
		stop_sfx_loop(key, fade_time)


## Returns whether a loop handle is active.
func is_sfx_looping(handle: String) -> bool:
	if not _sfx_loops.has(handle):
		return false
	var entry: Dictionary = _sfx_loops[handle]
	if entry.get("stopping", false):
		return false
	var player: AudioStreamPlayer = entry.get("player", null)
	return player != null and is_instance_valid(player) and player.playing

# ---------------------------------------------------------------------------
# Periodic SFX API (Random Interval Loops, Pausable, Auto-Cleaned)
# ---------------------------------------------------------------------------

## Handle object returned by play_periodic_sfx, allowing direct signal connection and control.
class PeriodicSFX extends RefCounted:
	signal played()
	signal played_sound(sound_key: Variant)

	var handle: String = ""
	var _audio_manager: Node = null

	func stop() -> void:
		if is_instance_valid(_audio_manager) and _audio_manager.has_method("stop_periodic_sfx"):
			_audio_manager.stop_periodic_sfx(handle)

	func is_active() -> bool:
		if is_instance_valid(_audio_manager) and _audio_manager.has_method("is_periodic_sfx_active"):
			return _audio_manager.is_periodic_sfx_active(handle)
		return false


## Starts or updates a periodic sound effect under a string handle that repeats
## at random intervals between min_interval and max_interval seconds.
## Returns a PeriodicSFX object whose `played` signal can be connected to directly.
## You can also pass an optional `on_play: Callable` callback directly.
func play_periodic_sfx(
	handle: String,
	stream_or_key: Variant,
	min_interval: float = 3.0,
	max_interval: float = 5.0,
	source: Node = null,
	volume_db_offset: float = 0.0,
	pitch_scale_offset: float = 1.0,
	play_immediately: bool = false,
	on_play: Callable = Callable()
) -> PeriodicSFX:
	if handle.is_empty():
		push_warning("AudioManager: Cannot play periodic SFX with an empty handle.")
		return null

	# Guard: If this handle is already running, update parameters in-place without resetting timer
	if _periodic_sfx.has(handle):
		var existing: Dictionary = _periodic_sfx[handle]
		var existing_timer: Timer = existing.get("timer", null)
		if is_instance_valid(existing_timer) and not existing_timer.is_stopped():
			existing["stream_or_key"] = stream_or_key
			existing["min_interval"] = min_interval
			existing["max_interval"] = max_interval
			existing["source"] = source
			existing["volume_db_offset"] = volume_db_offset
			existing["pitch_scale_offset"] = pitch_scale_offset
			if on_play.is_valid():
				existing["on_play"] = on_play
			return existing.get("handle_obj", null) as PeriodicSFX

	stop_periodic_sfx(handle)

	var timer := Timer.new()
	timer.name = "PeriodicSfxTimer_%s" % handle
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	timer.process_callback = Timer.TIMER_PROCESS_IDLE
	add_child(timer)

	var handle_obj := PeriodicSFX.new()
	handle_obj.handle = handle
	handle_obj._audio_manager = self

	var entry: Dictionary = {
		"timer": timer,
		"stream_or_key": stream_or_key,
		"min_interval": min_interval,
		"max_interval": max_interval,
		"source": source,
		"volume_db_offset": volume_db_offset,
		"pitch_scale_offset": pitch_scale_offset,
		"handle_obj": handle_obj,
		"on_play": on_play,
	}
	_periodic_sfx[handle] = entry

	# Auto-clean if source node exits the tree
	if is_instance_valid(source):
		source.tree_exiting.connect(func():
			stop_periodic_sfx(handle)
		, CONNECT_ONE_SHOT)

	timer.timeout.connect(_on_periodic_sfx_timeout.bind(handle))

	if play_immediately:
		_trigger_periodic_sfx(handle)
	else:
		_schedule_next_periodic_sfx(handle)

	return handle_obj


## Stops and frees a periodic sound effect by handle.
func stop_periodic_sfx(handle: String) -> void:
	if not _periodic_sfx.has(handle):
		return
	var entry: Dictionary = _periodic_sfx[handle]
	var timer: Timer = entry.get("timer", null)
	if is_instance_valid(timer):
		timer.stop()
		timer.queue_free()

	var handle_obj: PeriodicSFX = entry.get("handle_obj", null)
	if is_instance_valid(handle_obj):
		Utils.disconnect_all(handle_obj.played)
		Utils.disconnect_all(handle_obj.played_sound)

	entry.clear()
	_periodic_sfx.erase(handle)


## Stops all active periodic sound effects.
func stop_all_periodic_sfx() -> void:
	var keys := _periodic_sfx.keys()
	for key in keys:
		stop_periodic_sfx(key)


## Returns whether a periodic sound effect is currently active under this handle.
func is_periodic_sfx_active(handle: String) -> bool:
	if not _periodic_sfx.has(handle):
		return false
	var timer: Timer = _periodic_sfx[handle].get("timer", null)
	return is_instance_valid(timer) and not timer.is_stopped()


func _schedule_next_periodic_sfx(handle: String) -> void:
	if not _periodic_sfx.has(handle):
		return
	var entry: Dictionary = _periodic_sfx[handle]
	var timer: Timer = entry.get("timer", null)
	if not is_instance_valid(timer):
		_periodic_sfx.erase(handle)
		return

	var min_time: float = entry.get("min_interval", 3.0)
	var max_time: float = maxf(min_time, entry.get("max_interval", 5.0))
	var next_delay: float = randf_range(min_time, max_time)
	timer.start(next_delay)


func _on_periodic_sfx_timeout(handle: String) -> void:
	if not _periodic_sfx.has(handle):
		return

	_trigger_periodic_sfx(handle)
	_schedule_next_periodic_sfx(handle)


func _trigger_periodic_sfx(handle: String) -> void:
	if not _periodic_sfx.has(handle):
		return
	var entry: Dictionary = _periodic_sfx[handle]
	var source: Node = entry.get("source", null)
	var stream_or_key: Variant = entry.get("stream_or_key", null)
	var volume_offset: float = entry.get("volume_db_offset", 0.0)
	var pitch_offset: float = entry.get("pitch_scale_offset", 1.0)

	# If source was provided, validate its lifecycle and state
	if source != null:
		if not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_inside_tree():
			stop_periodic_sfx(handle)
			return

		# Check if source is dead
		if bool(source.get("_is_dead")):
			stop_periodic_sfx(handle)
			return

		# Check if source is stunned or culled offscreen (skip this tick, will retry next interval)
		if bool(source.get("is_stunned")):
			return
		if bool(source.get("enable_screen_culling")) and not bool(source.get("_is_in_screen")):
			return

		# Play spatial 2D SFX at source position
		if source is Node2D:
			play_sfx_at(stream_or_key, (source as Node2D).global_position, volume_offset, pitch_offset)
			_notify_periodic_played(entry, stream_or_key)
			return

	# Fallback to global SFX
	play_sfx(stream_or_key, volume_offset, pitch_offset)
	_notify_periodic_played(entry, stream_or_key)


func _notify_periodic_played(entry: Dictionary, sound_key: Variant) -> void:
	var callback: Callable = entry.get("on_play", Callable())
	if callback.is_valid():
		callback.call()

	var handle_obj: PeriodicSFX = entry.get("handle_obj", null)
	if is_instance_valid(handle_obj):
		handle_obj.played.emit()
		handle_obj.played_sound.emit(sound_key)

# ---------------------------------------------------------------------------
# Music API (Crossfading & Beat-Synced Switching)
# ---------------------------------------------------------------------------

## Plays background music with crossfading.
func play_music(
	stream_or_key: Variant,
	fade_time: float = 1.0,
	loop: bool = true,
	volume_db_offset: float = 0.0,
	bus_override: StringName = &""
) -> void:
	_cancel_crossfade()
	_pending_music.clear()
	_pending_stop.clear()

	var sound := resolve_sound_event(stream_or_key, _music_lookup)
	if sound == null or sound.stream == null:
		return

	current_music_key = stream_or_key

	var outgoing := _get_active_music_player()
	var incoming := _get_inactive_music_player()

	if loop:
		incoming.stream = _duplicate_looping_stream(sound.stream)
	else:
		incoming.stream = _duplicate_non_looping_stream(sound.stream)

	var target_bus: StringName = MUSIC_BUS
	if not bus_override.is_empty():
		target_bus = bus_override
	elif not sound.bus_override.is_empty():
		target_bus = sound.bus_override
	incoming.bus = target_bus

	var target_db: float = sound.volume_db + volume_db_offset

	if fade_time > 0.0 and outgoing.playing:
		incoming.volume_db = -80.0
		incoming.play()

		_crossfade_tween = create_tween()
		_crossfade_tween.set_parallel(true)
		_crossfade_tween.tween_property(outgoing, "volume_db", -80.0, fade_time)
		_crossfade_tween.tween_property(incoming, "volume_db", target_db, fade_time)
		_crossfade_tween.chain().tween_callback(func():
			_stop_player(outgoing)
			_active_music_slot = 1 - _active_music_slot
			_reset_music_clock()
		)
	else:
		_stop_player(outgoing)
		incoming.volume_db = target_db
		incoming.play()
		_active_music_slot = 1 - _active_music_slot
		_reset_music_clock()


## Queues music to transition on the next bar boundary.
func queue_music(stream_or_key: Variant, new_bpm: float = 120.0, new_beats_per_bar: int = 4, crossfade_sec: float = 1.0) -> void:
	var active_player := _get_active_music_player()
	if active_player == null or not active_player.playing:
		bpm = new_bpm
		beats_per_bar = maxi(new_beats_per_bar, 1)
		play_music(stream_or_key, crossfade_sec)
		return

	_pending_music = {
		"stream_or_key": stream_or_key,
		"bpm": new_bpm,
		"beats_per_bar": maxi(new_beats_per_bar, 1),
		"crossfade_sec": crossfade_sec,
	}
	_pending_stop.clear()


## Stops music (optionally aligned to the next bar boundary).
func stop_music(on_bar: bool = true, fade_sec: float = 1.0) -> void:
	_pending_music.clear()
	if on_bar:
		_pending_stop = {"fade_sec": fade_sec}
	else:
		_pending_stop.clear()
		_fade_out_active_music(fade_sec)


## Returns the currently playing music key or stream, or null if no music is active.
func get_current_track() -> Variant:
	var player := _get_active_music_player()
	if player and player.playing:
		return current_music_key
	return null

# ---------------------------------------------------------------------------
# Layered / Adaptive Music Support
# ---------------------------------------------------------------------------

func start_layers(stems: Dictionary, initial_volumes: Dictionary = {}, loop := true) -> void:
	stop_layers()
	for layer_name in stems:
		var stream: AudioStream = stems[layer_name]
		var copy := _duplicate_looping_stream(stream)
		var player := AudioStreamPlayer.new()
		player.name = "Layer_%s" % layer_name
		player.bus = MUSIC_BUS
		player.stream = copy
		player.volume_db = initial_volumes.get(layer_name, -80.0)
		add_child(player)
		_layers[layer_name] = player

	for player in _layers.values():
		player.play()


func set_layer_volume(layer_name: String, target_db: float, fade_sec := 0.5) -> void:
	if layer_name not in _layers:
		return
	var player: AudioStreamPlayer = _layers[layer_name]
	if not is_instance_valid(player):
		return

	if _layer_tweens.has(layer_name) and _layer_tweens[layer_name] and _layer_tweens[layer_name].is_valid():
		_layer_tweens[layer_name].kill()

	if fade_sec <= 0.0:
		player.volume_db = target_db
	else:
		var tw := create_tween()
		tw.tween_property(player, "volume_db", target_db, fade_sec)
		_layer_tweens[layer_name] = tw


func stop_layers(fade_sec := 0.0) -> void:
	for layer_name in _layers:
		var player: AudioStreamPlayer = _layers[layer_name]
		if fade_sec > 0.0 and is_instance_valid(player):
			var tw := create_tween()
			tw.tween_property(player, "volume_db", -80.0, fade_sec)
			tw.tween_callback(player.queue_free)
		elif is_instance_valid(player):
			player.queue_free()
	_layers.clear()
	_layer_tweens.clear()

# ---------------------------------------------------------------------------
# Bus Volume Control & Timing Helpers
# ---------------------------------------------------------------------------

## Sets master, music, or sfx bus volume from linear value (0.0 - 1.0).
func set_bus_volume(bus_name: String, linear_value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear_value, 0.0001, 1.0)))
	else:
		push_warning("AudioManager: Bus '%s' not found." % bus_name)


func get_bar_index() -> int:
	return _bar_index


func get_beat_index() -> int:
	return _beat_index


func get_bars_until_next_boundary() -> float:
	if bpm <= 0.0:
		return 0.0
	var beat_duration := 60.0 / bpm
	var active_player := _get_active_music_player()
	if active_player == null or not active_player.playing:
		return 0.0

	var position := active_player.get_playback_position()
	var current_beat := position / beat_duration
	var next_bar_beat := (int(current_beat / beats_per_bar) + 1) * beats_per_bar
	return next_bar_beat * beat_duration - position

# ---------------------------------------------------------------------------
# Specialized Effects Forwarding / Delegation
# ---------------------------------------------------------------------------

func update_player_wind(speed: float) -> void:
	if specialized_effects:
		specialized_effects.update_player_wind(speed)


func stop_player_wind() -> void:
	if specialized_effects:
		specialized_effects.stop_player_wind()


func play_player_thud(velocity: float) -> void:
	if specialized_effects:
		specialized_effects.play_player_thud(velocity)


func play_player_hurt() -> void:
	if specialized_effects:
		specialized_effects.play_player_hurt()


func attach_proximity_loop(source: Node2D, stream_or_key: Variant, max_distance := 200.0, volume_db := 0.0, attenuation := 1.0) -> AudioStreamPlayer2D:
	if specialized_effects:
		return specialized_effects.attach_proximity_loop(source, stream_or_key, max_distance, volume_db, attenuation)
	return null

# ---------------------------------------------------------------------------
# Private Internal Utilities
# ---------------------------------------------------------------------------

func get_active_music_player() -> AudioStreamPlayer:
	return _get_active_music_player()


func get_inactive_music_player() -> AudioStreamPlayer:
	return _get_inactive_music_player()


func _get_active_music_player() -> AudioStreamPlayer:
	return _music_a if _active_music_slot == 0 else _music_b


func _get_inactive_music_player() -> AudioStreamPlayer:
	return _music_b if _active_music_slot == 0 else _music_a


func _stop_player(player: AudioStreamPlayer) -> void:
	player.stop()
	player.volume_db = -80.0


func _reset_music_clock() -> void:
	_beat_index = -1
	_bar_index = -1
	_last_playback_position = 0.0
	_loop_offset = 0.0


func _execute_music_transition() -> void:
	var data := _pending_music
	_pending_music = {}

	var stream_or_key: Variant = data["stream_or_key"]
	bpm = data["bpm"]
	beats_per_bar = data["beats_per_bar"]
	var crossfade_sec: float = data["crossfade_sec"]

	play_music(stream_or_key, crossfade_sec)


func _execute_music_stop() -> void:
	var fade_sec: float = _pending_stop.get("fade_sec", 1.0)
	_pending_stop = {}
	_fade_out_active_music(fade_sec)


func _fade_out_active_music(fade_sec: float) -> void:
	var active_player := _get_active_music_player()
	if not active_player.playing:
		current_music_key = null
		_reset_music_clock()
		return

	_cancel_crossfade()
	_crossfade_tween = create_tween()
	_crossfade_tween.tween_property(active_player, "volume_db", -80.0, fade_sec)
	_crossfade_tween.tween_callback(func():
		_stop_player(active_player)
		_reset_music_clock()
		current_music_key = null
	)


func _cancel_crossfade() -> void:
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	_crossfade_tween = null


func _duplicate_looping_stream(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	var copy := stream.duplicate()
	if copy is AudioStreamOggVorbis:
		copy.loop = true
	elif copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif copy is AudioStreamMP3:
		copy.loop = true
	return copy


func _duplicate_non_looping_stream(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	var copy := stream.duplicate()
	if copy is AudioStreamOggVorbis:
		copy.loop = false
	elif copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif copy is AudioStreamMP3:
		copy.loop = false
	return copy
