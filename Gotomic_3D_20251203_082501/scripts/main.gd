class_name Main
extends Node3D

@onready var ui_scene = $UI as UI
@onready var player_node = $Player as Player

func _ready():
	# Connect UI signals to Player node
	if ui_scene and player_node:
		ui_scene.movement_input.connect(player_node.set_movement_input)
		ui_scene.camera_input.connect(player_node.set_camera_input)
		ui_scene.jump_pressed.connect(player_node.jump)
		print("UI signals connected to Player.")
	else:
		if not ui_scene:
			push_error("UI scene not found!")
		if not player_node:
			push_error("Player node not found!")