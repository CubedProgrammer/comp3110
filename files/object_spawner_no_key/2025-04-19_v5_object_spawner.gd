class_name ObjectSpawner
extends Node

var furnaces: Array[PackedScene] = [
	preload("res://scenes/world/objects/furnace_1_scene.tscn")
]

var chests: Array[PackedScene] = [
	preload("res://scenes/world/objects/chest_1_scene.tscn")
]

var tillers: Array[PackedScene] = [
	preload("res://scenes/world/objects/farming_furniture/bernouli_tiller.tscn"),
	preload("res://scenes/world/objects/farming_furniture/justin_moose_automated_tiller.tscn")
]

var sprinklers: Array[PackedScene] = [
	#preload("res://scenes/world/objects/farming_furniture/dinkler.tscn")
]

var planters: Array[PackedScene] = [
	#preload("res://scenes/world/objects/farming_furniture/trctr_planter.tscn")
] 

func spawn_object(object_type: ObjectType, tier: int, position: Vector2) -> Node:
	if not multiplayer.is_server():
		_request_object_spawn.rpc_id(1, object_type, tier, position)
		return
		
	var new_object = _spawn_correct_object(object_type, tier)
			
	new_object.position = position
	add_child(new_object, true)
	return new_object
	
@rpc("any_peer", "call_remote", "reliable")
func _request_object_spawn(object_type: ObjectType, tier: int, position: Vector2):
	if multiplayer.is_server():
		spawn_object(object_type, tier, position)	

func _spawn_correct_object(object_type: ObjectType, tier: int) -> Node:
	tier -= 1
	
	match object_type:
		ObjectType.Furnace:
			return furnaces[tier].instantiate()
		ObjectType.Chest:
			return chests[tier].instantiate()
		ObjectType.Tiller:
			return tillers[tier].instantiate()
		ObjectType.Sprinkler:
			return sprinklers[tier].instantiate()
		ObjectType.Planter:
			return planters[tier].instantiate()
		_:
			ErrorHandler.throw_error(106)
	
	return null
	
enum ObjectType{
	Chest,
	Furnace,
	Tiller,
	Sprinkler,
	Planter
}
