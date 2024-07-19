extends PathFollow3D

var TIME_TO_COMPLETE: float
var DUKE = TheDuke

static func init(ttc: float = 30.0):
	var new_caravan = load("res://entities/caravan/caravan.tscn").instantiate()
	new_caravan.TIME_TO_COMPLETE = ttc
	return new_caravan

func _process(delta): if not DUKE.PAUSED: set_progress_ratio(get_progress_ratio()+delta/TIME_TO_COMPLETE)
