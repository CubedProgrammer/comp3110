class_name ObjectSpawner
extends Node

var chest_scene: PackedScene = preload("res://scenes/objects/chest_scene.tscn")

func spawn_chest(position: Vector2) -> void:
	if not multiplayer.is_server():
		_request_chest_spawn(position)
		return
		
	var new_chest = chest_scene.instantiate() as ChestObject
	new_chest.position = position
	
	add_child(new_chest, true)
	
@rpc("any_peer", "reliable")
func _request_chest_spawn(position: Vector2):
	if multiplayer.is_server():
		spawn_chest(position)
	
