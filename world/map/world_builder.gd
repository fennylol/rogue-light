extends Thread
### WISHLIST ###
# change to cubic bezier
# trees
# smarter generation 
# - create world as one block
# - using hightmap, go through and paint biomes
# fix vertical gaps

const WORLD_TILE_LIST = preload("res://world/map/world_tile_list.gd")
var CHUNK_SIZE
var CHUNK_COUNT
var MAX_HEIGHT
var PATH_RADIUS
var PATH_TILE

signal finished
var heightmap = []
var MAP_GRID = GridMap.new()
var mutex = Mutex.new()

func _init(cs: int = 16, cc: int = 16, mh: int = 10, pr: int = 2, pt: String = "STONE"):
	CHUNK_COUNT = cc
	CHUNK_SIZE = cs
	MAX_HEIGHT = mh
	PATH_RADIUS = pr
	PATH_TILE = pt
	MAP_GRID.mesh_library = load("res://world/map/1m_tiles.tres")
	MAP_GRID.set_cell_size(Vector3(1,1,1))
	MAP_GRID.position = Vector3(-0.5,0,-0.5)

func get_heightmap():
	return heightmap

func get_map_grid():
	return MAP_GRID
	
func stop_thread():
	wait_to_finish()
	free()


func generate_map():
	MAP_GRID.clear()
	generate_chunks()
	generate_directed_path()
	finished.emit()

# function created with the help of claude AI, availible at claude.ai 
func generate_noise_heightmap(width: int, height: int, max_height: int, noise_seed: int = randi(), frequency: float = 0.005, lacunarity: float = 2.0, gain: float = 0.5) -> Array:
	var noise = FastNoiseLite.new()
	noise.set_seed(noise_seed)
	noise.set_noise_type(FastNoiseLite.TYPE_SIMPLEX) 
	noise.set_frequency(frequency)
	noise.set_fractal_lacunarity(lacunarity)
	noise.set_fractal_gain(gain)
	noise.set_fractal_type(FastNoiseLite.FRACTAL_RIDGED)
	
	heightmap = []
	for x in range(width):
		var row = []
		for y in range(height):
			var noise_value = noise.get_noise_2d(x, y)
			# Convert noise value (-1 to 1) to (0 to 1) range
			var t = (noise_value + 1) * 0.5
			# Discretize to 6 levels (0 to 5)
			var height_value = int(round(t * max_height))
			row.append(height_value)
		heightmap.append(row)
	return heightmap


func generate_chunks(height_map: Array = [], show_chunks: bool = false):
	var hm = generate_noise_heightmap(CHUNK_COUNT*CHUNK_SIZE,CHUNK_COUNT*CHUNK_SIZE,MAX_HEIGHT) if height_map == [] else height_map
	for i in hm.size():
		for j in hm[i].size():
			if show_chunks: set_column(i,j,hm[i][j],"GRASS" if (i/CHUNK_SIZE + j/CHUNK_SIZE)%2 == 0 else "WOOD")
			else: 
				var type =  "SNOW" if hm[i][j] > 3*MAX_HEIGHT/4 else \
							"GRASS" if hm[i][j] > MAX_HEIGHT/2 else \
							"GRASS" if hm[i][j] > MAX_HEIGHT/4 else \
							"WOOD"
				
				if i == 0 or j == 0 or i == hm.size()-1 or j == hm[i].size()-1: 
					set_column(i,j,hm[i][j],type)
				else:
					set_tile(i,j,hm[i][j],type)
					set_tile(i,j,hm[i][j]-1,type)



