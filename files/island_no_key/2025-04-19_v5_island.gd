class_name Island
extends Node

@export_category("Basic island info")
## The Biome this this island is in
@export var biome: Resource

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
@onready var data_layer: TileMapLayer = $Tilemaps/DataLayer
@onready var dirt_layer: TileMapLayer = $Tilemaps/DirtLayer
@onready var plant_layer: TileMapLayer = $Tilemaps/PlantLayer
@onready var tilemaps: Node2D = $Tilemaps
@onready var buying_ui: Control = $BuyingUI

@onready var object_spawner: ObjectSpawner = $"/root/Game/ObjectRoot"

func _process(delta: float) -> void:
	if not is_node_ready():
		return

	#loop through all active tiles and if the timer runs out them update them
	for tile in needs_updating_tile_array:
		if tile.dirt_timer <= 0:
			update_dirt_tile(tile)
		tile.dirt_timer -= delta

		if tile.plant_timer <= 0 and tile.plant_on_tile:
			increment_plant_growth_state(tile)

		if tile.tile_state == TileManager.TileState.Watered:
			tile.plant_timer -= delta


func _ready() -> void:
	ObjectManager.add_object_to_save(self)
	tilemaps.visible = false
	hide_unlocking_ui()

	if not is_multiplayer_authority():
		return
	#unlock all islands
	if cost == 0:
		_unlock.rpc_id(1)

	if tile_states.is_empty():
		_initialize_tile_states()

	multiplayer.peer_connected.connect(_on_peer_connected)


#region Unlocking logic
func _on_peer_connected(id: int) -> void:
	if not is_multiplayer_authority():
		return
	#person who just spawned (client) will request to sync island tiles
	_sync_tile_data_request()
	if unlocked:
		_unlock.rpc_id(id)


@rpc("any_peer", "call_local", "reliable")
func try_unlock() -> void:
	if not is_multiplayer_authority():
		return

	_unlock.rpc()


@rpc("authority", "call_local", "reliable")
func _unlock() -> void:
	if unlocked:
		return

	hide_unlocking_ui()
	unlocked = true
	tilemaps.visible = true

	owner.update_unlocking_ui()


func show_unlocking_ui() -> void:
	buying_ui.visible = true


func hide_unlocking_ui() -> void:
	buying_ui.visible = false
#endregion

#region Updating tile data
## Server will try and sync tiles on person who called it
## it will send in a copy of the servers tile_states as a dict
@rpc("any_peer", "call_local", "reliable")
func _sync_tile_data_request():
	if not multiplayer.is_server():
		return

	_sync_tile_data.rpc_id(multiplayer.get_remote_sender_id(), copy_tile_states_dict())


## Server will initialize an empty tile data dict for the caller and
## Will populate it with a copy of the existing tile data but as Tiles and not dictionary
@rpc("authority", "call_local", "reliable")
func _sync_tile_data(tile_data: Dictionary):
	tile_states = {}
	for tile in tile_data:
		tile_states[tile] = Tile.from_dict(tile_data[tile])
	#once the callers tile_states is set , update all their tile visuals
	update_all_tile_visuals()


## if a single tile needs to be updated take a dictionary with the tile data and its position
## and override the tile data for everyone
## then update the visual
@rpc("any_peer", "call_local", "reliable")
func update_single_tile_data(tile_location: Vector2i, tile_data: Dictionary):
	tile_states[tile_location].override_tile(tile_data)
	update_dirt_tile_visual(tile_location)
	update_plant_tile_visual(tile_location)


##Update the visual for each tile in the tile_states
func update_all_tile_visuals():
	for tile_position in tile_states.keys():
		update_dirt_tile_visual(tile_position)
		update_plant_tile_visual(tile_position)


## gets the tile state from the tile and updates its visual on the tile layers
func update_dirt_tile_visual(tile_position: Vector2i):
	var tile_to_update: Tile = tile_states[tile_position]
	var new_state = tile_to_update.tile_state
	match new_state:
		TileManager.TileState.Default:
			dirt_layer.set_cell(tile_position, -1)

		TileManager.TileState.Tilled:
			dirt_layer.set_cell(tile_position, 2, Vector2i(12, 0))

		TileManager.TileState.Watered:
			dirt_layer.set_cell(tile_position, 2, Vector2i(13, 0))


func update_plant_tile_visual(tile_position: Vector2i):
	var tile_to_update: Tile = tile_states[tile_position]

	if tile_to_update.plant_on_tile == null:
		plant_layer.erase_cell(tile_position)
		return

	match tile_to_update.plant_on_tile_growth_stage:
		1:
			plant_layer.set_cell(tile_position, 3, Vector2i(1, 0))
		2:
			plant_layer.set_cell(tile_position, 3, Vector2i(2, 0))
		3:
			plant_layer.set_cell(tile_position, 3, Vector2i(3, 0))
		4:
			plant_layer.set_cell(tile_position, 3, Vector2i(4, 0))
		-1:
			plant_layer.erase_cell(tile_position)
		_:
			pass


