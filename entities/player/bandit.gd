extends CharacterBody3D
### WISHLIST ###
# health
# inventory


var PAUSED = false
const SPEED: float = 7.50
const SPRINT_MULTI: float = 2
const JUMP_VELOCITY: float = 9.8 #* 2/3 #<- for use with half or quarter height tiles
const ROTATION_SPEED: float = 7
const SMOOTH_SPEED: float = 2.0

var SPAWN_POINT = Vector3.ZERO

# status bars
const MAX_HEALTH: float = 96
const MAX_STAM: float = 100
const SPRINT_SDPS: float = 20 #Stam Drain Per Second
const STAM_RPS: float = 50 #regen per second
var health: float = MAX_HEALTH
var stam: float = MAX_STAM
var recovering_stam: bool = false
const STAM_LOCKOUT: float = 1
var time_since_stam_use: float = 0

var last_direction = Vector3(0, 0, -1)
var last_jump_coords = Vector3.ZERO
var is_banned_from_jumping = false
@onready var MESH = $bandit
@onready var SMOKE_TRAIL = $bandit/GPUParticles3D
@onready var FPV = $bandit/Camera3D as Camera3D
@onready var GUI = $Gui as Control

var DUKE = TheDuke
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready(): 
	DUKE.command_dispatch.connect(recieve_orders)
	GUI.set_bar_max(MAX_HEALTH,MAX_STAM)


func _physics_process(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if DUKE.PAUSED: return
	
	# stam adjustments
	var speed = SPEED
	var jump_velocity = JUMP_VELOCITY
	if Input.is_action_pressed("sprint") and not recovering_stam and direction:
		speed *= SPRINT_MULTI
		jump_velocity *= SPRINT_MULTI
		get_tired(delta*SPRINT_SDPS)
		time_since_stam_use = 0
	else: 
		var growth_multi: float = 0.6
		time_since_stam_use += delta
		if time_since_stam_use > STAM_LOCKOUT: get_tired(-delta*max(stam,5)*growth_multi)
	
	if not stam: recovering_stam = true
	if stam > MAX_STAM*0.6: recovering_stam = false
	
	# vertical movement
	var col_data = move_and_collide(velocity*delta, true)
	# if this surface can be climbed
	if col_data != null and col_data.get_normal().y < 0.5 and not col_data.get_collider().is_in_group("slick"):
		# if this isnt the same spot you just jumped off
		if abs((last_jump_coords-position).length()) > 0.001 and not is_banned_from_jumping : 
			velocity.y = jump_velocity
			last_jump_coords = position
		else: 
			# TODO: fix this crap
			print("stuck ", (last_jump_coords-position).length())
			if is_banned_from_jumping: 
				position += col_data.get_normal() * .5
				print("blast off")
			else: is_banned_from_jumping = true
	elif col_data != null and col_data.get_normal().y > 0.5: is_banned_from_jumping = false
	if not is_on_floor(): velocity.y -= 5 * gravity * delta
	

	# horizontal movement
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		var angle = atan2(-last_direction.z, last_direction.x) + (2*PI if atan2(-last_direction.z, last_direction.x) < 0 else 0.0)
		var theta_delta = angle - MESH.rotation.y
		if abs(theta_delta) > PI: MESH.rotation.y += 2 * PI * (abs(theta_delta)/theta_delta)
		MESH.rotation.y = move_toward(MESH.rotation.y, angle, delta*ROTATION_SPEED)
		last_direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	else:
		velocity.x = move_toward(velocity.x, 0, speed**2*delta)
		velocity.z = move_toward(velocity.z, 0, speed**2*delta)
	
	# partical trail
	var vel: float = velocity.length()
	SMOKE_TRAIL.emitting = bool(vel)
	move_and_slide()

func get_spawn_point() -> Vector3: return SPAWN_POINT
func set_spawn_point(sp: Vector3 = Vector3.ZERO): SPAWN_POINT = sp
func set_full_minimap(map: Image): GUI.set_full_minimap(map)

func take_damage(amount: int = 6):
	health = max(min(health-amount,MAX_HEALTH),0)
	GUI.set_health(health)

func get_tired(amount: float): 
	stam = max(min(stam-amount,MAX_STAM),0)
	GUI.set_stam(stam)

func rotate_player(amount: float):
	rotation.y += amount
	MESH.rotation.y -= amount
	GUI.rotate_compass(amount)

func reset_rotation():
	rotation.y = 0
	MESH.rotation.y = PI/2

func enable_camera(state: bool = true):FPV.set_current(state)


func recieve_orders(orders: Dictionary):
	#var COMMAND_ = func(options: Dictionary): 
		#if options.has(""): pass
	
	var COMMAND_health = func(options: Dictionary): 
		if options.has("set"): take_damage(-(int(options.set[0]) - health))
		elif options.has("take"): take_damage(int(options.take[0]))
	
	var COMMAND_stam = func(options: Dictionary): 
		if options.has("set"): get_tired(-(int(options.set[0]) - health))
		elif options.has("take"): get_tired(int(options.take[0]))
	
	if orders.command_name == "health": COMMAND_health.call(orders.options)
	elif orders.command_name == "stam": COMMAND_stam.call(orders.options)
