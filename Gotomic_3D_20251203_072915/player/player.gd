class_name Player
extends CharacterBody3D

@export var mouse_sensitivity = 0.002
@export var walk_speed = 5.0
@export var sprint_speed = 8.0
@export var jump_velocity = 4.5
@export var gravity = 9.8
@export var max_health = 100

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var gun_mesh = $Head/Camera3D/GunMesh
@onready var ray_cast = $Head/Camera3D/RayCast3D
@onready var hud = get_node("/root/World/HUD")

var health = max_health
var current_speed = walk_speed

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if hud:
		hud.update_health(health, max_health)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotate the player body (yaw)
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Rotate the head/camera (pitch)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))

	if event.is_action_pressed("shoot"):
		shoot()
	if event.is_action_pressed("interact"):
		interact()
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	# Handle gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Handle movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	current_speed = sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

func shoot():
	if ray_cast.is_colliding():
		var collider = ray_cast.get_collider()
		if collider and collider.has_method("take_damage"):
			collider.take_damage(20) # Example damage
		print("Shot hit: ", collider.name)
	else:
		print("Shot missed.")

func interact():
	# Use a shorter raycast for interaction
	var interact_ray = RayCast3D.new()
	add_child(interact_ray)
	interact_ray.global_transform = camera.global_transform
	interact_ray.target_position = Vector3(0, 0, -2) # Interact distance
	interact_ray.force_raycast_update()

	if interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		if collider and collider.has_method("interact"):
			collider.interact(self) # Pass player for context if needed
			print("Interacted with: ", collider.name)

	interact_ray.queue_free()

func take_damage(amount):
	health -= amount
	health = maxi(0, health)
	if hud:
		hud.update_health(health, max_health)
	print("Player took ", amount, " damage. Health: ", health)
	if health <= 0:
		die()

func die():
	print("Player died!")
	# Implement game over logic here
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	if hud:
		hud.show_game_over()