## Set up a tile_states from the used cells in the tilemap
func _initialize_tile_states(tile_data = null):
	if tile_data != null:
		tile_states = tile_data
		return

	for cell in ground_layer.get_used_cells():
		tile_states[Vector2i(cell.x, cell.y)] = Tile.new(
			TileManager.TileState.Default, Vector2i(cell.x, cell.y)
		)


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
		loaded_tile = Tile.from_dict(loaded_tile_data)

		#if it was an active tile, add it to the array
		if loaded_tile.dirt_timer > 0:
			add_active_tile_to_active_array(loaded_tile)

		#update the tile states dict
		tile_states[Vector2i(loaded_tile_data.position_x, loaded_tile_data.position_y)] = loaded_tile

	#update all the visuals
	update_all_tile_visuals()
	#unlock all islands
	_unlock()


## Function that takes the tile_states and turns it into a dict so
## We can send it over the netork and save and load it
func copy_tile_states_dict():
	var states = {}
	for tile in tile_states:
		states[tile] = tile_states[tile].to_dict()
	return states


#endregion

#region Tile Interaction Functions


func increment_plant_growth_state(tile: Tile):
	var plant: PlantableItem = tile.plant_on_tile
	if tile.plant_on_tile_growth_stage >= plant.max_growth_state:
		return
	tile.plant_on_tile_growth_stage += 1
	tile.plant_timer = plant.initial_growth_timer
	update_single_tile_data.rpc(tile.tile_position, tile.to_dict())


## Function to be used when a tile needs to be updated
## for example if a timer runs out and we need to set a tilled tile back to default
func update_dirt_tile(tile: Tile) -> void:
	var tile_state = tile.tile_state
	match tile_state:
		TileManager.TileState.Default:
			pass

		TileManager.TileState.Tilled:
			tile.set_tile_state(TileManager.TileState.Default)
			tile.dirt_timer = 0
			back_to_default_tile_state(tile)

		TileManager.TileState.Watered:
			tile.set_tile_state(TileManager.TileState.Tilled)
			tile.dirt_timer = biome.dirt_timeout_value
		_:
			pass
			
	update_single_tile_data.rpc(tile.tile_position, tile.to_dict())


## Function that checks if the tile can be watered
func can_tile_be_watered(tile_to_till: Vector2i) -> bool:
	return (
		does_island_tile_state_have_tile(tile_to_till)
		and tile_states[tile_to_till].tile_state == TileManager.TileState.Tilled
	)


## Function that checks the tile custom data to make sure its not an untillable tile
func can_tile_on_tileset_be_tilled(tile_to_till: Vector2i) -> bool:
	#if its not default since you only till default tiles
	if tile_states[tile_to_till].tile_state != TileManager.TileState.Default:
		return false

	var custom_data = data_layer.get_cell_tile_data(tile_to_till)
	if custom_data:
		return custom_data.get_custom_data("is_tillable")

	return true


## Function that checks if a tile can be tilled
func can_tile_be_tilled(tile_to_till: Vector2i) -> bool:
	return (
		does_island_tile_state_have_tile(tile_to_till)
		and can_tile_on_tileset_be_tilled(tile_to_till)
	)


func can_tile_be_planted(tile_to_till: Vector2i) -> bool:
	return (
		does_island_tile_state_have_tile(tile_to_till) and
		get_island_tile_from_vector(tile_to_till).plant_on_tile == null and
		(tile_states[tile_to_till].tile_state == TileManager.TileState.Tilled or 
		tile_states[tile_to_till].tile_state == TileManager.TileState.Watered)
	)
			
		


#endregion


#region Helper
## Helper function that takes a tile position and returns the tile at that position
func get_island_tile_from_vector(tile_vector: Vector2i) -> Tile:
	if tile_states.has(tile_vector):
		return tile_states[tile_vector]
	return null


## Helper function that returns if the tile is on the island
func does_island_tile_state_have_tile(tile_to_till: Vector2i) -> bool:
	return tile_states.has(tile_to_till)

func add_active_tile_to_active_array(tile):
	if tile not in needs_updating_tile_array:
		needs_updating_tile_array.append(tile)

func remove_active_tile_from_active_array(tile):
	if tile in needs_updating_tile_array:
		needs_updating_tile_array.erase(tile)

func back_to_default_tile_state(tile: Tile):
	remove_active_tile_from_active_array(tile)
	if(tile.plant_on_tile):
		get_harvest_items(tile)
		tile.plant_on_tile = null
		tile.set_current_plant_growth_state(-1)

# TODO
#handle redrop seed
#handle some plants have a 5th state with the actual harvest
#and switch back and forth
#some plants also dont break on ahrvest
func get_harvest_items(tile: Tile):
	if(tile.plant_on_tile_growth_stage == tile.plant_on_tile.max_growth_state):
		object_spawner.spawn_dropable_item(
			TileManager.get_world_position(layout_position , tile.tile_position),
			tile.plant_on_tile.drop_item_id,
			DropableItem.get_amount_based_on_average(
				tile.plant_on_tile.average_drop,
				tile.plant_on_tile.drop_range.x,
				tile.plant_on_tile.drop_range.y
			), 
			true
		)
		
#endregion
