extends Camera2D

@export var zoomSpeed: float = 10.0
@export var intro_zoom: Vector2 = Vector2(0.3, 0.3)
@export var normal_zoom: Vector2 = Vector2(1.0, 1.0)
@export var intro_duration: float = 1.0
@export var min_zoom: float = 0.3
@export var max_zoom: float = 1.4

var zoomTarget: Vector2

var dragStartMousePos = Vector2.ZERO
var dragStartCameraPos = Vector2.ZERO
var isDragging: bool = false

var intro_finished: bool = false
var intro_timer: float = 0.0


func _ready():
	zoom = intro_zoom
	zoomTarget = normal_zoom


func _process(delta):
	if not intro_finished:
		intro_timer += delta

		var progress = clamp(intro_timer / intro_duration, 0.0, 1.0)
		zoom = intro_zoom.lerp(normal_zoom, progress)

		if progress >= 1.0:
			intro_finished = true

		return

	Zoom(delta)
	SimplePan(delta)
	ClickAndDrag()


func Zoom(delta):
	if Input.is_action_just_pressed("camera_zoom_in"):
		zoomTarget *= 1.1

	if Input.is_action_just_pressed("camera_zoom_out"):
		zoomTarget *= 0.9

	zoomTarget.x = clamp(zoomTarget.x, min_zoom, max_zoom)
	zoomTarget.y = clamp(zoomTarget.y, min_zoom, max_zoom)

	zoom = zoom.lerp(zoomTarget, zoomSpeed * delta)


func SimplePan(delta):
	var moveAmount = Vector2.ZERO

	if Input.is_action_pressed("camera_move_right"):
		moveAmount.x += 1

	if Input.is_action_pressed("camera_move_left"):
		moveAmount.x -= 1

	if Input.is_action_pressed("camera_move_up"):
		moveAmount.y -= 1

	if Input.is_action_pressed("camera_move_down"):
		moveAmount.y += 1

	moveAmount = moveAmount.normalized()
	position += moveAmount * delta * 1000 * (1 / zoom.x)


func ClickAndDrag():
	if !isDragging and Input.is_action_just_pressed("camera_pan"):
		dragStartMousePos = get_viewport().get_mouse_position()
		dragStartCameraPos = position
		isDragging = true

	if isDragging and Input.is_action_just_released("camera_pan"):
		isDragging = false

	if isDragging:
		var moveVector = get_viewport().get_mouse_position() - dragStartMousePos
		position = dragStartCameraPos - moveVector * (1 / zoom.x)
