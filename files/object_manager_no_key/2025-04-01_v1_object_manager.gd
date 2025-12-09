extends Node

var current_world : String
var objects_to_save: Array

func _ready() -> void:
	set_multiplayer_authority(1)
	# load in all our saved data
	pass

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
		_on_quit()
		get_tree().quit()

func _on_quit() -> void:
	if not is_multiplayer_authority():
		return
	
	DirAccess.make_dir_recursive_absolute("user://worlds/"+ current_world +"/")
	var save_file = FileAccess.open(
		"user://worlds/"+ current_world +"/savegame.save", 
		FileAccess.WRITE
	)
	
	for object in objects_to_save:
		if object.scene_file_path.is_empty():
			print("object '%s' is not an instanced scene, skipped" % object.name)
			continue

		if !object.has_method("save"):
			print("object '%s' is missing a save() function, skipped" % object.name)
			continue

		var object_data = object.call("save")
		var json_string = JSON.stringify(object_data)
		save_file.store_line(json_string)

func load_data():
	if not is_multiplayer_authority():
		return
		
	if not FileAccess.file_exists("user://worlds/"+ current_world +"/savegame.save"):
		return # We don't have a save to load.

	var save_file = FileAccess.open(
		"user://worlds/"+ current_world +"/savegame.save", 
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

		# Get the data from the JSON object.
		var node_data = json.data
		var new_object
		if node_data["instantiate"]:
			new_object = load(node_data["filename"]).instantiate()
			get_node(node_data["parent"]).add_child(new_object)
		else:
			new_object = get_node(node_data["path"])
			
		new_object.load(node_data)
