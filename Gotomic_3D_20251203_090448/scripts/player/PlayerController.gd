extends CharacterBody3D

## PlayerController.gd
## Manages player movement, input, health, and interaction logic.

@export var move_speed: float = 5.0 ## Player's movement speed.
@export var sprint_speed_multiplier: float = 1.5 ## Multiplier for sprint speed.
@export var jump_velocity: float = 7.0 ## Vertical velocity when jumping.
@export var acceleration: float = 10.0 ## How quickly the player reaches max speed.
@export var air_acceleration: float = 3.0 ## How quickly the player moves in air.
@export var friction: float = 10.0 ## How quickly the player slows down.
@export var max_health: int = 100 ## Maximum health of the player.

@onready var _camera_look: CameraLook = $CameraLook as CameraLook
@onready var _gun_system: GunSystem = $CameraLook/GunHolder/Gun as GunSystem
@onready var _interaction_area: Area3D = $InteractionArea as Area3D
@onready var _animation_player: AnimationPlayer = $AnimationPlayer as AnimationPlayer

var _current_health: int = max_health:
	set(value):
		var old_health = _current_health
		_current_health = clampi(value, 0, max_health)
		if _current_health != old_health:
			health_changed.emit(_current_health)
			if _current_health <= 0 and GameManager.player_is_alive:
				die()

signal health_changed(new_health: int)
signal took_damage(amount: int)
signal healed(amount: int)
signal interacted_with_object(object: Node3D)

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_current_health = max_health
	health_changed.emit(_current_health)
	GameManager.start_game()
	# Connect signals for interaction
	if is_instance_valid(_interaction_area):
		_interaction_area.body_entered.connect(self._on_InteractionArea_body_entered)
		_interaction_area.body_exited.connect(self._on_InteractionArea_body_exited)
	else:
		printerr("InteractionArea3D not found on Player scene!")
	
	if is_instance_valid(_gun_system):
		_gun_system.set_shooter_node(self) # Let the gun know who is shooting

func _physics_process(delta: float) -> void:
	if not GameManager.game_active or not GameManager.player_is_alive:
		# Stop all movement and input if game is over or player is dead
		velocity = Vector3.ZERO
		return

	_handle_movement(delta)
	_handle_input_actions() # Handles jump and shoot

## Handles player movement based on input.
func _handle_movement(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Get the input direction and handle the movement/deceleration.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (_camera_look.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed: float = move_speed
	# Add sprinting logic
	if Input.is_action_pressed("sprint"): # Assuming 'sprint' action exists, add to project.godot
		current_speed *= sprint_speed_multiplier
		if is_instance_valid(_animation_player) and not _animation_player.is_playing():
			_animation_player.play("Sprint") # Placeholder animation
	elif direction != Vector3.ZERO:
		if is_instance_valid(_animation_player) and not _animation_player.is_playing():
			_animation_player.play("Walk") # Placeholder animation
	else:
		if is_instance_valid(_animation_player) and not _animation_player.is_playing():
			_animation_player.play("Idle") # Placeholder animation

	if is_on_floor():
		if direction:
			velocity.x = lerp(velocity.x, direction.x * current_speed, acceleration * delta)
			velocity.z = lerp(velocity.z, direction.z * current_speed, acceleration * delta)
		else:
			velocity.x = lerp(velocity.x, 0.0, friction * delta)
			velocity.z = lerp(velocity.z, 0.0, friction * delta)
	else:
		# Air control
		if direction:
			velocity.x = lerp(velocity.x, direction.x * current_speed, air_acceleration * delta)
			velocity.z = lerp(velocity.z, direction.z * current_speed, air_acceleration * delta)

	move_and_slide()

## Handles player action inputs (jump, shoot, interact).
func _handle_input_actions() -> void:
	# Handle Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		if is_instance_valid(_animation_player):
			_animation_player.play("Jump") # Placeholder animation

	# Handle Shoot
	if Input.is_action_pressed("shoot"):
		if is_instance_valid(_gun_system):
			_gun_system.shoot()

	# Handle Interact
	if Input.is_action_just_pressed("interact"):
		_try_interact()

## Attempts to interact with objects in the interaction area.
func _try_interact() -> void:
	if not is_instance_valid(_interaction_area): return

	var bodies_in_area: Array[Node3D] = _interaction_area.get_overlapping_bodies()
	for body in bodies_in_area:
		# Check if the body has an 'interact' method
		if body.has_method("interact"):
			# Call the interact method on the body
			body.interact(self) # Pass self (PlayerController) as the interactor
			interacted_with_object.emit(body)
			print("Interacted with: ", body.name)
			return # Interact with only one object at a time

## Applies damage to the player.
func take_damage(amount: int) -> void:
	if not GameManager.player_is_alive: return

	_current_health -= amount
	took_damage.emit(amount)
	print("Player took %d damage. Current health: %d" % [amount, _current_health])

## Heals the player.
func heal(amount: int) -> void:
	_current_health += amount
	healed.emit(amount)
	print("Player healed %d. Current health: %d" % [amount, _current_health])

## Player death logic.
func die() -> void:
	if not GameManager.player_is_alive: return # Prevent multiple death calls

	print("Player has died!")
	GameManager.on_player_death()
	# Disable input and hide player model, play death animation, etc.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# You might want to disable collision, hide mesh, etc.
	set_collision_mask_value(1, false) # Disable collision with layer 1 (world)
	set_collision_layer_value(1, false) # Disable self-collision

## Callback when a body enters the interaction area.
func _on_InteractionArea_body_entered(body: Node3D) -> void:
	if body.has_method("on_player_enter_interaction_area"):
		body.on_player_enter_interaction_area(self)
		print("Player entered interaction area of: ", body.name)

## Callback when a body exits the interaction area.
func _on_InteractionArea_body_exited(body: Node3D) -> void:
	if body.has_method("on_player_exit_interaction_area"):
		body.on_player_exit_interaction_area(self)
		print("Player exited interaction area of: ", body.name)