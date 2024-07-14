extends Node

enum TILE_NAMES {GRASS, STONE, WOOD, PATH, WATER, SNOW, TALL_PINE, AIR = -1}

const COMMANDS = {
	"run": {
		"accepted_options":[
			"func",
			"args",
			"target"
		]
	},
	"help": {
		"accepted_options": [
			"command",
			"verbose"
		]
	},
	"resetworld": {
		"accepted_options": [
			"position",
			"rotation",
			"scale"
		]
	},
	"settime": {
		"accepted_options": [
			"time"
		]
	},
	"pause": {
		"accepted_options": []
	}
	
}
