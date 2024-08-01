extends Node


var NAMES = TheArchivist.TILE_NAMES
var COLORS = TheArchivist.TILE_COLORS


func make_minimap(gridmap: GridMap, dimentions: Vector3) -> Image:
	var h: int = dimentions.x
	var w: int = dimentions.z
	var depth: int = dimentions.y
	var use_mipmaps: bool = false
	var format: int = Image.FORMAT_RGBA8
	
	var img := Image.create(h,w,use_mipmaps,format)

	#for x in heightmap.size():
		#for y in heightmap.size(): 
			#img.set_pixel(x,y,COLORS[gridmap.get_cell_item(Vector3(x,heightmap[x][y],y))]/255)
	
	for pos in gridmap.get_used_cells():
		var item = gridmap.get_cell_item(pos)
		if item != NAMES.TALL_PINE: 
			img.set_pixel(pos.x,pos.z,adjust_color_by_height(COLORS[item],pos.y,depth))
	
	img.save_png("res://GUI/map/minimap.png")
	return img

func adjust_color_by_height(c: Color, value: float, max_height: float, min_height: float = 0) -> Color:
	var tone_steps: int = max_height/4
	var zerotoone: float = (value - min_height) / (max_height - min_height)
	zerotoone = snappedf(zerotoone, 1.0/tone_steps)
	var color_adjustment = Color(zerotoone,zerotoone,zerotoone,1)
	c /= 255
	return c * (2*color_adjustment)
