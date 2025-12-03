extends StaticBody3D

## ResourceNode.gd
## Represents a collectible resource node in the world.

@export var resource_type: String = "Scrap" ## Type of resource this node provides.
@export var amount: int = 10 ## Amount of resource given on interaction.
@export var cooldown_time: float = 5.0 ## Time before the node can be interacted with again.

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D as MeshInstance3D
@onready var _pickup_audio: AudioStreamPlayer3D = $PickupSound as AudioStreamPlayer3D

var _is_available: bool = true

func _ready() -> void:
	# Ensure the mesh is visible and interactive
	_mesh_instance.visible = true
	# Connect to GameManager if needed for global events, though ResourceManager is enough here.

## Called when the player interacts with this node.
func interact(interactor: Node3D) -> void:
	if _is_available:
		ResourceManager.add_resource(resource_type, amount)
		
		if is_instance_valid(_pickup_audio):
			_pickup_audio.play()
			
		_is_available = false
		_mesh_instance.visible = false # Temporarily hide the node
		print("ResourceNode: Collected %d %s. Node on cooldown." % [amount, resource_type])
		
		# Start cooldown timer
		await get_tree().create_timer(cooldown_time).timeout
		_is_available = true
		_mesh_instance.visible = true # Make node visible again
		print("ResourceNode: %s is now available again." % name)
	else:
		print("ResourceNode: %s is on cooldown." % name)

## Called when a player enters this node's interaction Area3D.
func on_player_enter_interaction_area(player_node: PlayerController) -> void:
	# Optional: Provide UI feedback to the player that this node is interactable.
	pass

## Called when a player exits this node's interaction Area3D.
func on_player_exit_interaction_area(player_node: PlayerController) -> void:
	# Optional: Remove UI feedback.
	pass