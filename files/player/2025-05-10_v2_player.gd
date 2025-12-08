class_name Player
extends Node2D

const uuid_util = preload("res://addons/uuid/uuid.gd")

@onready var spawner: ObjectSpawner = $"/root/Game/ObjectRoot"
@onready var inventory: PlayerInventory = $Inventory
@onready var hotbar: NonsortedInventory = $Hotbar
@onready var state_manager: StateManager = $StateManager
var in_ui: bool

var interactable_objects_in_range: Array[InteractableObject]
var closest_object: InteractableObject

enum PlayerClickDirection { S, SE, E, NE, N, NW, W, SW }

func _ready() -> void:
	ObjectManager.world.players.append(self)

	$PlayerCamera2D.visible = is_multiplayer_authority()
	$PlayerCamera2D.priority = 5 if is_multiplayer_authority() else 0
	
	if not is_multiplayer_authority():
		return
	
	var config = ConfigFile.new()

	if config.load("user://machine_info.cfg") != OK:
		config.set_value("player", "player_uid", str(uuid_util.v4()))
		config.save("user://machine_info.cfg")
		config.load("user://machine_info.cfg")

	request_load_player_data.rpc_id(1, config.get_value("player", "player_uid"))

func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	if not in_ui:
		recalculate_closest_object()
	
	if Input.is_action_just_pressed("interact") and closest_object:
		%StateChart.send_event("ui_interact")
		
	#if Input.is_action_just_pressed("ui_left_click"):
		#%NotificationSystem.notify(
			#NotificationSystem.NotificationType.Basic,
			#"This is a basic notification",
			#ItemDb.get_item("hey_timur").icon
		#)
	#if Input.is_action_just_pressed("ui_right_click"):
		#%NotificationSystem.notify(
			#NotificationSystem.NotificationType.Important,
			#"This is an important notification",
			#ItemDb.get_item("hey_timur").icon
		#)

func _exit_tree() -> void:
	if ObjectManager.world:
		ObjectManager.world.players.erase(self)

func recalculate_closest_object():
	if closest_object and not interactable_objects_in_range.has(closest_object):
		closest_object.disable_highlight()
		closest_object = null
	
	if interactable_objects_in_range.is_empty():
		return
	
	for object in interactable_objects_in_range:
		if object and not object.area_2D:
			continue
			
		if global_position.distance_to(object.area_2D.global_position) < global_position.distance_to(closest_object.area_2D.global_position) if closest_object else true:
			if closest_object:
				closest_object.disable_highlight()
				
			closest_object = object
			closest_object.enable_highlight()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var config = ConfigFile.new()
		config.load("user://machine_info.cfg")

		save.rpc_id(
			1,
			config.get_value("player", "player_uid"),
			{
				"position_x": position.x,
				"position_y": position.y,
				"inventory": inventory.inventory.map(func(x: InventoryItem): return x.to_dict()),
				"hotbar":
				inventory.hotbar.inventory.map(func(x: InventoryItem): return x.to_dict()),
			}
		)
		get_tree().quit()

@rpc("any_peer", "call_local", "reliable")
func save(uid, player_data) -> void:
	if not multiplayer.is_server():
		return

	DirAccess.make_dir_recursive_absolute(
		"user://worlds/" + ObjectManager.current_world_uid + "/players/"
	)
	var save_file = FileAccess.open(
		"user://worlds/" + ObjectManager.current_world_uid + "/players/" + str(uid) + ".save",
		FileAccess.WRITE
	)

	var json_string = JSON.stringify(player_data)
	save_file.store_line(json_string)


@rpc("any_peer", "call_local", "reliable")
func request_load_player_data(uid) -> void:
	if not multiplayer.is_server():
		return

	if not FileAccess.file_exists(
		"user://worlds/" + ObjectManager.current_world_uid + "/players/" + str(uid) + ".save"
	):
		return  # We don't have a save to load.

	var save_file = FileAccess.open(
		"user://worlds/" + ObjectManager.current_world_uid + "/players/" + str(uid) + ".save",
		FileAccess.READ
	)

	var json_string = save_file.get_line()
	var json = JSON.new()

	# Check if there is any error while parsing the JSON string, skip in case of failure.
	var parse_result = json.parse(json_string)
	if not parse_result == OK:
		print(
			"JSON Parse Error: ",
			json.get_error_message(),
			" in ",
			json_string,
			" at line ",
			json.get_error_line()
		)

	load_player_data.rpc_id(multiplayer.get_remote_sender_id(), json.data)

@rpc("any_peer", "call_local", "reliable")
func load_player_data(save_data):
	if not is_multiplayer_authority():
		return

	position.x = save_data["position_x"]
	position.y = save_data["position_y"]

	var temp_inventory: Array[InventoryItem]
	for item in save_data["inventory"]:
		temp_inventory.append(InventoryItem.from_dict(item))

	inventory.override_inventory(temp_inventory)

	var temp_hotbar: Array[InventoryItem]
	for item in save_data["hotbar"]:
		temp_hotbar.append(InventoryItem.from_dict(item))

	inventory.hotbar.override_inventory(temp_hotbar)

## Utility function to get direction the player clicks in
## Note that it is divided into four/eight triangles
func get_click_direction(eight_ways: bool = true) -> PlayerClickDirection:
	var direction_vector := get_global_mouse_position() - global_position
	var angle_rad := direction_vector.angle()
	var angle_deg := rad_to_deg(angle_rad)
	
	angle_deg = fmod(angle_deg + 360, 360)
	
	if !eight_ways:
		if angle_deg >= 45 and angle_deg < 135:
			return PlayerClickDirection.S
		if angle_deg >= 135 and angle_deg < 225:
			return PlayerClickDirection.W
		if angle_deg >= 225 and angle_deg < 315:
			return PlayerClickDirection.N
		else:
			return PlayerClickDirection.E
			
	if angle_deg >= 22.5 and angle_deg < 67.5:
		return PlayerClickDirection.SE
	elif angle_deg >= 67.5 and angle_deg < 112.5:
		return PlayerClickDirection.S
	elif angle_deg >= 112.5 and angle_deg < 157.5:
		return PlayerClickDirection.SW
	elif angle_deg >= 157.5 and angle_deg < 202.5:
		return PlayerClickDirection.W
	elif angle_deg >= 202.5 and angle_deg < 247.5:
		return PlayerClickDirection.NW
	elif angle_deg >= 247.5 and angle_deg < 292.5:
		return PlayerClickDirection.N
	elif angle_deg >= 292.5 and angle_deg < 337.5:
		return PlayerClickDirection.NE
	else:
		return PlayerClickDirection.E
