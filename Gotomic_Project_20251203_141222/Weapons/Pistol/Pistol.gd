class_name Pistol
extends Weapon

# You can override specific Pistol properties here if needed
# For example, if Pistol has a unique recoil pattern or special fire mode.

func _ready() -> void:
	# Set default values specific to Pistol (can be overridden by exported variables)
	weapon_name = "Low-Caliber Pistol"
	damage = 15.0
	fire_rate = 0.35
	magazine_size = 8
	reload_time = 1.5
	recoil_pitch = 1.0
	recoil_yaw = 0.3
	
	# Load specific sounds if they are different from generic Weapon sounds
	# fire_sound_stream = preload("res://Assets/Audio/pistol_fire.tres")
	# reload_sound_stream = preload("res://Assets/Audio/pistol_reload.tres")
	
	super._ready() # Call the base class _ready to setup timers, audio, etc.

func _get_property_list() -> Array:
	# This function can be used to hide/show properties in the Inspector if needed,
	# but for simplicity, we'll let the base class handle most properties.
	return []