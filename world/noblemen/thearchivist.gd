extends Node

enum TILE_NAMES {GRASS, STONE, WOOD, PATH, WATER, SNOW, TALL_PINE, AIR = -1}

const COMMANDS = {
	"run": {
		"accepted_options":{
			"func": "what function to call",
			"args": "an array of arguments to pass",
			"target": "what entity to target for running"
		},
		"desc": "!!! NOT IMPLEMENTED !!! AND DANGEROUS !!! this is literarally ACE the command. will probably never be implemented"
	},
	"pause": {
		"accepted_options": {},
		"desc": "!!! NOT IMPLEMENTED !!! pause or unpause the game"
	},
	"resetworld": {
		"accepted_options": {
			"position": "FLAG - reset camera position to be centered on player",
			"rotation": "FLAG - reset the rotation of the camera to face N",
			"scale": "FLAG - reset the scale of camera to default"
		},
		"desc": "regenerate terrain and optionally reset camera parameters"
	},
	"settime": {
		"accepted_options": {
			"time": "in the format [H,M,P,D] each an integer value representing hour (0-11. 0 being 12), minute (0-59), period (0/AM - 1/PM) and day since world creation",
			"h": "set just the hour",
			"m": "set just the minute",
			"p": "set just the period",
			"d": "set just the day"
		},
		"desc": "set time of day to a desired value"
	},
	"setfade": {
		"accepted_options": {
			"begin": "how far past the object the player must be to begin fading. negative values begin fading when the object is still behind the player",
			"end": "how far past the object the player must be to be totally faded. setting this equal to begin will made objects fade instantly",
			"minalpha": "how faded objects when at maximum fade. 0.0 will make objects totally invisible while 1.0 will make them not fade at all"
		},
		"desc": "adjust foreground object fade"
	},
		"help": {
		"accepted_options": {
			"command": "an array of commands to have explained",
			"verbose": "FLAG - list options along with commands"
		},
		"desc": "list availible commands or how to use specific ones"
	}
}
