class_name HUD
extends CanvasLayer

@onready var health_label = $HealthLabel
@onready var game_over_label = $GameOverLabel

func _ready():
	game_over_label.visible = false

func update_health(current_health: int, max_health: int):
	health_label.text = "HP: %d / %d" % [current_health, max_health]

func show_game_over():
	game_over_label.visible = true