class_name EnemyAI
extends CharacterBody3D

#region Signals
signal died()
signal took_damage(damage_amount: float, hit_position: Vector3)
#endregion

#region Exported Variables
@export var max_health: float = 100.0
@export var movement_speed: float = 2.0
@export var chase_speed_multiplier: float = 1.5
@export var attack_range: float = 2.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.5
@export var detection_range: float = 15.0

@export var mesh_instance: MeshInstance3D
@export var collision_shape: CollisionShape3D
@export var nav_agent: NavigationAgent3D
@export var detection_area: Area3D
@export var enemy_anim_player: AnimationPlayer

@export var attack_sound_stream: AudioStream = preload("res://Assets/Audio/placeholder_enemy_attack.tres")
@export var damage_sound_stream: AudioStream = preload("res://Assets/Audio/placeholder_enemy_damage.tres")
@export var death_sound_stream: AudioStream = preload("res://Assets/Audio/placeholder_enemy_death.tres")
#endregion

#region Private Variables
var _current_health: float
var _player_target: CharacterBody3D
var _state: int = STATE_IDLE
var _is_attacking: bool = false
var _attack_timer: Timer
var _death_timer: Timer

var _audio_player: AudioStreamPlayer3D
#endregion

enum {
	STATE_IDLE,
	STATE_PATROL,
	STATE_CHASE,
	STATE_ATTACK,
	STATE_DEATH
}

func _ready() -> void:
	_current_health = max_health * GameManager.get_difficulty_multiplier()
	print(name, " _ready: Initial health ", _current_health)
	
	_setup_nav_agent()
	_setup_timers()
	_setup_audio_player()
	_set_initial_state()
	_setup_detection_area()
	
	add_to_group("enemies")

func _set_initial_state() -> void:
	_state = STATE_IDLE
	_play_animation("idle")

func _setup_nav_agent() -> void:
	if is_instance_valid(nav_agent):
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		nav_agent.velocity_computed.connect(Callable(self, "_on_velocity_computed"))
	else:
		push_error(name, ": NavigationAgent3D node is not assigned!")

func _setup_timers() -> void:
	_attack_timer = Timer.new()
	add_child(_attack_timer)
	_attack_timer.one_shot = true
	_attack_timer.timeout.connect(func(): _is_attacking = false)
	
	_death_timer = Timer.new()
	add_child(_death_timer)
	_death_timer.one_shot = true
	_death_timer.timeout.connect(func(): queue_free())

func _setup_audio_player() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)
	_audio_player.name = "EnemyAudioPlayer"
	_audio_player.bus = "SFX"

func _setup_detection_area() -> void:
	if is_instance_valid(detection_area):
		detection_area.body_entered.connect(Callable(self, "_on_detection_area_body_entered"))
		detection_area.body_exited.connect(Callable(self, "_on_detection_area_body_exited"))
		if is_instance_valid(detection_area.get_node_or_null("CollisionShape3D")):
			(detection_area.get_node("CollisionShape3D") as CollisionShape3D).shape.set_deferred("radius", detection_range)
	else:
		push_warning(name, ": Detection Area3D node is not assigned!")

func _physics_process(delta: float) -> void:
	if GameManager.is_game_paused or _state == STATE_DEATH:
		return

	_update_state(delta)
	
	if not is_instance_valid(nav_agent):
		return

	var current_velocity: Vector3 = velocity

	if not is_on_floor():
		current_velocity.y -= GameManager.gravity * delta

	velocity = current_velocity
	move_and_slide()

func _update_state(delta: float) -> void:
	match _state:
		STATE_IDLE:
			_idle_state(delta)
		STATE_CHASE:
			_chase_state(delta)
		STATE_ATTACK:
			_attack_state(delta)
		STATE_DEATH:
			_death_state(delta)
		STATE_PATROL: # Default to idle if patrol not implemented in base class
			_idle_state(delta)

func _idle_state(_delta: float) -> void:
	_play_animation("idle")
	if is_instance_valid(_player_target):
		_change_state(STATE_CHASE)
	else:
		_set_velocity_zero()

