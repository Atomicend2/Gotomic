extends Node3D

## CameraLook.gd
## Manages camera rotation based on mouse/touch input.
## Attached to the Player node, with Camera3D as a child.

@export var sensitivity: float = 0.2 ## Mouse/touch look sensitivity.
@export var min_pitch: float = -90.0 ## Minimum camera pitch (look down).
@export var max_pitch: float = 90.0 ## Maximum camera pitch (look up).

var _current_pitch: float = 0.0 ## Current camera pitch in degrees.

func _ready() -> void:
	# Ensure the input mode is captured for FPS controls
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Captures mouse motion events to rotate the camera.
func _input(event: InputEvent) -> void:
	if not GameManager.game_active or not GameManager.player_is_alive:
		return # Disable camera look if game is over or player is dead

	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			_rotate_camera(event.relative)
		elif event is InputEventScreenDrag:
			_rotate_camera(event.relative)

## Rotates the camera (Node3D itself) and the parent (Player) based on mouse motion.
func _rotate_camera(relative_motion: Vector2) -> void:
	# Rotate the parent (Player) for Y-axis rotation
	var yaw_delta: float = -deg_to_rad(relative_motion.x * sensitivity)
	# Using 'rotate_y' on the parent (Player) will rotate the entire player body
	# along with the camera, which is usually desired for FPS.
	get_parent().rotate_y(yaw_delta)

	# Rotate the camera (this Node3D) for X-axis (pitch) rotation
	_current_pitch += relative_motion.y * sensitivity
	_current_pitch = clampi(_current_pitch, min_pitch, max_pitch)

	rotation.x = deg_to_rad(_current_pitch)