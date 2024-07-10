extends Node3D
### WISHLIST ###
# caravan
# collect resources
# camera improvements


const WORLD_TILE_LIST = preload("res://world/map/world_tile_list.gd")
const WorldBuilder = preload("res://world/map/world_builder.gd")
@onready var PLAYER = $Bandit as CharacterBody3D
@onready var CAMERA = $camera_man as Node3D
@onready var GUI = $Gui as Control
@onready var WORLD = $world_parts as Node3D
@onready var MAP_GRID = $world_parts/GridMap as GridMap
@onready var LIGHTS = $world_parts/lights as Node3D


@onready var test_tree = $Redwood
@onready var test_tree2 = $Redwood2
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
const CHUNK_SIZE = 8
const CHUNK_COUNT = 8
const MAX_HEIGHT = 10
const PATH_RADIUS = 2
const PATH_TILE = "PATH"
var WORLD_BUILDER = WorldBuilder.new(CHUNK_COUNT, CHUNK_SIZE, MAX_HEIGHT, PATH_RADIUS, PATH_TILE)
var generating = false


### CAMERA PARAMETERS ###
var CAM_MAX_RANGE = 10
const CAM_SIZE = 20
var tracking = false


### TIME ###
enum {AM, PM}
enum {HOUR, MINUTE, PERIOD}
var TIME = [0, 0, PM]
var time_since_tick = 0
var IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS = 1
var TIME_WARP_SPEED = 500.0 
var IGMLIRWS = IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS
var TIME_FROZEN = false

##TODO: REMOVE THIS AND MAKE A REAL CONTROLL PANEL AT SOME POINT
func process_dev_commands(delta):
	if Input.is_action_just_pressed("DEV_refresh"): generate_map()
	if Input.is_action_just_pressed("DEV_time_warp"): IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS /= TIME_WARP_SPEED
	if Input.is_action_just_released("DEV_time_warp"): IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS *= TIME_WARP_SPEED
	if Input.is_action_just_pressed("DEV_time_freeze"): IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS = (IGMLIRWS if TIME_FROZEN else 4092024); TIME_FROZEN = not TIME_FROZEN


func _ready(): generate_map()


func _process(delta):
	move_camera(delta)
	
	time_since_tick += delta
	if time_since_tick > IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS: 
		time_since_tick -= IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS
		process_world_tick()
	
	process_dev_commands(delta)
	
	var material: ShaderMaterial = test_tree.get_surface_override_material(0)
	if material:
		material.set_shader_parameter("player_position", PLAYER.global_transform.origin)
		material.set_shader_parameter("camera_position", CAMERA.get_child(0).global_transform.origin)
	
	material = test_tree2.get_surface_override_material(0)
	if material:
		material.set_shader_parameter("player_position", PLAYER.global_transform.origin)
		material.set_shader_parameter("camera_position", CAMERA.get_child(0).global_transform.origin)


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
	
	LIGHTS.rotate_z((2*PI)/1440)
	
	if TIME[HOUR] == 6: 
		var sun = LIGHTS.get_child(0) as DirectionalLight3D
		var moon = LIGHTS.get_child(1) as DirectionalLight3D
		#sun.visible = not TIME[PERIOD]
		#moon.visible = not not TIME[PERIOD]
	
	if TIME[HOUR] == 5:
		var rising_light = LIGHTS.get_child(TIME[PERIOD]) as DirectionalLight3D
		rising_light.light_energy += 1/60.0
	elif TIME[HOUR] == 6:
		var setting_light = LIGHTS.get_child(not TIME[PERIOD]) as DirectionalLight3D
		setting_light.light_energy -= 1/60.0



func center_player():
	var midpoint = CHUNK_COUNT/2.0 * CHUNK_SIZE as int
	var i = -1
	while MAP_GRID.get_cell_item(Vector3i(midpoint,i,midpoint)) == -1: i+=1
	PLAYER.position = Vector3(midpoint, i+1, midpoint)
	reset_camera_position()
	reset_camera_rotation()


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
		CAMERA.get_child(0).size += look_direction.z 
	
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



