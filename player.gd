extends CharacterBody2D

@onready var sprite_2d = $Sprite2D

## Set CharacterBody2D attributes


### Set constants

#### Set constants for movement
const MAX_X_VELOCITY = 64.0*3
const DELTA_X_VELOCITY_MOVING_GROUND = 64.0*2
const DELTA_X_VELOCITY_MOVING_AIR = 64.0
const DELTA_X_VELOCITY_STOPPING_GROUND = 64.0*4
const DELTA_X_VELOCITY_STOPPING_AIR = 64.0/2.0 # cannot divide by integer or result will be rounded
const JUMP_VELOCITY = 64.0*6.0
const DASH_VELOCITY = 64.0*8.0
const DASH_TIME = .2

#### Set constants for ceiling cling
const CEILING_SLIDE_TIME = 1.6

#### Set constants for sprite animation
const ROTATION_SPEED = 16


### Get global variables from project settings

#### Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

### Set global variables

### Set global variables for dash
var is_dashing = false
var dash_timer = 0
var dash_depleted = false
var held_dash_cling_velocity = Vector2(0, 0)
var held_dash_gravity = gravity
var held_dash_floor_snap_length = floor_snap_length
var held_dash_slide_on_ceiling = slide_on_ceiling
var dash_input_last_direction = Vector2(1, 0)

#### Set global variables for ceiling cling
var is_jumping = false
var held_jump_cling_velocity = Vector2(0, 0)
var just_started_cling = true
var jump_cling_depleted = false
var held_jump_floor_snap_length = floor_snap_length
var held_jump_slide_on_ceiling = slide_on_ceiling

#### Set global variables for sprite rotation
# floor_relative is specified as opposed to floor_absolute, as during ceiling cling the up direction is 
# reversed and briefly becomes the floor. when the up direction is reversed, floor_relative
# would refer to the ceiling, while floor_absolute will always refer to the level floor
var prev_step_was_on_floor_relative = false 


