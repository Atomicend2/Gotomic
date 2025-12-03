class_name UIManager
extends Control

# Manages the in-game user interface.

@onready var crosshair: ColorRect = $Crosshair
@onready var debug_label: Label = $DebugLabel

func _ready() -> void:
	# Ensure UI elements are correctly referenced.
	if not is_instance_valid(crosshair):
		push_error("Crosshair (ColorRect) not found for UIManager!")
		set_process(false)
		return
	if not is_instance_valid(debug_label):
		push_error("DebugLabel (Label) not found for UIManager!")
		set_process(false)
		return

	# Set initial visibility.
	crosshair.visible = true
	debug_label.visible = false # Hide by default

	# Connect to GameManager signals for score updates.
	if GameManager:
		GameManager.player_score_changed.connect(on_player_score_changed)

func _process(delta: float) -> void:
	# Example: Update debug info (e.g., FPS, player position).
	# This is a placeholder; actual debug info would be gathered from other nodes.
	# debug_label.text = "FPS: %d\nScore: %d" % [Engine.get_frames_per_second(), GameManager.current_score]
	pass

func toggle_debug_label(visible: bool) -> void:
	# Toggles the visibility of the debug information label.
	debug_label.visible = visible

func on_player_score_changed(new_score: int) -> void:
	# Update the UI when the player's score changes.
	# Example: Update a score display, though not present in this basic UI.
	print("UI Manager: Player score updated to ", new_score)
	# You could update debug_label.text here if it's visible.