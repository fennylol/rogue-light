extends Control
### WISHLIST ###
# [x] compasss
# [ ] cuter clock

enum {AM, PM}
enum {HOUR, MINUTE, PERIOD, DAY}

@onready var left_container = $left as VBoxContainer
@onready var input_zone = $command_zone/input_zone as TextEdit
@onready var command_zone = $command_zone as VBoxContainer
@onready var output = $output_zone as RichTextLabel

@onready var stam_bar = $bars/stam/stam_bar as TextureProgressBar
@onready var stam_loss_bar = $bars/stam/stam_loss_bar as TextureProgressBar
var last_stam: float = 0
@onready var health_bar = $bars/health/health_bar as TextureProgressBar
@onready var health_loss_bar = $bars/health/health_loss_bar as TextureProgressBar
var last_health: float = 0

@onready var clock_display = $left/dials/clock/clock_progress as TextureRect
@onready var compass_face = $left/dials/compass/compass_progress as TextureRect
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
	left_container.find_child("time_display") .text = hour + ":" + minute + " " + period
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



func rotate_compass(rot: float): target_rotation += rot

func prepend_output_text(message): output.text += "- "+str(message)+"\n\n"#+output.text

func set_health(amount: float): health_bar.value = amount
func set_stam(amount: float): stam_bar.value = amount
func set_bar_max(health_max:float, stam_max: float):
	health_bar.max_value = health_max
	stam_bar.max_value = stam_max
	stam_loss_bar.max_value = stam_max
func get_bar_max()->Vector2: return Vector2(health_bar.max_value,stam_bar.max_value)

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


