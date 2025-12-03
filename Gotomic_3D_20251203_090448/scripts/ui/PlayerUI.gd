extends Control

## PlayerUI.gd
## Manages the display of player health, ammo, and resources on the UI.

@onready var health_label: Label = $HUD/HealthPanel/HealthLabel as Label
@onready var ammo_label: Label = $HUD/AmmoPanel/AmmoLabel as Label
@onready var resource_container: HBoxContainer = $HUD/ResourcePanel as HBoxContainer
@onready var game_over_panel: PanelContainer = $GameOverPanel as PanelContainer
@onready var game_over_label: Label = $GameOverPanel/VBoxContainer/GameOverLabel as Label
@onready var retry_button: Button = $GameOverPanel/VBoxContainer/RetryButton as Button

var player_controller: PlayerController = null ## Reference to the player controller.
var current_gun_system: GunSystem = null ## Reference to the current gun system.

func _ready() -> void:
	game_over_panel.visible = false
	
	# Connect to GameManager for global events
	GameManager.game_started.connect(self._on_game_started)
	GameManager.game_over.connect(self._on_game_over)
	
	# Connect to ResourceManager for resource updates
	ResourceManager.resource_changed.connect(self._on_resource_changed)
	
	# Connect retry button
	if is_instance_valid(retry_button):
		retry_button.pressed.connect(self._on_retry_button_pressed)
	
	# Find player and gun to connect their signals
	await get_tree().create_timer(0.1).timeout # Wait for Main.tscn to instantiate player
	_find_player_and_gun()

## Attempts to find the PlayerController and GunSystem nodes.
func _find_player_and_gun() -> void:
	player_controller = get_tree().get_first_node_in_group("players") as PlayerController
	if is_instance_valid(player_controller):
		player_controller.health_changed.connect(self._on_player_health_changed)
		_on_player_health_changed(player_controller._current_health) # Initial update
		
		# Get the gun system from the player (assuming a fixed path for now)
		current_gun_system = player_controller.find_child("Gun", true, false) as GunSystem
		if is_instance_valid(current_gun_system):
			current_gun_system.ammo_changed.connect(self._on_gun_ammo_changed)
			_on_gun_ammo_changed(current_gun_system.get_current_ammo()) # Initial update
		else:
			printerr("PlayerUI: GunSystem not found on player!")
	else:
		printerr("PlayerUI: PlayerController not found in 'players' group!")

## Callback for GameManager.game_started.
func _on_game_started() -> void:
	game_over_panel.visible = false
	if is_instance_valid(player_controller):
		_on_player_health_changed(player_controller._current_health)
	if is_instance_valid(current_gun_system):
		_on_gun_ammo_changed(current_gun_system.get_current_ammo())
	for resource_name in ResourceManager.resources.keys():
		_on_resource_changed(resource_name, ResourceManager.get_resource_amount(resource_name))

## Callback for GameManager.game_over.
func _on_game_over() -> void:
	game_over_label.text = "GAME OVER!\nScore: %d" % GameManager.score
	game_over_panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Release mouse for UI interaction

## Callback for player health changes.
func _on_player_health_changed(new_health: int) -> void:
	if is_instance_valid(health_label):
		health_label.text = "Health: %d / %d" % [new_health, player_controller.max_health]

## Callback for gun ammo changes.
func _on_gun_ammo_changed(new_ammo: int) -> void:
	if is_instance_valid(ammo_label) and is_instance_valid(current_gun_system):
		ammo_label.text = "Ammo: %d / %d" % [new_ammo, current_gun_system.max_ammo]

## Callback for ResourceManager.resource_changed.
func _on_resource_changed(resource_name: String, new_amount: int) -> void:
	if not is_instance_valid(resource_container): return

	var label_name: String = "ResourceLabel_" + resource_name
	var resource_label: Label = resource_container.find_child(label_name) as Label

	if not is_instance_valid(resource_label):
		# Create a new label if it doesn't exist
		resource_label = Label.new()
		resource_label.name = label_name
		resource_container.add_child(resource_label)
		# Optional: Add a custom font/style here

	resource_label.text = "%s: %d" % [resource_name, new_amount]

## Callback for Retry Button pressed.
func _on_retry_button_pressed() -> void:
	# Reload the main scene to restart the game
	get_tree().reload_current_scene()
	GameManager.start_game()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)