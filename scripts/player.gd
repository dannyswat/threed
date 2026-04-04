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
const RELAXED_CLAVICLE_Z := 0.18
const RELAXED_UPPERARM_Z := 0.80
const RELAXED_ARM_SPREAD_Y := 0.22
const RELAXED_FOREARM_X := 0.22
const RELAXED_FOREARM_Z := 0.1
const RELAXED_HAND_X := -0.12
const RELAXED_HAND_Z := 0.06
const WALK_LEG_INWARD_Z := 0.00
const WALK_THIGH_SWING := 0.52
const WALK_CALF_SWING := 0.22
const WALK_CALF_BEND := 0.9
const WALK_FOOT_SWING := 0.16
const WALK_HIP_BOB := 0.028
const DEBUG_MODEL_ANIMATION := true

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
var left_key_was_pressed := false
var right_key_was_pressed := false
var anim_player: AnimationPlayer = null
var model_skeleton: Skeleton3D = null
var bone_ids: Dictionary = {}
var base_bone_rotations: Dictionary = {}
var base_bone_positions: Dictionary = {}
var leg_bone_groups := {
	"left_thigh": [],
	"left_calf": [],
	"left_foot": [],
	"right_thigh": [],
	"right_calf": [],
	"right_foot": []
}
var idle_timer := 0.0
var imported_idle_anim := ""
var using_imported_idle := false
var last_debug_log_time := 0.0

const IDLE_ANIMATION_DELAY := 0.5
const IDLE_ANIMATION_CANDIDATES := ["NlpTrack.001", "NlpTrack_001", "NlaTrack.001", "NlaTrack_001"]

func _ready() -> void:
	_rebuild_dummy_rig()
	# Find the imported model animation and skeleton nodes.
	var model := visual_root.get_node_or_null("Model")
	if model:
		anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		model_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if anim_player:
		anim_player.stop()
		imported_idle_anim = _find_animation_name(IDLE_ANIMATION_CANDIDATES)
	if model_skeleton:
		_cache_model_bones()
		_animate_model(0.0, 0.0)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var forward_input := _get_forward_input()
	var is_walking := forward_input != 0.0
	var move_direction: Vector3
	if forward_input != 0.0:
		move_direction = -global_transform.basis.z * forward_input
	else:
		move_direction = Vector3.ZERO

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

	# Snap turn 45 degrees per key press
	var left_pressed := _is_any_key_pressed([KEY_LEFT]) != 0
	var right_pressed := _is_any_key_pressed([KEY_RIGHT]) != 0
	if left_pressed and not left_key_was_pressed:
		rotation.y += PI / 4.0
	if right_pressed and not right_key_was_pressed:
		rotation.y -= PI / 4.0
	left_key_was_pressed = left_pressed
	right_key_was_pressed = right_pressed

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

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	_animate_rig(delta, horizontal_velocity.length())
	_animate_model(delta, forward_input)

func _find_animation_name(candidates: Array) -> String:
	if anim_player == null:
		return ""
	for candidate in candidates:
		if anim_player.has_animation(candidate):
			return candidate
	return ""

func _cache_model_bones() -> void:
	var tracked_bones := [
		"Root",
		"Hip",
		"Pelvis",
		"Waist",
		"Spine01",
		"Spine02",
		"NeckTwist01",
		"Head",
		"L_Clavicle",
		"L_Thigh",
		"L_ThighTwist01",
		"L_Calf",
		"L_Foot",
		"L_Forearm",
		"L_Hand",
		"R_Clavicle",
		"R_Thigh",
		"R_ThighTwist01",
		"R_Calf",
		"R_CalfTwist01",
		"R_CalfTwist02",
		"R_Foot",
		"R_Forearm",
		"R_Hand",
		"L_Upperarm",
		"R_Upperarm"
	]
	for mesh in visual_root.find_children("*", "MeshInstance3D", true, false):
		var skin: Skin = mesh.skin
		if skin == null:
			continue
		for i in skin.get_bind_count():
			var bind_name := skin.get_bind_name(i)
			if bind_name != "" and bind_name not in tracked_bones:
				tracked_bones.append(bind_name)
	for bone_name in tracked_bones:
		var bone_idx: int = model_skeleton.find_bone(bone_name)
		if bone_idx == -1:
			continue
		bone_ids[bone_name] = bone_idx
		base_bone_rotations[bone_name] = model_skeleton.get_bone_pose_rotation(bone_idx)
		base_bone_positions[bone_name] = model_skeleton.get_bone_pose_position(bone_idx)
		_register_leg_bone_group(bone_name)

	if DEBUG_MODEL_ANIMATION:
		print("PLAYER_MODEL_BONES|cached=", bone_ids.keys())
		print("PLAYER_MODEL_LEG_GROUPS|", leg_bone_groups)


