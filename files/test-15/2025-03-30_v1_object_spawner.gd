class_name ObjectSpawner
extends Node

var chest_scene: PackedScene = preload("res://scenes/objects/chest_scene.tscn")
var crafter_scene: PackedScene = preload("res://scenes/objects/crafter_scene.tscn")

func spawn_chest(position: Vector2) -> void:
	if not multiplayer.is_server():
		_request_chest_spawn(position)
		return
		
	var new_chest = chest_scene.instantiate()
	new_chest.position = position
	
	add_child(new_chest, true)
	
@rpc("any_peer", "reliable")
func _request_chest_spawn(position: Vector2):
	if multiplayer.is_server():
		spawn_chest(position)
		
########################################
		
		
func spawn_crafter(position: Vector2) -> void:
	if not multiplayer.is_server():
		_request_crafter_spawn(position)
		return
		
	var new_crafter = crafter_scene.instantiate()
	new_crafter.position = position
	add_child(new_crafter, true)
	
@rpc("any_peer", "reliable")
func _request_crafter_spawn(position: Vector2):
	if multiplayer.is_server():
		spawn_chest(position)
		
