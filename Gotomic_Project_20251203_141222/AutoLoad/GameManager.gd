extends Node

# This script is an Autoload and thus does NOT have a class_name declaration (Rule F24).

signal player_health_changed(new_health: int)
signal player_died()
signal weapon_switched(weapon_name: String, current_ammo: int, total_ammo: int)
signal ammo_changed(current_ammo_in_mag: int, total_reserve_ammo: int)
signal game_paused(paused: bool)
signal flashlight_energy_changed(current_energy: float, max_energy: float)
signal player_interact_prompt(visible: bool, message: String)

const SAVE_FILE_PATH: String = "user://game_save.cfg"
const SETTINGS_FILE_PATH: String = "user://game_settings.cfg"

var player_node: CharacterBody3D
var hud_node: Control
var current_weapon_node: Node
var current_level_node: Node3D

var game_state: int = 0 # 0: MainMenu, 1: Playing, 2: Paused, 3: Loading, 4: GameOver
var game_difficulty: int = 1 # 0: Easy, 1: Normal, 2: Hard

var mouse_sensitivity: float = 0.5
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0

var is_game_paused: bool = false:
	set(value):
		if is_game_paused == value:
			return
		is_game_paused = value
		get_tree().paused = value
		game_paused.emit(value)
		print("Game paused: ", value)

func _ready() -> void:
	print("GameManager _ready: Initializing...")
	load_settings()
	apply_volume_settings()
	process_mode = Node.PROCESS_MODE_ALWAYS # Ensure GameManager always runs

func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SETTINGS_FILE_PATH)
	if err == OK:
		mouse_sensitivity = config.get_value("settings", "mouse_sensitivity", mouse_sensitivity)
		master_volume = config.get_value("settings", "master_volume", master_volume)
		sfx_volume = config.get_value("settings", "sfx_volume", sfx_volume)
		music_volume = config.get_value("settings", "music_volume", music_volume)
		game_difficulty = config.get_value("settings", "difficulty", game_difficulty)
		print("Settings loaded successfully.")
	else:
		print("No settings file found or failed to load, using defaults.")
		save_settings() # Create default settings file

func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("settings", "master_volume", master_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "difficulty", game_difficulty)
	var err: Error = config.save(SETTINGS_FILE_PATH)
	if err != OK:
		push_error("Failed to save settings: ", err)
	else:
		print("Settings saved successfully.")

func apply_volume_settings() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))

func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	apply_volume_settings()
	save_settings()

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	apply_volume_settings()
	save_settings()

func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	apply_volume_settings()
	save_settings()

func set_mouse_sensitivity(sensitivity: float) -> void:
	mouse_sensitivity = clampf(sensitivity, 0.1, 2.0)
	save_settings()

func start_new_game() -> void:
	print("Starting new game...")
	game_state = 3 # Loading
	get_tree().change_scene_to_file("res://UI/LoadingScreen/LoadingScreen.tscn")

func load_game_world() -> void:
	# This function is called by the loading screen after a delay
	print("Loading GameWorld...")
	get_tree().change_scene_to_file("res://Scenes/GameWorld.tscn")
	game_state = 1 # Playing

func return_to_main_menu() -> void:
	print("Returning to Main Menu...")
	is_game_paused = false # Unpause if returning from pause menu
	get_tree().change_scene_to_file("res://UI/MainMenu/MainMenu.tscn")
	game_state = 0 # MainMenu

func quit_game() -> void:
	print("Quitting game...")
	get_tree().quit()

