class_name Island
extends Node2D

@export var layout_position: Vector2i
@export var biome: Biome

enum Biome {
	MEADOW,
	FOREST,
	DESERT,
	SWAMP,
}

func _ready() -> void:
	pass

func _get_layout() -> void:
	return layout_position;

func _get_layout_v() -> void:
	pass