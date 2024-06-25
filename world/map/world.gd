extends Node3D

@onready var PLAYER = $Bandit as CharacterBody3D
@onready var CAMERA = $camera_man as Node3D

### CAMERA CONSTANTS ###
const CAM_MAX_RANGE = 15
var tracking = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

	var diff_x = abs(CAMERA.position.x - PLAYER.position.x)
	var lerp_speed_x = ((diff_x/CAM_MAX_RANGE)**2.0)*delta
	CAMERA.position.x = lerpf(CAMERA.position.x, PLAYER.position.x, lerp_speed_x)  
	
	var diff_z = abs(CAMERA.position.z - PLAYER.position.z)
	var lerp_speed_z = ((diff_z/CAM_MAX_RANGE)**2.0)*delta
	CAMERA.position.z = lerpf(CAMERA.position.z, PLAYER.position.z, lerp_speed_z)  
