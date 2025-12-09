class_name Tile
extends Node

# Position info
var island: Island
var tile_state: TileManager.TileState
var tile_position: Vector2i

# Timers
var dirt_timer: float:
	set(value):
		dirt_timer = clamp(value, 0, 100000000000)
	
var plant_timer: float:
	set(value):
		plant_timer = clamp(value, 0, 100000000000)
		
var fertilizer_timer: float:
	set(value):
		fertilizer_timer = clamp(value, 0, 100000000000)

# Object Infos
var plant_on_tile: PlantableItem

var fertilizer_on_tile: FertilizerItem:
	set(value):
		fertilizer_on_tile = value
		if value and value.is_timer_fertilizer:
			fertilizer_timer = value.fertilizer_timer
			
var hittable_object: NodePath = NodePath(""):
	set(value):
		if hittable_object != NodePath("") and value != hittable_object and value != NodePath(""):
			ErrorHandler.throw_error(108)
		
		hittable_object = value

var can_hit_tile: bool

# Growing info
var plant_on_tile_growth_stage: int

func _init(owner: Island, tile_state: TileManager.TileState, tile_position: Vector2i) -> void:
	island = owner
	self.tile_state = tile_state
	self.tile_position = tile_position

func process_tile(delta: float) -> void:
	dirt_timer -= delta
	if dirt_timer - delta <= 0 and dirt_timer != 0:
		_update_dirt_tile()
	
	if fertilizer_on_tile and fertilizer_on_tile.is_timer_fertilizer and fertilizer_timer > 0:
		fertilizer_timer -= delta
		if fertilizer_timer <= 0:
			fertilizer_on_tile = null
			island.update_single_tile_data.rpc(to_dict())

	if plant_on_tile and tile_state == TileManager.TileState.Watered:
		var growth_multiplier = 1.0 * (fertilizer_on_tile.growth_rate_multiplier if fertilizer_on_tile else 1)
		plant_timer -= delta * growth_multiplier
		if plant_timer <= 0:
			increment_plant_growth_state()

#region Tile functionality helpers
func _update_dirt_tile() -> void:
	if tile_state == TileManager.TileState.Tilled:
		if plant_on_tile:
			return
		
		tile_state = TileManager.TileState.Default
		fertilizer_on_tile = null
		island.remove_active_tile_from_active_array(self)
	
	elif tile_state == TileManager.TileState.Watered:
		tile_state = TileManager.TileState.Tilled
		dirt_timer = island.biome.dirt_timeout_value

	island.update_single_tile_data.rpc(to_dict())


func increment_plant_growth_state():
	if not plant_on_tile.break_on_harvest and plant_on_tile_growth_stage == plant_on_tile.max_growth_state + 1:
		plant_on_tile_growth_stage -= 1
		plant_timer = plant_on_tile.regrow_timer._get_amount_based_on_average()
		spawn_harvestable_object()
		island.update_single_tile_data.rpc(to_dict())
		return
		
	if plant_on_tile_growth_stage >= plant_on_tile.max_growth_state:
		return
		
	plant_on_tile_growth_stage += 1
	if plant_on_tile_growth_stage == plant_on_tile.max_growth_state:
		spawn_harvestable_object()

	plant_timer = plant_on_tile.initial_growth_timer._get_amount_based_on_average()
	island.update_single_tile_data.rpc(to_dict())
#endregion

#region Updating visuals
func update_dirt_tile_visual():
	match tile_state:
		TileManager.TileState.Default:
			island.dirt_layer.set_cell(tile_position, -1)

		TileManager.TileState.Tilled:
			island.dirt_layer.set_cell(tile_position, island.biome.tilemap_index, Vector2i(12, 0))

		TileManager.TileState.Watered:
			island.dirt_layer.set_cell(tile_position, island.biome.tilemap_index, Vector2i(13, 0))
			
		TileManager.TileState.Bridge:
			island.dirt_layer.set_cell(tile_position, 3, Vector2i(0, 0))

func update_fertilized_tile_visual():
	if not fertilizer_on_tile:
		island.fertilizer_layer.erase_cell(tile_position)
		return
		
	island.fertilizer_layer.set_cell(tile_position , island.biome.tilemap_index, fertilizer_on_tile.tileset_index)
	
func update_plant_tile_visual():
	if not plant_on_tile || plant_on_tile_growth_stage <= 0:
		island.plant_layer.erase_cell(tile_position)
		return
	
	island.plant_layer.set_cell(
		tile_position, 
		0, 
		Vector2i(plant_on_tile_growth_stage + 1, plant_on_tile.tileset_index)
	)

