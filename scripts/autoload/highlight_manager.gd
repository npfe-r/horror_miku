extends Node

const HIGHLIGHT_LAYER_BIT: int = 10

var _highlight_viewport: SubViewport = null
var _viewport_camera: Camera3D = null
var _composite_quad: MeshInstance3D = null
var _composite_material: ShaderMaterial = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_highlight_viewport()

func _setup_highlight_viewport() -> void:
	_highlight_viewport = SubViewport.new()
	_highlight_viewport.name = "HighlightViewport"
	_highlight_viewport.size = _get_viewport_size()
	_highlight_viewport.transparent_bg = true
	_highlight_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_highlight_viewport.disable_3d = false
	add_child(_highlight_viewport)

	_viewport_camera = Camera3D.new()
	_viewport_camera.name = "HighlightCamera"
	_viewport_camera.cull_mask = 1 << HIGHLIGHT_LAYER_BIT
	_viewport_camera.environment = null
	_highlight_viewport.add_child(_viewport_camera)

func get_highlight_layer_bit() -> int:
	return HIGHLIGHT_LAYER_BIT

func _process(_delta: float) -> void:
	if not _composite_quad:
		_try_setup_composite_quad()
	_sync_camera()

func _try_setup_composite_quad() -> void:
	var im := get_node_or_null("/root/InteractionManager")
	if not im:
		return
	var player := im.get_player() as PlayerController
	if not player:
		return
	var player_camera := player.camera as Camera3D
	if not player_camera:
		return
	_setup_composite_quad(player_camera)

func _setup_composite_quad(camera: Camera3D) -> void:
	_composite_quad = MeshInstance3D.new()
	_composite_quad.name = "HighlightCompositeQuad"
	_composite_quad.mesh = QuadMesh.new()
	_composite_quad.mesh.size = Vector2(2.0, 2.0)
	_composite_quad.extra_cull_margin = 16384
	_composite_quad.ignore_occlusion_culling = true

	_composite_material = ShaderMaterial.new()
	_composite_material.shader = load("res://resources/shaders/highlight_composite.gdshader")
	_composite_material.set_shader_parameter("highlighted_tex", _highlight_viewport.get_texture())
	_composite_quad.material_override = _composite_material
	_composite_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	camera.add_child(_composite_quad)

func _sync_camera() -> void:
	var im := get_node_or_null("/root/InteractionManager")
	if not im:
		return

	var player := im.get_player() as PlayerController
	if not player:
		return

	var player_camera := player.camera as Camera3D
	if not player_camera or not _viewport_camera:
		return

	_viewport_camera.global_transform = player_camera.global_transform
	_viewport_camera.fov = player_camera.fov
	_highlight_viewport.size = _get_viewport_size()

func _get_viewport_size() -> Vector2i:
	return get_tree().root.size
