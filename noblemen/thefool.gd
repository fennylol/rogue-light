extends Node

var DUKE = TheDuke
var rng := RandomNumberGenerator.new()
var STARTER_SEED: int = Time.get_unix_time_from_system()

func _ready():
	set_seed(STARTER_SEED)
	DUKE.command_dispatch.connect(recieve_orders)

func set_seed(new_seed: int): rng.seed = new_seed
func rand_i(): return rng.randi()
func rand_f(): return rng.randf()
func range_i(from: int, to: int): return rng.randi_range(from, to)
func range_f(from: float, to: float): return rng.randf_range(from, to)
func function(mean: float, std: float): return rng.randfn(mean, std)


func recieve_orders(orders: Dictionary):
	if orders.command_name == "seed": COMMAND_seed(orders.options)


func COMMAND_seed(options: Dictionary):
	if options.size() == 0: print("improper usage")
	if options.has("set"):
		if options["set"].size()>0: set_seed(int(options["set"][0]))
		else : set_seed(Time.get_unix_time_from_system())
	if options.has("get"): print("/seed -set[", rng.seed,"]")
