class_name TileManager
extends Node

@onready var highlight_indicator_map: TileMapLayer = $"/root/Game/HighlightIndicatorMap"

#region Member Variables
# a dictionary of all the islands, [island_vector : island]
var island_tile_states: Dictionary[Vector2i, Island] = {}

# holds layout manager but probably will be removed later
var island_layout_manager: IslandsLayout

# holds a reference to the island that was interacted with
var island: Island

signal fishing_tile_changed

#endregion
func _ready() -> void:
	# save all islands in island_tile_states
	island_layout_manager = get_parent()
	for island in IslandsLayout.get_all_children(get_parent()):
		if not island is Island:
			continue
		island_tile_states[island.layout_position] = island

#region Tile Functions
## Only checks if given tile_action can be performed and does not actually perform
## it on the given location (which is converted to a relative island and tile if possible)
func can_do_tile_action(world_position: Vector2, tile_action: TileActions, item_id: StringName) -> bool:
	var relative_island_vector := get_relative_island_vector(world_position)
	var relative_tile_vector := get_relative_tile_vector(relative_island_vector, world_position)
	
	if not island_tile_states.has(relative_island_vector):
		return false
		
	var this_island: Island = island_tile_states[relative_island_vector]

	match tile_action:
		TileActions.Till:
			return this_island.can_tile_be_tilled(relative_tile_vector)
		TileActions.Water:
			return this_island.can_tile_be_watered(relative_tile_vector)
		TileActions.Plant:
			return this_island.can_tile_be_planted(relative_tile_vector, ItemDb.get_item(item_id))
		TileActions.Plant_Sapling:
			return can_tile_be_placed_on(world_position, true) and not is_tile_bridge(world_position)
		TileActions.Fish:
			return not this_island.get_island_tile_from_vector(relative_tile_vector)
		TileActions.Fertilize:
			return this_island.can_tile_be_fertilized(relative_tile_vector)
		TileActions.Bridge:
			return this_island.can_bridge_be_placed(relative_tile_vector)
		TileActions.Hit:
			return this_island.can_tile_be_chopped_or_mined(relative_tile_vector, ItemDb.get_item(item_id))
		_:
			ErrorHandler.throw_error(107)
	return false

func can_tile_be_placed_on(world_position: Vector2, ignore_player: bool = false) -> bool:
	var relative_island_vector := get_relative_island_vector(world_position)
	var relative_tile_vector := get_relative_tile_vector(relative_island_vector, world_position)
	
	if not island_tile_states.has(relative_island_vector):
		return false
		
	var target_island: Island = island_tile_states[relative_island_vector]
	
	return target_island.can_tile_be_placed_on(relative_tile_vector, ignore_player) && target_island.unlocked

func is_tile_bridge(world_position: Vector2) -> bool:
	var relative_island_vector := get_relative_island_vector(world_position)
	var relative_tile_vector := get_relative_tile_vector(relative_island_vector, world_position)
	
	if not island_tile_states.has(relative_island_vector):
		return false
		
	var target_island: Island = island_tile_states[relative_island_vector]
	
	return target_island.tile_states.has(relative_tile_vector) and target_island.tile_states[relative_tile_vector].tile_state == TileManager.TileState.Bridge

## Function that takes a position on the world and parses if it is a valid island and tile
## Then does the PlayerTileAction passed in after checking if it can be performed
func do_tile_action(world_position: Vector2, tile_action: TileActions) -> bool:
	var relative_island_vector := get_relative_island_vector(world_position)
	var relative_tile_vector := get_relative_tile_vector(relative_island_vector, world_position)

	if not island_tile_states.has(relative_island_vector):
		return false
		
	var tile: Tile = island_tile_states[relative_island_vector].get_island_tile_from_vector(relative_tile_vector)

	match tile_action:
		TileActions.Till:
			return tile.till_tile(false)
		TileActions.MachineTill:
			return tile.till_tile(true)
		TileActions.Water:
			return tile.water_tile()
		TileActions.Harvest:
			return tile.harvest_tile(false).size()
		TileActions.Bridge:
			return island_tile_states[relative_island_vector].add_bridge_tile(relative_tile_vector)
		_:
			ErrorHandler.throw_error(107)
	return false
	
func do_tile_action_with_id(world_position: Vector2, tile_action: TileActions, id: StringName) -> bool:
	var relative_island_vector := get_relative_island_vector(world_position)
	var relative_tile_vector := get_relative_tile_vector(relative_island_vector, world_position)
	
	if not island_tile_states.has(relative_island_vector):
		return false
		
	var tile: Tile = island_tile_states[relative_island_vector].get_island_tile_from_vector(relative_tile_vector)
	
	if not tile:
		return false
		
	var item: Item = ItemDb.get_item(id)
	
	match tile_action:
		TileManager.TileActions.Hit:
			return tile.use_axe_or_pickaxe_on_tile(item)
		TileManager.TileActions.Plant:
			return tile.plant_tile(item)
		TileManager.TileActions.Fertilize:
			return tile.fertilize_tile(item)
		_:
			return false
	
