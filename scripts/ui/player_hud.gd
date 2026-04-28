class_name PlayerHUD
extends Control

@onready var crosshair: Control = $Crosshair
@onready var interaction_label: Label = $InteractionLabel
@onready var stamina_bar: ProgressBar = $StaminaBarContainer/StaminaBar

var inventory_menu: InventoryMenu = null
var player: PlayerController = null

func _ready() -> void:
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	
	inventory_menu = get_node_or_null("InventoryMenu") as InventoryMenu
	print("[PlayerHUD] _ready: inventory_menu=%s" % inventory_menu)
	
	await get_tree().process_frame
	player = InteractionManager.get_player()
	if player:
		_on_stamina_changed(player.stamina)
		print("[PlayerHUD] 找到玩家, inventory_menu=%s" % inventory_menu)
		if inventory_menu:
			inventory_menu.set_player(player)
		else:
			push_warning("[PlayerHUD] inventory_menu is null!")
	else:
		push_warning("[PlayerHUD] 未找到玩家")
	if UIManager:
		UIManager.register_hud(self)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory_menu()
		get_viewport().set_input_as_handled()

func toggle_inventory_menu() -> void:
	if inventory_menu:
		inventory_menu.toggle()
		if crosshair:
			crosshair.visible = not inventory_menu.visible

func _on_stamina_changed(stamina: float) -> void:
	if stamina_bar:
		stamina_bar.value = stamina

func _on_interaction_prompt_changed(prompt_text: String) -> void:
	if interaction_label:
		if prompt_text.is_empty():
			interaction_label.visible = false
		else:
			interaction_label.text = "[E] " + prompt_text
			interaction_label.visible = true
