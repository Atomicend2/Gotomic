extends CharacterBody3D

class_name EnemyAI

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	DEAD
}

signal enemy_died
signal enemy_health_changed(new_health: int, old_health: int)

@export var health_component: HealthComponent
@export var navigation_agent: NavigationAgent3D
@export var sight_range: float = 20.0
@export var attack_range: float = 5.0
@export var patrol_speed: float = 3.0
@export var chase_speed: float = 6.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var patrol_points: Array[Node3D] # Assign these in the editor
@export var patrol_wait_time: float = 2.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var ray_cast_player_check: RayCast3D = $RayCastPlayerCheck # Used for line of sight
@onready var attack_timer: Timer = $AttackTimer
@onready var patrol_wait_timer: Timer = $PatrolWaitTimer

var _current_state: State = State.IDLE
var _target_player: PlayerController = null
var _current_patrol_point_index: int = 0
var _can_attack: bool = true

func _ready() -> void:
	if not health_component:
		push_error("EnemyAI: HealthComponent not assigned!")
		set_process(false)
		return
	if not navigation_agent:
		push_error("EnemyAI: NavigationAgent3D not assigned!")
		set_process(false)
		return

	health_component.died.connect(_on_died)
	health_component.health_changed.connect(enemy_health_changed)
	
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 0.5
	
	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_on_attack_cooldown_timeout)
	
	patrol_wait_timer.wait_time = patrol_wait_time
	patrol_wait_timer.one_shot = true
	patrol_wait_timer.timeout.connect(_on_patrol_wait_timeout)

	set_state(State.PATROL) # Start patrolling

func _physics_process(delta: float) -> void:
	if health_component.is_dead():
		set_state(State.DEAD)
		return

	_handle_state(delta)
	
	if navigation_agent.is_navigation_finished():
		velocity = velocity.move_toward(Vector3.ZERO, 2.0 * delta)
	
	move_and_slide()

func set_state(new_state: State) -> void:
	if _current_state == new_state:
		return

	_current_state = new_state
	_on_exit_state(_current_state) # Call exit for old state (if needed, simplified for this example)
	_on_enter_state(new_state)

func _on_enter_state(state: State) -> void:
	match state:
		State.IDLE:
			play_animation("idle")
			velocity = Vector3.ZERO
		State.PATROL:
			play_animation("walk")
			_start_patrol()
		State.CHASE:
			play_animation("run")
		State.ATTACK:
			play_animation("attack")
			velocity = Vector3.ZERO
		State.DEAD:
			play_animation("die")
			collision_layer = 0
			collision_mask = 0
			navigation_agent.velocity = Vector3.ZERO
			navigation_agent.set_navigation_map(null) # Remove from navigation
			set_physics_process(false)

func _on_exit_state(state: State) -> void:
	match state:
		State.PATROL:
			patrol_wait_timer.stop()
		State.ATTACK:
			attack_timer.stop()


func _handle_state(delta: float) -> void:
	_target_player = _find_player() # Always try to find the player

	match _current_state:
		State.IDLE:
			_idle_state(delta)
		State.PATROL:
			_patrol_state(delta)
		State.CHASE:
			_chase_state(delta)
		State.ATTACK:
			_attack_state(delta)
		State.DEAD:
			pass # No actions needed in dead state

func _find_player() -> PlayerController:
	# A simplified way to find the player. In a real game, use groups or a game manager.
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node and player_node is PlayerController:
		return player_node as PlayerController
	return null

func _can_see_player(player: PlayerController) -> bool:
	if not player:
		return false
	
	var player_pos: Vector3 = player.global_position + Vector3(0, 0.8, 0) # Eye level
	var my_pos: Vector3 = global_position + Vector3(0, 0.8, 0) # Eye level
	
	if my_pos.distance_to(player_pos) > sight_range:
		return false
	
	ray_cast_player_check.global_position = my_pos
	ray_cast_player_check.target_position = ray_cast_player_check.to_local(player_pos)
	ray_cast_player_check.force_raycast_update()
	
	if ray_cast_player_check.is_colliding():
		var collider: Object = ray_cast_player_check.get_collider()
		return collider == player or (collider is CharacterBody3D and (collider as CharacterBody3D).get_node_or_null("PlayerController") != null)
	return false

