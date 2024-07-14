extends Control
### WISHLIST ###
# [x] compasss
# [ ] cuter clock

enum {AM, PM}
enum {HOUR, MINUTE, PERIOD, DAY}

@onready var text_display = $time_zone/time_display as Label
@onready var clock_display = $time_zone/clock/clock_progress as TextureRect
@onready var input = $command_zone/input_zone as TextEdit
@onready var command_zone = $command_zone as VBoxContainer
var BOSS = Theboss

func _ready(): BOSS.tick.connect(update_display) 
func _process(_delta):
	if not command_zone.visible:
		if Input.is_action_just_pressed("DEV_command"):
			command_zone.visible = true
			input.text = ""
			input.grab_focus()
			BOSS.pause_game()
	else:
		if Input.is_action_just_pressed("DEV_command") or Input.is_action_just_pressed("submit"):
			command_zone.visible = false
			var command = input.text.strip_edges()
			Theboss.execute_command(command)
			BOSS.pause_game(false)


func update_display(TIME: Vector4i):
	var hour = str(TIME[HOUR] if TIME[HOUR] else 12)  
	var minute = str(TIME[MINUTE]).pad_zeros(2)
	var period = "PM" if TIME[PERIOD] else "AM" 
	text_display.text = hour + ":" + minute + " " + period
	
	hour = 12 - TIME[HOUR] + TIME[PERIOD]*12 
	minute = TIME[MINUTE]
	clock_display.rotation_degrees = hour*(360/24) - minute*(15.0/60.0)
