class_name Weapon
extends Node3D

#region Signals
signal weapon_fired(recoil_pitch: float, recoil_yaw: float)
signal reloading_state_changed(is_reloading: bool)
signal ammo_changed(current_ammo_in_mag: int, total_reserve_ammo: int)
signal dry_fire()
#endregion

#region Exported Variables
@export var weapon_name: String = "Pistol"
@export var damage: float = 10.0
@export var fire_rate: float = 0.5 # Seconds between shots
@export var magazine_size: int = 12
@export var reload_time: float = 2.0
@export var recoil_pitch: float = 0.5 # Degrees
@export var recoil_yaw: float = 0.2 # Degrees
@export var ads_fov_multiplier: float = 0.7 # For camera, if needed

@export var fire_sound_stream: AudioStream = preload("res://Assets/Audio/placeholder_shoot.tres")
@export var reload_sound_stream: AudioStream = preload("res://Assets/Audio/placeholder_reload.tres")
@export var dry_fire_sound_stream: AudioStream = preload("res://Assets/Audio/placeholder_dry_fire.tres")

@export var mesh_node: MeshInstance3D
@export var muzzle_flash_socket: Node3D
@export var ads_position_offset: Vector3 = Vector3(-0.15, 0.0, -0.1) # Position when ADS
@export var idle_position_offset: Vector3 = Vector3(0.1, -0.05, -0.1) # Default idle position

@export var weapon_anim_player: AnimationPlayer
#endregion

#region Public Variables (managed by PlayerCombat/GameManager)
var current_ammo_in_mag: int
var total_reserve_ammo: int
#endregion

#region Private Variables
var _player_combat_script: PlayerCombat
var _player_camera_script: PlayerCamera
var _player_movement_script: PlayerMovement

var _fire_timer: Timer
var _reload_timer: Timer
var _is_reloading: bool = false
var _can_fire: bool = true
var _is_aiming_down_sights: bool = false
var _tween_ads_pos: Tween
var _tween_idle_pos: Tween

var weapon_audio_player: AudioStreamPlayer3D
var muzzle_flash_pool: Array[CPUParticles3D] = []
var muzzle_flash_scene_preloaded: PackedScene = preload("res://Scenes/MuzzleFlash.tscn")
#endregion

func _ready() -> void:
	_init_ammo()
	_setup_timers()
	_setup_audio()
	_setup_muzzle_flash_pool(5) # Pool 5 muzzle flashes initially
	if is_instance_valid(mesh_node):
		mesh_node.position = idle_position_offset
	
	# Initial update for HUD
	ammo_changed.emit(current_ammo_in_mag, total_reserve_ammo)
	GameManager.register_current_weapon(self) # Re-register on ready for scene changes

func setup(player_combat: PlayerCombat, player_camera: PlayerCamera, player_movement: PlayerMovement) -> void:
	_player_combat_script = player_combat
	_player_camera_script = player_camera
	_player_movement_script = player_movement
	print("Weapon ", weapon_name, ": Setup complete.")

func _init_ammo() -> void:
	current_ammo_in_mag = magazine_size
	total_reserve_ammo = magazine_size * 2 # Start with 2 extra mags
	
func _setup_timers() -> void:
	_fire_timer = Timer.new()
	add_child(_fire_timer)
	_fire_timer.one_shot = true
	_fire_timer.timeout.connect(func(): _can_fire = true)

	_reload_timer = Timer.new()
	add_child(_reload_timer)
	_reload_timer.one_shot = true
	_reload_timer.timeout.connect(func(): _finish_reload())

func _setup_audio() -> void:
	weapon_audio_player = AudioStreamPlayer3D.new()
	add_child(weapon_audio_player)
	weapon_audio_player.name = "WeaponAudioPlayer"
	weapon_audio_player.bus = "SFX"

func _setup_muzzle_flash_pool(size: int) -> void:
	for i in range(size):
		var muzzle_flash: CPUParticles3D = muzzle_flash_scene_preloaded.instantiate() as CPUParticles3D
		if is_instance_valid(muzzle_flash):
			muzzle_flash.emitting = false
			muzzle_flash.visible = false
			add_child(muzzle_flash)
			muzzle_flash_pool.append(muzzle_flash)

