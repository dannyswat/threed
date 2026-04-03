@tool
extends Node3D

signal bullet_hit(position: Vector3)

const BULLET_SPEED := 30.0
const BULLET_RANGE := 40.0

func _ready() -> void:
	_build()

func _build() -> void:
	# Body
	_attach_box(Vector3(0.10, 0.07, 0.15), Vector3( 0.00, -0.02, -0.04), Color(0.15, 0.15, 0.15))
	# Barrel
	_attach_box(Vector3(0.05, 0.05, 0.18), Vector3( 0.00, -0.02, -0.18), Color(0.10, 0.10, 0.10))
	# Grip
	_attach_box(Vector3(0.07, 0.12, 0.06), Vector3( 0.00, -0.09,  0.01), Color(0.18, 0.18, 0.18))


func shoot(world: World3D, origin: Vector3, direction: Vector3, scene_tree_root: Node) -> void:
	var muzzle_pos := origin + direction * 0.3

	# Spawn bullet
	var bullet := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	bullet.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.2)
	mat.emission_energy_multiplier = 3.0
	bullet.material_override = mat
	bullet.global_position = muzzle_pos
	scene_tree_root.add_child(bullet)

	# Raycast to find hit point
	var space_state := world.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(muzzle_pos, muzzle_pos + direction * BULLET_RANGE)
	var result := space_state.intersect_ray(query)
	var target_pos := muzzle_pos + direction * BULLET_RANGE
	if result:
		target_pos = result["position"]

	# Animate bullet flying then remove; emit signal on hit
	var fly_time: float = muzzle_pos.distance_to(target_pos) / BULLET_SPEED
	var tween := scene_tree_root.create_tween()
	tween.tween_property(bullet, "global_position", target_pos, fly_time)
	tween.tween_callback(func() -> void:
		if result:
			bullet_hit.emit(target_pos)
		bullet.queue_free()
	)


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
