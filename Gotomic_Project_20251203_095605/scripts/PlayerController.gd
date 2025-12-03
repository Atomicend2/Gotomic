class_name PlayerController
extends CharacterBody3D

signal jumped
signal attacked

const JUMP_VELOCITY: float = 4.5
const ACCELERATION_SMOOTHING: float = 0.1

@export var speed: float = 5.0
@export var acceleration_strength: float = 10.0

@onready var _camera: Camera3D = $Camera3D
@onready var _mobile_input: MobileInput = get_node("/root/MobileInput")

var _current_horizontal_velocity: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	if not is_instance_valid(_mobile_input):
		print("ERROR: MobileInput Autoload is not valid.")
		set_physics_process(false)
		return

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Handle jump input
	if _mobile_input.is_jump_pressed() and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jumped.emit()

	var input_dir: Vector2 = _mobile_input.get_move_vector()
	var direction: Vector3 = (_camera.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		_current_horizontal_velocity = _current_horizontal_velocity.lerp(
			direction * speed,
			1.0 - exp(-delta * acceleration_strength)
		)
	else:
		_current_horizontal_velocity = _current_horizontal_velocity.lerp(
			Vector3.ZERO,
			1.0 - exp(-delta * acceleration_strength)
		)

	velocity.x = _current_horizontal_velocity.x
	velocity.z = _current_horizontal_velocity.z
	
	move_and_slide()

	if _mobile_input.is_attack_pressed():
		attacked.emit()
		# Add placeholder attack logic here, e.g., print a message
		print("Player attacked!")
		_mobile_input.reset_attack() # Reset attack state after processing