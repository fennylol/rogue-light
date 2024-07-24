extends Node3D
### WISHLIST ###
# [caravan]
#  L [x] follows path
#  L [x] ridable (cash money)
#  L [ ] sits on ground nicely
#  L [ ] other actor aware (slows/stop if something is in front etc)
#  L [ ] drops loot
#  L [ ] comes with body guards
#  L [ ] reacts to how player has been attacking it
# [ ] collect resources
# [x] camera improvements

var DUKE = TheDuke
var ARCHIVIST = TheArchivist
var FOOL = TheFool
const MasterOfWorks = preload("res://noblemen/themasterofworks.gd")
var Caravan = preload("res://entities/caravan/caravan.gd")
@onready var PLAYER = $Bandit as CharacterBody3D
@onready var CAMERA = $camera_man as Node3D
@onready var GUI = $Gui as Control
@onready var WORLD = $world_parts as Node3D
@onready var HEAVENLY_BODIES = $world_parts/lights/heavenly_bodies as Node3D
@onready var STATIC_LIGHTS = $world_parts/lights/static_lights as Node3D
@onready var POINTS_OF_INTEREST = $world_parts/points_of_interest as Node3D
@onready var MAP_GRID = $world_parts/GridMap as GridMap
const KILL_HEIGHT = -10

### WORLD GEN PARAMETERS ###
const CHUNK_SIZE: int = 64
const CHUNK_COUNT: int = 8
const MAX_HEIGHT: int = 40
const PATH_RADIUS: int = 3 #dist past the centerline on either side. path will be 2r+1 tiles wide
const PATH_TILE: String = "PATH"
const DEBUG_MODE: bool = false
var MASTER_OF_WORKS := MasterOfWorks.new()


### CAMERA PARAMETERS ###
const CAM_SIZE: float = 20
const MIN_CAM_SIZE: float = 5
const MAX_CAM_SIZE: float = 100
var target_size: float = CAM_SIZE

const MAX_PITCH: float = 2.5 #0.5
var target_rotation: float = 0.0
var target_pitch: float = 0.0
var mouse_pos := Vector2.ZERO

var FADE_SETTINGS := Vector3(5.0, 20.0, 0.25) # begin dist, end dist, and min alpha


#### TIME/CARAVAN ###
enum {AM, PM}
enum {HOUR, MINUTE, PERIOD, DAY}
const SCHEDULE_LENGTH: int = 14
const CARAVAN_MPS: float = 4 #meters/sec
const MAX_CARAVAN_SIZE = 3
var SHIPPING_SCHEDULE := Vector4i(13,14,0,0)
var active_wagons = 0

func _ready(): 
	generate_map()
	DUKE.tick.connect(process_world_tick)
	DUKE.command_dispatch.connect(recieve_orders)


func _process(delta):
	move_camera(delta)
	if DUKE.PAUSED: return
	if PLAYER.position.y <= KILL_HEIGHT: move_player(false,false, MASTER_OF_WORKS.get_world_scale())
	
	var fade_material: Material = MAP_GRID.mesh_library.get_item_mesh(ARCHIVIST.TILE_NAMES["TALL_PINE"]).surface_get_material(0)
	if fade_material is ShaderMaterial:
		fade_material.set_shader_parameter("player_position", PLAYER.global_transform.origin)
		fade_material.set_shader_parameter("camera_position", CAMERA.get_child(0).global_transform.origin)
		fade_material.set_shader_parameter("fade_settings", FADE_SETTINGS)
	else:
		var shader_material = ShaderMaterial.new() as ShaderMaterial
		shader_material.shader = preload("res://points_of_interest/the_forest/trees/tree_fade.gdshader")
		var texture = preload("res://points_of_interest/the_forest/trees/tall_pine.png")
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
	# TODO CONNECT CARAVAN FINISHED SIGNAL TO DESTROY THE PATH
	var path = MASTER_OF_WORKS.get_road_path()
	var hm = MASTER_OF_WORKS.get_heightmap()
	var ws = MASTER_OF_WORKS.get_world_scale()
	var path3d = Path3D.new()
	path3d.name = "road_path"
	path3d.set_curve(Curve3D.new())
	
	const LEG_SCALE: float = 0.6 #IDK why the godot bezier needs to be scaled down, but it just works.
	for i in path.size():
		var points = path[i]
		var next_points = path[i+1] if i+1 != path.size() else [path[i][2],path[i][1],path[i][0]]
		var true_end = (points[2]+next_points[0])/2.0
		if not i: path3d.curve.add_point(points[0], Vector3.ZERO, (points[1]-points[0])*LEG_SCALE)
		path3d.curve.add_point(true_end, (points[1]-true_end)*LEG_SCALE, (next_points[1]-true_end)*LEG_SCALE)
	
	WORLD.add_child(path3d)
	for i in TheFool.range_i(1,MAX_CARAVAN_SIZE):
		if WORLD.get_node("road_path"):
			var decrease_active_wagons = func(): active_wagons -= 1; if active_wagons == 0: WORLD.remove_child(path3d)
			var caravan = Caravan.init(hm, ws, path3d.curve.get_baked_length()/CARAVAN_MPS) as PathFollow3D
			caravan.name = "caravan_"+str(i)
			active_wagons += 1
			caravan.finished.connect(decrease_active_wagons)
			path3d.add_child(caravan)
			var caravan_length = caravan.length * 1.2
			await get_tree().create_timer(caravan_length/CARAVAN_MPS).timeout


