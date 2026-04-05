extends SceneTree

func _initialize() -> void:
	var target_path := "res://scenes/girl.glb"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		target_path = args[0]

	var scene := load(target_path) as PackedScene
	if scene == null:
		push_error("Failed to load scene: %s" % target_path)
		quit(1)
		return

	var root_node := scene.instantiate()
	root.add_child(root_node)
	await process_frame
	print("SCENE|", target_path)
	_print_tree(root_node, 0)
	var anim_player := root_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		print("ANIMATIONS|", anim_player.get_animation_list())
	var skeleton := root_node.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		var names: Array[String] = []
		for bone_idx in skeleton.get_bone_count():
			names.append(skeleton.get_bone_name(bone_idx))
		print("BONES|", names)
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
