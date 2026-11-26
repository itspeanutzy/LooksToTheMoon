extends CanvasLayer

@onready var faith_label = $FaithLabel
@onready var prosperity_label = $ProsperityLabel

func _ready():
	GameState.stats_changed.connect(update_ui)
	update_ui()

func update_ui():
	faith_label.text = "Faith: " + str(GameState.faith)
	prosperity_label.text = "Prosperity: Lv." + str(GameState.prosperity) + " (" + str(GameState.current_xp) + "/" + str(GameState.get_xp_needed()) + ")"
