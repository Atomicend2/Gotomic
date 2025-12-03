class_name PlayerCombat
extends Node

## PlayerCombat
## Handles player shooting logic, weapon management, and related effects.
## Adheres to ALMIGHTY-1000 Protocol rules 154, 201-260.

# Signals (Rule F25)
signal ammo_changed(current_ammo: int, max_ammo: int)
signal weapon_switched(weapon_name: String, current_ammo: int, max_ammo: int)
signal fired_weapon(weapon_name: String)
signal player_reloading(is_reloading: bool)
signal dry_fire_sound

# Constants (Rule F25)
const DEFAULT_MAX_WEAPONS: int = 2
const WEAPON_SWITCH_DELAY: float = 0.5
const CROSSHAIR_SPREAD_MIN: float = 0.01
const CROSSHAIR_SPREAD_MAX: float = 0.1
const CROSSHAIR_SPREAD_RECOVERY_RATE: float = 2.0
const CROSSHAIR_SPREAD_SPRINT_MULTIPLIER: float = 2.0
const CROSSHAIR_SPREAD_JUMP_MULTIPLIER: float = 3.0
const CROSSHAIR_SPREAD_ADS_MULTIPLIER: float = 0.5

# Exported variables (Rule 14)
@export var weapons: Array[PackedScene] = []
@export var weapon_socket_path: NodePath
@export var camera_raycast_path: NodePath

# Cached nodes (Rule 316)
var _weapon_socket: Node3D
var _camera_raycast: RayCast3D

# Internal variables (Rule F26)
var _current_weapon_index: int = 0
var _current_weapon: Weapon = null
var _can_switch_weapon: bool = true
var _weapon_switch_timer: Timer
var _fire_timer: Timer
var _reload_timer: Timer
var _is_reloading: bool = false
var _crosshair_spread: float = CROSSHAIR_SPREAD_MIN

func _ready() -> void:
	_weapon_socket = get_node_or_null(weapon_socket_path) # Rule 11, 119, 701, 716, 723
	if not _weapon_socket:
		push_error("PlayerCombat: Missing weapon socket node at path: ", weapon_socket_path)
		set_process(false)
		return

	_camera_raycast = get_node_or_null(camera_raycast_path) # Rule 11, 119, 701, 716, 723
	if not _camera_raycast:
		push_error("PlayerCombat: Missing camera raycast node at path: ", camera_raycast_path)
		set_process(false)
		return

	# Setup Timers (Rule 135, 274, 734)
	_weapon_switch_timer = Timer.new()
	add_child(_weapon_switch_timer)
	_weapon_switch_timer.one_shot = true
	_weapon_switch_timer.wait_time = WEAPON_SWITCH_DELAY
	_weapon_switch_timer.timeout.connect(Callable(self, "_on_weapon_switch_timeout"))

	_fire_timer = Timer.new()
	add_child(_fire_timer)
	_fire_timer.one_shot = true
	_fire_timer.timeout.connect(Callable(self, "_on_fire_cooldown_timeout"))

	_reload_timer = Timer.new()
	add_child(_reload_timer)
	_reload_timer.one_shot = true
	_reload_timer.timeout.connect(Callable(self, "_on_reload_finished"))

	# Initial weapon setup
	if not weapons.is_empty(): # Rule 702
		_current_weapon_index = 0
		switch_weapon(_current_weapon_index, true)
	else:
		push_warning("PlayerCombat: No weapons assigned to player!")

func _process(delta: float) -> void:
	_update_crosshair_spread(delta)

