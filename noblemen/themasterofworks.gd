extends Node
### WISHLIST ###
# [x] change to cubic bezier <- this doent help. instead draw a vector from the endpoint to the midpoint, negate that, make that the vector to the next chunk's midpoint.
# [x] trees
# [smarter generation] 
#   L [ ] create world as one block
#   L [ ] using hightmap, go through and paint biomes
# [x] fix vertical gaps (match min height of all adjacent tiles)
# [ ] regularize Y-up/Z-up (make it clearing when each is what.) 
# [ ] tunr x/y into vector inputs. 
# [ ] make world scaling more consistent and regular lol
# [ ] why does the path thing still leave gaps?!


### PLEASE NOTE: ### 
# anything that comes prebuilt out the box will use Y-up. thats cringe.
# anything i wrote uses Z-up. is this stupid, impractical, harder to read,
# harder to maintain, more error prone and devoid of practical benefits?
# yes.
# i'm using Z-up anyway. i think its the gentlemans choice.

# # # # # # # # # # # # #          # # # # # # # # # # # # #
# + > X |       |       #          # + > X |       |       #
# v     |       |       #          # v     |       |       #
# Y     |       |       #          # Z     |       |       #
# - - - + - - - + - - - #          # - - - + - - - + - - - #
#       |       |       #          #       |       |       #
#       |       |       #          #       |       |       #
#       |       |       #          #       |       |       #
# - - - + - - - + - - - #          # - - - + - - - + - - - #
#       |       |       #          #       |       |       #
#       |       |       #          #       |       |       #
#       |       |       #          #       |       |       #
# # # # # # # # # # # # #          # # # # # # # # # # # # #
# MINE (based)                     GODOT's (cringe)


const TILES = TheArchivist.TILE_NAMES
var FOOL = TheFool
var thread: Thread
signal finished

# WORLD 
var CHUNK_SIZE: int
var CHUNK_COUNT: int
var EDGE_LENGTH: int
var MAX_HEIGHT: int
var heightmap: Array
var MAP_GRID := GridMap.new()
const WORLD_SCALE = Vector3(1,1,1)
const MESH_LIB = preload("res://points_of_interest/the_forest/1m_tiles.tres")
#const WORLD_SCALE = Vector3(1,.5,1)
#const MESH_LIB = preload("res://points_of_interest/the_forest/1m_tiles_half_height.tres")
#const WORLD_SCALE = Vector3(.5,.25,.5)
#const MESH_LIB = preload("res://points_of_interest/the_forest/halfm_tiles.tres")

# ROAD
var PATH_RADIUS: int
var PATH_TILE: String
var road_path: Array 

# FOREST
const TREE_ODDS: int = 10
const MIN_TREE_SPACING: int = 5

# POINTS OF INTEREST
enum {NAME, COORDS, SCENE}
var points_of_interest: Array 
const POI_TO_GENERATE = TheArchivist.POINTS_OF_INTEREST 


# DEBUG
var SHOW_CHUNKS: bool = false
var SHOW_CURVE_HANDLES: bool = false
const TIME_PROFILING: bool = true
const HANDLE_HEIGHT: int = 2


func _init(cs: int = 16, cc: int = 16, mh: int = 40, pr: int = 3, pt: String = "PATH", dm: bool = false):
	CHUNK_COUNT = cc
	CHUNK_SIZE = cs
	EDGE_LENGTH = cs*cc
	MAP_GRID.set_octant_size(cs)
	MAX_HEIGHT = mh * int(not dm)
	PATH_RADIUS = pr
	PATH_TILE = pt
	MAP_GRID.mesh_library = MESH_LIB
	MAP_GRID.set_cell_size(WORLD_SCALE)
	MAP_GRID.position = Vector3(-0.5,0,-0.5)
	SHOW_CHUNKS = dm
	SHOW_CURVE_HANDLES = dm

func get_heightmap(): return heightmap
func get_map_grid(): return MAP_GRID
func get_chunk(chunk_coords: Vector2): pass
func get_road_path(): return road_path
func get_world_scale(): return WORLD_SCALE
func get_points_of_interest(): return points_of_interest

func point_is_on_grid(coords: Vector2) -> bool: 
	return coords.x >= 0 and coords.x < EDGE_LENGTH and coords.y >= 0 and coords.y < EDGE_LENGTH

func point_is_near_POI(coords: Vector3, search_range: int) -> bool: 
	if search_range == 0: return false
	for poi in points_of_interest: 
		if abs((coords - poi[COORDS]/WORLD_SCALE).length()) < search_range: return true
	return false

