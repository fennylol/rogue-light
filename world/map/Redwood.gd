extends MeshInstance3D


func _ready():
	# Create a new ShaderMaterial
	var shader_material = ShaderMaterial.new()
	
	# Load and set the shader
	shader_material.shader = preload("res://world/map/trees/tree_fade.gdshader")
	
	# Load the texture
	var texture = preload("res://RAW_RESOURCES/blends/redwood.png")
	
	# Set the texture in the shader material
	shader_material.set_shader_parameter("albedo_texture", texture)
	
	# Apply the shader material
	for i in range(0, 17):
		set_surface_override_material(i, shader_material)
