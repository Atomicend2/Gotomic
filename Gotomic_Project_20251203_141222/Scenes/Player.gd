class_name Player
extends CharacterBody3D

#region Signals
signal player_health_changed(new_health: int)
signal player_died_signal()
signal weapon_switched(weapon_name: String, current_ammo: int, total_ammo: int)
signal flashlight_energy_changed(current_energy: float, max_energy: float)
signal player_interact_prompt(visible: bool, message: String)
#endregion

#region Exported Variables
@export var max_health: int = 100
@export var player_movement_script: PlayerMovement
@export var player_camera_script: PlayerCamera
@export var player_combat_script: PlayerCombat

@export var hud_scene: PackedScene
@export var initial_weapon_scene: PackedScene
@export var pause_menu_scene: PackedScene

@export var footstep_sound_stream: AudioStream = preload("res://Assets/Audio/placeholder_footstep.tres")
@export var footstep_audio_player: AudioStreamPlayer3D

@export var flashlight_node: OmniLight3D
@export var flashlight_max_energy: float = 100.0
@export var flashlight_drain_rate: float = 5.0
@export var flashlight_recharge_rate: float = 10.0
#endregion

#region Public Variables
var player_health: int
var current_weapon_index: int = 0
var flashlight_energy: float
#endregion

#region Private Variables
var _hud_instance: HUD
var _pause_menu_instance: PauseMenu
var _is_flashlight_on: bool = false
#endregion

func _ready() -> void:
	player_health = max_health
	flashlight_energy = flashlight_max_energy

	if GameManager.is_instance_valid(GameManager):
		GameManager.register_player(self)
		
	_setup_components()
	_spawn_initial_weapon()
	_setup_ui()
	_setup_flashlight()
	
	if player_movement_script:
		player_movement_script.footstep_played.connect(Callable(self, "_play_footstep_sound"))

	player_health_changed.emit(player_health) # Initial HUD update
	
	print("Player: Ready.")

func _setup_components() -> void:
	if player_movement_script:
		player_movement_script.setup(self, $CameraMount, $CameraMount/PlayerCamera)
	else:
		push_error("Player: PlayerMovement script not assigned!")

	if player_camera_script:
		player_camera_script.setup(self, $CameraMount, $CameraMount/PlayerCamera)
	else:
		push_error("Player: PlayerCamera script not assigned!")

	if player_combat_script:
		player_combat_script.setup(self, player_camera_script, player_movement_script)
		player_combat_script.weapon_fire_initiated.connect(Callable(self, "_on_weapon_fire"))
		player_combat_script.current_weapon_changed.connect(Callable(self, "_on_weapon_switched"))
		player_combat_script.get_signal("player_interact_prompt").connect(Callable(self, "player_interact_prompt"))
	else:
		push_error("Player: PlayerCombat script not assigned!")
	
	if not is_instance_valid(footstep_audio_player):
		footstep_audio_player = $AudioPlayerFootsteps as AudioStreamPlayer3D
		if footstep_audio_player:
			footstep_audio_player.bus = "SFX"
			footstep_audio_player.stream = footstep_sound_stream
		else:
			push_error("Player: Footstep AudioStreamPlayer3D not found!")

func _spawn_initial_weapon() -> void:
	if player_combat_script and initial_weapon_scene:
		player_combat_script.add_weapon(initial_weapon_scene)
	else:
		push_error("Player: Cannot spawn initial weapon, either PlayerCombat or initial_weapon_scene is missing.")

func _setup_ui() -> void:
	if hud_scene:
		_hud_instance = hud_scene.instantiate() as HUD
		if is_instance_valid(_hud_instance):
			get_tree().root.add_child(_hud_instance)
			_hud_instance.set_player(self)
			print("Player: HUD instantiated.")
		else:
			push_error("Player: Failed to instance HUD scene!")
	
	if pause_menu_scene:
		_pause_menu_instance = pause_menu_scene.instantiate() as PauseMenu
		if is_instance_valid(_pause_menu_instance):
			get_tree().root.add_child(_pause_menu_instance)
			print("Player: Pause Menu instantiated.")
		else:
			push_error("Player: Failed to instance Pause Menu scene!")

