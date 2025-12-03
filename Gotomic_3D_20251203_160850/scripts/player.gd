extends CharacterBody3D

const SPEED: float = 5.0
const SPRINT_SPEED: float = 8.0
const JUMP_VELOCITY: float = 8.0
const MOUSE_SENSITIVITY: float = 0.002 # For desktop mouse input

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var health: int = 100
@export var max_ammo: int = 30
@export var current_ammo: int = 30
@export var bullet_scene: PackedScene

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _weapon_muzzle: Node3D = $Head/WeaponMuzzle
@onready var _shoot_timer: Timer = $ShootTimer
@onready var _reload_timer: Timer = $ReloadTimer
@onready var _animation_player: AnimationPlayer = $AnimationPlayer

var _can_shoot: bool = true
var _is_reloading: bool = false
var _is_firing_held: bool = false # For continuous firing

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Global.player_health_changed.emit(health)
	Global.player_ammo_changed.emit(current_ammo, max_ammo)

func _input(event: InputEvent) -> void:
	if Global.player_is_dead:
		return
		
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_head.rotate_x(deg_to_rad(-event.relative.y * MOUSE_SENSITIVITY))
			rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENSITIVITY))
			
			_head.rotation.x = clampf(_head.rotation.x, deg_to_rad(-90), deg_to_rad(90))

	if event.is_action_pressed("shoot"):
		_is_firing_held = true
		try_shoot()
	if event.is_action_released("shoot"):
		_is_firing_held = false

func _physics_process(delta: float) -> void:
	if Global.player_is_dead:
		velocity = Vector3.ZERO
		return
		
	# Handle continuous firing if button is held
	if _is_firing_held:
		try_shoot()

	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_on_floor() and direction == Vector3.ZERO:
		velocity.x = lerpf(velocity.x, 0.0, 0.1)
		velocity.z = lerpf(velocity.z, 0.0, 0.1)
	else:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED

	move_and_slide()

func try_shoot() -> void:
	if _can_shoot and current_ammo > 0 and not _is_reloading:
		shoot()
		_can_shoot = false
		_shoot_timer.start()
		current_ammo -= 1
		Global.player_ammo_changed.emit(current_ammo, max_ammo)
		_animation_player.play("shoot_recoil")
		
		if current_ammo == 0:
			reload()

func shoot() -> void:
	if bullet_scene:
		var new_bullet: CharacterBody3D = bullet_scene.instantiate() as CharacterBody3D
		new_bullet.global_transform = _weapon_muzzle.global_transform
		new_bullet.direction = -_weapon_muzzle.global_transform.basis.z # Bullet shoots forward from muzzle
		get_parent().add_child(new_bullet)

func reload() -> void:
	if _is_reloading or current_ammo == max_ammo:
		return
	
	_is_reloading = true
	print("Reloading...")
	_reload_timer.start()

func take_damage(amount: int) -> void:
	if health <= 0:
		return

	health -= amount
	health = maxi(0, health) # Ensure health doesn't go below 0
	Global.player_health_changed.emit(health)
	print("Player took %d damage. Health: %d" % [amount, health])

	if health <= 0:
		die()

func die() -> void:
	print("Player died.")
	Global.game_over()
	# Prevent further input processing and movement
	set_process_input(false)
	set_physics_process(false)
	_camera.set_as_top_level(true) # Detach camera for a death cinematic or specific view
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Release mouse

func _on_shoot_timer_timeout() -> void:
	_can_shoot = true

func _on_reload_timer_timeout() -> void:
	current_ammo = max_ammo
	_is_reloading = false
	Global.player_ammo_changed.emit(current_ammo, max_ammo)
	print("Reload complete. Ammo: %d/%d" % [current_ammo, max_ammo])
