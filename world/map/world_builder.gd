extends Thread
### WISHLIST ###
# change to cubic bezier <- this doent help. instead draw a vector from the endpoint to the midpoint, negate that, make that the vector to the next chunk's midpoint.
# trees
# smarter generation 
# - create world as one block
# - using hightmap, go through and paint biomes
# fix vertical gaps

const TILES = TheArchivist.TILE_NAMES
var FOOL = TheFool
var CHUNK_SIZE
var CHUNK_COUNT
var MAX_HEIGHT
var PATH_RADIUS
var PATH_TILE
const TREE_ODDS = 10
const MIN_TREE_SPACING = 5
const WORLD_SCALE = Vector3(.5,.25,.5)

signal finished
var heightmap = []
var road_path: Array = []
var MAP_GRID = GridMap.new()
var mutex = Mutex.new()

# debug settings
var SHOW_CHUNKS = false
var SHOW_CURVE_HANDLES = false
const HANDLE_HEIGHT = 2

func _init(cs: int = 16, cc: int = 16, mh: int = 10, pr: int = 2, pt: String = "STONE", dm: bool = false):
	CHUNK_COUNT = cc
	CHUNK_SIZE = cs
	MAX_HEIGHT = mh * int(not dm)
	PATH_RADIUS = pr
	PATH_TILE = pt
	MAP_GRID.mesh_library = load("res://world/map/halfm_tiles.tres")
	MAP_GRID.set_cell_size(WORLD_SCALE)
	MAP_GRID.position = Vector3(-0.5,0,-0.5)
	SHOW_CHUNKS = dm
	SHOW_CURVE_HANDLES = dm

func get_heightmap(): return heightmap
func get_map_grid(): return MAP_GRID
func get_road_path(): return road_path


func stop_thread():
	wait_to_finish()
	free()

func generate_map():
	MAP_GRID.clear()
	generate_chunks()
	generate_forest()
	#generate_directed_curve("WATER")
	generate_directed_curve(PATH_TILE)
	finished.emit()


# i believe in Z-UP cry about it
func set_tile(x, y, z, type, rot = 0): 
	mutex.lock()
	MAP_GRID.set_cell_item(Vector3(x, z, y), TILES[type], rot)
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
		MAP_GRID.set_cell_item(Vector3(x, i, y), TILES[type], 0)
		i += 1

func set_path(x, y, type):
	var i_min = 0 if x % (CHUNK_SIZE*CHUNK_COUNT) == 0 else 1-PATH_RADIUS
	var j_min = 0 if y % (CHUNK_SIZE*CHUNK_COUNT) == 0 else 1-PATH_RADIUS
	var i_max = 1 if (x+1) % (CHUNK_SIZE*CHUNK_COUNT) == 0 else PATH_RADIUS
	var j_max = 1 if (y+1) % (CHUNK_SIZE*CHUNK_COUNT) == 0 else PATH_RADIUS
	var height = 0.0
	
	for i in range(i_min, i_max):
		for j in range(j_min, j_max):
			height += heightmap[x+i][y+j]
	
	height = floor((height/(abs(i_max-i_min)*abs(j_max-j_min)))+0.5)
	
	# -1..1 unless on the edge of a chunk. (assuming r=2)
	for i in range(i_min, i_max):
		for j in range(j_min, j_max):
			if MAX_HEIGHT <= 20:
				set_tile(x+i, y+j, height-1, type)
				set_tile(x+i, y+j, height, type)
				set_tile(x+i, y+j, height+1,"AIR")
			else:
				set_tile(x+i, y+j, heightmap[x+i][y+j], type)
				set_tile(x+i, y+j, heightmap[x+i][y+j]+1,"AIR")

