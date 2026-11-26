extends TextureButton

signal scene_requested(scene_path)
@onready var label = $Label
var target_scene: String = ""

const HOVER_MULTIPLIER := 1.08
const TWEEN_TIME := 0.12

var _base_scale: Vector2
var _tween: Tween

func _ready():
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_scale = scale  # remember whatever scale it started with
	_update_pivot()
	resized.connect(_update_pivot)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(game_name: String, scene_path: String):
	target_scene = scene_path
	label.text = game_name

func _on_pressed() -> void:
	if target_scene != "":
		scene_requested.emit(target_scene)

func _update_pivot() -> void:
	pivot_offset = size / 2.0

func _on_mouse_entered() -> void:
	_animate_scale(_base_scale * HOVER_MULTIPLIER)

func _on_mouse_exited() -> void:
	_animate_scale(_base_scale)

func _animate_scale(target: Vector2) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", target, TWEEN_TIME)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
