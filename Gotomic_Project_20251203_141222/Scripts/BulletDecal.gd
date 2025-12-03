class_name BulletDecal
extends MeshInstance3D

@export var lifetime: float = 5.0
@export var fade_time: float = 1.0

var _timer: Timer
var _initial_albedo_color: Color

func _ready() -> void:
	if not is_instance_valid(material_override):
		push_error("BulletDecal: Material override not set!")
		queue_free()
		return
	
	if material_override is StandardMaterial3D:
		_initial_albedo_color = (material_override as StandardMaterial3D).albedo_color
	else:
		_initial_albedo_color = Color(1, 1, 1, 1) # Default to white if material type unknown

	_timer = Timer.new()
	add_child(_timer)
	_timer.one_shot = true
	_timer.wait_time = lifetime - fade_time
	_timer.timeout.connect(Callable(self, "_start_fade"))
	_timer.start()
	
	# Set a default mesh if none is provided
	if not is_instance_valid(mesh):
		var plane_mesh: PlaneMesh = PlaneMesh.new()
		plane_mesh.size = Vector2(0.1, 0.1)
		mesh = plane_mesh

func init(position: Vector3, normal: Vector3) -> void:
	global_transform.origin = position + normal * 0.01 # Offset slightly to avoid Z-fighting
	look_at(position + normal, Vector3.UP)
	rotate_y(randf_range(0, PI * 2)) # Random rotation
	# Make decal slightly embedded into the surface
	scale = Vector3(1.0, 1.0, 0.001)

func _start_fade() -> void:
	var fade_tween: Tween = create_tween()
	fade_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_LINEAR)
	if material_override is StandardMaterial3D:
		fade_tween.tween_property(material_override, "albedo_color:a", 0.0, fade_time)
	fade_tween.tween_callback(Callable(self, "queue_free"))