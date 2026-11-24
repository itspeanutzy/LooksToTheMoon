extends CanvasLayer

@onready var life_container = $HBoxContainer
var boat

func _ready():
	boat = get_tree().get_first_node_in_group("boat")
	
	if boat:
		boat.health_changed.connect(update_health_ui)
		boat.boat_destroyed.connect(_on_boat_destroyed)
		
		update_health_ui(boat.current_health)

func update_health_ui(current_health: int):
	var lives = life_container.get_children()
	
	for i in range(lives.size()):
		var life = lives[i]
		
		if i < current_health:
			if not life.visible:
				life.visible = true
				life.scale = Vector2(0, 0)
				var tween = create_tween()
				tween.tween_property(life, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			if life.visible:
				var tween = create_tween()
				tween.tween_property(life, "scale", Vector2(0, 0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tween.tween_callback(life.hide)

func _on_boat_destroyed():
	pass
