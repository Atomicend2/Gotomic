class_name EnemyAI
extends CharacterBody3D

## EnemyAI
## Script for controlling enemy behavior, states, and interactions.
## Adheres to ALMIGHTY-1000 Protocol rules 18, 20, 89, 261-320, 841-880.

# Signals (Rule F25)
signal died
signal took_damage(amount: int, current_health: int)
signal alerted_player(target_position: Vector3)
signal attack_started

# Constants (Rule F25)
const GRAVITY: float = 9.8
const CHASE_SPEED: float = 4.0
const PATROL_SPEED: float = 2.0
const ATTACK_RANGE: float = 3.0
const VISION_RANGE: float = 15.0
const ATTACK_COOLDOWN: float = 1.0

# State machine enum (Rule 18, 264, 842)
enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	DEATH
}

# Exported variables (Rule 14)
@export var max_health: int = 50
@export var damage_on_hit: int = 10
@export var patrol_waypoints: Array[NodePath] # For patrolling enemies (Rule 285)
@export var model_path: PackedScene # Placeholder for enemy model (Rule 296)
@export var debug_draw_path: bool = true

var current_health: int
var current_state: State = State.IDLE

# Cached nodes (Rule 316, 875)
var _navigation_agent: NavigationAgent3D
var _player: CharacterBody3D # Direct ref for convenience, but checked for null (Rule 701)
var _animation_player: AnimationPlayer
var _model: Node3D # The instantiated model (Rule 261)
var _line_of_sight_raycast: RayCast3D # For player detection (Rule 266, 268, 844)
var _attack_timer: Timer

# Internal variables (Rule F26)
var _target_position: Vector3
var _current_waypoint_index: int = 0
var _velocity: Vector3 = Vector3.ZERO
var _agent_speed: float = PATROL_SPEED

func _ready() -> void:
	# Rule 316, 875 - Cache nodes
	_navigation_agent = get_node_or_null("NavigationAgent3D")
	if not _navigation_agent:
		push_error("EnemyAI: Missing NavigationAgent3D child!")
		set_physics_process(false)
		return

	_animation_player = get_node_or_null("AnimationPlayer")
	if not _animation_player:
		push_error("EnemyAI: Missing AnimationPlayer child!")

	_line_of_sight_raycast = get_node_or_null("LineOfSightRayCast3D")
	if not _line_of_sight_raycast:
		push_error("EnemyAI: Missing LineOfSightRayCast3D child!")

	_attack_timer = Timer.new()
	add_child(_attack_timer)
	_attack_timer.one_shot = true
	_attack_timer.wait_time = ATTACK_COOLDOWN
	_attack_timer.timeout.connect(_on_attack_cooldown_timeout) # Rule 305

	# Setup navigation (Rule 263)
	_navigation_agent.velocity_computed.connect(Callable(self, "_on_navigation_velocity_computed"))
	# Rule 282: Set collision layers/masks
	set_collision_layer_value(3, true) # Layer 3: Enemies
	set_collision_mask_value(1, true) # Mask 1: World
	set_collision_mask_value(2, true) # Mask 2: Player
	set_collision_mask_value(4, true) # Mask 4: Bullets

	# Rule 296, 309, 250 - Fallback model
	if model_path:
		_model = model_path.instantiate()
		add_child(_model)
		_model.owner = self
	else:
		# Use a default placeholder cube if no model provided
		var mesh_instance = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(1, 1, 1)
		mesh_instance.mesh = box_mesh
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.0, 0.0) # Red placeholder
		mesh_instance.material_override = material
		add_child(mesh_instance)
		mesh_instance.owner = self
		_model = mesh_instance # Assign placeholder to _model

	current_health = max_health
	GameManager.enemy_spawned() # Rule 694

	change_state(State.IDLE) # Start in IDLE state (Rule 264)
	print(name, ": Initialized in ", current_state, " state.")

