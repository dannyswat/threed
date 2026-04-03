@tool
extends CharacterBody3D

const SPEED := 4.8
const ACCELERATION := 14.0
const TURN_SPEED := 10.0
const WALK_CYCLE_SPEED := 8.0
const GRAVITY := 18.0

const C_SKIN  := Color(0.92, 0.78, 0.64)
const C_SHIRT := Color(0.25, 0.45, 0.70)
const C_PANTS := Color(0.22, 0.22, 0.34)
const C_SHOE  := Color(0.14, 0.11, 0.09)
const C_EYE   := Color(0.06, 0.06, 0.08)
const SWING_DURATION := 0.45
const SHOOT_DURATION := 0.35

const SWORD_SCENE := preload("res://scenes/Sword.tscn")
const GUN_SCENE   := preload("res://scenes/Gun.tscn")

@onready var visual_root: Node3D = $VisualRoot

var walk_cycle := 0.0
var joint_map: Dictionary = {}
var material_cache: Dictionary = {}
var swing_timer := 0.0
var hit_bodies_this_swing: Array = []
var holding_gun := false
var sword: Node3D
var gun: Node3D
var g_key_pressed_last_frame := false

func _ready() -> void:
	_rebuild_dummy_rig()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var input_vector := _get_move_input()
	var move_direction := _camera_relative_direction(input_vector)

	if move_direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, move_direction.x * SPEED, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, move_direction.z * SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCELERATION * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	move_and_slide()

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length() > 0.12:
		var facing_angle := atan2(horizontal_velocity.x, horizontal_velocity.z) - PI
		rotation.y = lerp_angle(rotation.y, facing_angle, TURN_SPEED * delta)

	if Input.is_physical_key_pressed(KEY_X) and swing_timer <= 0.0:
		swing_timer = SHOOT_DURATION if holding_gun else SWING_DURATION
		if holding_gun:
			_shoot_bullet()
		else:
			hit_bodies_this_swing.clear()
	if swing_timer > 0.0:
		swing_timer = max(0.0, swing_timer - delta)
		if not holding_gun:
			_check_sword_collisions()

	var g_pressed := Input.is_physical_key_pressed(KEY_G)
	if g_pressed and not g_key_pressed_last_frame:
		holding_gun = not holding_gun
		_update_weapon_visibility()
	g_key_pressed_last_frame = g_pressed

	_animate_rig(delta, horizontal_velocity.length())

func _get_move_input() -> Vector2:
	var left := _is_any_key_pressed([KEY_A, KEY_LEFT])
	var right := _is_any_key_pressed([KEY_D, KEY_RIGHT])
	var forward := _is_any_key_pressed([KEY_W, KEY_UP])
	var backward := _is_any_key_pressed([KEY_S, KEY_DOWN])

	var input_vector := Vector2(float(right - left), float(backward - forward))
	return input_vector.limit_length(1.0)

func _is_any_key_pressed(keys: Array[int]) -> int:
	for keycode in keys:
		if Input.is_physical_key_pressed(keycode):
			return 1
	return 0

func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector == Vector2.ZERO:
		return Vector3.ZERO

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_vector.x, 0.0, input_vector.y).normalized()

	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	return (right * input_vector.x + forward * -input_vector.y).normalized()

