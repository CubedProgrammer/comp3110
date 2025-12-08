extends Node


var current_world_info: WorldInfo
var objects_to_save: Array
var object_data_manager: ObjectDataManager
var world: World:
	set(value):
		world = value

		if value:
			value.world_info = current_world_info

class WorldInfo:
	var world_id: String
	var world_name: String
	var icon: WorldSelectPlanet.Planet
	var time_played: int
	var calories_served: int
	var last_played: String
	
	func _init(id: String, new_world_name: String, new_icon: WorldSelectPlanet.Planet, tp: int, cs: int, world_last_played: String) -> void:
		world_id = id
		world_name = new_world_name
		icon = new_icon
		time_played = tp
		calories_served = cs
		last_played = world_last_played
		
	func to_dict() -> Dictionary:
		return {
			"world_id": world_id,
			"world_name": world_name,
			"icon": icon,
			"time_played": time_played,
			"calories_served": calories_served,
			"last_played": last_played
		}

	static func from_dict(info: Dictionary) -> WorldInfo:
		return WorldInfo.new(
			info.world_id,
			info.world_name,
			info.icon,
			info.time_played,
			info.calories_served,
			info.last_played
		)

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	set_multiplayer_authority(1)

func add_object_to_save(data_manager) -> void:
	if not is_multiplayer_authority():
		return

	if not objects_to_save.has(data_manager):
		objects_to_save.append(data_manager)


func remove_object_to_save(data_manager) -> void:
	if not is_multiplayer_authority():
		return

	if objects_to_save.has(data_manager):
		objects_to_save.erase(data_manager)


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_quit(true)


func _on_quit(exit_tree: bool = false) -> void:
	#TODO also run this when exiting to main menu
	if not ObjectManager.world or not multiplayer.is_server():
		return

	DirAccess.make_dir_recursive_absolute("user://worlds/" + current_world_info.world_id + "/")
	var save_file = FileAccess.open(
		"user://worlds/" + current_world_info.world_id + "/savegame.save", FileAccess.WRITE
	)

	for object in objects_to_save:
		if not object:
			continue
			
		var object_data = object.call("save")
		if object.scene_file_path.is_empty() and object_data.instantiate:
			print("object '%s' is not an instanced scene, skipped" % object.name)
			continue

		if !object.has_method("save"):
			print("object '%s' is missing a save() function, skipped" % object.name)
			continue

		var json_string = JSON.stringify(object_data)
		save_file.store_line(json_string)
	
	save_file.close()

	var current_worlds = get_current_worlds()

	# Append new world info
	world.world_info.last_played = Time.get_datetime_string_from_system(true)
	current_worlds[current_world_info.world_id] = world.world_info

	save_worlds(current_worlds)
	reset_world.bind(exit_tree).call_deferred()


func reset_world(exit_tree: bool):
	world = null
	
	if exit_tree:
		get_tree().quit()


func load_data():
	if not multiplayer.is_server():
		return

	if not FileAccess.file_exists("user://worlds/" + current_world_info.world_id + "/savegame.save"):
		return  # We don't have a save to load.

	var save_file = FileAccess.open(
		"user://worlds/" + current_world_info.world_id + "/savegame.save", FileAccess.READ
	)

	while save_file.get_position() < save_file.get_length():
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
			continue

		# Get the data from the JSON object.
		var node_data = json.data
		
		var new_object
		if node_data["instantiate"]:
			new_object = load(node_data["filename"]).instantiate()
			get_node(node_data["parent"]).add_child(new_object, true)
		else:
			new_object = get_node(node_data["path"])

		new_object.load(node_data)
		
		#if node_data["instantiate"]:
			#ObjectManager.object_data_manager.register_object(node_data , false)
		#else:
			#get_node(node_data["path"]).load(node_data)


func create_world(world_id: String) -> void:
	current_world_info = get_planet_info(world_id)
	PlayerNetInfo.create_world.emit()

func get_current_worlds() -> Dictionary[String, WorldInfo]:
	var save_file = FileAccess.open("user://worlds.save", FileAccess.READ)
	var world_saves: Dictionary[String, WorldInfo]
	
	if not save_file:
		return {}

	while save_file != null and save_file.get_position() < save_file.get_length():
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
			continue

		var data = json.get_data()
		world_saves[data["world_id"]] = WorldInfo.from_dict(data)
	
	save_file.close()
	return world_saves

func save_worlds(worlds: Dictionary[String, WorldInfo]) -> void:
	var save_file = FileAccess.open("user://worlds.save", FileAccess.WRITE)

	for world in worlds:
		var json_string = JSON.stringify(worlds[world].to_dict())
		save_file.store_line(json_string)

	save_file.close()
	
func get_planet_info(id: String) -> WorldInfo:
	return get_current_worlds()[id]