func _physics_process(delta: float) -> void: # Rule 276, 864
	if current_state == State.DEATH:
		return

	# Apply gravity (Rule 276)
	if not is_on_floor():
		_velocity.y -= GRAVITY * delta

	# Process states (Rule 314)
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.PATROL:
			_state_patrol(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.DEATH:
			pass # Handled by death logic

	move_and_slide() # Rule 276

	# Update model orientation to match velocity direction
	if _velocity.length_squared() > 0.1 and _model:
		var target_look_direction = Vector3(_velocity.x, 0, _velocity.z).normalized()
		if target_look_direction != Vector3.ZERO:
			_model.look_at(_model.global_position + target_look_direction, Vector3.UP, true) # Rule 307

func change_state(new_state: State) -> void: # Rule 873
	if current_state == new_state:
		return

	current_state = new_state
	_play_animation_for_state(new_state) # Rule 307, 873

	match current_state:
		State.IDLE:
			_agent_speed = 0.0
			_navigation_agent.target_position = global_position # Stop movement
		State.PATROL:
			_agent_speed = PATROL_SPEED
			_set_next_waypoint()
		State.CHASE:
			_agent_speed = CHASE_SPEED
		State.ATTACK:
			_attack_timer.start() # Rule 274, 305
			_velocity = Vector3.ZERO # Stop movement during attack animation (Rule 301)
			attack_started.emit() # Rule 868
		State.DEATH:
			_navigation_agent.target_position = global_position # Stop pathfinding (Rule 289)
			_attack_timer.stop()
			set_physics_process(false) # Disable physics updates on death (Rule 289)
			# Handle removal after death animation (Rule 271, 291)
			if _animation_player and _animation_player.has_animation("death"):
				_animation_player.play("death")
				await _animation_player.animation_finished
			queue_free() # Rule 291
			GameManager.enemy_died() # Rule 694

func _play_animation_for_state(state: State) -> void: # Rule 307, 873
	if not _animation_player:
		return

	match state:
		State.IDLE:
			if _animation_player.has_animation("idle"): _animation_player.play("idle")
		State.PATROL:
			if _animation_player.has_animation("walk"): _animation_player.play("walk")
		State.CHASE:
			if _animation_player.has_animation("run"): _animation_player.play("run")
		State.ATTACK:
			if _animation_player.has_animation("attack"): _animation_player.play("attack")
		State.DEATH:
			if _animation_player.has_animation("death"): _animation_player.play("death")
	# Fallback if no specific animation exists
	if not _animation_player.is_playing() and state != State.DEATH:
		if _animation_player.has_animation("idle"): _animation_player.play("idle")

func _state_idle(delta: float) -> void:
	if _can_see_player():
		change_state(State.CHASE)
	elif patrol_waypoints.size() > 0:
		change_state(State.PATROL)
	# Else, just remain idle.

func _state_patrol(delta: float) -> void:
	if _can_see_player():
		change_state(State.CHASE)
		return

	if _navigation_agent.is_navigation_finished(): # Rule 265
		_set_next_waypoint()

	_set_agent_velocity_towards_target() # Rule 864

func _state_chase(delta: float) -> void:
	if not is_instance_valid(_player) or not _can_see_player(): # Rule 286
		change_state(State.IDLE)
		return

	_navigation_agent.target_position = _player.global_position # Rule 263
	_set_agent_velocity_towards_target() # Rule 864

	if global_position.distance_to(_player.global_position) <= ATTACK_RANGE: # Rule 301
		change_state(State.ATTACK)

func _state_attack(delta: float) -> void:
	if not is_instance_valid(_player) or not _can_see_player():
		change_state(State.IDLE) # Rule 286
		return

	if global_position.distance_to(_player.global_position) > ATTACK_RANGE + 0.5: # Rule 301 (Added hysteresis)
		change_state(State.CHASE)
		return

	# Face player during attack (Rule 301)
	if _model and is_instance_valid(_player):
		_model.look_at(_player.global_position, Vector3.UP, true)

	if _attack_timer.is_stopped(): # Rule 274, 305
		# Perform attack
		print(name, ": Attacking player!")
		if is_instance_valid(_player):
			GameManager.change_player_health(-damage_on_hit)
		_attack_timer.start() # Reset cooldown

func _set_next_waypoint() -> void:
	if patrol_waypoints.size() == 0:
		return

	var waypoint_node: Node = get_node_or_null(patrol_waypoints[_current_waypoint_index]) # Rule 285
	if waypoint_node and waypoint_node is Marker3D: # Rule 317
		_navigation_agent.target_position = waypoint_node.global_position # Rule 263
		_current_waypoint_index = (_current_waypoint_index + 1) % patrol_waypoints.size()
	else:
		push_warning(name, ": Waypoint node at path ", patrol_waypoints[_current_waypoint_index], " is invalid or not a Marker3D.")
		# Fallback to IDLE if waypoint is invalid (Rule 296, 555)
		change_state(State.IDLE)

func _can_see_player() -> bool: # Rule 266, 268, 844, 845
	var player_found: bool = false
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node is CharacterBody3D:
		_player = player_node as CharacterBody3D
		if global_position.distance_to(_player.global_position) > VISION_RANGE:
			return false

		if _line_of_sight_raycast: # Rule 317
			_line_of_sight_raycast.target_position = to_local(_player.global_position)
			_line_of_sight_raycast.force_raycast_update()
			if _line_of_sight_raycast.is_colliding():
				var collider = _line_of_sight_raycast.get_collider()
				if collider == _player or (collider is Area3D and collider.get_parent() == _player):
					player_found = true
				else: # Obstacle in the way (Rule 268)
					player_found = false
			else: # Nothing hit, player not visible
				player_found = false
		else:
			# Fallback: simple distance check if no raycast (less robust)
			player_found = global_position.distance_to(_player.global_position) <= VISION_RANGE
	else:
		_player = null # Player not in scene or not valid

	if player_found and current_state != State.CHASE and current_state != State.ATTACK:
		alerted_player.emit(_player.global_position) # Rule 288, 868
	return player_found

func take_damage(amount: int, hit_position: Vector3, hit_normal: Vector3) -> void: # Rule 269, 303, 851
	if current_state == State.DEATH:
		return

	var actual_damage = amount # Placeholder for damage multipliers (Rule 303)
	current_health -= actual_damage
	print(name, ": Took ", actual_damage, " damage. Health: ", current_health)
	took_damage.emit(actual_damage, current_health) # Rule 270, 292, 851

	# Instantiate hit effect (Rule 272)
	var bullet_impact_scene = preload("res://FX/Particles/BulletImpact.tscn") # Rule 227
	if bullet_impact_scene: # Rule 721
		var impact_fx = bullet_impact_scene.instantiate()
		get_tree().root.add_child(impact_fx)
		impact_fx.global_position = hit_position
		impact_fx.look_at_from_direction(hit_normal, Vector3.UP, true)
		impact_fx.emitting = true
	else:
		push_warning("EnemyAI: BulletImpact scene not found!")

	if current_health <= 0:
		change_state(State.DEATH) # Rule 271, 852

# Navigation Agent callbacks (Rule 263, 265, 864)
func _set_agent_velocity_towards_target() -> void:
	if not is_instance_valid(_navigation_agent) or not _navigation_agent.is_navigation_finished(): # Rule 317, 768, 879
		var next_point: Vector3 = _navigation_agent.get_next_path_position()
		var direction: Vector3 = global_position.direction_to(next_point)
		_navigation_agent.set_velocity(direction * _agent_speed) # Rule 277, 864
	else:
		_navigation_agent.set_velocity(Vector3.ZERO) # Stop moving

func _on_navigation_velocity_computed(safe_velocity: Vector3) -> void:
	_velocity.x = safe_velocity.x
	_velocity.z = safe_velocity.z
	velocity = _velocity # Update CharacterBody3D velocity (Rule 156)

	if GameManager.debug_mode_enabled and debug_draw_path and is_instance_valid(_navigation_agent): # Rule 299, 685
		var path = _navigation_agent.get_nav_path()
		if path.size() > 1:
			for i in range(path.size() - 1):
				DebugDraw3D.draw_line(path[i], path[i+1], Color.PURPLE, 0.1) # Placeholder debug drawing
		DebugDraw3D.draw_sphere(_navigation_agent.target_position, 0.5, Color.RED) # Placeholder debug drawing

func _on_attack_cooldown_timeout() -> void:
	# Cooldown finished, ready to attack again if still in ATTACK state
	if current_state == State.ATTACK:
		# Attack function itself handles _attack_timer.start()
		pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	# Placeholder for Area3D detection (Rule 266)
	if body.is_in_group("player") and current_state != State.CHASE and current_state != State.ATTACK:
		_player = body as CharacterBody3D
		if is_instance_valid(_player) and _can_see_player():
			change_state(State.CHASE)

func _exit_tree() -> void:
	if GameManager.is_instance_valid(GameManager): # Rule 791
		GameManager.enemy_died() # Ensure count is decremented if enemy dies outside normal death state