func _register_leg_bone_group(bone_name: String) -> void:
	if bone_name.begins_with("L_Thigh"):
		leg_bone_groups["left_thigh"].append(bone_name)
	elif bone_name.begins_with("L_Calf"):
		leg_bone_groups["left_calf"].append(bone_name)
	elif bone_name.begins_with("L_Foot"):
		leg_bone_groups["left_foot"].append(bone_name)
	elif bone_name.begins_with("R_Thigh"):
		leg_bone_groups["right_thigh"].append(bone_name)
	elif bone_name.begins_with("R_Calf"):
		leg_bone_groups["right_calf"].append(bone_name)
	elif bone_name.begins_with("R_Foot"):
		leg_bone_groups["right_foot"].append(bone_name)

func _animate_model(delta: float, forward_input: float) -> void:
	if model_skeleton == null or bone_ids.is_empty():
		return

	var move_blend: float = abs(forward_input)
	if move_blend > 0.0:
		idle_timer = 0.0
		if using_imported_idle:
			_stop_imported_idle()
	else:
		idle_timer += delta
		if imported_idle_anim != "" and idle_timer >= IDLE_ANIMATION_DELAY:
			if not using_imported_idle:
				_restore_model_pose()
				anim_player.play(imported_idle_anim)
				using_imported_idle = true
			return

	if move_blend > 0.0:
		walk_cycle += delta * WALK_CYCLE_SPEED * move_blend * sign(forward_input)

	var idle_time: float = Time.get_ticks_msec() * 0.001
	var idle_breath: float = sin(idle_time * 1.8) * 0.02 * (1.0 - move_blend)
	var swing: float = sin(walk_cycle) * WALK_THIGH_SWING * move_blend
	var opposite_swing: float = sin(walk_cycle + PI) * WALK_THIGH_SWING * move_blend
	var left_calf_phase: float = sin(walk_cycle - PI * 0.35) * WALK_CALF_SWING * move_blend
	var right_calf_phase: float = sin(walk_cycle + PI - PI * 0.35) * WALK_CALF_SWING * move_blend
	var left_knee: float = 0.05 * move_blend + left_calf_phase + max(0.0, -swing) * WALK_CALF_BEND
	var right_knee: float = 0.05 * move_blend + right_calf_phase + max(0.0, -opposite_swing) * WALK_CALF_BEND
	var hip_bob: float = abs(sin(walk_cycle * 2.0)) * WALK_HIP_BOB * move_blend
	var left_leg_inward_z: float = WALK_LEG_INWARD_Z * move_blend
	var right_leg_inward_z: float = -WALK_LEG_INWARD_Z * move_blend
	var torso_twist: float = sin(walk_cycle) * 0.08 * move_blend
	var left_clavicle_x: float = opposite_swing * 0.18
	var right_clavicle_x: float = swing * 0.18
	var left_upperarm_x: float = opposite_swing * 0.8 + 0.08
	var right_upperarm_x: float = swing * 0.8 + 0.08
	var left_forearm_x: float = RELAXED_FOREARM_X + max(0.0, -opposite_swing) * 0.35 + 0.08 * move_blend
	var right_forearm_x: float = RELAXED_FOREARM_X + max(0.0, -swing) * 0.35 + 0.08 * move_blend
	var left_hand_x: float = RELAXED_HAND_X + opposite_swing * 0.2
	var right_hand_x: float = RELAXED_HAND_X + swing * 0.2
	var left_visible_thigh: float = swing * 1.15
	var right_visible_thigh: float = opposite_swing * 1.15
	var left_visible_calf: float = left_knee * 1.1
	var right_visible_calf: float = right_knee * 1.1
	var left_foot_lift: float = -0.14 - swing * (WALK_FOOT_SWING * 1.5) - left_calf_phase * 0.5
	var right_foot_lift: float = -0.14 - opposite_swing * (WALK_FOOT_SWING * 1.5) - right_calf_phase * 0.5

	_set_bone_rotation("Root", Vector3(0.0, 0.0, 0.0))
	_set_bone_rotation("Hip", Vector3(0.03 * move_blend, 0.0, 0.0))
	_set_bone_position("Hip", Vector3(0.0, hip_bob, 0.0))
	_set_bone_rotation("Pelvis", Vector3(0.02 * move_blend, 0.0, 0.0))
	_set_bone_rotation("Waist", Vector3(-idle_breath, torso_twist * 0.3, 0.0))
	_set_bone_rotation("Spine01", Vector3(idle_breath + sin(walk_cycle + PI * 0.5) * 0.08 * move_blend, torso_twist, 0.0))
	_set_bone_rotation("Spine02", Vector3(idle_breath * 0.5, torso_twist * 0.65, 0.0))
	_set_bone_rotation("NeckTwist01", Vector3(-idle_breath * 0.5, 0.0, 0.0))
	_set_bone_rotation("Head", Vector3(-idle_breath * 0.8, 0.0, 0.0))

	_apply_leg_group_pose(leg_bone_groups["left_thigh"], left_visible_thigh, left_leg_inward_z)
	_apply_leg_group_pose(leg_bone_groups["left_calf"], left_visible_calf, 0.0)
	_apply_leg_group_pose(leg_bone_groups["left_foot"], left_foot_lift, -left_leg_inward_z * 0.5)
	_apply_leg_group_pose(leg_bone_groups["right_thigh"], right_visible_thigh, right_leg_inward_z)
	_apply_leg_group_pose(leg_bone_groups["right_calf"], right_visible_calf, 0.0)
	_apply_leg_group_pose(leg_bone_groups["right_foot"], right_foot_lift, -right_leg_inward_z * 0.5)
	_set_bone_rotation("L_Clavicle", Vector3(left_clavicle_x, -RELAXED_ARM_SPREAD_Y * 0.35, -RELAXED_CLAVICLE_Z))
	_set_bone_rotation("R_Clavicle", Vector3(right_clavicle_x, RELAXED_ARM_SPREAD_Y * 0.35, RELAXED_CLAVICLE_Z))
	_set_bone_rotation("L_Upperarm", Vector3(left_upperarm_x, -RELAXED_ARM_SPREAD_Y, -RELAXED_UPPERARM_Z))
	_set_bone_rotation("R_Upperarm", Vector3(right_upperarm_x, RELAXED_ARM_SPREAD_Y, RELAXED_UPPERARM_Z))
	_set_bone_rotation("L_Forearm", Vector3(left_forearm_x, -RELAXED_ARM_SPREAD_Y * 0.2, -RELAXED_FOREARM_Z))
	_set_bone_rotation("R_Forearm", Vector3(right_forearm_x, RELAXED_ARM_SPREAD_Y * 0.2, RELAXED_FOREARM_Z))
	_set_bone_rotation("L_Hand", Vector3(left_hand_x, 0.0, -RELAXED_HAND_Z))
	_set_bone_rotation("R_Hand", Vector3(right_hand_x, 0.0, RELAXED_HAND_Z))

	if DEBUG_MODEL_ANIMATION and move_blend > 0.0:
		var now := Time.get_ticks_msec() * 0.001
		if now - last_debug_log_time > 0.5:
			last_debug_log_time = now
			print(
				"PLAYER_WALK_DEBUG|blend=", move_blend,
				"|left_thigh=", leg_bone_groups["left_thigh"],
				"|left_calf=", leg_bone_groups["left_calf"],
				"|left_foot=", leg_bone_groups["left_foot"],
				"|right_thigh=", leg_bone_groups["right_thigh"],
				"|right_calf=", leg_bone_groups["right_calf"],
				"|right_foot=", leg_bone_groups["right_foot"]
			)


