class_name Island
extends Node2D

@export_category("Basic island info")
## The Biome this this island is in
@export var biome: Biome

#array of tiles that have their timers ticking
var needs_updating_tile_array: Array[Tile]

## The position of this island in the islands layout map.
@export var layout_position: Vector2i = Vector2i.ZERO

## How much this island costs
@export var cost: int

## Tracks if this island is unlocked
var unlocked: bool

## The status of all this islands tiles
var tile_states: Dictionary = {}

#tilemaps and nodes
@onready var ground_layer: TileMapLayer = $Tilemaps/GroundLayer
@onready var stitching_manager: StitchingManager = $Tilemaps/StitchingLayer
@onready var water_layer: TileMapLayer = $Tilemaps/WaterLayer
@onready var data_layer: TileMapLayer = $Tilemaps/DataLayer
@onready var dirt_layer: TileMapLayer = $Tilemaps/DirtLayer
@onready var plant_layer: TileMapLayer = $Tilemaps/PlantLayer
@onready var fertilizer_layer: TileMapLayer = $Tilemaps/FertilizerLayer
@onready var addons_layer: TileMapLayer = $Tilemaps/AddonsLayer
@onready var tilemaps: Node2D = $Tilemaps
@onready var water_placeholder: TileMapLayer = $WaterPlaceholder

@onready var islands_layout: IslandsLayout = $"/root/Game/IslandsLayout"
@onready var object_spawner: ObjectSpawner = $"/root/Game/ObjectRoot"
# Used for tiles
@onready var tile_manager: TileManager = $"/root/Game/IslandsLayout/TileManager"
#region Init
func _initialize_tile_states(tile_data = null):
	if tile_data:
		tile_states = tile_data
		return

	for cell in ground_layer.get_used_cells():
		tile_states[Vector2i(cell.x, cell.y)] = Tile.new(self, TileManager.TileState.Default, Vector2i(cell.x, cell.y))


func _ready() -> void:
	ObjectManager.add_object_to_save(self)
	tilemaps.visible = false
	water_placeholder.visible = true

	if cost == 0:
		islands_layout.finished_initial_load_signal.connect(
			func():
				if not multiplayer.is_server():
					_unlock.rpc_id.bind(1)
				else:
					_unlock()
		)

	if tile_states.is_empty():
		_initialize_tile_states()
	
	multiplayer.peer_connected.connect(_on_peer_connected)
#endregion

func _process(delta: float) -> void:
	if not is_node_ready() || not is_multiplayer_authority():
		return

	for tile in needs_updating_tile_array:
		tile.process_tile(delta)

#region Unlocking logic
func _on_peer_connected(id: int) -> void:
	if not is_inside_tree() or not is_multiplayer_authority():
		return

	if unlocked:
		_unlock.rpc_id(id)
		
	_sync_tile_data.rpc_id(id, copy_tile_states_dict())


@rpc("any_peer", "call_local", "reliable")
func try_unlock() -> void:
	if not is_multiplayer_authority():
		return

	_unlock.rpc()


@rpc("authority", "call_local", "reliable")
func _unlock() -> void:
	if unlocked:
		return

	unlocked = true
	tilemaps.visible = true
	water_placeholder.visible = false
	water_placeholder.collision_enabled = false
	
	stitching_manager._initialize_stitching_manager()
	islands_layout.island_changed.emit(layout_position)
	ObjectManager.world.world_info.islands_unlocked += 1

#endregion

#region Updating tile data
## if a single tile needs to be updated take a dictionary with the tile data and its position
## and override the tile data for everyone
## then update the visual
@rpc("any_peer", "call_local", "reliable")
func update_single_tile_data(tile_data: Dictionary):
	var tile_position = Vector2i(tile_data.position_x, tile_data.position_y)
	if not tile_states.has(tile_position):
		tile_states[tile_position] = Tile.new(
			self, 
			tile_data.state,
			tile_position
		)
		
		water_layer.set_cell(tile_position, 0, Vector2i(0, 0), 1)

	tile_states[
		tile_position
	].update_single_tile_data(tile_data)


## Server will initialize an empty tile data dict for the caller and
## Will populate it with a copy of the existing tile data but as Tiles and not dictionary
@rpc("authority", "call_remote", "reliable")
func _sync_tile_data(tile_data: Dictionary):
	tile_states = {}
	for tile in tile_data:
		tile_states[tile] = Tile.from_dict(self, tile_data[tile])
		if tile_states[tile].tile_state == TileManager.TileState.Bridge:
			water_layer.set_cell(tile, 0, Vector2i(0, 0), 1)
	
	#once the callers tile_states is set , update all their tile visuals
	update_all_tile_visuals()
	
func add_bridge_tile(tile_position: Vector2i) -> bool:
	if not can_bridge_be_placed(tile_position):
		return false
		
	tile_states[tile_position] = Tile.new(self, TileManager.TileState.Bridge, tile_position)
	water_layer.set_cell(tile_position, 0, Vector2i(0, 0), 1)
	update_single_tile_data.rpc(tile_states[tile_position].to_dict())
	return true