func _chase_state(delta: float) -> void:
	if not is_instance_valid(_player_target):
		_change_state(STATE_IDLE)
		return

	_play_animation("run") # Or "walk"
	nav_agent.set_target_position(_player_target.global_position)
	var next_point: Vector3 = nav_agent.get_next_path_position()
	var new_velocity: Vector3 = (next_point - global_position).normalized() * movement_speed * chase_speed_multiplier
	
	# Rotate enemy to face target
	look_at(_player_target.global_position, Vector3.UP, true)
	rotation.x = 0.0
	rotation.z = 0.0
	
	nav_agent.set_velocity(new_velocity)
	
	if global_position.distance_to(_player_target.global_position) <= attack_range:
		_change_state(STATE_ATTACK)

func _attack_state(_delta: float) -> void:
	if not is_instance_valid(_player_target) or global_position.distance_to(_player_target.global_position) > attack_range * 1.5:
		_change_state(STATE_CHASE)
		return

	_set_velocity_zero()
	look_at(_player_target.global_position, Vector3.UP, true)
	rotation.x = 0.0
	rotation.z = 0.0

	if not _is_attacking:
		_is_attacking = true
		_play_animation("attack")
		_attack_timer.start(attack_cooldown)
		_perform_attack()
	else:
		_play_animation("idle") # Or hold attack animation
		
func _perform_attack() -> void:
	if is_instance_valid(_player_target) and global_position.distance_to(_player_target.global_position) <= attack_range:
		print(name, ": Attacking player!")
		if is_instance_valid(_audio_player) and attack_sound_stream:
			_audio_player.stream = attack_sound_stream
			_audio_player.play()
		_player_target.take_damage(attack_damage)

func _death_state(_delta: float) -> void:
	_set_velocity_zero()
	if is_instance_valid(collision_shape):
		collision_shape.disabled = true
	nav_agent.set_velocity(Vector3.ZERO)
	# Play death animation
	if enemy_anim_player and enemy_anim_player.has_animation("death"):
		enemy_anim_player.play("death")
		_death_timer.start(enemy_anim_player.get_animation("death").length + 0.5) # Wait for anim + small buffer
	else:
		# If no death animation, just queue_free after a short delay
		_death_timer.start(1.0) # Small delay
	died.emit()
	set_physics_process(false) # Stop physics processing for dead enemy

func _change_state(new_state: int) -> void:
	if _state == new_state:
		return
	_state = new_state
	print(name, ": Changed state to ", _state)

func _play_animation(anim_name: String) -> void:
	if is_instance_valid(enemy_anim_player) and enemy_anim_player.has_animation(anim_name) and enemy_anim_player.current_animation != anim_name:
		enemy_anim_player.play(anim_name)

func take_damage(damage_amount: float, _hit_position: Vector3) -> void:
	if _state == STATE_DEATH:
		return
	
	_current_health -= damage_amount
	took_damage.emit(damage_amount, _hit_position)
	print(name, ": Took ", damage_amount, " damage. Health: ", _current_health)
	
	if is_instance_valid(_audio_player) and damage_sound_stream:
		_audio_player.stream = damage_sound_stream
		_audio_player.play()

	if _current_health <= 0.0:
		_current_health = 0.0
		_change_state(STATE_DEATH)
		if is_instance_valid(_audio_player) and death_sound_stream:
			_audio_player.stream = death_sound_stream
			_audio_player.play()

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity

func _set_velocity_zero() -> void:
	velocity = Vector3.ZERO
	nav_agent.set_velocity(Vector3.ZERO)

func _on_detection_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_target = body as CharacterBody3D
		print(name, ": Player detected!")
		if _state != STATE_DEATH:
			_change_state(STATE_CHASE)

func _on_detection_area_body_exited(body: Node3D) -> void:
	if body == _player_target:
		print(name, ": Player lost!")
		_player_target = null
		if _state != STATE_DEATH:
			_change_state(STATE_IDLE)