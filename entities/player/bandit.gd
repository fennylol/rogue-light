extends CharacterBody3D
### WISHLIST ###
# health
# inventory



const SPEED = 7.50
const JUMP_VELOCITY = 9.8
const ROTATION_SPEED = 7
const SMOOTH_SPEED = 2.0

var last_direction = Vector3(0, 0, -1)
@onready var MESH = $bandit
@onready var SMOKE_TRAIL = $bandit/GPUParticles3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _physics_process(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var look_input_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var look_direction = (Vector3(look_input_dir.x, 0, look_input_dir.y)).normalized()
	
	var col_data = move_and_collide(velocity*delta, true)
	if col_data != null && col_data.get_normal().y < 0.001 : velocity.y = JUMP_VELOCITY
	if not is_on_floor(): velocity.y -= 5 * gravity * delta
	
	if look_direction:
		rotation.y += look_direction.x * delta
		MESH.rotation.y -= look_direction.x * delta
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		var angle = atan2(-last_direction.z, last_direction.x) + (2*PI if atan2(-last_direction.z, last_direction.x) < 0 else 0.0)
		var theta_delta = angle - MESH.rotation.y
		if abs(theta_delta) > PI: MESH.rotation.y += 2 * PI * (abs(theta_delta)/theta_delta)
		MESH.rotation.y = move_toward(MESH.rotation.y, angle, delta*ROTATION_SPEED)
		last_direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	else:
		SMOKE_TRAIL.emitting = false
		velocity.x = move_toward(velocity.x, 0, SPEED**2*delta)
		velocity.z = move_toward(velocity.z, 0, SPEED**2*delta)
	
	if velocity and is_on_floor():
		SMOKE_TRAIL.emitting = true
	else: 
		SMOKE_TRAIL.emitting = false
	
	move_and_slide()

func reset_rotation():
	rotation.y = 0
	MESH.rotation.y = PI/2
