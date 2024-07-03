extends CharacterBody3D

const SPEED = 15.0
const JUMP_VELOCITY = 4.5
const ROTATION_SPEED = 7
const SMOOTH_SPEED = 2.0

var last_direction = Vector3(0, 0, -1)
@onready var MESH = $bandit
@onready var SMOKE_TRAIL = $bandit/GPUParticles3D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		#velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		SMOKE_TRAIL.emitting = true
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		last_direction = direction
		var angle = atan2(-last_direction.z, last_direction.x)
		if angle < 0: angle += 2 * PI
		var theta_delta = angle - MESH.rotation.y
		if abs(theta_delta) > PI: MESH.rotation.y += 2 * PI * (abs(theta_delta)/theta_delta)
		MESH.rotation.y = move_toward(MESH.rotation.y, angle, delta*ROTATION_SPEED)
	else:
		SMOKE_TRAIL.emitting = false
		velocity.x = move_toward(velocity.x, 0, SPEED**2*delta)
		velocity.z = move_toward(velocity.z, 0, SPEED**2*delta)
	
	
	

	var col_data = move_and_collide(velocity*delta, true)
	if col_data != null && col_data.get_normal().y == 0 && velocity.y == 0: velocity.y = JUMP_VELOCITY 
	move_and_slide()
	
