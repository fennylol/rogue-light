extends Node
### UNIMPIMENTED ###
var DUKE = TheDuke
var SHIPPING_SCHEDULE: Vector4i = Vector4i(13,14,0,0)
const SCHEDULE_LENGTH = 14
enum {AM, PM}
enum {HOUR, MINUTE, PERIOD, DAY}

func _init(): DUKE.tick.connect(schedule_shipments)
func _process(delta):pass


func schedule_shipments(TIME: Vector4i):
	var schedule_progress = TIME[DAY] % SCHEDULE_LENGTH
	if not schedule_progress and TIME[HOUR] == 6 and not TIME[MINUTE]:
		print("scheduling ")
		SHIPPING_SCHEDULE.x = randi_range(0,SCHEDULE_LENGTH)
		SHIPPING_SCHEDULE.y = randi_range(0,SCHEDULE_LENGTH-1)
		SHIPPING_SCHEDULE.z = randi_range(0, 1439)
		SHIPPING_SCHEDULE.w = randi_range(0, 1439)
		if SHIPPING_SCHEDULE.y >= SHIPPING_SCHEDULE.x: SHIPPING_SCHEDULE.y += 1
	if  ((schedule_progress == SHIPPING_SCHEDULE.x) and \
		(TIME[PERIOD]*720 + TIME[HOUR]*60 + TIME[MINUTE] == SHIPPING_SCHEDULE.z)) or \
		((schedule_progress == SHIPPING_SCHEDULE.y) and \
		(TIME[PERIOD]*720 + TIME[HOUR]*60 + TIME[MINUTE] == SHIPPING_SCHEDULE.w)):
			send_shipment()


func send_shipment(): print("A CARAVAN ENTERS THE FOREST")