func _get_muzzle_flash_from_pool() -> CPUParticles3D:
	for muzzle_flash in muzzle_flash_pool:
		if not muzzle_flash.emitting:
			return muzzle_flash
	# If no available, create a new one (expand pool)
	var new_muzzle_flash: CPUParticles3D = muzzle_flash_scene_preloaded.instantiate() as CPUParticles3D
	if is_instance_valid(new_muzzle_flash):
		new_muzzle_flash.emitting = false
		new_muzzle_flash.visible = false
		add_child(new_muzzle_flash)
		muzzle_flash_pool.append(new_muzzle_flash)
		return new_muzzle_flash
	return null

func fire() -> void:
	if GameManager.is_game_paused or not _can_fire or _is_reloading:
		return

	if current_ammo_in_mag <= 0:
		dry_fire.emit()
		_can_fire = false
		_fire_timer.start(fire_rate / 2.0) # Short delay for dry fire
		return

	current_ammo_in_mag -= 1
	ammo_changed.emit(current_ammo_in_mag, total_reserve_ammo)
	weapon_fired.emit(recoil_pitch, recoil_yaw)
	
	_play_fire_sound()
	_spawn_muzzle_flash()
	_play_weapon_animation("fire")

	_can_fire = false
	_fire_timer.start(fire_rate)

func reload() -> void:
	if GameManager.is_game_paused or _is_reloading or current_ammo_in_mag == magazine_size or total_reserve_ammo <= 0:
		return

	_is_reloading = true
	reloading_state_changed.emit(true)
	_can_fire = false # Block firing during reload
	_play_weapon_animation("reload")
	
	if is_instance_valid(weapon_audio_player) and reload_sound_stream:
		weapon_audio_player.stream = reload_sound_stream
		weapon_audio_player.play()

	_reload_timer.start(reload_time)

func _finish_reload() -> void:
	var ammo_needed: int = magazine_size - current_ammo_in_mag
	var ammo_to_take: int = mini(ammo_needed, total_reserve_ammo)

	current_ammo_in_mag += ammo_to_take
	total_reserve_ammo -= ammo_to_take

	_is_reloading = false
	reloading_state_changed.emit(false)
	_can_fire = true
	ammo_changed.emit(current_ammo_in_mag, total_reserve_ammo)
	_play_weapon_animation("idle")

func _play_fire_sound() -> void:
	if is_instance_valid(weapon_audio_player) and fire_sound_stream:
		weapon_audio_player.stream = fire_sound_stream
		weapon_audio_player.play()

func _spawn_muzzle_flash() -> void:
	if not is_instance_valid(muzzle_flash_socket):
		return
	
	var muzzle_flash: CPUParticles3D = _get_muzzle_flash_from_pool()
	if is_instance_valid(muzzle_flash):
		muzzle_flash.global_transform = muzzle_flash_socket.global_transform
		muzzle_flash.emitting = true
		muzzle_flash.visible = true
		
		# Hide and stop emitting after particle lifetime
		var timer: Timer = get_tree().create_timer(muzzle_flash.lifetime + muzzle_flash.preprocess)
		timer.timeout.connect(func():
			if is_instance_valid(muzzle_flash):
				muzzle_flash.emitting = false
				muzzle_flash.visible = false
		)

func set_ads_state(is_ads: bool) -> void:
	_is_aiming_down_sights = is_ads
	_update_weapon_position()

func _update_weapon_position() -> void:
	if not is_instance_valid(mesh_node):
		return

	if is_instance_valid(_tween_ads_pos):
		_tween_ads_pos.kill()
	if is_instance_valid(_tween_idle_pos):
		_tween_idle_pos.kill()

	var target_position: Vector3 = ads_position_offset if _is_aiming_down_sights else idle_position_offset
	
	if _is_aiming_down_sights:
		_tween_ads_pos = get_tree().create_tween()
		_tween_ads_pos.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		_tween_ads_pos.tween_property(mesh_node, "position", target_position, 0.2)
		_play_weapon_animation("ads_in")
	else:
		_tween_idle_pos = get_tree().create_tween()
		_tween_idle_pos.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		_tween_idle_pos.tween_property(mesh_node, "position", target_position, 0.2)
		_play_weapon_animation("ads_out") # Or just "idle"

func _play_weapon_animation(anim_name: String) -> void:
	if is_instance_valid(weapon_anim_player) and weapon_anim_player.has_animation(anim_name):
		weapon_anim_player.play(anim_name)