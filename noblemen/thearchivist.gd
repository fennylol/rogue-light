extends Node

enum TILE_NAMES {
	AIR = -1,
	GRASS = 0, 
	STONE = 1, 
	WOOD = 2, 
	PATH = 3, 
	WATER = 4, 
	SNOW = 5, 
	TALL_PINE = 6, 
	WHITE = 7, 
	BLACK = 8, 
	}
const TILE_COLORS: Array[Color] = [
	Color(160,195,104,255), #GRASS
	Color(133,134,177,255), #STONE
	Color(148,114,106,255), #WOOD
	Color(188,185,99,255), #PATH
	Color(60,212,255,255), #WATER
	Color(160,188,244,255), #SNOW
	Color(0,0,0,255), #TALL_PINE
	Color(255,255,255,255), #WHITE
	Color(0,0,0,255), #BLACK
	] 

enum period {AM, PM}
enum time {HOUR, MINUTE, PERIOD, DAY}

const POINTS_OF_INTEREST = {
	"camp": {
		"size": 7,  
		"attempts": 30, 
		"road_spacing": 0, 
		"ground": "WOOD", 
		"scene": "res://points_of_interest/camp/camp.tscn"
	},
	
	"tent": {
		"size": 3,  
		"attempts": 10, 
		"POI_spacing": 20,
		"ground": "SNOW", 
		"scene": "res://points_of_interest/camp/tent.tscn"
	},
	
	"stalled_caravan": {
		"size": 10,
		"attempts": 1,
		"POI_spacing": 50,
		"road_spacing": 10,
		"scene": "res://entities/caravan/horts_and_wagon.tscn"
	},
	
	"the_sacred_one": {
		"attempts": 1,
		"size": 1,
		"road_spacing": 100, 
		"POI_spacing": 100
	}
}

const SAMPLE_POI = {
"": {
		"size": 0,
		"attempts": 0,
		"road_spacing": 0, 
		"POI_spacing": 0,
		"scene": "res://"
	}

	# size: the radius of the ground disk,
	# attempts: how many points to test for. high,
	# road_spacing: min dist from the road. if 0, will default to chunk_size. if not present, will use ground_disk size. 
	# POI_spacing: min_dist from other POIs.
	# scene: "res://"
	#}
}


const COMMANDS = {
	"run": {
		"accepted_options":{
			"func": "what function to call",
			"args": "an array of arguments to pass",
			"target": "what entity to target for running"
		},
		"desc": "!!! NOT IMPLEMENTED !!! AND DANGEROUS !!! this is literarally ACE the command. will probably never be implemented",
		"targets": ["NONE EVER (teehee)"]
	},
	
	"pause": {
		"accepted_options": {},
		"desc": "pause or unpause the game",
		"targets": ["theduke.gd"]
	},
	
	"resetworld": {
		"accepted_options": {
			"r": "FLAG - reset the rotation of the camera to face N",
			"s": "FLAG - reset the scale of camera to default"
		},
		"desc": "regenerate terrain and optionally reset camera parameters",
		"targets": ["world.gd"]
	},
	
	"settime": {
		"accepted_options": {
			"time": "in the format [H,M,P,D] each an integer value representing hour (0-11. 0 being 12), minute (0-59), period (0/AM - 1/PM) and day since world creation",
			"h": "set just the hour",
			"m": "set just the minute",
			"p": "set just the period",
			"d": "set just the day"
		},
		"desc": "set time of day to a desired value",
		"targets": ["theduke.gd"]
	},
	
	"setfade": {
		"accepted_options": {
			"begin": "how far past the object the player must be to begin fading. negative values begin fading when the object is still behind the player",
			"end": "how far past the object the player must be to be totally faded. setting this equal to begin will made objects fade instantly",
			"minalpha": "how faded objects when at maximum fade. 0.0 will make objects totally invisible while 1.0 will make them not fade at all"
		},
		"desc": "adjust foreground object fade",
		"targets": ["world.gd"]
	},
	
	"help": {
		"accepted_options": {
			"command": "an array of commands to have explained",
			"verbose": "FLAG - list options along with commands"
		},
		"desc": "list availible commands or how to use specific ones",
		"targets": ["GUI.gd"]
	},
	
	"seed": {
		"accepted_options":{
			"set": "seed to use for the global RNG",
			"get": "FLAG - get the current seed in use"
		},
		"desc": "feed the fool a seed.",
		"targets": ["thefool.gd"]
	},
	
	"clear": {
		"accepted_options":{
			"": "",
		},
		"desc": "clear GUI output",
		"targets": ["GUI.gd"]
	},
	
	"caravan": {
		"accepted_options":{
			"getschedule": "FLAG - get the shipping schedule",
			"send": "FLAG - send one..."
		},
		"desc": "send a caravan into the world. or retrieve the schedule",
		"targets": ["world.gd"]
	},
	
	"cam": {
		"accepted_options":{
			"o": "FLAG - o",
			"p": "FLAG - p",
			"f": "FLAG - f"
		},
		"desc": "camera",
		"targets": ["world.gd"]
	},
	
	"health": {
		"accepted_options":{
			"set": "sets health to specified value",
			"take": "reduces health by specified value. negative inputs will heal"
		},
		"desc": "manage player health",
		"targets": ["bandit.gd"]
	},
	
	"stam": {
		"accepted_options":{
			"set": "sets stam to specified value",
			"take": "reduces stam by specified value. negative inputs will heal"
		},
		"desc": "manage player stam",
		"targets": ["bandit.gd"]
	}
}

const sameple_command = {
"": {
		"accepted_options":{
			"": "",
		},
		"desc": "",
		"targets": []
	}
}
