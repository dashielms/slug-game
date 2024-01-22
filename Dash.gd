# Dash.gd
extends PlayerState

var dash_input_direction = Vector2.RIGHT
var dash_timer = 0
var bunny_hop = false
var bunny_hop_direction = Vector2.UP


func enter(msg := {}) -> void:
	print("ENTERING DASH")
	dash_timer = 0
	bunny_hop = false
	dash_input_direction = Vector2(
		Input.get_axis("dash_left", "dash_right"), 
		Input.get_axis("dash_up", "dash_down")
	)
	
	player.dash_depleted = true
	# Set floor behavior to allow free sliding along it (avoids sudden stops and
	# jittery movement when dashing into the floor at certain angles)
	player.floor_stop_on_slope = false
	player.floor_constant_speed = false
	player.floor_snap_length = 0


func physics_update(delta: float) -> void:
	
	# Dash movement
	# If bunny hopping, dash in the direction of the bunny hop bounce
	# Otherwise, dash in the direction of the initial dash input and watch
	# for collisions that would result in a bunny hop 
	if bunny_hop: 
		player.velocity = player.DASH_VELOCITY * player.position.direction_to(Vector2(
			player.position.x + bunny_hop_direction.x, 
			player.position.y + bunny_hop_direction.y, 
		))
		player.velocity.y = max(player.velocity.y, -256)
	else:
		player.velocity = player.DASH_VELOCITY * player.position.direction_to(Vector2(
			player.position.x + dash_input_direction.x, 
			player.position.y + dash_input_direction.y, 
		))
	
		# Bunny hop conditions: dash has a horizontal component, player on floor, 
		# and the time window for bunny hopping is not past. If all these are met
		# and a collision takes place, calculate the bounce direction and initiate
		# the bunny hop. Note there are two options for how to calculate the bounce
		# trajectory, one that is consistent and one that depends on the incoming 
		# dash angle.
		# TODO: The player.is_on_floor() check allows for bunny hopping into
		# adjacent walls, this should be altered to skipping the bunny hop and
		# going directly into dash in such a situation
		if (abs(dash_input_direction.x) > 0
				and player.is_on_floor() 
				and dash_timer < player.DASH_BUNNYHOP_WINDOW):
			var collision_info = player.move_and_collide(player.velocity * delta, false)
			if collision_info:
				# Bounce the player such that the trajectory is always 60 degrees off the surface normal (30 degrees off the surface slide angle)
				# This can be used as a more stable and predictable feeling alternative to the bounce logic below
				var collision_bounce = Vector2(dash_input_direction.x, 0).bounce(collision_info.get_normal())
				var collision_bounce_angle_adjusted = collision_info.get_normal().angle() + (sign(dash_input_direction.x)*(PI/3))

				## Bounce the player such that the trajectory is halfway between the angle the
				## player would take if sliding along the surface, and the angle the player would 
				## bounce off the surface with perfect reflection of the incoming dash angle around the surface normal.
				## In plain english, allows the player to control the bounce angle precisely by altering
				## the dash input direction. This is in contrast to the alternative logic above that always
				## bounces the player a predictable 30 degrees off the surface slide angle.
				## If using this, note there is a bug when dashing into a surface with normal between
				## -90 to -180 (not inclusive) that causes the dash to aim in the opposite of intended
				## direction.
				#var collision_bounce = Vector2(dash_input_direction.x, dash_input_direction.y).bounce(collision_info.get_normal())
				#var collision_slide_angle = collision_info.get_normal().angle() + (sign(dash_input_direction.x)*(PI/2))
				#var dif_between_slide_and_bounce = abs(collision_slide_angle - collision_bounce.angle())
				#var mid_angle_between_slide_and_bounce = collision_slide_angle - sign(dash_input_direction.x)*(dif_between_slide_and_bounce/2)
				#var collision_bounce_angle_adjusted = mid_angle_between_slide_and_bounce
				
				# Initiate the bunny hop
				bunny_hop = true
				# convert collision_bounce_angle_adjusted back to a Vector2 using Vector2.RIGHT.rotated()
				bunny_hop_direction = Vector2.RIGHT.rotated(collision_bounce_angle_adjusted)
				bunny_hop_direction.y = max(-0.25, bunny_hop_direction.y)
				print("bunny_hop_direction:", bunny_hop_direction)
				# update the player velocity to the new bunny hop direction 
				#player.velocity = player.DASH_VELOCITY * player.position.direction_to(Vector2(
					#player.position.x + bunny_hop_direction.x, 
					#player.position.y + bunny_hop_direction.y, 
				#))
				#print(player.velocity.y)
				#player.velocity.y = max(player.velocity.y, -256)

	player.move_and_slide()
	
	# Increment timer until it reaches DASH_TIME
	# Upon reaching DASH_TIME, adjust final velocity and exit the dash
	dash_timer += delta
	if dash_timer > player.DASH_TIME:
		if player.velocity.y < -player.DASH_VELOCITY/player.DASH_EXIT_Y_VELOCITY_DAMPING:
			player.velocity.y /= player.DASH_EXIT_Y_VELOCITY_DAMPING
		
		if player.is_on_floor():
			player.dash_depleted = false
			if is_equal_approx(player.velocity.x, 0.0):
				state_machine.transition_to("Idle")
			else:
				state_machine.transition_to("Run")
		else: 
			state_machine.transition_to("Air")

			
func exit() -> void:
	# Reset floor behavior to default
	player.floor_stop_on_slope = player.default_floor_stop_on_slope
	player.floor_constant_speed = player.default_floor_constant_speed
	player.floor_snap_length = player.default_floor_snap_length
