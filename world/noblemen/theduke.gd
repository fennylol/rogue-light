# the game manager. he owns the forest.
extends Node

### OTHER EXECS ###
const COMMANDER = preload("res://world/noblemen/thecommander.gd")

var PAUSED = false

enum {AM, PM}
enum {HOUR, MINUTE, PERIOD, DAY}
var TIME = Vector4i(5, 59, AM, -1)
var time_since_tick = 0
var IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS = 1
var TICK_SPEEDS = {"DEFAULT" = 1, "WARP" = 1.0/500, "FROZEN" = 4092024}
signal tick(time: Vector3i)
signal message_dispatch(message: Dictionary)
signal command_dispatch(command: Dictionary)



func process_dev_inputs(_delta):
	if Input.is_action_just_pressed("DEV_refresh"): execute_command("/resetworld -position[true] -rotation[true] -scale[true]")
	if Input.is_action_just_pressed("DEV_time_warp"): change_world_tick_speed(TICK_SPEEDS["WARP"] if IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS != TICK_SPEEDS["WARP"] else TICK_SPEEDS["DEFAULT"] )
	if Input.is_action_just_pressed("DEV_time_freeze"): change_world_tick_speed(TICK_SPEEDS["FROZEN"] if IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS != TICK_SPEEDS["FROZEN"] else TICK_SPEEDS["DEFAULT"] )

func change_world_tick_speed(tick_length): 
	IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS = tick_length
	time_since_tick = 0

func pause_game(state: bool = true): PAUSED = state

func _ready(): 
	command_dispatch.connect(order_self)
	time_since_tick = IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS

func _process(delta):
	process_dev_inputs(delta)
	
	if PAUSED: return
	time_since_tick += delta
	if time_since_tick > IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS: 
		time_since_tick -= IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS
		send_world_tick()


func send_world_tick():
	TIME[MINUTE] = (TIME[MINUTE] + 1) % 60
	if not TIME[MINUTE]: TIME[HOUR] = ((TIME[HOUR] + 1) % 12)
	if not (TIME[HOUR] or TIME[MINUTE]): TIME[PERIOD] = (TIME[PERIOD] + 1) % 2
	if TIME[HOUR] == 6 and not (TIME[MINUTE] or TIME[PERIOD]): TIME[DAY] += 1
	tick.emit(TIME)


func execute_command(input: String = "/help"):
	var parsed_command = COMMANDER.parse_command_string(input)
	message_dispatch.emit(parsed_command)
	if not parsed_command.has("error"): command_dispatch.emit(parsed_command)


func order_self(orders: Dictionary):
	print("BOSS dispatching: ", orders)
	if orders.command_name == "settime": COMMAND_settime(orders.options)
	if orders.command_name == "pause": pause_game(not PAUSED)

func COMMAND_settime(options: Dictionary):
	if options.has("time"):
		if options["time"].size()==4:
			TIME = Vector4i(int(options["time"][0]),\
								int(options["time"][1]),\
								int(options["time"][2]),\
								int(options["time"][3]))
		elif options["time"].size()==3:
			TIME = Vector4i(int(options["time"][0]),\
								int(options["time"][1]),\
								int(options["time"][2]),\
								TIME.w)
	else:
		if options.has("h"): TIME[HOUR] = clamp(int(options["h"][0]), 0, 11)
		if options.has("m"): TIME[MINUTE] = clamp(int(options["m"][0]), 0, 59)
		if options.has("p"): TIME[PERIOD] = clamp(int(options["p"][0]), 0, 1)
		if options.has("d"): TIME[DAY] = max(int(options["d"][0]), 0)