func do_machine_harvest(world_position: Vector2) -> Array[InventoryItem]:
	var relative_island_vector := get_relative_island_vector(world_position)
	var relative_tile_vector := get_relative_tile_vector(relative_island_vector, world_position)
		
	if not island_tile_states.has(relative_island_vector):
		return []
		
	var tile: Tile = island_tile_states[relative_island_vector].get_island_tile_from_vector(relative_tile_vector)
	
	if not tile:
		return []
		
	return tile.harvest_tile(true)
	
func free_tile_of_object(world_position: Vector2) -> void:
	var relative_island_vector := get_relative_island_vector(world_position)
	var relative_tile_vector := get_relative_tile_vector(relative_island_vector, world_position)
		
	if not island_tile_states.has(relative_island_vector):
		return
		
	var tile: Tile = island_tile_states[relative_island_vector].get_island_tile_from_vector(relative_tile_vector)
	
	if not tile:
		return 
		
	tile.hittable_object = NodePath("")
	island_tile_states[relative_island_vector].update_single_tile_data.rpc(tile.to_dict())
	
#endregion

#region Other tile functionality
func assign_object_to_tile(world_position: Vector2, object_path: NodePath, targetable: bool = true, ignore_player: bool = false) -> bool:
	var relative_island_vector := get_relative_island_vector(world_position)
	var relative_tile_vector := get_relative_tile_vector(relative_island_vector, world_position)
	
	var target_island: Island = island_tile_states[relative_island_vector]
	var tile: Tile = target_island.get_island_tile_from_vector(relative_tile_vector)
	
	if not target_island.can_tile_be_placed_on(relative_tile_vector, ignore_player):
		return false
		
	return tile.place_object_on_tile(object_path, targetable, ignore_player)

## Highlights or un-highlights the tile at the given location
func update_highlight_on_tile(world_position: Vector2, indicator: TileIndicators):
	var relative_island_vector := get_relative_island_vector(world_position)
	var relative_tile_vector := get_relative_tile_vector(relative_island_vector, world_position)
	
	var tile_position = relative_island_vector * 18 + relative_tile_vector
	
	match indicator:
		TileManager.TileIndicators.Valid:
			highlight_indicator_map.set_cell(tile_position, 1, Vector2i(0,0))
		TileManager.TileIndicators.Invalid:
			highlight_indicator_map.set_cell(tile_position, 1, Vector2i(0,0), 1)
		_:
			highlight_indicator_map.set_cell(tile_position, -1)
#endregion

#region Tile Helper Functions
func get_relative_island_vector(world_position: Vector2) -> Vector2i:
	var tile_size := 64
	var island_size := 18
	var island_pixel_size := tile_size * island_size # 1152
	var half_island := island_pixel_size / 2

	var x_index = floor((world_position.x + half_island) / island_pixel_size)
	var y_index = floor((world_position.y + half_island) / island_pixel_size)

	return Vector2i(x_index, y_index)


func get_relative_tile_vector(relative_island: Vector2, world_position: Vector2) -> Vector2i:
	var island_center: Vector2i = relative_island * 64 * 18
	var relative_tile := Vector2i(
		floor((world_position.x - island_center.x) / 64),
		floor((world_position.y - island_center.y) / 64)
	)
	return relative_tile
	
static func get_world_position(island_center: Vector2i, tile: Vector2i):
	var island_position: Vector2i = island_center * 64 * 18
	island_position += tile * 64 + Vector2i(32,32)
	return island_position
#endregion

#region Fishing Helpers
func get_random_time_until_next_fish(position: Vector2) -> float:
	var island_vector: Vector2i = get_relative_island_vector(position)
	if not island_tile_states.has(island_vector):
		printerr("Island not found, this should not happen")
		return 0.0

	return island_tile_states[island_vector].biome.fish_catch_time._get_amount_based_on_average()

func get_random_fish(position: Vector2) -> FishOnLine:
	var island_vector: Vector2i = get_relative_island_vector(position)
	var relative_tile_vector: Vector2i = get_relative_tile_vector(island_vector, position)
	if not island_tile_states.has(island_vector):
		printerr("Island not found, this should not happen")
		return null
		
	return island_tile_states[island_vector].get_random_fish(relative_tile_vector)

func update_fishing_bubbles(position: Vector2, has_fish: bool) -> void:
	var island_vector: Vector2i = get_relative_island_vector(position)
	if not island_tile_states.has(island_vector):
		printerr("Island not found, this should not happen")
		return
	
	var relative_tile_vector: Vector2i = get_relative_tile_vector(island_vector, position)
	island_tile_states[island_vector].update_fishing_bubbles(relative_tile_vector, has_fish)
#endregion

#region enums
enum TileState { Default, Tilled, Watered, Bridge } 
enum TileActions { Till, Water, Plant, Plant_Sapling, Fish, Harvest, Fertilize, Bridge, Hit, MachineTill}
enum TileIndicators { Default, Valid, Invalid }
#endregion
