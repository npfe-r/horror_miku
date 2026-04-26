class_name ItemEffectManager
extends RefCounted

signal effect_triggered(effect_name: String, user: Node)

static func use_item(item: ItemData, user: Node) -> bool:
	if not item:
		return false
	
	if item.use_effect.is_empty():
		return false
	
	match item.use_effect:
		"flashlight":
			return _toggle_flashlight(user)
		"noise_lure":
			return _spawn_noise_lure(user)
		"flashbang":
			return _throw_flashbang(user)
		"heal":
			return _heal_player(user)
		"key":
			return _use_key(user, item)
		"map":
			return _show_map(user)
		"compass":
			return _show_compass(user)
		"monster_detector":
			return _use_monster_detector(user)
		_:
			push_warning("Unknown item effect: " + item.use_effect)
			return false

static func _toggle_flashlight(user: Node) -> bool:
	if not user:
		return false
	
	if user.has_method("toggle_flashlight"):
		user.call("toggle_flashlight")
		return true
	
	push_warning("User does not have toggle_flashlight method")
	return false

static func _spawn_noise_lure(user: Node) -> bool:
	if not user:
		return false
	
	if user.has_method("spawn_noise_lure"):
		user.call("spawn_noise_lure")
		return true
	
	push_warning("User does not have spawn_noise_lure method")
	return false

static func _throw_flashbang(user: Node) -> bool:
	if not user:
		return false
	
	if user.has_method("throw_flashbang"):
		user.call("throw_flashbang")
		return true
	
	push_warning("User does not have throw_flashbang method")
	return false

static func _heal_player(user: Node) -> bool:
	if not user:
		return false
	
	if user.has_method("heal"):
		user.call("heal")
		return true
	
	if "stamina" in user:
		user.stamina = mini(user.stamina + 50.0, 100.0)
		if user.has_signal("stamina_changed"):
			user.emit_signal("stamina_changed", user.stamina)
		return true
	
	push_warning("User does not have heal method or stamina property")
	return false

static func _use_key(user: Node, item: ItemData) -> bool:
	if not user or not item:
		return false
	
	push_warning("Key usage should be handled by interaction system")
	return false

static func _show_map(user: Node) -> bool:
	if not user:
		return false
	
	if user.has_method("show_map"):
		user.call("show_map")
		return true
	
	push_warning("User does not have show_map method")
	return false

static func _show_compass(user: Node) -> bool:
	if not user:
		return false
	
	if user.has_method("show_compass"):
		user.call("show_compass")
		return true
	
	push_warning("User does not have show_compass method")
	return false

static func _use_monster_detector(user: Node) -> bool:
	if not user:
		return false
	
	if user.has_method("use_monster_detector"):
		user.call("use_monster_detector")
		return true
	
	push_warning("User does not have use_monster_detector method")
	return false

static func get_effect_description(effect_name: String) -> String:
	match effect_name:
		"flashlight":
			return "切换手电筒"
		"noise_lure":
			return "制造噪音吸引怪物"
		"flashbang":
			return "投掷闪光弹，暂时致盲怪物"
		"heal":
			return "恢复体力"
		"key":
			return "用于开启对应的门"
		"map":
			return "显示学校地图"
		"compass":
			return "显示出口方向"
		"monster_detector":
			return "检测怪物位置"
		_:
			return "未知效果"