#func generate_map():
	#MAP_GRID.clear()
	#generate_chunks()
	#generate_directed_path()
	#center_player()
	
#func generate_map_asynch(heightmap):
	#MAP_GRID.clear()
	#generate_chunks(heightmap)
	#generate_directed_path()
	#center_player()

#func generate_noise_heightmap(width: int, height: int, max_height: int, seed: int = randi(), frequency: float = 0.005, lacunarity: float = 2.0, gain: float = 0.5) -> Array:
	#var noise = FastNoiseLite.new()
	#noise.set_seed(seed)
	#noise.set_noise_type(FastNoiseLite.TYPE_SIMPLEX) 
	#noise.set_frequency(frequency)
	#noise.set_fractal_lacunarity(lacunarity)
	#noise.set_fractal_gain(gain)
	#noise.set_fractal_type(FastNoiseLite.FRACTAL_RIDGED)
	#
	#var heightmap = []
	#for x in range(width):
		#var row = []
		#for y in range(height):
			#var noise_value = noise.get_noise_2d(x, y)
			## Convert noise value (-1 to 1) to (0 to 1) range
			#var t = (noise_value + 1) * 0.5
			## Discretize to 6 levels (0 to 5)
			#var height_value = int(round(t * max_height))
			#row.append(height_value)
		#heightmap.append(row)
	#return heightmap
#
#
#func generate_chunks(height_map: Array = [], show_chunks: bool = false):
	#var hm = generate_noise_heightmap(CHUNK_COUNT*CHUNK_SIZE,CHUNK_COUNT*CHUNK_SIZE,10) if height_map == [] else height_map
	#for i in hm.size():
		#for j in hm[i].size():
			#if show_chunks: set_column(i,j,hm[i][j],"GRASS" if (i/CHUNK_SIZE + j/CHUNK_SIZE)%2 == 0 else "WOOD")
			#else: 
				#if i == 0 or j == 0 or i == hm.size()-1 or j == hm[i].size()-1: 
					#set_column(i,j,hm[i][j],"GRASS" if hm[i][j] > 4 else "WOOD")
				#else:
					#set_tile_z(i,j,hm[i][j],"GRASS" if hm[i][j] > 4 else "WOOD")
