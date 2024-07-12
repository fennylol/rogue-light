extends MeshInstance3D


func _ready():
	# Create a new ShaderMaterial
	var shader_material = ShaderMaterial.new() as ShaderMaterial
	shader_material.shader = preload("res://world/map/trees/tree_fade.gdshader")
	var texture = preload("res://world/map/trees/tall_pine.png")
	shader_material.set_shader_parameter("albedo_texture", texture)
	set_surface_override_material(0, shader_material)
