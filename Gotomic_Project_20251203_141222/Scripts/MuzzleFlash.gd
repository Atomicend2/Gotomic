class_name MuzzleFlash
extends CPUParticles3D

@export var flash_lifetime: float = 0.1
@export var random_rotation: float = 360.0

func _ready() -> void:
	one_shot = true
	lifetime = flash_lifetime
	speed_scale = 1.0
	process_material.set_param("emission_box_extents", Vector3(0.01, 0.01, 0.01)) # Tiny emission box
	
	emitting = false
	visible = false

func _process(delta: float) -> void:
	if emitting and amount_left <= 0.0:
		emitting = false
		visible = false

func play_flash() -> void:
	if not is_instance_valid(self):
		return
	
	# Randomize rotation for visual variety
	rotation_degrees.z = randf_range(0, random_rotation)
	
	emitting = true
	visible = true
	restart()