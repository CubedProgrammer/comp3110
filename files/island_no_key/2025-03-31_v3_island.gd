class_name Island
extends Node

enum TileState {
	Default,
	Watered,
	Tilled
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

var tile_state: Dictionary = {}

## The Biome this this island is in
@export var biome: Biome

## The position of this island in the islands layout map
@export var layout_position: Vector2i = Vector2i.ZERO

## How much this island costs
@export var cost: int

var unlocked: bool

@onready var tilemaps: Node2D = $Tilemaps
@onready var buying_ui: Control = $BuyingUI


func _ready() -> void:
	_initialize_tile_data_request()
	## TODO: Load unlocked island state from save
	tilemaps.visible = false
	hide_unlocking_ui()
	
	if not is_multiplayer_authority():
		return

	if cost == 0:
		_unlock.rpc_id(1)
	
	_initialize_tile_states()
	multiplayer.peer_connected.connect(_on_peer_connected)


func _initialize_tile_states():
	tile_state.clear()
	var counter = 0
	var groundTileMap = tilemaps.get_child(0)
	for cell in groundTileMap.get_used_cells():
		tile_state[Vector2i(cell.x,cell.y)] = {"state": TileState.Default }

func show_unlocking_ui() -> void:
	buying_ui.visible = true


func hide_unlocking_ui() -> void:
	buying_ui.visible = false


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

		

@rpc("any_peer","call_local","reliable")
func _initialize_tile_data_request():
	if not multiplayer.is_server():
		return
	_initialize_tile_data.rpc_id(multiplayer.get_remote_sender_id(),tile_state)
	
@rpc("authority","call_local","reliable")
func _initialize_tile_data(tile_data: Dictionary):
	tile_state = tile_data
	
@rpc("any_peer","call_remote","reliable")
func _update_single_tile_data(tile_data: Dictionary , tile_location: Vector2i ):
	tile_state[tile_location] = tile_data

func _on_peer_connected(id: int) -> void:
	if not is_multiplayer_authority():
		return

	if unlocked:
		_unlock.rpc_id(id)
