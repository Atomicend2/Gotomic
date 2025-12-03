class_name PlayerController
extends CharacterBody3D

# Player controller for a first-person perspective.

@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002
@export var ray_shoot_power: float = 50.0
@export var ray_max_distance: float = 100.0

@onready var head_node: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray_cast: RayCast3D = $Head/Camera3D/RayCast3D
@onready var shoot_audio: AudioStreamPlayer3D = $Head/Camera3D/ShootAudio

var target_speed: float = move_speed
var rotation_x: float = 0.0
var rotation_y: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	# Lock mouse to center of screen and hide it.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not is_instance_valid(head_node):
		push_error("Head node not found for PlayerController!")
		set_physics_process(false)
		return
	if not is_instance_valid(camera):
		push_error("Camera not found under Head node for PlayerController!")
		set_physics_process(false)
		return
	if not is_instance_valid(ray_cast):
		push_error("RayCast3D not found under Camera3D for PlayerController!")
		set_physics_process(false)
		return
	if not is_instance_valid(shoot_audio):
		push_error("ShootAudio (AudioStreamPlayer3D) not found for PlayerController!")
		set_physics_process(false)
		return

	ray_cast.target_position = Vector3(0, 0, -ray_max_distance)

func _input(event: InputEvent) -> void:
	# Handle mouse movement for camera rotation.
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_y -= event.relative.x * mouse_sensitivity
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_x = clamp(rotation_x, -PI/2, PI/2) # Clamp vertical look
		
		# Apply rotation to player body (Y-axis) and head (X-axis).
		rotation.y = rotation_y
		head_node.rotation.x = rotation_x
	
	# Handle shooting input.
	if event.is_action_pressed("shoot"):
		shoot()
		event.handled = true # Crucial for F07/F19 enforcement

func _physics_process(delta: float) -> void:
	# Apply gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Apply movement.
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_at_angle(velocity.x, 0.0, 0.1) # Decelerate X
		velocity.z = move_at_angle(velocity.z, 0.0, 0.1) # Decelerate Z

	move_and_slide()

func shoot() -> void:
	# Perform a raycast to hit physics objects.
	if ray_cast.is_colliding():
		var collider: Object = ray_cast.get_collider()
		if collider is RigidBody3D:
			var body: RigidBody3D = collider as RigidBody3D
			# Apply an impulse to the hit object.
			var hit_position: Vector3 = ray_cast.get_collision_point()
			var direction: Vector3 = (hit_position - ray_cast.global_position).normalized()
			body.apply_impulse(direction * ray_shoot_power, hit_position - body.global_position)
			print("Shot hit RigidBody3D: ", body.name, " at ", hit_position)
			
			# Emit a signal or call a method on the physics object if it has one.
			if body.has_method("on_shot"):
				body.on_shot(ray_shoot_power, hit_position)

	# Play shoot sound (placeholder - stream property is empty).
	if is_instance_valid(shoot_audio) and shoot_audio.stream != null:
		shoot_audio.play()

func move_at_angle(current_value: float, target_value: float, delta_ratio: float) -> float:
	# Utility function for smooth deceleration.
	return current_value + (target_value - current_value) * delta_ratio