func _input(event: InputEvent) -> void:
	if GameManager.game_is_paused or GameManager.game_over:
		return

	if event.is_action_pressed("fire"):
		fire_weapon()
		event.handled = true # Rule F07/F19 Enforcement
	if event.is_action_released("fire"):
		if _current_weapon and _current_weapon.fire_mode == Weapon.FireMode.AUTO:
			_fire_timer.stop()
		event.handled = true

	if event.is_action_pressed("reload"):
		reload_weapon()
		event.handled = true

	if event.is_action_pressed("weapon_next"):
		switch_weapon_next()
		event.handled = true
	if event.is_action_pressed("weapon_prev"):
		switch_weapon_prev()
		event.handled = true

	# Mobile touch controls (Rule 148, 149, 150, 229)
	if event.is_action_pressed("touch_fire"):
		fire_weapon()
		event.handled = true
	if event.is_action_released("touch_fire"):
		if _current_weapon and _current_weapon.fire_mode == Weapon.FireMode.AUTO:
			_fire_timer.stop()
		event.handled = true
	if event.is_action_pressed("touch_reload"):
		reload_weapon()
		event.handled = true
	if event.is_action_pressed("touch_ads"):
		_get_parent().set_ads_input(not _get_parent().is_ads_active()) # Assuming Player.gd handles this
		event.handled = true


func fire_weapon() -> void: # Rule 133, 134, 135, 213, 214, 215, 232
	if not is_instance_valid(_current_weapon) or _is_reloading or not _can_switch_weapon: # Rule 132, 214
		return

	if _current_weapon.current_ammo <= 0: # Rule 133, 215
		dry_fire_sound.emit() # Rule 212
		print("PlayerCombat: Out of ammo!")
		return

	if _fire_timer.is_stopped(): # Rule 135, 213
		_current_weapon.fire()
		fired_weapon.emit(_current_weapon.weapon_name) # Rule 194, 254
		_fire_timer.wait_time = _current_weapon.fire_rate # Rule 135
		_fire_timer.start() # Rule 135
		_crosshair_spread = min(CROSSHAIR_SPREAD_MAX, _crosshair_spread + _current_weapon.spread_increase) # Rule 196
		# Raycast for hit detection (Rule 178, 181, 182, 206)
		if _camera_raycast: # Rule 718
			_camera_raycast.force_raycast_update()
			if _camera_raycast.is_colliding(): # Rule 193
				var collider = _camera_raycast.get_collider()
				var hit_point = _camera_raycast.get_collision_point()
				var hit_normal = _camera_raycast.get_collision_normal()
				print("PlayerCombat: Hit ", collider.name, " at ", hit_point)
				if collider is CharacterBody3D and collider.is_in_group("enemies"): # Rule 257
					var enemy_ai = collider as EnemyAI
					if is_instance_valid(enemy_ai): # Rule 719, 760
						enemy_ai.take_damage(_current_weapon.damage, hit_point, hit_normal) # Rule 177
				# Instantiate bullet decal (Rule 193)
				var bullet_decal_scene = preload("res://FX/Decals/BulletDecal.tscn")
				if bullet_decal_scene: # Rule 721
					var decal = bullet_decal_scene.instantiate()
					get_tree().root.add_child(decal)
					decal.global_position = hit_point
					decal.look_at_from_direction(hit_normal, Vector3.UP, true)
	else:
		# Auto fire handling (Rule 230)
		if _current_weapon.fire_mode == Weapon.FireMode.AUTO and Input.is_action_pressed("fire"):
			pass # Do nothing, wait for timer

func reload_weapon() -> void: # Rule 132, 149, 188, 214, 233
	if not is_instance_valid(_current_weapon) or _is_reloading or _current_weapon.current_ammo == _current_weapon.magazine_size:
		return

	_is_reloading = true
	_can_switch_weapon = false # Rule 163
	player_reloading.emit(true) # Rule 189
	_fire_timer.stop() # Prevent firing during reload (Rule 214)
	_current_weapon.play_reload_animation() # Rule 188, 233
	_reload_timer.wait_time = _current_weapon.reload_time # Rule 233
	_reload_timer.start()