func _idle_state(delta: float) -> void:
	if _target_player and _can_see_player(_target_player):
		set_state(State.CHASE)
	elif patrol_points.is_empty():
		# If no patrol points, stay idle (or transition to a fixed guard position)
		pass
	elif not patrol_wait_timer.is_stopped():
		# Waiting to start patrol
		pass
	else:
		set_state(State.PATROL)

func _start_patrol() -> void:
	if patrol_points.is_empty():
		set_state(State.IDLE)
		return
	
	var target_point: Vector3 = patrol_points[_current_patrol_point_index].global_position
	navigation_agent.target_position = target_point
	play_animation("walk")

func _patrol_state(delta: float) -> void:
	if _target_player and _can_see_player(_target_player):
		set_state(State.CHASE)
		return

	if navigation_agent.is_navigation_finished():
		patrol_wait_timer.start()
		set_state(State.IDLE) # Briefly enter idle to wait
	
	if navigation_agent.is_navigation_blocked():
		# Handle being blocked, e.g., re-path or find new point
		_current_patrol_point_index = (_current_patrol_point_index + 1) % patrol_points.size()
		_start_patrol()
		
	_move_towards_navigation_target(patrol_speed, delta)

func _on_patrol_wait_timeout() -> void:
	_current_patrol_point_index = (_current_patrol_point_index + 1) % patrol_points.size()
	set_state(State.PATROL)

func _chase_state(delta: float) -> void:
	if not _target_player or not _can_see_player(_target_player):
		set_state(State.PATROL) # Lost sight, go back to patrol
		return
	
	navigation_agent.target_position = _target_player.global_position
	_move_towards_navigation_target(chase_speed, delta)
	
	# Look at target while chasing
	var look_at_target = Vector3(_target_player.global_position.x, global_position.y, _target_player.global_position.z)
	look_at(look_at_target, Vector3.UP)
	
	if global_position.distance_to(_target_player.global_position) <= attack_range:
		set_state(State.ATTACK)

func _attack_state(delta: float) -> void:
	if not _target_player or not _can_see_player(_target_player):
		set_state(State.CHASE) # Lost sight or target moved out of range
		return
	
	# Keep looking at the target
	var look_at_target = Vector3(_target_player.global_position.x, global_position.y, _target_player.global_position.z)
	look_at(look_at_target, Vector3.UP)

	# If player moves out of attack range, chase again
	if global_position.distance_to(_target_player.global_position) > attack_range + 0.5: # Add small buffer
		set_state(State.CHASE)
		return
	
	velocity = Vector3.ZERO # Stop moving when attacking
	
	if _can_attack:
		_perform_attack()
		_can_attack = false
		attack_timer.start() # Start cooldown

func _perform_attack() -> void:
	print("Enemy attacking player!")
	if _target_player and _target_player.health_component:
		_target_player.health_component.take_damage(attack_damage)
	play_animation("attack") # Play attack animation each time

func _on_attack_cooldown_timeout() -> void:
	_can_attack = true

func _move_towards_navigation_target(speed: float, delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		return
	
	var next_point: Vector3 = navigation_agent.get_next_path_position()
	var direction: Vector3 = global_position.direction_to(next_point)
	var desired_velocity: Vector3 = direction * speed

	navigation_agent.set_velocity(desired_velocity)

	# Rotate towards movement direction (Y-axis only)
	if direction.length_squared() > 0.01:
		var target_rotation: float = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 5.0)

func _on_velocity_computed(current_velocity: Vector3) -> void:
	velocity = current_velocity

func _on_died() -> void:
	print("Enemy Died!")
	set_state(State.DEAD)
	enemy_died.emit()
	# Optional: Remove the enemy or despawn after a delay
	# queue_free() # For example

func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	elif animation_player:
		print("Warning: Animation '", anim_name, "' not found for enemy.")

