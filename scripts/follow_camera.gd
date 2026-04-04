extends Node3D

@export var target_path: NodePath
@export var follow_distance := 5.0
@export var follow_distance_indoor := 1.5
@export var pitch_degrees := 30.0
@export var look_height := 0.9
@export var smoothing := 7.0
@export var yaw_speed_degrees := 110.0
@export var pitch_speed_degrees := 75.0
@export var min_pitch_degrees := 15.0
@export var max_pitch_degrees := 65.0

# House bounds for indoor detection
const HOUSE_SIZE := Vector3(16.0, 100.0, 14.0)  # x, y (ignored), z
const HOUSE_CENTER := Vector3(0.0, 0.0, 0.0)

var target: Node3D
var transparent_materials: Dictionary = {}  # Track original materials for restoration
var camera_yaw_offset := 0.0

func _ready() -> void:
	set_as_top_level(true)
	target = get_node_or_null(target_path) as Node3D
	if target != null:
		global_position = _get_desired_position(follow_distance)
		look_at(target.global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)

func _is_indoors(position: Vector3) -> bool:
	var half_size := HOUSE_SIZE * 0.5
	var relative_pos := position - HOUSE_CENTER
	return abs(relative_pos.x) < half_size.x and abs(relative_pos.z) < half_size.z

func _physics_process(delta: float) -> void:
	if target == null:
		target = get_node_or_null(target_path) as Node3D
		if target == null:
			return

	_update_camera_input(delta)

	# Determine camera distance based on indoor/outdoor status
	var current_distance := follow_distance_indoor if _is_indoors(target.global_position) else follow_distance

	var desired_position := _get_desired_position(current_distance)
	var weight := 1.0 - exp(-smoothing * delta)
	global_position = global_position.lerp(desired_position, weight)
	look_at(target.global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)
	
	# Check for walls blocking camera view and make them transparent
	_update_wall_transparency()


func _update_camera_input(delta: float) -> void:
	var yaw_input := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		yaw_input += 1.0
	if Input.is_physical_key_pressed(KEY_D):
		yaw_input -= 1.0
	camera_yaw_offset += deg_to_rad(yaw_input * yaw_speed_degrees * delta)

	var pitch_input := 0.0
	if Input.is_physical_key_pressed(KEY_W):
		pitch_input += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		pitch_input -= 1.0
	pitch_degrees = clamp(
		pitch_degrees + pitch_input * pitch_speed_degrees * delta,
		min_pitch_degrees,
		max_pitch_degrees
	)


func _get_desired_position(current_distance: float) -> Vector3:
	var pitch_radians := deg_to_rad(pitch_degrees)
	var horizontal_distance := current_distance * cos(pitch_radians)
	var vertical_offset := current_distance * sin(pitch_radians)
	var local_offset := Basis(Vector3.UP, camera_yaw_offset) * Vector3(0.0, 0.0, horizontal_distance)
	var world_offset := target.global_transform.basis * local_offset
	return target.global_position + world_offset + Vector3.UP * vertical_offset


func _update_wall_transparency() -> void:
	if target == null:
		return
	
	# Reset previously transparent materials
	for material_key in transparent_materials.keys():
		var data = transparent_materials[material_key]
		var material = data["material"]
		material.transparency = StandardMaterial3D.TRANSPARENCY_DISABLED
	transparent_materials.clear()
	
	# Raycast from camera to player to detect blocking walls
	var camera_pos = global_position
	var player_pos = target.global_position + Vector3(0.0, look_height, 0.0)
	var direction = (player_pos - camera_pos).normalized()
	var distance = camera_pos.distance_to(player_pos)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera_pos, player_pos)
	query.hit_back_faces = true
	
	var result = space_state.intersect_ray(query)
	
	# Check all hits along the ray (not just the first one)
	while result and result.has("position"):
		var collider = result.get("collider")
		
		# Skip the player and player's parts
		if collider and collider != target and not collider.is_ancestor_of(target) and target.is_ancestor_of(collider) == false:
			_make_material_transparent(collider)
		
		# Move ray start past this collision to find other blocking objects
		camera_pos = result["position"] + direction * 0.01
		query = PhysicsRayQueryParameters3D.create(camera_pos, player_pos)
		query.hit_back_faces = true
		result = space_state.intersect_ray(query)


func _make_material_transparent(collider: Node) -> void:
	# Get the MeshInstance3D from the collider or its children
	var mesh_instances = []
	
	if collider is MeshInstance3D:
		mesh_instances.append(collider)
	elif collider is Node3D:
		# Search for MeshInstance3D children
		for child in collider.find_children("*", "MeshInstance3D"):
			mesh_instances.append(child)
	
	for mesh_inst in mesh_instances:
		if mesh_inst.material_override != null:
			var mat = mesh_inst.material_override
			var mat_key = str(mesh_inst.get_instance_id())
			
			if mat is StandardMaterial3D:
				# Store original material state
				if not transparent_materials.has(mat_key):
					transparent_materials[mat_key] = {
						"material": mat,
						"original_alpha": mat.albedo_color.a
					}
				
				# Make transparent
				var color = mat.albedo_color
				color.a = 0.5
				mat.albedo_color = color
				mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
