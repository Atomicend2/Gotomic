class_name PlayerMovement
extends Node

#region Signals
signal footstep_played()
#endregion

#region Exported Variables
@export var movement_speed: float = 5.0
@export var sprint_speed_multiplier: float = 1.5
@export var jump_velocity: float = 4.5
@export var acceleration: float = 10.0
@export var friction: float = 10.0
@export var air_friction: float = 2.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var stamina_max: float = 100.0
@export var stamina_regen_rate: float = 10.0
@export var stamina_sprint_cost: float = 15.0
@export var head_bob_amplitude_x: float = 0.05
@export var head_bob_amplitude_y: float = 0.05
@export var head_bob_frequency: float = 10.0
@export var footstep_interval_walk: float = 0.4
@export var footstep_interval_sprint: float = 0.2
#endregion

#region Private Variables
var _player_body: CharacterBody3D
var _camera_mount: Node3D
var _camera: Camera3D

var _velocity: Vector3 = Vector3.ZERO
var _current_stamina: float
var _is_sprinting: bool = false
var _time_since_last_footstep: float = 0.0
var _current_footstep_interval: float = 0.0
var _bob_time: float = 0.0
var _initial_camera_position: Vector3
#endregion

func _init() -> void:
	_current_stamina = stamina_max

func setup(player_body: CharacterBody3D, camera_mount: Node3D, camera: Camera3D) -> void:
	_player_body = player_body
	_camera_mount = camera_mount
	_camera = camera
	_initial_camera_position = _camera.position
	print("PlayerMovement: Setup complete.")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player_body) or GameManager.is_game_paused:
		return

	_apply_gravity(delta)
	_handle_input_movement(delta)
	_handle_stamina(delta)
	_handle_head_bob(delta)
	_handle_footsteps(delta)

	_player_body.velocity = _velocity
	_player_body.move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not _player_body.is_on_floor():
		_velocity.y -= gravity * delta

func _handle_input_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (_player_body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	_is_sprinting = Input.is_action_pressed("sprint") and input_dir.y < 0 and _current_stamina > 0

	var target_speed: float = movement_speed
	if _is_sprinting:
		target_speed *= sprint_speed_multiplier
	
	if direction != Vector3.ZERO:
		var current_horizontal_velocity: Vector3 = _velocity
		current_horizontal_velocity.y = 0.0
		var target_horizontal_velocity: Vector3 = direction * target_speed
		current_horizontal_velocity = current_horizontal_velocity.lerp(target_horizontal_velocity, acceleration * delta)
		_velocity.x = current_horizontal_velocity.x
		_velocity.z = current_horizontal_velocity.z
	else:
		_velocity.x = lerpf(_velocity.x, 0.0, friction * delta)
		_velocity.z = lerpf(_velocity.z, 0.0, friction * delta)
	
	if Input.is_action_just_pressed("jump") and _player_body.is_on_floor():
		_velocity.y = jump_velocity

func _handle_stamina(delta: float) -> void:
	if _is_sprinting and _player_body.is_on_floor():
		_current_stamina = max(0.0, _current_stamina - stamina_sprint_cost * delta)
		if _current_stamina <= 0.0:
			_is_sprinting = false # Stop sprinting if stamina runs out
	else:
		_current_stamina = min(stamina_max, _current_stamina + stamina_regen_rate * delta)

func _handle_head_bob(delta: float) -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_player_body):
		return

	var horizontal_velocity: Vector3 = _player_body.velocity
	horizontal_velocity.y = 0.0

	if horizontal_velocity.length() > 0.1 and _player_body.is_on_floor():
		_bob_time += delta * head_bob_frequency * (sprint_speed_multiplier if _is_sprinting else 1.0)
		var bob_x: float = sin(_bob_time) * head_bob_amplitude_x
		var bob_y: float = cos(_bob_time * 2.0) * head_bob_amplitude_y
		_camera.position = _initial_camera_position + Vector3(bob_x, bob_y, 0)
	else:
		_bob_time = lerpf(_bob_time, 0.0, delta * 5.0) # Reset bob time smoothly
		_camera.position = _initial_camera_position.lerp(_camera.position, exp(-delta * 10.0))

func _handle_footsteps(delta: float) -> void:
	var horizontal_velocity: Vector3 = _player_body.velocity
	horizontal_velocity.y = 0.0

	if horizontal_velocity.length() > 0.1 and _player_body.is_on_floor():
		_current_footstep_interval = footstep_interval_sprint if _is_sprinting else footstep_interval_walk
		_time_since_last_footstep += delta
		if _time_since_last_footstep >= _current_footstep_interval:
			footstep_played.emit()
			_time_since_last_footstep = 0.0
	else:
		_time_since_last_footstep = 0.0

func get_is_sprinting() -> bool:
	return _is_sprinting

func get_current_stamina() -> float:
	return _current_stamina

func get_max_stamina() -> float:
	return stamina_max