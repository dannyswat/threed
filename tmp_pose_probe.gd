extends SceneTree

func _initialize() -> void:
	var scene := load("res://scenes/pajama girl.glb") as PackedScene
	var root_node := scene.instantiate()
	root.add_child(root_node)
	await process_frame
	_print_tree(root_node, 0)
	var skeleton := root_node.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		var names := ["Hip", "Pelvis", "L_Thigh", "L_ThighTwist01", "L_Calf", "L_Foot", "R_Thigh", "R_ThighTwist01", "R_Calf", "R_CalfTwist01", "R_CalfTwist02", "R_Foot"]
		for name in names:
			var idx := skeleton.find_bone(name)
			print("POSE|", name, "|IDX|", idx)
			if idx != -1:
				print("ROT|", skeleton.get_bone_pose_rotation(idx))
	quit()

func _print_tree(node: Node, depth: int) -> void:
	print("  ".repeat(depth) + node.name + " [" + node.get_class() + "]")
	for child in node.get_children():
		_print_tree(child, depth + 1)