func point_is_near_path(test_point: Vector2, search_range: float) -> bool:
	if search_range == 0: return false
	for chunk in road_path:
		for point in chunk:
			point /= WORLD_SCALE
			if test_point.distance_to(Vector2(point.x, point.z)) <= search_range:
				return true
	return false

func find_tile_at_point(coords: Vector2) -> String:
	var answer: String = ""
	for tile in TILES.keys(): 
		if TILES[tile] == MAP_GRID.get_cell_item(Vector3(coords.x,heightmap[coords.x][coords.y],coords.y)): 
			answer = tile
	return answer

func find_tile_from_height(h: int) -> String:
	return "STONE" if h > 3*MAX_HEIGHT/4 else \
			("STONE" if FOOL.range_i((5*MAX_HEIGHT/8),3*MAX_HEIGHT/4) < h else "GRASS") if h > 5*MAX_HEIGHT/8 else \
			"GRASS" if h > MAX_HEIGHT/2 else \
			"GRASS" if h > MAX_HEIGHT/4 else \
			("GRASS" if FOOL.range_i((MAX_HEIGHT/8),MAX_HEIGHT/4) < h else "WOOD") if h > MAX_HEIGHT/8 else \
			"WOOD"

func generate_map():
	var start_time: float = Time.get_unix_time_from_system()
	var last_time: float = start_time
	if TIME_PROFILING: 
		print("beginning generation for ", CHUNK_COUNT, " chunk world.")
		print("(",CHUNK_COUNT*CHUNK_SIZE,"x",CHUNK_COUNT*CHUNK_SIZE," tiles)")
	
	MAP_GRID.clear()
	generate_chunks()
	
	if TIME_PROFILING: 
		print("chunks complete: ", snapped(Time.get_unix_time_from_system()-last_time, 0.00001))
		last_time = Time.get_unix_time_from_system()
	
	if not SHOW_CHUNKS: 
		generate_forest()
		if TIME_PROFILING: 
			print("forest complete: ", snapped(Time.get_unix_time_from_system()-last_time, 0.00001))
			last_time = Time.get_unix_time_from_system()
	
	#generate_directed_curve("WATER")
	generate_directed_curve(PATH_TILE)
	
	if TIME_PROFILING: 
		print("curve(s) complete: ", snapped(Time.get_unix_time_from_system()-last_time, 0.00001))
		last_time = Time.get_unix_time_from_system()
	
	generate_POIs(POI_TO_GENERATE)
	
	if TIME_PROFILING: 
		print("POIs complete: ", snapped(Time.get_unix_time_from_system()-last_time, 0.00001))
	
	finished.emit()
	
	if TIME_PROFILING: print("total generation time: ", snapped(Time.get_unix_time_from_system()-start_time, 0.00001))

# i believe in Z-UP cry about it
func set_tile(x, y, z, type, single: bool = false, rot = 0): 
	if single: MAP_GRID.set_cell_item(Vector3(x, z, y), TILES[type], rot)
	else: 
		var min_z = z
		for i in 1:
			if point_is_on_grid(Vector2(x+1,y)):
				if heightmap[x+1][y] < min_z: min_z = heightmap[x+1][y]
			else: min_z = 0; break
			if point_is_on_grid(Vector2(x-1,y)):
				if heightmap[x-1][y] < min_z: min_z = heightmap[x-1][y]
			else: min_z = 0; break
			if point_is_on_grid(Vector2(x,y+1)):
				if heightmap[x][y+1] < min_z: min_z = heightmap[x][y+1]
			else: min_z = 0; break
			if point_is_on_grid(Vector2(x,y-1)):
				if heightmap[x][y-1] < min_z: min_z = heightmap[x][y-1]
			else: min_z = 0; break
		
		set_column(x, y, z, type, min_z)

# TODO: switch this and set tile cus wth is this?!
func set_column(x, y, z, type: String, start: int = 0): 
	var i = start
	while i <= z:
		MAP_GRID.set_cell_item(Vector3(x, i, y), TILES[type], 0)
		i += 1

