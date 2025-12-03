extends CharacterBody3D

## Player controller with FPS mechanics, health, and gun interaction.

@export var speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var acceleration: float = 8.0
@export var friction: float = 10.0

# Mouse look settings
@export var mouse_sensitivity: float = 0.002 # Radians per pixel
@export var min_pitch: float = -90.0 # Degrees
@export var max_pitch: float = 90.0 # Degrees

# Interaction settings
@export var interact_distance: float = 3.0

@onready var camera: Camera3D = $Camera3D
@onready var gun_holder: Node3D = $Camera3D/GunHolder
@onready var gun: Gun = $Camera3D/GunHolder/Gun
@onready var health_component: HealthComponent = $HealthComponent
@onready var interaction_ray: RayCast3D = $Camera3D/InteractionRay

var current_speed: float = speed
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var camera_pitch: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	gun.ammo_changed.connect(_on_ammo_changed)
	
	# Setup interaction ray
	interaction_ray.target_position = Vector3(0, 0, -interact_distance)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		handle_mouse_look(event)
	
	if event.is_action_pressed("shoot"):
		gun.fire()
	
	if event.is_action_pressed("interact"):
		handle_interaction()
	
	if event.is_action_pressed("ui_cancel"): # Escape to release mouse
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event.is_action_pressed("ui_accept") and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE: # Click to recapture
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	handle_movement(delta)

func handle_mouse_look(event: InputEventMouseMotion) -> void:
	# Rotate player body horizontally
	rotate_y(-event.relative.x * mouse_sensitivity)
	
	# Rotate camera vertically
	camera_pitch -= event.relative.y * mouse_sensitivity
	camera_pitch = clamp(camera_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	camera.transform.basis = Basis(Vector3(1, 0, 0), camera_pitch)
	camera.rotation.y = 0.0 # Prevent camera from rotating on Y relative to player

func handle_movement(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get the input direction and handle the movement/deceleration.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	current_speed = speed # Placeholder, could add sprinting logic here: if Input.is_action_pressed("sprint_key"): current_speed = sprint_speed

	if direction:
		velocity.x = lerp(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, acceleration * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * delta)

	move_and_slide()

func handle_interaction() -> void:
	interaction_ray.force_raycast_update()
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider is Node:
			var parent_door = collider.get_parent() # Assuming door panel is child of DoorPanel StaticBody3D, which is child of DoorPivot, child of Door.
			if parent_door and parent_door.has_method("interact"):
				parent_door.interact()
			else:
				# Try to find a Door node directly
				var door_node = collider
				while door_node and not door_node.has_method("interact"):
					door_node = door_node.get_parent()
				
				if door_node and door_node.has_method("interact"):
					door_node.interact()


func _on_health_changed(new_health: int, max_health: int) -> void:
	# Update HUD or perform player-specific health actions
	get_node("/root/MainScene/HUD").update_health(new_health, max_health)

func _on_ammo_changed(new_ammo: int, max_ammo: int) -> void:
	# Update HUD
	get_node("/root/MainScene/HUD").update_ammo(new_ammo, max_ammo)

func _on_died() -> void:
	print("Player Died!")
	# Handle game over, respawn, etc.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().reload_current_scene() # Simple respawn for now