# function created with the help of claude AI, availible at claude.ai 
func generate_noise_heightmap(width: int, height: int, max_height: int, noise_seed: int = FOOL.rand_i(), frequency: float = 0.005, lacunarity: float = 2.0, gain: float = 0.5) -> Array:
	var noise = FastNoiseLite.new()
	var offset = Vector2i(width,height)
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
				var type =  "STONE" if hm[i][j] > 3*MAX_HEIGHT/4 else \
							"GRASS" if hm[i][j] > MAX_HEIGHT/2 else \
							"GRASS" if hm[i][j] > MAX_HEIGHT/4 else \
							"WOOD"
				
				if i == 0 or j == 0 or i == hm.size()-1 or j == hm[i].size()-1: 
					set_column(i,j,hm[i][j],type)
				else:
					set_tile(i,j,hm[i][j],type)
					set_tile(i,j,hm[i][j]-1,type)



func generate_directed_curve(tile):
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
	var next_starting_point = org_block
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
		next_starting_point = extend_curve(org_chunk_coords, next_starting_point, dir, tile)
		org_chunk_coords += dir
	
	while org_chunk_coords != term_chunk_coords:
		dist = term_chunk_coords - org_chunk_coords
		if dist.x != 0 && dist.y != 0: move_x = FOOL.range_i(0, 1)
		elif dist.x != 0: move_x = 1 
		else: move_x = 0  
		dir = Vector2(dist.x/abs(dist.x) * move_x, dist.y/abs(dist.y) * (1-move_x))
		if is_nan(dir.x): dir.x = 0
		if is_nan(dir.y): dir.y = 0  
		next_starting_point = extend_curve(org_chunk_coords, next_starting_point, dir, tile)
		org_chunk_coords += dir

	if term_edge == 0: dir = Vector2(0, -1)
	elif term_edge == 1: dir = Vector2(1, 0)
	elif term_edge == 2: dir = Vector2(0, 1)
	else: dir = Vector2(-1, 0)
	extend_curve(org_chunk_coords, next_starting_point, dir, tile)





### PLOT CURVE AGAINST TILE GRID ###
func extend_curve(chunk_coords, block_coords, dir, path):
	var offset = chunk_coords * CHUNK_SIZE
	var rand = FOOL.range_i(0, CHUNK_SIZE - 1)
	var x1 
	var y1 
	var x2
	var y2 
	
	x1 = FOOL.range_i(1, CHUNK_SIZE - 2) + offset.x
	y1 = FOOL.range_i(1, CHUNK_SIZE - 2) + offset.y
	x2 = ((abs(dir.x)*((1+dir.x)/2)*(CHUNK_SIZE-1)))+((1-abs(dir.x))*rand) + offset.x
	y2 = ((abs(dir.y)*((1+dir.y)/2)*(CHUNK_SIZE-1)))+((1-abs(dir.y))*rand) + offset.y
	
	#if block_coords.x==x1 and x1==x2:
		#x1 += 1 if x1 != CHUNK_SIZE - 2 else -1
	#if block_coords.y==y1 and y1==y2:
		#y1 += 1 if y1 != CHUNK_SIZE - 2 else -1
		
	if (block_coords-Vector2(x1,y1)).normalized() == (Vector2(x1,y1)-Vector2(x2,y2)).normalized():
		if FOOL.range_i(0,1): x1 += 1 if x1 != CHUNK_SIZE - 2 else -1
		else: y1 += 1 if y1 != CHUNK_SIZE - 2 else -1
	
	while abs(block_coords.x-x2) + abs(block_coords.y-y2) < CHUNK_SIZE/2:
		rand = FOOL.range_i(0, CHUNK_SIZE - 1)
		x2 = ((abs(dir.x)*((1+dir.x)/2)*(CHUNK_SIZE-1)))+((1-abs(dir.x))*rand) + offset.x
		y2 = ((abs(dir.y)*((1+dir.y)/2)*(CHUNK_SIZE-1)))+((1-abs(dir.y))*rand) + offset.y
	
	
	plotQuadBezier(block_coords.x, block_coords.y, x1, y1, x2, y2, path)
	var start_point = Vector3(block_coords.x,heightmap[block_coords.x][block_coords.y],block_coords.y) * WORLD_SCALE
	var mid_point = Vector3(x1,heightmap[x1][y1],y1) * WORLD_SCALE
	var end_point = Vector3(x2,heightmap[x2][y2],y2) * WORLD_SCALE
	road_path.push_back([start_point,mid_point,end_point])
	
	if SHOW_CURVE_HANDLES:
		var color = "BLACK"
		if int(chunk_coords.x + chunk_coords.y) % 2: color = "WHITE"
		MAP_GRID.set_cell_item(start_point+Vector3(0,HANDLE_HEIGHT,0), TILES[color])
		MAP_GRID.set_cell_item(mid_point+Vector3(0,HANDLE_HEIGHT,0), TILES[color])
		MAP_GRID.set_cell_item(end_point+Vector3(0,HANDLE_HEIGHT,0), TILES[color])
	return Vector2(x2, y2) + dir




