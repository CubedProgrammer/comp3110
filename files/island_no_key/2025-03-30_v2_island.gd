class_name Island
extends Node

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
	## TODO: Load unlocked island state from save
	
	tilemaps.visible = false
	hide_unlocking_ui()
	
	if not is_multiplayer_authority():
		return

	if cost == 0:
		_unlock.rpc_id(1)
	
	multiplayer.peer_connected.connect(_on_peer_connected)


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


func _on_peer_connected(id: int) -> void:
	if not is_multiplayer_authority():
		return

	if unlocked:
		_unlock.rpc_id(id)
