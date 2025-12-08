class_name ObjectSpawner
extends Node

@onready var tile_manager: TileManager = $"/root/Game/IslandsLayout/TileManager"

#region Objects
var furnaces: Array[PackedScene] = [
	preload("res://scenes/world/objects/utility_furniture/furnaces/bloomery_furnace.tscn")
]

var chests: Array[PackedScene] = [
	preload("res://scenes/world/objects/utility_furniture/chests/chest_1_scene.tscn")
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

var sapling_scenes: Array[PackedScene] = [
	preload("res://scenes/world/objects/harvestables/saplings/basic_sapling.tscn")
]
#endregion


func spawn_object(object_type: ObjectType, tier: int, position: Vector2) -> Node:
	#if not multiplayer.is_server():
		#_request_object_spawn.rpc_id(1, object_type, tier, position)
		#return null

	return attempt_spawn_object(get_correct_object(object_type, tier), position)

#@rpc("any_peer", "call_remote", "reliable")
#func _request_object_spawn(object_type: ObjectType, tier: int, position: Vector2):
	#if multiplayer.is_server():
		#spawn_object(object_type, tier, position)

func get_correct_object(object_type: ObjectType, tier: int) -> PackedScene:
	tier -= 1
	
	match object_type:
		ObjectType.Furnace:
			return furnaces[tier]
		ObjectType.Chest:
			return chests[tier]
		ObjectType.Tiller:
			return tillers[tier]
		ObjectType.Sprinkler:
			return sprinklers[tier]
		ObjectType.Planter:
			return planters[tier]
		ObjectType.Harvestor:
			return harvestors[tier]
		ObjectType.Composter:
			return composters[tier]
		_:
			ErrorHandler.throw_error(106)
	
	return null

func spawn_dropable_item(position: Vector2 , item_id_to_drop: StringName, item_count: int , offset: bool = false) -> void:
	if not multiplayer.is_server():
		_request_dropable_item_spawn.rpc_id(1 , position , item_id_to_drop, item_count)
		return
		
	var random_offset = Vector2.ZERO
	var new_item = item_on_ground.instantiate() 
	if offset:
		random_offset = Vector2(randf_range(-32, 32) , randf_range(-32, 32))
		
	new_item.position = position + random_offset
	new_item.setup(item_id_to_drop , item_count)
	ObjectManager.object_data_manager.register_object(new_item.save())

@rpc("any_peer", "call_remote", "reliable")
func _request_dropable_item_spawn(position: Vector2 , item_id_to_drop: StringName, item_count: int):
	if multiplayer.is_server():
		spawn_dropable_item(position , item_id_to_drop, item_count)

func attempt_spawn_object(object_scene: PackedScene, position: Vector2i, can_spawn_on_bridge: bool = true) -> Node:
	if not multiplayer.is_server():
		_request_spawn_object(object_scene.resource_path, position, can_spawn_on_bridge)
		return null
		
	var object_instance = object_scene.instantiate()
	
	if object_instance is HittableObject:
		object_instance = can_spawn_hittable_object(object_instance, position, can_spawn_on_bridge)
	
	if object_instance == null:
		return null
	
	object_instance.initalize(position)
	
	var object_id = ObjectManager.object_data_manager.register_object(object_instance.save())
	
	return ObjectManager.object_data_manager.active_objects.get(object_id, object_instance)

func can_spawn_hittable_object(object_instance: Node, position: Vector2i, can_spawn_on_bridge: bool = true) -> Node:
	#var object_instance: HittableObject = object_scene.instantiate()
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

func spawn_harvestable_plant(position: Vector2, island: Island, tilemap_location: Vector2):
	var harvestable_plant = harvestable_plant_scene.instantiate()
	harvestable_plant.assign_plant(island, tilemap_location)
	harvestable_plant.position = position
#
	ObjectManager.object_data_manager.register_object(harvestable_plant.save())
	
func spawn_harvestable_tree(position: Vector2, sapling: SaplingItem) -> Node:
	return attempt_spawn_object(sapling_scenes[sapling.tree_scene_index], position, false)
	#if not multiplayer.is_server():
		#_request_spawn_harvestable_tree.rpc_id(1, position, island.get_path(), tilemap_location, sapling.id)
		#return false
#
	#var harvestable_tree: Sapling = can_spawn_hittable_object(sapling_scenes[sapling.tree_scene_index], position)
#
	#if not attempt_spawn_object(sapling_scenes[sapling.tree_scene_index], position, false):
		#return false
		#
	#harvestable_tree.position = ((island.layout_position * 18) + tilemap_location) * 64
	#harvestable_tree.initialize()
	#return ObjectManager.object_data_manager.register_object(harvestable_tree.save()).length() > 0


#@rpc("any_peer", "call_remote", "reliable")
#func _request_spawn_harvestable_tree(position: Vector2, island: String, tilemap_location: Vector2, tree_id: StringName):
	#if not multiplayer.is_server():
		#return
#
	#spawn_harvestable_tree(position, get_node(island), tilemap_location, ItemDb.get_item(tree_id) as SaplingItem)

enum ObjectType{
	Chest,
	Furnace,
	Tiller,
	Sprinkler,
	Planter,
	Harvestor,
	Composter
}
