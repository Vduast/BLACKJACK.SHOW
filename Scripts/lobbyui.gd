extends Control

@onready var title_label = $VBoxContainer/TitleLabel
@onready var player_list = $VBoxContainer/PlayerList
@onready var start_button = $VBoxContainer/StartGameButton

func _ready():
	NetworkManager.players_updated.connect(_update_lobby_ui)
	start_button.pressed.connect(_on_start_pressed)
	_update_lobby_ui()

func _update_lobby_ui():
	if multiplayer.is_server():
		start_button.show()
		var my_code = NetworkManager.generate_room_code()
		title_label.text = "Código de Sala: " + my_code
	else:
		start_button.hide()
		title_label.text = "Conectado. Esperando al Host..."

	for child in player_list.get_children():
		child.queue_free()
		
	for id in NetworkManager.players:
		var lbl = Label.new()
		lbl.text = str(id) + ": " + NetworkManager.players[id].name
		player_list.add_child(lbl)

func _on_start_pressed():
	NetworkManager.rpc("start_game")
