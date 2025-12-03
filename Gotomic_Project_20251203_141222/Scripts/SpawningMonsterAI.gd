class_name SpawningMonsterAI
extends EnemyAI

#region Exported Variables
@export var projectile_scene: PackedScene = preload("res://Scenes/BulletProjectile.tscn")
@export var projectile_speed: float = 20.0
@export var projectile_spawn_offset: Vector3 = Vector3(0, 1.0, 0.5) # Relative to monster
#endregion

func _ready() -> void:
	super._ready()
	# Override specific settings for Spawning Monster
	chase_speed_multiplier = 2.0
	attack_range = 10.0 # Ranged attack
	attack_cooldown = 2.0

func _perform_attack() -> void:
	if not is_instance_valid(_player_target):
		return
	
	if global_position.distance_to(_player_target.global_position) <= attack_range:
		print(name, ": Ranged attacking player!")
		if is_instance_valid(_audio_player) and attack_sound_stream:
			_audio_player.stream = attack_sound_stream
			_audio_player.play()
		_shoot_projectile()
		# No direct damage to player, projectile handles that.
		
func _shoot_projectile() -> void:
	if not is_instance_valid(projectile_scene) or not is_instance_valid(_player_target):
		return

	var projectile_instance: BulletProjectile = projectile_scene.instantiate() as BulletProjectile
	if not is_instance_valid(projectile_instance):
		push_error(name, ": Failed to instance projectile scene!")
		return

	get_tree().current_scene.add_child(projectile_instance)

	var spawn_pos: Vector3 = global_position + global_transform.basis * projectile_spawn_offset
	var target_dir: Vector3 = (_player_target.global_position - spawn_pos).normalized()

	projectile_instance.global_transform.origin = spawn_pos
	projectile_instance.shoot(target_dir * projectile_speed, attack_damage, self)

	print(name, ": Fired projectile.")