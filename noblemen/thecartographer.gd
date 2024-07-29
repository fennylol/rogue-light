extends Node


var NAMES = TheArchivist.TILE_NAMES
var COLORS = TheArchivist.TILE_COLORS


func _ready(): pass 
func _process(delta): pass


func make_minimap(gridmap: GridMap, heightmap: Array) -> ImageTexture:
	var h: int = heightmap.size()
	var w: int = h
	var use_mipmaps: bool = false
	var format: int = Image.FORMAT_RGBA8
	
	var img := Image.create(h,w,use_mipmaps,format)

	#for x in heightmap.size():
		#for y in heightmap.size(): 
			#img.set_pixel(x,y,COLORS[gridmap.get_cell_item(Vector3(x,heightmap[x][y],y))]/255)
	
	for pos in gridmap.get_used_cells():
		var item = gridmap.get_cell_item(pos)
		if item != NAMES.TALL_PINE: img.set_pixel(pos.x,pos.z,COLORS[item]/255)
	
	return ImageTexture.create_from_image(img)
