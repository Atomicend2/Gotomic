extends Node3D

## GunSystem.gd
## Manages weapon firing, ammo, and cooldown logic.

@export var damage: int = 10 ## Damage dealt per shot.
@export var fire_rate: float = 0.2 ## Time between shots in seconds.
@export var max_ammo: int = 30 ## Maximum ammunition capacity.
@export var reload_time: float = 2.0 ## Time it takes to reload.
@export var bullet_spread_degrees: float = 0.5 ## Max bullet spread angle in degrees.

@onready var _ray_cast: RayCast3D = $RayCast3D as RayCast3D
@onready var _shoot_audio: AudioStreamPlayer3D = $ShootSound as AudioStreamPlayer3D
@onready var _hit_audio: AudioStreamPlayer3D = $HitSound as AudioStreamPlayer3D
@onready var _animation_player: AnimationPlayer = $AnimationPlayer as AnimationPlayer

var _current_ammo: int = max_ammo:
	set(value):
		var old_ammo = _current_ammo
		_current_ammo = clampi(value, 0, max_ammo)
		if _current_ammo != old_ammo:
			ammo_changed.emit(_current_ammo)

var _can_fire: bool = true
var _is_reloading: bool = false
var _shooter_node: Node3D # Reference to the node that owns this gun (e.g., PlayerController)

signal ammo_changed(new_ammo: int)
signal fired_shot
signal reloaded
signal started_reloading
signal stopped_reloading

func _ready() -> void:
	_current_ammo = max_ammo
	_can_fire = true
	ammo_changed.emit(_current_ammo)

	if not is_instance_valid(_ray_cast):
		printerr("RayCast3D node not found for gun system!")
		set_physics_process(false) # Disable if essential nodes are missing

## Sets the node that is "shooting" this gun, for ignoring self in raycasts.
func set_shooter_node(node: Node3D) -> void:
	_shooter_node = node
	if is_instance_valid(_ray_cast):
		_ray_cast.add_exception(_shooter_node)

## Attempts to fire the weapon.
func shoot() -> void:
	if not _can_fire or _is_reloading or _current_ammo <= 0 or not GameManager.game_active:
		return

	_current_ammo -= 1
	fired_shot.emit()

	# Play shoot animation
	if is_instance_valid(_animation_player):
		if _animation_player.has_animation("Shoot"):
			_animation_player.play("Shoot")
		else:
			print("Warning: 'Shoot' animation not found for GunSystem.")

	# Play shoot sound
	if is_instance_valid(_shoot_audio):
		_shoot_audio.play()

	_perform_raycast_shot()

	_can_fire = false
	await get_tree().create_timer(fire_rate).timeout
	_can_fire = true

## Performs the raycast to detect hits.
func _perform_raycast_shot() -> void:
	if not is_instance_valid(_ray_cast): return

	# Apply bullet spread
	var original_transform: Transform3D = _ray_cast.global_transform
	var spread_x: float = randf_range(-1.0, 1.0) * bullet_spread_degrees
	var spread_y: float = randf_range(-1.0, 1.0) * bullet_spread_degrees
	_ray_cast.rotate_x(deg_to_rad(spread_x))
	_ray_cast.rotate_y(deg_to_rad(spread_y))

	_ray_cast.force_raycast_update() # Ensure raycast is updated instantly

	if _ray_cast.is_colliding():
		var collider: Node3D = _ray_cast.get_collider() as Node3D
		var hit_position: Vector3 = _ray_cast.get_collision_point()
		var hit_normal: Vector3 = _ray_cast.get_collision_normal()

		print("Hit: ", collider.name, " at ", hit_position)

		# Play hit sound
		if is_instance_valid(_hit_audio):
			_hit_audio.global_position = hit_position
			_hit_audio.play()

		# Notify the hit object it has been damaged
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(damage)
		
		# Instantiate a simple explosion effect at hit point
		_spawn_explosion_effect(hit_position)
	else:
		print("Missed.")

	# Reset raycast transform
	_ray_cast.global_transform = original_transform

## Spawns a temporary explosion effect at the hit position.
func _spawn_explosion_effect(position: Vector3) -> void:
	var explosion_effect_scene: PackedScene = preload("res://scenes/ExplosionEffect.tscn")
	if explosion_effect_scene:
		var effect: GPUParticles3D = explosion_effect_scene.instantiate() as GPUParticles3D
		if is_instance_valid(effect):
			get_tree().root.add_child(effect)
			effect.global_position = position
			effect.emitting = true
			await get_tree().create_timer(1.0).timeout # Auto-queue_free after a short duration
			if is_instance_valid(effect):
				effect.queue_free()

## Initiates the reload process.
func reload() -> void:
	if _is_reloading or _current_ammo == max_ammo or not GameManager.game_active:
		return

	_is_reloading = true
	started_reloading.emit()
	print("Reloading...")

	# Play reload animation
	if is_instance_valid(_animation_player):
		if _animation_player.has_animation("Reload"):
			_animation_player.play("Reload")
		else:
			print("Warning: 'Reload' animation not found for GunSystem.")

	await get_tree().create_timer(reload_time).timeout
	_current_ammo = max_ammo
	_is_reloading = false
	reloaded.emit()
	stopped_reloading.emit()
	print("Reload complete. Ammo: %d" % _current_ammo)

## Gets the current ammo count.
func get_current_ammo() -> int:
	return _current_ammo

## Gets the max ammo count.
func get_max_ammo() -> int:
	return max_ammo