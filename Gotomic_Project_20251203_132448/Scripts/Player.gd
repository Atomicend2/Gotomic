class_name Player
extends CharacterBody3D

## Player
## Root script for the player character, managing child scripts and global interactions.
## Adheres to ALMIGHTY-1000 Protocol rules 19, 79, 87, 121-200.

# Signals (Rule F25)
signal player_crouching(is_crouching: bool) # Placeholder for crouching logic (Rule 169)
signal player_health_updated(health: int, max_health: int)
signal player_stamina_updated(stamina: float, max_stamina: float)

# Constants (Rule F25)
const PLAYER_CAMERA_OFFSET: Vector3 = Vector3(0, 1.6, 0) # Head position
const PLAYER_SPRINT_FOVC_MOD: float = 0.1 # FOV change during sprint

# Exported variables (Rule 14)
@export var player_movement_script: PackedScene
@export var player_camera_script: PackedScene
@export var player_combat_script: PackedScene
@export var player_visual_arms_scene: PackedScene # For player arms/hands model

# Cached nodes (Rule 316)
var _player_movement: PlayerMovement
var _player_camera: PlayerCamera
var _player_combat: PlayerCombat
var _camera_node: Camera3D
var _weapon_socket: Node3D
var _player_arms_instance: Node3D
var _player_arm_animation_player: AnimationPlayer

# Internal variables (Rule F26)
var _current_health: int
var _current_stamina: float
var _is_sprinting: bool = false
var _is_ads_active: bool = false

func _ready() -> void:
	# Add scripts as children for modularity (Rule 152)
	_player_movement = player_movement_script.instantiate() as PlayerMovement
	add_child(_player_movement)
	_player_movement.player_character_body_path = NodePath(".")
	_player_movement.ground_raycast_path = NodePath("GroundRayCast3D")

	_player_camera = player_camera_script.instantiate() as PlayerCamera
	add_child(_player_camera)
	_player_camera.camera_node_path = NodePath("Camera3D")
	_player_camera.weapon_root_node_path = NodePath("Camera3D/GunSocket")

	_player_combat = player_combat_script.instantiate() as PlayerCombat
	add_child(_player_combat)
	_player_combat.weapon_socket_path = NodePath("Camera3D/GunSocket")
	_player_combat.camera_raycast_path = NodePath("Camera3D/AimRayCast3D")

	# Cache direct child nodes (Rule 316)
	_camera_node = get_node_or_null("Camera3D") # Rule 122
	if not _camera_node:
		push_error("Player: Missing Camera3D child node.")
		set_physics_process(false)
		return
	_camera_node.global_position = global_position + PLAYER_CAMERA_OFFSET # Rule 157

	_weapon_socket = get_node_or_null("Camera3D/GunSocket") # Rule 123
	if not _weapon_socket:
		push_error("Player: Missing GunSocket child node under Camera3D.")

	# Instantiate player arms (Rule 103)
	if player_visual_arms_scene:
		_player_arms_instance = player_visual_arms_scene.instantiate()
		_weapon_socket.add_child(_player_arms_instance)
		_player_arms_instance.owner = self
		_player_arm_animation_player = _player_arms_instance.get_node_or_null("AnimationPlayer")
		if not _player_arm_animation_player:
			push_warning("Player: Player arms scene missing AnimationPlayer.")
	else:
		push_warning("Player: Player visual arms scene not provided.")

	# Connect signals for UI updates and player state
	GameManager.player_health_changed.connect(Callable(self, "_on_game_manager_player_health_changed")) # Rule 136, 187
	GameManager.player_died.connect(Callable(self, "_on_game_manager_player_died")) # Rule 138

	_player_movement.sprint_toggled.connect(Callable(self, "_on_player_movement_sprint_toggled")) # Rule 151
	_player_movement.footstep_sound_triggered.connect(Callable(self, "play_footstep_sound")) # Rule 147
	_player_movement.jump_initiated.connect(Callable(self, "_on_player_jump_initiated")) # Rule 822

	_player_camera.ads_toggled.connect(Callable(self, "_on_player_camera_ads_toggled")) # Rule 150

	_player_combat.ammo_changed.connect(Callable(self, "_on_player_combat_ammo_changed")) # Rule 186
	_player_combat.weapon_switched.connect(Callable(self, "_on_player_combat_weapon_switched")) # Rule 146, 217
	_player_combat.player_reloading.connect(Callable(self, "_on_player_combat_reloading")) # Rule 189
	_player_combat.fired_weapon.connect(Callable(self, "_on_player_combat_fired_weapon")) # Rule 194
	_player_combat.dry_fire_sound.connect(Callable(self, "play_dry_fire_sound")) # Rule 212

	# Initialize health/stamina from GameManager (Rule 673)
	_current_health = GameManager.current_player_health
	_current_stamina = GameManager.current_player_stamina
	player_health_updated.emit(_current_health, GameManager.PLAYER_MAX_HEALTH)
	player_stamina_updated.emit(_current_stamina, GameManager.PLAYER_MAX_STAMINA)

	add_to_group("player") # Rule 266, 844

