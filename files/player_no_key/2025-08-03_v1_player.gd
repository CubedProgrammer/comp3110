class_name Player
extends Node2D

@onready var spawner: ObjectSpawner = $"/root/Game/ObjectRoot"
@onready var character_creation_window: CharacterCreation = $"/root/Game/CharacterCreation"
@onready var inventory: PlayerInventory = $Inventory
@onready var hotbar: NonsortedInventory = $Hotbar
@onready var state_manager: StateManager = $StateManager
@onready var anmimated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var name_label: Label = $Name
@onready var fps_label: Label = $PlayerUI/HUD/fps
@onready var energy_bar: TextureProgressBar = $PlayerUI/HUD/Stats/EnergyBar
@onready var health_bar: TextureProgressBar = $PlayerUI/HUD/Stats/HealthBar
@onready var feet_point: Node2D = $FeetPoint
@onready var light: PointLight2D = $Light
@onready var player_ui_parent: CanvasLayer = $PlayerUI
@onready var player_camera_2d: PhantomCamera2D = $PlayerCamera2D

var player_data: PlayerData = PlayerData.new()

var interacting: bool

var interactable_objects_in_range: Array[InteractableObject]
var closest_object: InteractableObject

enum PlayerClickDirection { S, SE, E, NE, N, NW, W, SW }


func _ready() -> void:
	disable_player()
	ObjectManager.world.players.append(self)

	player_camera_2d.visible = is_multiplayer_authority()
	player_camera_2d.priority = 5 if is_multiplayer_authority() else 0
	# Things everyone needs changed when they change
	player_data.name_changed.connect(func(value): name_label.text = value)
	player_data.sprite_frames_changed.connect(func(value): anmimated_sprite.sprite_frames = load(value) if value.length() > 0 else null)
	
	if not is_multiplayer_authority():
		request_enable_player.rpc()
		return
	
	var config = ConfigFile.new()
	
	name_label.text = player_data.player_name
	health_bar.max_value = player_data.max_health
	energy_bar.max_value = player_data.max_energy
	health_bar.value = player_data.health
	energy_bar.value = player_data.energy
	anmimated_sprite.sprite_frames = load(player_data.sprite_frames) if player_data.sprite_frames.length() > 0 else null
	
	player_data.max_health_changed.connect(func(value): health_bar.max_value = value)
	player_data.max_energy_changed.connect(func(value): energy_bar.max_value = value)
	player_data.health_changed.connect(_on_stat_changed.bind(health_bar))
	player_data.energy_changed.connect(_on_stat_changed.bind(energy_bar))
	
	if not multiplayer.is_server():
		request_load_player_data.rpc_id(1, PlayerNetInfo.my_player_info.steam_id)
	else:
		request_load_player_data(PlayerNetInfo.my_player_info.steam_id)


func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	fps_label.text = str(Engine.get_frames_per_second())
	
	if not interacting:
		recalculate_closest_object()
	
	if Input.is_action_just_pressed("interact") and closest_object:
		if closest_object.type == InteractableObject.Type.Harvest:
			%StateChart.send_event("harvest")
		elif closest_object.type == InteractableObject.Type.UI:
			%StateChart.send_event("ui_interact")
		else:
			closest_object.interact()


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
		if object and not object.interaction_area:
			continue
			
		if global_position.distance_to(object.interaction_area.global_position) < global_position.distance_to(closest_object.interaction_area.global_position) if closest_object else true:
			if closest_object:
				closest_object.disable_highlight()
				
			closest_object = object
			closest_object.enable_highlight()


func _on_stat_changed(val: float, bar: TextureProgressBar) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(bar, "value", val, 0.2)


@rpc("any_peer", "call_local", "reliable")
func load_player_data(save_data: Dictionary) -> void:
	if not is_multiplayer_authority():
		return
	
	player_data.target_player = self
	player_data.from_dict(save_data)
	
	position = player_data.position
	
	inventory.override_inventory(player_data.inventory)
	
	while player_data.hotbar.size() < inventory.hotbar.max_inventory_length:
		player_data.hotbar.append(InventoryItem.new("filler", -1))
	inventory.hotbar.override_inventory(player_data.hotbar)

	($"/root/Game/PuzzleManager" as PuzzleManager).add_or_remove_player_to_puzzle(self, player_data.current_puzzle, false)
	
	character_creation_window.disable_all()
	enable_player.rpc()


