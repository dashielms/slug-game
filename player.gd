extends CharacterBody2D

@onready var sprite_2d = $Sprite2D

## Set CharacterBody2D attributes


### Set constants

#### Set constants for movement
const MAX_X_VELOCITY = 128.0
const DELTA_X_VELOCITY = 16.0
const JUMP_VELOCITY = -256.0 - 128.0

#### Set constants for ceiling cling
const CEILING_SLIDE_TIME = 1.6
const ROTATION_SPEED = 16


### Get global variables from project settings

#### Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

### Set global variables

#### Set global variables for ceiling cling
var held_velocity = Vector2(0, 0)
var just_started_cling = true
var cling_depleted = false

#### Set global variables for sprite rotation
# floor_relative is specified as opposed to floor_absolute, as during ceiling cling the up direction is 
# reversed and briefly becomes the floor. when the up direction is reversed, floor_relative
# would refer to the ceiling, while floor_absolute will always refer to the level floor
var prev_step_was_on_floor_relative = false 


func _physics_process(delta):

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * MAX_X_VELOCITY, DELTA_X_VELOCITY)
	else:
		# Reduce speed when no horizontal input detected, faster on floor than in air
		velocity.x = move_toward(velocity.x, 0, DELTA_X_VELOCITY*2)



	# HANDLE GRAVITY, JUMPING, AND CLINGING TO CEILING. 
	# Note - Written assuming slide_on_ceiling is off.
	
	# If gravity direction is normal (not clinging to ceiling)
	if up_direction == Vector2(0, -1):
		# If on floor, watch for jump button and initiate jump if pressed
		if is_on_floor():
			if Input.is_action_just_pressed("ui_accept"):
				velocity.y = JUMP_VELOCITY
				# setting held_velocity here is required for the case that the 
				# player is pressing jump while touching both ceiling and floor
				held_velocity.y = velocity.y 
				cling_depleted = false
				print("gravity normal. initiating jump. held_velocity.y: ", held_velocity.y, ", velocity.y: ", velocity.y)
		# If in air and on ceiling, initiate cling by reversing the gravity direction
		# If in air and not on ceiling, apply gravity and update held_velocity.y
		else:
			if is_on_ceiling() and not cling_depleted:
				up_direction = Vector2(0, 1)
				held_velocity.y += gravity*delta
				# save velocity.x and temporarily set to 0, to ensure move_and_slide() does not move 
				# player horizontally off the ceiling before the next frame (which would result in an 
				# infinite loop between moving off the ceiling and reconnecting causing jittery movement). 
				# velocity.x will be returned in next frame once gravity has reversed and the player 
				# has succesfully snapped to the new floor (i.e. the ceiling). set just_started_cling
				# to true, which will be used to ensure the velocity.x is only returned on the next 
				# frame and none after.
				# Note - loop may be avoided without holding x velocity by just setting the floor snap length higher
				held_velocity.x = velocity.x 
				velocity = Vector2(0, -200) 
				just_started_cling = true
				print("gravity normal. initiating cling. held_velocity.y: ", held_velocity.y, ", velocity.y: ", velocity.y, ", velocity.x:", velocity.x, ", held_velocity.x: ", held_velocity.x)
			else:
				velocity.y += gravity * delta
				# track velocity.y while in air, as waiting until is_on_ceiling true results in velocity.y = 0
				held_velocity.y = velocity.y
				print("gravity normal. applying gravity. held_velocity.y: ", held_velocity.y, ", velocity.y: ", velocity.y, ", velocity.x:", velocity.x, ", held_velocity.x: ", held_velocity.x)

	# If gravity direction is reversed (clinging to ceiling)
	elif up_direction == Vector2(0, 1):
		# If ceiling cling just started, return held velocity.x to player. Required to ensure player makes
		# proper contact with ceiling without getting stuck in a loop of moving off and reconnecting.
		if just_started_cling:
			velocity.x = held_velocity.x
			held_velocity.x = 0
			just_started_cling = false
			print("gravity reversed. cling just started. returning held_velocity.y: ", held_velocity.y, ", velocity.y: ", velocity.y, ", velocity.x:", velocity.x, ", held_velocity.x: ", held_velocity.x)
		# If ceiling cling is ongoing, apply gravity to held_velocity
		# Note - ceiling cling is ongoing if player is on ceiling and held_velocity.y not depleted
		# Note - using is_on_floor because gravity direction is reversed
		# Note - important to continue cling when held_velocity.y == 0, as ending the cling
		# 		 without a positive held_velocity.y will fail to push the player off the ceiling,
		#        and will therefore result in an endless loop
		if is_on_floor() and held_velocity.y <= 0:
			held_velocity.y += gravity*delta
			print("gravity reversed. cling ongoing, applying gravity to held_velocity.y: ", held_velocity.y, ", velocity.y: ", velocity.y)
		# If ceiling cling is over, begin applying gravity like normal again
		# Note - ceiling cling is over if player left ceiling or held_velocity.y depleted
		else: 
			# If held_velocity depleted, push player off ceiling
			# Else (player has moved off the ceiling), return held_velocity to player
			if held_velocity.y > 0: 
				cling_depleted = true
				velocity.y = max(16, abs(held_velocity.y))
			else:
				velocity.y = held_velocity.y
			# Return up_direction to normal
			up_direction = Vector2(0, -1)
			print("gravity reversed. leaving ceiling, returning held_velocity.y:", held_velocity.y, ", velocity.y: ", velocity.y)

	
	var up = Input.is_action_pressed("ui_up")
	if up:
		print("up", up)
		
	
	move_and_slide()

	
			# debug print 
	#print("delta:", delta)
	#print("rotation:", sprite_2d.rotation_degrees)
	#print("velocity.y: ", velocity.y)
	#print("velocity_angle: ", velocity.angle())

	if (not is_on_floor()):
		prev_step_was_on_floor_relative = false;
		
		# Copy velocity to new Vector2 with adjusted y component such that: 
		# If player is moving horizontally: don't adjust y (allow full degree of rotation so that top of sprite is always pointed in direction of movement) 
		# Else (no horizontal movement):  clamp y smaller than -1, so sprite is always pointing upward instead of tilting horizontally as velocity.y changes from + to - (looks weird because sprite is only supposed to tilt in air when moving horizontally) 
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
	

# figured out issue: grav reverses properly on  initial ceiling hit but thinks player is 
# repeatedly leaving the ceiling, setting grav to normal but returning remaining 
# velocity to the player, who then hit the ceiling, resulting in a loop. 
# player needs to snap onto ceiling like he does onto the floor
# 
