extends Node3D

## Interactable door logic.

@export var open_angle: float = 90.0
@export var open_speed: float = 2.0 # Degrees per second

@onready var door_pivot: Node3D = $DoorPivot
@onready var interaction_area: Area3D = $InteractionArea

enum State { CLOSED, OPENING, OPENED, CLOSING }
var current_state: State = State.CLOSED
var target_rotation: float = 0.0

func _ready() -> void:
	interaction_area.body_entered.connect(_on_InteractionArea_body_entered)
	interaction_area.body_exited.connect(_on_InteractionArea_body_exited)

func _process(delta: float) -> void:
	match current_state:
		State.OPENING:
			rotate_door(open_angle, delta)
		State.CLOSING:
			rotate_door(0.0, delta)

func rotate_door(target_rot_y_deg: float, delta: float) -> void:
	var current_rot_y_deg = rad_to_deg(door_pivot.rotation.y)
	
	if abs(current_rot_y_deg - target_rot_y_deg) < 0.1: # Close enough to target
		door_pivot.rotation.y = deg_to_rad(target_rot_y_deg)
		current_state = State.OPENED if target_rot_y_deg > 0 else State.CLOSED
		return
	
	var direction = 1 if target_rot_y_deg > current_rot_y_deg else -1
	var rotation_amount = deg_to_rad(open_speed * delta) * direction
	
	door_pivot.rotation.y += rotation_amount
	door_pivot.rotation.y = clamp(door_pivot.rotation.y, deg_to_rad(0.0), deg_to_rad(open_angle))
	
	if (direction == 1 and door_pivot.rotation.y >= deg_to_rad(target_rot_y_deg)) or \
	   (direction == -1 and door_pivot.rotation.y <= deg_to_rad(target_rot_y_deg)):
		door_pivot.rotation.y = deg_to_rad(target_rot_y_deg)
		current_state = State.OPENED if target_rot_y_deg > 0 else State.CLOSED

func interact() -> void:
	if current_state == State.CLOSED:
		current_state = State.OPENING
		print("Opening door.")
	elif current_state == State.OPENED:
		current_state = State.CLOSING
		print("Closing door.")
	# Ignore interaction if already opening/closing

func _on_InteractionArea_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "Player":
		print("Player entered door interaction area.")
		# Show interaction prompt if needed
		# For this simple demo, we just print

func _on_InteractionArea_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "Player":
		print("Player exited door interaction area.")
		# Hide interaction prompt