extends Node3D
### WISHLIST ###
# [ ] caravan
# [ ] collect resources
# [x] camera improvements

var DUKE = TheDuke
var ARCHIVIST = TheArchivist
var FOOL = TheFool
const WorldBuilder = preload("res://world/map/world_builder.gd")
var Caravan = preload("res://entities/caravan/caravan.gd")
@onready var PLAYER = $Bandit as CharacterBody3D
@onready var CAMERA = $camera_man as Node3D
@onready var GUI = $Gui as Control
@onready var WORLD = $world_parts as Node3D
@onready var MAP_GRID = $world_parts/GridMap as GridMap
@onready var HEAVENLY_BODIES = $world_parts/lights/heavenly_bodies as Node3D
@onready var STATIC_LIGHTS = $world_parts/lights/static_lights as Node3D

### WORLD GEN PARAMETERS ###
# # # # # # # # # # # # #
# + > X |       |       #
# v     |       |       #
# Z     |       |       #
# - - - + - - - + - - - #
#       |       |       #
#       |       |       #
#       |       |       #
# - - - + - - - + - - - #
#       |       |       #
#       |       |       #
#       |       |       #
# # # # # # # # # # # # #
const CHUNK_SIZE = 64
const CHUNK_COUNT = 4
const MAX_HEIGHT = 40
const PATH_RADIUS = 2 #dist past the centerline on either side. path will be 2r+1 tiles wide
const PATH_TILE = "PATH"
const DEBUG_MODE = true
var WORLD_BUILDER = WorldBuilder.new(CHUNK_SIZE, CHUNK_COUNT, MAX_HEIGHT, PATH_RADIUS, PATH_TILE, DEBUG_MODE)
var TREES = []


### CAMERA PARAMETERS ###
var CAM_MAX_RANGE = 10
const CAM_SIZE = 20
var FADE_SETTINGS = Vector3(5.0, 20.0, 0.25) # begin dist, end dist, and min alpha
var tracking = false


#### TIME ###
enum {AM, PM}
enum {HOUR, MINUTE, PERIOD, DAY}
var SHIPPING_SCHEDULE: Vector4i = Vector4i(13,14,0,0)
const SCHEDULE_LENGTH = 2
const CARAVAN_MPS = 4 #meters/sec


func _ready(): 
	generate_map()
	DUKE.tick.connect(process_world_tick)
	DUKE.command_dispatch.connect(recieve_orders)


func recieve_orders(orders: Dictionary):
	if orders.command_name == "resetworld": generate_map()
	elif orders.command_name == "setfade": COMMAND_setfade(orders.options)


func _process(delta):
	move_camera(delta)
	if DUKE.PAUSED: return
	var fade_material: Material = MAP_GRID.mesh_library.get_item_mesh(ARCHIVIST.TILE_NAMES["TALL_PINE"]).surface_get_material(0)
	if fade_material is ShaderMaterial:
		fade_material.set_shader_parameter("player_position", PLAYER.global_transform.origin)
		fade_material.set_shader_parameter("camera_position", CAMERA.get_child(0).global_transform.origin)
		fade_material.set_shader_parameter("fade_settings", FADE_SETTINGS)
	else:
		var shader_material = ShaderMaterial.new() as ShaderMaterial
		shader_material.shader = preload("res://world/map/trees/tree_fade.gdshader")
		var texture = preload("res://world/map/trees/tall_pine.png")
		shader_material.set_shader_parameter("albedo_texture", texture)
		MAP_GRID.mesh_library.get_item_mesh(ARCHIVIST.TILE_NAMES["TALL_PINE"]).surface_set_material(0, shader_material)


func process_world_tick(TIME: Vector4i):
	# adjust lighting
	var hour =  12 - TIME[HOUR] + TIME[PERIOD]*12 
	HEAVENLY_BODIES.rotation_degrees.z = hour*(360/24) - TIME[MINUTE]*(15.0/60.0)
	
	var fade_light = STATIC_LIGHTS.get_child(TIME[PERIOD]) as DirectionalLight3D
	if TIME[HOUR] == 5:
		var rising_light = HEAVENLY_BODIES.get_child(TIME[PERIOD]) as DirectionalLight3D
		rising_light.light_energy = TIME[MINUTE]/60.0
		fade_light.light_energy = TIME[MINUTE]*2/60.0
	elif TIME[HOUR] == 6:
		var setting_light = HEAVENLY_BODIES.get_child(not TIME[PERIOD]) as DirectionalLight3D
		setting_light.light_energy = 1-TIME[MINUTE]/60.0
		fade_light.light_energy = 2-TIME[MINUTE]*2/60.0
	else: 
		STATIC_LIGHTS.get_child(0).light_energy = 0
		STATIC_LIGHTS.get_child(1).light_energy = 0
	
	# schedule caravan
	var schedule_progress = TIME[DAY] % SCHEDULE_LENGTH
	if not (schedule_progress or TIME[MINUTE] or TIME[PERIOD]) and TIME[HOUR] == 6:
		SHIPPING_SCHEDULE.x = FOOL.range_i(0,SCHEDULE_LENGTH)
		SHIPPING_SCHEDULE.y = FOOL.range_i(0,SCHEDULE_LENGTH-1)
		SHIPPING_SCHEDULE.z = FOOL.range_i(0, 1439)
		SHIPPING_SCHEDULE.w = FOOL.range_i(0, 1439)
		if SHIPPING_SCHEDULE.y >= SHIPPING_SCHEDULE.x: SHIPPING_SCHEDULE.y += 1
	if  ((schedule_progress == SHIPPING_SCHEDULE.x) and \
		(TIME[PERIOD]*720 + TIME[HOUR]*60 + TIME[MINUTE] == SHIPPING_SCHEDULE.z)) or \
		((schedule_progress == SHIPPING_SCHEDULE.y) and \
		(TIME[PERIOD]*720 + TIME[HOUR]*60 + TIME[MINUTE] == SHIPPING_SCHEDULE.w)):
			send_shipment()


