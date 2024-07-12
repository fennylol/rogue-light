extends Node3D
### WISHLIST ###
# [ ] caravan
# [ ] collect resources
# [x] camera improvements


const TILES = preload("res://world/map/world_tile_list.gd").TILE_NAMES
const WorldBuilder = preload("res://world/map/world_builder.gd")
@onready var PLAYER = $Bandit as CharacterBody3D
@onready var CAMERA = $camera_man as Node3D
@onready var GUI = $Gui as Control
@onready var WORLD = $world_parts as Node3D
@onready var MAP_GRID = $world_parts/GridMap as GridMap
@onready var HEAVENLY_BODIES = $world_parts/lights/heavenly_bodies as Node3D
@onready var STATIC_LIGHTS = $world_parts/lights/static_lights as Node3D

@onready var test_tree = $Redwood
@onready var test_tree2 = $TallPine
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
const CHUNK_SIZE = 16
const CHUNK_COUNT = 16
const MAX_HEIGHT = 10
const PATH_RADIUS = 2
const PATH_TILE = "PATH"
var WORLD_BUILDER = WorldBuilder.new(CHUNK_COUNT, CHUNK_SIZE, MAX_HEIGHT, PATH_RADIUS, PATH_TILE)
var TREES = []


### CAMERA PARAMETERS ###
var CAM_MAX_RANGE = 10
const CAM_SIZE = 20
const FADE_SETTINGS = Vector3(5.0, 20.0, 0.25) # begin dist, end dist, and min alpha
var tracking = false


### TIME ###
enum {AM, PM}
enum {HOUR, MINUTE, PERIOD}
var TIME = [0, 0, PM]
var time_since_tick = 0
var IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS = 1
var TICK_SPEEDS = {"DEFAULT" = 1, "WARP" = 1.0/500, "FROZEN" = 4092024}


##TODO: REMOVE THIS AND MAKE A REAL CONTROLL PANEL AT SOME POINT
func process_dev_commands(_delta):
	if Input.is_action_just_pressed("DEV_refresh"): generate_map()
	if Input.is_action_just_pressed("DEV_time_warp"): change_world_tick_speed(TICK_SPEEDS["WARP"] if IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS != TICK_SPEEDS["WARP"] else TICK_SPEEDS["DEFAULT"] )
	if Input.is_action_just_pressed("DEV_time_freeze"): change_world_tick_speed(TICK_SPEEDS["FROZEN"] if IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS != TICK_SPEEDS["FROZEN"] else TICK_SPEEDS["DEFAULT"] )

func change_world_tick_speed(tick_length): IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS = tick_length


func _ready(): generate_map()


func _process(delta):
	move_camera(delta)
	
	time_since_tick += delta
	if time_since_tick > IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS: 
		time_since_tick -= IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS
		process_world_tick()
	
	process_dev_commands(delta)
	
	var fade_shader: ShaderMaterial = MAP_GRID.mesh_library.get_item_mesh(TILES["TALL_PINE"]).surface_get_material(0)
	if fade_shader:
		fade_shader.set_shader_parameter("player_position", PLAYER.global_transform.origin)
		fade_shader.set_shader_parameter("camera_position", CAMERA.get_child(0).global_transform.origin)
		fade_shader.set_shader_parameter("fade_settings", FADE_SETTINGS)



func _on_map_generation_finished():
	MAP_GRID.queue_free()
	MAP_GRID = WORLD_BUILDER.get_map_grid()
	WORLD.add_child(MAP_GRID)
	center_player()


func process_world_tick():
	TIME[MINUTE] = (TIME[MINUTE] + 1) % 60
	if not TIME[MINUTE]: TIME[HOUR] = ((TIME[HOUR] + 1) % 12)
	if not (TIME[HOUR] or TIME[MINUTE]): TIME[PERIOD] = (TIME[PERIOD] + 1) % 2
	GUI.update_display(TIME)
	
	HEAVENLY_BODIES.rotate_z(-(2*PI)/1440.0)
	
	var fade_light = STATIC_LIGHTS.get_child(TIME[PERIOD]) as DirectionalLight3D
	if TIME[HOUR] == 5:
		var rising_light = HEAVENLY_BODIES.get_child(TIME[PERIOD]) as DirectionalLight3D
		rising_light.light_energy += 1/60.0
		fade_light.light_energy += 2/60.0
	elif TIME[HOUR] == 6:
		var setting_light = HEAVENLY_BODIES.get_child(not TIME[PERIOD]) as DirectionalLight3D
		setting_light.light_energy -= 1/60.0
		fade_light.light_energy -= 2/60.0



func center_player():
	var midpoint = CHUNK_COUNT/2.0 * CHUNK_SIZE as int
	var i = -1
	while MAP_GRID.get_cell_item(Vector3i(midpoint,i,midpoint)) == -1: i+=1
	PLAYER.position = Vector3(midpoint, i+1, midpoint)
	reset_camera_position()
	#reset_camera_rotation()


func move_camera(delta):
	var diff_x = abs(CAMERA.position.x - PLAYER.position.x)
	var lerp_speed_x = ((diff_x/(CAMERA.get_child(0).size/4))**2.0)*delta
	#var lerp_speed_x = ((diff_x/CAM_MAX_RANGE)**2.0)*delta
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
	
	if Input.is_action_pressed("look_up") and Input.is_action_pressed("look_down"): reset_camera_position()
	if Input.is_action_pressed("look_left") and Input.is_action_pressed("look_right"): reset_camera_rotation()

func reset_camera_position():
		CAMERA.get_child(0).size = CAM_SIZE
		CAMERA.position = PLAYER.position

func reset_camera_rotation():
		CAMERA.rotation = Vector3.ZERO
		PLAYER.reset_rotation()


func generate_map():
	WORLD_BUILDER = WorldBuilder.new(CHUNK_COUNT, CHUNK_SIZE, MAX_HEIGHT, PATH_RADIUS, PATH_TILE)
	WORLD_BUILDER.connect("finished", _on_map_generation_finished)
	WORLD_BUILDER.generate_map()

