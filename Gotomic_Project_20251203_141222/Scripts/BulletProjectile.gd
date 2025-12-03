class_name BulletProjectile
extends RayCast3D

#region Signals
signal hit_target(collider: Object, position: Vector3, normal: Vector3)
#endregion

#region Exported Variables
@export var speed: float = 50.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0 # Max time before despawning
@export var trail_mesh_instance: MeshInstance3D
@export var impact_effect_scene: PackedScene = preload("res://Scenes/BulletHitFX.tscn")
#endregion

#region Private Variables
var _direction: Vector3
var _timer: Timer
var _has_hit: bool = false
var _shooter: Node3D
#endregion

func _ready() -> void:
	enabled = true
	collide_with_areas = true
	collide_with_bodies = true
	
	# Collision mask for enemy bullets: World, Player
	collision_mask = (1 << 1) | (1 << 2)
	exclude_parent = true # Exclude the projectile itself if it has a collider (e.g. Area3D)

	_timer = Timer.new()
	add_child(_timer)
	_timer.one_shot = true
	_timer.wait_time = lifetime
	_timer.timeout.connect(Callable(self, "queue_free"))
	_timer.start()

func shoot(initial_velocity: Vector3, base_damage: float, shooter_node: Node3D) -> void:
	_direction = initial_velocity.normalized()
	speed = initial_velocity.length()
	damage = base_damage
	_shooter = shooter_node
	
	if is_instance_valid(trail_mesh_instance):
		trail_mesh_instance.rotation = Vector3.ZERO
		trail_mesh_instance.look_at(global_position + _direction)
	
	print("Projectile shot with damage: ", damage)

func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	var current_pos: Vector3 = global_position
	var target_pos: Vector3 = current_pos + _direction * speed * delta
	
	target_position = target_pos - current_pos # Raycast target is relative to origin

	force_raycast_update()

	if is_colliding():
		var collider: Object = get_collider()
		var hit_position: Vector3 = get_collision_point()
		var hit_normal: Vector3 = get_collision_normal()
		
		# Prevent hitting the shooter itself immediately
		if collider == _shooter:
			return

		hit_target.emit(collider, hit_position, hit_normal)
		_handle_hit(collider, hit_position, hit_normal)
		_has_hit = true
		queue_free() # Destroy projectile after hitting

	else:
		global_position = target_pos
		# Update trail mesh position/rotation
		if is_instance_valid(trail_mesh_instance):
			trail_mesh_instance.global_position = global_position
			trail_mesh_instance.look_at(global_position + _direction, Vector3.UP)

func _handle_hit(collider: Object, position: Vector3, normal: Vector3) -> void:
	# Spawn impact effect
	_spawn_impact_effect(position, normal)

	if collider is CharacterBody3D and collider.is_in_group("player"):
		var player_body: CharacterBody3D = collider as CharacterBody3D
		if is_instance_valid(player_body) and player_body.has_method("take_damage"):
			player_body.take_damage(damage)
			print("Player hit! Took ", damage, " damage from enemy projectile.")
	elif collider is CharacterBody3D and collider.is_in_group("enemies"):
		# Enemy projectiles hitting enemies should not cause damage in this game, or should have specific logic
		pass # Enemy bullets don't damage other enemies
	else:
		# Generic hit on world object
		print("Projectile hit: ", collider.name if collider else "World", " at ", position)

func _spawn_impact_effect(position: Vector3, normal: Vector3) -> void:
	if not impact_effect_scene:
		return
	var hit_fx_instance: CPUParticles3D = impact_effect_scene.instantiate() as CPUParticles3D
	if not is_instance_valid(hit_fx_instance):
		return
	get_tree().current_scene.add_child(hit_fx_instance)
	hit_fx_instance.global_position = position
	hit_fx_instance.look_at(position + normal, Vector3.UP) # Align particles with hit normal
	hit_fx_instance.emitting = true # Start emission
	
	# Autodelete after particles finish
	var timer: Timer = get_tree().create_timer(hit_fx_instance.lifetime + hit_fx_instance.preprocess)
	timer.timeout.connect(hit_fx_instance.queue_free)