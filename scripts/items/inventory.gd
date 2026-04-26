class_name Inventory
extends Node

signal item_added(item: ItemData, count: int)
signal item_removed(item_id: String, count: int)
signal inventory_changed()
signal quick_bar_changed(slot_index: int)
signal selected_slot_changed(slot_index: int)

const MAX_SLOTS: int = 8
const QUICK_BAR_SIZE: int = 4

var slots: Array[ItemSlot] = []
var quick_bar: Array[int] = [-1, -1, -1, -1]
var selected_quick_slot: int = 0

func _ready() -> void:
	_initialize_slots()

func _initialize_slots() -> void:
	slots.clear()
	for i in range(MAX_SLOTS):
		slots.append(ItemSlot.new())

func add_item(item: ItemData, amount: int = 1) -> bool:
	if not item:
		return false
	
	var remaining: int = amount
	remaining = _try_stack_existing_item(item, remaining)
	remaining = _try_add_to_empty_slot(item, remaining)
	
	if remaining < amount:
		var added_count: int = amount - remaining
		print("[背包] 添加物品: %s x%d" % [item.item_name, added_count])
		emit_signal("item_added", item, added_count)
		emit_signal("inventory_changed")
		return true
	
	print("[背包] 添加物品失败: %s (背包已满)" % item.item_name)
	return false

func _try_stack_existing_item(item: ItemData, amount: int) -> int:
	var remaining: int = amount
	
	for slot in slots:
		if slot.is_empty():
			continue
		if slot.item_data.item_id == item.item_id:
			while remaining > 0 and slot.can_add_amount(1):
				slot.add_amount(1)
				remaining -= 1
	
	return remaining

func _try_add_to_empty_slot(item: ItemData, amount: int) -> int:
	var remaining: int = amount
	
	for slot in slots:
		if not slot.is_empty():
			continue
		
		var to_add: int = mini(remaining, item.max_stack)
		slot.set_item(item, to_add)
		remaining -= to_add
		
		if remaining <= 0:
			break
	
	return remaining

func remove_item(item_id: String, amount: int = 1) -> bool:
	var total_count: int = get_item_count(item_id)
	if total_count < amount:
		print("[背包] 移除物品失败: %s (数量不足)" % item_id)
		return false
	
	var item_name: String = ""
	var remaining: int = amount
	for i in range(slots.size() - 1, -1, -1):
		var slot: ItemSlot = slots[i]
		if slot.is_empty():
			continue
		if slot.item_data.item_id == item_id:
			if item_name.is_empty():
				item_name = slot.item_data.item_name
			var removed: int = slot.remove_amount(remaining)
			remaining -= removed
			
			if remaining <= 0:
				break
	
	if remaining < amount:
		var removed_count: int = amount - remaining
		print("[背包] 移除物品: %s x%d" % [item_name, removed_count])
		emit_signal("item_removed", item_id, removed_count)
		emit_signal("inventory_changed")
		return true
	
	return false

func get_item_count(item_id: String) -> int:
	var total: int = 0
	for slot in slots:
		if not slot.is_empty() and slot.item_data.item_id == item_id:
			total += slot.count
	return total

func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount

func get_slot(index: int) -> ItemSlot:
	if index < 0 or index >= slots.size():
		return null
	return slots[index]

func get_item_at_slot(index: int) -> ItemData:
	var slot: ItemSlot = get_slot(index)
	if slot and not slot.is_empty():
		return slot.item_data
	return null

func use_item(slot_index: int, user: Node = null) -> bool:
	var slot: ItemSlot = get_slot(slot_index)
	if not slot or slot.is_empty():
		print("[背包] 使用物品失败: 槽位为空")
		return false
	
	var item: ItemData = slot.item_data
	print("[背包] 使用物品: %s" % item.item_name)
	var effect_success: bool = ItemEffectManager.use_item(item, user)
	
	if effect_success:
		print("[背包] 物品效果生效: %s" % item.item_name)
		if item.is_consumable:
			remove_item(item.item_id, 1)
	else:
		print("[背包] 物品效果失败: %s" % item.item_name)
	
	return effect_success

