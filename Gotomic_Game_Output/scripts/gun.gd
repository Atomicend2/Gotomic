extends Node3D

## Basic gun logic for the player.

@export var damage: int = 20
@export var max_ammo: int = 30
@export var current_ammo: int
@export var fire_rate: float = 0.15 # Seconds between shots
@export var shoot_distance: float = 100.0

@onready var ray_cast: RayCast3D = $RayCast3D
@onready var fire_timer: Timer = $FireTimer
@onready var gun_mesh: MeshInstance3D = $GunMeshInstance3D

signal ammo_changed(new_ammo: int, max_ammo: int)
signal fired

var can_fire: bool = true

func _ready() -> void:
	current_ammo = max_ammo
	fire_timer.wait_time = fire_rate
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	
	emit_signal("ammo_changed", current_ammo, max_ammo)

func fire() -> void:
	if not can_fire or current_ammo <= 0:
		return
	
	can_fire = false
	current_ammo -= 1
	fire_timer.start()
	
	emit_signal("fired")
	emit_signal("ammo_changed", current_ammo, max_ammo)
	
	print("Bang! Ammo: %s/%s" % [current_ammo, max_ammo])
	
	# Implement hitscan logic
	if ray_cast.is_enabled():
		ray_cast.force_raycast_update()
		if ray_cast.is_colliding():
			var collider = ray_cast.get_collider()
			var hit_position = ray_cast.get_collision_point()
			print("Hit: %s at %s" % [collider.name, hit_position])
			
			# Check if collider has a HealthComponent
			var health_comp: HealthComponent = null
			if collider is Node:
				health_comp = collider.find_child("HealthComponent")
			
			if health_comp:
				health_comp.take_damage(damage)
				# Optionally show a hit marker or visual feedback
				# For this example, we'll change the material of hit objects to red briefly
				if collider is MeshInstance3D:
					var original_material = collider.get_surface_override_material(0)
					collider.set_surface_override_material(0, preload("res://materials/red_material.tres"))
					get_tree().create_timer(0.1).timeout.connect(func(): collider.set_surface_override_material(0, original_material))
			else:
				print("Hit %s, but no HealthComponent found." % collider.name)
	else:
		print("RayCast3D is not enabled!")

func reload() -> void:
	# Simplified reload, instantly refills ammo
	current_ammo = max_ammo
	emit_signal("ammo_changed", current_ammo, max_ammo)
	print("Reloaded! Ammo: %s/%s" % [current_ammo, max_ammo])

func _on_fire_timer_timeout() -> void:
	can_fire = true