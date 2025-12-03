class_name Player
extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var movement_direction_input: Vector2 = Vector2.ZERO
var camera_look_input: Vector2 = Vector2.ZERO
var is_jump_pressed: bool = false

@onready var camera_pivot = $CameraPivot
@onready var camera_3d = $CameraPivot/Camera3D

func _physics_process(delta: float):
	# Apply gravity if not on floor
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	if is_jump_pressed and is_on_floor():
		velocity.y = Globals.PLAYER_JUMP_VELOCITY
		is_jump_pressed = false # Consume jump input

	# Get the input direction and normalize it
	var input_dir = Vector3(movement_direction_input.x, 0, movement_direction_input.y)
	input_dir = input_dir.normalized()

	# Rotate input direction based on player's yaw
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()

	if direction:
		velocity.x = lerp(velocity.x, direction.x * Globals.PLAYER_SPEED, Globals.PLAYER_ACCELERATION * delta)
		velocity.z = lerp(velocity.z, direction.z * Globals.PLAYER_SPEED, Globals.PLAYER_ACCELERATION * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, Globals.PLAYER_DEACCELERATION * delta)
		velocity.z = lerp(velocity.z, 0.0, Globals.PLAYER_DEACCELERATION * delta)

	move_and_slide()

func _input(event: InputEvent):
	# Desktop debugging input
	if OS.get_name() != "Android":
		if event is InputEventMouseMotion and event.relative.length() > 0:
			if Input.is_action_pressed("fire"): # Right-click or mouse button 1 for camera on desktop
				rotate_y(deg_to_rad(-event.relative.x * Globals.SENSITIVITY * 100)) # Adjust sensitivity for mouse
				camera_pivot.rotate_x(deg_to_rad(-event.relative.y * Globals.SENSITIVITY * 100))
				camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))
				event.handled = true
		
		var input_dir_desktop = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		set_movement_input(input_dir_desktop)
		if Input.is_action_just_pressed("jump"):
			jump()

func set_movement_input(p_direction: Vector2):
	movement_direction_input = p_direction

func set_camera_input(p_delta: Vector2):
	camera_look_input = p_delta
	rotate_y(deg_to_rad(-camera_look_input.x * Globals.SENSITIVITY))
	camera_pivot.rotate_x(deg_to_rad(-camera_look_input.y * Globals.SENSITIVITY))
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func jump():
	is_jump_pressed = true