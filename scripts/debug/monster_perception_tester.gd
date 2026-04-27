@tool
extends Node3D

@export var test_vision: bool = false:
	set(value):
		test_vision = value
		if test_vision:
			_test_monster_vision()

@export var test_hearing: bool = false:
	set(value):
		test_hearing = value
		if test_hearing:
			_test_monster_hearing()

func _test_monster_vision() -> void:
	print("\n=== 测试敌人视觉系统 ===")
	
	var monsters := get_tree().get_nodes_in_group("enemies")
	if monsters.size() == 0:
		print("[错误] 未找到敌人")
		return
	
	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		print("[错误] 未找到玩家")
		return
	
	var monster = monsters[0]
	var player = players[0]
	
	print("敌人位置: %s" % monster.global_position)
	print("玩家位置: %s" % player.global_position)
	print("距离: %.1fm" % monster.global_position.distance_to(player.global_position))
	
	if monster.has_node("Perception"):
		var perception = monster.get_node("Perception")
		print("感知节点存在")
		print("视野范围: %.1fm" % perception.sight_range)
		print("视野角度: %.1f°" % perception.sight_angle)
		print("能否看到玩家: %s" % perception.can_see_player())
	else:
		print("[错误] 敌人没有感知节点")

func _test_monster_hearing() -> void:
	print("\n=== 测试敌人听觉系统 ===")
	
	var monsters := get_tree().get_nodes_in_group("enemies")
	if monsters.size() == 0:
		print("[错误] 未找到敌人")
		return
	
	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		print("[错误] 未找到玩家")
		return
	
	var monster = monsters[0]
	var player = players[0]
	
	if player.has_signal("noise_made"):
		print("玩家有noise_made信号，正在发送测试噪音...")
		EventBus.noise_made.emit(3.0, player.global_position, 24.0)
	else:
		print("[错误] 玩家没有noise_made信号")