func _process(delta: float) -> void:
	# Update camera position relative to player (Rule 157)
	if is_instance_valid(_camera_node): # Rule 718
		_camera_node.global_position = global_position + PLAYER_CAMERA_OFFSET # Rule 157
	
	# Update stamina from movement script every frame for UI display (Rule 187)
	if is_instance_valid(_player_movement): # Rule 756
		_current_stamina = _player_movement.get_current_stamina()
		player_stamina_updated.emit(_current_stamina, _player_movement.get_max_stamina()) # Rule 823

	_update_arm_animations() # Rule 259

# Signal handlers for GameManager
func _on_game_manager_player_health_changed(new_health: int) -> void: # Rule 136, 187
	_current_health = new_health
	player_health_updated.emit(_current_health, GameManager.PLAYER_MAX_HEALTH)
	if new_health <= 0:
		pass # GameManager handles player_died signal, which can then trigger death screen logic.

func _on_game_manager_player_died() -> void: # Rule 138
	print("Player: Received player_died signal from GameManager. Initiating player death sequence.")
	# Hide player model, disable input, show death screen, etc.
	set_process(false)
	set_physics_process(false)
	get_node("CollisionShape3D").disabled = true # Disable collision
	if _camera_node: _camera_node.current = false # Disable player camera

# PlayerMovement signal handlers
func _on_player_movement_sprint_toggled(active: bool) -> void: # Rule 151
	_is_sprinting = active
	if is_instance_valid(_camera_node): # Rule 718
		# Adjust camera FOV for sprint (Rule 200)
		_camera_node.fov = GameManager.BASE_FOV + (GameManager.BASE_FOV * PLAYER_SPRINT_FOVC_MOD if active else 0.0)

	# Rule 165 - inform PlayerCombat that player is sprinting
	if is_instance_valid(_player_combat) and is_instance_valid(_player_combat._current_weapon): # Rule 723, 779
		_player_combat._current_weapon.set_sprint_state(active)
	print("Player: Sprint toggled: ", active)

func _on_player_jump_initiated() -> void: # Rule 822
	# Example: Play jump sound
	# print("Player: Jump!")
	pass

func play_footstep_sound(surface_type: String, speed_multiplier: float) -> void: # Rule 147, 838
	# Play sound based on surface_type and speed_multiplier (Rule 452, 474)
	var footstep_player = get_node_or_null("FootstepAudioPlayer")
	if footstep_player and footstep_player is AudioStreamPlayer3D:
		# Use different audio streams or pitches based on surface_type and speed
		# Example:
		# var sound_resource = load("res://Assets/Sounds/footstep_" + surface_type + ".res")
		# footstep_player.stream = sound_resource
		footstep_player.pitch_scale = 1.0 + (speed_multiplier * 0.2) # Faster steps higher pitch
		footstep_player.play()
	else:
		push_warning("Player: Footstep AudioStreamPlayer3D not found.")

# PlayerCamera signal handlers
func _on_player_camera_ads_toggled(active: bool) -> void: # Rule 150
	_is_ads_active = active
	if is_instance_valid(_player_combat) and is_instance_valid(_player_combat._current_weapon): # Rule 723, 779
		_player_combat._current_weapon.set_ads_state(active)
	print("Player: ADS toggled: ", active)

