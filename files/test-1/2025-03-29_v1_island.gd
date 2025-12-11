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

func _get_biome() -> void:
	print("not implemented yet")

func _get_rate() -> void:
	print("not implemented yet")

func _get_hp() -> void:
	print("not implemented yet")

func _get_growth() -> void:
	print("not implemented yet")

# TODO: check if biome matches
# check hp
# check growth
# check rate

func _get_layout() -> void:
	return layout_position;

func _get_layout_v() -> void:
	pass