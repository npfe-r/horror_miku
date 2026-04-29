@tool
extends Node3D

signal build_completed

const BW: float = 52.0
const BD: float = 32.0
const FH: float = 4.0
const WH: float = 3.2
const ST: float = 0.3
const WT: float = 0.2
const DW: float = 1.2
const DH: float = 2.4
const CW: float = 4.0

const FY: Array[float] = [0.0, 4.0, 8.0]
const SW: float = 2.0

var _mat_cache: Dictionary = {}
var _floor_count: int = 3

@export var auto_build: bool = true:
	set(val):
		auto_build = val
		if val and Engine.is_editor_hint():
			build_school()

@export var rebuild_btn: bool = false:
	set(val):
		if val and Engine.is_editor_hint():
			build_school()


func _mat(color: Color, metal: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
	var key = str(color) + str(metal) + str(rough)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	_mat_cache[key] = m
	return m


func _wall(pos: Vector3, size: Vector3, mat: StandardMaterial3D, parent: Node, node_name: String = "") -> void:
	var body = StaticBody3D.new()
	body.name = node_name if not node_name.is_empty() else "WallSegment"
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	var mi = MeshInstance3D.new()
	mi.name = "CollisionMesh"
	mi.layers = 1
	var mesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	body.add_child(mi)
	mi.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	var col = CollisionShape3D.new()
	col.name = "CollisionShape"
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	col.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self


func _floor_node(floor_idx: int) -> Node:
	for c in get_children():
		if c.name == "Floor" + str(floor_idx + 1):
			return c
	return self


func _create_floor(floor_idx: int) -> void:
	var fn = Node3D.new()
	fn.name = "Floor" + str(floor_idx + 1)
	add_child(fn)
	var owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	fn.owner = owner

	var y = FY[floor_idx]
	var slab_mat = _mat(Color(0.25, 0.25, 0.28), 0.0, 0.85)

	var slab = StaticBody3D.new()
	slab.name = "Slab"
	slab.position = Vector3(0, y, 0)
	slab.collision_layer = 1
	slab.collision_mask = 0
	fn.add_child(slab)
	slab.owner = owner

	var mi = MeshInstance3D.new()
	mi.name = "SlabMesh"
	mi.layers = 1
	var mesh = BoxMesh.new()
	mesh.size = Vector3(BW, ST, BD)
	mi.mesh = mesh
	mi.set_surface_override_material(0, slab_mat)
	slab.add_child(mi)
	mi.owner = owner

	var col = CollisionShape3D.new()
	col.name = "SlabShape"
	var shape = BoxShape3D.new()
	shape.size = Vector3(BW, ST, BD)
	col.shape = shape
	slab.add_child(col)
	col.owner = owner


func _create_exterior(floor_idx: int) -> void:
	var y = FY[floor_idx]
	var mat = _mat(Color(0.45, 0.4, 0.35), 0.0, 0.9)
	var wn = Node3D.new()
	wn.name = "ExteriorWalls"
	var parent = _floor_node(floor_idx)
	parent.add_child(wn)
	var owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	wn.owner = owner

	var hw = BW / 2.0
	var hd = BD / 2.0
	var wy = y + WH / 2.0

	_wall(Vector3(0, wy, -hd), Vector3(BW, WH, WT), mat, wn, "WallNorth")
	_wall(Vector3(0, wy, hd), Vector3(BW, WH, WT), mat, wn, "WallSouth")
	_wall(Vector3(-hw, wy, 0), Vector3(WT, WH, BD), mat, wn, "WallWest")
	_wall(Vector3(hw, wy, 0), Vector3(WT, WH, BD), mat, wn, "WallEast")


func _create_corridor_wall(parent: Node, wz: float, segments: Array, wall_mat: StandardMaterial3D, wall_y: float) -> void:
	for seg in segments:
		var x = seg[0]
		var w = seg[1]
		if w > 0.1:
			_wall(Vector3(x, wall_y, wz), Vector3(w, WH, WT), wall_mat, parent)


func _create_divider_wall(parent: Node, px: float, py: float, pz: float, len_z: float, door_z: float, mat: StandardMaterial3D) -> void:
	var z0 = pz - len_z / 2.0
	var z1 = pz + len_z / 2.0
	var dh = DW / 2.0

	var bot = door_z - dh - z0
	if bot > 0.1:
		_wall(Vector3(px, py, z0 + bot / 2.0), Vector3(WT, WH, bot), mat, parent)

	var top = z1 - (door_z + dh)
	if top > 0.1:
		_wall(Vector3(px, py, door_z + dh + top / 2.0), Vector3(WT, WH, top), mat, parent)

	var above = WH - DH
	if above > 0.1:
		_wall(Vector3(px, py + DH + above / 2.0, door_z), Vector3(WT, above, DW), mat, parent)


func _add_stairwell(parent: Node, wall_y: float, wall_mat: StandardMaterial3D) -> void:
	var sm = _mat(Color(0.4, 0.38, 0.35), 0.0, 0.85)
	var sx = -BW / 2.0 + 3.0
	var nz = -CW / 2.0
	var sz = CW / 2.0

	_wall(Vector3(sx - 3.0, wall_y, nz), Vector3(6.0, WH, WT), sm, parent, "StairwellNorth")
	_wall(Vector3(sx - 3.0, wall_y, sz), Vector3(6.0, WH, WT), sm, parent, "StairwellSouth")


func _build_floor1(parent: Node, wall_y: float, hw: float, hd: float) -> void:
	var im = _mat(Color(0.5, 0.48, 0.45), 0.0, 0.85)
	var cnz = -CW / 2.0 + WT / 2.0
	var csz = CW / 2.0 - WT / 2.0
	var nd = hd - CW / 2.0
	var sd = hd - CW / 2.0
	var stair_end = -20.0

	# Corridor north wall (stairwell at X=-26 to -20, then Office at X=-14, Lobby opening at X=4-8)
	_create_corridor_wall(parent, cnz, [
		[stair_end + (-14 - DW/2 - stair_end) / 2.0, -14 - DW/2 - stair_end],
		[-14 + DW/2 + (-2 - (-14 + DW/2))/2, -2 - (-14 + DW/2)],
		[(2 + 4) / 2.0, 4 - 2],
		[(8 + hw) / 2.0, hw - 8]
	], im, wall_y)

	# Corridor south wall (stairwell at X=-26 to -20, Library at X=-10, Cafeteria at X=6)
	_create_corridor_wall(parent, csz, [
		[stair_end + (-10 - DW/2 - stair_end) / 2.0, -10 - DW/2 - stair_end],
		[-10 + DW/2 + (-2 - (-10 + DW/2))/2, -2 - (-10 + DW/2)],
		[(2 + 6 - DW/2) / 2.0, 6 - DW/2 - 2],
		[(6 + DW/2 + hw) / 2.0, hw - (6 + DW/2)]
	], im, wall_y)

	# Divider between Office and Lobby (X=-2, north)
	var nd_z = -hd + nd / 2.0
	_create_divider_wall(parent, -2.0, wall_y, nd_z, nd, nd_z, im)

	# Divider between Library and Cafeteria (X=-2, south)
	var sd_z = CW / 2.0 + sd / 2.0
	_create_divider_wall(parent, -2.0, wall_y, sd_z, sd, sd_z, im)

	# Cafeteria/Gym divider at X=14
	_create_divider_wall(parent, 14.0, wall_y, sd_z, sd, sd_z - 1.0, im)

	_add_stairwell(parent, wall_y, im)


func _build_floor2(parent: Node, wall_y: float, hw: float) -> void:
	var im = _mat(Color(0.52, 0.5, 0.48), 0.0, 0.85)
	var hd = BD / 2.0
	var cnz = -CW / 2.0 + WT / 2.0
	var csz = CW / 2.0 - WT / 2.0
	var nd = hd - CW / 2.0
	var sd = hd - CW / 2.0
	var stair_end = -20.0

	# Corridor north wall: stairwell at X=-26 to -20, doors at X=-12 (Class A) and X=10 (Class B)
	_create_corridor_wall(parent, cnz, [
		[stair_end + (-12 - DW/2 - stair_end) / 2.0, -12 - DW/2 - stair_end],
		[-12 + DW/2 + (-2 - (-12 + DW/2))/2, -2 - (-12 + DW/2)],
		[(2 + 10 - DW/2) / 2.0, 10 - DW/2 - 2],
		[(10 + DW/2 + hw) / 2.0, hw - (10 + DW/2)]
	], im, wall_y)

	# Corridor south wall: doors at X=-12 (Class C) and X=10 (Class D)
	_create_corridor_wall(parent, csz, [
		[stair_end + (-12 - DW/2 - stair_end) / 2.0, -12 - DW/2 - stair_end],
		[-12 + DW/2 + (-2 - (-12 + DW/2))/2, -2 - (-12 + DW/2)],
		[(2 + 10 - DW/2) / 2.0, 10 - DW/2 - 2],
		[(10 + DW/2 + hw) / 2.0, hw - (10 + DW/2)]
	], im, wall_y)

	# Divider A/B at X=-2 (north)
	var nd_z = -hd + nd / 2.0
	_create_divider_wall(parent, -2.0, wall_y, nd_z, nd, nd_z, im)

	# Divider C/D at X=-2 (south)
	var sd_z = CW / 2.0 + sd / 2.0
	_create_divider_wall(parent, -2.0, wall_y, sd_z, sd, sd_z, im)

	_add_stairwell(parent, wall_y, im)


func _build_floor3(parent: Node, wall_y: float, hw: float) -> void:
	var im = _mat(Color(0.48, 0.45, 0.42), 0.0, 0.85)
	var hd = BD / 2.0
	var cnz = -CW / 2.0 + WT / 2.0
	var csz = CW / 2.0 - WT / 2.0
	var nd = hd - CW / 2.0
	var sd = hd - CW / 2.0
	var stair_end = -20.0

	# North wall: doors at X=-8 and X=10
	_create_corridor_wall(parent, cnz, [
		[stair_end + (-8 - DW/2 - stair_end) / 2.0, -8 - DW/2 - stair_end],
		[-8 + DW/2 + (-2 - (-8 + DW/2))/2, -2 - (-8 + DW/2)],
		[(2 + 10 - DW/2) / 2.0, 10 - DW/2 - 2],
		[(10 + DW/2 + hw) / 2.0, hw - (10 + DW/2)]
	], im, wall_y)

	# South wall: doors at X=-8 and X=10
	_create_corridor_wall(parent, csz, [
		[stair_end + (-8 - DW/2 - stair_end) / 2.0, -8 - DW/2 - stair_end],
		[-8 + DW/2 + (-2 - (-8 + DW/2))/2, -2 - (-8 + DW/2)],
		[(2 + 10 - DW/2) / 2.0, 10 - DW/2 - 2],
		[(10 + DW/2 + hw) / 2.0, hw - (10 + DW/2)]
	], im, wall_y)

	var nd_z = -hd + nd / 2.0
	_create_divider_wall(parent, -2.0, wall_y, nd_z, nd, nd_z, im)

	var sd_z = CW / 2.0 + sd / 2.0
	_create_divider_wall(parent, -2.0, wall_y, sd_z, sd, sd_z, im)

	_add_stairwell(parent, wall_y, im)


func _create_interior(floor_idx: int) -> void:
	var y = FY[floor_idx]
	var wn = Node3D.new()
	wn.name = "InteriorWalls"
	var parent = _floor_node(floor_idx)
	parent.add_child(wn)
	var owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	wn.owner = owner

	var wy = y + WH / 2.0
	var hw = BW / 2.0
	var hd = BD / 2.0

	match floor_idx:
		0: _build_floor1(wn, wy, hw, hd)
		1: _build_floor2(wn, wy, hw)
		_: _build_floor3(wn, wy, hw)


func _create_stairs() -> void:
	var sm = _mat(Color(0.55, 0.5, 0.45), 0.05, 0.7)
	var sn = Node3D.new()
	sn.name = "Stairs"
	add_child(sn)
	var owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	sn.owner = owner

	var sx = -BW / 2.0 + 3.0
	var sh = 0.2
	var sd = 0.35
	var spf = int(FH / sh)
	var ld = 2.0

	for fi in range(_floor_count - 1):
		var fy = FY[fi]
		var f1 = spf / 2
		for i in range(f1):
			var sy = fy + sh * (i + 1)
			var sz = -ld / 2.0 - sd * i
			_wall(Vector3(sx, sy + sh / 2.0, sz), Vector3(SW, sh, sd), sm, sn)

		var ly = fy + FH / 2.0
		_wall(Vector3(sx, ly, -ld / 2.0 - sd * f1 + 1.0), Vector3(SW, sh, 1.0), sm, sn)

		var f2 = spf / 2
		for i in range(f2):
			var sy = ly + sh * (i + 1)
			var sz = sd * (f2 - i)
			_wall(Vector3(sx, sy + sh / 2.0, sz), Vector3(SW, sh, sd), sm, sn)


func _create_ceiling(floor_idx: int) -> void:
	if floor_idx >= _floor_count - 1:
		return
	var cm = _mat(Color(0.35, 0.35, 0.38), 0.0, 0.9)
	var parent = _floor_node(floor_idx)

	var mi = MeshInstance3D.new()
	mi.name = "CeilingMesh"
	mi.layers = 1
	mi.position = Vector3(0, FH - ST, 0)
	var mesh = BoxMesh.new()
	mesh.size = Vector3(BW - 0.4, ST, BD - 0.4)
	mi.mesh = mesh
	mi.set_surface_override_material(0, cm)
	parent.add_child(mi)
	mi.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self


func _create_nav(floor_idx: int) -> void:
	var parent = _floor_node(floor_idx)
	var y = FY[floor_idx] + ST + 0.05

	var nav = NavigationRegion3D.new()
	nav.name = "Navigation"
	var nm = NavigationMesh.new()
	nm.agent_height = 1.8
	nm.agent_radius = 0.3
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 45.0
	nm.cell_height = 0.2
	nm.cell_size = 0.2
	nm.border_size = 0.5

	var hw = BW / 2.0 - 0.5
	var hd = BD / 2.0 - 0.5
	nm.vertices = PackedVector3Array([
		Vector3(-hw, y, -hd),
		Vector3(hw, y, -hd),
		Vector3(hw, y, hd),
		Vector3(-hw, y, hd)
	])
	nm.polygons = [PackedInt32Array([0, 1, 2, 3])]

	nav.navigation_mesh = nm
	parent.add_child(nav)
	nav.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self


func clear_school() -> void:
	for c in get_children():
		if c.name.begins_with("Floor"):
			remove_child(c)
			c.queue_free()
		if c.name == "Stairs":
			remove_child(c)
			c.queue_free()
	_mat_cache.clear()


func build_school() -> void:
	if not Engine.is_editor_hint():
		return

	clear_school()

	for i in range(_floor_count):
		_create_floor(i)
		_create_exterior(i)
		_create_interior(i)
		_create_ceiling(i)
		_create_nav(i)

	_create_stairs()

	print("School built: ", _floor_count, " floors")
	emit_signal("build_completed")


func _ready() -> void:
	if Engine.is_editor_hint() and auto_build:
		call_deferred("build_school")
