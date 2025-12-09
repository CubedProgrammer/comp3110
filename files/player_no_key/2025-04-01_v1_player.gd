class_name Player
extends Node2D

const uuid_util = preload('res://addons/uuid/uuid.gd')

@onready var spawner: ObjectSpawner = $"/root/Game/ObjectRoot"
@onready var inventory: Inventory = $Inventory

func _ready() -> void:
	var config = ConfigFile.new()
	
	if config.load("user://machine_info.cfg") != OK:
		config.set_value("player", "player_uid", str(uuid_util.v4()))
		config.save("user://machine_info.cfg")
		config.load("user://machine_info.cfg")
		
	request_load_player_data.rpc_id(1, config.get_value("player", "player_uid"))
	$PlayerCamera2D.visible = is_multiplayer_authority()
	$PlayerCamera2D.priority = 5 if is_multiplayer_authority() else 0
	ObjectManager.load_data()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var config = ConfigFile.new()
		config.load("user://machine_info.cfg")
			
		save.rpc_id(
			1,
			config.get_value("player", "player_uid"),
			{
				"position_x" : position.x,
				"position_y" : position.y,
				"inventory" : inventory.inventory.map(func(x: InventoryItem): return x.to_dict())
			}
		)
		get_tree().quit()

@rpc("any_peer", "call_local", "reliable")
func save(uid, player_data) -> void:
	if not multiplayer.is_server():
		return
	
	DirAccess.make_dir_recursive_absolute("user://worlds/" + ObjectManager.current_world + "/players/")
	var save_file = FileAccess.open(
		"user://worlds/" + ObjectManager.current_world + "/players/" + str(uid) + ".save", 
		FileAccess.WRITE
	)
	
	var json_string = JSON.stringify(player_data)
	save_file.store_line(json_string)

@rpc("any_peer", "call_local", "reliable")
func request_load_player_data(uid) -> void:
	if not multiplayer.is_server():
		return
		
	if not FileAccess.file_exists("user://worlds/" + ObjectManager.current_world + "/players/" + str(uid) + ".save"):
		return # We don't have a save to load.

	var save_file = FileAccess.open(
		"user://worlds/" + ObjectManager.current_world + "/players/" + str(uid) + ".save", 
		FileAccess.READ
	)
	
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()
		var json = JSON.new()

		# Check if there is any error while parsing the JSON string, skip in case of failure.
		var parse_result = json.parse(json_string)
		if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			continue

		load_player_data.rpc_id(multiplayer.get_remote_sender_id(), json.data)

@rpc("authority", "call_local", "reliable")
func load_player_data(save_data):
	if not is_multiplayer_authority():
		return
			
	position.x = save_data["position_x"]
	position.y = save_data["position_y"]
	
	var temp_inventory: Array[InventoryItem]
	for item in save_data["inventory"]:
		temp_inventory.append(InventoryItem.from_dict(item))
	
	inventory.override_inventory(temp_inventory)