func _apply_leg_group_pose(bone_names: Array, x_rotation: float, z_rotation: float) -> void:
	for bone_name in bone_names:
		var scale := 1.0
		if "Twist02" in bone_name:
			scale = 0.75
		elif "Twist01" in bone_name:
			scale = 0.9
		_set_bone_rotation(bone_name, Vector3(x_rotation * scale, 0.0, z_rotation * scale))


func _stop_imported_idle() -> void:
	if anim_player:
		anim_player.stop()
	using_imported_idle = false
	_restore_model_pose()


func _restore_model_pose() -> void:
	for bone_name in bone_ids.keys():
		var bone_idx: int = int(bone_ids.get(bone_name, -1))
		if bone_idx == -1:
			continue
		var base_rotation: Quaternion = base_bone_rotations.get(bone_name, Quaternion.IDENTITY) as Quaternion
		var base_position: Vector3 = base_bone_positions.get(bone_name, Vector3.ZERO) as Vector3
		model_skeleton.set_bone_pose_rotation(bone_idx, base_rotation)
		model_skeleton.set_bone_pose_position(bone_idx, base_position)


func _set_bone_rotation(bone_name: String, euler_rotation: Vector3) -> void:
	var bone_idx: int = int(bone_ids.get(bone_name, -1))
	if bone_idx == -1:
		return
	var base_rotation: Quaternion = base_bone_rotations.get(bone_name, Quaternion.IDENTITY) as Quaternion
	var offset_rotation: Quaternion = Basis.from_euler(euler_rotation).get_rotation_quaternion()
	model_skeleton.set_bone_pose_rotation(bone_idx, base_rotation * offset_rotation)


func _set_bone_position(bone_name: String, position_offset: Vector3) -> void:
	var bone_idx: int = int(bone_ids.get(bone_name, -1))
	if bone_idx == -1:
		return
	var base_position: Vector3 = base_bone_positions.get(bone_name, Vector3.ZERO) as Vector3
	model_skeleton.set_bone_pose_position(bone_idx, base_position + position_offset)

func _get_forward_input() -> float:
	var forward := _is_any_key_pressed([KEY_UP])
	var backward := _is_any_key_pressed([KEY_DOWN])
	return float(forward - backward)

func _is_any_key_pressed(keys: Array[int]) -> int:
	for keycode in keys:
		if Input.is_physical_key_pressed(keycode):
			return 1
	return 0

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
	joint_map.clear()
	material_cache.clear()


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