func send_shipment():
	print("A CARAVAN ENTERS THE FOREST")
	var path = WORLD_BUILDER.get_road_path()
	var path3d = Path3D.new()
	path3d.set_curve(Curve3D.new())
	
	for points in path:
		path3d.curve.add_point(points[0], Vector3.ZERO, (points[1]-points[0])*0.8)
		path3d.curve.add_point(points[2], (points[1]-points[2])*0.8)
	
	
	#path3d.position.y += 2.5
	var caravan = Caravan.init(path3d.curve.get_baked_length()/CARAVAN_MPS)
	path3d.add_child(caravan)
	WORLD.add_child(path3d)

func generate_map():
	WORLD_BUILDER = WorldBuilder.new(CHUNK_SIZE, CHUNK_COUNT, MAX_HEIGHT, PATH_RADIUS, PATH_TILE, DEBUG_MODE)
	WORLD_BUILDER.finished.connect(on_map_generation_finished)
	WORLD_BUILDER.generate_map()


func on_map_generation_finished():
	MAP_GRID.queue_free()
	MAP_GRID = WORLD_BUILDER.get_map_grid()
	WORLD.add_child(MAP_GRID)
	center_player()


func center_player():
	var midpoint = CHUNK_COUNT/2.0 * CHUNK_SIZE as int
	
	PLAYER.position = Vector3(midpoint, WORLD_BUILDER.get_heightmap()[midpoint][midpoint]+2, midpoint)
	reset_camera()


func move_camera(delta):
	var diff_x = abs(CAMERA.position.x - PLAYER.position.x)
	var lerp_speed_x = ((diff_x/(CAMERA.get_child(0).size/4))**2.0)*delta
	CAMERA.position.x = lerpf(CAMERA.position.x, PLAYER.position.x, lerp_speed_x)  
	
	var diff_y = abs(CAMERA.position.y - PLAYER.position.y)
	var lerp_speed_y = (diff_y**2.0)*delta
	CAMERA.position.y = lerpf(CAMERA.position.y, PLAYER.position.y, lerp_speed_y)
	
	var diff_z = abs(CAMERA.position.z - PLAYER.position.z)
	var lerp_speed_z = ((diff_z/(CAMERA.get_child(0).size/4))**2.0)*delta
	CAMERA.position.z = lerpf(CAMERA.position.z, PLAYER.position.z, lerp_speed_z)
	
	var look_input_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var look_direction = (transform.basis * Vector3(look_input_dir.x, 0, look_input_dir.y)).normalized()
	if look_direction:
		CAMERA.rotation.y += look_direction.x * delta
		if CAMERA.get_child(0).size > 5 or look_direction.z > 0: CAMERA.get_child(0).size += look_direction.z 
	
	if Input.is_action_pressed("DEV"):
		if Input.is_action_pressed("look_up") and Input.is_action_pressed("look_down"): reset_camera(false, false, true)
		if Input.is_action_pressed("look_left") and Input.is_action_pressed("look_right"): reset_camera(false, true, false)
		if Input.is_action_pressed("look_up") and Input.is_action_pressed("look_left"): reset_camera()


func reset_camera(p: bool = true, r: bool = true, s: bool = true):
	if p: CAMERA.position = PLAYER.position
	if r: CAMERA.rotation = Vector3.ZERO; PLAYER.reset_rotation()
	if s: CAMERA.get_child(0).size = CAM_SIZE


func COMMAND_setfade(options: Dictionary):
	var begin: float = FADE_SETTINGS.x
	var end: float = FADE_SETTINGS.y
	var minalpha: float = FADE_SETTINGS.z
	if options.has("begin"): begin = float(options.begin[0])
	if options.has("end"): end = float(options.end[0])
	if options.has("minalpha"): minalpha = float(options.minalpha[0])
	FADE_SETTINGS = Vector3(begin, end, minalpha)