#
#
#func generate_full_path():
	## determine edges and chunk indices for start/end points
	#var org_edge = randi_range(0, 3) # which edge (^,>,v,<) the path begins/ends
	#var term_edge = org_edge
	#while term_edge == org_edge: term_edge = randi_range(0, 3)
	## which chunk along that edge the path begins/ends
	#var org_chunk = randi_range(0, CHUNK_COUNT - 1) 
	#var term_chunk = randi_range(0, CHUNK_COUNT - 1)
	##(X,Y) coords in the chunk grid
	#var org_chunk_coords 
	#var mid_chunk_coords = Vector2(randi_range(0, CHUNK_COUNT - 1), randi_range(0, CHUNK_COUNT - 1))
	#var term_chunk_coords
	#
	## turn edge/chunk index into chunk coordinates
	#if org_edge == 0: org_chunk_coords = Vector2(org_chunk, 0)
	#elif org_edge == 1: org_chunk_coords = Vector2(CHUNK_COUNT - 1, org_chunk)
	#elif org_edge == 2: org_chunk_coords = Vector2(org_chunk, CHUNK_COUNT - 1)
	#else: org_chunk_coords = Vector2(0, org_chunk)
	#
	#if term_edge == 0: term_chunk_coords = Vector2(term_chunk, 0)
	#elif term_edge == 1: term_chunk_coords = Vector2(CHUNK_COUNT - 1, term_chunk)
	#elif term_edge == 2: term_chunk_coords = Vector2(term_chunk, CHUNK_COUNT - 1)
	#else: term_chunk_coords = Vector2(0, term_chunk)
	#
	## prevent both endpoints being the same corner chunk
	#if org_chunk_coords == term_chunk_coords && CHUNK_COUNT != 1:
		#if randi_range(0, 1):
			#if term_chunk_coords.x < CHUNK_COUNT/2: term_chunk_coords.x += CHUNK_COUNT/2;
			#else: term_chunk_coords.x -= CHUNK_COUNT/2
		#else:
			#if term_chunk_coords.y < CHUNK_COUNT/2: term_chunk_coords.y += CHUNK_COUNT/2;
			#else: term_chunk_coords.y -= CHUNK_COUNT/2
	#
	#
	#
	## trace first leg
	#var dX = mid_chunk_coords.x - org_chunk_coords.x
	#var dY = mid_chunk_coords.y - org_chunk_coords.y
	#while org_chunk_coords != mid_chunk_coords:
		#generate_path(org_chunk_coords.x * CHUNK_SIZE as int, org_chunk_coords.y * CHUNK_SIZE as int)
		#var move_x
		#if dX != 0 && dY != 0: move_x = randi_range(0, 1)
		#elif dX != 0: move_x = 1 
		#else: move_x = 0 
		#
		#if move_x: org_chunk_coords.x += dX/abs(dX)
		#else: org_chunk_coords.y += dY/abs(dY)
		#dX = mid_chunk_coords.x - org_chunk_coords.x
		#dY = mid_chunk_coords.y - org_chunk_coords.y
	#
	## trace second leg
	#dX = term_chunk_coords.x - org_chunk_coords.x
	#dY = term_chunk_coords.y - org_chunk_coords.y
	#while org_chunk_coords != term_chunk_coords:
		#generate_path(org_chunk_coords.x * CHUNK_SIZE as int, org_chunk_coords.y * CHUNK_SIZE as int)
		#var move_x
		#if dX != 0 && dY != 0: move_x = randi_range(0, 1)
		#elif dX != 0: move_x = 1 
		#else: move_x = 0 
		#
		#if move_x: org_chunk_coords.x += dX/abs(dX)
		#else: org_chunk_coords.y += dY/abs(dY)
		#dX = term_chunk_coords.x - org_chunk_coords.x
		#dY = term_chunk_coords.y - org_chunk_coords.y
	#generate_path(term_chunk_coords.x * CHUNK_SIZE as int, term_chunk_coords.y * CHUNK_SIZE as int)
	#
	## calculate 3 steps. working from the middle, direct the path