func _setup_flashlight() -> void:
	if is_instance_valid(flashlight_node):
		flashlight_node.light_energy = 0.0 # Start off
	else:
		push_error("Player: Flashlight node not assigned!")

func _physics_process(delta: float) -> void:
	if GameManager.is_game_paused:
		return
	
	_update_flashlight(delta)

func take_damage(amount: float) -> void:
	if player_health <= 0:
		return

	player_health = maxi(0, player_health - int(amount))
	player_health_changed.emit(player_health)
	print("Player health: ", player_health)

	if player_health <= 0:
		_die()

func _die() -> void:
	print("Player Died!")
	player_died_signal.emit()
	GameManager.game_state = 4 # Game Over
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().reload_current_scene() # Placeholder: reload scene on death

func _on_weapon_fire() -> void:
	if player_movement_script and player_combat_script:
		var speed_factor: float = player_movement_script.velocity.length() / player_movement_script.movement_speed
		var ads_factor: float = 0.5 if player_combat_script.get_is_aiming_down_sights() else 1.0
		var sprint_factor: float = 1.5 if player_movement_script.get_is_sprinting() else 1.0
		var spread_amount: float = clampf(speed_factor * sprint_factor * ads_factor, 0.0, 1.0)
		
		if is_instance_valid(_hud_instance):
			_hud_instance.set_crosshair_spread(spread_amount)
	
	# Reset spread after a short delay
	var timer: Timer = get_tree().create_timer(0.3)
	timer.timeout.connect(func(): if is_instance_valid(_hud_instance): _hud_instance.set_crosshair_spread(0.0))

func _on_weapon_switched(weapon_index: int) -> void:
	current_weapon_index = weapon_index
	weapon_switched.emit(player_combat_script.get_current_weapon().weapon_name, 
						player_combat_script.get_current_weapon().current_ammo_in_mag, 
						player_combat_script.get_current_weapon().total_reserve_ammo)

func _play_footstep_sound() -> void:
	if is_instance_valid(footstep_audio_player) and footstep_audio_player.stream:
		footstep_audio_player.play()

func toggle_flashlight() -> void:
	_is_flashlight_on = not _is_flashlight_on
	if _is_flashlight_on:
		if flashlight_energy <= 0:
			_is_flashlight_on = false # Cannot turn on if no energy
			if is_instance_valid(flashlight_node):
				flashlight_node.light_energy = 0.0
			return
		if is_instance_valid(_hud_instance) and is_instance_valid(_hud_instance.flashlight_bar):
			_hud_instance.flashlight_bar.visible = true
	else:
		if is_instance_valid(_hud_instance) and is_instance_valid(_hud_instance.flashlight_bar):
			_hud_instance.flashlight_bar.visible = false
	
	print("Flashlight toggled: ", _is_flashlight_on)

func _update_flashlight(delta: float) -> void:
	if not is_instance_valid(flashlight_node):
		return

	if _is_flashlight_on:
		flashlight_energy -= flashlight_drain_rate * delta
		flashlight_energy = max(0.0, flashlight_energy)
		flashlight_node.light_energy = lerpf(flashlight_node.light_energy, 3.0, delta * 5.0) # Fade in
		if flashlight_energy <= 0.0:
			_is_flashlight_on = false
			flashlight_node.light_energy = 0.0
			if is_instance_valid(_hud_instance) and is_instance_valid(_hud_instance.flashlight_bar):
				_hud_instance.flashlight_bar.visible = false
	else:
		flashlight_energy += flashlight_recharge_rate * delta
		flashlight_energy = min(flashlight_max_energy, flashlight_energy)
		flashlight_node.light_energy = lerpf(flashlight_node.light_energy, 0.0, delta * 5.0) # Fade out
	
	flashlight_energy_changed.emit(flashlight_energy, flashlight_max_energy)
	update_hud() # Ensure HUD is updated

func update_hud() -> void:
	player_health_changed.emit(player_health)
	flashlight_energy_changed.emit(flashlight_energy, flashlight_max_energy)
	if is_instance_valid(player_combat_script) and is_instance_valid(player_combat_script.get_current_weapon()):
		var current_weapon: Weapon = player_combat_script.get_current_weapon()
		weapon_switched.emit(current_weapon.weapon_name, current_weapon.current_ammo_in_mag, current_weapon.total_reserve_ammo)