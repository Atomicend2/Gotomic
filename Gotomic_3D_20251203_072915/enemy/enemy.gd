class_name Enemy
extends CharacterBody3D

@export var max_health = 60
@export var speed = 3.0
@export var damage_amount = 10

var health = max_health
var player_node: Player = null

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_node = players[0]
	
	if get_node_or_null("DeathTimer"):
		$DeathTimer.timeout.connect(_on_death_timer_timeout)

func _physics_process(delta):
	if player_node and is_instance_valid(player_node):
		var direction = (player_node.global_transform.origin - global_transform.origin).normalized()
		direction.y = 0 # Keep enemy on ground
		velocity = direction * speed
		
		look_at(player_node.global_transform.origin, Vector3.UP)
		rotation.x = 0
		rotation.z = 0
		
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		move_and_slide()

func take_damage(amount):
	health -= amount
	health = maxi(0, health)
	print("Enemy took ", amount, " damage. Health: ", health)
	if health <= 0:
		die()

func die():
	print("Enemy died!")
	var mesh_instance = $MeshInstance3D
	if mesh_instance:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.2, 0.2, 1) # Darken when dead
		mesh_instance.set_surface_override_material(0, material)
	
	set_collision_layer(0)
	set_collision_mask(0)
	
	# Start a timer to remove the enemy after a short delay
	var death_timer = Timer.new()
	death_timer.name = "DeathTimer"
	add_child(death_timer)
	death_timer.wait_time = 2.0 # Wait 2 seconds before queuing free
	death_timer.one_shot = true
	death_timer.timeout.connect(_on_death_timer_timeout)
	death_timer.start()

func _on_death_timer_timeout():
	queue_free()

func _on_body_entered(body):
	if body is Player:
		body.take_damage(damage_amount)
		print("Enemy collided with player, dealt damage.")