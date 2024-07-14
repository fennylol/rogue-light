extends Node

static func add_mesh_to_library(path_to_library: String, path_to_mesh: String, mesh_name: String):
	var LIB = load(path_to_library)
	var index = LIB.get_item_list().size()
	
	LIB.create_item(index)
	LIB.set_item_name(index, mesh_name)
	LIB.set_item_mesh(index, load(path_to_mesh))
	LIB.set_item_shapes(index, [load(path_to_mesh).create_trimesh_shape(), Transform3D.IDENTITY])
	ResourceSaver.save(LIB, path_to_library)

static func add_mesh_to_library_shaded(path_to_library: String, path_to_mesh: String, mesh_name: String):
	var LIB = load(path_to_library)
	var index = LIB.get_item_list().size()
	var mesh = load(path_to_mesh) as Mesh
	
	var shader_material = ShaderMaterial.new() as ShaderMaterial
	shader_material.shader = preload("res://world/map/trees/tree_fade.gdshader")
	var texture = preload("res://world/map/trees/tall_pine.png")
	shader_material.set_shader_parameter("albedo_texture", texture)
	
	mesh.surface_set_material(0, shader_material)
	LIB.create_item(index)
	LIB.set_item_name(index, mesh_name)
	LIB.set_item_mesh(index,mesh)
	LIB.set_item_shapes(index, [load(path_to_mesh).create_trimesh_shape(), Transform3D.IDENTITY])
	ResourceSaver.save(mesh, path_to_mesh)
	ResourceSaver.save(LIB, path_to_library)
	
