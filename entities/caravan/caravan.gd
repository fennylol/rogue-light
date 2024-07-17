extends PathFollow3D

var TIME_TO_COMPLETE: float

static func init(ttc: float = 30.0):
	var new_caravan = load("res://entities/caravan/caravan.tscn").instantiate()
	new_caravan.TIME_TO_COMPLETE = ttc
	return new_caravan

func _process(delta): set_progress_ratio(get_progress_ratio()+delta/TIME_TO_COMPLETE)
