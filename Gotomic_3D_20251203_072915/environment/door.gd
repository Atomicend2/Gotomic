class_name Door
extends StaticBody3D

@export var open_angle = 90.0
@export var open_time = 0.5
@export var open_offset = Vector3(0, 0, -1.0) # Offset for the pivot point if door swings, relative to door's origin

var is_open = false
var original_transform: Transform3D
var tween: Tween

func _ready():
	original_transform = global_transform # Store initial transform

func interact(player: Player):
	if is_open:
		close_door()
	else:
		open_door()

func open_door():
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	
	# To make the door rotate around its side, adjust its pivot.
	# Temporarily move the door's origin, rotate, then move back.
	# Or, simply rotate around a world pivot if the door is a child of a Spatial node
	# that represents the hinge point. For simplicity, we'll assume door.tscn's origin
	# is at its pivot (e.g., one edge). If not, we'd adjust `global_position` before rotation.

	# Assuming the door's origin is at its center. To rotate around one side (e.g., XZ plane, at -0.5 on X axis if door width is 1):
	# The Door's MeshInstance3D's origin should be at the pivot point for direct rotation.
	# If the door model has its pivot at its center, we need to shift it before rotating.
	# For this example, let's assume the DOOR.obj has its origin already at one of its edges for simpler rotation.
	# If it was centered, we'd need to shift it:
	# `var pivot_offset = Vector3(-0.5, 0, 0) * global_transform.basis` # Assuming door width is 1
	# `global_transform.origin += pivot_offset`
	# `tween.tween_property(self, "rotation_degrees:y", -open_angle, open_time)`
	# `tween.tween_callback(func(): global_transform.origin -= pivot_offset)`

	# For simplicity, let's just rotate it around its current Y axis.
	# If the OBJ's origin is at the center, it will swing around its center.
	# If the OBJ's origin is at one edge, it will swing correctly.
	# Our door.obj is centered, so it will swing around its center. Let's make it swing open
	# by also translating it slightly.
	
	var target_rotation = Vector3(rotation_degrees.x, rotation_degrees.y - open_angle, rotation_degrees.z)
	var target_position = global_transform.origin + transform.basis * open_offset # Move along local Z axis
	
	tween.tween_property(self, "global_position", target_position, open_time)
	tween.parallel().tween_property(self, "rotation_degrees:y", target_rotation.y, open_time)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(Callable(self, "_on_door_opened"))
	
	is_open = true

func close_door():
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	var target_rotation = original_transform.rotation_degrees
	var target_position = original_transform.origin
	
	tween.tween_property(self, "global_position", target_position, open_time)
	tween.parallel().tween_property(self, "rotation_degrees:y", target_rotation.y, open_time)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(Callable(self, "_on_door_closed"))
	
	is_open = false

func _on_door_opened():
	print("Door opened!")

func _on_door_closed():
	print("Door closed!")