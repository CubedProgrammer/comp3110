class_name ObjectSpawner
extends Node

@onready var tile_manager: TileManager = $"/root/Game/IslandsLayout/TileManager"

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

var bridge: PackedScene = preload("res://scenes/world/objects/bridge.tscn")

var dropable_scene = preload("res://scenes/world/objects/dropable_item_scene.tscn")
var harvestable_plant_scene = preload("res://scenes/world/objects/harvestable_plant_object.tscn")
var harvestable_tree_scene: PackedScene = preload("res://scenes/world/objects/harvestable_tree_object.tscn")

func spawn_object(object_type: ObjectType, tier: int, position: Vector2) -> Node:
	if not multiplayer.is_server():
		_request_object_spawn.rpc_id(1, object_type, tier, position)
		return
		
	var new_object: HittableObject = _spawn_correct_object(object_type, tier)
	var tiles_to_occupy: Array[Vector2]
	var untargetable_tiles: Array[Vector2]
	
	var object_texture = (new_object.get_node("AnimatedSprite2D") as AnimatedSprite2D).sprite_frames.get_frame_texture("idle", 0)
	
	for x in range(new_object.hitbox_size.x):
		for y in range(new_object.hitbox_size.y):
			tiles_to_occupy.append(position - Vector2(0, object_texture.get_height()) - Vector2(-x, -y - 1) * 64)
			if new_object.not_targetable_tiles.has(Vector2(x, y)):
				untargetable_tiles.append(position - Vector2(0, object_texture.get_height()) - Vector2(-x, -y - 1) * 64)
	
	for tile in tiles_to_occupy:
		if not tile_manager.can_tile_be_placed_on(tile):
			return null
	
	new_object.occupied_tiles = tiles_to_occupy
	new_object.position = position
	
	add_child(new_object, true)
	
	for tile in tiles_to_occupy:
		tile_manager.assign_object_to_tile(tile, new_object, not untargetable_tiles.has(tile))
	
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
		ObjectType.Harvestor:
			return harvestors[tier].instantiate()
		ObjectType.Composter:
			return composters[tier].instantiate()
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

func attempt_spawn_resource(resource_scene: PackedScene, position: Vector2) -> bool:
	var resource: HarvestableResource = resource_scene.instantiate()
	var tiles_to_occupy: Array[Vector2]
	var untargetable_tiles: Array[Vector2]
	
	for x in range(resource.hitbox_size.x):
		for y in range(resource.hitbox_size.y):
			tiles_to_occupy.append(position - Vector2(0, resource.texture.texture.get_height()) - Vector2(-x, -y - 1) * 64)
			if resource.not_targetable_tiles.has(Vector2(x, y)):
				untargetable_tiles.append(position - Vector2(0, resource.texture.texture.get_height()) - Vector2(-x, -y - 1) * 64)
	
	for tile in tiles_to_occupy:
		if not tile_manager.can_tile_be_placed_on(tile) or tile_manager.is_tile_bridge(tile) :
			return false
	
	resource.occupied_tiles = tiles_to_occupy
	resource.position = position
	add_child(resource, true)
	
	for tile in tiles_to_occupy:
		tile_manager.assign_object_to_tile(tile, resource, not untargetable_tiles.has(tile))
		
	return true

func spawn_harvestable_plant(position: Vector2, island: Island, tilemap_location: Vector2):
	var harvestable_plant = harvestable_plant_scene.instantiate()
	harvestable_plant.assign_plant(island, tilemap_location)
	harvestable_plant.position = position
	add_child(harvestable_plant, true)
	
func spawn_harvestable_tree(position: Vector2, island: Island, tilemap_location: Vector2):
	var harvestable_tree: Sapling = harvestable_tree_scene.instantiate()
	harvestable_tree.assign_plant(island, tilemap_location)
	harvestable_tree.position = position
	add_child(harvestable_tree, true)
	harvestable_tree.occupied_tiles = [position]
	tile_manager.assign_object_to_tile(position, harvestable_tree, true)

enum ObjectType{
	Chest,
	Furnace,
	Tiller,
	Sprinkler,
	Planter,
	Harvestor,
	Composter,
	Bridge
}
