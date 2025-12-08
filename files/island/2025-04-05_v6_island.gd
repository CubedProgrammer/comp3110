class_name Island
extends Node

@export_category("Basic island info")
## The Biome this this island is in
@export var biome: Resource

#array of tiles that have their timers ticking
var needs_updating_tile_array: Array[Tile]

## The position of this island in the islands layout map
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
@onready var tilemaps: Node2D = $Tilemaps
@onready var buying_ui: Control = $BuyingUI

func _process(delta: float) -> void:
	#loop through all active tiles and if the timer runs out them update them
	for tile in needs_updating_tile_array:
		if tile.get_tile_timer() <= 0:
			update_tile(tile)
			update_single_tile_data.rpc(tile.get_tile_position(), tile)
		tile.decrement_tile_timer(delta)
			
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
	#if a client joins , request to sync tile data
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
@rpc("any_peer","call_local","reliable")
func _sync_tile_data_request():
	if not multiplayer.is_server():
		return
	_sync_tile_data.rpc_id(multiplayer.get_remote_sender_id(),tile_states)
	
@rpc("authority","call_local","reliable")
func _sync_tile_data(tile_data: Dictionary):
	tile_states = tile_data
	update_game_tiles()
	
@rpc("any_peer","call_local","reliable")
func update_single_tile_data(tile_location: Vector2i, tile_data: Tile):
	tile_states[tile_location] = tile_data
	update_game_tile(tile_location)

func update_game_tiles():
	for tile_position in tile_states.keys():
		update_game_tile(tile_position)
	
func update_game_tile(tile_position: Vector2i):
	var tile_to_update = tile_states[tile_position] 
	var new_state = tile_to_update.get_tile_state()
	match new_state:
		TileManager.TileState.Default:
			dirt_layer.set_cell(tile_position, -1)
			
		TileManager.TileState.Tilled:
			dirt_layer.set_cell(tile_position, 2, Vector2i(12, 0))

		TileManager.TileState.Watered:
			dirt_layer.set_cell(tile_position, 2, Vector2i(13, 0))
		_:
			pass
			
			
func _initialize_tile_states(tile_data = null):
	if tile_data != null:
		tile_states = tile_data
		return

	for cell in ground_layer.get_used_cells():
		tile_states[Vector2i(cell.x,cell.y)] = Tile.new(TileManager.TileState.Default , Vector2i(cell.x,cell.y))
		
#endregion

#region save/load
func save() -> Dictionary:
	return {
		"instantiate" : false,
		"path" : get_path(),
		"unlocked" : unlocked,
		"tile_states" : copy_tile_states_dict(),
	}
	
func load(save_data):
	if not save_data["unlocked"]:
		return
		
	var loaded_tile_data
	var loaded_tile: Tile
	tile_states.clear()
	
	for tile in save_data["tile_states"]:
		loaded_tile_data = save_data["tile_states"][tile]
		loaded_tile = Tile.from_dict(loaded_tile_data)
		
		if(loaded_tile.get_tile_timer_() > 0):
			add_active_tile_to_active_array(loaded_tile)
			
		tile_states[Vector2i(
			loaded_tile_data.position_x,
			loaded_tile_data.position_y)
		] = loaded_tile
		
	update_game_tiles()
	_unlock()
	
func copy_tile_states_dict():
	var states = {}
	for tile in tile_states:
		states[tile] = tile_states[tile].to_dict()
	return states
	
#endregion

#region Tile Interaction Functions
func update_tile(tile: Tile) -> void:
	var tile_state = tile.get_tile_state()
	match tile_state:
		
		TileManager.TileState.Default:
			pass
			
		TileManager.TileState.Tilled:
			tile.set_tile_state(TileManager.TileState.Default)
			tile.reset_tile_timer()
			remove_active_tile_from_active_array(tile)
	
		TileManager.TileState.Watered:
			tile.set_tile_state(TileManager.TileState.Tilled)
			tile.set_tile_timer(biome.dirt_timeout_value)

		_:
			pass
func get_island_tile_from_vector(tile_vector: Vector2i) -> Tile:
	if tile_states.has(tile_vector):
		return tile_states[tile_vector]
	return null
	
func does_island_tile_state_have_tile(tile_to_till: Vector2i) -> bool:
	if !tile_states.has(tile_to_till):
		return false
	return true
	
#region Watered
func can_tile_on_tileset_be_watered(tile_to_till: Vector2i) -> bool:
	return tile_states[tile_to_till].get_tile_state() == TileManager.TileState.Tilled
	
func can_tile_be_watered(tile_to_till: Vector2i) -> bool:
	return does_island_tile_state_have_tile(tile_to_till) and can_tile_on_tileset_be_watered(tile_to_till)
	
#endregion

#region Tilled
func can_tile_on_tileset_be_tilled(tile_to_till: Vector2i) -> bool:
	if tile_states[tile_to_till].get_tile_state() != 0:
		return false
		
	var custom_data = data_layer.get_cell_tile_data(tile_to_till)
	if custom_data:
		return custom_data.get_custom_data("is_tillable")
	
	return true
	
func can_tile_be_tilled(tile_to_till: Vector2i) -> bool:
	return does_island_tile_state_have_tile(tile_to_till) and can_tile_on_tileset_be_tilled(tile_to_till)
	
func add_active_tile_to_active_array(tile):
	if tile not in needs_updating_tile_array:
		needs_updating_tile_array.append(tile)
			
func remove_active_tile_from_active_array(tile):
	if tile in needs_updating_tile_array:
		needs_updating_tile_array.erase(tile)
		
#endregion

#endregion
