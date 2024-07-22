extends Control
### WISHLIST ###
# [x] compasss
# [ ] cuter clock

enum {AM, PM}
enum {HOUR, MINUTE, PERIOD, DAY}

@onready var text_display = $time_zone/text as VBoxContainer
@onready var clock_display = $time_zone/clock/clock_progress as TextureRect

@onready var input_zone = $command_zone/input_zone as TextEdit
@onready var command_zone = $command_zone as VBoxContainer
@onready var output = $command_zone/bottom_log/output_zone as RichTextLabel

@onready var compass_face = $compass/compass_progress as TextureRect
var target_rotation: float = 0.0
var angular_velocity: float = 0.0

var DUKE = TheDuke
var ARCHIVIST = TheArchivist



func _ready():
	DUKE.tick.connect(update_time_display) 
	DUKE.message_dispatch.connect(recieve_message)
	DUKE.command_dispatch.connect(recieve_orders)

func _process(_delta): command_window()

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
	text_display.get_child(0).text = hour + ":" + minute + " " + period
	text_display.get_child(1).text = "day: " + str(TIME[DAY]) 
	
	hour = 12 - TIME[HOUR] + TIME[PERIOD]*12 
	minute = TIME[MINUTE]
	clock_display.rotation_degrees = hour*(360/24) - minute*(15.0/60.0)


func update_compass_display(delta):
	var damping_factor = 0.99
	var spring_strength: float = 10.0 
	
	var diff = target_rotation - compass_face.rotation
	var acceleration = spring_strength * diff
	
	angular_velocity += acceleration * delta
	angular_velocity *= damping_factor
	compass_face.rotation += angular_velocity * delta
	
	if abs(diff) < 0.001 and abs(angular_velocity) < 0.001:
		rotation = target_rotation
		angular_velocity = 0.0


func rotate_compass(rot: float): target_rotation += rot

func prepend_output_text(message): output.text = "- "+str(message)+"\n\n"+output.text


func command_window():
	if not command_zone.visible:
		if Input.is_action_just_pressed("DEV_command"):
			command_zone.visible = true
			#output.text = ""
			input_zone.grab_focus()
			#DUKE.pause_game()
	else:
		if Input.is_action_just_pressed("DEV_command") or Input.is_action_just_pressed("esc"):
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


