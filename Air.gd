# Air.gd
extends PlayerState

@onready var jump_effects = $"../../Effects/JumpEffects"
@onready var jump_particles = $"../../Effects/JumpEffects/JumpParticles"

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
		
		# Duplicate the JumpParticles object as a new child of JumpEffects
		# This is required to allow for multiple JumpParticles to play on screen at the same time, as
		# often the player will begin a new jump before the particle effects from the prior jump
		# have completed their one-time emit cycle
		var new_jp = jump_particles.duplicate()
		new_jp.emitting = true
		new_jp.position = player.position
		if player.get_floor_normal():
			new_jp.direction = player.get_floor_normal()
		new_jp.direction.x += 0 if is_equal_approx(player.velocity.x, 0.0) else 0.2*-sign(player.move_input_direction.x) #tilt the particle burst away from the direction of movement
		jump_effects.add_child(new_jp)

	if player.velocity.y <=0:
		held_ceiling_jump_velocity = player.velocity.y


func physics_update(delta: float) -> void:
	for particle in jump_effects.get_children():
		if not particle.emitting:
			#particle.position = player.position
		#else:
			jump_effects.remove_child(particle)
		
		print(particle, ", ", particle.emitting)
	print("end update")
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
