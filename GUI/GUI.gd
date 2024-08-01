extends Control
### WISHLIST ###
# [x] compasss
# [ ] cuter clock

enum {AM, PM}
enum {HOUR, MINUTE, PERIOD, DAY}

@onready var left_container = $top/left as VBoxContainer
@onready var input_zone = $command_zone/input_zone as TextEdit
@onready var command_zone = $command_zone as VBoxContainer
@onready var output = $output_zone as RichTextLabel

@onready var minimap = $top/minimap as TextureRect
var minimap_range = 65 as int
var world_scale: Vector3
var maximap: Image
var last_player_pos := Vector3i.ZERO

@onready var stam_bar = $bottom/stam/stam_bar as TextureProgressBar
@onready var stam_loss_bar = $bottom/stam/stam_loss_bar as TextureProgressBar
var last_stam: float = 0
@onready var health_bar = $bottom/health/health_bar as TextureProgressBar
@onready var health_loss_bar = $bottom/health/health_loss_bar as TextureProgressBar
var last_health: float = 0

@onready var clock_display = $top/left/dials/clock/clock_progress as TextureRect
@onready var compass_face = $top/left/dials/compass/compass_progress as TextureRect
var target_rotation: float = 0.0
var angular_velocity: float = 0.0

var DUKE = TheDuke
var ARCHIVIST = TheArchivist



func _ready():
	DUKE.tick.connect(update_time_display) 
	DUKE.message_dispatch.connect(recieve_message)
	DUKE.command_dispatch.connect(recieve_orders)

func _process(delta): 
	command_window()
	update_minimap_display()
	
	if last_stam > stam_bar.value: pass
	elif stam_loss_bar.value > stam_bar.value:
		stam_loss_bar.value = lerp(stam_loss_bar.value, stam_bar.value, 10*delta)
	else: stam_loss_bar.value = stam_bar.value
	last_stam = stam_bar.value
	
	
	if health_loss_bar.value > health_bar.value:
		health_loss_bar.value = lerp(health_loss_bar.value, health_bar.value, 1*delta)
	else: health_loss_bar.value = health_bar.value
	last_health = health_bar.value

func _physics_process(delta): update_compass_display(delta)

func set_health(amount: float): health_bar.value = amount
func set_stam(amount: float): stam_bar.value = amount
func set_bar_max(health_max:float, stam_max: float):
	health_bar.max_value = health_max
	stam_bar.max_value = stam_max
	stam_loss_bar.max_value = stam_max
func get_bar_max()->Vector2: return Vector2(health_bar.max_value,stam_bar.max_value)

func set_full_minimap(map: Image, ws: Vector3): 
	maximap = map
	world_scale = ws
	var subset_rect := Rect2i(Vector2i.ZERO,Vector2i(2*(minimap_range),2*minimap_range))
	minimap.texture = ImageTexture.create_from_image(maximap.get_region(subset_rect))


func recieve_message(message: Dictionary):
	if message.has("error"): prepend_output_text(message)
	elif message.has("command_name"): prepend_output_text("executed /"+str(message["command_name"])+" with "+str(message["options"]))

func recieve_orders(orders: Dictionary):
	if orders.command_name == "run": pass
	elif orders.command_name == "help": COMMAND_help(orders.options)
	elif orders.command_name == "clear": COMMAND_clear(orders.options)


func update_time_display(TIME: Vector4i):
	var hour = str(TIME[HOUR] if TIME[HOUR] else 12)  
	var minute = str(TIME[MINUTE]).pad_zeros(2)
	var period = "PM" if TIME[PERIOD] else "AM" 
	left_container.find_child("time_display").text = hour + ":" + minute + " " + period
	left_container.find_child("day_display").text = "day: " + str(TIME[DAY]) 
	
	hour = 12 - TIME[HOUR] + TIME[PERIOD]*12 
	minute = TIME[MINUTE]
	clock_display.rotation_degrees = hour*(360/24) - minute*(15.0/60.0)
	

func update_compass_display(delta):
	var damping_factor = 0.975
	var spring_strength: float = 5.0 
	
	var diff = target_rotation - compass_face.rotation
	var acceleration = spring_strength * diff
	
	angular_velocity += acceleration * delta
	angular_velocity *= damping_factor
	compass_face.rotation += angular_velocity * delta
	
	if abs(diff) < 0.001 and abs(angular_velocity) < 0.001:
		compass_face.rotation = target_rotation
		angular_velocity = 0.0