func _build_dummy_rig() -> void:
	# -----------------------------------------------------------------------
	# Pure Node3D joint hierarchy — no Skeleton3D, no BoneAttachment3D.
	# Transforms are set instantly in _ready(); no frame-delay.
	# Child joints inherit parent rotation automatically (standard FK).
	#
	# All positions are LOCAL to the parent node.
	# visual_root origin == CharacterBody3D origin == floor contact (y = 0).
	#
	# Absolute joint heights (for reference):
	#   ankle/foot  y = 0.08
	#   knee        y = 0.50
	#   hip joint   y = 0.93  (±0.10 x)
	#   hips centre y = 0.97
	#   spine       y = 1.10
	#   chest       y = 1.40  (shoulders ±0.22 x)
	#   neck base   y = 1.52
	#   head centre y = 1.67
	#   elbow       y = 1.12  (±0.22 x)
	#   wrist       y = 0.86  (±0.22 x)
	# -----------------------------------------------------------------------

	# Spine chain
	var hips   := _make_joint("hips",        visual_root, Vector3( 0.00,  0.97,  0.00))
	var spine  := _make_joint("spine",        hips,        Vector3( 0.00,  0.13,  0.00))
	var chest  := _make_joint("chest",        spine,       Vector3( 0.00,  0.30,  0.00))
	var neck   := _make_joint("neck",         chest,       Vector3( 0.00,  0.12,  0.00))
	var head_j := _make_joint("head",         neck,        Vector3( 0.00,  0.15,  0.00))

	# Arms (shoulders at chest level, hanging straight down)
	var uarm_l := _make_joint("upper_arm.L",  chest,       Vector3(-0.22,  0.00,  0.00))
	var larm_l := _make_joint("lower_arm.L",  uarm_l,      Vector3( 0.00, -0.28,  0.00))
	var hand_l := _make_joint("hand.L",       larm_l,      Vector3( 0.00, -0.26,  0.00))
	var uarm_r := _make_joint("upper_arm.R",  chest,       Vector3( 0.22,  0.00,  0.00))
	var larm_r := _make_joint("lower_arm.R",  uarm_r,      Vector3( 0.00, -0.28,  0.00))
	var hand_r := _make_joint("hand.R",       larm_r,      Vector3( 0.00, -0.26,  0.00))
	var sword_j := _make_joint("sword", hand_r, Vector3( 0.00, -0.12,  0.00))
	var gun_j   := _make_joint("gun",   hand_r, Vector3( 0.00, -0.05,  0.00))

	# Legs
	var uleg_l := _make_joint("upper_leg.L",  hips,        Vector3(-0.10, -0.04,  0.00))
	var lleg_l := _make_joint("lower_leg.L",  uleg_l,      Vector3( 0.00, -0.43,  0.00))
	var foot_l := _make_joint("foot.L",       lleg_l,      Vector3( 0.00, -0.42,  0.00))
	var uleg_r := _make_joint("upper_leg.R",  hips,        Vector3( 0.10, -0.04,  0.00))
	var lleg_r := _make_joint("lower_leg.R",  uleg_r,      Vector3( 0.00, -0.43,  0.00))
	var foot_r := _make_joint("foot.R",       lleg_r,      Vector3( 0.00, -0.42,  0.00))

	# -------------------------------------------------------------------
	# Meshes — each box offset by half the segment length so it is
	# centred between this joint and the next joint down the chain.
	# -------------------------------------------------------------------

	# Pelvis
	_attach_box(hips,   Vector3(0.28, 0.18, 0.20), Vector3( 0.00,  0.04,  0.00), C_PANTS)
	# Abdomen: spine(1.10)→chest(1.40), half = 0.15
	_attach_box(spine,  Vector3(0.28, 0.28, 0.19), Vector3( 0.00,  0.15,  0.00), C_SHIRT)
	# Chest block: chest(1.40)→neck(1.52), half = 0.06
	_attach_box(chest,  Vector3(0.38, 0.20, 0.22), Vector3( 0.00,  0.06,  0.00), C_SHIRT)
	# Neck: neck(1.52)→head(1.67), half = 0.075
	_attach_box(neck,   Vector3(0.11, 0.13, 0.11), Vector3( 0.00,  0.075, 0.00), C_SKIN)
	# Head sphere centred at joint + eyes
	_attach_sphere(head_j, 0.115, Vector3( 0.00,  0.00,  0.00), C_SKIN)
	_attach_box(head_j, Vector3(0.04, 0.03, 0.02), Vector3(-0.05,  0.04, -0.105), C_EYE)
	_attach_box(head_j, Vector3(0.04, 0.03, 0.02), Vector3( 0.05,  0.04, -0.105), C_EYE)

	# Upper arm: shoulder→elbow len=0.28, half=0.14
	_attach_box(uarm_l, Vector3(0.12, 0.26, 0.12), Vector3( 0.00, 0.00,  0.00), C_SHIRT)
	# Lower arm: elbow→wrist len=0.26, half=0.13
	_attach_box(larm_l, Vector3(0.10, 0.24, 0.10), Vector3( 0.00, 0.02,  0.00), C_SKIN)
	_attach_box(hand_l, Vector3(0.10, 0.09, 0.06), Vector3( 0.00, 0.04, 0.00), C_SKIN)
	_attach_box(uarm_r, Vector3(0.12, 0.26, 0.12), Vector3( 0.00, 0.00,  0.00), C_SHIRT)
	_attach_box(larm_r, Vector3(0.10, 0.24, 0.10), Vector3( 0.00, 0.02,  0.00), C_SKIN)
	_attach_box(hand_r, Vector3(0.10, 0.09, 0.06), Vector3( 0.00, 0.04, 0.00), C_SKIN)

	# Sword — instantiate from scene
	sword = SWORD_SCENE.instantiate()
	joint_map.get("sword").add_child(sword)

	# Gun — instantiate from scene, starts hidden
	gun = GUN_SCENE.instantiate()
	gun.visible = false
	gun.bullet_hit.connect(_create_spark)
	var gun_j_node := joint_map.get("gun") as Node3D
	gun_j_node.rotation.x = -PI / 2.0  # barrel (-Z) points down (-Y) to match hanging arm
	gun_j_node.add_child(gun)

	# Upper leg: hip-joint(0.93)→knee(0.50), len=0.43, half=0.215
	_attach_box(uleg_l, Vector3(0.17, 0.41, 0.17), Vector3( 0.00, -0.215, 0.00), C_PANTS)
	# Lower leg: knee(0.50)→ankle(0.08), len=0.42, half=0.21
	_attach_box(lleg_l, Vector3(0.13, 0.40, 0.13), Vector3( 0.00, -0.21,  0.00), C_PANTS)
	# Foot: ankle at y=0.08, shoe points forward (−Z)
	# Bottom of foot box: 0.08 − 0.04 − 0.04 = 0.00  (flush with floor)
	_attach_box(foot_l, Vector3(0.13, 0.08, 0.24), Vector3( 0.00, -0.04, -0.06), C_SHOE)
	_attach_box(uleg_r, Vector3(0.17, 0.41, 0.17), Vector3( 0.00, -0.215, 0.00), C_PANTS)
	_attach_box(lleg_r, Vector3(0.13, 0.40, 0.13), Vector3( 0.00, -0.21,  0.00), C_PANTS)
	_attach_box(foot_r, Vector3(0.13, 0.08, 0.24), Vector3( 0.00, -0.04, -0.06), C_SHOE)


