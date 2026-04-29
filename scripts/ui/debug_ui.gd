class_name DebugUI
extends Control

@onready var noise_label: Label = $VBoxContainer/NoiseLabel
@onready var state_label: Label = $VBoxContainer/StateLabel
@onready var stand_up_label: Label = $VBoxContainer/StandUpLabel
@onready var monster_label: Label = $VBoxContainer/MonsterLabel
@onready var stamina_label: Label = $VBoxContainer/StaminaLabel
@onready var quick_bar_label: Label = $InventoryContainer/QuickBarLabel
@onready var items_label: Label = $InventoryContainer/ItemsLabel

var player: PlayerController = null
var monster: MonsterAI = null

func _ready() -> void:
	EventBus.noise_made.connect(_on_noise_made)
	EventBus.monster_state_changed.connect(_on_monster_state_changed)
	EventBus.inventory_changed.connect(_update_inventory_display)
	EventBus.item_picked_up.connect(_on_item_picked_up)

	await get_tree().process_frame
	_find_and_connect_player()
	_find_and_connect_monster()
	_update_inventory_display()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_toggle_debug()

func _toggle_debug() -> void:
	visible = not visible

func _find_and_connect_player() -> void:
	player = InteractionManager.get_player()
	if not player:
		push_warning("[DebugUI] 未找到玩家")
		return

	if not player.inventory:
		await get_tree().create_timer(0.1).timeout
		if not player.inventory:
			push_warning("[DebugUI] 玩家背包未初始化")
			return

func _process(_delta: float) -> void:
	if not player:
		return
	_update_state_display()
	_update_monster_display()

func _on_noise_made(noise_level: float, _position: Vector3, _max_range: float) -> void:
	if noise_label:
		noise_label.text = "噪音等级: %.1f" % noise_level
		await get_tree().create_timer(0.5).timeout
		if noise_label:
			noise_label.text = "噪音等级: 0.0"

func _on_monster_state_changed(_state: String) -> void:
	pass  # Handled in _update_monster_display

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

	if stamina_label and player:
		stamina_label.text = "体力: %.1f" % player.stamina

	if stand_up_label:
		if player.is_crouching:
			stand_up_label.text = "可以起身: " + ("是" if player._can_stand_up else "否")
			stand_up_label.visible = true
		else:
			stand_up_label.visible = false

func _on_item_picked_up(_item: ItemData, _count: int) -> void:
	_update_inventory_display()

func _update_inventory_display() -> void:
	if not player or not player.inventory:
		return
	_update_quick_bar_display()
	_update_items_list_display()

func _update_quick_bar_display() -> void:
	if not player.inventory or not quick_bar_label:
		return

	var quick_bar_text := "快捷栏:\n"
	var has_items := false

	for i in range(Inventory.QUICK_BAR_SIZE):
		var slot_index: int = player.inventory.quick_bar[i]
		var marker := "*" if i == player.inventory.selected_quick_slot else " "

		if slot_index >= 0:
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

	quick_bar_label.text = quick_bar_text

func _update_items_list_display() -> void:
	if not player.inventory or not items_label:
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

	items_label.text = items_text

func _find_and_connect_monster() -> void:
	var monsters := get_tree().get_nodes_in_group("enemies")
	if monsters.size() > 0:
		monster = monsters[0] as MonsterAI

func _update_monster_display() -> void:
	if not monster_label or not monster:
		if monster_label:
			monster_label.visible = false
		return

	monster_label.visible = true

	var speed := Vector2(monster.velocity.x, monster.velocity.z).length()
	var distance := ""
	var alertness_bar := ""

	if player:
		var dist_to_player := monster.global_position.distance_to(player.global_position)
		distance = " | 距离: %.1fm" % dist_to_player

	var alertness_percent := monster.get_alertness_percent()
	var bar_length := 20
	var filled := int(alertness_percent * bar_length)
	var empty := bar_length - filled
	alertness_bar = "\n警觉: [%s%s] %.0f%%" % ["█".repeat(filled), "░".repeat(empty), alertness_percent * 100]

	monster_label.text = "敌人状态: %s\n速度: %.2f m/s%s%s" % [monster.get_state_name(), speed, distance, alertness_bar]
