class_name PhysicsObject
extends RigidBody3D

# Script for dynamic physics objects.

signal object_hit(object_name: String, impact_force: float, impact_point: Vector3)

@export var base_mass: float = 1.0
@export var base_bounciness: float = 0.5
@export var material_color: Color = Color(0.8, 0.5, 0.2, 1)

func _ready() -> void:
	# Set up physics properties.
	mass = base_mass
	bounce = base_bounciness

	# Apply the material color if a MeshInstance3D is present.
	if get_node_or_null("MeshInstance3D"):
		var mesh_instance: MeshInstance3D = get_node("MeshInstance3D") as MeshInstance3D
		if mesh_instance.mesh is ArrayMesh or mesh_instance.mesh is BoxMesh: # Check if it's a generated or placeholder mesh
			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.albedo_color = material_color
			mesh_instance.material_override = material
		else:
			# If a custom mesh is provided, assume it has its own material or instruction to add one.
			print("PhysicsObject: Custom mesh detected, not overriding material color.")

func _on_body_entered(body: Node3D) -> void:
	# Example: Detect collision with other bodies.
	print(name, " collided with ", body.name)

func on_shot(power: float, hit_point: Vector3) -> void:
	# Called when this object is hit by the player's raycast.
	object_hit.emit(name, power, hit_point)
	print(name, " was shot with power: ", power, " at ", hit_point)
	# You could add visual feedback or particle effects here.