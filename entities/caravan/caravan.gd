extends PathFollow3D

# this is for timing caravan sending. this is just for debug purposes dont let this stick around
var length = 20

var TIME_TO_COMPLETE: float
var HEIGHT_MAP: Array
var WORLD_SCALE: Vector3
var DUKE = TheDuke

var height_offset = 0#4
var target_height: float
var forward_tilt: float = 0
var side_tilt: float = 0
var TILT_SPEED: float = 10
var TRANSLATE_SPEED: float = 5

@onready var body = $AnimatableBody3D as AnimatableBody3D
@onready var rt = $RemoteTransform3D
@onready var wheels = [$suspension/FL, $suspension/FR, $suspension/BL, $suspension/BR]
signal finished

static func init(hm: Array, ws: Vector3, ttc: float = 30.0):
	var new_caravan = load("res://entities/caravan/caravan2.tscn").instantiate()
	new_caravan.TIME_TO_COMPLETE = ttc
	new_caravan.HEIGHT_MAP = hm
	new_caravan.WORLD_SCALE = ws
	return new_caravan

func _process(delta): 
	
	target_height = height_at(position) + height_offset
	
	var heights = []
	for wheel in wheels:
		var h = height_at(wheel.get_global_position())
		wheel.position.y = lerp(wheel.position.y, h, delta*TRANSLATE_SPEED)
		#wheel.get_child(0).position.y=h
		heights.push_back(wheel.get_global_position())
		#wheel.get_child(0).position.y+=1.75
		wheel.rotation.z = lerp(wheel.rotation.z, side_tilt, delta*TILT_SPEED)
	
	var avg_forward_angle = ((heights[0]-heights[2])+(heights[1]-heights[3]))/2.0
	var avg_side_angle = ((heights[1]-heights[0])+(heights[3]-heights[2]))/2.0
	forward_tilt = get_angle_from_floor(avg_forward_angle)
	side_tilt = get_angle_from_floor(avg_side_angle)
	
	rt.rotation = lerp(rt.rotation, Vector3(forward_tilt, 0, side_tilt), delta*TILT_SPEED)# Vector3(forward_tilt, 0, side_tilt)
	rt.position.y = lerp(rt.position.y, target_height, delta*TRANSLATE_SPEED)
	
	if not progress_ratio: rt.position.y = target_height
	
	if not DUKE.PAUSED: set_progress_ratio(get_progress_ratio()+delta/TIME_TO_COMPLETE)
	if progress_ratio == 1: 
		finished.emit()
		self.queue_free()


func height_at(coords: Vector3):
	var scaled_pos = Vector3(coords.x, 0, coords.z)/WORLD_SCALE
	var x = int(min(max(scaled_pos.x,0),HEIGHT_MAP.size()-1))
	var y = int(min(max(scaled_pos.z,0),HEIGHT_MAP.size()-1))
	return HEIGHT_MAP[x][y]*WORLD_SCALE.y


func get_angle_from_floor(hypotenuse: Vector3) -> float:
	# Get the length of the projection on the XZ plane
	var xz_length = Vector2(hypotenuse.x, hypotenuse.z).length()
	# Calculate the angle using atan2
	var angle = atan2(hypotenuse.y, xz_length)
	# To get the angle from the floor, we need to subtract this angle from PI/2 (90 degrees)
	#var angle_from_floor = PI/2 - angle
	return angle
