extends PathFollow3D

# this is for timing caravan sending. this is just for debug purposes dont let this stick around
var length = 20

var TIME_TO_COMPLETE: float
var DUKE = TheDuke
signal finished

static func init(ttc: float = 30.0):
	var new_caravan = load("res://entities/caravan/caravan.tscn").instantiate()
	new_caravan.TIME_TO_COMPLETE = ttc
	return new_caravan

func _process(delta): 
	if not DUKE.PAUSED: set_progress_ratio(get_progress_ratio()+delta/TIME_TO_COMPLETE)
	if progress_ratio == 1: 
		finished.emit()
		self.queue_free()
