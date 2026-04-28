class_name InventoryMenu
extends Control

signal menu_closed()

const SLOT_SIZE: int = 64
const SLOT_GAP: int = 8
const DEFAULT_ICON_PATH: String = "res://icon.svg"

@onready var grid_container: GridContainer = $Panel/MarginContainer/VBoxContainer/SlotsContainer/GridContainer
@onready var item_info_panel: PanelContainer = $Panel/MarginContainer/VBoxContainer/ItemInfoPanel
@onready var item_name_label: Label = $Panel/MarginContainer/VBoxContainer/ItemInfoPanel/MarginContainer/VBoxContainer/ItemName
@onready var item_type_label: Label = $Panel/MarginContainer/VBoxContainer/ItemInfoPanel/MarginContainer/VBoxContainer/ItemType
@onready var item_desc_label: Label = $Panel/MarginContainer/VBoxContainer/ItemInfoPanel/MarginContainer/VBoxContainer/ItemDesc
@onready var quick_bar_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/QuickBarContainer
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/CloseButton
@onready var drop_zone: Control = $DropZone

var player: PlayerController = null
var slot_controls: Array[Control] = []
var quick_bar_controls: Array[Control] = []
var selected_slot_index: int = -1

var dragged_item: Control = null
var dragged_from_index: int = -1
var dragged_from_quick_bar: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var default_icon: Texture2D = null

func _ready() -> void:
	visible = false
	_load_default_icon()
	_setup_ui()
	_connect_signals()

func _load_default_icon() -> void:
	if ResourceLoader.exists(DEFAULT_ICON_PATH):
		default_icon = load(DEFAULT_ICON_PATH) as Texture2D
	else:
		push_warning("默认图标文件不存在: " + DEFAULT_ICON_PATH)
		default_icon = null

func _setup_ui() -> void:
	_create_inventory_slots()
	_create_quick_bar_slots()
	_hide_item_info()

func _create_inventory_slots() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	
	slot_controls.clear()
	
	for i in range(Inventory.MAX_SLOTS):
		var slot: Control = _create_slot_panel(i, false)
		slot_controls.append(slot)
		grid_container.add_child(slot)

func _create_quick_bar_slots() -> void:
	for child in quick_bar_container.get_children():
		child.queue_free()
	
	quick_bar_controls.clear()
	
	for i in range(Inventory.QUICK_BAR_SIZE):
		var slot: Control = _create_slot_panel(i, true)
		quick_bar_controls.append(slot)
		quick_bar_container.add_child(slot)