func update_all_visuals():
	update_dirt_tile_visual()
	update_fertilized_tile_visual()
	update_plant_tile_visual()
#endregion

#region Harvesting and drops
func spawn_harvestable_object():
	island.spawn_harvestable_object(tile_position)
	
func get_diggable_items(is_machine_till: bool = false)-> Array[InventoryItem]:
	if tile_state == TileManager.TileState.Tilled:
		return []
		
	var diggable_items: Array[InventoryItem] = ItemDrop.attempt_drops_on_array(island.biome.diggable_item_drop_resource)
	if not is_machine_till:
		for diggable_item in diggable_items:
				island.object_spawner.spawn_dropable_item(
					TileManager.get_world_position(island.layout_position, tile_position),
					diggable_item.item_id,
					diggable_item.item_count, 
					true
				)

	return diggable_items
	
func get_harvest_items(is_machine_harvest: bool = false) -> Array[InventoryItem]:
	if not plant_on_tile or plant_on_tile_growth_stage != plant_on_tile.max_growth_state:
		return []
	
	var drops: Array[InventoryItem] = ItemDrop.attempt_drops_on_array(plant_on_tile.item_drop_resource)
	if not is_machine_harvest:
		for drop in drops:
			island.object_spawner.spawn_dropable_item(
				TileManager.get_world_position(island.layout_position, tile_position),
				drop.item_id,
				drop.item_count, 
				true
			)

	return drops
#endregion

#region Tile Availability
func can_tile_be_watered() -> bool:
	return (
			tile_state == TileManager.TileState.Tilled or
			tile_state == TileManager.TileState.Watered
	)

func can_tile_be_tilled() -> bool:
	var cell = island.data_layer.get_cell_tile_data(tile_position)
	if cell and cell.get_custom_data("un-interactable"):
		return false
		
	return(
		hittable_object.is_empty() and
		not (plant_on_tile and plant_on_tile_growth_stage == plant_on_tile.max_growth_state) and
		(
			tile_state == TileManager.TileState.Tilled or
			tile_state == TileManager.TileState.Default
		)
	)

func can_tile_be_fertilized() -> bool:
	return (
		fertilizer_on_tile == null and
		plant_on_tile == null and
		(tile_state == TileManager.TileState.Tilled or tile_state == TileManager.TileState.Watered)
	)

func can_tile_be_planted(plant: PlantableItem) -> bool:
	return (
		plant_on_tile == null and
		(tile_state == TileManager.TileState.Tilled or tile_state == TileManager.TileState.Watered) and
		plant.allowed_biomes.has(island.biome)
	)
	
func can_tile_be_planted_with_sapling(sapling: SaplingItem) -> bool:
	return (
		sapling.allowed_biomes.has(island.biome) and
		can_tile_be_placed_on(true) and
		not tile_state == TileManager.TileState.Bridge
	)

func can_tile_be_harvested() -> bool:
	var cell = island.data_layer.get_cell_tile_data(tile_position)
	if cell and cell.get_custom_data("un-interactable"):
		return false

	return plant_on_tile and plant_on_tile_growth_stage == plant_on_tile.max_growth_state
	
func can_tile_be_placed_on(ignore_player: bool = false) -> bool:
	if not ObjectManager.world:
		return false
	
	var cell = island.data_layer.get_cell_tile_data(tile_position)
	if cell and cell.get_custom_data("un-interactable"):
		return false

	var player_on_tile
	if not ignore_player:
		player_on_tile = ObjectManager.world.players.any(
			func(player: Player): return island.tile_manager.get_relative_tile_vector(island.layout_position, (player.get_node("CollisionShape2D") as CollisionShape2D).global_position) == tile_position
		)
	else :
		player_on_tile = false

	return not player_on_tile and hittable_object == NodePath("") and not plant_on_tile

func can_tile_be_chopped_or_mined(item: Item) -> bool:
	var cell = island.data_layer.get_cell_tile_data(tile_position)
	if cell and cell.get_custom_data("un-interactable"):
		return false
		
	if not hittable_object or not can_hit_tile or hittable_object.is_empty():
		return false
		
	if not island.has_node(hittable_object):
		push_warning("node not found")
		return false
		
	var object = island.get_node(hittable_object)
	return object and object is HittableObject and (object as HittableObject).can_hit(item)
	
#endregion

#region Tile interactions
func till_tile(is_machine_till: bool = false) -> bool:
	if not can_tile_be_tilled():
		return false
		
	var items : Array[InventoryItem] = get_diggable_items(is_machine_till)
	plant_on_tile = null
	
	if tile_state == TileManager.TileState.Watered:
		island.update_single_tile_data.rpc(to_dict())
		return true
	
	tile_state = TileManager.TileState.Tilled
	dirt_timer = island.biome.dirt_timeout_value
	island.add_active_tile_to_active_array(self)
	island.update_single_tile_data.rpc(to_dict())
	
	return true
	