#
#
#
#func generate_directed_path():
	## determine block, edge and chunk indices for start/end points
	#var org_block = CHUNK_SIZE/2 #randi_range(0, CHUNK_SIZE - 1)# the block index of where the path begins/ends
	#var org_edge = randi_range(0, 3) # which edge (^,>,v,<) the path begins/ends
	#var term_edge = org_edge
	#while term_edge == org_edge: term_edge = randi_range(0, 3)
	## which chunk along that edge the path begins/ends
	#var org_chunk = randi_range(0, CHUNK_COUNT - 1) 
	#var term_chunk = randi_range(0, CHUNK_COUNT - 1)
	##(X,Y) coords in the chunk grid
	#var org_chunk_coords 
	#var mid_chunk_coords = Vector2(randi_range(1, CHUNK_COUNT - 2), randi_range(1, CHUNK_COUNT - 2))
	#var term_chunk_coords
	#
	## turn edge/chunk index into chunk coordinates
	#if org_edge == 0: 
		#org_chunk_coords = Vector2(org_chunk, 0)
		#org_block = (org_chunk_coords * CHUNK_SIZE) + Vector2(org_block, 0)
	#elif org_edge == 1: 
		#org_chunk_coords = Vector2(CHUNK_COUNT - 1, org_chunk)
		#org_block = (org_chunk_coords * CHUNK_SIZE) + Vector2(CHUNK_SIZE - 1, org_block)
	#elif org_edge == 2: 
		#org_chunk_coords = Vector2(org_chunk, CHUNK_COUNT - 1)
		#org_block = (org_chunk_coords * CHUNK_SIZE) + Vector2(org_block, CHUNK_SIZE - 1)
	#else: 
		#org_chunk_coords = Vector2(0, org_chunk)
		#org_block = (org_chunk_coords * CHUNK_SIZE) + Vector2(0, org_block)
	#
	#if term_edge == 0: term_chunk_coords = Vector2(term_chunk, 0)
	#elif term_edge == 1: term_chunk_coords = Vector2(CHUNK_COUNT - 1, term_chunk)
	#elif term_edge == 2: term_chunk_coords = Vector2(term_chunk, CHUNK_COUNT - 1)
	#else: term_chunk_coords = Vector2(0, term_chunk)
	#
	## prevent endpoints from spawning onh the same corner
	#if CHUNK_COUNT != 1 && org_chunk_coords == term_chunk_coords:
		#if randi_range(0, 1):
			#if term_chunk_coords.x < CHUNK_COUNT/2: term_chunk_coords.x += CHUNK_COUNT/2;
			#else: term_chunk_coords.x -= CHUNK_COUNT/2
		#else:
			#if term_chunk_coords.y < CHUNK_COUNT/2: term_chunk_coords.y += CHUNK_COUNT/2;
			#else: term_chunk_coords.y -= CHUNK_COUNT/2
	#
	## trace first leg
	#var next_starting_point = org_block
	#var move_x 
	#var dist
	#var dir
	#while org_chunk_coords != mid_chunk_coords:
		#dist = mid_chunk_coords - org_chunk_coords
		#if dist.x != 0 && dist.y != 0: move_x = randi_range(0, 1)
		#elif dist.x != 0: move_x = 1 
		#else: move_x = 0  
		#dir = Vector2(dist.x/abs(dist.x) * move_x, dist.y/abs(dist.y) * (1-move_x))
		#if is_nan(dir.x): dir.x = 0
		#if is_nan(dir.y): dir.y = 0  
		#next_starting_point = extend_path(org_chunk_coords, next_starting_point, dir)
		#org_chunk_coords += dir
	#
	#while org_chunk_coords != term_chunk_coords:
		#dist = term_chunk_coords - org_chunk_coords
		#if dist.x != 0 && dist.y != 0: move_x = randi_range(0, 1)
		#elif dist.x != 0: move_x = 1 
		#else: move_x = 0  
		#dir = Vector2(dist.x/abs(dist.x) * move_x, dist.y/abs(dist.y) * (1-move_x))
		#if is_nan(dir.x): dir.x = 0
		#if is_nan(dir.y): dir.y = 0  
		#next_starting_point = extend_path(org_chunk_coords, next_starting_point, dir)
		#org_chunk_coords += dir
#
	#if term_edge == 0: dir = Vector2(0, -1)
	#elif term_edge == 1: dir = Vector2(1, 0)
	#elif term_edge == 2: dir = Vector2(0, 1)
	#else: dir = Vector2(-1, 0)
	#extend_path(org_chunk_coords, next_starting_point, dir)
#
#
#
#
#
#### PLOT CURVE AGAINST TILE GRID ###
#func extend_path(chunk_coords, block_coords, dir):
	#var offset = chunk_coords * CHUNK_SIZE
	#var rand = randi_range(0, CHUNK_SIZE - 1)
	#var success = false
	#var x1 
	#var y1 
	#var x2
	#var y2 
	#
	#while not success:
		#x1 = randi_range(0, CHUNK_SIZE - 1) + offset.x
		#y1 = randi_range(0, CHUNK_SIZE - 1) + offset.y
		#x2 = ((abs(dir.x)*((1+dir.x)/2)*(CHUNK_SIZE-1)))+((1-abs(dir.x))*rand) + offset.x
		#y2 = ((abs(dir.y)*((1+dir.y)/2)*(CHUNK_SIZE-1)))+((1-abs(dir.y))*rand) + offset.y
		#if abs(block_coords.x-x2) + abs(block_coords.y-y2) > CHUNK_SIZE or true:
			#success = plotQuadBezierSeg(block_coords.x, block_coords.y, x1, y1, x2, y2)
	#return Vector2(x2, y2) + dir