func generate_map(r: bool = true, s: bool = true):
	if WORLD.get_node_or_null("road_path"): WORLD.get_node("road_path").queue_free()
	var on_map_generation_finished = func():	
		move_player(r,s, MASTER_OF_WORKS.get_world_scale())
		MAP_GRID.queue_free()
		for i in POINTS_OF_INTEREST.get_child_count(): POINTS_OF_INTEREST.get_child(i).queue_free()
		MAP_GRID = MASTER_OF_WORKS.get_map_grid()
		WORLD.add_child(MAP_GRID)
		
		for poi in MASTER_OF_WORKS.get_points_of_interest():
			#print("generating: ", poi[MASTER_OF_WORKS.NAME])
			var scene = load(poi[MASTER_OF_WORKS.SCENE]).instantiate()
			POINTS_OF_INTEREST.add_child(scene)
			scene.position = poi[MASTER_OF_WORKS.COORDS]
			scene.name = poi[MASTER_OF_WORKS.NAME]
			scene.rotation.y = FOOL.range_f(0, 2*PI)
			if poi[MASTER_OF_WORKS.NAME] == "camp": move_player(r,s, MASTER_OF_WORKS.get_world_scale(), poi[MASTER_OF_WORKS.COORDS])
	
	MASTER_OF_WORKS = MasterOfWorks.new(CHUNK_SIZE, CHUNK_COUNT, MAX_HEIGHT, PATH_RADIUS, PATH_TILE, DEBUG_MODE)
	MASTER_OF_WORKS.finished.connect(on_map_generation_finished)
	MASTER_OF_WORKS.generate_map()



func move_player(r: bool = true, s: bool = true, world_scale := Vector3(1,1,1), set_pos := Vector3.ZERO):
	if set_pos: PLAYER.position = set_pos + Vector3(0,1,0)
	else:
		var midpoint = Vector2(CHUNK_COUNT*CHUNK_SIZE*world_scale.x, CHUNK_COUNT*CHUNK_SIZE*world_scale.z)/2.0
		var height = ceil(MASTER_OF_WORKS.get_heightmap()[midpoint.x][midpoint.y]*world_scale.y)
		PLAYER.position = Vector3(midpoint.x, height+1, midpoint.y)
	reset_camera(r, s)


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
	
	if Input.is_action_just_released("move_cam"): 
		Input.warp_mouse(mouse_pos) 
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif Input.is_action_just_pressed("move_cam"):
		mouse_pos = get_viewport().get_mouse_position()
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		#var pos =
		#if pos.x + 1 >= get_viewport().size.x: Input.warp_mouse(Vector2(1,pos.y))
		#elif pos.x <= 0: Input.warp_mouse(Vector2(get_viewport().size.x,pos.y-1))
		#
		#if pos.y + 1 >= get_viewport().size.y: Input.warp_mouse(Vector2(pos.x,1))
		#elif pos.y <= 0: Input.warp_mouse(Vector2(pos.x,get_viewport().size.y-1))
	
	var scroll: int = 2*int(Input.is_action_just_released("scroll_down")) - int(Input.is_action_just_released("scroll_up"))
	target_size = min(max(target_size+scroll, MIN_CAM_SIZE), MAX_CAM_SIZE)
	
	if CAMERA.get_child(0).get_projection() == Camera3D.PROJECTION_ORTHOGONAL:
		CAMERA.get_child(0).size = lerp(CAMERA.get_child(0).size, target_size, 0.1)
	
	CAMERA.rotation.y = lerp(CAMERA.rotation.y, target_rotation, 0.1)
	CAMERA.rotation.x = lerp(CAMERA.rotation.x, target_pitch, 0.1)
	
	if Input.is_action_pressed("DEV"):
		if Input.is_action_pressed("look_up") and Input.is_action_pressed("look_down"): reset_camera(false, true)
		if Input.is_action_pressed("look_left") and Input.is_action_pressed("look_right"): reset_camera(true, false)
		if Input.is_action_pressed("look_up") and Input.is_action_pressed("look_left"): reset_camera()