func water_tile() -> bool:
	if not can_tile_be_watered():
		return false
		
	tile_state = TileManager.TileState.Watered
	dirt_timer = island.biome.water_timeout_value
	island.add_active_tile_to_active_array(self)
	island.update_single_tile_data.rpc(to_dict())
	
	return true
	
func plant_tile(seed: Item) -> bool:
	if not can_tile_be_planted(seed):
		return false

	plant_on_tile = seed
	plant_timer = seed.initial_growth_timer._get_amount_based_on_average()
	plant_on_tile_growth_stage = 1
	island.add_active_tile_to_active_array(self)
	island.update_single_tile_data.rpc(to_dict())

	return true
	
func harvest_tile(is_machine_harvest: bool) -> Array[InventoryItem]:
	var items : Array[InventoryItem] = get_harvest_items(is_machine_harvest)
	
	if plant_on_tile.break_on_harvest:
		plant_on_tile_growth_stage = -1
		plant_timer = 0
		plant_on_tile = null
	else:
		plant_timer = plant_on_tile.regrow_timer._get_amount_based_on_average()
		plant_on_tile_growth_stage += 1
		
	if fertilizer_on_tile and not fertilizer_on_tile.is_timer_fertilizer:
		fertilizer_on_tile = null
	
	island.update_single_tile_data.rpc(to_dict())
	return items 

func fertilize_tile(fertilizer: FertilizerItem):
	if not can_tile_be_fertilized():
		return false
		
	fertilizer_on_tile = fertilizer
	island.update_single_tile_data.rpc(to_dict())
	return true

func place_object_on_tile(hittable_object_path: NodePath, targetable: bool, ignore_player: bool = false) -> bool:
	if not can_tile_be_placed_on(ignore_player):
		return false
	
	if tile_state != TileManager.TileState.Bridge:
		fertilizer_on_tile = null
		tile_state = TileManager.TileState.Default
		
	hittable_object = hittable_object_path
	can_hit_tile = targetable
	island.update_single_tile_data.rpc(to_dict())
	
	return true
	
func use_axe_or_pickaxe_on_tile(item: Item) -> bool:
	if not can_tile_be_chopped_or_mined(item):
		return false
		
	(island.get_node(hittable_object) as HittableObject).hit(item)
	return true
		
#endregion

#region RPC Bridges
## if a single tile needs to be updated take a dictionary with the tile data and its position
## and override the tile data for everyone
## then update the visual
func update_single_tile_data(tile_data: Dictionary):
	override_tile(tile_data)
	update_all_visuals()
	

#endregion

#region to dict / from dict
func to_dict() -> Dictionary:
	return {
		"state": tile_state,
		"position_x": tile_position.x,
		"position_y": tile_position.y,
		"dirt_timer": dirt_timer,
		"plant_timer": plant_timer,
		"fertilizer_timer": fertilizer_timer,
		"planted_item": plant_on_tile.id if plant_on_tile else "",
		"fertilizer_item": fertilizer_on_tile.id if fertilizer_on_tile else "", 
		"plant_on_tile_growth_stage": plant_on_tile_growth_stage,
		"hittable_object": hittable_object,
		"hittable": can_hit_tile
	}


static func from_dict(root: Node, tile_save_data: Dictionary) -> Tile:
	var tile: Tile = Tile.new(
		root,
		tile_save_data.state, 
		Vector2i(tile_save_data.position_x, tile_save_data.position_y)
	)
	
	return tile.override_tile(tile_save_data)


func override_tile(tile_save_data: Dictionary) -> Tile:
	tile_position = Vector2i(tile_save_data.position_x, tile_save_data.position_y)
	tile_state = tile_save_data.state
	hittable_object = NodePath("")
	hittable_object = NodePath(tile_save_data.hittable_object)
	dirt_timer = tile_save_data.dirt_timer
	plant_timer = tile_save_data.plant_timer
	fertilizer_timer = tile_save_data.fertilizer_timer
	plant_on_tile = ItemDb.get_item(tile_save_data.planted_item) if tile_save_data.planted_item else null
	fertilizer_on_tile = ItemDb.get_item(tile_save_data.fertilizer_item) if tile_save_data.fertilizer_item else null
	plant_on_tile_growth_stage = tile_save_data.plant_on_tile_growth_stage
	can_hit_tile = tile_save_data.hittable
	
	return self
#endregion
