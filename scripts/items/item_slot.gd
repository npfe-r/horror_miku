class_name ItemSlot
extends RefCounted

var item_data: ItemData = null
var count: int = 0

func _init(data: ItemData = null, amount: int = 1) -> void:
	item_data = data
	count = amount

func is_empty() -> bool:
	return item_data == null or count <= 0

func can_add_amount(amount: int) -> bool:
	if is_empty():
		return true
	if not item_data:
		return false
	return count + amount <= item_data.max_stack

func add_amount(amount: int) -> int:
	if is_empty():
		return amount
	
	var space_available: int = item_data.max_stack - count
	var amount_to_add: int = mini(amount, space_available)
	count += amount_to_add
	return amount - amount_to_add

func remove_amount(amount: int) -> int:
	if is_empty():
		return 0
	
	var amount_removed: int = mini(amount, count)
	count -= amount_removed
	
	if count <= 0:
		clear()
	
	return amount_removed

func clear() -> void:
	item_data = null
	count = 0

func set_item(data: ItemData, amount: int = 1) -> void:
	item_data = data
	count = amount

func get_free_space() -> int:
	if is_empty():
		return 0
	if not item_data:
		return 0
	return item_data.max_stack - count

func duplicate_slot() -> ItemSlot:
	return ItemSlot.new(item_data, count)