func switch_weapon(index: int, force: bool = false) -> void: # Rule 162, 163, 164, 165, 167, 216, 217, 218
	if not _can_switch_weapon and not force:
		return

	if index == _current_weapon_index and not force:
		return

	if index < 0 or index >= weapons.size(): # Rule 702
		return

	if _is_reloading and not force: # Rule 163
		print("PlayerCombat: Cannot switch weapon while reloading!")
		return

	if _get_parent().is_ads_active() and not force: # Rule 164 (assuming Player.gd has is_ads_active)
		print("PlayerCombat: Cannot switch weapon while aiming down sights!")
		return

	# Assuming Player.gd handles sprint state for Rule 165
	if _get_parent().is_sprinting() and not force:
		print("PlayerCombat: Cannot switch weapon while sprinting!")
		return

	_can_switch_weapon = false
	_weapon_switch_timer.start() # Rule 162

	# Remove old weapon
	if is_instance_valid(_current_weapon): # Rule 723
		_current_weapon.queue_free()

	# Instance new weapon (Rule 118, 201)
	var new_weapon_scene = weapons[index] # Rule 702
	if not new_weapon_scene: # Rule 706
		push_error("PlayerCombat: Weapon scene at index ", index, " is null.")
		_current_weapon = null
		return

	_current_weapon = new_weapon_scene.instantiate() as Weapon # Rule 201
	if is_instance_valid(_current_weapon): # Rule 723
		_weapon_socket.add_child(_current_weapon) # Rule 104
		_current_weapon.owner = self
		_current_weapon_index = index

		# Connect signals from new weapon (Rule 254)
		_current_weapon.ammo_changed.connect(_on_weapon_ammo_changed)
		_current_weapon.reload_started.connect(Callable(self, "reload_weapon")) # Weapon can initiate reload
		_current_weapon.fire_started.connect(Callable(_get_parent(), "apply_recoil")) # PlayerCamera applies recoil
		_current_weapon.muzzle_flash_activated.connect(Callable(_current_weapon, "activate_muzzle_flash")) # Muzzle flash is a child of weapon
		_current_weapon.sound_played.connect(Callable(_current_parent(), "play_weapon_sound")) # Assuming Player will have this function

		# Initial HUD update for new weapon (Rule 217, 248)
		weapon_switched.emit(_current_weapon.weapon_name, _current_weapon.current_ammo, _current_weapon.magazine_size)
		ammo_changed.emit(_current_weapon.current_ammo, _current_weapon.magazine_size) # Also update ammo specifically
		print("PlayerCombat: Switched to weapon: ", _current_weapon.weapon_name)
	else:
		push_error("PlayerCombat: Failed to instance weapon scene: ", new_weapon_scene.resource_path)
		_current_weapon = null

func switch_weapon_next() -> void:
	var next_index = (_current_weapon_index + 1) % weapons.size() # Rule 161
	switch_weapon(next_index)

func switch_weapon_prev() -> void:
	var prev_index = (_current_weapon_index - 1 + weapons.size()) % weapons.size() # Rule 161
	switch_weapon(prev_index)

func _on_weapon_switch_timeout() -> void: # Rule 162
	_can_switch_weapon = true

func _on_fire_cooldown_timeout() -> void:
	if _current_weapon.fire_mode == Weapon.FireMode.AUTO and Input.is_action_pressed("fire"):
		fire_weapon() # Continue firing if auto and button held (Rule 230)

func _on_reload_finished() -> void: # Rule 233
	if is_instance_valid(_current_weapon): # Rule 779
		_current_weapon.current_ammo = _current_weapon.magazine_size # Refill ammo
		ammo_changed.emit(_current_weapon.current_ammo, _current_weapon.magazine_size) # Rule 186
	_is_reloading = false
	_can_switch_weapon = true
	player_reloading.emit(false)

func _on_weapon_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	ammo_changed.emit(current_ammo, max_ammo) # Rule 186

func get_crosshair_spread() -> float: # Rule 196
	return _crosshair_spread

func _update_crosshair_spread(delta: float) -> void: # Rule 197, 258
	var target_spread = CROSSHAIR_SPREAD_MIN
	var player = get_parent() as Player

	if player:
		if player.is_sprinting(): # Rule 200
			target_spread *= CROSSHAIR_SPREAD_SPRINT_MULTIPLIER
		if player.is_on_floor() == false: # Rule 198
			target_spread *= CROSSHAIR_SPREAD_JUMP_MULTIPLIER
		if player.is_ads_active(): # Rule 222
			target_spread *= CROSSHAIR_SPREAD_ADS_MULTIPLIER

	_crosshair_spread = lerp(_crosshair_spread, target_spread, delta * CROSSHAIR_SPREAD_RECOVERY_RATE)

func is_reloading() -> bool: # Rule 189
	return _is_reloading