func set_path(x, y, type):
	var i_min = -min(x, PATH_RADIUS)
	var j_min = -min(y, PATH_RADIUS)
	var i_max = min(EDGE_LENGTH - x, PATH_RADIUS+1)
	var j_max = min(EDGE_LENGTH - y, PATH_RADIUS+1)

	# that height CRAP
	#var height = 0.0
	#
	#for i in range(i_min, i_max):
		#for j in range(j_min, j_max):
			#height += heightmap[x+i][y+j]
	#
	#height = floor((height/(abs(i_max-i_min)*abs(j_max-j_min)))+0.5)
	
	# -1..1 unless on the edge of a chunk. (assuming r=2)
	#for i in range(i_min, i_max):
		#for j in range(j_min, j_max):
			#if MAP_GRID.get_cell_item(Vector3(x+i, heightmap[x+i][y+j], y+j)) == TILES.WATER and type != "WATER":
				#set_tile(x+i, y+j, heightmap[x+i][y+j]+1, "WOOD")
				#set_tile(x+i, y+j, heightmap[x+i][y+j]+2, "AIR")
			#else:
				#set_tile(x+i, y+j, heightmap[x+i][y+j], type)
				#set_tile(x+i, y+j, heightmap[x+i][y+j]+1,"AIR")


	for i in range(i_min-PATH_RADIUS, i_max+PATH_RADIUS):
		for j in range(j_min-PATH_RADIUS, j_max+PATH_RADIUS):
			if i > i_min and i < i_max:
				if MAP_GRID.get_cell_item(Vector3(x+i, heightmap[x+i][y+j], y+j)) == TILES.WATER and type != "WATER":
					set_tile(x+i, y+j, heightmap[x+i][y+j]+1, "WOOD")
					set_tile(x+i, y+j, heightmap[x+i][y+j]+2, "AIR")
				else:
					set_tile(x+i, y+j, heightmap[x+i][y+j], type)
					set_tile(x+i, y+j, heightmap[x+i][y+j]+1,"AIR")
			else:
				#if point_is_on_grid(Vector2(x+i, y+j)): set_tile(x+i, y+j, heightmap[x+i][y+j]+1,"AIR")
				pass
	
			# for use with that height CRAP
			#if MAX_HEIGHT <= 20:
				#set_tile(x+i, y+j, height-1, type)
				#set_tile(x+i, y+j, height, type)
				#set_tile(x+i, y+j, height+1,"AIR")
			#else:
				#set_tile(x+i, y+j, heightmap[x+i][y+j], type)
				#set_tile(x+i, y+j, heightmap[x+i][y+j]+1,"AIR")

func draw_filled_circle(center_x: int, center_y: int, type: String = PATH_TILE, radius: int = PATH_RADIUS, avg_height: int = -1, clear_sides: bool = false):
	var x = radius
	var y = 0
	var error = 1 - radius

	while x >= y:
		if clear_sides:
			var clear_rad = 3
			draw_line(center_x - int(x * clear_rad), center_x + int(x * clear_rad), center_y + int(y * clear_rad), "AIR", avg_height)
			draw_line(center_x - int(x * clear_rad), center_x + int(x * clear_rad), center_y - int(y * clear_rad), "AIR", avg_height)
			draw_line(center_x - int(y * clear_rad), center_x + int(y * clear_rad), center_y + int(x * clear_rad), "AIR", avg_height)
			draw_line(center_x - int(y * clear_rad), center_x + int(y * clear_rad), center_y - int(x * clear_rad), "AIR", avg_height)
		
		draw_line(center_x - x, center_x + x, center_y + y, type, avg_height)
		draw_line(center_x - x, center_x + x, center_y - y, type, avg_height)
		draw_line(center_x - y, center_x + y, center_y + x, type, avg_height)
		draw_line(center_x - y, center_x + y, center_y - x, type, avg_height)
		
		if avg_height != -1:
			if point_is_on_grid(Vector2(center_x + x + 1, center_y + y)) and heightmap[center_x + x + 1][center_y + y] > avg_height: set_column(center_x + x + 1, center_y + y, heightmap[center_x + x + 1][center_y + y], find_tile_at_point(Vector2(center_x + x + 1, center_y + y)),  avg_height)
			if point_is_on_grid(Vector2(center_x - x - 1, center_y + y)) and heightmap[center_x - x - 1][center_y + y] > avg_height: set_column(center_x - x - 1, center_y + y, heightmap[center_x - x - 1][center_y + y], find_tile_at_point(Vector2(center_x - x - 1, center_y + y)), avg_height)
			if point_is_on_grid(Vector2(center_x + x + 1, center_y - y)) and heightmap[center_x + x + 1][center_y - y] > avg_height: set_column(center_x + x + 1, center_y - y, heightmap[center_x + x + 1][center_y - y], find_tile_at_point(Vector2(center_x + x + 1, center_y - y)), avg_height)
			if point_is_on_grid(Vector2(center_x - x - 1, center_y - y)) and heightmap[center_x - x - 1][center_y - y] > avg_height: set_column(center_x - x - 1, center_y - y, heightmap[center_x - x - 1][center_y - y], find_tile_at_point(Vector2(center_x - x - 1, center_y - y)), avg_height)
			if point_is_on_grid(Vector2(center_x + y, center_y + x + 1)) and heightmap[center_x + y][center_y + x + 1] > avg_height: set_column(center_x + y, center_y + x + 1, heightmap[center_x + y][center_y + x + 1], find_tile_at_point(Vector2(center_x + y, center_y + x + 1)), avg_height)
			if point_is_on_grid(Vector2(center_x - y, center_y + x + 1)) and heightmap[center_x - y][center_y + x + 1] > avg_height: set_column(center_x - y, center_y + x + 1, heightmap[center_x - y][center_y + x + 1], find_tile_at_point(Vector2(center_x - y, center_y + x + 1)), avg_height)
			if point_is_on_grid(Vector2(center_x + y, center_y - x - 1)) and heightmap[center_x + y][center_y - x - 1] > avg_height: set_column(center_x + y, center_y - x - 1, heightmap[center_x + y][center_y - x - 1], find_tile_at_point(Vector2(center_x + y, center_y - x - 1)), avg_height)
			if point_is_on_grid(Vector2(center_x - y, center_y - x - 1)) and heightmap[center_x - y][center_y - x - 1] > avg_height: set_column(center_x - y, center_y - x - 1, heightmap[center_x - y][center_y - x - 1], find_tile_at_point(Vector2(center_x - y, center_y - x - 1)), avg_height)
		
		y += 1
		if error <= 0:
			error += 2 * y + 1
		else:
			x -= 1
			error += 2 * (y - x) + 1

