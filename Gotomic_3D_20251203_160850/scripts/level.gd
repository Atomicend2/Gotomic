extends Node3D

@export var enemy_scene: PackedScene
@export var player_spawn_path: NodePath = "PlayerSpawn"
@export var enemy_spawns_path: NodePath = "EnemySpawns"

@onready var _player: CharacterBody3D = get_node(player_spawn_path).get_child(0) as CharacterBody3D
@onready var _enemy_spawns: Node3D = get_node(enemy_spawns_path)

func _ready() -> void:
	Global.reset_game_state()
	Global.enemy_defeated.connect(_on_enemy_defeated)
	Global.player_health_changed.connect(_on_player_health_changed_in_level)
	
	spawn_enemies()
	
	# Initial navigation mesh bake for enemies
	var nav_region: NavigationRegion3D = $NavigationRegion3D as NavigationRegion3D
	if nav_region:
		nav_region.bake_navigation_mesh(true)
	else:
		printerr("NavigationRegion3D not found!")

func spawn_enemies() -> void:
	for child in _enemy_spawns.get_children():
		if child is Node3D:
			var enemy_instance: CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
			enemy_instance.global_transform.origin = child.global_transform.origin
			add_child(enemy_instance)
	
	Global.update_objective_text() # Update objective after all enemies are registered

func _on_enemy_defeated() -> void:
	# This signal is emitted by Global, which already updates the count.
	# We just need to check if all enemies are defeated.
	if Global.current_enemies_defeated >= Global.total_enemies_in_level:
		_win_game()

func _on_player_health_changed_in_level(new_health: int) -> void:
	if new_health <= 0 and not Global.player_is_dead:
		Global.game_over()
		get_tree().paused = true # Pause the game

func _win_game() -> void:
	Global.mission_objective_changed.emit("MISSION COMPLETE!")
	get_tree().paused = true # Pause the game
	# Optionally display a "You Win" screen
	print("MISSION COMPLETE! All enemies defeated.")

