class_name ObjectSpawner
extends Node

@onready var tile_manager: TileManager = $"/root/Game/IslandsLayout/TileManager"

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
	preload("res://scenes/world/objects/farming_furniture/trctr_planter.tscn")
] 

var dropable_scene = preload("res://scenes/world/objects/dropable_item_scene.tscn")

func spawn_object(object_type: ObjectType, tier: int, position: Vector2, tiles_to_occupy:Array) -> Node:
	if not multiplayer.is_server():
		_request_object_spawn.rpc_id(1, object_type, tier, position, tiles_to_occupy)
		return
		
	var new_object = _spawn_correct_object(object_type, tier)
			
	new_object.position = position
	add_child(new_object, true)
	
	for tile in tiles_to_occupy:
		tile_manager.assign_object_to_tile(tile * 64, new_object)
		
	return new_object
	
@rpc("any_peer", "call_remote", "reliable")
func _request_object_spawn(object_type: ObjectType, tier: int, position: Vector2, tiles_to_occupy: Array = [] ):
	if multiplayer.is_server():
		spawn_object(object_type, tier, position, tiles_to_occupy)	

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
func spawn_dropable_item(position: Vector2 , item_id_to_drop: StringName, item_count: int , offset: bool = false) -> void:
	if not multiplayer.is_server():
		_request_dropable_item_spawn.rpc_id(1 , position , item_id_to_drop, item_count)
		return
		
	var random_offset = Vector2.ZERO
	var new_item = dropable_scene.instantiate() 
	if offset:
		random_offset = Vector2(randf_range(-15,15) , randf_range(-15, 15))
		
	new_item.position = position + random_offset
	add_child(new_item , true)
	new_item.setup(item_id_to_drop , item_count)
	
@rpc("any_peer", "call_remote", "reliable")
func _request_dropable_item_spawn(position: Vector2 , item_id_to_drop: StringName, item_count: int):
	if multiplayer.is_server():
		spawn_dropable_item(position , item_id_to_drop, item_count)
		
enum ObjectType{
	Chest,
	Furnace,
	Tiller,
	Sprinkler,
	Planter
}