# TODO: make the tiles on the edge fill under themselves
func draw_line(x1, x2, y, type, ah):
	for x in range(x1, x2 + 1):
		if point_is_on_grid(Vector2(x,y)): 
			if ah == -1: 
				if type != "AIR": set_tile(x, y, heightmap[x][y], type, true)
				set_tile(x, y, heightmap[x][y]+1, "AIR", true)
			else:
				for i in range(ah+1,heightmap[x][y]+2):
					set_tile(x, y, i, "AIR", true)
				set_tile(x, y, ah, type)
	#if ah != -1: 
		#if point_is_on_grid(Vector2(x1-1,y)): set_tile(x1-1, y, heightmap[x1-1][y]+2, "WHITE", true)
		#if point_is_on_grid(Vector2(x2+1,y)): set_tile(x2+1, y, heightmap[x2+1][y]+2, "WHITE", true)





# function created with the help of claude AI, availible at claude.ai 
func generate_noise_heightmap(width: int, height: int, max_height: int, noise_seed: int = FOOL.rand_i(), frequency: float = 0.001, lacunarity: float = 2.0, gain: float = 0.5) -> Array:
	var noise = FastNoiseLite.new()
	var offset = Vector2i(width,height)
	noise.set_seed(noise_seed)
	noise.set_noise_type(FastNoiseLite.TYPE_SIMPLEX_SMOOTH) 
	noise.set_frequency(frequency)
	noise.set_fractal_lacunarity(lacunarity)
	noise.set_fractal_gain(gain)
	noise.set_fractal_type(FastNoiseLite.FRACTAL_RIDGED)
	
	heightmap = []
	for x in range(width):
		var row = []
		for y in range(height):
			var noise_value = noise.get_noise_2d(x + offset.x, y + offset.y)
			# Convert noise value (-1 to 1) to (0 to 1) range
			var t = (noise_value + 1) * 0.5
			# Discretize to 6 levels (0 to 5)
			var height_value = int(round(t * max_height))
			row.append(height_value)
		heightmap.append(row)
	return heightmap


func generate_chunks(height_map: Array = [], show_chunks: bool = SHOW_CHUNKS):
	var hm = generate_noise_heightmap(CHUNK_COUNT*CHUNK_SIZE,CHUNK_COUNT*CHUNK_SIZE,MAX_HEIGHT) if height_map == [] else height_map
	for i in hm.size():
		for j in hm[i].size():
			if show_chunks: set_column(i,j,hm[i][j],"WHITE" if (i/CHUNK_SIZE + j/CHUNK_SIZE)%2 == 0 else "BLACK")
			else: 
				var type = find_tile_from_height(hm[i][j])
				#var type =  "STONE" if hm[i][j] > 3*MAX_HEIGHT/4 else \
							#("STONE" if FOOL.range_i((5*MAX_HEIGHT/8),3*MAX_HEIGHT/4)<hm[i][j] else "GRASS") if hm[i][j] > 5*MAX_HEIGHT/8 else \
							#"GRASS" if hm[i][j] > MAX_HEIGHT/2 else \
							#"GRASS" if hm[i][j] > MAX_HEIGHT/4 else \
							#"WOOD"
				set_tile(i,j,hm[i][j],type)


