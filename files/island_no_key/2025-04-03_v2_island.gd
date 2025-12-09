class_name Island
extends Node

@export_category("Basic island info")
## The Biome this this island is in
@export var biome: Biome

## The position of this island in the islands layout map
@export var layout_position: Vector2i = Vector2i.ZERO

## How much this island costs
@export var cost: int

## Tracks if this island is unlocked
var unlocked: bool

## The status of all this islands tiles
var tile_states: Dictionary = {}
var groundTileMap: TileMapLayer
var dirtLayer: TileMapLayer
var dataLayer: TileMapLayer

@onready var tilemaps: Node2D = $Tilemaps
@onready var buying_ui: Control = $BuyingUI


func _ready() -> void:
	ObjectManager.add_object_to_save(self)

	tilemaps.visible = false
	hide_unlocking_ui()
	
	if not is_multiplayer_authority():
		return

	if cost == 0:
		_unlock.rpc_id(1)
	
	if tile_states.is_empty():
		_initialize_tile_states()
	
	multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(id: int) -> void:
	if not is_multiplayer_authority():
		return
		
	_sync_tile_data_request()
	if unlocked:
		_unlock.rpc_id(id)

#region Unlocking logic
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
func update_single_tile_data(tile_location: Vector2i, tile_data: Dictionary):
	tile_states[tile_location] = tile_data
	update_game_tile(tile_location)

func update_game_tiles():
	for tile_position in tile_states.keys():
		update_game_tile(tile_position)

func can_tile_on_tileset_be_tilled(tile_to_till: Vector2i) -> bool:
	var custom_data = dataLayer.get_cell_tile_data(tile_to_till)
	if custom_data:
		var is_tile_tillable_on_tilemap = custom_data.get_custom_data("is_tillable")
		if(is_tile_tillable_on_tilemap == false):
			return false
	return true
	
func can_tile_on_tileset_be_watered(tile_to_till: Vector2i) -> bool:
	var custom_data = dirtLayer.get_cell_tile_data(tile_to_till)
	if custom_data:
		var is_tile_tillable_on_tilemap = custom_data.get_custom_data("is_tilled")
		if(is_tile_tillable_on_tilemap == false):
			print("not tilled")
			return false
	return true
	
func does_island_tile_state_have_tile(tile_to_till: Vector2i):
	if !tile_states.has(tile_to_till):
		return false
	return true
	
func can_tile_be_tilled(tile_to_till: Vector2i) -> bool:
	if !does_island_tile_state_have_tile(tile_to_till) || !can_tile_on_tileset_be_tilled(tile_to_till) || !tile_states[tile_to_till].state == 0:
		return false
	return true
	
func can_tile_be_watered(tile_to_till: Vector2i) -> bool:
	if !does_island_tile_state_have_tile(tile_to_till) || !can_tile_on_tileset_be_watered(tile_to_till) || tile_states[tile_to_till].state != 1:
		return false
	return true
	
func update_game_tile(tile_position: Vector2i):
	var tile_data = tile_states[tile_position]  
	var new_state = tile_data.state       
	match new_state:
		0:
			dirtLayer.set_cell(tile_position, -1)
		1:
			print("at 2 ΓÇö trying to till dirt at: ", tile_position)
			dirtLayer.set_cell(tile_position, 2, Vector2i(10, 1))
			
		2:
			print("at 1 ΓÇö trying to water tile: ", tile_position)
			dirtLayer.set_cell(tile_position, 2, Vector2i(10, 4))
		_:
			print("at default")

func _initialize_tile_states(tile_data = null):
	if tile_data != null:
		tile_states = tile_data
		return
		
	_initialize_tilemap_variables()
	for cell in groundTileMap.get_used_cells():
		tile_states[Vector2i(cell.x,cell.y)] = {"state": TileState.Default }
		

func _initialize_tilemap_variables():
	for tilemap in tilemaps.get_children():
		if tilemap.name == "GroundLayer":
			groundTileMap = tilemap
		elif tilemap.name == "DirtLayer":
			dirtLayer = tilemap
		elif tilemap.name == "DataLayer":
			dataLayer = tilemap
#endregion

#region save/load
func save() -> Dictionary:
	return {
		"instantiate" : false,
		"path" : get_path(),
		"unlocked" : unlocked,
		"tile_states" : tile_states_to_dict()
	}
	
func load(save_data):
	if not save_data["unlocked"]:
		return
		
	tile_states.clear()
	for tile in save_data["tile_states"]:
		tile_states[Vector2i(
			save_data["tile_states"][tile].x,
			save_data["tile_states"][tile].y)
		] = save_data["tile_states"][tile].value	
	
	update_game_tiles()
	_unlock()
#endregion

#region to/from dict
func tile_states_to_dict() -> Dictionary:
	var states = {}
	for tile_data in tile_states:
		states[tile_data] = {
			"value": tile_states[tile_data],
			"x": tile_data.x,
			"y": tile_data.y
		}	
		
	return states
#endregion

#region Enums
enum TileState {
	Default,
	Tilled,
	Watered,
}

enum Biome {
	Meadow,
	Forest,
	FrozenOcean,
	Lavalands,
	BrokenSteamship,
	ClockWork,
	Desert,
	Tundra,
	Woodlands
}
#endregion