func generate_forest(): 
	#load("res://RAW_RESOURCES/helpers.gd").add_mesh_to_library_shaded("res://world/map/1m_tiles.tres", "res://world/map/trees/tall_pine.obj", "tall_pine")
	for i in heightmap.size():
		for j in heightmap[i].size():
			var Z = heightmap[i][j]+1
			if not FOOL.range_i(0,TREE_ODDS):
				var rot_i = [0, 16, 10, 22]
				var rot = rot_i[FOOL.range_i(0, 3)]
				if is_flat_and_centered(Vector2(i,j), 1) and \
				is_no_trees_nearby(Vector2(i,j), MIN_TREE_SPACING): set_tile(i,j,Z,"TALL_PINE",rot)
				#else: set_tile(i,j,Z,"TREE_"+str(FOOL.range_i(0,1)),rot)


func is_flat_and_centered(coords: Vector2, range: int) -> bool:
	var height = heightmap[coords.x][coords.y]

	if coords.x == 0 or coords.x == CHUNK_COUNT*CHUNK_SIZE-1 \
	or coords.y == 0 or coords.y == CHUNK_COUNT*CHUNK_SIZE-1:
		return false
	
	for i in range(coords.x - range, coords.x + range + 1):
		for j in range(coords.y - range, coords.y + range + 1):
			if heightmap[i][j] != height: return false
	
	return true

func is_no_trees_nearby(coords: Vector2, range: int):
	if coords.x == 0 or coords.x == CHUNK_COUNT*CHUNK_SIZE-1 \
	or coords.y == 0 or coords.y == CHUNK_COUNT*CHUNK_SIZE-1:
		return false
	
	var height = heightmap[coords.x][coords.y]
	for i in range(coords.x - range, coords.x + range + 1):
		for j in range(coords.y - range, coords.y + range + 1):
			for k in range(height - range, height + range + 1):
				if MAP_GRID.get_cell_item(Vector3(i,k,j)) == TILES["TALL_PINE"]: return false
	
	return true

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