#endregion

#region Tile Availability
func can_tile_be_watered(interacted_tile: Vector2i) -> bool:
	var tile = get_island_tile_from_vector(interacted_tile)
	return tile and tile.can_tile_be_watered()

func can_tile_be_tilled(interacted_tile: Vector2i) -> bool:
	var tile = get_island_tile_from_vector(interacted_tile)
	return tile and tile.can_tile_be_tilled()

func can_tile_be_fertilized(interacted_tile: Vector2i):
	var tile = get_island_tile_from_vector(interacted_tile)
	return tile and tile.can_tile_be_fertilized()
	
func can_tile_be_planted(interacted_tile: Vector2i) -> bool:
	var tile = get_island_tile_from_vector(interacted_tile)
	return tile and tile.can_tile_be_planted()

func can_tile_be_harvested(interacted_tile: Vector2i) -> bool:
	var tile = get_island_tile_from_vector(interacted_tile)
	return tile and tile.can_tile_be_harvested()
	
func can_tile_be_placed_on(interacted_tile: Vector2i, ignore_player: bool = false) -> bool:
	var tile = get_island_tile_from_vector(interacted_tile)
	return tile and tile.can_tile_be_placed_on(ignore_player)
	
func can_bridge_be_placed(interacted_tile: Vector2i) -> bool:
	return not tile_states.has(interacted_tile) and unlocked
	
func can_tile_be_chopped_or_mined(interacted_tile: Vector2i, item: Item) -> bool:
	var tile = get_island_tile_from_vector(interacted_tile)
	return tile and tile.can_tile_be_chopped_or_mined(item)
#endregion

#region save/load
## Save function that saves the tile_states as a dict
func save() -> Dictionary:
	return {
		"instantiate": false,
		"path": get_path(),
		"unlocked": unlocked,
		"tile_states": copy_tile_states_dict(),
	}


## Load function that gets the tile save file and parses it into a dictionary of Tiles
func load(save_data):
	if not save_data["unlocked"]:
		return

	var loaded_tile_data
	var loaded_tile: Tile
	tile_states.clear()

	#for each saved tile
	for tile in save_data["tile_states"]:
		#get the tile data
		loaded_tile_data = save_data["tile_states"][tile]
		#turn it into a tile
		loaded_tile = Tile.from_dict(self, loaded_tile_data)

		#if it was an active tile, add it to the array
		if loaded_tile.dirt_timer > 0:
			add_active_tile_to_active_array(loaded_tile)
		#update the tile states dict
		tile_states[Vector2i(loaded_tile_data.position_x, loaded_tile_data.position_y)] = loaded_tile

	#update all the visuals
	update_all_tile_visuals()
	#unlock all islands
	islands_layout.finished_initial_load_signal.connect(_unlock)


## Function that takes the tile_states and turns it into a dict so
## We can send it over the netork and save and load it
func copy_tile_states_dict():
	var states = {}
	for tile in tile_states:
		states[tile] = tile_states[tile].to_dict()
	return states


#endregion

#region Visual updates
## Update the visual for each tile in the tile_states
func update_all_tile_visuals():
	for tile: Tile in tile_states.values():
		tile.update_all_visuals()

#endregion

#region Helper
func get_random_fish(tile_position: Vector2) -> FishOnLine:
	var fish_options: Dictionary[FishOnLine, int]
	if not data_layer.get_cell_tile_data(tile_position) or not data_layer.get_cell_tile_data(tile_position).has_custom_data("fish_region_id"):
		fish_options = biome.get_fish_options(0)
	else:
		var fish_region_id = data_layer.get_cell_tile_data(tile_position).get_custom_data("fish_region_id")
		fish_options = biome.get_fish_options(fish_region_id)

	return biome.pick_random_fish(fish_options)

func update_fishing_bubbles(tile: Vector2i, has_fish: bool) -> void:
	if has_fish:
		addons_layer.set_cell(tile, 1, Vector2i(0, 0))
	else:
		addons_layer.erase_cell(tile)

## Helper function that takes a tile position and returns the tile at that position
func get_island_tile_from_vector(tile_vector: Vector2i) -> Tile:
	return tile_states[tile_vector] if tile_states.has(tile_vector) else null

func add_active_tile_to_active_array(tile):
	if tile not in needs_updating_tile_array:
		needs_updating_tile_array.append(tile)

func remove_active_tile_from_active_array(tile):
	if tile in needs_updating_tile_array:
		needs_updating_tile_array.erase(tile)

func spawn_harvestable_object(tile_position: Vector2i) -> void:
	if not is_multiplayer_authority():
		return
		
	object_spawner.spawn_harvestable_plant(
		((layout_position * 18) + tile_position) * 64,
		self,
		tile_position
	)

#endregion
