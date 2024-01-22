# Air.gd
extends PlayerState

# By default, move_and_slide() will set player velocity.y to 0 on ceiling
# collision. This variable will hold and track what the velocity.y should
# be, allowing the player to continue the jump upon moving out from under
# the ceiling.
var held_ceiling_jump_velocity = 0


# If we get a message asking us to jump, we jump.
# If the player is not yet falling, begin storing velocity.y in held_ceiling_jump_velocity
func enter(msg := {}) -> void:
	print("ENTERING AIR")
	if msg.has("do_jump"):
		player.velocity.y = -player.JUMP_VELOCITY
	if player.velocity.y <=0:
		held_ceiling_jump_velocity = player.velocity.y


func physics_update(delta: float) -> void:

	# Horizontal movement
	player.velocity.x = move_toward(
		player.velocity.x, 
		player.move_input_direction.x * player.MAX_X_VELOCITY, 
		player.DELTA_X_VELOCITY_MOVING_AIR
	)
	
	# Vertical movement
	# If not on ceiling, apply gravity to player velocity
	# If on ceiling, apply gravity to held velocity and repeatedly return it 
	# to player, allowing to continue the jump upon moving out from under
	# the ceiling. See held_ceiling_jump_velocity declaration above.
	if not player.is_on_ceiling():
		player.velocity.y += player.gravity * delta
		held_ceiling_jump_velocity = player.velocity.y
	else:
		held_ceiling_jump_velocity += player.gravity * delta
		player.velocity.y = held_ceiling_jump_velocity
			
	player.move_and_slide()

	
	# State transitions
	# Check for Dash input, as this will interrupt the jump
	if Input.is_action_just_pressed("dash") and not player.dash_depleted:
		state_machine.transition_to("Dash")
	
	# Landing on floor, return dash_depleted to false 
	# and set state based on horizontal velocity
	if player.is_on_floor():
		player.dash_depleted = false
		if is_equal_approx(player.velocity.x, 0.0):
			state_machine.transition_to("Idle")
		else:
			state_machine.transition_to("Run")
