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


func _ready() -> void:
	## TODO: Load unlocked island state from save
	if cost == 0:
		unlocked = true
