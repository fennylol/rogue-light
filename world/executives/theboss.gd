# the game manager. he owns the forest.
extends Node

### OTHER EXECS ###
const LIBRARIAN = preload("res://world/executives/thelibrarian.gd")
const COMMANDER = preload("res://world/executives/thecommander.gd")

var PAUSED = false

enum {AM, PM}
enum {HOUR, MINUTE, PERIOD, DAY}
var TIME = Vector4i(0, 0, PM, 0)
var time_since_tick = 0
var IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS = 1
var TICK_SPEEDS = {"DEFAULT" = 1, "WARP" = 1.0/500, "FROZEN" = 4092024}
signal tick(time: Vector3i)
signal command_dispatch(command: Dictionary)



func process_dev_inputs(_delta):
	if Input.is_action_just_pressed("DEV_refresh"): execute_command("/resetworld -position[true] -rotation[true] -scale[true]")
	if Input.is_action_just_pressed("DEV_time_warp"): change_world_tick_speed(TICK_SPEEDS["WARP"] if IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS != TICK_SPEEDS["WARP"] else TICK_SPEEDS["DEFAULT"] )
	if Input.is_action_just_pressed("DEV_time_freeze"): change_world_tick_speed(TICK_SPEEDS["FROZEN"] if IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS != TICK_SPEEDS["FROZEN"] else TICK_SPEEDS["DEFAULT"] )

func change_world_tick_speed(tick_length): IN_GAME_MINUTE_LENGTH_IN_REAL_WORLD_SECONDS = tick_length
func pause_game(state: bool = true): PAUSED = state

func _ready(): command_dispatch.connect(notify_dispatch)
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
	if parsed_command.has("error"): print("error: ", parsed_command["error"]); return
	command_dispatch.emit(parsed_command)


func notify_dispatch(orders: Dictionary):
	print("dispatching: ", orders)
	if orders.command_name == "settime": 
		TIME = Vector4i(int(orders.options["time"][0]),\
						int(orders.options["time"][1]),\
						int(orders.options["time"][2]),\
						int(orders.options["time"][3]))
