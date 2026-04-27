## GameManager — 游戏流程状态机 + 场景切换
extends Node

enum State { MENU, PLAYING, PAUSED, GAME_OVER, WON }

var current_state: State = State.MENU

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_game() -> void:
	current_state = State.PLAYING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.game_started.emit()

func pause_game() -> void:
	if current_state != State.PLAYING:
		return
	current_state = State.PAUSED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.game_paused.emit(true)

func resume_game() -> void:
	if current_state != State.PAUSED:
		return
	current_state = State.PLAYING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.game_paused.emit(false)

func game_over() -> void:
	current_state = State.GAME_OVER
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.player_died.emit()

func win_game() -> void:
	current_state = State.WON
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.game_won.emit()

func restart_level() -> void:
	get_tree().reload_current_scene()
	start_game()

func get_state() -> State:
	return current_state
