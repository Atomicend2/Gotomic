extends CharacterBody3D

var speed: float = 50.0
var damage: int = 10
var direction: Vector3 = Vector3.FORWARD
var life_time: float = 3.0

func _ready() -> void:
	set_as_top_level(true) # To prevent parent movement affecting it
	look_at(global_transform.origin + direction, Vector3.UP)
	$Timer.start(life_time)

func _physics_process(delta: float) -> void:
	var collision_info: KinematicCollision3D = move_and_collide(direction * speed * delta)
	if collision_info:
		if collision_info.get_collider() is CharacterBody3D:
			var target = collision_info.get_collider()
			if target.has_method("take_damage"):
				target.take_damage(damage)
		queue_free()

func _on_timer_timeout() -> void:
	queue_free()

