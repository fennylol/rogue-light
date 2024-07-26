extends Node3D

enum {AM, PM}
enum {HOUR, MINUTE, PERIOD, DAY}
var DUKE = TheDuke

@onready var smoke = $GPUParticles3D
@onready var fire_sprites = [$Sprite3D,$Sprite3D2] as Array[Sprite3D]
@onready var light = $OmniLight3D as OmniLight3D
@onready var tent = $Tent

func _ready():DUKE.tick.connect(update_time)

func _process(_delta):pass

func get_tent_position() -> Vector3: return tent.get_global_position()

func update_time(TIME: Vector4i):
	if TIME[PERIOD] == PM and TIME[HOUR] >= 6:
		smoke.set_emitting(false)
		for sprite in fire_sprites: sprite.visible = true
		light.light_energy = 1
	else: 
		smoke.set_emitting(true) 
		for sprite in fire_sprites: sprite.visible = false
		light.light_energy = 0