func generate_directed_path():
	# determine block, edge and chunk indices for start/end points
	var org_block = CHUNK_SIZE/2 #randi_range(0, CHUNK_SIZE - 1)# the block index of where the path begins/ends
	var org_edge = randi_range(0, 3) # which edge (^,>,v,<) the path begins/ends
	var term_edge = org_edge
	while term_edge == org_edge: term_edge = randi_range(0, 3)
	# which chunk along that edge the path begins/ends
	var org_chunk = randi_range(0, CHUNK_COUNT - 1) 
	var term_chunk = randi_range(0, CHUNK_COUNT - 1)
	#(X,Y) coords in the chunk grid
	var org_chunk_coords 
	var mid_chunk_coords = Vector2(randi_range(1, CHUNK_COUNT - 2), randi_range(1, CHUNK_COUNT - 2))
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
		if randi_range(0, 1):
			if term_chunk_coords.x < CHUNK_COUNT/2: term_chunk_coords.x += CHUNK_COUNT/2;
			else: term_chunk_coords.x -= CHUNK_COUNT/2
		else:
			if term_chunk_coords.y < CHUNK_COUNT/2: term_chunk_coords.y += CHUNK_COUNT/2;
			else: term_chunk_coords.y -= CHUNK_COUNT/2
	
	# trace first leg
	var next_starting_point = org_block
	var move_x 
	var dist
	var dir
	while org_chunk_coords != mid_chunk_coords:
		dist = mid_chunk_coords - org_chunk_coords
		if dist.x != 0 && dist.y != 0: move_x = randi_range(0, 1)
		elif dist.x != 0: move_x = 1 
		else: move_x = 0  
		dir = Vector2(dist.x/abs(dist.x) * move_x, dist.y/abs(dist.y) * (1-move_x))
		if is_nan(dir.x): dir.x = 0
		if is_nan(dir.y): dir.y = 0  
		next_starting_point = extend_path(org_chunk_coords, next_starting_point, dir)
		org_chunk_coords += dir
	
	while org_chunk_coords != term_chunk_coords:
		dist = term_chunk_coords - org_chunk_coords
		if dist.x != 0 && dist.y != 0: move_x = randi_range(0, 1)
		elif dist.x != 0: move_x = 1 
		else: move_x = 0  
		dir = Vector2(dist.x/abs(dist.x) * move_x, dist.y/abs(dist.y) * (1-move_x))
		if is_nan(dir.x): dir.x = 0
		if is_nan(dir.y): dir.y = 0  
		next_starting_point = extend_path(org_chunk_coords, next_starting_point, dir)
		org_chunk_coords += dir

	if term_edge == 0: dir = Vector2(0, -1)
	elif term_edge == 1: dir = Vector2(1, 0)
	elif term_edge == 2: dir = Vector2(0, 1)
	else: dir = Vector2(-1, 0)
	extend_path(org_chunk_coords, next_starting_point, dir)





### PLOT CURVE AGAINST TILE GRID ###
func extend_path(chunk_coords, block_coords, dir):
	var offset = chunk_coords * CHUNK_SIZE
	var rand = randi_range(0, CHUNK_SIZE - 1)
	var success = false
	var x1 
	var y1 
	var x2
	var y2 
	
	while not success:
		x1 = randi_range(0, CHUNK_SIZE - 1) + offset.x
		y1 = randi_range(0, CHUNK_SIZE - 1) + offset.y
		x2 = ((abs(dir.x)*((1+dir.x)/2)*(CHUNK_SIZE-1)))+((1-abs(dir.x))*rand) + offset.x
		y2 = ((abs(dir.y)*((1+dir.y)/2)*(CHUNK_SIZE-1)))+((1-abs(dir.y))*rand) + offset.y
		if abs(block_coords.x-x2) + abs(block_coords.y-y2) > CHUNK_SIZE or true:
			success = plotQuadBezierSeg(block_coords.x, block_coords.y, x1, y1, x2, y2, PATH_TILE)
	return Vector2(x2, y2) + dir




#func set_tile(x, y, type): 
	#MAP_GRID.set_cell_item(Vector3(x, 0, y), WORLD_TILE_LIST.TILE_NAMES[type], 0)

# i believe in Z-UP cry about it
func set_tile(x, y, z, type): 
	mutex.lock()
	MAP_GRID.set_cell_item(Vector3(x, z, y), WORLD_TILE_LIST.TILE_NAMES[type], 0)
	mutex.unlock()

func set_top_tile(x, y, type): 
	var i = 0
	while ((MAP_GRID.get_cell_item(Vector3i(x,i,y)) == -1 \
			or MAP_GRID.get_cell_item(Vector3i(x,i+1,y)) != -1) \
			and i <= MAX_HEIGHT): i+=1
	#MAP_GRID.set_cell_item(Vector3(x, i, y), WORLD_TILE_LIST.TILE_NAMES[type], 0)
	set_tile(x, y, i, type)



func set_column(x, y, z, type): 
	var i = 0
	while i != z+1:
		MAP_GRID.set_cell_item(Vector3(x, i, y), WORLD_TILE_LIST.TILE_NAMES[type], 0)
		i += 1

func set_path(x, y, type):
	var i_min = 0 if x % (CHUNK_SIZE*CHUNK_COUNT) == 0 else 1-PATH_RADIUS
	var j_min = 0 if y % (CHUNK_SIZE*CHUNK_COUNT) == 0 else 1-PATH_RADIUS
	var i_max = 1 if (x+1) % (CHUNK_SIZE*CHUNK_COUNT) == 0 else PATH_RADIUS
	var j_max = 1 if (y+1) % (CHUNK_SIZE*CHUNK_COUNT) == 0 else PATH_RADIUS
	
	# -1..1 unless on the edge of a chunk.
	for i in range(i_min, i_max):
		for j in range(j_min, j_max):
			set_top_tile(x+i, y+j, type)


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
		set_path(x0 as int, y0 as int, tile)
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
		
		set_path(x0 as int, y0 as int, tile)
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
			set_path(x0 as int, y0 as int, tile)
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

#func plotFullBezier(points):
	#pass
