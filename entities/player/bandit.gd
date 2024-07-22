extends CharacterBody3D
### WISHLIST ###
# health
# inventory


var PAUSED = false
const SPEED = 7.50
const JUMP_VELOCITY = 9.8 * 2/3 #<- for use with half or quarter height tiles
const ROTATION_SPEED = 7
const SMOOTH_SPEED = 2.0

var last_direction = Vector3(0, 0, -1)
var last_jump_coords = Vector3.ZERO
var is_banned_from_jumping = false
@onready var MESH = $bandit
@onready var SMOKE_TRAIL = $bandit/GPUParticles3D
@onready var FPV = $bandit/Camera3D as Camera3D
var DUKE = TheDuke
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if DUKE.PAUSED: return
	
	var col_data = move_and_collide(velocity*delta, true)
	if col_data != null and col_data.get_normal().y < 0.5: 
		if abs((last_jump_coords-position).length()) > 0.001 and not is_banned_from_jumping: 
			velocity.y = JUMP_VELOCITY
			last_jump_coords = position
		else: 
			print("stuck ", (last_jump_coords-position).length())
			if is_banned_from_jumping: 
				position += col_data.get_normal() * .5
				print("blast off")
			else: is_banned_from_jumping = true
	elif col_data != null and col_data.get_normal().y > 0.5: is_banned_from_jumping = false
	
	if not is_on_floor(): velocity.y -= 5 * gravity * delta
	
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		var angle = atan2(-last_direction.z, last_direction.x) + (2*PI if atan2(-last_direction.z, last_direction.x) < 0 else 0.0)
		var theta_delta = angle - MESH.rotation.y
		if abs(theta_delta) > PI: MESH.rotation.y += 2 * PI * (abs(theta_delta)/theta_delta)
		MESH.rotation.y = move_toward(MESH.rotation.y, angle, delta*ROTATION_SPEED)
		last_direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED**2*delta)
		velocity.z = move_toward(velocity.z, 0, SPEED**2*delta)
	
	SMOKE_TRAIL.emitting = velocity.length() > 0.9*SPEED
	
	move_and_slide()

func rotate_player(amount: float):
	rotation.y += amount
	MESH.rotation.y -= amount

func reset_rotation():
	rotation.y = 0
	MESH.rotation.y = PI/2

func enable_camera(state: bool = true):FPV.set_current(state)
