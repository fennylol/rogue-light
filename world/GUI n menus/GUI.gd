extends Control
### WISHLIST ###
# [x] compasss
# [ ] cuter clock



@onready var text_display = $HBoxContainer/time_display as Label
@onready var clock_display = $HBoxContainer/clock/clock_progress as TextureRect


func _ready(): pass 
func _process(_delta): pass



func update_display(TIME):
	var hour = str(TIME[0] if TIME[0] else 12)  
	var minute = str(TIME[1]).pad_zeros(2)
	var period = "PM" if TIME[2] else "AM" 
	text_display.text = hour + ":" + minute + " " + period
	
	hour = 12 - TIME[0] + TIME[2]*12 
	minute = TIME[1]
	clock_display.rotation_degrees = hour*(360/24) - minute*(15.0/60.0)
