extends Node

enum TILE_NAMES {GRASS, STONE, WOOD}

const WORLD_TILES = {
	PILLARS = PILLARS_LIST,
	CUBES = CUBES_LIST
}

const PILLARS_LIST = [
	preload("res://world/map/blocks/grass_block.tscn"),
	preload("res://world/map/blocks/wood_block.tscn"),
	preload("res://world/map/blocks/stone_block.tscn")
]

const CUBES_LIST = [
	preload("res://world/map/blocks/grass_block_1m.tscn"),
	preload("res://world/map/blocks/wood_block_1m.tscn"),
	preload("res://world/map/blocks/stone_block_1m.tscn")
]
