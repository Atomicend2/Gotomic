extends CharacterBody3D

const SPEED: float = 3.0
const JUMP_VELOCITY: float = 4.5
const GRAVITY: float = 9.8
const FIRE_RANGE: float = 15.0
const PATROL_RADIUS: float = 10.0

@export var health: int = 100
@export var bullet_scene: PackedScene

var _target: CharacterBody3D
var _patrol_points: Array[Vector3]
var _current_patrol_point_index: int = 0
var _can_see_player: bool = false
var _is_shooting: bool = false

@onready var _navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _ray_cast: RayCast3D = $Head/RayCast3D
@onready var _shoot_timer: Timer = $ShootTimer
@onready var _weapon_muzzle: Node3D = $Head/WeaponMuzzle

func _ready() -> void:
	# Add self to Global tracking
	Global.register_enemy()
	
	_shoot_timer.timeout.connect(_on_shoot_timer_timeout) # Ensure connection is made
	
	# Generate some random patrol points around initial position
	for i in range(3):
		_patrol_points.append(global_transform.origin + Vector3(
			randf_range(-PATROL_RADIUS, PATROL_RADIUS),
			0,
			randf_range(-PATROL_RADIUS, PATROL_RADIUS)
		))
	
	if not _patrol_points.is_empty():
		set_new_target_location(_patrol_points[_current_patrol_point_index])

func _physics_process(delta: float) -> void:
	if Global.player_is_dead:
		# Stop all enemy activity if player is dead
		_navigation_agent.velocity = Vector3.ZERO
		velocity = Vector3.ZERO
		return
		
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Check for player visibility
	_check_player_visibility()

	var new_velocity: Vector3 = Vector3.ZERO
	if _can_see_player and _target:
		# Chase player
		var direction_to_player: Vector3 = (_target.global_transform.origin - global_transform.origin).normalized()
		
		# Look at the player, only rotate around Y-axis
		var target_look_at: Vector3 = _target.transform.origin
		target_look_at.y = global_transform.origin.y
		look_at(target_look_at, Vector3.UP)
		
		var distance_to_player: float = global_transform.origin.distance_to(_target.global_transform.origin)
		
		if distance_to_player > FIRE_RANGE * 0.8: # Move closer if too far
			set_new_target_location(_target.global_transform.origin)
			var next_point: Vector3 = _navigation_agent.get_next_path_position()
			new_velocity = (next_point - global_transform.origin).normalized() * SPEED
		else: # Stop and shoot if in range
			new_velocity = Vector3.ZERO
			if not _is_shooting:
				_shoot_timer.start() # Start shooting if not already
				_is_shooting = true
	else:
		# Patrol
		var next_point: Vector3 = _navigation_agent.get_next_path_position()
		new_velocity = (next_point - global_transform.origin).normalized() * SPEED
		
		# If patrol target is reached, find next one
		if global_transform.origin.distance_to(_navigation_agent.target_location) < _navigation_agent.target_desired_distance:
			_next_patrol_point()
		
		_is_shooting = false # Stop shooting if player is not seen

	velocity.x = new_velocity.x
	velocity.z = new_velocity.z
	move_and_slide()

func set_new_target_location(target_location: Vector3) -> void:
	if _navigation_agent.is_navigation_finished():
		_navigation_agent.set_target_location(target_location)
	else:
		_navigation_agent.set_target_location(target_location)

func _next_patrol_point() -> void:
	if _patrol_points.is_empty():
		return
	_current_patrol_point_index = (_current_patrol_point_index + 1) % _patrol_points.size()
	set_new_target_location(_patrol_points[_current_patrol_point_index])

func _check_player_visibility() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_can_see_player = false
		_target = null
		return

	var player: CharacterBody3D = players[0] as CharacterBody3D
	_ray_cast.target_position = _ray_cast.to_local(player.global_transform.origin + Vector3(0, 0.5, 0)) # Aim at player's chest level
	_ray_cast.force_raycast_update()

	if _ray_cast.is_colliding():
		var collider: Object = _ray_cast.get_collider()
		if collider == player:
			_can_see_player = true
			_target = player
			return

	_can_see_player = false
	_target = null

func _on_shoot_timer_timeout() -> void:
	if _can_see_player and _target:
		shoot()
	else:
		_is_shooting = false
		_shoot_timer.stop() # Stop timer if player is not seen

func shoot() -> void:
	if bullet_scene and _target:
		var new_bullet: CharacterBody3D = bullet_scene.instantiate() as CharacterBody3D
		var start_pos: Vector3 = _weapon_muzzle.global_transform.origin
		var target_pos: Vector3 = _target.global_transform.origin + Vector3(0, 0.5, 0) # Aim at player's chest
		var bullet_direction: Vector3 = (target_pos - start_pos).normalized()
		new_bullet.global_transform.origin = start_pos
		new_bullet.direction = bullet_direction
		get_parent().add_child(new_bullet)

func take_damage(amount: int) -> void:
	if health <= 0:
		return

	health -= amount
	print("Enemy took %d damage. Health: %d" % [amount, health])

	if health <= 0:
		die()

func die() -> void:
	print("Enemy died.")
	Global.enemy_was_defeated()
	queue_free()

func _on_navigation_agent_3d_navigation_finished() -> void:
	if not _can_see_player: # Only switch patrol point if not chasing player
		_next_patrol_point()

