extends Node

## GameManager
## Autoload singleton for global game state, settings, save/load, and event management.
## Adheres to ALMIGHTY-1000 Protocol rules 47, 78, 111, 112, 138, 145, 297, 380, 418, 541-580, 671-700.

# Signals (Rule F25)
signal player_health_changed(new_health: int)
signal player_died
signal weapon_switched(weapon_name: String, current_ammo: int, max_ammo: int)
signal weapon_ammo_changed(current_ammo: int, max_ammo: int)
signal game_paused(paused: bool)
signal level_completed
signal settings_changed

# Constants (Rule F25)
const SAVE_PATH: String = "user://game_save.cfg"
const DEFAULT_SENSITIVITY: float = 0.2
const DEFAULT_VOLUME: float = 0.8
const DEFAULT_DIFFICULTY: int = 1 # 0: Easy, 1: Normal, 2: Hard
const PLAYER_MAX_HEALTH: int = 100
const PLAYER_MAX_STAMINA: float = 100.0
const PROJECT_VERSION: String = "1.0.0"

# Exported variables (Rule 14)
@export var player_start_scene: PackedScene # The scene to load after Boot
@export var debug_mode_enabled: bool = true

# Game state (Rule 673)
var current_player_health: int = PLAYER_MAX_HEALTH
var current_player_stamina: float = PLAYER_MAX_STAMINA
var current_level_path: String = ""
var enemies_alive: int = 0
var game_is_paused: bool = false
var game_over: bool = false

# Player settings (Rule 673)
var mouse_sensitivity: float = DEFAULT_SENSITIVITY
var master_volume: float = DEFAULT_VOLUME
var sfx_volume: float = DEFAULT_VOLUME
var music_volume: float = DEFAULT_VOLUME
var difficulty: int = DEFAULT_DIFFICULTY # 0: Easy, 1: Normal, 2: Hard

# Autoload initialization (Rule 679, 949)
func _ready() -> void:
	print("GameManager: Initializing...")
	load_game() # Load settings on startup
	apply_settings()
	process_mode = Node.PROCESS_MODE_ALWAYS # Ensure GameManager processes even when game is paused

	get_tree().paused = false
	game_is_paused = false
	game_over = false

# Player health management (Rule 136, 137, 695)
func change_player_health(amount: int) -> void:
	if game_over:
		return

	current_player_health = clamp(current_player_health + amount, 0, PLAYER_MAX_HEALTH)
	player_health_changed.emit(current_player_health) # Rule 675
	print("Player health: ", current_player_health)

	if current_player_health <= 0:
		player_died_logic()

func player_died_logic() -> void: # Rule 138, 695
	if game_over:
		return

	game_over = true
	print("Player has died!")
	player_died.emit() # Rule 675
	get_tree().paused = true # Pause game on death (placeholder for proper death screen)
	# TODO: Show game over screen, offer restart/quit

# Player stamina management (Rule 168)
func change_player_stamina(amount: float) -> void:
	current_player_stamina = clamp(current_player_stamina + amount, 0.0, PLAYER_MAX_STAMINA)

# Pause/Resume Game (Rule 113, 683)
func toggle_pause_game() -> void:
	game_is_paused = not game_is_paused
	get_tree().paused = game_is_paused
	game_paused.emit(game_is_paused) # Rule 675
	print("Game paused: ", game_is_paused)

	# Show/hide mouse cursor (Rule 429)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if game_is_paused else Input.MOUSE_MODE_CAPTURED)

# Settings management (Rule 391, 418)
func set_mouse_sensitivity(sensitivity: float) -> void:
	mouse_sensitivity = sensitivity
	settings_changed.emit() # Rule 675
	print("Mouse sensitivity set to: ", mouse_sensitivity)

func set_master_volume(volume: float) -> void:
	master_volume = volume
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(volume))
	settings_changed.emit()
	print("Master volume set to: ", master_volume)

func set_sfx_volume(volume: float) -> void:
	sfx_volume = volume
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(volume))
	settings_changed.emit()
	print("SFX volume set to: ", sfx_volume)

func set_music_volume(volume: float) -> void:
	music_volume = volume
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(volume))
	settings_changed.emit()
	print("Music volume set to: ", music_volume)

