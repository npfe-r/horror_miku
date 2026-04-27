## SaveManager — 存档/读档骨架（文件 I/O 后续实现）
extends Node

var _save_data: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func save_game(data: Dictionary) -> bool:
	_save_data = data.duplicate(true)
	EventBus.game_saved.emit()
	return true

func load_game() -> Dictionary:
	EventBus.game_loaded.emit()
	return _save_data.duplicate(true)

func has_save() -> bool:
	return not _save_data.is_empty()

func delete_save() -> void:
	_save_data.clear()
