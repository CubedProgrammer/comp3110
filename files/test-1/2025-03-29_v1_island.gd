class_name Island
extends Node2D

enum Biome {
	MEADOW
}

## Position in the global map
## of the biomes
@export var layout_position: Vector2i
@export var biome: Biome

func _ready() -> void:
	pass