### POINTS OF INTEREST ### 
func generate_POIs(locations: Dictionary):
	for loc in locations:
		print("placing ",loc)
		var options = locations[loc]
		
		var size: int = 0 if not options.has("size") else options.size 
		var attempts: int = 1 if not options.has("attempts") else options.attempts 
		var ground: String = "" if not options.has("ground") else options.ground 
		# my second goat of an EQ
		var road_spacing: float = size+1 if not options.has("road_spacing") else max(floor(1-absf(options.road_spacing)),0)*sqrt(2*(CHUNK_SIZE**2))+options.road_spacing
		var poi_spacing: float = size+1 if not options.has("POI_spacing") else options.POI_spacing 
		var scene: String = options.scene if options.has("scene") else "res://entities/bingus/bingus.glb"
		
		var coords = find_flat_spawn_location(size/WORLD_SCALE.x, attempts, poi_spacing, road_spacing)

		if coords:
			print("found suitable spot for ",loc, ". placing")
			# this abominable one-liner will generate the ground disk out of the extant ground tile at that point
			if not ground: ground = find_tile_at_point(Vector2(coords.x,coords.z))
				#for tile in TILES.keys(): 
					#if TILES[tile] == MAP_GRID.get_cell_item(Vector3(coords.x,heightmap[coords.x][coords.z],coords.z)): 
						#ground = tile
						#break
			draw_filled_circle(coords.x, coords.z, ground, int(size/WORLD_SCALE.x), coords.y)
			print(loc, " placed")
			points_of_interest.push_back([loc,(coords + Vector3(0,1,0))*WORLD_SCALE,scene])

		else:
			print("no suitable spawn spot for ", loc)
			pass



### FOREST STUFF ### 
func generate_forest(): 
	#load("res://RAW_RESOURCES/helpers.gd").add_mesh_to_library_shaded("res://world/map/1m_tiles.tres", "res://world/map/trees/tall_pine.obj", "tall_pine")
	for i in heightmap.size():
		for j in heightmap[i].size():
			var Z = heightmap[i][j]+1
			if not FOOL.range_i(0,TREE_ODDS):
				var rot_i = [0, 16, 10, 22]
				var rot = rot_i[FOOL.range_i(0, 3)]
				if MAX_HEIGHT <= 60 or true:
					if is_flat_and_centered(Vector2(i,j), 1) and \
					MAP_GRID.get_cell_item(Vector3(i,Z-1,j)) != TILES["STONE"] and \
					is_no_trees_nearby(Vector2(i,j), MIN_TREE_SPACING): 
						set_tile(i,j,Z,"TALL_PINE",true,rot)
				elif is_no_trees_nearby(Vector2(i,j), MIN_TREE_SPACING*2): set_tile(i,j,Z,"TALL_PINE",true,rot)

func is_flat_and_centered(coords: Vector2, search_range: int) -> bool:
	var height = heightmap[coords.x][coords.y]

	if coords.x == 0 or coords.x == CHUNK_COUNT*CHUNK_SIZE-1 \
	or coords.y == 0 or coords.y == CHUNK_COUNT*CHUNK_SIZE-1:
		return false
	
	for i in range(coords.x - search_range, coords.x + search_range + 1):
		for j in range(coords.y - search_range, coords.y + search_range + 1):
			if heightmap[i][j] != height: return false
	
	return true

# TODO: replace with find_flat_spawwn_location
func is_no_trees_nearby(coords: Vector2, search_range: int):
	if coords.x == 0 or coords.x == CHUNK_COUNT*CHUNK_SIZE-1 \
	or coords.y == 0 or coords.y == CHUNK_COUNT*CHUNK_SIZE-1:
		return false
	
	var height = heightmap[coords.x][coords.y]
	for i in range(coords.x - search_range, coords.x + search_range + 1):
		for j in range(coords.y - search_range, coords.y + search_range + 1):
			for k in range(height - search_range, height + search_range + 1):
				if MAP_GRID.get_cell_item(Vector3(i,k,j)) == TILES["TALL_PINE"]: return false
	
	return true

func find_flat_spawn_location(size: int, spawn_attempts: int, poi_spacing: float, road_spacing:float) -> Vector3:
	var sort_by_size_then_flatness = func (a, b): 
		if a[1][2] == b[1][2]: return a[1][1] < b[1][1]
		else: return a[1][2] > b[1][2]
	
	var convert_to_vec3 = func (sub): return Vector3(sub[0].x, sub[1][0], sub[0].y)
	var valid_points: Array
	
	for i in spawn_attempts:
		var spawn_point := Vector2(FOOL.range_i(0, EDGE_LENGTH-1),FOOL.range_i(0, EDGE_LENGTH-1))
		if not point_is_near_path(spawn_point, road_spacing): valid_points.push_back([spawn_point, height_avg_and_dev(spawn_point,size)])
																					#[Vector2,     [height, dev, counted_tiles]]
	
	if not valid_points.size(): return Vector3.ZERO
	
	valid_points.sort_custom(sort_by_size_then_flatness)
	valid_points = valid_points.map(convert_to_vec3)

	while valid_points.size() > 0 and point_is_near_POI(valid_points[0], poi_spacing):
		set_tile(valid_points[0].x,valid_points[0].z+5,valid_points[0].y, "WHITE")
		valid_points.pop_front()
	
	return valid_points[0] if valid_points.size() else Vector3.ZERO

