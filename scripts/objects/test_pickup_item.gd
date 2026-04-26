class_name TestPickupItem
extends InteractableObject

@export var item_data: ItemData
@export var pickup_count: int = 1

signal item_picked_up(item: ItemData, count: int)

func _ready() -> void:
	super._ready()
	if item_data:
		interaction_text = "拾取 " + item_data.item_name
	else:
		interaction_text = "拾取物品"

func interact() -> void:
	if not item_data:
		push_warning("PickupItem has no item_data assigned")
		return
	
	var player := _get_player()
	if not player:
		push_warning("Could not find player to give item to")
		return
	
	var success: bool = player.pickup_item(item_data, pickup_count)
	
	if success:
		print("拾取了 %s x%d" % [item_data.item_name, pickup_count])
		emit_signal("item_picked_up", item_data, pickup_count)
		queue_free()
	else:
		print("背包已满，无法拾取 %s" % item_data.item_name)

func _get_player() -> PlayerController:
	var interaction_manager := get_node_or_null("/root/InteractionManager")
	if interaction_manager and interaction_manager.has_method("get_player"):
		return interaction_manager.call("get_player")
	
	var player := get_tree().get_first_node_in_group("player")
	if player is PlayerController:
		return player
	
	return null

func get_item_info() -> Dictionary:
	if not item_data:
		return {}
	
	return {
		"id": item_data.item_id,
		"name": item_data.item_name,
		"description": item_data.description,
		"type": item_data.get_type_name(),
		"count": pickup_count
	}