func set_ads_input(active: bool) -> void:
	if is_instance_valid(_player_camera):
		_player_camera.set_ads_active(active)

func is_ads_active() -> bool:
	return _is_ads_active

func is_sprinting() -> bool:
	return _is_sprinting

# PlayerCombat signal handlers
func _on_player_combat_ammo_changed(current_ammo: int, max_ammo: int) -> void: # Rule 186
	pass # HUD will listen to GameManager.weapon_ammo_changed, which PlayerCombat emits to

func _on_player_combat_weapon_switched(weapon_name: String, current_ammo: int, max_ammo: int) -> void: # Rule 146, 217
	GameManager.weapon_switched.emit(weapon_name, current_ammo, max_ammo) # Rule 675
	if is_instance_valid(_player_arms_instance) and _player_arm_animation_player: # Rule 259
		_player_arm_animation_player.play("switch_weapon") # Placeholder animation (Rule 103)

func _on_player_combat_reloading(is_reloading: bool) -> void: # Rule 189
	player_reloading.emit(is_reloading)
	if is_instance_valid(_player_arms_instance) and _player_arm_animation_player: # Rule 259
		if is_reloading:
			_player_arm_animation_player.play("reload") # Placeholder animation
		else:
			_player_arm_animation_player.play("idle") # Return to idle

func _on_player_combat_fired_weapon(weapon_name: String) -> void: # Rule 194
	# Apply weapon recoil via camera (Rule 195)
	if is_instance_valid(_player_combat._current_weapon) and is_instance_valid(_player_camera):
		var recoil_pattern = _player_combat._current_weapon.recoil_pattern
		_player_camera.apply_recoil(recoil_pattern, _is_ads_active)
	play_weapon_sound(weapon_name, "fire") # Rule 194

func play_weapon_sound(weapon_name: String, sound_type: String) -> void: # Rule 194, 212, 453
	var audio_player = get_node_or_null("WeaponAudioPlayer")
	if audio_player and audio_player is AudioStreamPlayer3D:
		var sound_resource: AudioStreamWAV = null
		match sound_type:
			"fire":
				# Placeholder: load specific weapon fire sound
				sound_resource = load("res://Assets/Sounds/audio_stream_empty.tres")
				# print("Player: Playing ", weapon_name, " fire sound.")
			"reload":
				# Placeholder: load specific weapon reload sound
				sound_resource = load("res://Assets/Sounds/audio_stream_empty.tres")
				# print("Player: Playing ", weapon_name, " reload sound.")
		if sound_resource:
			audio_player.stream = sound_resource
			audio_player.play()
	else:
		push_warning("Player: Weapon AudioStreamPlayer3D not found.")

func play_dry_fire_sound() -> void: # Rule 212
	var dry_fire_player = get_node_or_null("DryFireAudioPlayer")
	if dry_fire_player and dry_fire_player is AudioStreamPlayer3D:
		var sound_resource = load("res://Assets/Sounds/audio_stream_empty.tres") # Placeholder
		dry_fire_player.stream = sound_resource
		dry_fire_player.play()
	else:
		push_warning("Player: DryFire AudioStreamPlayer3D not found.")

# Arm animations (Rule 259)
func _update_arm_animations() -> void:
	if not _player_arm_animation_player or not is_instance_valid(_player_movement):
		return

	var current_animation = _player_arm_animation_player.current_animation
	if _player_combat.is_reloading():
		if current_animation != "reload":
			_player_arm_animation_player.play("reload")
		return

	if _is_ads_active:
		if current_animation != "ads":
			_player_arm_animation_player.play("ads")
		return

	var is_moving = velocity.length_squared() > 0.1
	if _is_sprinting:
		if current_animation != "sprint":
			_player_arm_animation_player.play("sprint")
	elif is_moving:
		if current_animation != "walk":
			_player_arm_animation_player.play("walk")
	else:
		if current_animation != "idle":
			_player_arm_animation_player.play("idle")