#
#
#func generate_path(chunk_x_offset, chunk_y_offset):
	## determine which side and direction to draw path from
	#var start_horz = randi_range(0,1)
	#var end_horz = randi_range(0,1)
	#var start_direction = randi_range(0, 1)
	#
	#var success = false
	#while not success:
		#var x0 = (CHUNK_SIZE - 1) * start_direction + chunk_x_offset
		#var y0 = (CHUNK_SIZE - 1) * start_direction + chunk_y_offset
		#var x1 = randi_range(0, CHUNK_SIZE - 1) + chunk_x_offset
		#var y1 = randi_range(0, CHUNK_SIZE - 1) + chunk_y_offset
		#var x2 = (CHUNK_SIZE - 1) * (1 - start_direction) + chunk_x_offset
		#var y2 = (CHUNK_SIZE - 1) * (1 - start_direction) + chunk_y_offset
		#
		#if start_horz: x0 = randi_range(0, CHUNK_SIZE - 1) + chunk_x_offset
		#else: y0 = randi_range(0, CHUNK_SIZE - 1) + chunk_y_offset
		#
		#if end_horz: x2 = randi_range(0, CHUNK_SIZE - 1) + chunk_x_offset
		#else: y2 = randi_range(0, CHUNK_SIZE - 1) + chunk_y_offset
		#
		#if abs(x0-x2) + abs(y0-y2) > CHUNK_SIZE:
			#success = plotQuadBezierSeg(x0, y0, x1, y1, x2, y2)
#
#
#
#func set_tile(x, y, type): 
	#MAP_GRID.set_cell_item(Vector3(x, 0, y), WORLD_TILE_LIST.TILE_NAMES[type], 0)
#
## i believe in Z-UP cry about it
#func set_tile_z(x, y, z, type): 
	#MAP_GRID.set_cell_item(Vector3(x, z, y), WORLD_TILE_LIST.TILE_NAMES[type], 0)
#
#func set_top_tile(x, y, type): 
	#var i = -1
	#while MAP_GRID.get_cell_item(Vector3i(x,i,y)) == -1 or MAP_GRID.get_cell_item(Vector3i(x,i+1,y)) != -1: i+=1
	#MAP_GRID.set_cell_item(Vector3(x, i, y), WORLD_TILE_LIST.TILE_NAMES[type], 0)
#
#
#func set_column(x, y, z, type): 
	#var i = 0
	#while i != z+1:
		#MAP_GRID.set_cell_item(Vector3(x, i, y), WORLD_TILE_LIST.TILE_NAMES[type], 0)
		#i += 1
#
#func set_path(x, y):
	#var i_min = 0 if x % (CHUNK_SIZE*CHUNK_COUNT) == 0 else 1-PATH_RADIUS
	#var j_min = 0 if y % (CHUNK_SIZE*CHUNK_COUNT) == 0 else 1-PATH_RADIUS
	#var i_max = 1 if (x+1) % (CHUNK_SIZE*CHUNK_COUNT) == 0 else PATH_RADIUS
	#var j_max = 1 if (y+1) % (CHUNK_SIZE*CHUNK_COUNT) == 0 else PATH_RADIUS
	#
	## -1..1 unless on the edge of a chunk.
	#for i in range(i_min, i_max):
		#for j in range(j_min, j_max):
			#set_top_tile(x+i, y+j, "STONE")
#
#
## this section of code is adapted from the work of Alois Zingl
## plotLine, plotQuadBezier and plotQuadBezierSeg are not my own
## read his paper on Bresenham Rasterization here: 
## https://zingl.github.io/Bresenham.pdf 
#
#func plotLine(x0, y0, x1, y1):
	#var dx = abs(x1 - x0)
	#var sx = 1 if x0 < x1 else -1
	#var dy = -abs(y1 - y0)
	#var sy = 1 if y0 < y1 else -1
	#var err = dx+dy
	#var e2
	#
	#while true:
		#set_path(x0 as int, y0 as int)
		#e2 = 2*err
		#
		#if e2 >= dy:
			#if x0 == x1: break
			#err += dy
			#x0 += sx
		#if e2 <= dx:
			#if y0 == y1: break
			#err += dx
			#y0 += sy