func _rebuild_dummy_rig() -> void:
	if visual_root == null:
		return
	for child in visual_root.get_children():
		child.free()
	joint_map.clear()
	material_cache.clear()
	visual_root.position = Vector3.ZERO
	_build_dummy_rig()


func _make_joint(joint_name: String, parent: Node3D, local_pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = joint_name.replace(".", "_")
	node.position = local_pos
	parent.add_child(node)
	joint_map[joint_name] = node
	return node


func _attach_box(joint: Node3D, size: Vector3, offset: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = offset
	mi.material_override = _material(color)
	joint.add_child(mi)


func _attach_sphere(joint: Node3D, radius: float, offset: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.position = offset
	mi.material_override = _material(color)
	joint.add_child(mi)


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if material_cache.has(key):
		return material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	material_cache[key] = material
	return material


func _animate_rig(delta: float, horizontal_speed: float) -> void:
	if joint_map.is_empty():
		return

	var move_blend: float = clamp(horizontal_speed / SPEED, 0.0, 1.0)
	if move_blend > 0.05:
		walk_cycle += delta * WALK_CYCLE_SPEED * move_blend

	var idle_time: float = Time.get_ticks_msec() * 0.001
	var swing: float          = sin(walk_cycle) * 0.75 * move_blend
	var opposite_swing: float = sin(walk_cycle + PI) * 0.75 * move_blend
	var left_knee: float      = max(0.0, -swing) * 0.55
	var right_knee: float     = max(0.0, -opposite_swing) * 0.55
	var idle_breath: float    = sin(idle_time * 2.0) * 0.04 * (1.0 - move_blend)

	_set_joint_rotation("upper_leg.L", Vector3(swing, 0.0, 0.0))
	_set_joint_rotation("lower_leg.L", Vector3(left_knee, 0.0, 0.0))
	_set_joint_rotation("foot.L",      Vector3(-0.15 - swing * 0.25, 0.0, 0.0))
	_set_joint_rotation("upper_leg.R", Vector3(opposite_swing, 0.0, 0.0))
	_set_joint_rotation("lower_leg.R", Vector3(right_knee, 0.0, 0.0))
	_set_joint_rotation("foot.R",      Vector3(-0.15 - opposite_swing * 0.25, 0.0, 0.0))
	_set_joint_rotation("upper_arm.L", Vector3(opposite_swing * 0.85, 0.0, 0.0))
	_set_joint_rotation("lower_arm.L", Vector3(-0.15 - move_blend * 0.2, 0.0, 0.0))
	_set_joint_rotation("hand.L",      Vector3(-0.1, 0.0, 0.0))
	_set_joint_rotation("upper_arm.R", Vector3(swing * 0.85, 0.0, 0.0))
	_set_joint_rotation("lower_arm.R", Vector3(-0.15 - move_blend * 0.2, 0.0, 0.0))
	_set_joint_rotation("hand.R",      Vector3(-0.1, 0.0, 0.0))
	_set_joint_rotation("spine",       Vector3(-idle_breath * 0.5, 0.0, 0.0))
	_set_joint_rotation("chest",       Vector3(idle_breath + sin(walk_cycle + PI * 0.5) * 0.1 * move_blend, 0.0, 0.0))
	_set_joint_rotation("head",        Vector3(-idle_breath * 0.75, 0.0, 0.0))

	visual_root.position.y = abs(sin(walk_cycle * 2.0)) * 0.04 * move_blend

	# Sword swing — horizontal slash in front from right to left
	if swing_timer > 0.0 and not holding_gun:
		var t := 1.0 - (swing_timer / SWING_DURATION)
		var sweep: float = lerp(-0.8, 0.8, t)
		var bend: float  = lerp(0.7, 0.05, t)
		_set_joint_rotation("upper_arm.R", Vector3(1.1, sweep, 0.0))
		_set_joint_rotation("lower_arm.R", Vector3(bend, 0.0, 0.0))
		_set_joint_rotation("hand.R",      Vector3(-0.1, 0.0, 0.0))

	# Gun raise and shoot animation
	if swing_timer > 0.0 and holding_gun:
		var t := 1.0 - (swing_timer / SHOOT_DURATION)
		var raise: float = sin(t * PI)  # raises and lowers
		_set_joint_rotation("upper_arm.R", Vector3(raise * 1.4, 0.0, 0.0))
		_set_joint_rotation("lower_arm.R", Vector3(-raise * 0.1, 0.0, 0.0))
		_set_joint_rotation("hand.R",      Vector3(0.0, 0.0, 0.0))


func _set_joint_rotation(joint_name: String, euler_rotation: Vector3) -> void:
	var node := joint_map.get(joint_name) as Node3D
	if node == null:
		return
	node.rotation = euler_rotation


func _update_weapon_visibility() -> void:
	if sword:
		sword.visible = not holding_gun
	if gun:
		gun.visible = holding_gun


func _shoot_bullet() -> void:
	if gun == null:
		return
	var shoot_dir := -global_transform.basis.z
	var origin    := global_position + Vector3(0.0, 1.4, 0.0)
	gun.shoot(get_world_3d(), origin, shoot_dir, get_parent())


func _check_sword_collisions() -> void:
	if sword == null:
		return
	for body in sword.get_overlapping_bodies():
		if body != self and body not in hit_bodies_this_swing:
			hit_bodies_this_swing.append(body)
			_create_spark(sword.get_area_position())



func _create_spark(position: Vector3) -> void:
	# Create a quick particle effect using small rotating cubes
	var spark_container = Node3D.new()
	spark_container.global_position = position
	get_parent().add_child(spark_container)
	
	var spark_material := StandardMaterial3D.new()
	spark_material.albedo_color = Color(1.0, 0.85, 0.3)  # Orange/yellow
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.85, 0.3)
	spark_material.emission_energy_multiplier = 2.0
	
	# Create several small spark particles
	for i in range(6):
		var spark = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.1, 0.1, 0.1)
		spark.mesh = mesh
		spark.material_override = spark_material
		
		var angle = (TAU / 6.0) * i
		var direction = Vector3(cos(angle), randf_range(0.3, 0.8), sin(angle)).normalized()
		spark.position = direction * 0.1
		
		spark_container.add_child(spark)
		
		# Animate spark: move and fade
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", spark.position + direction * 0.5, 0.4)
		tween.tween_property(spark_material, "emission_energy_multiplier", 0.0, 0.4)
	
	# Remove the spark container after animation
	var remove_tween = create_tween()
	remove_tween.tween_callback(spark_container.queue_free).set_delay(0.5)
