class_name PlayerHUD
extends Control

@onready var crosshair: Control = $Crosshair
@onready var interaction_label: Label = $InteractionLabel
@onready var stamina_bar_bg: ColorRect = $StaminaBarContainer/StaminaBarBg
@onready var stamina_bar_fill: ColorRect = $StaminaBarContainer/StaminaBarFill
@onready var equipped_item_label: Label = $EquippedItemContainer/EquippedItemLabel
@onready var quick_slots: Array[PanelContainer] = [
	$QuickBarContainer/QuickBarHBox/QuickSlot0,
	$QuickBarContainer/QuickBarHBox/QuickSlot1,
	$QuickBarContainer/QuickBarHBox/QuickSlot2,
	$QuickBarContainer/QuickBarHBox/QuickSlot3
]

var inventory_menu: InventoryMenu = null
var player: PlayerController = null

func _ready() -> void:
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.item_equipped.connect(_on_item_equipped)
	EventBus.item_unequipped.connect(_on_item_unequipped)
	
	resized.connect(_on_hud_resized)
	
	inventory_menu = get_node_or_null("InventoryMenu") as InventoryMenu
	print("[PlayerHUD] _ready: inventory_menu=%s" % inventory_menu)
	
	await get_tree().process_frame
	player = InteractionManager.get_player()
	if player:
		_on_stamina_changed(player.stamina)
		print("[PlayerHUD] 找到玩家, inventory_menu=%s" % inventory_menu)
		if inventory_menu:
			inventory_menu.set_player(player)
		else:
			push_warning("[PlayerHUD] inventory_menu is null!")
		
		if player.inventory:
			player.inventory.selected_slot_changed.connect(_on_selected_slot_changed)
			_update_quick_bar()
	else:
		push_warning("[PlayerHUD] 未找到玩家")
	if UIManager:
		UIManager.register_hud(self)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory_menu()
		get_viewport().set_input_as_handled()

func toggle_inventory_menu() -> void:
	if inventory_menu:
		inventory_menu.toggle()
		if crosshair:
			crosshair.visible = not inventory_menu.visible

func _on_stamina_changed(stamina: float) -> void:
	if stamina_bar_fill and stamina_bar_bg:
		var bar_width: float = stamina_bar_bg.size.x
		if bar_width > 0:
			var fill_ratio: float = clampf(stamina / 100.0, 0.0, 1.0)
			var fill_width: float = bar_width * fill_ratio
			stamina_bar_fill.offset_left = -fill_width / 2.0
			stamina_bar_fill.offset_right = fill_width / 2.0

			var t: float = clampf((stamina - 10.0) / 20.0, 0.0, 1.0)
			stamina_bar_fill.color = Color(1, t, t, 0.9)
		else:
			await get_tree().process_frame
			_on_stamina_changed(stamina)

func _on_hud_resized() -> void:
	if stamina_bar_fill and stamina_bar_bg:
		var bar_width: float = stamina_bar_bg.size.x
		if bar_width > 0 and player:
			var fill_ratio: float = clampf(player.stamina / 100.0, 0.0, 1.0)
			var fill_width: float = bar_width * fill_ratio
			stamina_bar_fill.offset_left = -fill_width / 2.0
			stamina_bar_fill.offset_right = fill_width / 2.0

			var t: float = clampf((player.stamina - 10.0) / 20.0, 0.0, 1.0)
			stamina_bar_fill.color = Color(1, t, t, 0.9)

func _on_interaction_prompt_changed(prompt_text: String) -> void:
	if interaction_label:
		if prompt_text.is_empty():
			interaction_label.visible = false
		else:
			interaction_label.text = "[E] " + prompt_text
			interaction_label.visible = true

func _on_inventory_changed() -> void:
	_update_quick_bar()

func _on_selected_slot_changed(slot_index: int) -> void:
	_highlight_selected_slot(slot_index)

func _on_item_equipped(item: ItemData) -> void:
	if equipped_item_label:
		equipped_item_label.text = item.item_name
		equipped_item_label.visible = true

func _on_item_unequipped() -> void:
	if equipped_item_label:
		equipped_item_label.text = ""
		equipped_item_label.visible = false

func _update_quick_bar() -> void:
	if not player or not player.inventory:
		return
	
	var inventory: Inventory = player.inventory
	for i in range(mini(quick_slots.size(), inventory.QUICK_BAR_SIZE)):
		var slot: PanelContainer = quick_slots[i]
		if not slot:
			continue
		
		var icon: TextureRect = slot.get_node_or_null("Icon") as TextureRect
		var index_label: Label = slot.get_node_or_null("IndexLabel") as Label
		
		var slot_index: int = inventory.quick_bar[i]
		if slot_index >= 0:
			var item: ItemData = inventory.get_item_at_slot(slot_index)
			if item:
				if icon:
					icon.texture = item.icon
				if index_label:
					index_label.text = str(i + 1)
				continue
		
		if icon:
			icon.texture = null
		if index_label:
			index_label.text = str(i + 1)
	
	_highlight_selected_slot(inventory.selected_quick_slot)

func _highlight_selected_slot(slot_index: int) -> void:
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color(0.2, 0.2, 0.2, 0.85)
	selected_style.border_color = Color(0.8, 0.8, 0.8, 0.9)
	selected_style.set_border_width_all(2)
	selected_style.corner_radius_top_left = 0
	selected_style.corner_radius_top_right = 0
	selected_style.corner_radius_bottom_right = 0
	selected_style.corner_radius_bottom_left = 0

	var default_style := StyleBoxFlat.new()
	default_style.bg_color = Color(0.08, 0.08, 0.08, 0.55)
	default_style.border_color = Color(0.3, 0.3, 0.3, 0.8)
	default_style.set_border_width_all(1)
	default_style.corner_radius_top_left = 0
	default_style.corner_radius_top_right = 0
	default_style.corner_radius_bottom_right = 0
	default_style.corner_radius_bottom_left = 0
	
	for i in range(quick_slots.size()):
		var slot: PanelContainer = quick_slots[i]
		if not slot:
			continue
		
		if i == slot_index:
			slot.add_theme_stylebox_override("panel", selected_style)
		else:
			slot.add_theme_stylebox_override("panel", default_style)
