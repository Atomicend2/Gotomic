class_name PlayerCamera
extends Node

## PlayerCamera
## Handles camera movement, aiming down sights (ADS), recoil, and head bob.
## Adheres to ALMIGHTY-1000 Protocol rules 155, 122, 128, 130, 131, 144, 145, 157, 159, 160, 190, 195, 209, 220, 221, 222, 964.

# Signals (Rule F25)
signal camera_shake_applied(amount: float)
signal ads_toggled(active: bool)

# Constants (Rule F25)
const BASE_FOV: float = 75.0
const ADS_FOV_MULTIPLIER: float = 0.6 # e.g. 75 * 0.6 = 45 FOV when ADS
const ADS_SPEED: float = 10.0
const MIN_PITCH: float = -90.0
const MAX_PITCH: float = 90.0
const HEAD_BOB_AMPLITUDE: float = 0.05
const HEAD_BOB_FREQUENCY: float = 10.0
const HEAD_BOB_SMOOTH_SPEED: float = 8.0
const WEAPON_SWAY_AMOUNT: float = 0.02
const WEAPON_SWAY_SMOOTH: float = 8.0

# Exported variables (Rule 14)
@export var camera_node_path: NodePath
@export var weapon_root_node_path: NodePath # Where the weapon model is parented (for sway)
@export var weapon_ads_offset_path: NodePath # Node under weapon for ADS position

# Cached nodes (Rule 316)
var _camera: Camera3D
var _weapon_root: Node3D # Usually PlayerCamera node itself, or a subnode
var _weapon_ads_offset_node: Node3D # Child of weapon

# Internal variables (Rule F26)
var _current_pitch: float = 0.0
var _current_yaw: float = 0.0
var _ads_active: bool = false
var _camera_recoil_tween: Tween
var _current_recoil_offset: Vector3 = Vector3.ZERO
var _head_bob_offset: Vector3 = Vector3.ZERO
var _weapon_sway_offset: Vector3 = Vector3.ZERO
var _current_ads_progress: float = 0.0 # 0.0 = not ADS, 1.0 = full ADS

func _ready() -> void:
	_camera = get_node_or_null(camera_node_path) # Rule 11, 119, 701, 716, 718
	if not _camera:
		push_error("PlayerCamera: Missing Camera3D node at path: ", camera_node_path)
		set_process(false)
		return

	_weapon_root = get_node_or_null(weapon_root_node_path) # Rule 11, 119, 701, 716
	if not _weapon_root:
		push_warning("PlayerCamera: Missing weapon root node at path: ", weapon_root_node_path, ". Weapon sway may not function.")

	_camera.fov = BASE_FOV # Rule 130
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_camera_recoil_tween = create_tween()
	_camera_recoil_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_camera_recoil_tween.stop()

func _input(event: InputEvent) -> void:
	if GameManager.game_is_paused or GameManager.game_over:
		return

	# Mouse look (Rule 128, 145)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sensitivity = GameManager.mouse_sensitivity # Rule 145, 673
		_current_yaw -= event.relative.x * sensitivity
		_current_pitch -= event.relative.y * sensitivity
		_current_pitch = clamp(_current_pitch, MIN_PITCH, MAX_PITCH) # Rule 128

		# Rotate player body for horizontal look
		if get_parent() is Node3D:
			get_parent().rotation_degrees.y = _current_yaw
		# Rotate camera for vertical look
		_camera.rotation_degrees.x = _current_pitch
		event.handled = true # Rule F07/F19 Enforcement

	# Joystick look (Rule 129)
	if event.is_action("look_left"):
		_current_yaw += event.get_action_strength("look_left") * GameManager.mouse_sensitivity * 10.0
		if get_parent() is Node3D: get_parent().rotation_degrees.y = _current_yaw
		event.handled = true
	if event.is_action("look_right"):
		_current_yaw -= event.get_action_strength("look_right") * GameManager.mouse_sensitivity * 10.0
		if get_parent() is Node3D: get_parent().rotation_degrees.y = _current_yaw
		event.handled = true
	if event.is_action("look_up"):
		_current_pitch += event.get_action_strength("look_up") * GameManager.mouse_sensitivity * 10.0
		_current_pitch = clamp(_current_pitch, MIN_PITCH, MAX_PITCH)
		_camera.rotation_degrees.x = _current_pitch
		event.handled = true
	if event.is_action("look_down"):
		_current_pitch -= event.get_action_strength("look_down") * GameManager.mouse_sensitivity * 10.0
		_current_pitch = clamp(_current_pitch, MIN_PITCH, MAX_PITCH)
		_camera.rotation_degrees.x = _current_pitch
		event.handled = true

	if event.is_action_pressed("aim"):
		toggle_ads()
		event.handled = true
	if event.is_action_released("aim"):
		toggle_ads()
		event.handled = true

func _process(delta: float) -> void:
	_update_ads(delta)
	_update_weapon_sway(delta)
	_update_head_bob(delta) # Call head bob update

	# Apply accumulated offsets to camera (Rule 157)
	# Camera base position is handled by CharacterBody3D and its rotation.
	# Here, we only apply recoil and head bob as local offsets.
	var final_camera_offset = _current_recoil_offset + _head_bob_offset
	_camera.transform.origin = final_camera_offset

func toggle_ads() -> void: # Rule 130, 220
	if get_parent().is_sprinting(): # Rule 199
		set_ads_active(false) # Cannot ADS while sprinting
		return
	set_ads_active(not _ads_active)

func set_ads_active(active: bool) -> void:
	if _ads_active == active:
		return

	_ads_active = active
	ads_toggled.emit(_ads_active) # Rule 150

