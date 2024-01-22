# Run.gd
extends PlayerState

func enter(_msg := {}) -> void:
	print("ENTERING RUN")
	# TODO: this should be redundant as it is already set when exiting
	# Dash while on the floor, as well as when exiting Air while on the floor,
	# but somehow it keeps returning true when it shouldn't so adding here for
	# good measure.
	player.dash_depleted = false
	
	
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

	player.move_and_slide()

	if Input.is_action_just_pressed("dash") and not player.dash_depleted:
		state_machine.transition_to("Dash")
	if Input.is_action_just_pressed("jump"):
		state_machine.transition_to("Air", {do_jump = true})
	elif is_equal_approx(player.move_input_direction.x, 0.0):
		state_machine.transition_to("Idle")
