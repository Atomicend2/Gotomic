class_name TestMap
extends Node3D

#region Exported Variables
@export var player_spawn_point: Marker3D
@export var infected_spawn_points: Array[Marker3D]
@export var spawning_monster_spawn_points: Array[Marker3D]
@export var infected_enemy_scene: PackedScene = preload("res://Enemies/Infected/Enemy.tscn")
@export var spawning_monster_scene: PackedScene = preload("res://Enemies/SpawningMonster/SpawningMonster.tscn")

@export var level_ambient_music: AudioStream = preload("res://Assets/Audio/placeholder_bgm.tres")
#endregion

#region Private Variables
var _audio_player_music: AudioStreamPlayer
var _initial_enemy_count: int = 0
#endregion

func _ready() -> void:
	if GameManager.is_instance_valid(GameManager):
		GameManager.register_level(self)
	
	_setup_ambient_music()
	_spawn_enemies()
	print("TestMap: Ready. Enemies spawned: ", _initial_enemy_count)

func _setup_ambient_music() -> void:
	_audio_player_music = AudioStreamPlayer.new()
	add_child(_audio_player_music)
	_audio_player_music.bus = "Music"
	_audio_player_music.stream = level_ambient_music
	_audio_player_music.autoplay = true
	_audio_player_music.play()

func _spawn_enemies() -> void:
	_initial_enemy_count = 0
	
	for spawn_point in infected_spawn_points:
		if is_instance_valid(infected_enemy_scene) and is_instance_valid(spawn_point):
			var enemy: EnemyAI = infected_enemy_scene.instantiate() as EnemyAI
			if is_instance_valid(enemy):
				add_child(enemy)
				enemy.global_position = spawn_point.global_position
				_initial_enemy_count += 1
			else:
				push_error("TestMap: Failed to instance Infected enemy scene.")
		else:
			push_warning("TestMap: Infected enemy scene or spawn point missing/invalid.")

	for spawn_point in spawning_monster_spawn_points:
		if is_instance_valid(spawning_monster_scene) and is_instance_valid(spawn_point):
			var enemy: SpawningMonsterAI = spawning_monster_scene.instantiate() as SpawningMonsterAI
			if is_instance_valid(enemy):
				add_child(enemy)
				enemy.global_position = spawn_point.global_position
				_initial_enemy_count += 1
			else:
				push_error("TestMap: Failed to instance Spawning Monster scene.")
		else:
			push_warning("TestMap: Spawning Monster scene or spawn point missing/invalid.")