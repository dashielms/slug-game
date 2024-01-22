# Idle.gd
extends PlayerState


func enter(_msg := {}) -> void:
	print("ENTERING IDLE")
	player.velocity = Vector2.ZERO
	# TODO: this should be redundant as it is already set when exiting
	# Dash while on the floor, as well as when exiting Air while on the floor,
	# but somehow it keeps returning true when it shouldn't so adding here for
	# good measure.
	player.dash_depleted = false


func physics_update(_delta: float) -> void:
	if not player.is_on_floor():
		state_machine.transition_to("Air")
		return
	
	if Input.is_action_just_pressed("dash"):
		state_machine.transition_to("Dash")
	elif Input.is_action_just_pressed("jump"):
		state_machine.transition_to("Air", {do_jump = true})
	elif Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		state_machine.transition_to("Run")
