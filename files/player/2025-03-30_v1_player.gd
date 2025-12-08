class_name Player
extends Node2D

@onready var spawner: ObjectSpawner = $"/root/Game/ObjectRoot"

func _ready() -> void:
	$PlayerCamera2D.visible = is_multiplayer_authority()
	$PlayerCamera2D.priority = 5 if is_multiplayer_authority() else 0
	ObjectManager.load_data()

func _unhandled_input(event: InputEvent) -> void:
	if (not is_multiplayer_authority()):
		return
		
	if (event.is_action_pressed("ui_left_click")):
		spawner.spawn_chest(get_global_mouse_position())
		
	if (event.is_action_pressed("ui_right_click")):
		spawner.spawn_crafter(get_global_mouse_position())
