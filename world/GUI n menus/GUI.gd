extends Control

@onready var time_display = $time_display as Label

func _ready(): pass 
func _process(delta): pass


func update_display(TIME):
	var hour = str(TIME[0] if TIME[0] else 12)  
	var min = str(TIME[1]).pad_zeros(2)
	var period = "PM" if TIME[2] else "AM" 
	time_display.text = hour + ":" + min + " " + period
