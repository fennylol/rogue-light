extends Node3D

@onready var area = $tent/Area3D

func _ready(): area.body_entered.connect(handle_area_entered)

func handle_area_entered(body: Node3D):
	var gp = get_global_position()
	print("set spawn to: ", gp)
	if body.is_in_group("player") and body.get_spawn_point() != gp: body.set_spawn_point(gp)  

func _process(_delta): pass