func set_difficulty(level: int) -> void:
	difficulty = clamp(level, 0, 2)
	settings_changed.emit()
	print("Difficulty set to: ", difficulty)

func apply_settings() -> void: # Rule 679
	set_master_volume(master_volume)
	set_sfx_volume(sfx_volume)
	set_music_volume(music_volume)

# Save/Load functions (Rule 112, 541-580, 674)
func save_game() -> void: # Rule 548
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("GameManager: Failed to load config file for saving: ", error)
		return

	config.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("settings", "master_volume", master_volume)
	config.set_value("settings", "sfx_volume", sfx_volume)
	config.set_value("settings", "music_volume", music_volume)
	config.set_value("settings", "difficulty", difficulty)
	config.set_value("game", "current_level_path", current_level_path)
	config.set_value("game", "player_health", current_player_health)
	config.set_value("game", "player_stamina", current_player_stamina)
	config.set_value("game", "project_version", PROJECT_VERSION) # Rule 569, 692

	error = config.save(SAVE_PATH) # Rule 576
	if error != OK:
		push_error("GameManager: Failed to save game: ", error)
		# emit_signal("save_failed") # Rule 557
	else:
		print("Game saved successfully.")
		# emit_signal("save_succeeded") # Rule 557

func load_game() -> void: # Rule 549
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH) # Rule 543

	if error == OK:
		mouse_sensitivity = config.get_value("settings", "mouse_sensitivity", DEFAULT_SENSITIVITY)
		master_volume = config.get_value("settings", "master_volume", DEFAULT_VOLUME)
		sfx_volume = config.get_value("settings", "sfx_volume", DEFAULT_VOLUME)
		music_volume = config.get_value("settings", "music_volume", DEFAULT_VOLUME)
		difficulty = config.get_value("settings", "difficulty", DEFAULT_DIFFICULTY)
		current_level_path = config.get_value("game", "current_level_path", "")
		current_player_health = config.get_value("game", "player_health", PLAYER_MAX_HEALTH)
		current_player_stamina = config.get_value("game", "player_stamina", PLAYER_MAX_STAMINA)
		var saved_version: String = config.get_value("game", "project_version", "")
		if saved_version != PROJECT_VERSION: # Rule 571
			print("GameManager: Save file version mismatch (", saved_version, " vs ", PROJECT_VERSION, "). May need migration.")

		print("Game loaded successfully.")
		# emit_signal("load_succeeded") # Rule 557
	elif error == ERR_FILE_NOT_FOUND:
		print("GameManager: No save file found. Initializing with default settings.")
		reset_save() # Rule 544
	else:
		push_error("GameManager: Failed to load game: ", error)
		# emit_signal("load_failed") # Rule 557
		reset_save() # Fallback for corrupted saves (Rule 544)

func reset_save() -> void: # Rule 550
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists(SAVE_PATH.split("user://")[1]):
		dir.remove(SAVE_PATH.split("user://")[1])
		print("Save file deleted.")
	else:
		print("No save file to delete or directory error.")

	# Reset settings to default (Rule 679)
	mouse_sensitivity = DEFAULT_SENSITIVITY
	master_volume = DEFAULT_VOLUME
	sfx_volume = DEFAULT_VOLUME
	music_volume = DEFAULT_VOLUME
	difficulty = DEFAULT_DIFFICULTY
	current_player_health = PLAYER_MAX_HEALTH
	current_player_stamina = PLAYER_MAX_STAMINA
	current_level_path = ""
	apply_settings()
	save_game() # Save default settings

# Level management (Rule 690)
func load_level(path: String) -> void:
	if ResourceLoader.exists(path): # Rule 793
		current_level_path = path
		get_tree().change_scene_to_file(path)
		print("Loading level: ", path)
	else:
		push_error("GameManager: Level path does not exist: ", path)

func enemy_spawned() -> void:
	enemies_alive += 1
	print("Enemies alive: ", enemies_alive)

func enemy_died() -> void:
	enemies_alive -= 1
	print("Enemies alive: ", enemies_alive)
	if enemies_alive <= 0:
		level_completed.emit() # Rule 696
		print("All enemies defeated! Level completed.")
		# TODO: Trigger next level or win screen

func _exit_tree() -> void:
	save_game() # Ensure settings are saved on exit
	print("GameManager: Exiting...")