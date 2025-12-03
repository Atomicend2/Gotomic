class_name PlayerCamera
extends Node

#region Signals
signal camera_shaking_done()
#endregion

#region Exported Variables
@export var mouse_sensitivity_base: float = 0.002
@export var gamepad_sensitivity: float = 0.05
@export var min_pitch: float = -90.0
@export var max_pitch: float = 90.0
@export var camera_smoothing_factor: float = 0.1
@export var recoil_reduction_factor_ads: float = 0.5

@export var shake_duration: float = 0.2
@export var shake_strength: float = 0.1
@export var shake_fade_speed: float = 5.0

@export var default_fov: float = 75.0
@export var ads_fov: float = 50.0
@export var fov_transition_speed: float = 10.0
#endregion

#region Private Variables
var _player_body: CharacterBody3D
var _camera_mount: Node3D
var _camera: Camera3D

var _current_pitch: float = 0.0
var _camera_target_rotation: Vector3 = Vector3.ZERO
var _current_camera_offset: Vector3 = Vector3.ZERO

var _shake_active: bool = false
var _current_shake_strength: float = 0.0
var _shake_timer: float = 0.0

var _ads_state: bool = false
var _camera_base_position: Vector3
#endregion

func setup(player_body: CharacterBody3D, camera_mount: Node3D, camera: Camera3D) -> void:
	_player_body = player_body
	_camera_mount = camera_mount
	_camera = camera
	if is_instance_valid(_camera):
		_camera_base_position = _camera.position
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("PlayerCamera: Setup complete.")

func _input(event: InputEvent) -> void:
	if GameManager.is_game_paused or not is_instance_valid(_player_body) or not is_instance_valid(_camera_mount):
		return

	var sensitivity: float = GameManager.mouse_sensitivity * mouse_sensitivity_base

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_look(event, sensitivity)
		event.handled = true # Rule F07/F19 Enforcement
	elif event is InputEventJoypadMotion:
		_handle_gamepad_look(event)
		event.handled = true # Rule F07/F19 Enforcement

func _process(delta: float) -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_camera_mount) or GameManager.is_game_paused:
		return

	_apply_camera_smoothing(delta)
	_apply_recoil_offset(delta)
	_update_fov(delta)
	_apply_camera_shake(delta)

func _handle_mouse_look(event: InputEventMouseMotion, sensitivity: float) -> void:
	if not is_instance_valid(_player_body) or not is_instance_valid(_camera_mount):
		return

	_player_body.rotate_y(-event.relative.x * sensitivity)
	_current_pitch += event.relative.y * sensitivity
	_current_pitch = clampf(_current_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	_camera_target_rotation.x = _current_pitch

func _handle_gamepad_look(event: InputEventJoypadMotion) -> void:
	if not is_instance_valid(_player_body) or not is_instance_valid(_camera_mount):
		return

	var axis_value: float = event.axis_value

	# Right stick X-axis (look left/right)
	if event.axis == JOY_AXIS_2: # Assuming right stick X-axis
		_player_body.rotate_y(-axis_value * gamepad_sensitivity)
	# Right stick Y-axis (look up/down)
	elif event.axis == JOY_AXIS_3: # Assuming right stick Y-axis
		_current_pitch += axis_value * gamepad_sensitivity
		_current_pitch = clampf(_current_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		_camera_target_rotation.x = _current_pitch

func _apply_camera_smoothing(delta: float) -> void:
	if not is_instance_valid(_camera_mount):
		return
	_camera_mount.rotation.x = lerp_angle(_camera_mount.rotation.x, _camera_target_rotation.x, delta * 1.0 / camera_smoothing_factor)

func _apply_recoil_offset(delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	_camera.position = _camera.position.lerp(_camera_base_position + _current_camera_offset, delta * 10.0)
	_current_camera_offset = _current_camera_offset.lerp(Vector3.ZERO, delta * 5.0)

func _update_fov(delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	var target_fov: float = ads_fov if _ads_state else default_fov
	_camera.fov = lerpf(_camera.fov, target_fov, delta * fov_transition_speed)

func apply_recoil(recoil_pitch_deg: float, recoil_yaw_deg: float) -> void:
	if not is_instance_valid(_camera_mount):
		return

	var final_recoil_pitch: float = recoil_pitch_deg
	var final_recoil_yaw: float = recoil_yaw_deg

	if _ads_state:
		final_recoil_pitch *= recoil_reduction_factor_ads
		final_recoil_yaw *= recoil_reduction_factor_ads

	# Apply recoil to camera pitch
	_current_pitch -= deg_to_rad(final_recoil_pitch)
	_current_pitch = clampf(_current_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	_camera_target_rotation.x = _current_pitch
	
	# Apply recoil to camera yaw (left/right) - Player body rotation
	_player_body.rotate_y(deg_to_rad(randf_range(-final_recoil_yaw, final_recoil_yaw)))

	# Optional: Apply visual camera position offset (slight bump)
	_current_camera_offset += Vector3(randf_range(-0.01, 0.01), randf_range(-0.01, 0.01), randf_range(-0.02, -0.05))

func start_camera_shake(strength_multiplier: float = 1.0) -> void:
	if not _shake_active:
		_shake_active = true
		_current_shake_strength = shake_strength * strength_multiplier
		_shake_timer = shake_duration

func _apply_camera_shake(delta: float) -> void:
	if not _shake_active or not is_instance_valid(_camera_mount):
		return

	_shake_timer -= delta
	_current_shake_strength = lerpf(_current_shake_strength, 0.0, shake_fade_speed * delta)

	if _shake_timer <= 0.0 and _current_shake_strength < 0.01:
		_shake_active = false
		_current_shake_strength = 0.0
		camera_shaking_done.emit()
		return

	var shake_offset: Vector3 = Vector3(
		randf_range(-_current_shake_strength, _current_shake_strength),
		randf_range(-_current_shake_strength, _current_shake_strength),
		randf_range(-_current_shake_strength, _current_shake_strength)
	)
	_camera_mount.position = _camera_mount.position + shake_offset

func set_ads_state(is_ads: bool) -> void:
	_ads_state = is_ads