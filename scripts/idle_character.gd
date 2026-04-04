extends Node3D

@export var idle_animation := "NlaTrack.001"

func _ready() -> void:
	var anim_player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null:
		return

	var anim_name := idle_animation
	if not anim_player.has_animation(anim_name):
		anim_name = _find_shortest_animation(anim_player)
	if anim_name == "":
		return

	var animation := anim_player.get_animation(anim_name)
	if animation:
		animation.loop_mode = Animation.LOOP_LINEAR
	anim_player.play(anim_name)


func _find_shortest_animation(anim_player: AnimationPlayer) -> String:
	var best_name := ""
	var best_length := INF
	for anim_name in anim_player.get_animation_list():
		if anim_name == "RESET":
			continue
		var animation := anim_player.get_animation(anim_name)
		if animation and animation.length < best_length:
			best_name = anim_name
			best_length = animation.length
	return best_name
