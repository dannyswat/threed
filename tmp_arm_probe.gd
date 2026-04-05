extends SceneTree

const MODEL_PATH := "res://scenes/girl.glb"
const ARM_BONES := ["L_Clavicle", "R_Clavicle", "L_Upperarm", "R_Upperarm", "L_Forearm", "R_Forearm", "L_Hand", "R_Hand"]
const HAND_BONES := {
	"L_Clavicle": "L_Hand",
	"R_Clavicle": "R_Hand",
	"L_Upperarm": "L_Hand",
	"R_Upperarm": "R_Hand",
	"L_Forearm": "L_Hand",
	"R_Forearm": "R_Hand",
	"L_Hand": "L_Hand",
	"R_Hand": "R_Hand"
}
const TEST_OFFSETS := {
	"y_pos": Vector3(0.0, 0.25, 0.0),
	"y_neg": Vector3(0.0, -0.25, 0.0),
	"z_pos": Vector3(0.0, 0.0, 0.25),
	"z_neg": Vector3(0.0, 0.0, -0.25)
}

func _initialize() -> void:
	var scene := load(MODEL_PATH) as PackedScene
	var root_node := scene.instantiate()
	root.add_child(root_node)
	await process_frame

	var skeleton := root_node.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		push_error("No Skeleton3D found")
		quit(1)
		return

	for bone_name in ARM_BONES:
		_probe_bone(skeleton, bone_name)
	quit()


func _probe_bone(skeleton: Skeleton3D, bone_name: String) -> void:
	var bone_idx := skeleton.find_bone(bone_name)
	var hand_name := String(HAND_BONES[bone_name])
	var hand_idx := skeleton.find_bone(hand_name)
	if bone_idx == -1 or hand_idx == -1:
		return

	var base_rotation := skeleton.get_bone_pose_rotation(bone_idx)
	var base_hand_origin := skeleton.get_bone_global_pose(hand_idx).origin
	print("BASE|", bone_name, "|hand=", hand_name, "|origin=", base_hand_origin)

	for label in TEST_OFFSETS.keys():
		var euler: Vector3 = TEST_OFFSETS[label]
		skeleton.set_bone_pose_rotation(bone_idx, base_rotation * Basis.from_euler(euler).get_rotation_quaternion())
		var moved_origin := skeleton.get_bone_global_pose(hand_idx).origin
		print("TEST|", bone_name, "|", label, "|delta=", moved_origin - base_hand_origin)
		skeleton.set_bone_pose_rotation(bone_idx, base_rotation)