func height_avg_and_dev(coords: Vector2, search_range: int):
	var height = 0.0
	var dev = 0.0
	var counted_tiles = 0
	
	for i in range(-search_range, search_range+1):
		for j in range(-search_range, search_range+1):
			if point_is_on_grid(Vector2(coords.x+i,coords.y+j)): 
				height += heightmap[coords.x+i][coords.y+j]
				counted_tiles += 1
	height = floor((height/counted_tiles)+0.5)
	
	for i in range(-search_range, search_range+1):
		for j in range(-search_range, search_range+1):
			if point_is_on_grid(Vector2(coords.x+i,coords.y+j)): 
				dev += absf(heightmap[coords.x+i][coords.y+j] - height)
	dev /= counted_tiles
	
	return [height,dev,counted_tiles]





### ROAD GENERATION ###
# determines the start/ending points of the curve and what chunks it will go through
func generate_directed_curve(tile):
	road_path = []
	# determine block, edge and chunk indices for start/end points
	var org_block = CHUNK_SIZE/2 #FOOL.range_i(0, CHUNK_SIZE - 1)# the block index of where the path begins/ends
	var org_edge = FOOL.range_i(0, 3) # which edge (^,>,v,<) the path begins/ends
	var term_edge = org_edge
	while term_edge == org_edge: term_edge = FOOL.range_i(0, 3)
	# which chunk along that edge the path begins/ends
	var org_chunk = FOOL.range_i(0, CHUNK_COUNT - 1) 
	var term_chunk = FOOL.range_i(0, CHUNK_COUNT - 1)
	#(X,Y) coords in the chunk grid
	var org_chunk_coords 
	var mid_chunk_coords = Vector2(FOOL.range_i(1, CHUNK_COUNT - 2), FOOL.range_i(1, CHUNK_COUNT - 2))
	var term_chunk_coords
	
	# turn edge/chunk index into chunk coordinates
	if org_edge == 0: 
		org_chunk_coords = Vector2(org_chunk, 0)
		org_block = (org_chunk_coords * CHUNK_SIZE) + Vector2(org_block, 0)
	elif org_edge == 1: 
		org_chunk_coords = Vector2(CHUNK_COUNT - 1, org_chunk)
		org_block = (org_chunk_coords * CHUNK_SIZE) + Vector2(CHUNK_SIZE - 1, org_block)
	elif org_edge == 2: 
		org_chunk_coords = Vector2(org_chunk, CHUNK_COUNT - 1)
		org_block = (org_chunk_coords * CHUNK_SIZE) + Vector2(org_block, CHUNK_SIZE - 1)
	else: 
		org_chunk_coords = Vector2(0, org_chunk)
		org_block = (org_chunk_coords * CHUNK_SIZE) + Vector2(0, org_block)
	
	if term_edge == 0: term_chunk_coords = Vector2(term_chunk, 0)
	elif term_edge == 1: term_chunk_coords = Vector2(CHUNK_COUNT - 1, term_chunk)
	elif term_edge == 2: term_chunk_coords = Vector2(term_chunk, CHUNK_COUNT - 1)
	else: term_chunk_coords = Vector2(0, term_chunk)
	
	# prevent endpoints from spawning onh the same corner
	if CHUNK_COUNT != 1 && org_chunk_coords == term_chunk_coords:
		if FOOL.range_i(0, 1):
			if term_chunk_coords.x < CHUNK_COUNT/2: term_chunk_coords.x += CHUNK_COUNT/2;
			else: term_chunk_coords.x -= CHUNK_COUNT/2
		else:
			if term_chunk_coords.y < CHUNK_COUNT/2: term_chunk_coords.y += CHUNK_COUNT/2;
			else: term_chunk_coords.y -= CHUNK_COUNT/2
	
	# trace first leg
	var next_curve_data = [org_block, Vector2.ZERO]
	var move_x 
	var dist
	var dir
	while org_chunk_coords != mid_chunk_coords:
		dist = mid_chunk_coords - org_chunk_coords
		if dist.x != 0 && dist.y != 0: move_x = FOOL.range_i(0, 1)
		elif dist.x != 0: move_x = 1 
		else: move_x = 0  
		dir = Vector2(dist.x/abs(dist.x) * move_x, dist.y/abs(dist.y) * (1-move_x))
		if is_nan(dir.x): dir.x = 0
		if is_nan(dir.y): dir.y = 0  
		next_curve_data = extend_curve(org_chunk_coords, next_curve_data, dir, tile)
		org_chunk_coords += dir
	
	while org_chunk_coords != term_chunk_coords:
		dist = term_chunk_coords - org_chunk_coords
		if dist.x != 0 && dist.y != 0: move_x = FOOL.range_i(0, 1)
		elif dist.x != 0: move_x = 1 
		else: move_x = 0  
		dir = Vector2(dist.x/abs(dist.x) * move_x, dist.y/abs(dist.y) * (1-move_x))
		if is_nan(dir.x): dir.x = 0
		if is_nan(dir.y): dir.y = 0  
		next_curve_data = extend_curve(org_chunk_coords, next_curve_data, dir, tile)
		org_chunk_coords += dir

	if term_edge == 0: dir = Vector2(0, -1)
	elif term_edge == 1: dir = Vector2(1, 0)
	elif term_edge == 2: dir = Vector2(0, 1)
	else: dir = Vector2(-1, 0)
	extend_curve(org_chunk_coords, next_curve_data, dir, tile)