#
#func plotQuadBezierSeg(x0, y0, x1, y1, x2, y2):
	#var sx = x2-x1
	#var sy = y2-y1
	#var xx = x0-x1
	#var yy = y0-y1
	#var xy
	#var dx
	#var dy
	#var err
	#var cur = xx*sy-yy*sx
	#
	##if not xx*sx <= 0 and yy*sy <= 0:
		##print("sign of gradient must not change")
		###return false
	#
	#if sx*sx+sy*sy > xx*xx+yy*yy:
		#x2 = x0
		#x0 = sx+x1
		#y2 = y0
		#y0 = sy+y1
		#cur = -cur
	#if cur != 0:
		#xx += sx
		#sx = 1 if x0 < x2 else -1 
		#xx *= sx
		#
		#yy += sy
		#sy = 1 if y0 < y2 else -1
		#yy *= sy
		#
		#xy = 2*xx*yy
		#xx *= xx
		#yy *= yy
		#
		#if cur*sx*sy < 0:
			#xx = -xx
			#yy = -yy
			#xy = -xy
			#cur = -cur
		#dx = 4.0*sy*cur*(x1-x0)+xx-xy
		#dy = 4.0*sx*cur*(y0-y1)+yy-xy
		#xx += xx
		#yy += yy
		#err = dx+dy+xy
		#
		#set_path(x0 as int, y0 as int)
		#if x0 == x2 and y0 == y2: return true
		#y1 = 2*err < dx
		#if 2*err > dy:
			#x0 += sx
			#dx -= xy
			#dy += yy
			#err += dy
		#if y1:
			#y0 += sy
			#dy -= xy
			#dx += xx
			#err += dx
		#while dy < 0 and dx > 0:
			#set_path(x0 as int, y0 as int)
			#if x0 == x2 and y0 == y2: return true
			#y1 = 2*err < dx
			#if 2*err > dy:
				#x0 += sx
				#dx -= xy
				#dy += yy
				#err += dy
			#if y1:
				#y0 += sy
				#dy -= xy
				#dx += xx
				#err += dx
		#plotLine(x0, y0, x2, y2)
		#return true
#
#func plotQuadBezier(x0, y0, x1, y1, x2, y2):
	#var x = x0-x1
	#var y = y0-y1
	#var t = x0-2*x1+x2
	#var r
	#
	#if x*(x2-x1) > 0:
		#if y*(y2-y1) > 0:
			#if absf((y0-2.0*y1+y2)/t*x) > abs(y):
				#x0 = x2
				#x2 = x+x1
				#y0 = y2
				#y2 = y+y1
		#t = (x0-x1)/t
		#r = (1-t)*((1-t)*y0+2.0*t*y1)+t*t*y2
		#t = (x0*x2-x1*x1)*t/(x0-x1)
		#x = floor(t+0.5)
		#y = floor(r+0.5)
		#r = (y1-y0)*(t-x0)/(x1-x0)+y0
		#plotQuadBezierSeg(x0,y0, x,floor(r+0.5), x,y)
		#r = (y1-y2)*(t-x2)/(x1-x2)+y2
		#x1 = x
		#x0 = x1
		#y0 = y
		#y1 = floor(r+0.5)
	#if ((y0-y1)*(y2-y1) > 0):
		#t = y0-2*y1+y2
		#t = (y0-y1)/t
		#r = (1-t)*((1-t)*x0+2.0*t*x1)+t*t*x2
		#t = (y0*y2-y1*y1)*t/(y0-y1)
		#x = floor(r+0.5)
		#y = floor(t+0.5)
		#r = (x1-x0)*(t-y0)/(y1-y0)+x0
		#plotQuadBezierSeg(x0,y0,floor(r+0.5),y,x,y);
		#r = (x1-x2)*(t-y2)/(y1-y2)+x2
		#x0 = x
		#x1 = floor(r+0.5)
		#y1 = y
		#y0 = y1
	#plotQuadBezierSeg(x0,y0,x1,y1,x2,y2)
#
#func plotFullBezier(points):
	#pass