func update_minimap_display():
	minimap.rotation = lerp(minimap.rotation, target_rotation, 7.5*get_process_delta_time())
	var player_pos := Vector3i(get_parent().get_global_position()/world_scale)
	if player_pos != last_player_pos:
		last_player_pos = player_pos
		
		var clear_color := Color(0,0,0,0)
		var base_color := Color(0,0,0,0.5)
		var minimap_border_color := Color.DARK_GOLDENROD
		var player_color := Color.AQUA
		var player_border_color := Color.WEB_GRAY
		
		var minimap_boarder_thickness: int = 3
		var player_icon_size: int = 2

		var rect_pos := Vector2i(player_pos.x - minimap_range, player_pos.z - minimap_range) 
		var rect_size := Vector2i(2*(minimap_range),2*minimap_range)
		
		#var subset_rect := Rect2i(rect_pos,rect_size)
		var subset_img := Image.create(rect_size.x, rect_size.y, false, Image.FORMAT_RGBA8)
		for x in rect_size.x:
			for y in rect_size.y:
				var pixel_pos = Vector2(x, y)
				var distance = pixel_pos.distance_to(Vector2(minimap_range, minimap_range))
				var c: Color = base_color

				
				if distance < player_icon_size: c = player_color
				elif distance < player_icon_size+1: c = player_border_color
				elif distance > minimap_range-minimap_boarder_thickness and distance < minimap_range: c = minimap_border_color
				elif distance < minimap_range: 
					if x+rect_pos.x < maximap.get_size().x and y+rect_pos.y < maximap.get_size().y and x+rect_pos.x >= 0 and y+rect_pos.y >= 0:
						c = maximap.get_pixel(x+rect_pos.x,y+rect_pos.y)
				else: c = clear_color
				subset_img.set_pixel(x,y,c)
		
		minimap.texture.update(subset_img) 
		minimap.pivot_offset = Vector2i((minimap.size.x+minimap_boarder_thickness)/2,(minimap.size.y+minimap_boarder_thickness)/2)

func update_minimap_display_fast():
	var player_pos := Vector3i(get_parent().get_global_position()/world_scale)
	#var minimap_boarder_thickness = 3
	if player_pos != last_player_pos:
		last_player_pos = player_pos
		var rect_pos := Vector2i(player_pos.x - minimap_range, player_pos.z - minimap_range) 
		var rect_size := Vector2i(2*(minimap_range),2*minimap_range)
		
		var subset_rect := Rect2i(rect_pos,rect_size)
		var subset_img: Image = maximap.get_region(subset_rect)

		var player_color := Color.AQUA
		var player_icon_size: int = 2
		subset_img.set_pixel(minimap_range,minimap_range, player_color)
		
		for x in range(-player_icon_size, player_icon_size+1):
			for y in range(-player_icon_size, player_icon_size+1):
				var pixel_pos = Vector2(minimap_range+x, minimap_range+y)
				var distance = pixel_pos.distance_to(Vector2(minimap_range, minimap_range))
				if distance < player_icon_size: subset_img.set_pixel(minimap_range+x,minimap_range+y, player_color)
				elif distance < player_icon_size+1: subset_img.set_pixel(minimap_range+x,minimap_range+y, Color.BLACK)
		
		minimap.texture.update(subset_img) #= new_minimap
		minimap.pivot_offset = Vector2i(minimap.size.x/2,minimap.size.y/2)


func rotate_compass(rot: float): target_rotation += rot

func prepend_output_text(message): output.text += "- "+str(message)+"\n\n"#+output.text

func command_window():
	if not command_zone.visible:
		if Input.is_action_just_pressed("DEV_command"):
			command_zone.visible = true
			#output.text = ""
			input_zone.grab_focus()
			#DUKE.pause_game()
	else:
		#all handling of the text itself is found in input_zone.gd
		if Input.is_action_just_pressed("esc"): # or Input.is_action_just_pressed("DEV_command"):
			command_zone.visible = false
			DUKE.pause_game(false)
		elif Input.is_action_just_pressed("submit"):
			var command = input_zone.text.strip_edges()
			DUKE.execute_command(command)


func COMMAND_help(options: Dictionary = {}):
	if not options.has("command"):
		var commands_array:Array[String] = []
		for command in ARCHIVIST.COMMANDS: commands_array.push_back(command)
		commands_array.sort()
		commands_array.reverse()
		
		for command in commands_array:
			var out_str = "= - "+command+" - = -\n| "+ ARCHIVIST.COMMANDS[command]["desc"]
			if options.has("verbose") or options.has("v"):
				out_str += "\n-- valid options --"
				for option in ARCHIVIST.COMMANDS[command]["accepted_options"]:
					out_str += "\n| -" + option
				out_str += "\n-- targets --"
				for target in ARCHIVIST.COMMANDS[command]["targets"]:
					out_str += "\n| " + target
				
			prepend_output_text(out_str)
		
		if options.has("verbose") or options.has("v"):
			var info_str = "=- COMMAND -=-\n|- VALID\n|- OPTIONS"
			prepend_output_text(info_str)
	else:
		for i in options["command"].size():
			var command = options["command"][i]
			if ARCHIVIST.COMMANDS.has(command):
				var command_options = ARCHIVIST.COMMANDS[command]["accepted_options"]
				var out_str = "= - "+command+" - = -\n| "+ ARCHIVIST.COMMANDS[command]["desc"]
				out_str += "\n-- valid options --"
				for option in command_options:
					out_str += "\n| -" + option + ": " + command_options[option]
				prepend_output_text(out_str)
			else: prepend_output_text("=- "+command+" -=-\n|- doesn't exist")

func COMMAND_clear(_options: Dictionary): output.text = ""


