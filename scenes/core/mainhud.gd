extends CanvasLayer

@onready var faith_label = $FaithLabel
@onready var prosperity_label = $ProsperityLabel
@export var prosperity_bar: Control

func _ready():
	GameState.stats_changed.connect(update_ui)
	update_ui()

func update_ui():
	faith_label.text = str(GameState.faith)
	prosperity_label.text = "Prosperity: Lv." + str(GameState.prosperity)
	prosperity_bar.max_value = GameState.get_xp_needed()
	prosperity_bar.value = GameState.current_xp
