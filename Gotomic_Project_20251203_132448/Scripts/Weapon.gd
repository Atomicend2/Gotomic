class_name Weapon
extends Node3D

## Weapon
## Base script for all weapons, providing common functionality and stats.
## Adheres to ALMIGHTY-1000 Protocol rules 24, 88, 117, 201-260, 971.

# Signals (Rule F25)
signal ammo_changed(current_ammo: int, max_ammo: int)
signal fire_started(recoil_pattern: Dictionary)
signal reload_started
signal muzzle_flash_activated
signal sound_played(weapon_name: String, sound_type: String)
signal weapon_state_changed(state: String) # For animation sync

# Constants (Rule F25)
enum FireMode { SEMI, BURST, AUTO }
const AMMO_COLD_RELOAD_TIME_MULTIPLIER: float = 0.5 # For partially full magazine reloads (placeholder)

# Exported variables (Rule 14)
@export var weapon_name: String = "Generic Weapon"
@export var damage: int = 10
@export var fire_rate: float = 0.15 # Seconds between shots (Rule 202)
@export var magazine_size: int = 30 # Rule 202
@export var reload_time: float = 2.0 # Rule 202
@export var recoil_pattern: Dictionary = {
	"recoil_x": 0.1, "recoil_y": 0.2, "recover_time": 0.2, "recoil_duration": 0.1
} # Rule 202, 209
@export var spread_increase: float = 0.05
@export var fire_mode: FireMode = FireMode.AUTO

# Ammo (Rule 203)
var current_ammo: int = 0

# Cached nodes (Rule 316)
var _animation_player: AnimationPlayer
var _muzzle_flash_node: CPUParticles3D # Muzzle flash (Rule 210)
var _ads_offset_node: Node3D # For weapon ADS position (Rule 219)

# Internal variables (Rule F26)
var _is_reloading: bool = false
var _is_ads_active: bool = false
var _is_sprinting: bool = false

func _ready() -> void:
	current_ammo = magazine_size # Start with full ammo

	_animation_player = get_node_or_null("AnimationPlayer") # Rule 23
	if not _animation_player:
		push_warning("Weapon: Missing AnimationPlayer child!")

	_muzzle_flash_node = get_node_or_null("MuzzleFlash")
	if not _muzzle_flash_node:
		push_warning("Weapon: Missing MuzzleFlash child node! Muzzle flash effects will not play.")

	_ads_offset_node = get_node_or_null("ADS_Offset")
	if not _ads_offset_node:
		push_warning("Weapon: Missing ADS_Offset child node! ADS will not have weapon specific position.")

	play_idle_animation() # Rule 102

func fire() -> void: # Rule 134, 232
	if _is_reloading or current_ammo <= 0:
		return

	current_ammo -= 1
	ammo_changed.emit(current_ammo, magazine_size) # Rule 254
	fire_started.emit(recoil_pattern) # Rule 254
	sound_played.emit(weapon_name, "fire") # Rule 212, 254

	play_fire_animation() # Rule 102

func activate_muzzle_flash() -> void: # Rule 210, 211
	if _muzzle_flash_node and _muzzle_flash_node is CPUParticles3D: # Rule 721
		_muzzle_flash_node.restart() # Ensure it restarts if already emitting
		_muzzle_flash_node.emitting = true
	else:
		push_warning("Weapon: Muzzle flash node not found or invalid for: ", weapon_name)

func play_reload_animation() -> void: # Rule 102, 188, 233
	if not _animation_player or not _animation_player.has_animation("reload"):
		push_warning("Weapon: Reload animation not found for ", weapon_name)
		return

	_animation_player.play("reload")
	weapon_state_changed.emit("reload") # Rule 259

func play_fire_animation() -> void: # Rule 102
	if not _animation_player or not _animation_player.has_animation("fire"):
		push_warning("Weapon: Fire animation not found for ", weapon_name)
		return

	_animation_player.play("fire")
	weapon_state_changed.emit("fire") # Rule 259

func play_idle_animation() -> void: # Rule 102
	if not _animation_player or not _animation_player.has_animation("idle"):
		push_warning("Weapon: Idle animation not found for ", weapon_name)
		return

	_animation_player.play("idle")
	weapon_state_changed.emit("idle") # Rule 259

func play_ads_animation() -> void: # Rule 102, 160
	if not _animation_player or not _animation_player.has_animation("ads"):
		push_warning("Weapon: ADS animation not found for ", weapon_name)
		return
	_animation_player.play("ads")
	weapon_state_changed.emit("ads") # Rule 259

func set_ads_state(active: bool) -> void: # Rule 259
	_is_ads_active = active
	if active:
		play_ads_animation() # Rule 160
	elif not _is_sprinting:
		play_idle_animation()

func set_sprint_state(active: bool) -> void: # Rule 259
	_is_sprinting = active
	if active:
		if _animation_player and _animation_player.has_animation("sprint"): # Rule 259
			_animation_player.play("sprint")
			weapon_state_changed.emit("sprint")
		else:
			play_idle_animation() # Fallback
	elif not _is_ads_active:
		play_idle_animation()