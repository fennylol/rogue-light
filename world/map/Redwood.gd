extends MeshInstance3D


func _ready():
	var shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://world/map/trees/tree_fade.gdshader")
	var texture = preload("res://RAW_RESOURCES/blends/tall_pine.png")
	shader_material.set_shader_parameter("albedo_texture", texture)
	
	# Apply the shader material
	for i in range(0, 17):
		set_surface_override_material(i, shader_material)