@rpc("any_peer", "call_local", "reliable")
func save(steam_id: int, data_to_save: Dictionary, save_type: SaveType) -> void:
	if not multiplayer.is_server():
		return

	if steam_id == PlayerNetInfo.my_player_info.steam_id:
		ObjectManager.save_game()

	DirAccess.make_dir_recursive_absolute(
		"user://worlds/" + ObjectManager.current_world_info.world_id + "/players/"
	)
	var save_file = FileAccess.open(
		"user://worlds/" + ObjectManager.current_world_info.world_id + "/players/" + str(steam_id) + ".save",
		FileAccess.WRITE
	)

	var json_string = JSON.stringify(data_to_save)
	save_file.store_line(json_string)

	match save_type:
		SaveType.Save:
			pass
		SaveType.ToMainMenu:
			_leave_world.rpc_id(multiplayer.get_remote_sender_id())
		SaveType.ExitGame:
			_exit_game.rpc_id(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_local", "reliable")
func _leave_world():
	ObjectManager.world = null
	PlayerNetInfo.leave_world()


@rpc("any_peer", "call_local", "reliable")
func _exit_game() -> void:
	get_tree().quit()


@rpc("any_peer", "call_local", "reliable")
func request_load_player_data(uid) -> void:
	if not multiplayer.is_server():
		return

	if not FileAccess.file_exists(
		"user://worlds/" + ObjectManager.current_world_info.world_id + "/players/" + str(uid) + ".save"
	):
		var sender_id := multiplayer.get_remote_sender_id()
		if sender_id != 0:
			init_player_creation.rpc_id(multiplayer.get_remote_sender_id())
		else:
			init_player_creation()
		return

	var save_file = FileAccess.open(
		"user://worlds/" + ObjectManager.current_world_info.world_id + "/players/" + str(uid) + ".save",
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
	
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != 0:
		load_player_data.rpc_id(multiplayer.get_remote_sender_id(), json.data)
	else:
		load_player_data(json.data)


@rpc("any_peer", "call_local", "reliable")
func init_player_creation():
	if not is_multiplayer_authority():
		return
	
	character_creation_window.open_window(self)


## Utility function to get direction the player clicks in
## Note that it is divided into four/eight triangles
func get_click_direction(eight_ways: bool = true) -> PlayerClickDirection:
	var direction_vector: Vector2 = get_global_mouse_position() - $DirectionPoint.global_position
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


@rpc("authority", "call_local", "reliable")
func disable_player() -> void:
	visible = false
	state_manager.input_disabled = true


@rpc("authority", "call_local", "reliable")
func enable_player() -> void:
	if not is_multiplayer_authority():
		request_enable_player.rpc()
		return
		
	visible = true
	state_manager.input_disabled = false
	state_manager.play_animation.rpc("idle")


@rpc("any_peer", "call_local", "reliable")
func load_other_info(info: Dictionary) -> void:
	if is_multiplayer_authority():
		return
		
	player_data.player_name = info["name"]
	player_data.sprite_frames = info["sprite_frames"] 
	visible = true
	state_manager.input_disabled = true


@rpc("any_peer", "call_local", "reliable")
func request_enable_player():
	# Player not made yet
	if not is_multiplayer_authority() or not visible:
		return
		
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != 0:
		load_other_info.rpc_id(multiplayer.get_remote_sender_id(), {
			"name": player_data.player_name,
			"sprite_frames": ($AnimatedSprite2D as AnimatedSprite2D).sprite_frames.resource_path
		})
	else:
		load_other_info({
			"name": player_data.player_name,
			"sprite_frames": ($AnimatedSprite2D as AnimatedSprite2D).sprite_frames.resource_path
		})


@rpc("authority", "call_local", "reliable")
func set_animation_speed(speed: float) -> void:
	$AnimatedSprite2D.speed_scale = speed
	$ToolAnimatedSprite.speed_scale = speed


enum SaveType {
	Save,
	ToMainMenu,
	ExitGame
}