func plotCubicBezierSeg(x0: int, y0: int, x1: float, y1: float, x2: float, y2: float, x3: int, y3: int, tile):
	var f
	var fx
	var fy
	var leg = 1
	var sx = 1 if x0 < x3 else -1
	var sy = 1 if y0 < y3 else -1
	var xc = -absf(x0+x1-x2-x3)
	var xa = xc-4*sx*(x1-x2)
	var xb = sx*(x0-x1-x2+x3)
	var yc = -absf(y0+y1-y2-y3)
	var ya = yc-4*sy*(y1-y2)
	var yb = sy*(y0-y1-y2+y3);
	var ab
	var ac
	var bc
	var cb
	var xx
	var xy
	var yy
	var dx
	var dy
	var ex
	var ptr_xy
	var EP = 0.01; 
	
	#assert((x1-x0)*(x2-x3) < EP && ((x3-x0)*(x1-x2) < EP || xb*xb < xa*xc+EP)); 
	#assert((y1-y0)*(y2-y3) < EP && ((y3-y0)*(y1-y2) < EP || yb*yb < ya*yc+EP));
	
	if ((x1-x0)*(x2-x3) < EP && ((x3-x0)*(x1-x2) < EP || xb*xb < xa*xc+EP)): print("good")
	if ((y1-y0)*(y2-y3) < EP && ((y3-y0)*(y1-y2) < EP || yb*yb < ya*yc+EP)): print("good")
	
	
	if (xa == 0 && ya == 0):
		sx = floor((3*x1-x0+1)/2)
		sy = floor((3*y1-y0+1)/2)
		print("qwuadding")
		return plotQuadBezierSeg(x0,y0, sx,sy, x3,y3, tile);
	
	x1 = (x1-x0)*(x1-x0)+(y1-y0)*(y1-y0)+1
	x2 = (x2-x3)*(x2-x3)+(y2-y3)*(y2-y3)+1
	
	### for DO-WHILE like behavior
	var outer_loop = true
	while leg > 0 or outer_loop:
		outer_loop = false
		leg -= 1
		ab = xa*yb-xb*ya; ac = xa*yc-xc*ya; bc = xb*yc-xc*yb
		ex = ab*(ab+ac-3*bc)+ac*ac
		f = 1 if ex > 0 else sqrt(1+1024/x1)
		ab *= f
		ac *= f
		bc *= f
		ex *= f*f;
		xy = 9*(ab+ac+bc)/8
		cb = 8*(xa-ya)
		dx = 27*(8*ab*(yb*yb-ya*yc)+ex*(ya+2*yb+yc))/64-ya*ya*(xy-ya)
		dy = 27*(8*ab*(xb*xb-xa*xc)-ex*(xa+2*xb+xc))/64-xa*xa*(xy+xa)
		xx = 3*(3*ab*(3*yb*yb-ya*ya-2*ya*yc)-ya*(3*ac*(ya+yb)+ya*cb))/4
		yy = 3*(3*ab*(3*xb*xb-xa*xa-2*xa*xc)-xa*(3*ac*(xa+xb)+xa*cb))/4
		xy = xa*ya*(6*ab+6*ac-3*bc+cb)
		ac = ya*ya
		cb = xa*xa
		xy = 3*(xy+9*f*(cb*yb*yc-xb*xc*ac)-18*xb*yb*ab)/8; 
		
		if ex < 0:
			dx = -dx
			dy = -dy
			xx = -xx
			yy = -yy
			xy = -xy
			ac = -ac
			cb = -cb
		
		ab = 6*ya*ac
		ac = -6*xa*ac
		bc = 6*ya*cb
		cb = -6*xa*cb
		dx += xy
		ex = dx+dy
		dy += xy
		
		#for (ptr_xy = xy, fx = fy = f; x0 != x3 && y0 != y3; ) {
		ptr_xy = xy
		fx = f
		fy = f
		var exit = false
		while (x0 != x3 and y0 != y3) and not exit:
			set_path(x0,y0,tile)
			
			var inner_loop = true
			while (fx > 0 and fy > 0) or inner_loop:
				inner_loop = false
				if dx > ptr_xy || dy < ptr_xy: 
					exit = true
					break #GOTO EXIT
				y1 = 2*ex-dy
				if 2*ex >= dx:
					fx -= 1
					ex += dx
					dx += xx
					dy += xy
					xy += ac
					yy += bc
					xx += ab
				if y1 <= 0:
					fy -= 1
					ex += dy
					dy += yy
					dx += xy
					xy += bc
					xx += ac
					yy += cb
			
			if 2*fx <= f:
				x0 += sx
				fx += f       
			if 2*fy <= f: 
				y0 += sy
				fy += f
			if ptr_xy == xy && dx < 0 && dy > 0: ptr_xy = EP
		##EXIT 
		xx = x0
		x0 = x3
		x3 = xx
		sx = -sx
		xb = -xb
		yy = y0
		y0 = y3
		y3 = yy
		sy = -sy
		yb = -yb
		x1 = x2
		### OUTER WHILE
	plotLine(x0,y0,x3,y3,tile)



