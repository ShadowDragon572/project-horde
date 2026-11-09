## Gives flat-shaded meshes smooth "outline directions" so a grown outline stays closed.
## Flat shading gives every face its own copy of each corner, each with its face's normal.
## Here, every copy of a corner gets the average of all those normals, stored in the vertex
## color. The outline shader pushes along that instead, so the copies move together.
## The real normals are untouched, so the lighting stays faceted.
class_name OutlineNormals

## Mesh -> processed mesh. Every drone shares the same few meshes, so each is only processed once.
static var _cache := {}


## Swaps every MeshInstance3D under `root` for a copy with outline directions baked in.
static func apply(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			mesh_instance.mesh = _get_outline_mesh(mesh_instance.mesh)


static func _get_outline_mesh(mesh: Mesh) -> Mesh:
	if _cache.has(mesh):
		return _cache[mesh]

	var result := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

		# Add up the normals of every copy of each corner. Snapping the position
		# makes copies that differ by a rounding error count as the same corner.
		var sums := {}
		for i in vertices.size():
			var key := vertices[i].snapped(Vector3.ONE * 0.0001)
			sums[key] = sums.get(key, Vector3.ZERO) + normals[i]

		# Store the averaged direction as a color. Colors only go 0 to 1 and
		# directions go -1 to 1, so squash it here and the shader unsquashes it.
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		for i in vertices.size():
			var dir: Vector3 = sums[vertices[i].snapped(Vector3.ONE * 0.0001)].normalized()
			colors[i] = Color(dir.x * 0.5 + 0.5, dir.y * 0.5 + 0.5, dir.z * 0.5 + 0.5, 0.0)

		arrays[Mesh.ARRAY_COLOR] = colors
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(surface, mesh.surface_get_material(surface))

	_cache[mesh] = result
	return result
