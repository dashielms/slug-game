# player.gd
class_name Player
extends CharacterBody2D

@onready var sprite_2d = $Sprite2D

# Set CharacterBody2D attributes

# Set internal states
# (none yet)


# Set constants
# Set constants for movement
const MAX_X_VELOCITY = 64.0*3
const DELTA_X_VELOCITY_MOVING_GROUND = 64.0*2
const DELTA_X_VELOCITY_MOVING_AIR = 64.0
const DELTA_X_VELOCITY_STOPPING_GROUND = 64.0*4
const DELTA_X_VELOCITY_STOPPING_AIR = 64.0/2.0 # cannot divide by integer or result will be rounded
const JUMP_VELOCITY = 64.0*6.0
const DASH_VELOCITY = 64.0*9.0
const DASH_TIME = .125
const DASH_BUNNYHOP_WINDOW = .75
const DASH_EXIT_Y_VELOCITY_DAMPING = 2.5

# Set constants for sprite animation
const ROTATION_SPEED = 16


# Get global variables from settings, inspector, inputs, etc
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Get global variable defaults from inspector
var default_floor_stop_on_slope = floor_stop_on_slope
var default_floor_constant_speed = floor_constant_speed
var default_floor_snap_length = floor_snap_length

# Get inputs
# Get inputs for running
var move_input_direction = Vector2(
	Input.get_axis("move_left", "move_right"), 
	Input.get_axis("move_up", "move_down")
)


# Set global variables
# Set global variables for dash
var dash_depleted = false

# Set global variables for sprite rotation
# floor_relative is specified as opposed to floor_absolute, in case the up direction
# ever changes and the floor_relative to the up direction no longer matches the 
# the floor_absolute according to an unchanging reference frame where the up direction
# remains the default
var prev_step_was_on_floor_relative = false 


func _physics_process(delta):
	
	# Update the movement input direction
	move_input_direction = Vector2(
		Input.get_axis("move_left", "move_right"), 
		Input.get_axis("move_up", "move_down")
	)
	
	
	#  Handle sprite rotation
	if (not is_on_floor()):
		prev_step_was_on_floor_relative = false;
		
		# Copy velocity to new Vector2 with adjusted y component such that: 
		# If player is moving horizontally: don't adjust y (allow full degree of rotation so that top of sprite is always pointed in direction of movement) 
		# Else (no horizontal movement):  clamp y smaller than -1, so sprite is always pointing upward instead of tilting horizontally as velocity.y changes from + to - (sprite should only tilt in air when moving horizontally) 
		var y_clamped = min (-1, velocity.y)
		var flightdir_y_adjusted = Vector2( velocity.x, velocity.y if not velocity.x == 0 else y_clamped)
		# calculate the angle of motion from the new Vector2, then rotate 90 degrees and take modulus to stay within 0 to 360 degrees
		var flightdir_angle_adjusted = fmod(flightdir_y_adjusted.angle()+PI/2, 2*PI)
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