func plot_cubic_bezier_seg(x0: int, y0: int, x1: float, y1: float,
						   x2: float, y2: float, x3: int, y3: int, tile):
	var f: int
	var fx: int
	var fy: int
	var leg = 1
	var sx = 1 if x0 < x3 else -1
	var sy = 1 if y0 < y3 else -1
	var xc = -abs(x0 + x1 - x2 - x3)
	var xa = xc - 4 * sx * (x1 - x2)
	var xb = sx * (x0 - x1 - x2 + x3)
	var yc = -abs(y0 + y1 - y2 - y3)
	var ya = yc - 4 * sy * (y1 - y2)
	var yb = sy * (y0 - y1 - y2 + y3)
	var ab: float
	var ac: float
	var bc: float
	var cb: float
	var xx: float
	var xy: float
	var yy: float
	var dx: float
	var dy: float
	var ex: float
	var pxy: float
	var EP = 0.01
	
	assert((x1 - x0) * (x2 - x3) < EP and ((x3 - x0) * (x1 - x2) < EP or xb * xb < xa * xc + EP))
	#assert((y1 - y0) * (y2 - y3) < EP and ((y3 - y0) * (y1 - y2) < EP or yb * yb < ya * yc + EP))
	
	if xa == 0 and ya == 0:
		sx = floor((3 * x1 - x0 + 1) / 2)
		sy = floor((3 * y1 - y0 + 1) / 2)
		return plotQuadBezierSeg(x0, y0, sx, sy, x3, y3, tile)
	
	x1 = (x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0) + 1
	x2 = (x2 - x3) * (x2 - x3) + (y2 - y3) * (y2 - y3) + 1
	
	while leg > 0:
		ab = xa * yb - xb * ya
		ac = xa * yc - xc * ya
		bc = xb * yc - xc * yb
		ex = ab * (ab + ac - 3 * bc) + ac * ac
		f = 1 if ex > 0 else sqrt(1 + 1024 / x1)
		ab *= f
		ac *= f
		bc *= f
		ex *= f * f
		xy = 9 * (ab + ac + bc) / 8
		cb = 8 * (xa - ya)
		dx = 27 * (8 * ab * (yb * yb - ya * yc) + ex * (ya + 2 * yb + yc)) / 64 - ya * ya * (xy - ya)
		dy = 27 * (8 * ab * (xb * xb - xa * xc) - ex * (xa + 2 * xb + xc)) / 64 - xa * xa * (xy + xa)
		xx = 3 * (3 * ab * (3 * yb * yb - ya * ya - 2 * ya * yc) - ya * (3 * ac * (ya + yb) + ya * cb)) / 4
		yy = 3 * (3 * ab * (3 * xb * xb - xa * xa - 2 * xa * xc) - xa * (3 * ac * (xa + xb) + xa * cb)) / 4
		xy = xa * ya * (6 * ab + 6 * ac - 3 * bc + cb)
		ac = ya * ya
		cb = xa * xa
		xy = 3 * (xy + 9 * f * (cb * yb * yc - xb * xc * ac) - 18 * xb * yb * ab) / 8
		
		if ex < 0:
			dx = -dx
			dy = -dy
			xx = -xx
			yy = -yy
			xy = -xy
			ac = -ac
			cb = -cb
		
		ab = 6 * ya * ac
		ac = -6 * xa * ac
		bc = 6 * ya * cb
		cb = -6 * xa * cb
		dx += xy
		ex = dx + dy
		dy += xy
		
		pxy = xy
		fx = f
		fy = f
		while x0 != x3 and y0 != y3:
			set_path(x0, y0, tile)
			while fx > 0 and fy > 0:
				if dx > pxy or dy < pxy:
					break
				y1 = 2 * ex - dy
				if 2 * ex >= dx:
					fx -= 1
					ex += dx
					dx += xx
					dy += xy
					xy += ac
					yy += bc
					xx += ab
				if y1 <= 0:
					fy -= 1
					ex += dy
					dy += yy
					dx += xy
					xy += bc
					xx += ac
					yy += cb
			if 2 * fx <= f:
				x0 += sx
				fx += f
			if 2 * fy <= f:
				y0 += sy
				fy += f
			if pxy == xy and dx < 0 and dy > 0:
				pxy = EP
		
		xx = x0
		x0 = x3
		x3 = xx
		sx = -sx
		xb = -xb
		yy = y0
		y0 = y3
		y3 = yy
		sy = -sy
		yb = -yb
		x1 = x2
		leg -= 1
	
	plotLine(x0, y0, x3, y3, tile)

