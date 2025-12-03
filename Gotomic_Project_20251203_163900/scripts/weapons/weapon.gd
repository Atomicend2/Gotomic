extends Node3D

class_name Weapon

signal ammo_changed(current_ammo: int, max_ammo: int)
signal magazine_changed(current_magazines: int)
signal reloading_state_changed(is_reloading: bool)

@export var weapon_name: String = "Default Weapon"
@export var damage: int = 20
@export var fire_rate_per_minute: int = 600 # Rounds per minute
@export var magazine_size: int = 30
@export var reserve_ammo: int = 90
@export var reload_time: float = 2.0
@export var recoil_pattern: RecoilPattern
@export var fire_sound: AudioStream = preload("res://assets/audio/gunshot.ogg")
@export var reload_sound: AudioStream = preload("res://assets/audio/reload.ogg")

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var fire_audio_stream_player: AudioStreamPlayer3D = $FireAudioStreamPlayer
@onready var reload_audio_stream_player: AudioStreamPlayer3D = $ReloadAudioStreamPlayer
@onready var ray_cast_bullet: RayCast3D = $BulletRayCast3D

var _current_ammo: int = 0
var _is_reloading: bool = false
var _can_fire: bool = true
var _fire_timer: Timer = Timer.new()
var _player_controller: PlayerController = null

func _ready() -> void:
	add_child(_fire_timer)
	_fire_timer.one_shot = true
	_fire_timer.timeout.connect(Callable(self, "_on_fire_timer_timeout"))
	
	_current_ammo = magazine_size
	
	fire_audio_stream_player.stream = fire_sound
	reload_audio_stream_player.stream = reload_sound

func _on_fire_timer_timeout() -> void:
	_can_fire = true

func set_player_controller(controller: PlayerController) -> void:
	_player_controller = controller

func fire() -> void:
	if not _can_fire or _is_reloading or _current_ammo <= 0:
		return
	
	_can_fire = false
	_current_ammo -= 1
	ammo_changed.emit(_current_ammo, magazine_size)
	
	_fire_timer.start(60.0 / fire_rate_per_minute) # Convert RPM to seconds between shots
	
	_play_fire_animation()
	_play_fire_sound()
	_apply_recoil()
	
	_perform_shoot_hit_scan()

func _play_fire_animation() -> void:
	if animation_player and animation_player.has_animation("fire"):
		animation_player.play("fire")

func _play_fire_sound() -> void:
	if fire_audio_stream_player:
		fire_audio_stream_player.play()

func _apply_recoil() -> void:
	if _player_controller and recoil_pattern:
		_player_controller.apply_recoil(recoil_pattern)

func _perform_shoot_hit_scan() -> void:
	ray_cast_bullet.force_raycast_update()
	if ray_cast_bullet.is_colliding():
		var collider: Object = ray_cast_bullet.get_collider()
		if collider is CharacterBody3D: # Check if it's an enemy or other damageable entity
			var target_health_comp: HealthComponent = (collider as CharacterBody3D).get_node_or_null("HealthComponent")
			if target_health_comp:
				target_health_comp.take_damage(damage)
				print("Hit ", collider.name, " for ", damage, " damage.")

func reload() -> void:
	if _is_reloading or _current_ammo == magazine_size or reserve_ammo == 0:
		return
	
	_is_reloading = true
	reloading_state_changed.emit(true)
	
	if animation_player and animation_player.has_animation("reload"):
		animation_player.play("reload")
	
	if reload_audio_stream_player:
		reload_audio_stream_player.play()
	
	await get_tree().create_timer(reload_time).timeout
	
	var ammo_to_add: int = magazine_size - _current_ammo
	var actual_ammo_added: int = min(ammo_to_add, reserve_ammo)
	
	_current_ammo += actual_ammo_added
	reserve_ammo -= actual_ammo_added
	
	ammo_changed.emit(_current_ammo, magazine_size)
	magazine_changed.emit(reserve_ammo) # Assuming reserve_ammo represents total magazines or reserve
	
	_is_reloading = false
	reloading_state_changed.emit(false)

func aim() -> void:
	if animation_player and animation_player.has_animation("aim_in"):
		animation_player.play("aim_in")

func unaim() -> void:
	if animation_player and animation_player.has_animation("aim_out"):
		animation_player.play("aim_out")

func get_current_ammo() -> int:
	return _current_ammo

func get_magazine_size() -> int:
	return magazine_size

func get_reserve_ammo() -> int:
	return reserve_ammo

func is_reloading() -> bool:
	return _is_reloading

