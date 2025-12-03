class_name HUD
extends Control

@onready var _mobile_input: MobileInput = get_node("/root/MobileInput")

func _ready() -> void:
	if not is_instance_valid(_mobile_input):
		print("ERROR: MobileInput Autoload is not valid. HUD functionality will be limited.")
		set_process_input(false)
		return

	# Connect movement buttons
	$MovementPanel/UpButton.pressed.connect(Callable(self, "_on_move_button_pressed").bind(Vector2(0, -1)))
	$MovementPanel/UpButton.released.connect(Callable(self, "_on_move_button_released").bind(Vector2(0, -1)))
	$MovementPanel/DownButton.pressed.connect(Callable(self, "_on_move_button_pressed").bind(Vector2(0, 1)))
	$MovementPanel/DownButton.released.connect(Callable(self, "_on_move_button_released").bind(Vector2(0, 1)))
	$MovementPanel/LeftButton.pressed.connect(Callable(self, "_on_move_button_pressed").bind(Vector2(-1, 0)))
	$MovementPanel/LeftButton.released.connect(Callable(self, "_on_move_button_released").bind(Vector2(-1, 0)))
	$MovementPanel/RightButton.pressed.connect(Callable(self, "_on_move_button_pressed").bind(Vector2(1, 0)))
	$MovementPanel/RightButton.released.connect(Callable(self, "_on_move_button_released").bind(Vector2(1, 0)))

	# Connect action buttons
	$ActionPanel/JumpButton.pressed.connect(_mobile_input.set_jump_pressed)
	$ActionPanel/AttackButton.pressed.connect(Callable(_mobile_input, "set_attack_pressed").bind(true))
	$ActionPanel/AttackButton.released.connect(Callable(_mobile_input, "set_attack_pressed").bind(false))

var _active_move_vectors: Array[Vector2] = []

func _on_move_button_pressed(direction: Vector2) -> void:
	if not _active_move_vectors.has(direction):
		_active_move_vectors.append(direction)
	_update_move_vector()

func _on_move_button_released(direction: Vector2) -> void:
	if _active_move_vectors.has(direction):
		_active_move_vectors.erase(direction)
	_update_move_vector()

func _update_move_vector() -> void:
	var combined_vector: Vector2 = Vector2.ZERO
	for vec in _active_move_vectors:
		combined_vector += vec
	_mobile_input.set_move_vector(combined_vector.normalized())