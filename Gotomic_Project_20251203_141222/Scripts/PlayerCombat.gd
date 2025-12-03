class_name PlayerCombat
extends Node

#region Signals
signal current_weapon_changed(weapon_index: int)
signal weapon_fire_initiated()
signal weapon_reloaded()
#endregion

#region Exported Variables
@export var ray_cast_node: RayCast3D
@export var weapon_socket: Node3D
@export var bullet_decal_scene: PackedScene = preload("res://Scenes/BulletDecal.tscn")
@export var muzzle_flash_scene: PackedScene = preload("res://Scenes/MuzzleFlash.tscn")
@export var hit_effect_scene: PackedScene = preload("res://Scenes/BulletHitFX.tscn") # Placeholder for now, can be specific
@export var hit_sound_player: AudioStreamPlayer3D

@export var max_recoil_x: float = 0.5
@export var max_recoil_y: float = 0.5
@export var recoil_recovery_speed: float = 5.0

@export var weapon_switch_delay: float = 0.5
@export var interaction_distance: float = 3.0
#endregion

#region Private Variables
var _player_body: CharacterBody3D
var _player_camera_script: PlayerCamera
var _player_movement_script: PlayerMovement

var _equipped_weapons: Array[Weapon] = []
var _current_weapon_index: int = -1
var _current_weapon: Weapon

var _is_reloading: bool = false
var _is_aiming_down_sights: bool = false
var _can_switch_weapon: bool = true
var _can_fire: bool = true
var _interaction_ray_hit_node: Node3D
#endregion

func setup(player_body: CharacterBody3D, player_camera_script: PlayerCamera, player_movement_script: PlayerMovement) -> void:
	_player_body = player_body
	_player_camera_script = player_camera_script
	_player_movement_script = player_movement_script
	
	if not is_instance_valid(ray_cast_node):
		push_error("PlayerCombat: RayCast3D node is not assigned!")
		return
		
	ray_cast_node.collision_mask = (1 << 1) | (1 << 3) | (1 << 6) # World, Enemy, Interactables
	ray_cast_node.exclude_parent = true # Exclude player's own collision body

	print("PlayerCombat: Setup complete.")

func _ready() -> void:
	if not is_instance_valid(hit_sound_player):
		hit_sound_player = AudioStreamPlayer3D.new()
		add_child(hit_sound_player)
		hit_sound_player.name = "HitSoundPlayer"

func _process(delta: float) -> void:
	if GameManager.is_game_paused or not is_instance_valid(_player_body) or not is_instance_valid(_player_camera_script):
		return

	_handle_interaction_ray()
	_handle_input()

func _handle_input() -> void:
	if not is_instance_valid(_current_weapon):
		return

	if Input.is_action_pressed("fire") or Input.is_action_pressed("touch_fire"):
		_current_weapon.fire()
	if Input.is_action_just_pressed("reload") or Input.is_action_just_pressed("touch_reload"):
		_current_weapon.reload()
	if Input.is_action_just_pressed("ads") or Input.is_action_just_pressed("touch_ads"):
		toggle_ads()
	if Input.is_action_just_pressed("toggle_flashlight"):
		_player_body.toggle_flashlight()
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("touch_interact"):
		if is_instance_valid(_interaction_ray_hit_node) and _interaction_ray_hit_node.has_method("interact"):
			_interaction_ray_hit_node.interact(_player_body) # Pass player as activator

func _handle_interaction_ray() -> void:
	if not is_instance_valid(ray_cast_node):
		return
		
	ray_cast_node.force_raycast_update()
	if ray_cast_node.is_colliding():
		var collider: Object = ray_cast_node.get_collider()
		if collider is Node3D:
			_interaction_ray_hit_node = collider
			if collider.has_method("get_interaction_text"):
				var text: String = collider.get_interaction_text()
				GameManager.player_interact_prompt.emit(true, text)
			else:
				GameManager.player_interact_prompt.emit(true, "Interact")
		else:
			_interaction_ray_hit_node = null
			GameManager.player_interact_prompt.emit(false, "")
	else:
		_interaction_ray_hit_node = null
		GameManager.player_interact_prompt.emit(false, "")

func add_weapon(weapon_scene: PackedScene) -> void:
	var new_weapon_instance: Weapon = weapon_scene.instantiate() as Weapon
	if not is_instance_valid(new_weapon_instance):
		push_error("Failed to instance weapon scene: ", weapon_scene.resource_path)
		return

	if is_instance_valid(weapon_socket):
		weapon_socket.add_child(new_weapon_instance)
		new_weapon_instance.owner = _player_body # Set owner for proper scene tree handling
		new_weapon_instance.global_transform = weapon_socket.global_transform # Initialize position correctly

		new_weapon_instance.hide()
		_equipped_weapons.append(new_weapon_instance)
		new_weapon_instance.setup(self, _player_camera_script, _player_movement_script)
		
		# Connect weapon signals
		new_weapon_instance.weapon_fired.connect(_on_weapon_fired)
		new_weapon_instance.reloading_state_changed.connect(_on_weapon_reloading_state_changed)
		new_weapon_instance.ammo_changed.connect(GameManager.ammo_changed)
		new_weapon_instance.dry_fire.connect(Callable(self, "_play_dry_fire_sound"))

		if _current_weapon_index == -1:
			_current_weapon_index = 0
			switch_weapon(_current_weapon_index)

	print("Weapon added: ", new_weapon_instance.weapon_name)

