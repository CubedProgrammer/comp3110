class_name Player
extends Node2D

@onready var spawner: ObjectSpawner = $"/root/Game/ObjectRoot" 

func _unhandled_input(event: InputEvent) -> void:
	if(not is_multiplayer_authority()):
		return
		
	if(event.is_action_pressed("ui_left_click")):
		spawner.spawn_chest(get_global_mouse_position())
