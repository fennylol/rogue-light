extends Control
### WISHLIST ###
# compasss
# cuter clock



@onready var time_display = $time_display as Label

func _ready(): pass 
func _process(_delta): pass


func update_display(TIME):
	var hour = str(TIME[0] if TIME[0] else 12)  
	var minute = str(TIME[1]).pad_zeros(2)
	var period = "PM" if TIME[2] else "AM" 
	time_display.text = hour + ":" + minute + " " + period