# create a curve within a chunk
func extend_curve(chunk_coords, curve_data, dir, path):
	var block_coords = curve_data[0]
	var mid_vector = curve_data[1]
	var offset = chunk_coords * CHUNK_SIZE
	var rand = FOOL.range_i(CHUNK_SIZE * 1/4, CHUNK_SIZE * 3/4)
	var x1: int
	var y1: int
	var x2: int
	var y2: int
	
	if mid_vector == Vector2.ZERO:
		x1 = FOOL.range_i(CHUNK_SIZE * 1/4.0, CHUNK_SIZE * 3/4.0) + offset.x
		y1 = FOOL.range_i(CHUNK_SIZE * 1/4.0, CHUNK_SIZE * 3/4.0) + offset.y
	else: 
		var midpoint_dist = FOOL.range_f(CHUNK_SIZE/4, CHUNK_SIZE)
		mid_vector = (mid_vector.normalized() * midpoint_dist) + block_coords
		x1 = int(min(max(mid_vector.x, 0), EDGE_LENGTH-1))
		y1 = int(min(max(mid_vector.y, 0), EDGE_LENGTH-1))
	
	x2 = ((abs(dir.x)*((1+dir.x)/2)*(CHUNK_SIZE-1)))+((1-abs(dir.x))*rand) + offset.x
	y2 = ((abs(dir.y)*((1+dir.y)/2)*(CHUNK_SIZE-1)))+((1-abs(dir.y))*rand) + offset.y
	
	while abs(block_coords.x-x2) + abs(block_coords.y-y2) < CHUNK_SIZE/2:
		rand = FOOL.range_i(0, CHUNK_SIZE - 1)
		# the goat of an equation. never touch this. its too perfect
		x2 = ((abs(dir.x)*((1+dir.x)/2)*(CHUNK_SIZE-1)))+((1-abs(dir.x))*rand) + offset.x
		y2 = ((abs(dir.y)*((1+dir.y)/2)*(CHUNK_SIZE-1)))+((1-abs(dir.y))*rand) + offset.y
	
	plotQuadBezier(block_coords.x, block_coords.y, x1, y1, x2, y2, path)
	
	#var start_point = Vector3(block_coords.x,heightmap[block_coords.x][block_coords.y],block_coords.y) * WORLD_SCALE
	#var mid_point = Vector3(x1,heightmap[x1][y1],y1) * WORLD_SCALE
	#var end_point = Vector3(x2,heightmap[x2][y2],y2) * WORLD_SCALE
	var start_point = Vector3(block_coords.x,0,block_coords.y) * WORLD_SCALE
	var mid_point = Vector3(x1,0,y1) * WORLD_SCALE
	var end_point = Vector3(x2,0,y2) * WORLD_SCALE
	road_path.push_back([start_point,mid_point,end_point])
	
	if SHOW_CURVE_HANDLES:
		var color = "BLACK"
		if int(chunk_coords.x + chunk_coords.y) % 2: color = "WHITE"
		MAP_GRID.set_cell_item((start_point+Vector3(0,HANDLE_HEIGHT,0))/WORLD_SCALE, TILES[color])
		MAP_GRID.set_cell_item((mid_point+Vector3(0,HANDLE_HEIGHT,0))/WORLD_SCALE, TILES[color])
		MAP_GRID.set_cell_item((end_point+Vector3(0,HANDLE_HEIGHT,0))/WORLD_SCALE, TILES[color])
	
	return [Vector2(x2, y2) + dir, Vector2(x2, y2) - Vector2(x1, y1)]

