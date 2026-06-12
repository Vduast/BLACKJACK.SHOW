extends Control

# --- CAJAS DE NAVEGACIÓN ---
@onready var mode_box = $ModeBox
@onready var connection_box = $ConnectionBox
@onready var lobby_box = $LobbyBox
@onready var settings_box = $SettingsBox

# --- ELEMENTOS PERMANENTES ---
@onready var open_settings_button = $PersistentBox/SettingsButton
@onready var quit_button = $PersistentBox/QuitButton

# --- NODOS DE MODO ---
@onready var single_btn = $ModeBox/SinglePlayerButton
@onready var multi_btn = $ModeBox/MultiPlayerButton

# --- NODOS DE CONEXIÓN ---
@onready var name_input = $ConnectionBox/NameInput
@onready var ip_input = $ConnectionBox/IPInput
@onready var host_button = $ConnectionBox/HostButton
@onready var join_button = $ConnectionBox/JoinButton

# --- NODOS DEL LOBBY ---
@onready var title_label = $LobbyBox/TitleLabel
@onready var player_list = $LobbyBox/PlayerList
@onready var start_button = $LobbyBox/StartGameButton

# --- NODOS DE CONFIGURACIÓN ---
@onready var master_slider = $SettingsBox/MasterSlider
@onready var sfx_slider = $SettingsBox/SFXSlider
@onready var music_slider = $SettingsBox/MusicSlider
@onready var voz_slider = $SettingsBox/VozSlider

# --- REFERENCIA A LA CÁMARA ---
@onready var main_camera = get_node_or_null("../../Camera3D")

# --- SISTEMA DE AUDIO CENTRALIZADO (POOLING) ---
@onready var sfx_player = $SFXPlayer # <-- ¡Asegúrate de haber creado este nodo!
var sfx_pool: Array = []
var sfx_index: int = 0
var max_sfx_players: int = 4 # 4 sonidos simultáneos para el menú está perfecto

@export_group("Efectos de Sonido")
@export var snd_hover: AudioStream      # Sonido sutil al pasar el ratón por los botones
@export var snd_click: AudioStream      # Sonido metálico/mecánico al hacer clic
@export var snd_transition: AudioStream # Sonido de "Swoosh" o estática al hacer zoom a la TV
@export var snd_error: AudioStream      # Sonido de buzzer/error al fallar conexión

var master_bus_idx = AudioServer.get_bus_index("Master")
var sfx_bus_idx = AudioServer.get_bus_index("SFX")
var music_bus_idx = AudioServer.get_bus_index("Music")
var voz_bus_idx = AudioServer.get_bus_index("Voz")
var menu_history: Array[Control] = []
var current_box: Control

func _ready():
	# --- CREACIÓN DEL POOL DE AUDIO DINÁMICO ---
	if is_instance_valid(sfx_player):
		sfx_pool.append(sfx_player)
		for i in range(max_sfx_players - 1):
			var new_player = sfx_player.duplicate()
			add_child(new_player)
			sfx_pool.append(new_player)

	NetworkManager.players_updated.connect(_update_lobby_ui)
	NetworkManager.connection_succeeded.connect(_on_connection_success)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	voz_slider.value_changed.connect(_on_voz_volume_changed)
	
	ip_input.placeholder_text = "Pegar Código Aquí"
	_hide_all_boxes()
	mode_box.show()
	current_box = mode_box
	
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus_idx))
	sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_idx))
	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus_idx))
	voz_slider.value = db_to_linear(AudioServer.get_bus_volume_db(voz_bus_idx))
	
	_apply_button_juice(self)

# --- FUNCIÓN CENTRAL DE SONIDO (CON ROUND-ROBIN) ---
func play_sfx(stream: AudioStream, randomize_pitch: bool = true):
	if stream == null or sfx_pool.is_empty():
		return
	
	var current_player = sfx_pool[sfx_index]
	current_player.stop() 
	current_player.stream = stream
	
	if randomize_pitch:
		current_player.pitch_scale = randf_range(0.9, 1.1)
	else:
		current_player.pitch_scale = 1.0
		
	current_player.play()
	sfx_index = (sfx_index + 1) % max_sfx_players

# --- SISTEMA DE "JUICE" AUTOMATIZADO (Hover y Sonidos) ---
func _apply_button_juice(node: Node):
	for child in node.get_children():
		if child is Button:
			child.pivot_offset = child.size / 2.0
			
			child.mouse_entered.connect(func(): 
				_animate_button_hover(child, true)
				play_sfx(snd_hover, true)
			)
			child.mouse_exited.connect(func(): 
				_animate_button_hover(child, false)
			)
			child.pressed.connect(func(): 
				play_sfx(snd_click, false) 
			)
			
		elif child is Control or child is CanvasLayer:
			_apply_button_juice(child)

