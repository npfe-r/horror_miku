class_name DebugUI
extends Control

@onready var noise_label: Label = $VBoxContainer/NoiseLabel
@onready var state_label: Label = $VBoxContainer/StateLabel
@onready var stand_up_label: Label = $VBoxContainer/StandUpLabel
@onready var quick_bar_label: Label = $InventoryContainer/QuickBarLabel
@onready var items_label: Label = $InventoryContainer/ItemsLabel

var player: PlayerController = null

func _ready() -> void:
	await get_tree().process_frame
	_find_and_connect_player()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_toggle_debug()

func _toggle_debug() -> void:
	visible = not visible
	print("[DebugUI] 调试UI %s" % ("显示" if visible else "隐藏"))

func _find_and_connect_player() -> void:
	player = get_parent().get_node("Player") as PlayerController
	if not player:
		push_warning("[DebugUI] 未找到玩家节点")
		return
	
	if not player.inventory:
		await get_tree().create_timer(0.1).timeout
		if not player.inventory:
			push_warning("[DebugUI] 玩家背包未初始化")
			return
	
	player.noise_made.connect(_on_noise_made)
	player.inventory_updated.connect(_update_inventory_display)
	player.item_picked_up.connect(_on_item_picked_up)
	
	print("[DebugUI] 已连接玩家信号")
	_update_inventory_display()

func _process(_delta: float) -> void:
	if not player:
		return
	
	_update_state_display()

func _on_noise_made(noise_level: float, _position: Vector3) -> void:
	if noise_label:
		noise_label.text = "噪音等级: %.1f" % noise_level
		await get_tree().create_timer(0.5).timeout
		if noise_label:
			noise_label.text = "噪音等级: 0.0"

func _update_state_display() -> void:
	if not state_label or not player:
		return
	
	var state_text := ""
	if player.is_hiding:
		state_text = "状态: 躲藏中"
	elif player.is_jumping:
		state_text = "状态: 跳跃中"
	elif player.is_crouching:
		state_text = "状态: 蹲下"
		if not player._can_stand_up:
			state_text += " (无法起身)"
	elif player.is_running:
		state_text = "状态: 奔跑"
	else:
		state_text = "状态: 行走"
	
	state_label.text = state_text
	
	if stand_up_label:
		if player.is_crouching:
			stand_up_label.text = "可以起身: " + ("是" if player._can_stand_up else "否")
			stand_up_label.visible = true
		else:
			stand_up_label.visible = false

func _on_item_picked_up(_item: ItemData, _count: int) -> void:
	print("[DebugUI] 收到 item_picked_up 信号")
	_update_inventory_display()

func _update_inventory_display() -> void:
	if not player:
		return
	if not player.inventory:
		print("[DebugUI] 玩家背包为空")
		return
	
	print("[DebugUI] 更新背包显示")
	_update_quick_bar_display()
	_update_items_list_display()

func _update_quick_bar_display() -> void:
	if not player.inventory:
		return
	
	if not quick_bar_label:
		push_warning("[DebugUI] quick_bar_label 节点为空")
		return
	
	var quick_bar_text := "快捷栏:\n"
	var has_items := false
	
	for i in range(Inventory.QUICK_BAR_SIZE):
		var slot_index: int = player.inventory.quick_bar[i]
		var marker := "*" if i == player.inventory.selected_quick_slot else " "
		
		if slot_index >= 0 and slot_index < Inventory.MAX_SLOTS:
			var slot: ItemSlot = player.inventory.get_slot(slot_index)
			if slot and not slot.is_empty():
				quick_bar_text += "  [%d]%s %s x%d\n" % [i + 1, marker, slot.item_data.item_name, slot.count]
				has_items = true
			else:
				quick_bar_text += "  [%d]%s 空\n" % [i + 1, marker]
		else:
			quick_bar_text += "  [%d]%s 空\n" % [i + 1, marker]
	
	if not has_items:
		quick_bar_text = "快捷栏: 无物品"
	
	print("[DebugUI] 快捷栏文本: %s" % quick_bar_text.replace("\n", "\\n"))
	quick_bar_label.text = quick_bar_text

func _update_items_list_display() -> void:
	if not player.inventory:
		return
	
	if not items_label:
		push_warning("[DebugUI] items_label 节点为空")
		return
	
	var items_text := "背包物品:\n"
	var has_items := false
	
	for i in range(Inventory.MAX_SLOTS):
		var slot: ItemSlot = player.inventory.get_slot(i)
		if slot and not slot.is_empty():
			items_text += "  %s x%d\n" % [slot.item_data.item_name, slot.count]
			has_items = true
	
	if not has_items:
		items_text = "背包物品: 无"
	
	print("[DebugUI] 物品列表文本: %s" % items_text.replace("\n", "\\n"))
	items_label.text = items_text
