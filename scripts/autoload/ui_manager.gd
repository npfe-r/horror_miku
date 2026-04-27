## UIManager — UI 显示层级管理
extends Node

var hud: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_hud(h: Control) -> void:
	hud = h

func show_hud() -> void:
	if hud:
		hud.visible = true

func hide_hud() -> void:
	if hud:
		hud.visible = false

func show_interaction_prompt(text: String) -> void:
	EventBus.interaction_prompt_changed.emit(text)

func hide_interaction_prompt() -> void:
	EventBus.interaction_prompt_changed.emit("")
