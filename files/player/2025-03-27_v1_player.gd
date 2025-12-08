class_name Player
extends Node

func _ready() -> void:
	if not is_multiplayer_authority():
		$PlayerCamera2D.visible = false
