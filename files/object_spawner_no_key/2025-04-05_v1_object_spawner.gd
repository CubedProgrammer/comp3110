class_name ObjectSpawner
extends Node

var chest_1_scene: PackedScene = preload("res://scenes/objects/chest_1_scene.tscn")
var furnace_1_scene: PackedScene = preload("res://scenes/objects/furnace_1_scene.tscn")

#region Chest
func spawn_chest(position: Vector2, tier: int) -> ChestObject:
	if not multiplayer.is_server():
		_request_chest_spawn(position, tier)
		return
		
	var new_chest
	match tier:
		1:
			new_chest = chest_1_scene.instantiate()
		_:
			ErrorHandler.throw_error(106)
			return null
			
	new_chest.position = position
	add_child(new_chest, true)
	return new_chest
	
@rpc("any_peer", "reliable")
func _request_chest_spawn(position: Vector2, tier: int):
	if multiplayer.is_server():
		spawn_chest(position, tier)
#endregion

#region Furnace	
func spawn_furnace(position: Vector2, tier: int) -> CrafterObject:
	if not multiplayer.is_server():
		_request_crafter_spawn(position, tier)
		return
		
	var new_furnace
	match tier:
		1:
			new_furnace = furnace_1_scene.instantiate()
		_:
			ErrorHandler.throw_error(106)
			return null
			
	new_furnace.position = position
	add_child(new_furnace, true)
	return new_furnace
	
@rpc("any_peer", "reliable")
func _request_crafter_spawn(position: Vector2, tier: int):
	if multiplayer.is_server():
		spawn_chest(position, tier)
#endregion		
