@tool
extends Node3D

const WALL_HEIGHT := 3.2
const WALL_THICKNESS := 0.2

var material_cache: Dictionary = {}
var generated_root: Node3D

func _ready() -> void:
	_rebuild_world()

func _rebuild_world() -> void:
	for child in get_children():
		child.free()

	material_cache.clear()
	generated_root = Node3D.new()
	generated_root.name = "GeneratedWorld"
	add_child(generated_root)
	_build_world()

func _build_world() -> void:
	_add_block("Ground", Vector3(34.0, 0.2, 34.0), Vector3(0.0, -0.2, 0.0), Color(0.33, 0.47, 0.3))
	_add_block("HouseFloor", Vector3(16.0, 0.2, 14.0), Vector3(0.0, -0.1, 0.0), Color(0.74, 0.67, 0.56))
	_add_block("Porch", Vector3(5.0, 0.16, 2.4), Vector3(0.0, -0.12, 8.0), Color(0.62, 0.55, 0.45))

	_build_outer_walls()
	_build_room_dividers()
	_build_furniture()
	_add_lights()

func _build_outer_walls() -> void:
	_add_block("BackWall", Vector3(16.0, WALL_HEIGHT, WALL_THICKNESS), Vector3(0.0, WALL_HEIGHT * 0.5, -6.9), Color(0.92, 0.89, 0.84))
	_add_block("LeftWall", Vector3(WALL_THICKNESS, WALL_HEIGHT, 14.0), Vector3(-7.9, WALL_HEIGHT * 0.5, 0.0), Color(0.92, 0.89, 0.84))
	_add_block("RightWall", Vector3(WALL_THICKNESS, WALL_HEIGHT, 14.0), Vector3(7.9, WALL_HEIGHT * 0.5, 0.0), Color(0.92, 0.89, 0.84))
	_add_block("FrontWallLeft", Vector3(6.2, WALL_HEIGHT, WALL_THICKNESS), Vector3(-4.9, WALL_HEIGHT * 0.5, 6.9), Color(0.92, 0.89, 0.84))
	_add_block("FrontWallRight", Vector3(6.2, WALL_HEIGHT, WALL_THICKNESS), Vector3(4.9, WALL_HEIGHT * 0.5, 6.9), Color(0.92, 0.89, 0.84))
	_add_block("DoorFrameLeft", Vector3(0.25, 2.5, 0.25), Vector3(-1.1, 1.25, 6.75), Color(0.49, 0.34, 0.24))
	_add_block("DoorFrameRight", Vector3(0.25, 2.5, 0.25), Vector3(1.1, 1.25, 6.75), Color(0.49, 0.34, 0.24))
	_add_block("DoorLintel", Vector3(2.45, 0.25, 0.25), Vector3(0.0, 2.55, 6.75), Color(0.49, 0.34, 0.24))

func _build_room_dividers() -> void:
	_add_block("DividerNorth", Vector3(7.0, WALL_HEIGHT, WALL_THICKNESS), Vector3(-4.5, WALL_HEIGHT * 0.5, -1.2), Color(0.88, 0.86, 0.82))
	_add_block("DividerSouthLeft", Vector3(WALL_THICKNESS, WALL_HEIGHT, 4.4), Vector3(2.2, WALL_HEIGHT * 0.5, -4.7), Color(0.88, 0.86, 0.82))
	_add_block("DividerSouthRight", Vector3(WALL_THICKNESS, WALL_HEIGHT, 4.1), Vector3(2.2, WALL_HEIGHT * 0.5, 2.3), Color(0.88, 0.86, 0.82))
	_add_block("BedroomDoorTop", Vector3(0.25, 0.25, 2.2), Vector3(2.2, 2.55, -1.1), Color(0.49, 0.34, 0.24))

