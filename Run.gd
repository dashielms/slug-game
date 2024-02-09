# Run.gd
extends PlayerState

@onready var run_particles = $"../../Effects/RunParticles"
		
func enter(_msg := {}) -> void:
	print("ENTERING RUN")
	# TODO: this should be redundant as it is already set when exiting
	# Dash while on the floor, as well as when exiting Air while on the floor,
	# but somehow it keeps returning true when it shouldn't so adding here for
	# good measure.
	player.dash_depleted = false
	run_particles.emitting = true
	
#func player_animations(delta: float, slide_info) -> void:
	#if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		#run_particles.emitting = true
	#else: 
		#run_particles.emitting = false
			
func physics_update(delta: float) -> void:

	
	if not player.is_on_floor():
		state_machine.transition_to("Air")
		return

	# Update the horizontal velocity based on move_input
	player.velocity.x = move_toward(
		player.velocity.x, 
		player.move_input_direction.x * player.MAX_X_VELOCITY, 
		player.DELTA_X_VELOCITY_MOVING_AIR
	)

	var slide_info = player.move_and_slide()
	#player_animations(delta, slide_info)

	if Input.is_action_just_pressed("dash") and not player.dash_depleted:
		state_machine.transition_to("Dash")
	if Input.is_action_just_pressed("jump"):
		state_machine.transition_to("Air", {do_jump = true})
	elif is_equal_approx(player.move_input_direction.x, 0.0):
		state_machine.transition_to("Idle")

func exit() -> void:
	run_particles.emitting = false
