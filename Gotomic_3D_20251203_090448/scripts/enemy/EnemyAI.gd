extends CharacterBody3D

## EnemyAI.gd
## Implements a basic AI for enemies with states, health, and basic pathing.

@export var move_speed: float = 3.0 ## Enemy movement speed.
@export var chase_speed_multiplier: float = 1.5 ## Speed multiplier when chasing player.
@export var rotation_speed: float = 5.0 ## How quickly the enemy rotates towards target.
@export var max_health: int = 50 ## Maximum health of the enemy.
@export var attack_damage: int = 10 ## Damage dealt per attack.
@export var attack_cooldown: float = 1.0 ## Time between attacks.
@export var detection_range: float = 15.0 ## Distance at which enemy detects player.
@export var attack_range: float = 2.0 ## Distance at which enemy can attack.
@export var patrol_points: Array[Vector3] ## List of points for the enemy to patrol.

@onready var _animation_player: AnimationPlayer = $AnimationPlayer as AnimationPlayer
@onready var _hit_audio: AudioStreamPlayer3D = $HitSound as AudioStreamPlayer3D
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D as CollisionShape3D

enum State { IDLE, PATROL, CHASE, ATTACK, DEAD }
var current_state: State = State.IDLE

var _current_health: int = max_health:
	set(value):
		var old_health = _current_health
		_current_health = clampi(value, 0, max_health)
		if _current_health != old_health:
			health_changed.emit(_current_health)
			if _current_health <= 0 and current_state != State.DEAD:
				transition_to_state(State.DEAD)

signal health_changed(new_health: int)
signal took_damage(amount: int)

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _player: PlayerController = null ## Reference to the player node.
var _can_attack: bool = true
var _current_patrol_point_index: int = 0
var _is_dead: bool = false

func _ready() -> void:
	_current_health = max_health
	health_changed.emit(_current_health)
	transition_to_state(State.IDLE)
	_find_player()

## Attempts to find the player node in the scene tree.
func _find_player() -> void:
	# This is a simple way; in a larger game, you might use a GameManager or a global group.
	var player_node: PlayerController = get_tree().get_first_node_in_group("players") as PlayerController
	if is_instance_valid(player_node):
		_player = player_node
	else:
		printerr("EnemyAI: Player not found! Ensure Player has 'players' group.")

func _physics_process(delta: float) -> void:
	if not GameManager.game_active or _is_dead: return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta

	match current_state:
		State.IDLE: _state_idle(delta)
		State.PATROL: _state_patrol(delta)
		State.CHASE: _state_chase(delta)
		State.ATTACK: _state_attack(delta)
		State.DEAD: pass # Handled in _process and _current_health setter

	move_and_slide()

## Transitions the enemy to a new state.
func transition_to_state(new_state: State) -> void:
	if current_state == new_state: return
	
	print("Enemy %s: %s -> %s" % [name, State.keys()[current_state], State.keys()[new_state]])
	current_state = new_state
	_play_animation_for_state(new_state)

	match new_state:
		State.IDLE:
			velocity = Vector3.ZERO
		State.PATROL:
			if patrol_points.is_empty():
				printerr("No patrol points defined for enemy %s. Falling back to Idle." % name)
				transition_to_state(State.IDLE)
				return
			_current_patrol_point_index = 0
		State.CHASE:
			pass
		State.ATTACK:
			_can_attack = true # Reset attack cooldown on entering attack state
		State.DEAD:
			_is_dead = true
			_collision_shape.set_deferred("disabled", true) # Disable collision
			# Emit signal for game manager to clean up or add score
			GameManager.add_score(100)
			await get_tree().create_timer(3.0).timeout # Wait for death animation
			queue_free()

## Plays appropriate animation based on current state.
func _play_animation_for_state(state: State) -> void:
	if not is_instance_valid(_animation_player): return

	var anim_name: String = ""
	match state:
		State.IDLE: anim_name = "Idle"
		State.PATROL: anim_name = "Walk"
		State.CHASE: anim_name = "Run"
		State.ATTACK: anim_name = "Attack"
		State.DEAD: anim_name = "Die"
	
	if _animation_player.has_animation(anim_name):
		_animation_player.play(anim_name)
	else:
		print("Warning: Animation '%s' not found for EnemyAI." % anim_name)