func _build_furniture() -> void:
	_add_block("LivingRug", Vector3(4.4, 0.04, 2.8), Vector3(-3.4, 0.02, 2.3), Color(0.78, 0.29, 0.24))
	_add_block("SofaBase", Vector3(2.6, 0.5, 0.9), Vector3(-4.7, 0.25, 4.8), Color(0.29, 0.44, 0.54))
	_add_block("SofaBack", Vector3(2.6, 0.7, 0.2), Vector3(-4.7, 0.6, 5.25), Color(0.25, 0.38, 0.48))
	_add_block("CoffeeTable", Vector3(1.4, 0.35, 0.8), Vector3(-3.2, 0.175, 2.3), Color(0.47, 0.3, 0.2))
	_add_block("TVStand", Vector3(1.8, 0.5, 0.45), Vector3(-1.2, 0.25, 4.9), Color(0.32, 0.22, 0.18))
	_add_block("TV", Vector3(1.3, 0.8, 0.08), Vector3(-1.2, 1.0, 5.15), Color(0.08, 0.08, 0.1))

	_add_block("DiningTable", Vector3(1.8, 0.5, 1.1), Vector3(4.6, 0.25, 3.4), Color(0.58, 0.41, 0.28))
	_add_block("DiningBenchA", Vector3(1.6, 0.42, 0.35), Vector3(4.6, 0.21, 2.4), Color(0.41, 0.28, 0.19))
	_add_block("DiningBenchB", Vector3(1.6, 0.42, 0.35), Vector3(4.6, 0.21, 4.4), Color(0.41, 0.28, 0.19))
	_add_block("KitchenCounter", Vector3(4.2, 0.95, 0.8), Vector3(5.5, 0.475, 5.3), Color(0.73, 0.71, 0.69))
	_add_block("KitchenCabinet", Vector3(1.4, 1.8, 0.7), Vector3(6.7, 0.9, 3.9), Color(0.8, 0.79, 0.74))

	_add_block("BedroomRug", Vector3(3.3, 0.04, 2.5), Vector3(4.8, 0.02, -3.2), Color(0.27, 0.54, 0.43))
	_add_block("BedFrame", Vector3(3.1, 0.45, 2.1), Vector3(4.7, 0.225, -4.9), Color(0.47, 0.31, 0.21))
	_add_block("Mattress", Vector3(2.9, 0.28, 1.9), Vector3(4.7, 0.54, -4.9), Color(0.93, 0.93, 0.9))
	_add_block("PillowLeft", Vector3(0.7, 0.18, 0.45), Vector3(4.15, 0.74, -5.55), Color(0.95, 0.95, 0.96))
	_add_block("PillowRight", Vector3(0.7, 0.18, 0.45), Vector3(5.25, 0.74, -5.55), Color(0.95, 0.95, 0.96))
	_add_block("Wardrobe", Vector3(1.3, 2.2, 0.8), Vector3(6.8, 1.1, -2.0), Color(0.42, 0.28, 0.19))

	_add_block("BathroomCounter", Vector3(1.8, 0.9, 0.7), Vector3(-5.6, 0.45, -4.8), Color(0.72, 0.73, 0.76))
	_add_block("BathBlock", Vector3(2.4, 0.9, 1.2), Vector3(-4.6, 0.45, -2.8), Color(0.84, 0.87, 0.91))
	_add_block("Shelf", Vector3(0.35, 1.8, 1.2), Vector3(-1.2, 0.9, -4.6), Color(0.49, 0.34, 0.24))

func _add_lights() -> void:
	_add_omni_light("LivingLight", Vector3(-3.5, 2.5, 2.0), Color(1.0, 0.89, 0.76), 2.8, 10.0)
	_add_omni_light("KitchenLight", Vector3(4.8, 2.6, 3.8), Color(1.0, 0.93, 0.84), 2.4, 9.0)
	_add_omni_light("BedroomLight", Vector3(4.8, 2.6, -3.8), Color(1.0, 0.9, 0.82), 2.2, 8.0)
	_add_omni_light("BathroomLight", Vector3(-4.8, 2.4, -3.8), Color(0.92, 0.95, 1.0), 1.9, 7.0)

func _add_block(name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	generated_root.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _add_omni_light(name: String, position: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.name = name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = true
	generated_root.add_child(light)

func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if material_cache.has(key):
		return material_cache[key] as StandardMaterial3D

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	material_cache[key] = material
	return material
