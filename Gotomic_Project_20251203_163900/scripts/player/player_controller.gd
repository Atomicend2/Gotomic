extends CharacterBody3D

class_name PlayerController

signal player_died
signal player_health_changed(new_health: int, old_health: int)
signal weapon_switched(weapon: Weapon)

@export var mouse_sensitivity: float = 0.002
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 6.0
@export var acceleration: float = 10.0
@export var friction: float = 10.0
@export var gravity: float = 14.0

@export var recoil_recovery_speed: float = 5.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_anchor: Node3D = $Head/Camera3D/WeaponAnchor
@onready var health_component: HealthComponent = $HealthComponent
@onready var ray_cast_interact: RayCast3D = $Head/Camera3D/RayCast3D

var _current_speed: float = 0.0
var _recoil_offset: Vector3 = Vector3.ZERO
var _recoil_rotation: Vector3 = Vector3.ZERO
var _current_weapon: Weapon = null
var _weapons: Array[Weapon] = []
var _is_sprinting: bool = false
var _is_aiming: bool = false
var _is_crouching: bool = false

# Mobile input variables
var _look_delta: Vector2 = Vector2.ZERO
var _move_direction: Vector2 = Vector2.ZERO
var _fire_pressed: bool = false
var _aim_pressed: bool = false
var _reload_pressed: bool = false
var _jump_pressed: bool = false
var _crouch_pressed: bool = false
var _sprint_pressed: bool = false
var _pause_pressed: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	health_component.died.connect(_on_died)
	health_component.health_changed.connect(player_health_changed)
	
	for child in weapon_anchor.get_children():
		if child is Weapon:
			_weapons.append(child as Weapon)
			child.global_transform = weapon_anchor.global_transform # Ensure initial position
			child.visible = false
	
	if not _weapons.is_empty():
		switch_weapon(_weapons[0])

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_delta = event.relative * mouse_sensitivity
	elif event is InputEventScreenDrag: # Mobile touch input for looking
		if event.index == 0: # Assuming first touch for movement, second for look. This is a simplification.
			_look_delta = event.relative * mouse_sensitivity * 0.1 # Adjust sensitivity for touch

	if event.is_action_pressed("jump"):
		_jump_pressed = true
	if event.is_action_released("jump"):
		_jump_pressed = false
	
	if event.is_action_pressed("fire"):
		_fire_pressed = true
	if event.is_action_released("fire"):
		_fire_pressed = false

	if event.is_action_pressed("aim"):
		_aim_pressed = true
	if event.is_action_released("aim"):
		_aim_pressed = false

	if event.is_action_pressed("reload"):
		_reload_pressed = true
	if event.is_action_released("reload"):
		_reload_pressed = false

	if event.is_action_pressed("sprint"):
		_sprint_pressed = true
	if event.is_action_released("sprint"):
		_sprint_pressed = false

	if event.is_action_pressed("crouch"):
		_crouch_pressed = true
	if event.is_action_released("crouch"):
		_crouch_pressed = false
	
	if event.is_action_pressed("pause"):
		_pause_pressed = true
	if event.is_action_released("pause"):
		_pause_pressed = false

# Set mobile joystick inputs from HUD
func set_mobile_move_input(direction: Vector2) -> void:
	_move_direction = direction

func set_mobile_look_input(delta: Vector2) -> void:
	_look_delta = delta

func set_mobile_fire_button(pressed: bool) -> void:
	_fire_pressed = pressed

func set_mobile_aim_button(pressed: bool) -> void:
	_aim_pressed = pressed

func set_mobile_reload_button(pressed: bool) -> void:
	_reload_pressed = pressed

func set_mobile_jump_button(pressed: bool) -> void:
	_jump_pressed = pressed

func set_mobile_sprint_button(pressed: bool) -> void:
	_sprint_pressed = pressed

func set_mobile_crouch_button(pressed: bool) -> void:
	_is_crouching = pressed # For toggle or hold, adjust as needed

func set_mobile_pause_button(pressed: bool) -> void:
	_pause_pressed = pressed

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_camera_look(delta)
	_handle_weapon_actions(delta)
	_handle_recoil_recovery(delta)
	
	move_and_slide()

func _handle_movement(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if _jump_pressed and is_on_floor():
		velocity.y = jump_velocity
	
	# Determine current speed (walk/sprint)
	_is_sprinting = (_sprint_pressed or Input.is_action_pressed("sprint"))
	_current_speed = sprint_speed if _is_sprinting else walk_speed

	# Get input direction
	var input_dir: Vector2 = Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: # Keyboard/Mouse
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	else: # Mobile Joystick
		input_dir = _move_direction
	
	var direction: Vector3 = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = lerp(velocity.x, direction.x * _current_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * _current_speed, acceleration * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * delta)

func _handle_camera_look(delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: # Mouse
		rotate_y(-_look_delta.x)
		head.rotate_x(-_look_delta.y)
	else: # Touch
		rotate_y(-_look_delta.x * 0.1) # Further reduce sensitivity for touch
		head.rotate_x(-_look_delta.y * 0.1)
	
	var camera_rot_x: float = head.rotation.x
	head.rotation.x = clampf(camera_rot_x, deg_to_rad(-80), deg_to_rad(80))
	
	_look_delta = Vector2.ZERO # Reset look delta after use

func _handle_weapon_actions(delta: float) -> void:
	if _current_weapon:
		if _fire_pressed or Input.is_action_pressed("fire"):
			_current_weapon.fire()
		
		if _aim_pressed or Input.is_action_pressed("aim"):
			_is_aiming = true
			_current_weapon.aim()
		else:
			_is_aiming = false
			_current_weapon.unaim()

		if _reload_pressed or Input.is_action_pressed("reload"):
			_current_weapon.reload()

func _handle_recoil_recovery(delta: float) -> void:
	_recoil_offset = _recoil_offset.lerp(Vector3.ZERO, recoil_recovery_speed * delta)
	_recoil_rotation = _recoil_rotation.lerp(Vector3.ZERO, recoil_recovery_speed * delta)
	
	# Apply recoil to weapon anchor and camera (simplified)
	weapon_anchor.position = _recoil_offset
	weapon_anchor.rotation = _recoil_rotation
	
	# Apply recoil to camera for actual view shake (more subtle)
	camera.rotation_degrees.x += _recoil_rotation.x * 0.5 # Example, adjust factor

func apply_recoil(recoil_pattern: RecoilPattern) -> void:
	_recoil_offset += recoil_pattern.position_kick
	_recoil_rotation += recoil_pattern.rotation_kick
	
	# Clamp rotation to prevent camera flipping
	_recoil_rotation.x = clampf(_recoil_rotation.x, deg_to_rad(-10), deg_to_rad(10))
	_recoil_rotation.y = clampf(_recoil_rotation.y, deg_to_rad(-5), deg_to_rad(5))

func switch_weapon(new_weapon: Weapon) -> void:
	if _current_weapon:
		_current_weapon.unaim()
		_current_weapon.visible = false
	
	_current_weapon = new_weapon
	if _current_weapon:
		_current_weapon.visible = true
		weapon_switched.emit(_current_weapon)
		_current_weapon.set_player_controller(self)

func _on_died() -> void:
	print("Player Died!")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	player_died.emit()
	set_process(false)
	set_physics_process(false)

func get_current_weapon() -> Weapon:
	return _current_weapon

func get_health_component() -> HealthComponent:
	return health_component

