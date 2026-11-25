@tool
extends DialogicLayoutLayer

@export var portrait_size_mode: DialogicNode_PortraitContainer.SizeModes = DialogicNode_PortraitContainer.SizeModes.FIT_SCALE_HEIGHT

## Scale multiplier when a character is not speaking.
@export var unfocused_scale := Vector2(0.95, 0.95)

## How fast the transitions happen.
@export var transition_duration := 0.2

## Store each portrait's original scale.
var original_scales: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	DialogicUtil.autoload().Text.speaker_updated.connect(_on_speaker_updated)


func _on_speaker_updated(current_speaker: DialogicCharacter) -> void:
	for character: DialogicCharacter in Dialogic.Portraits.get_joined_characters():
		var current_portrait: Node = Dialogic.Portraits.get_character_portrait(character)

		if not is_instance_valid(current_portrait):
			continue

		# Save original scale once.
		if not original_scales.has(current_portrait):
			original_scales[current_portrait] = current_portrait.scale

		var is_speaking := (current_speaker == character)

		var target_color := Color.WHITE if is_speaking else Color(0.5, 0.5, 0.5, 1.0)

		var original_scale: Vector2 = original_scales[current_portrait]
		var target_scale := original_scale if is_speaking else original_scale * unfocused_scale

		# Center pivot.
		if current_portrait is Control:
			current_portrait.pivot_offset = current_portrait.size / 2.0

		# Tween transitions.
		var tween := get_tree().create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)

		tween.tween_property(current_portrait, "modulate", target_color, transition_duration)
		tween.tween_property(current_portrait, "scale", target_scale, transition_duration)
		
func crossfade_expression(sprite: Sprite2D) -> void:
	var old_sprite := Sprite2D.new()

	old_sprite.texture = sprite.texture
	old_sprite.hframes = sprite.hframes
	old_sprite.vframes = sprite.vframes
	old_sprite.frame = sprite.frame
	old_sprite.position = sprite.position
	old_sprite.scale = sprite.scale
	old_sprite.rotation = sprite.rotation
	old_sprite.offset = sprite.offset
	old_sprite.centered = sprite.centered
	old_sprite.z_index = sprite.z_index + 1

	sprite.add_sibling(old_sprite)
	old_sprite.owner = sprite.owner

	old_sprite.position = sprite.position

	var tween := create_tween()
	tween.tween_property(old_sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(old_sprite.queue_free)
