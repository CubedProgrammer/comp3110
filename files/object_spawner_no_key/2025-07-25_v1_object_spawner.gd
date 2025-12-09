class_name ObjectSpawner
extends Node

@onready var tile_manager: TileManager = $"/root/Game/IslandsLayout/TileManager"

#region Objects
var furnaces: Array[PackedScene] = [
	preload("res://scenes/world/objects/utility_furniture/furnaces/bloomery_furnace.tscn"),
]

var chests: Array[PackedScene] = [
	preload("res://scenes/world/objects/utility_furniture/chests/fiberous_chest.tscn"),
	preload("res://scenes/world/objects/utility_furniture/chests/icebox_chest.tscn"),
	preload("res://scenes/world/objects/utility_furniture/chests/desert_coffer.tscn"),
	preload("res://scenes/world/objects/utility_furniture/chests/magical_religuary.tscn"),
	preload("res://scenes/world/objects/utility_furniture/chests/magma_tank.tscn")
]

var tillers: Array[PackedScene] = [
	preload("res://scenes/world/objects/farming_furniture/tillers/bernouli_tiller.tscn"),
	preload("res://scenes/world/objects/farming_furniture/tillers/justin_moose_automated_tiller.tscn")
]

var sprinklers: Array[PackedScene] = [
	preload("res://scenes/world/objects/farming_furniture/sprinklers/dinkler.tscn"),
	preload("res://scenes/world/objects/farming_furniture/sprinklers/land_hydrator.tscn")
]

var planters: Array[PackedScene] = [
	preload("res://scenes/world/objects/farming_furniture/planters/trctr_planter.tscn"),
	preload("res://scenes/world/objects/farming_furniture/planters/type_m_steam_planter.tscn")
]

var harvestors: Array[PackedScene] = [
	preload("res://scenes/world/objects/farming_furniture/harvestors/pendulum_harvestor.tscn"),
	preload("res://scenes/world/objects/farming_furniture/harvestors/steam_combine.tscn")
]

var composters: Array[PackedScene] = [
	preload("res://scenes/world/objects/utility_furniture/composters/composter.res")
]

var item_on_ground: PackedScene = preload("res://scenes/world/objects/item_on_ground.tscn")

var harvestable_plant_scene: PackedScene = preload("res://scenes/world/objects/harvestables/harvestable_plant_object.tscn")

var saplings: Array[PackedScene] = [
	preload("res://scenes/world/objects/harvestables/saplings/mango_sapling.tscn")
]
#endregion


func spawn_object(object_type: ObjectType, tier: int, position: Vector2) -> Node:
	return attempt_spawn_object(get_correct_object(object_type, tier), position)


func get_correct_object(object_type: ObjectType, index: int) -> PackedScene:
	index -= 1
	
	match object_type:
		ObjectType.Furnace:
			return furnaces[index]
		ObjectType.Chest:
			return chests[index]
		ObjectType.Tiller:
			return tillers[index]
		ObjectType.Sprinkler:
			return sprinklers[index]
		ObjectType.Planter:
			return planters[index]
		ObjectType.Harvestor:
			return harvestors[index]
		ObjectType.Composter:
			return composters[index]
		ObjectType.SaplingPlant:
			return saplings[index]
		_:
			ErrorHandler.throw_error(106)
	
	return null


func spawn_dropable_item(position: Vector2 , item_id_to_drop: StringName, item_count: int , offset: bool = false) -> void:
	if not multiplayer.is_server():
		_request_dropable_item_spawn.rpc_id(1, position, item_id_to_drop, item_count)
		return
	
	var random_offset = Vector2.ZERO
	var new_item: ItemOnGround = item_on_ground.instantiate() 
	if offset:
		random_offset = Vector2(randf_range(-32, 32) , randf_range(-32, 32))
	
	new_item.position = position + random_offset
	new_item.setup(item_id_to_drop , item_count)
	add_child(new_item, true)


@rpc("any_peer", "call_remote", "reliable")
func _request_dropable_item_spawn(position: Vector2 , item_id_to_drop: StringName, item_count: int):
	if multiplayer.is_server():
		spawn_dropable_item(position, item_id_to_drop, item_count)


func attempt_spawn_object(object_scene: PackedScene, position: Vector2i, can_spawn_on_bridge: bool = true) -> Node:
	if not multiplayer.is_server():
		_request_spawn_object.rpc_id(1, object_scene.resource_path, position, can_spawn_on_bridge)
		return null
		
	var object_instance = object_scene.instantiate()
	
	if object_instance is HittableObject:
		object_instance = can_spawn_hittable_object(object_instance, position, can_spawn_on_bridge)
	
	if object_instance == null:
		return null
	
	object_instance.initialize(position)
	add_child(object_instance, true)
	
	return object_instance


func can_spawn_hittable_object(object_instance: Node, position: Vector2i, can_spawn_on_bridge: bool = true) -> Node:
	var tiles_to_occupy: Array[Vector2i]

	for x in range(object_instance.hitbox_size.x):
		for y in range(object_instance.hitbox_size.y):
			tiles_to_occupy.append(position + Vector2i(x, y) * 64)

	for tile in tiles_to_occupy:
		if not tile_manager.can_tile_be_placed_on(tile) or (not can_spawn_on_bridge and tile_manager.is_tile_bridge(tile)):
			return null
	
	object_instance.occupied_tiles = tiles_to_occupy
	
	return object_instance


@rpc("any_peer", "call_remote", "reliable")
func _request_spawn_object(object_scene_path: String, position: Vector2i, can_spawn_on_bridge: bool = true):
	if multiplayer.is_server():
		attempt_spawn_object(ResourceLoader.load(object_scene_path), position, can_spawn_on_bridge)


func spawn_harvestable_plant(position: Vector2, island: Island, tilemap_location: Vector2) -> void:
	var harvestable_plant: HarvestablePlantObject = harvestable_plant_scene.instantiate()
	harvestable_plant.assign_plant(island, tilemap_location)
	harvestable_plant.position = position
	add_child(harvestable_plant, true)


func spawn_harvestable_tree(position: Vector2, sapling: SaplingItem) -> Node:
	return attempt_spawn_object(get_correct_object(ObjectType.SaplingPlant, sapling.tree_scene_index), position, false)


enum ObjectType{
	Chest,
	Furnace,
	Tiller,
	Sprinkler,
	Planter,
	Harvestor,
	Composter,
	SaplingPlant,
}
