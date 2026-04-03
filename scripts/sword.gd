@tool
extends Node3D

var area: Area3D

func _ready() -> void:
	_build()

func _build() -> void:
	# Grip
	_attach_box(Vector3(0.04, 0.12, 0.04), Vector3( 0.00,  0.06,  0.00), Color(0.45, 0.30, 0.18))
	# Guard
	_attach_box(Vector3(0.18, 0.03, 0.04), Vector3( 0.00, -0.07,  0.00), Color(0.45, 0.46, 0.50))
	# Blade
	_attach_box(Vector3(0.03, 0.55, 0.02), Vector3( 0.00, -0.30,  0.00), Color(0.82, 0.85, 0.90))

	# Collision area for hit detection
	area = Area3D.new()
	area.name = "SwordArea"
	add_child(area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.04, 0.60, 0.03)
	collision.shape = shape
	area.add_child(collision)


func get_overlapping_bodies() -> Array:
	if area == null:
		return []
	return area.get_overlapping_bodies()


func get_area_position() -> Vector3:
	if area == null:
		return global_position
	return area.global_position


func _attach_box(size: Vector3, offset: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mi.material_override = mat
	add_child(mi)