func is_ads_active() -> bool:
	return _ads_active

func apply_recoil(recoil_pattern: Dictionary, ads_active: bool) -> void: # Rule 131, 195, 209, 221, 751, 964
	# Stop any previous recoil tween (Rule 131)
	if _camera_recoil_tween.is_running():
		_camera_recoil_tween.stop()

	# Recalculate recoil based on ADS (Rule 190, 221)
	var recoil_x = recoil_pattern.get("recoil_x", 0.1) * (0.5 if ads_active else 1.0) # Reduce recoil when ADS
	var recoil_y = recoil_pattern.get("recoil_y", 0.2) * (0.5 if ads_active else 1.0)
	var recover_time = recoil_pattern.get("recover_time", 0.2)
	var recoil_duration = recoil_pattern.get("recoil_duration", 0.1)

	_camera_recoil_tween = create_tween()
	_camera_recoil_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_camera_recoil_tween.set_parallel(true)

	# Apply immediate recoil to current pitch
	_current_pitch -= recoil_y
	_current_pitch = clamp(_current_pitch, MIN_PITCH, MAX_PITCH)
	_camera.rotation_degrees.x = _current_pitch

	# Tween camera offset for visual shake (Rule 195)
	var new_recoil_offset = Vector3(
		randf_range(-recoil_x, recoil_x) * 0.5,
		randf_range(0, recoil_y) * 0.2,
		randf_range(0, recoil_x) * 0.1
	)

	_camera_recoil_tween.tween_property(self, "_current_recoil_offset", new_recoil_offset, recoil_duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_camera_recoil_tween.tween_property(self, "_current_recoil_offset", Vector3.ZERO, recover_time)\
		.set_delay(recoil_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	camera_shake_applied.emit(recoil_y) # Rule 195

func _update_ads(delta: float) -> void: # Rule 159, 220, 964
	var target_fov = BASE_FOV * (ADS_FOV_MULTIPLIER if _ads_active else 1.0) # Rule 130, 220
	_camera.fov = lerp(_camera.fov, target_fov, delta * ADS_SPEED) # Rule 220, 785

	# Smoothly move weapon into ADS position (Rule 159)
	if is_instance_valid(_weapon_root) and is_instance_valid(_weapon_ads_offset_node): # Rule 104, 219
		var target_weapon_pos = _weapon_ads_offset_node.position if _ads_active else Vector3.ZERO
		_current_ads_progress = lerp(_current_ads_progress, 1.0 if _ads_active else 0.0, delta * ADS_SPEED)
		var interp_pos = lerp(_weapon_root.position, target_weapon_pos, _current_ads_progress)
		_weapon_root.position = interp_pos
	else:
		# If weapon_root or weapon_ads_offset_node are not valid, clear _current_ads_progress
		# to ensure weapon doesn't get stuck in an "aiming" state visually.
		_current_ads_progress = 0.0 # Rule 219, 723
		# If weapon_ads_offset_path isn't pointing to a valid node, we need to try and get it
		# from the current weapon dynamically.
		var player_combat = get_parent().get_node_or_null("PlayerCombat") # Rule 716
		if player_combat and player_combat.is_instance_valid(player_combat._current_weapon):
			_weapon_ads_offset_node = player_combat._current_weapon.get_node_or_null("ADS_Offset") # Rule 219
		if _ads_active:
			print("PlayerCamera: Warning: Cannot perform ADS animation. Weapon ADS offset node missing.")

func _update_head_bob(delta: float) -> void: # Rule 143
	var player = get_parent() as Player
	if not player:
		_head_bob_offset = Vector3.ZERO
		return

	var is_moving = player.velocity.x != 0.0 or player.velocity.z != 0.0
	var current_time = Time.get_ticks_msec() / 1000.0

	var target_bob_offset = Vector3.ZERO
	if is_moving and not _ads_active:
		var bob_amount = HEAD_BOB_AMPLITUDE * player.velocity.length() / player.walk_speed # Scale bob with speed
		target_bob_offset = Vector3(
			sin(current_time * HEAD_BOB_FREQUENCY) * bob_amount,
			cos(current_time * HEAD_BOB_FREQUENCY * 2.0) * bob_amount, # Y bob is faster
			0.0
		)
	_head_bob_offset = _head_bob_offset.lerp(target_bob_offset, delta * HEAD_BOB_SMOOTH_SPEED)

func _update_weapon_sway(delta: float) -> void: # Rule 183, 184, 185, 223, 224, 964
	if not is_instance_valid(_weapon_root) or _ads_active: # Rule 223, 224, 200
		_weapon_sway_offset = Vector3.ZERO
		return

	var mouse_input_vec = Input.get_vector("look_left", "look_right", "look_up", "look_down") # Use joystick input directly for sway
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var event_mouse_motion = Input.get_last_mouse_motion_event()
		if event_mouse_motion is InputEventMouseMotion:
			mouse_input_vec = Vector2(event_mouse_motion.relative.x, event_mouse_motion.relative.y)

	var target_sway_offset = Vector3(
		-mouse_input_vec.x * WEAPON_SWAY_AMOUNT,
		-mouse_input_vec.y * WEAPON_SWAY_AMOUNT,
		0.0
	)

	_weapon_sway_offset = _weapon_sway_offset.lerp(target_sway_offset, delta * WEAPON_SWAY_SMOOTH)
	_weapon_root.position += _weapon_sway_offset # Apply sway to weapon root position

func _get_parent() -> Node:
	# Helper to safely get the parent node (Player)
	var parent_node = get_parent()
	if not parent_node:
		push_error("PlayerCamera: Parent node is null!")
		return null
	return parent_node