func save_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	if is_instance_valid(player_node):
		config.set_value("player", "position_x", player_node.global_transform.origin.x)
		config.set_value("player", "position_y", player_node.global_transform.origin.y)
		config.set_value("player", "position_z", player_node.global_transform.origin.z)
		config.set_value("player", "health", player_node.player_health)
		config.set_value("player", "flashlight_energy", player_node.flashlight_energy)
		config.set_value("player", "current_weapon_index", player_node.current_weapon_index)

	if is_instance_valid(current_weapon_node) and current_weapon_node is Weapon:
		var weapon: Weapon = current_weapon_node as Weapon
		config.set_value("weapon", "name", weapon.weapon_name)
		config.set_value("weapon", "current_ammo_in_mag", weapon.current_ammo_in_mag)
		config.set_value("weapon", "total_reserve_ammo", weapon.total_reserve_ammo)

	config.set_value("game", "current_scene", get_tree().current_scene.scene_file_path)
	config.set_value("game", "game_version", "1.0")
	var err: Error = config.save(SAVE_FILE_PATH)
	if err != OK:
		push_error("Failed to save game: ", err)
	else:
		print("Game saved successfully.")

func load_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(SAVE_FILE_PATH)
	if err != OK:
		push_error("Failed to load game: ", err)
		return

	var current_scene_path: String = config.get_value("game", "current_scene", "res://Scenes/GameWorld.tscn")
	get_tree().change_scene_to_file(current_scene_path)
	await get_tree().changed
	
	# After scene loaded, apply saved data
	if is_instance_valid(player_node):
		var pos_x: float = config.get_value("player", "position_x", player_node.global_transform.origin.x)
		var pos_y: float = config.get_value("player", "position_y", player_node.global_transform.origin.y)
		var pos_z: float = config.get_value("player", "position_z", player_node.global_transform.origin.z)
		player_node.global_transform.origin = Vector3(pos_x, pos_y, pos_z)
		player_node.player_health = config.get_value("player", "health", player_node.player_health)
		player_node.flashlight_energy = config.get_value("player", "flashlight_energy", player_node.flashlight_energy)
		player_node.current_weapon_index = config.get_value("player", "current_weapon_index", player_node.current_weapon_index)
		player_node.update_hud() # Force HUD update after load

	if is_instance_valid(current_weapon_node) and current_weapon_node is Weapon:
		var weapon: Weapon = current_weapon_node as Weapon
		weapon.current_ammo_in_mag = config.get_value("weapon", "current_ammo_in_mag", weapon.current_ammo_in_mag)
		weapon.total_reserve_ammo = config.get_value("weapon", "total_reserve_ammo", weapon.total_reserve_ammo)
		weapon_switched.emit(weapon.weapon_name, weapon.current_ammo_in_mag, weapon.total_reserve_ammo) # Force HUD update

	print("Game loaded successfully.")
	game_state = 1 # Playing

func reset_save() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir and dir.file_exists("game_save.cfg"):
		dir.remove("game_save.cfg")
		print("Save file reset.")
	else:
		print("No save file to reset.")

func get_difficulty_multiplier() -> float:
	match game_difficulty:
		0: return 0.75 # Easy
		1: return 1.0  # Normal
		2: return 1.5  # Hard
		_ : return 1.0

func register_player(player: CharacterBody3D) -> void:
	player_node = player
	if player_node:
		player_node.player_health_changed.connect(player_health_changed)
		player_node.player_died_signal.connect(player_died)
		player_node.weapon_switched.connect(weapon_switched)
		player_node.flashlight_energy_changed.connect(flashlight_energy_changed)
		player_node.player_interact_prompt.connect(player_interact_prompt)
		print("Player registered with GameManager.")

func register_hud(hud: Control) -> void:
	hud_node = hud
	print("HUD registered with GameManager.")

func register_current_weapon(weapon: Node) -> void:
	if is_instance_valid(current_weapon_node) and current_weapon_node != weapon:
		if current_weapon_node.is_connected("ammo_changed", Callable(self, "ammo_changed")):
			current_weapon_node.disconnect("ammo_changed", Callable(self, "ammo_changed"))
	current_weapon_node = weapon
	if current_weapon_node and current_weapon_node is Weapon:
		current_weapon_node.ammo_changed.connect(ammo_changed)
		weapon_switched.emit(current_weapon_node.weapon_name, current_weapon_node.current_ammo_in_mag, current_weapon_node.total_reserve_ammo)
	print("Current weapon registered with GameManager.")

func register_level(level: Node3D) -> void:
	current_level_node = level
	print("Level registered with GameManager.")