func switch_weapon(index: int) -> void:
	if not _can_switch_weapon or index < 0 or index >= _equipped_weapons.size():
		return

	if is_instance_valid(_current_weapon):
		_current_weapon.set_physics_process(false)
		_current_weapon.set_process(false)
		_current_weapon.hide()
		_current_weapon.set_ads_state(false) # Make sure ADS is off

	_current_weapon_index = index
	_current_weapon = _equipped_weapons[_current_weapon_index]
	_current_weapon.show()
	_current_weapon.set_physics_process(true)
	_current_weapon.set_process(true)
	GameManager.register_current_weapon(_current_weapon)
	current_weapon_changed.emit(_current_weapon_index)
	print("Switched to weapon: ", _current_weapon.weapon_name)

	# Block switching for a short duration
	_can_switch_weapon = false
	var switch_timer: Timer = get_tree().create_timer(weapon_switch_delay)
	switch_timer.timeout.connect(func(): _can_switch_weapon = true)

func _on_weapon_fired(recoil_pitch: float, recoil_yaw: float) -> void:
	if not is_instance_valid(ray_cast_node):
		return
	_player_camera_script.apply_recoil(recoil_pitch, recoil_yaw)
	_player_camera_script.start_camera_shake(0.5)
	weapon_fire_initiated.emit()

	ray_cast_node.force_raycast_update()
	if ray_cast_node.is_colliding():
		var collider: Object = ray_cast_node.get_collider()
		var hit_position: Vector3 = ray_cast_node.get_collision_point()
		var hit_normal: Vector3 = ray_cast_node.get_collision_normal()

		_spawn_bullet_decal(hit_position, hit_normal)
		_spawn_hit_effect(hit_position, hit_normal)
		
		if collider is CharacterBody3D and collider.is_in_group("enemies"):
			var enemy: EnemyAI = collider as EnemyAI
			if is_instance_valid(enemy):
				# Calculate damage, maybe apply headshot bonus
				var damage_to_deal: float = _current_weapon.damage
				enemy.take_damage(damage_to_deal, hit_position)
				print("Hit enemy! Damage: ", damage_to_deal)
				if is_instance_valid(hit_sound_player) and hit_sound_player.stream == null: # Play generic hit sound if not already playing or specific assigned
					hit_sound_player.global_position = hit_position
					hit_sound_player.stream = preload("res://Assets/Audio/placeholder_enemy_damage.tres") # Use a specific hit sound if available
					hit_sound_player.play()
		else:
			print("Hit: ", collider.name if collider else "Nothing", " at ", hit_position)

func _spawn_bullet_decal(position: Vector3, normal: Vector3) -> void:
	if not bullet_decal_scene:
		return
	var decal_instance: BulletDecal = bullet_decal_scene.instantiate() as BulletDecal
	if not is_instance_valid(decal_instance):
		return
	get_tree().current_scene.add_child(decal_instance) # Add to current scene (TestMap)
	decal_instance.init(position, normal)

func _spawn_hit_effect(position: Vector3, normal: Vector3) -> void:
	if not hit_effect_scene:
		return
	var hit_fx_instance: CPUParticles3D = hit_effect_scene.instantiate() as CPUParticles3D
	if not is_instance_valid(hit_fx_instance):
		return
	get_tree().current_scene.add_child(hit_fx_instance)
	hit_fx_instance.global_position = position
	hit_fx_instance.look_at(position + normal, Vector3.UP) # Align particles with hit normal
	hit_fx_instance.emitting = true # Start emission
	
	# Autodelete after particles finish
	var timer: Timer = get_tree().create_timer(hit_fx_instance.lifetime + hit_fx_instance.preprocess)
	timer.timeout.connect(hit_fx_instance.queue_free)

func _play_dry_fire_sound() -> void:
	if is_instance_valid(_current_weapon) and is_instance_valid(_current_weapon.weapon_audio_player) and _current_weapon.dry_fire_sound_stream:
		_current_weapon.weapon_audio_player.stream = _current_weapon.dry_fire_sound_stream
		_current_weapon.weapon_audio_player.play()

func _on_weapon_reloading_state_changed(is_reloading_state: bool) -> void:
	_is_reloading = is_reloading_state
	# Disable ADS and switching while reloading
	if _is_reloading:
		if _is_aiming_down_sights:
			toggle_ads()
		_can_switch_weapon = false
	else:
		_can_switch_weapon = true

func toggle_ads() -> void:
	if _is_reloading or (_player_movement_script and _player_movement_script.get_is_sprinting()):
		return # Cannot ADS while reloading or sprinting

	_is_aiming_down_sights = not _is_aiming_down_sights
	_player_camera_script.set_ads_state(_is_aiming_down_sights)
	if is_instance_valid(_current_weapon):
		_current_weapon.set_ads_state(_is_aiming_down_sights)

func get_is_aiming_down_sights() -> bool:
	return _is_aiming_down_sights

func get_current_weapon() -> Weapon:
	return _current_weapon