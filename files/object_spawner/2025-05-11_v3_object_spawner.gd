class_name ObjectSpawner
extends Node

@onready var tile_manager: TileManager = $"/root/Game/IslandsLayout/TileManager"

#region Objects
var furnaces: Array[PackedScene] = [
	preload("res://scenes/world/objects/utility_furniture/furnace_1_scene.tscn")
]

var chests: Array[PackedScene] = [
	preload("res://scenes/world/objects/utility_furniture/chest_1_scene.tscn")
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

var dropable_scene = preload("res://scenes/world/objects/dropable_item_scene.tscn")
var harvestable_plant_scene = preload("res://scenes/world/objects/harvestable_plant_object.tscn")
#endregion

func spawn_object(object_type: ObjectType, tier: int, position: Vector2) -> Node:
	if not multiplayer.is_server():
		_request_object_spawn.rpc_id(1, object_type, tier, position)
		return

	return attempt_spawn_hittable_object(get_correct_object(object_type, tier), position)

@rpc("any_peer", "call_remote", "reliable")
func _request_object_spawn(object_type: ObjectType, tier: int, position: Vector2):
	if multiplayer.is_server():
		spawn_object(object_type, tier, position)	

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

func attempt_spawn_hittable_object(object_scene: PackedScene, position: Vector2i, can_spawn_on_bridge: bool = true) -> Node:
	var object_instance: HittableObject = can_spawn_hittable_object(object_scene, position, can_spawn_on_bridge)

	if not object_instance:
		return null

	var untargetable_tiles: Array[Vector2i]

	for x in range(object_instance.hitbox_size.x):
		for y in range(object_instance.hitbox_size.y):
			if object_instance.not_targetable_tiles.has(Vector2i(x, y)):
				untargetable_tiles.append(position + Vector2i(x, y) * 64)

	object_instance.position = position
	add_child(object_instance, true)

	if not object_instance.occupied_tiles.has(position):
		print("err")

	for tile in object_instance.occupied_tiles:
		tile_manager.assign_object_to_tile(tile, object_instance, not untargetable_tiles.has(tile))

	return object_instance

func can_spawn_hittable_object(object_scene: PackedScene, position: Vector2i, can_spawn_on_bridge: bool = true) -> Node:
	var object_instance: HittableObject = object_scene.instantiate()
	var tiles_to_occupy: Array[Vector2i]

	for x in range(object_instance.hitbox_size.x):
		for y in range(object_instance.hitbox_size.y):
			tiles_to_occupy.append(position + Vector2i(x, y) * 64)

	for tile in tiles_to_occupy:
		if not tile_manager.can_tile_be_placed_on(tile) or (not can_spawn_on_bridge and tile_manager.is_tile_bridge(tile)):
			return null
	
	object_instance.occupied_tiles = tiles_to_occupy
	
	return object_instance

func spawn_harvestable_plant(position: Vector2, island: Island, tilemap_location: Vector2):
	var harvestable_plant = harvestable_plant_scene.instantiate()
	harvestable_plant.assign_plant(island, tilemap_location)
	harvestable_plant.position = position
	add_child(harvestable_plant, true)

enum ObjectType{
	Chest,
	Furnace,
	Tiller,
	Sprinkler,
	Planter,
	Harvestor,
	Composter
}