func _physics_process(delta):
	
	# Calculate if player is on floor (floor_absolute is specified, as this
	# variable always refers to the true ground even when gravity is reversed)
	var is_on_floor_absolute = up_direction == Vector2(0, -1) and is_on_floor()
	

	# HANDLE WALK MOVEMENT AND INPUT
	
	# Get the walking movement input direction
	var move_input_direction = Vector2(
		Input.get_axis("walk_left", "walk_right"), 
		Input.get_axis("walk_up", "walk_down")
	)
	# Handle the walking movement/deceleration.
	if dash_timer == 0:
		if move_input_direction.x:
			velocity.x = move_toward(
				velocity.x, 
				move_input_direction.x * MAX_X_VELOCITY, 
				DELTA_X_VELOCITY_MOVING_GROUND if is_on_floor_absolute else DELTA_X_VELOCITY_MOVING_AIR
			)
		else:
			# Reduce speed when no horizontal walking input detected, faster on floor than in air
			velocity.x = move_toward(
				velocity.x, 
				0,
				DELTA_X_VELOCITY_STOPPING_GROUND if is_on_floor_absolute else DELTA_X_VELOCITY_STOPPING_AIR
			)
			

	# HANDLE DASH MOVEMENT AND INPUT
	
	# Get the dash input direction,
	var dash_input_direction = Vector2(
		Input.get_axis("dash_left", "dash_right"), 
		Input.get_axis("dash_up", "dash_down")
	)
	print("dash: ", dash_input_direction)
	# Remember the last input for each axis that is not 0 (so player still has 
	# a direction to dash even when nothing is pressed)
	if abs(dash_input_direction.x) > 0:
		dash_input_last_direction.x = dash_input_direction.x
	if abs(dash_input_direction.y) > 0:
		dash_input_last_direction.y = dash_input_direction.y

	# Initiate the dash on button press
	if Input.is_action_just_pressed("dash") and not dash_depleted:
		is_dashing = true
		# Set the velocity to the dash input direction pressed (if neither axis
		# pressed, dash either left or right based on whichever was last pressed)
		if dash_input_direction.x == 0 and dash_input_direction.y == 0:
			velocity = DASH_VELOCITY * position.direction_to(Vector2(
				position.x + (1*sign(dash_input_last_direction.x) if not dash_input_last_direction.x == 0 else 0), 
				position.y, 
			))
		else:
			velocity = DASH_VELOCITY * position.direction_to(Vector2(
				position.x + (1*sign(dash_input_direction.x) if not dash_input_direction.x == 0 else 0), 
				position.y + (1*sign(dash_input_direction.y) if not dash_input_direction.y == 0 else 0), 
			))
		held_dash_cling_velocity = velocity
		held_dash_gravity = gravity
		gravity = 0
		held_dash_floor_snap_length = floor_snap_length
		floor_snap_length = 0
		held_dash_slide_on_ceiling = slide_on_ceiling
		slide_on_ceiling = true
		dash_timer += delta
		dash_depleted = true
	# If dash is ongoing, and time is left: increment timer and maintain velocity
	# If dash is ongoing, and time is up: end the dash
	elif is_dashing:
		if dash_timer <= DASH_TIME:
			dash_timer += delta
			# Do not maintain velocity if on floor (prevents jittering when dashing 
			# into the floor normal) 
			if not is_on_floor():
				velocity = DASH_VELOCITY * position.direction_to(Vector2(
					position.x + held_dash_cling_velocity.x, 
					position.y + held_dash_cling_velocity.y
				))
		else:
			is_dashing = false
			dash_timer = 0
			gravity = held_dash_gravity
			floor_snap_length = held_dash_floor_snap_length
			slide_on_ceiling = held_dash_slide_on_ceiling
			velocity = Vector2(
				MAX_X_VELOCITY * (sign(held_dash_cling_velocity.x) if not held_dash_cling_velocity.x == 0 else 0), 
				MAX_X_VELOCITY * (sign(held_dash_cling_velocity.y) if not held_dash_cling_velocity.y == 0 else 0)
			)
			# if dash finishes by tossing player up into the air, act as if a jump has started
			if velocity.y < 0:
				held_jump_cling_velocity.y = velocity.y 
				jump_cling_depleted = false
				
	# Allow dashing again after player touches the ground and the dash is over
	if dash_depleted and is_on_floor_absolute and not is_dashing:
		dash_depleted = false
	

	# HANDLE GRAVITY, JUMPING, AND CLINGING TO CEILING
	if not is_dashing:
	# If gravity direction is normal (not clinging to ceiling)
		if up_direction == Vector2(0, -1):
			# If on floor, watch for jump button and initiate jump if pressed
			if is_on_floor():
				if Input.is_action_just_pressed("jump"):
					# setting held_jump_cling_velocity immediately after velocity.y is required 
					# for the case that the player is beginning jump while already touching ceiling
					velocity.y = -JUMP_VELOCITY
					held_jump_cling_velocity.y = velocity.y 
					held_jump_slide_on_ceiling = slide_on_ceiling
					slide_on_ceiling = false
					held_jump_floor_snap_length = floor_snap_length
					floor_snap_length = 4
					jump_cling_depleted = false
					#print("gravity normal. initiating jump. held_jump_cling_velocity.y: ", held_jump_cling_velocity.y, ", velocity.y: ", velocity.y)
			# If in air and on ceiling, initiate cling by reversing the gravity direction
			# If in air and not on ceiling, apply gravity and update held_jump_cling_velocity.y
			else:
				if is_on_ceiling() and not jump_cling_depleted:
					up_direction = Vector2(0, 1)
					held_jump_cling_velocity.y += gravity*delta
					# save velocity.x and temporarily set to 0, to ensure move_and_slide() does not move 
					# player horizontally off the ceiling before the next frame (which would result in an 
					# infinite loop between moving off the ceiling and reconnecting causing jittery movement). 
					# velocity.x will be returned in next frame once gravity has reversed and the player 
					# has succesfully snapped to the new floor (i.e. the ceiling). set just_started_cling
					# to true, which will be used to ensure the velocity.x is only returned on the next 
					# frame and none after.
					# Note - loop may be avoided without holding x velocity by just setting the floor snap length higher
					held_jump_cling_velocity.x = velocity.x 
					velocity = Vector2(0, -200) 
					just_started_cling = true
					#print("gravity normal. initiating cling. held_jump_cling_velocity.y: ", held_jump_cling_velocity.y, ", velocity.y: ", velocity.y, ", velocity.x:", velocity.x, ", held_jump_cling_velocity.x: ", held_jump_cling_velocity.x)
				else:
					velocity.y += gravity * delta
					# track velocity.y while in air, as waiting until is_on_ceiling true results in velocity.y = 0
					held_jump_cling_velocity.y = velocity.y
					#print("gravity normal. applying gravity. held_jump_cling_velocity.y: ", held_jump_cling_velocity.y, ", velocity.y: ", velocity.y, ", velocity.x:", velocity.x, ", held_jump_cling_velocity.x: ", held_jump_cling_velocity.x)

		# If gravity direction is reversed (clinging to ceiling)
		elif up_direction == Vector2(0, 1):
			# If ceiling cling just started, return held velocity.x to player. Required to ensure player makes
			# proper contact with ceiling without getting stuck in a loop of moving off and reconnecting.
			if just_started_cling:
				velocity.x = held_jump_cling_velocity.x
				held_jump_cling_velocity.x = 0
				just_started_cling = false
				#print("gravity reversed. cling just started. returning held_jump_cling_velocity.y: ", held_jump_cling_velocity.y, ", velocity.y: ", velocity.y, ", velocity.x:", velocity.x, ", held_jump_cling_velocity.x: ", held_jump_cling_velocity.x)
			# If ceiling cling is ongoing, apply gravity to held_jump_cling_velocity
			# Note - ceiling cling is ongoing if player is on ceiling and held_jump_cling_velocity.y not depleted
			# Note - using is_on_floor because gravity direction is reversed
			# Note - important to continue cling when held_jump_cling_velocity.y == 0, as ending the cling
			# 		 without a positive held_jump_cling_velocity.y will fail to push the player off the ceiling,
			#        and will therefore result in an endless loop
			if is_on_floor() and held_jump_cling_velocity.y <= 0:
				held_jump_cling_velocity.y += gravity*delta
				#print("gravity reversed. cling ongoing, applying gravity to held_jump_cling_velocity.y: ", held_jump_cling_velocity.y, ", velocity.y: ", velocity.y)
			# If ceiling cling is over, return gravity and other variables to normal
			# Note - ceiling cling is over if player left ceiling or held_jump_cling_velocity.y depleted
			else: 
				# If held_jump_cling_velocity depleted, push player off ceiling
				# Else (player has moved off the ceiling), return held_jump_cling_velocity to player
				if held_jump_cling_velocity.y > 0: 
					jump_cling_depleted = true
					velocity.y = max(16, abs(held_jump_cling_velocity.y))
				else:
					velocity.y = held_jump_cling_velocity.y
				# Return up_direction, floor_snap_length, and slide_on_ceiling to normal
				up_direction = Vector2(0, -1)
				floor_snap_length = held_jump_floor_snap_length
				slide_on_ceiling = held_jump_slide_on_ceiling
				#print("gravity reversed. leaving ceiling, returning held_jump_cling_velocity.y:", held_jump_cling_velocity.y, ", velocity.y: ", velocity.y)

	
	move_and_slide()

	
	#  HANDLE SPRITE ROTATION

	if (not is_on_floor()):
		prev_step_was_on_floor_relative = false;
		
		# Copy velocity to new Vector2 with adjusted y component such that: 
		# If player is moving horizontally: don't adjust y (allow full degree of rotation so that top of sprite is always pointed in direction of movement) 
		# Else (no horizontal movement):  clamp y smaller than -1, so sprite is always pointing upward instead of tilting horizontally as velocity.y changes from + to - (sprite should only tilt in air when moving horizontally) 
		var y_clamped = min (-1, velocity.y)
		var flightdir_y_adjusted = Vector2( velocity.x, velocity.y if not velocity.x == 0 else y_clamped)
		# calculate the angle of motion from the new Vector2, then rotate 90 degrees and take modulus to stay within 0 to 360 degrees
		var flightdir_angle_adjusted = fmod(flightdir_y_adjusted.angle()+PI/2, 2*PI)
		# debug print 
		# If in air, and moving up: set rotation in direction of flight with easing
		# If in air, and moving down: snap rotation snap rotation to direction of flight (avoids sluggish response when leaving floor or ceiling)
		# Note - movement "up" or "down" here is global, independant of player up_direction 
		if velocity.y <= 0:
			sprite_2d.rotation = lerp_angle(sprite_2d.rotation, flightdir_angle_adjusted, delta * ROTATION_SPEED)
		else:
			sprite_2d.rotation = lerp_angle(sprite_2d.rotation, flightdir_angle_adjusted, delta * 1/delta)
		
	else:
		var normal_rounded = fmod(deg_to_rad(snapped(rad_to_deg(get_floor_normal().angle()), 1)+90+(180 if up_direction.y == 1 else 0)), PI*2)
		# If on floor, but was not in last step (just landing on floor): snap rotation flush with floor (avoids sluggish response when landing on floor or ceiling)
		# If on floor, but was also on floor in last step (no change): set rotation with easing
		if not prev_step_was_on_floor_relative:
			sprite_2d.rotation = lerp_angle(sprite_2d.rotation,normal_rounded, delta * 1/delta)
			prev_step_was_on_floor_relative = true
		else: 
			sprite_2d.rotation = lerp_angle(sprite_2d.rotation,normal_rounded, delta * ROTATION_SPEED)
