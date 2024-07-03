extends Thread
signal finished
var heightmap = []

func _init():
	pass # Replace with function body.

func get_heightmap():
	return heightmap

func _run(width: int, height: int, max_height: int, seed: int = randi(), frequency: float = 0.01, lacunarity: float = 2.0, gain: float = 0.25):
	var noise = FastNoiseLite.new()
	noise.set_seed(seed)
	noise.set_noise_type(FastNoiseLite.TYPE_PERLIN) 
	noise.set_frequency(frequency)
	noise.set_fractal_lacunarity(lacunarity)
	noise.set_fractal_gain(gain)
	
	heightmap = []
	for x in range(width):
		var row = []
		for y in range(height):
			var noise_value = noise.get_noise_2d(x, y)
			# Convert noise value (-1 to 1) to (0 to 1) range
			var t = (noise_value + 1) * 0.5
			# Discretize to 6 levels (0 to 5)
			var height_value = int(round(t * max_height))
			row.append(height_value)
		heightmap.append(row)
	finished.emit()
	return heightmap

