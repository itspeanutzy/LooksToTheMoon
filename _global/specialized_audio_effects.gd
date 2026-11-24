# res://_tools/audio_manager/specialized_audio_effects.gd
class_name SpecializedAudioEffects
extends Node

## Child component of AudioManager handling specialized gameplay audio logic
## (dynamic wind simulation, impact thuds, damage pitch variations, proximity loops).

@export var wind_velocity_threshold: float = 200.0
@export var wind_velocity_max: float = 700.0
@export var wind_volume_cap_db: float = -12.0
@export var wind_silent_db: float = -40.0

@export var thud_velocity_threshold: float = 300.0
@export var thud_velocity_max: float = 1000.0
@export var thud_volume_min_db: float = -30.0
@export var thud_volume_max_db: float = 0.0

var _wind_player: AudioStreamPlayer
var _audio_manager: Node


func _ready() -> void:
	_audio_manager = get_parent()
	_wind_player = AudioStreamPlayer.new()
	_wind_player.name = "WindPlayer"
	_wind_player.bus = "SFX"
	_wind_player.volume_db = wind_silent_db
	add_child(_wind_player)


## Dynamically adjusts player speed wind sound volume based on current movement speed.
func update_player_wind(speed: float) -> void:
	if speed <= wind_velocity_threshold:
		stop_player_wind()
		return

	if _wind_player.stream == null and _audio_manager.has_method("resolve_stream"):
		_wind_player.stream = _audio_manager.resolve_stream(&"WIND")

	if not _wind_player.playing and _wind_player.stream != null:
		_wind_player.volume_db = wind_silent_db
		_wind_player.play()

	var span := wind_velocity_max - wind_velocity_threshold
	var t := 0.0 if span <= 0.0 else (speed - wind_velocity_threshold) / span
	var volume_db := lerpf(wind_silent_db, wind_volume_cap_db, clampf(t, 0.0, 1.0))
	_wind_player.volume_db = volume_db


## Stops the wind player.
func stop_player_wind() -> void:
	if _wind_player.playing:
		_wind_player.stop()
	_wind_player.volume_db = wind_silent_db


## Plays landing thud sound scaled dynamically by impact velocity.
func play_player_thud(velocity: float) -> void:
	if velocity <= thud_velocity_threshold:
		return

	var span := thud_velocity_max - thud_velocity_threshold
	var t := 0.0 if span <= 0.0 else (velocity - thud_velocity_threshold) / span
	var volume_db := lerpf(thud_volume_min_db, thud_volume_max_db, clampf(t, 0.0, 1.0))

	if _audio_manager.has_method("play_sfx"):
		_audio_manager.play_sfx(&"THUD", volume_db)


## Plays player hurt SFX with random pitch variation.
func play_player_hurt() -> void:
	if _audio_manager.has_method("play_sfx"):
		_audio_manager.play_sfx(&"HURT", 0.0, randf_range(0.9, 1.1))


## Attaches a 2D distance proximity loop to a Node2D source.
func attach_proximity_loop(
	source: Node2D,
	stream_or_key: Variant,
	max_distance: float = 200.0,
	volume_db: float = 0.0,
	attenuation: float = 1.0,
) -> AudioStreamPlayer2D:
	if not is_instance_valid(source) or source.is_queued_for_deletion():
		return null

	var stream: AudioStream = null
	if _audio_manager.has_method("resolve_stream"):
		stream = _audio_manager.resolve_stream(stream_or_key)

	if stream == null:
		return null

	var copy := stream.duplicate()
	if copy is AudioStreamOggVorbis:
		copy.loop = true
	elif copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD

	var player := AudioStreamPlayer2D.new()
	player.name = "ProximityLoop"
	player.bus = "SFX"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.stream = copy
	player.max_distance = max_distance
	player.attenuation = attenuation
	player.volume_db = volume_db
	source.add_child(player)
	player.play()

	source.tree_exiting.connect(func():
		if is_instance_valid(player):
			player.stop()
	, CONNECT_ONE_SHOT)

	return player
