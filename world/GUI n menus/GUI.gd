extends Control
### WISHLIST ###
# [x] compasss
# [ ] cuter clock

enum {AM, PM}
enum {HOUR, MINUTE, PERIOD, DAY}

@onready var text_display = $time_zone/text as VBoxContainer
@onready var clock_display = $time_zone/clock/clock_progress as TextureRect
@onready var input = $command_zone/input_zone as TextEdit
@onready var command_zone = $command_zone as VBoxContainer
@onready var output = $command_zone/bottom_log/output_zone as RichTextLabel
var DUKE = TheDuke
var ARCHIVIST = TheArchivist

var COMMAND_HISTORY: Array[String] = []
var CH_pointer = -1
var your_input: String

func _ready():
	DUKE.tick.connect(update_display) 
	DUKE.message_dispatch.connect(recieve_message)
	DUKE.command_dispatch.connect(recieve_orders)


func recieve_message(message: Dictionary):
	if message.has("error"): prepend_output_text(message)
	elif message.has("command_name"): prepend_output_text("executed /"+str(message["command_name"])+" with "+str(message["options"]))

func recieve_orders(orders: Dictionary):
	if orders.command_name == "run": pass
	elif orders.command_name == "help": COMMAND_help(orders.options)

func _process(_delta):
	if not command_zone.visible:
		if Input.is_action_just_pressed("DEV_command"):
			command_zone.visible = true
			output.text = ""
			input.grab_focus()
			#DUKE.pause_game()
	else:
		if Input.is_action_just_pressed("DEV_command") or Input.is_action_just_pressed("submit"):
			if Input.is_action_just_pressed("DEV_command"): command_zone.visible = false; #DUKE.pause_game(false)
			var command = input.text.strip_edges()
			COMMAND_HISTORY.push_front(command)
			DUKE.execute_command(command)
			input.text = ""
			your_input = ""
			CH_pointer = -1
		if Input.is_action_just_pressed("look_up"):
			if CH_pointer == -1: your_input = input.text
			if CH_pointer < COMMAND_HISTORY.size()-1:
				CH_pointer += 1 
				input.text = COMMAND_HISTORY[CH_pointer]
		elif Input.is_action_just_pressed("look_down"):
			if CH_pointer >= 0:
				CH_pointer -= 1 
				input.text = your_input if CH_pointer == -1 else COMMAND_HISTORY[CH_pointer]


func update_display(TIME: Vector4i):
	var hour = str(TIME[HOUR] if TIME[HOUR] else 12)  
	var minute = str(TIME[MINUTE]).pad_zeros(2)
	var period = "PM" if TIME[PERIOD] else "AM" 
	text_display.get_child(0).text = hour + ":" + minute + " " + period
	text_display.get_child(1).text = "day: " + str(TIME[DAY]) 
	
	hour = 12 - TIME[HOUR] + TIME[PERIOD]*12 
	minute = TIME[MINUTE]
	clock_display.rotation_degrees = hour*(360/24) - minute*(15.0/60.0)

func prepend_output_text(message):
	output.text = "- "+str(message)+"\n\n"+output.text

func COMMAND_help(options: Dictionary = {}):
	if not options.has("command"):
		var commands_array:Array[String] = []
		for command in ARCHIVIST.COMMANDS: commands_array.push_back(command)
		commands_array.sort()
		commands_array.reverse()
		
		for command in commands_array:
			var str = "= - "+command+" - = -\n|- "+ ARCHIVIST.COMMANDS[command]["desc"]
			if options.has("verbose") or options.has("v"):
				for option in ARCHIVIST.COMMANDS[command]["accepted_options"]:
					str += "\n|- " + option
			prepend_output_text(str)
		
		if options.has("verbose") or options.has("v"):
			var info_str = "=- COMMAND -=-\n|- VALID\n|- OPTIONS"
			prepend_output_text(info_str)
	else:
		for i in options["command"].size():
			var command = options["command"][i]
			if ARCHIVIST.COMMANDS.has(command):
				var command_options = ARCHIVIST.COMMANDS[command]["accepted_options"]
				var str = "= - "+command+" - = -\n|- "+ ARCHIVIST.COMMANDS[command]["desc"]
				for option in command_options:
					str += "\n|- " + option + ": " + command_options[option]
				prepend_output_text(str)
			else: prepend_output_text("=- "+command+" -=-\n|- doesn't exist")