func _input(event):
	if event is InputEventMouseMotion and Input.is_action_pressed("move_cam"):
		if abs(event.relative.x): 
			var amount = -event.relative.x * get_process_delta_time()
			target_rotation += amount
			PLAYER.rotate_player(amount)
			GUI.rotate_compass(amount)
		if abs(event.relative.y): 
			var input = target_pitch + -event.relative.y/abs(event.relative.y) * get_process_delta_time()
			target_pitch = min(max(input, -MAX_PITCH), MAX_PITCH)


func move_cam_with_buttons(delta):
	var look_direction = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_direction:
		target_rotation += look_direction.x * delta  
		if CAMERA.get_child(0).get_projection() == Camera3D.PROJECTION_ORTHOGONAL:
			target_size = min(max(look_direction.y+target_size, MIN_CAM_SIZE), MAX_CAM_SIZE)
		else: 
			CAMERA.get_child(0).position.y += look_direction.y * delta * CAMERA.get_child(0).position.y
			CAMERA.get_child(0).position.z += look_direction.y * delta * CAMERA.get_child(0).position.z


func reset_camera(r: bool = true, s: bool = true):
	CAMERA.position = PLAYER.position
	if r: 
		CAMERA.rotation = Vector3.ZERO; 
		PLAYER.reset_rotation()
		target_rotation = 0
	if s: 
		if CAMERA.get_child(0).get_projection() == Camera3D.PROJECTION_ORTHOGONAL:
			CAMERA.get_child(0).size = CAM_SIZE
		else: CAMERA.get_child(0).position = Vector3(0,15.5,22.0)

func recieve_orders(orders: Dictionary):
	#var COMMAND_ = func(options: Dictionary): 
		#if options.has(""): pass
		
	var COMMAND_setfade = func(options: Dictionary):
		var begin: float = FADE_SETTINGS.x
		var end: float = FADE_SETTINGS.y
		var minalpha: float = FADE_SETTINGS.z
		if options.has("begin"): begin = float(options.begin[0])
		if options.has("end"): end = float(options.end[0])
		if options.has("minalpha"): minalpha = float(options.minalpha[0])
		FADE_SETTINGS = Vector3(begin, end, minalpha)
	
	var COMMAND_resetworld = func(options: Dictionary):
		var r = true if options.has("r") else false
		var s = true if options.has("s") else false
		generate_map(r,s)
	
	var COMMAND_caravan = func(options: Dictionary):
		if options.has("send"): send_shipment()
		if options.has("getschedule"): 
			print("shipment 1: day ", SHIPPING_SCHEDULE.x, " at ", int(SHIPPING_SCHEDULE.z)/60, ":", int(SHIPPING_SCHEDULE.z)%60)
			print("shipment 2: day ", SHIPPING_SCHEDULE.y, " at ", int(SHIPPING_SCHEDULE.w)/60, ":", str(int(SHIPPING_SCHEDULE.w)%60).pad_zeros(2) )
	
	var COMMAND_cam = func(options: Dictionary): 
		var cam: Camera3D = CAMERA.get_child(0)
		if options.has("o"):
			cam.set_current(true)
			PLAYER.enable_camera(false)
			cam.set_projection(Camera3D.PROJECTION_ORTHOGONAL)
			cam.position = Vector3(0,155,220)
		elif options.has("p"): 
			cam.set_current(true)
			PLAYER.enable_camera(false)
			cam.set_projection(Camera3D.PROJECTION_PERSPECTIVE)
			cam.position = Vector3(0,15.5,22.0)
		elif options.has("f"):
			PLAYER.enable_camera()
			cam.set_current(false)
		
	
	if orders.command_name == "resetworld": COMMAND_resetworld.call(orders.options)
	elif orders.command_name == "setfade": COMMAND_setfade.call(orders.options)
	elif orders.command_name == "caravan": COMMAND_caravan.call(orders.options)
	elif orders.command_name == "cam": COMMAND_cam.call(orders.options)
	
	