## State: IDLE
func _state_idle(delta: float) -> void:
	# Check for player detection
	if _player and global_position.distance_to(_player.global_position) < detection_range:
		transition_to_state(State.CHASE)
		return

	# If patrol points exist, transition to patrol
	if not patrol_points.is_empty():
		transition_to_state(State.PATROL)

## State: PATROL
func _state_patrol(delta: float) -> void:
	# Check for player detection
	if _player and global_position.distance_to(_player.global_position) < detection_range:
		transition_to_state(State.CHASE)
		return

	if patrol_points.is_empty():
		transition_to_state(State.IDLE)
		return

	var target_point: Vector3 = patrol_points[_current_patrol_point_index]
	var direction: Vector3 = (target_point - global_position).normalized()
	
	# Rotate towards the target point
	_rotate_towards_target(target_point, delta)

	# Move towards the target point
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	# If close enough, move to next patrol point
	if global_position.distance_to(target_point) < 1.0:
		_current_patrol_point_index = (_current_patrol_point_index + 1) % patrol_points.size()
		# Briefly stop at point or continue smoothly

## State: CHASE
func _state_chase(delta: float) -> void:
	if not is_instance_valid(_player) or not GameManager.player_is_alive:
		transition_to_state(State.IDLE)
		return

	var distance_to_player: float = global_position.distance_to(_player.global_position)

	# Check if player is out of detection range
	if distance_to_player > detection_range * 1.5: # Use a larger "forget" range
		transition_to_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)
		return

	# Check if player is in attack range
	if distance_to_player < attack_range:
		transition_to_state(State.ATTACK)
		return

	var direction: Vector3 = (_player.global_position - global_position).normalized()

	# Rotate towards the player
	_rotate_towards_target(_player.global_position, delta)

	# Move towards the player
	velocity.x = direction.x * (move_speed * chase_speed_multiplier)
	velocity.z = direction.z * (move_speed * chase_speed_multiplier)

## State: ATTACK
func _state_attack(delta: float) -> void:
	if not is_instance_valid(_player) or not GameManager.player_is_alive:
		transition_to_state(State.IDLE)
		return

	var distance_to_player: float = global_position.distance_to(_player.global_position)

	# Check if player left attack range
	if distance_to_player > attack_range * 1.2: # Use a slightly larger "disengage" range
		transition_to_state(State.CHASE)
		return

	# Stop movement during attack
	velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
	velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)
	
	# Rotate towards the player even when attacking
	_rotate_towards_target(_player.global_position, delta)

	if _can_attack:
		_perform_attack()

## Rotates the enemy to face a target point (ignoring Y-axis).
func _rotate_towards_target(target_point: Vector3, delta: float) -> void:
	var target_direction: Vector3 = (target_point - global_position).normalized()
	target_direction.y = 0 # Keep enemy upright

	if target_direction.length_squared() > 0:
		var target_basis: Basis = Basis.looking_at(target_direction, Vector3.UP)
		var target_rotation: Vector3 = target_basis.get_euler()

		var current_rotation_y: float = rotation.y
		var new_rotation_y: float = lerp_angle(current_rotation_y, target_rotation.y, rotation_speed * delta)
		rotation.y = new_rotation_y

## Performs the attack action.
func _perform_attack() -> void:
	_can_attack = false
	print("Enemy attacked player!")
	_player.take_damage(attack_damage)
	if is_instance_valid(_animation_player):
		_animation_player.play("Attack") # Ensure this animation exists
	
	await get_tree().create_timer(attack_cooldown).timeout
	_can_attack = true

## Applies damage to the enemy.
func take_damage(amount: int) -> void:
	if _is_dead: return

	_current_health -= amount
	took_damage.emit(amount)
	print("Enemy took %d damage. Current health: %d" % [amount, _current_health])

	if is_instance_valid(_hit_audio):
		_hit_audio.play()

	# If hit while idle/patrolling, transition to chase
	if current_state == State.IDLE or current_state == State.PATROL:
		transition_to_state(State.CHASE)