func _animate_button_hover(btn: Button, is_hovered: bool):
	var tween = create_tween()
	var target_scale = Vector2(1.1, 1.1) if is_hovered else Vector2(1.0, 1.0)
	tween.tween_property(btn, "scale", target_scale, 0.1).set_trans(Tween.TRANS_SINE)

# --- ANIMACIÓN INMERSIVA DE CÁMARA (Zoom + Fade Simultáneo) ---
func play_transition_and_start(callback: Callable):
	play_sfx(snd_transition, false)
	
	var fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0) 
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT) 
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	var root_canvas = self
	while root_canvas.get_parent() and (root_canvas.get_parent() is Control or root_canvas.get_parent() is CanvasLayer):
		root_canvas = root_canvas.get_parent()
	root_canvas.add_child(fade_rect)

	if is_instance_valid(main_camera):
		var tween = create_tween()
		var fov_original = main_camera.fov
		
		tween.tween_property(main_camera, "fov", fov_original + 15.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(main_camera, "fov", 15.0, 1.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(fade_rect, "color:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		await tween.finished
	else:
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
		await tween.finished
		
	callback.call()

# --- MANEJO DE VENTANAS Y MEMORIA ---
func _hide_all_boxes():
	mode_box.hide()
	connection_box.hide()
	lobby_box.hide()
	settings_box.hide()

func _change_menu(new_box: Control):
	if current_box != null:
		menu_history.append(current_box) 
		current_box.hide() 
	new_box.show()
	current_box = new_box

func _on_back_pressed():
	if menu_history.size() > 0:
		var previous_box = menu_history.pop_back()
		if current_box == lobby_box and multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer = null
			NetworkManager.players.clear()
		current_box.hide()
		previous_box.show()
		current_box = previous_box 

func _on_quit_pressed():
	get_tree().quit()

# --- NAVEGACIÓN DE MODO ---
func _on_singleplayer_pressed():
	var p_name = name_input.text.strip_edges()
	if p_name == "": p_name = "Jugador 1" 
	play_transition_and_start(func(): NetworkManager.start_singleplayer(p_name))

func _on_multiplayer_pressed():
	_change_menu(connection_box)
	NetworkManager.game_mode = "multiplayer"

func _on_open_settings_pressed():
	_change_menu(settings_box)
	
# --- LÓGICA DE CONEXIÓN MULTIJUGADOR ---
func _on_host_pressed():
	if name_input.text.strip_edges() == "": return
	NetworkManager.host_game(name_input.text)
	_change_menu(lobby_box)
	_update_lobby_ui()

func _on_join_pressed():
	var player_name = name_input.text.strip_edges()
	var room_code = ip_input.text.strip_edges()
	
	if player_name == "" or room_code == "": return
	
	var target_ip = NetworkManager.decode_room_code(room_code)
	if target_ip == "":
		_show_error("¡CÓDIGO INVÁLIDO!")
		return
		
	_set_ui_disabled(true)
	ip_input.text = ""
	ip_input.placeholder_text = "Buscando sala..."
	NetworkManager.join_game(target_ip, player_name)

func _on_connection_success():
	_set_ui_disabled(false)
	_change_menu(lobby_box)
	_update_lobby_ui()

func _on_connection_failed():
	_show_error("¡SALA NO ENCONTRADA!")

func _show_error(msg: String):
	play_sfx(snd_error, false) 
	ip_input.text = ""
	ip_input.placeholder_text = msg
	_set_ui_disabled(false)

func _set_ui_disabled(disabled: bool):
	join_button.disabled = disabled
	host_button.disabled = disabled
	name_input.editable = !disabled
	ip_input.editable = !disabled

# --- LÓGICA DEL LOBBY ---
func _update_lobby_ui():
	if not lobby_box.visible: return 
	
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
	play_transition_and_start(func(): NetworkManager.rpc("start_game"))

# --- AUDIO ---
func _on_master_volume_changed(value: float):
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(value))
func _on_sfx_volume_changed(value: float):
	AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(value))
func _on_music_volume_changed(value: float):
	AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(value))
func _on_voz_volume_changed(value: float):
	AudioServer.set_bus_volume_db(voz_bus_idx, linear_to_db(value))
