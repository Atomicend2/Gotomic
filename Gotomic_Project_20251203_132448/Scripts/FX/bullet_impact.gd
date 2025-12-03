class_name BulletImpactFX
extends CPUParticles3D

## BulletImpactFX
## Script for bullet impact particle effects.
## Adheres to ALMIGHTY-1000 Protocol rules 481-520, 990.

# Signals (Rule F25)
signal finished_playback

func _ready() -> void:
	# Ensure the timer exists (Rule 734)
	var timer = get_node_or_null("Timer")
	if timer:
		timer.start(lifetime + preprocess + 0.1) # Give a little extra time (Rule 489)
	else:
		push_warning("BulletImpactFX: Missing Timer node!")
		queue_free() # Fallback

	# Auto-start emitting if not already (Rule 497)
	if not emitting:
		emitting = true

func _on_timer_timeout() -> void: # Rule 490, 493, 957, 990
	emitting = false # Stop emitting new particles
	# Wait a bit for existing particles to fade out (Rule 504)
	await get_tree().create_timer(lifetime_randomness * lifetime + 0.1).timeout
	finished_playback.emit()
	queue_free() # Free the node (Rule 485)