func _create_slot_panel(slot_index: int, is_quick_bar: bool) -> Control:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.add_theme_constant_override("separation", 2)
	container.set_meta("slot_index", slot_index)
	container.set_meta("is_quick_bar", is_quick_bar)
	
	var panel := PanelContainer.new()
	panel.name = "SlotPanel"
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.add_child(panel)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.border_color = Color(0.3, 0.3, 0.3, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	
	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	margin.add_child(icon_rect)
	
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	name_label.offset_left = 4
	name_label.offset_bottom = -4
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.clip_text = true
	name_label.custom_minimum_size = Vector2(SLOT_SIZE - 28, 12)
	panel.add_child(name_label)
	
	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.offset_right = -4
	count_label.offset_bottom = -4
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	count_label.add_theme_constant_override("outline_size", 2)
	panel.add_child(count_label)
	
	if is_quick_bar:
		var key_label := Label.new()
		key_label.name = "KeyLabel"
		key_label.text = str(slot_index + 1)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		container.add_child(key_label)
	
	container.gui_input.connect(_on_slot_gui_input.bind(container))
	
	return container

func _connect_signals() -> void:
	close_button.pressed.connect(_on_close_button_pressed)

func set_player(p: PlayerController) -> void:
	player = p
	if player and player.inventory:
		player.inventory.inventory_changed.connect(_update_display)
		player.inventory.selected_slot_changed.connect(_update_quick_bar_selection)
		_update_display()
		_update_quick_bar_selection(player.inventory.selected_quick_slot)

func toggle() -> void:
	visible = not visible
	if visible:
		_open_menu()
	else:
		_close_menu()

func open() -> void:
	visible = true
	_open_menu()

func close() -> void:
	visible = false
	_close_menu()

func _open_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	selected_slot_index = -1
	_hide_item_info()
	_update_display()
	if player and player.inventory:
		_update_quick_bar_selection(player.inventory.selected_quick_slot)

func _close_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	selected_slot_index = -1
	_cancel_drag()
	emit_signal("menu_closed")

func _update_display() -> void:
	if not player or not player.inventory:
		return
	
	for i in range(slot_controls.size()):
		_update_slot_display(slot_controls[i], i, false)
	
	for i in range(quick_bar_controls.size()):
		_update_slot_display(quick_bar_controls[i], i, true)

func _update_slot_display(container: Control, slot_index: int, is_quick_bar: bool) -> void:
	var panel: PanelContainer = container.find_child("SlotPanel") as PanelContainer
	if not panel:
		return
	
	var icon_rect: TextureRect = panel.find_child("Icon") as TextureRect
	var count_label: Label = panel.find_child("CountLabel") as Label
	var name_label: Label = panel.find_child("NameLabel") as Label
	
	if not icon_rect or not count_label or not name_label:
		return
	
	var actual_slot: ItemSlot = null
	
	if is_quick_bar:
		if player.inventory.quick_bar[slot_index] >= 0:
			actual_slot = player.inventory.get_slot(player.inventory.quick_bar[slot_index])
	else:
		actual_slot = player.inventory.get_slot(slot_index)
	
	if actual_slot and not actual_slot.is_empty():
		if actual_slot.item_data.icon:
			icon_rect.texture = actual_slot.item_data.icon
		else:
			icon_rect.texture = default_icon
		count_label.text = str(actual_slot.count) if actual_slot.count > 1 else ""
		name_label.text = actual_slot.item_data.item_name
	else:
		icon_rect.texture = null
		count_label.text = ""
		name_label.text = ""

func _update_quick_bar_selection(index: int) -> void:
	for i in range(quick_bar_controls.size()):
		var container: Control = quick_bar_controls[i]
		var panel: PanelContainer = container.find_child("SlotPanel") as PanelContainer
		if not panel:
			continue
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			if i == index:
				style.border_color = Color(0.3, 0.7, 0.4, 1)
				style.set_border_width_all(3)
			else:
				style.border_color = Color(0.3, 0.3, 0.3, 1)
				style.set_border_width_all(2)

func _on_slot_gui_input(event: InputEvent, container: Control) -> void:
	var slot_index: int = container.get_meta("slot_index")
	var is_quick_bar: bool = container.get_meta("is_quick_bar")
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(container, slot_index, is_quick_bar)
			else:
				_end_drag(container, slot_index, is_quick_bar)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_on_slot_right_click(slot_index, is_quick_bar)

func _start_drag(container: Control, slot_index: int, is_quick_bar: bool) -> void:
	if not player or not player.inventory:
		return
	
	var panel: PanelContainer = container.find_child("SlotPanel") as PanelContainer
	if not panel:
		return
	
	var actual_slot: ItemSlot = null
	if is_quick_bar:
		var inv_index: int = player.inventory.quick_bar[slot_index]
		if inv_index >= 0:
			actual_slot = player.inventory.get_slot(inv_index)
	else:
		actual_slot = player.inventory.get_slot(slot_index)
	
	if not actual_slot or actual_slot.is_empty():
		return
	
	dragged_from_index = slot_index
	dragged_from_quick_bar = is_quick_bar
	
	var icon_rect: TextureRect = panel.find_child("Icon") as TextureRect
	if not icon_rect:
		return
	
	dragged_item = Control.new()
	dragged_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dragged_item.custom_minimum_size = Vector2(48, 48)
	dragged_item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dragged_item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var drag_icon := TextureRect.new()
	drag_icon.texture = icon_rect.texture
	drag_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_icon.custom_minimum_size = Vector2(48, 48)
	dragged_item.add_child(drag_icon)
	
	var drag_count := Label.new()
	drag_count.text = str(actual_slot.count) if actual_slot.count > 1 else ""
	drag_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	drag_count.add_theme_font_size_override("font_size", 12)
	drag_count.add_theme_color_override("font_color", Color.WHITE)
	drag_count.add_theme_color_override("font_outline_color", Color.BLACK)
	drag_count.add_theme_constant_override("outline_size", 2)
	dragged_item.add_child(drag_count)
	
	add_child(dragged_item)
	dragged_item.global_position = get_global_mouse_position() - Vector2(24, 24)
	drag_offset = Vector2(24, 24)
	
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = Color(0.1, 0.1, 0.1, 0.5)

func _end_drag(_container: Control, _slot_index: int, _is_quick_bar: bool) -> void:
	if not dragged_item:
		return
	
	var drop_pos: Vector2 = get_global_mouse_position()
	
	var dropped_on_slot: bool = false
	for i in range(slot_controls.size()):
		var target: Control = slot_controls[i]
		if target.get_global_rect().has_point(drop_pos):
			_handle_drop_on_slot(i, false)
			dropped_on_slot = true
			break
	
	if not dropped_on_slot:
		for i in range(quick_bar_controls.size()):
			var target: Control = quick_bar_controls[i]
			if target.get_global_rect().has_point(drop_pos):
				_handle_drop_on_slot(i, true)
				dropped_on_slot = true
				break
	
	if not dropped_on_slot and drop_zone and drop_zone.get_global_rect().has_point(drop_pos):
		_handle_drop_outside()
	
	_cancel_drag()

func _handle_drop_on_slot(target_index: int, target_is_quick_bar: bool) -> void:
	if not player or not player.inventory:
		return
	
	if dragged_from_quick_bar:
		if target_is_quick_bar:
			var from_inv_index: int = player.inventory.quick_bar[dragged_from_index]
			var to_inv_index: int = player.inventory.quick_bar[target_index]
			player.inventory.quick_bar[dragged_from_index] = to_inv_index
			player.inventory.quick_bar[target_index] = from_inv_index
			player.inventory.emit_signal("quick_bar_changed", dragged_from_index)
			player.inventory.emit_signal("quick_bar_changed", target_index)
		else:
			var from_inv_index: int = player.inventory.quick_bar[dragged_from_index]
			if from_inv_index >= 0:
				player.inventory.move_slot(from_inv_index, target_index)
				player.inventory.quick_bar[dragged_from_index] = target_index
				player.inventory.emit_signal("quick_bar_changed", dragged_from_index)
	else:
		if target_is_quick_bar:
			player.inventory.quick_bar[target_index] = dragged_from_index
			player.inventory.emit_signal("quick_bar_changed", target_index)
		else:
			player.inventory.move_slot(dragged_from_index, target_index)

func _handle_drop_outside() -> void:
	if not player or not player.inventory:
		return
	
	var actual_index: int = dragged_from_index
	if dragged_from_quick_bar:
		actual_index = player.inventory.quick_bar[dragged_from_index]
		if actual_index < 0:
			return
	
	var drop_data: Dictionary = player.inventory.drop_item(actual_index)
	if drop_data.is_empty():
		return
	
	print("[背包] 丢弃物品: %s x%d" % [drop_data.item.item_name, drop_data.count])

func _cancel_drag() -> void:
	if dragged_item:
		dragged_item.queue_free()
		dragged_item = null
	
	if dragged_from_index >= 0:
		var container: Control
		if dragged_from_quick_bar:
			container = quick_bar_controls[dragged_from_index]
		else:
			container = slot_controls[dragged_from_index]
		
		if container:
			var panel: PanelContainer = container.find_child("SlotPanel") as PanelContainer
			if panel:
				var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
				if style:
					style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	
	dragged_from_index = -1
	dragged_from_quick_bar = false

func _on_slot_right_click(slot_index: int, is_quick_bar: bool) -> void:
	if not player or not player.inventory:
		return
	
	var actual_index: int = slot_index
	if is_quick_bar:
		actual_index = player.inventory.quick_bar[slot_index]
		if actual_index < 0:
			return
	
	var slot: ItemSlot = player.inventory.get_slot(actual_index)
	if not slot or slot.is_empty():
		return
	
	player.inventory.use_item(actual_index, player)

func _process(_delta: float) -> void:
	if dragged_item:
		dragged_item.global_position = get_global_mouse_position() - drag_offset

func _show_item_info(index: int) -> void:
	if not player or not player.inventory:
		return
	
	var slot: ItemSlot = player.inventory.get_slot(index)
	if not slot or slot.is_empty():
		_hide_item_info()
		return
	
	var item: ItemData = slot.item_data
	item_name_label.text = item.item_name
	item_type_label.text = item.get_type_name()
	item_desc_label.text = item.description
	item_info_panel.visible = true

func _hide_item_info() -> void:
	item_name_label.text = ""
	item_type_label.text = ""
	item_desc_label.text = ""
	item_info_panel.visible = false

func _on_close_button_pressed() -> void:
	close()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