func use_quick_slot_item(quick_slot_index: int, user: Node = null) -> bool:
	if quick_slot_index < 0 or quick_slot_index >= QUICK_BAR_SIZE:
		return false
	
	var slot_index: int = quick_bar[quick_slot_index]
	if slot_index < 0:
		return false
	
	return use_item(slot_index, user)

func set_quick_bar_slot(quick_slot_index: int, inventory_slot_index: int) -> bool:
	if quick_slot_index < 0 or quick_slot_index >= QUICK_BAR_SIZE:
		return false
	if inventory_slot_index < 0 or inventory_slot_index >= MAX_SLOTS:
		return false
	
	quick_bar[quick_slot_index] = inventory_slot_index
	emit_signal("quick_bar_changed", quick_slot_index)
	return true

func clear_quick_bar_slot(quick_slot_index: int) -> bool:
	if quick_slot_index < 0 or quick_slot_index >= QUICK_BAR_SIZE:
		return false
	
	quick_bar[quick_slot_index] = -1
	emit_signal("quick_bar_changed", quick_slot_index)
	return true

func select_quick_slot(index: int) -> bool:
	if index < 0 or index >= QUICK_BAR_SIZE:
		return false
	
	selected_quick_slot = index
	var item: ItemData = get_selected_item()
	if item:
		print("[背包] 选择快捷栏 [%d]: %s" % [index + 1, item.item_name])
	else:
		print("[背包] 选择快捷栏 [%d]: 空" % [index + 1])
	emit_signal("selected_slot_changed", index)
	return true

func get_selected_item() -> ItemData:
	var slot_index: int = quick_bar[selected_quick_slot]
	if slot_index < 0:
		return null
	return get_item_at_slot(slot_index)

func find_item_by_id(item_id: String) -> int:
	for i in range(slots.size()):
		var slot: ItemSlot = slots[i]
		if not slot.is_empty() and slot.item_data.item_id == item_id:
			return i
	return -1

func get_all_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for slot in slots:
		if not slot.is_empty():
			items.append(slot.item_data)
	return items

func clear_inventory() -> void:
	for slot in slots:
		slot.clear()
	for i in range(QUICK_BAR_SIZE):
		quick_bar[i] = -1
	selected_quick_slot = 0
	emit_signal("inventory_changed")

func get_empty_slot_count() -> int:
	var count: int = 0
	for slot in slots:
		if slot.is_empty():
			count += 1
	return count

func serialize() -> Dictionary:
	var data: Dictionary = {}
	data["slots"] = []
	
	for slot in slots:
		var slot_data: Dictionary = {}
		if not slot.is_empty():
			slot_data["item_id"] = slot.item_data.item_id
			slot_data["count"] = slot.count
		data["slots"].append(slot_data)
	
	data["quick_bar"] = quick_bar.duplicate()
	data["selected_quick_slot"] = selected_quick_slot
	
	return data

func deserialize(data: Dictionary, item_database: Dictionary) -> void:
	clear_inventory()
	
	if data.has("slots"):
		var slots_data: Array = data["slots"]
		for i in range(mini(slots_data.size(), MAX_SLOTS)):
			var slot_data: Dictionary = slots_data[i]
			if slot_data.has("item_id") and slot_data.has("count"):
				var item_id: String = slot_data["item_id"]
				var count: int = slot_data["count"]
				
				if item_database.has(item_id):
					var item: ItemData = item_database[item_id]
					slots[i].set_item(item, count)
	
	if data.has("quick_bar"):
		var quick_bar_data: Array = data["quick_bar"]
		for i in range(mini(quick_bar_data.size(), QUICK_BAR_SIZE)):
			quick_bar[i] = quick_bar_data[i]
	
	if data.has("selected_quick_slot"):
		selected_quick_slot = data["selected_quick_slot"]
	
	emit_signal("inventory_changed")