func plot_cubic_bezier(x0: int, y0: int, x1: int, y1: int,
					   x2: int, y2: int, x3: int, y3: int, tile):
	var n = 0
	#var i = 0
	var xc = x0 + x1 - x2 - x3
	var xa = xc - 4 * (x1 - x2)
	var xb = x0 - x1 - x2 + x3
	var xd = xb + 4 * (x1 + x2)
	var yc = y0 + y1 - y2 - y3
	var ya = yc - 4 * (y1 - y2)
	var yb = y0 - y1 - y2 + y3
	var yd = yb + 4 * (y1 + y2)
	var fx0 = float(x0)
	var fy0 = float(y0)
	var fx1: float
	var fx2: float
	var fx3: float
	var fy1: float
	var fy2: float
	var fy3: float
	var t1 = xb * xb - xa * xc
	var t2: float
	var t = []
	
	if xa == 0:  # horizontal
		if abs(xc) < 2 * abs(xb):
			t.append(xc / (2.0 * xb))  # one change
	elif t1 > 0.0:  # two changes
		t2 = sqrt(t1)
		t1 = (xb - t2) / xa
		if abs(t1) < 1.0:
			t.append(t1)
		t1 = (xb + t2) / xa
		if abs(t1) < 1.0:
			t.append(t1)
	
	t1 = yb * yb - ya * yc
	if ya == 0:  # vertical
		if abs(yc) < 2 * abs(yb):
			t.append(yc / (2.0 * yb))  # one change
	elif t1 > 0.0:  # two changes
		t2 = sqrt(t1)
		t1 = (yb - t2) / ya
		if abs(t1) < 1.0:
			t.append(t1)
		t1 = (yb + t2) / ya
		if abs(t1) < 1.0:
			t.append(t1)
	
	t.sort()  # replace bubble sort with built-in sort
	
	t1 = -1.0
	t.append(1.0)  # begin / end point
	for i in range(t.size() + 1):  # plot each segment separately
		t2 = t[i] if i < t.size() else 1.0  # sub-divide at t[i-1], t[i]
		fx1 = (t1 * (t1 * xb - 2 * xc) - t2 * (t1 * (t1 * xa - 2 * xb) + xc) + xd) / 8 - fx0
		fy1 = (t1 * (t1 * yb - 2 * yc) - t2 * (t1 * (t1 * ya - 2 * yb) + yc) + yd) / 8 - fy0
		fx2 = (t2 * (t2 * xb - 2 * xc) - t1 * (t2 * (t2 * xa - 2 * xb) + xc) + xd) / 8 - fx0
		fy2 = (t2 * (t2 * yb - 2 * yc) - t1 * (t2 * (t2 * ya - 2 * yb) + yc) + yd) / 8 - fy0
		fx3 = (t2 * (t2 * (3 * xb - t2 * xa) - 3 * xc) + xd) / 8
		fx0 -= fx3 
		fy3 = (t2 * (t2 * (3 * yb - t2 * ya) - 3 * yc) + yd) / 8
		fy0 -= fx3 
		x3 = int(fx3 + 0.5)
		y3 = int(fy3 + 0.5)  # scale bounds to int
		if fx0 != 0.0:
			fx0 = (x0 - x3) / fx0
			fx1 *= fx0
			fx2 *= fx0
		if fy0 != 0.0:
			fy0 = (y0 - y3) / fy0
			fy1 *= fy0
			fy2 *= fy0
		if x0 != x3 or y0 != y3:  # segment t1 - t2
			plotCubicBezierSeg(x0, y0, x0 + fx1, y0 + fy1, x0 + fx2, y0 + fy2, x3, y3, tile)
		x0 = x3
		y0 = y3
		fx0 = fx3
		fy0 = fy3
		t1 = t2
