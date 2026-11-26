extends Node2D

@onready var fade: ColorRect = $CanvasGroup/fade
@onready var button_slots = [$Slot1, $Slot2, $Slot3, $Slot4] 

var minigame_pool = [
	{
		"name": "Blessing Harvest", 
		"scene": "res://scenes/minigames/BlessingHarvest/blessing_harvest.tscn",
		"req_level": 1
	},
	{
		"name": "Coastal Defense", 
		"scene": "res://scenes/minigames/CoastalDefense/CoastalDefense.tscn", 
		"req_level": 1
	},
	{
		"name": "Guide a Boat", 
		"scene": "res://scenes/minigames/BoatGuiding/guide_a_ship_REG.tscn", 
		"req_level": 3
	}
]

func _ready() -> void:
	fade.color.a = 0
	HUD.show()
	_setup_minigames()

func _setup_minigames():
	var available_minigames = []
	for mg in minigame_pool:
		if GameState.prosperity >= mg["req_level"]:
			available_minigames.append(mg)
			
	available_minigames.shuffle()
	
	for i in range(button_slots.size()):
		var btn = button_slots[i]
		
		if i < available_minigames.size():
			btn.show()
			var mg_data = available_minigames[i]
			btn.setup(mg_data["name"], mg_data["scene"])
			btn.scene_requested.connect(_change_scene_with_fade)
		else:
			btn.hide()
			
func _change_scene_with_fade(scene_path: String):
	var tween = create_tween()
	
	tween.tween_property(fade, "color:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	
	await get_tree().create_timer(0.1).timeout
	
	get_tree().change_scene_to_file(scene_path)
