class_name PlayerMovement
extends Node

## PlayerMovement
## Handles player character movement (walk, sprint, jump, gravity).
## Adheres to ALMIGHTY-1000 Protocol rules 153, 126, 129, 139, 140, 141, 142, 168, 801-840.

# Signals (Rule F25)
signal sprint_toggled(active: bool)
signal jump_initiated
signal footstep_sound_triggered(surface_type: String, speed_multiplier: float)

# Constants (Rule F25)
const GRAVITY: float = 9.8
const JUMP_VELOCITY: float = 5.0
const WALK_SPEED: float = 5.0
const SPRINT_SPEED_MULTIPLIER: float = 1.5
const SPRINT_STAMINA_CONSUMPTION: float = 10.0 # per second
const STAMINA_REGEN_RATE: float = 5.0 # per second
const HEAD_BOB_RESET_SPEED: float = 5.0

# Exported variables (Rule 14)
@export var player_character_body_path: NodePath
@export var ground_raycast_path: NodePath

# Cached nodes (Rule 316)
var _player_character_body: CharacterBody3D
var _ground_raycast: RayCast3D

# Internal variables (Rule F26)
var _direction: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _is_sprinting: bool = false
var _current_stamina: float = GameManager.PLAYER_MAX_STAMINA
var _is_jumping: bool = false
var _is_on_floor_cached: bool = false
var _last_footstep_time: float = 0.0
var _footstep_interval: float = 0.4 # Shorter when sprinting

func _ready() -> void:
	_player_character_body = get_node_or_null(player_character_body_path) # Rule 11, 119, 701, 756
	if not _player_character_body:
		push_error("PlayerMovement: Missing CharacterBody3D node at path: ", player_character_body_path)
		set_physics_process(false)
		return

	_ground_raycast = get_node_or_null(ground_raycast_path) # Rule 11, 119, 701, 756
	if not _ground_raycast:
		push_error("PlayerMovement: Missing RayCast3D node at path: ", ground_raycast_path)
		set_physics_process(false)
		return

	_current_stamina = GameManager.current_player_stamina # Initialize stamina from GameManager (Rule 673)
	GameManager.player_health_changed.connect(Callable(self, "_on_game_manager_player_health_changed"))

	# Add to player group for enemy detection (Rule 266, 844)
	_player_character_body.add_to_group("player")

func _physics_process(delta: float) -> void: # Rule 141, 140, 813, 837, 912
	_is_on_floor_cached = _player_character_body.is_on_floor() # Update cached state (Rule 125)

	# Apply gravity (Rule 140)
	if not _is_on_floor_cached:
		_velocity.y -= GRAVITY * delta # Rule 140
		_is_jumping = true
	else:
		_is_jumping = false

	# Handle input (Rule 127, 129)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	_direction = (_player_character_body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	_handle_sprinting(delta) # Rule 142, 168, 802

	var current_speed = WALK_SPEED * (SPRINT_SPEED_MULTIPLIER if _is_sprinting else 1.0)
	if _direction != Vector3.ZERO:
		_velocity.x = _direction.x * current_speed
		_velocity.z = _direction.z * current_speed
	else:
		_velocity.x = lerp(_velocity.x, 0.0, delta * 7.0)
		_velocity.z = lerp(_velocity.z, 0.0, delta * 7.0)

	if Input.is_action_just_pressed("jump") and _is_on_floor_cached: # Rule 140, 813
		_velocity.y = JUMP_VELOCITY
		jump_initiated.emit() # Rule 822

	_player_character_body.velocity = _velocity # Update CharacterBody3D velocity
	_player_character_body.move_and_slide() # Rule 126, 139

	_update_footsteps(delta, current_speed) # Rule 147, 838

	GameManager.current_player_stamina = _current_stamina # Update GameManager (Rule 673)

func _handle_sprinting(delta: float) -> void: # Rule 142, 168, 802
	var can_sprint = Input.is_action_pressed("sprint") and _direction.z < 0 # Only sprint forward
	can_sprint = can_sprint and _current_stamina > 0.0 # Rule 142

	if can_sprint and not _is_sprinting:
		_is_sprinting = true
		sprint_toggled.emit(true) # Rule 822
	elif (not can_sprint and _is_sprinting) or (_current_stamina <= 0.0 and _is_sprinting):
		_is_sprinting = false
		sprint_toggled.emit(false) # Rule 822

	if _is_sprinting: # Rule 142, 802
		_current_stamina -= SPRINT_STAMINA_CONSUMPTION * delta
		_current_stamina = max(0.0, _current_stamina)
	else: # Rule 168, 802
		_current_stamina += STAMINA_REGEN_RATE * delta
		_current_stamina = min(GameManager.PLAYER_MAX_STAMINA, _current_stamina)

func is_sprinting() -> bool:
	return _is_sprinting

func is_on_floor() -> bool:
	return _is_on_floor_cached

func get_current_stamina() -> float:
	return _current_stamina

func get_max_stamina() -> float:
	return GameManager.PLAYER_MAX_STAMINA

func _update_footsteps(delta: float, current_speed: float) -> void: # Rule 147, 838
	if not _is_on_floor_cached or _player_character_body.velocity.length_squared() < 0.1:
		_last_footstep_time = 0.0 # Reset when not moving
		return

	# Adjust footstep interval based on speed (Rule 147, 838)
	_footstep_interval = 0.4 / (current_speed / WALK_SPEED)
	if _is_sprinting: # Rule 200
		_footstep_interval /= SPRINT_SPEED_MULTIPLIER

	if Time.get_ticks_msec() / 1000.0 - _last_footstep_time > _footstep_interval:
		_last_footstep_time = Time.get_ticks_msec() / 1000.0

		var surface_type = "default" # Placeholder for different surface types (Rule 452)
		if _ground_raycast and _ground_raycast.is_colliding(): # Rule 756
			var collider = _ground_raycast.get_collider()
			# Implement logic here to determine surface type based on collider material/group
			if collider is MeshInstance3D and collider.get_name().to_lower().contains("metal"):
				surface_type = "metal"

		footstep_sound_triggered.emit(surface_type, current_speed / WALK_SPEED) # Rule 838

func _on_game_manager_player_health_changed(new_health: int) -> void:
	if new_health <= 0:
		_is_sprinting = false # Stop sprinting if player dies
		sprint_toggled.emit(false)