# this section of code is adapted from the work of Alois Zingl
# plotLine, plotQuadBezier and plotQuadBezierSeg are not my own
# read his paper on Bresenham Rasterization here: 
# https://zingl.github.io/Bresenham.pdf 
func plotLine(x0, y0, x1, y1, tile):
	var dx = abs(x1 - x0)
	var sx = 1 if x0 < x1 else -1
	var dy = -abs(y1 - y0)
	var sy = 1 if y0 < y1 else -1
	var err = dx+dy
	var e2
	
	while true:
		draw_filled_circle(x0, y0, tile, PATH_RADIUS, -1, true)
		e2 = 2*err
		
		if e2 >= dy:
			if x0 == x1: break
			err += dy
			x0 += sx
		if e2 <= dx:
			if y0 == y1: break
			err += dx
			y0 += sy

func plotQuadBezierSeg(x0, y0, x1, y1, x2, y2, tile):
	var sx = x2-x1
	var sy = y2-y1
	var xx = x0-x1
	var yy = y0-y1
	var xy
	var dx
	var dy
	var err
	var cur = xx*sy-yy*sx
	
	#if not xx*sx <= 0 and yy*sy <= 0:
		#print("sign of gradient must not change")
		##return false
	
	if sx*sx+sy*sy > xx*xx+yy*yy:
		x2 = x0
		x0 = sx+x1
		y2 = y0
		y0 = sy+y1
		cur = -cur
	if cur != 0:
		xx += sx
		sx = 1 if x0 < x2 else -1 
		xx *= sx
		
		yy += sy
		sy = 1 if y0 < y2 else -1
		yy *= sy
		
		xy = 2*xx*yy
		xx *= xx
		yy *= yy
		
		if cur*sx*sy < 0:
			xx = -xx
			yy = -yy
			xy = -xy
			cur = -cur
		dx = 4.0*sy*cur*(x1-x0)+xx-xy
		dy = 4.0*sx*cur*(y0-y1)+yy-xy
		xx += xx
		yy += yy
		err = dx+dy+xy
		
		draw_filled_circle(x0, y0, tile, PATH_RADIUS, -1, true)
		if x0 == x2 and y0 == y2: return true
		y1 = 2*err < dx
		if 2*err > dy:
			x0 += sx
			dx -= xy
			dy += yy
			err += dy
		if y1:
			y0 += sy
			dy -= xy
			dx += xx
			err += dx
		while dy < 0 and dx > 0:
			draw_filled_circle(x0, y0, tile, PATH_RADIUS, -1, true)
			if x0 == x2 and y0 == y2: return true
			y1 = 2*err < dx
			if 2*err > dy:
				x0 += sx
				dx -= xy
				dy += yy
				err += dy
			if y1:
				y0 += sy
				dy -= xy
				dx += xx
				err += dx
		plotLine(x0, y0, x2, y2, tile)
		return true

func plotQuadBezier(x0, y0, x1, y1, x2, y2, tile):
	var x = x0-x1
	var y = y0-y1
	var t = x0-2*x1+x2
	var r
	
	if x*(x2-x1) > 0:
		if y*(y2-y1) > 0:
			if absf((y0-2.0*y1+y2)/t*x) > abs(y):
				x0 = x2
				x2 = x+x1
				y0 = y2
				y2 = y+y1
		t = (x0-x1)/t
		r = (1-t)*((1-t)*y0+2.0*t*y1)+t*t*y2
		t = (x0*x2-x1*x1)*t/(x0-x1)
		x = floor(t+0.5)
		y = floor(r+0.5)
		r = (y1-y0)*(t-x0)/(x1-x0)+y0
		plotQuadBezierSeg(x0,y0,x,floor(r+0.5),x,y,tile)
		r = (y1-y2)*(t-x2)/(x1-x2)+y2
		x1 = x
		x0 = x1
		y0 = y
		y1 = floor(r+0.5)
	if ((y0-y1)*(y2-y1) > 0):
		t = y0-2*y1+y2
		t = (y0-y1)/t
		r = (1-t)*((1-t)*x0+2.0*t*x1)+t*t*x2
		t = (y0*y2-y1*y1)*t/(y0-y1)
		x = floor(r+0.5)
		y = floor(t+0.5)
		r = (x1-x0)*(t-y0)/(y1-y0)+x0
		plotQuadBezierSeg(x0,y0,floor(r+0.5),y,x,y,tile);
		r = (x1-x2)*(t-y2)/(y1-y2)+x2
		x0 = x
		x1 = floor(r+0.5)
		y1 = y
		y0 = y1
	plotQuadBezierSeg(x0,y0,x1,y1,x2,y2,tile)





