extends CanvasLayer

signal start_game
signal hit_pressed
signal stand_pressed
signal clear_pressed
signal joker_used(effect_id: String)
signal double_pressed 

@onready var status_label = $UI/StatusLabel
@onready var start_button = $UI/StartButton
@onready var clear_button = $UI/ClearButton
@onready var game_panel = $UI/GamePanel
@onready var hit_button = $UI/GamePanel/HitButton
@onready var stand_button = $UI/GamePanel/StandButton
@onready var double_button = $UI/GamePanel/DoubleButton 

@onready var jokers_container = $UI/JokersContainer
@onready var joker_action_box = $UI/JokerActionBox
@onready var btn_cancelar = $UI/JokerActionBox/BtnCancelar
@onready var btn_usar = $UI/JokerActionBox/BtnUsar

# --- NODOS DEL MENÚ SOBREPUESTO ---
@onready var open_menu_button = $UI/OpenMenuButton
@onready var overlay_menu = $UI/OverlayMenu
@onready var pause_box = $UI/OverlayMenu/PauseBox
@onready var settings_box = $UI/OverlayMenu/SettingsBox
@onready var continue_button = $UI/OverlayMenu/PauseBox/ContinueButton
@onready var settings_button = $UI/OverlayMenu/PauseBox/SettingsButton
@onready var exit_button = $UI/OverlayMenu/PauseBox/ExitButton

# --- CONTROLES DE CONFIGURACIÓN ---
@onready var master_slider = $UI/OverlayMenu/SettingsBox/MasterSlider
@onready var sfx_slider = $UI/OverlayMenu/SettingsBox/SFXSlider
@onready var music_slider = $UI/OverlayMenu/SettingsBox/MusicSlider
@onready var voz_slider = $UI/OverlayMenu/SettingsBox/VozSlider
@onready var back_button = $UI/OverlayMenu/SettingsBox/BackButton

var master_bus_idx = AudioServer.get_bus_index("Master")
var sfx_bus_idx = AudioServer.get_bus_index("SFX")
var music_bus_idx = AudioServer.get_bus_index("Music")
var voz_bus_idx = AudioServer.get_bus_index("Voz")

var joker_scene = preload("res://Objetos/JokerUI.tscn")
var selected_joker: Button = null

func _ready():
	start_button.pressed.connect(func(): start_game.emit())
	hit_button.pressed.connect(func(): hit_pressed.emit())
	stand_button.pressed.connect(func(): stand_pressed.emit())
	clear_button.pressed.connect(func(): clear_pressed.emit())
	
	if is_instance_valid(double_button):
		double_button.pressed.connect(func(): double_pressed.emit())
	
	btn_cancelar.pressed.connect(_on_joker_canceled)
	btn_usar.pressed.connect(_on_joker_confirmed)
	
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	voz_slider.value_changed.connect(_on_voz_volume_changed)
	
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus_idx))
	sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_idx))
	music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus_idx))
	voz_slider.value = db_to_linear(AudioServer.get_bus_volume_db(voz_bus_idx))
	
	game_panel.hide()
	clear_button.hide()
	overlay_menu.hide()
	settings_box.hide()
	joker_action_box.hide()
	status_label.text = "Esperando..."
	
	# JUICE: Animaciones de escalado (Hover) para todos los botones de la UI de juego
	_apply_button_juice(self)

# --- SISTEMA DE "JUICE" (Animación de Botones) ---
func _apply_button_juice(node: Node):
	for child in node.get_children():
		if child is Button:
			child.pivot_offset = child.size / 2.0
			child.mouse_entered.connect(func(): _animate_button_hover(child, true))
			child.mouse_exited.connect(func(): _animate_button_hover(child, false))
		elif child is Control or child is CanvasLayer:
			_apply_button_juice(child)

func _animate_button_hover(btn: Button, is_hovered: bool):
	var tween = create_tween()
	var target_scale = Vector2(1.1, 1.1) if is_hovered else Vector2(1.0, 1.0)
	tween.tween_property(btn, "scale", target_scale, 0.1).set_trans(Tween.TRANS_SINE)

# --- FUNCIONES DEL MENÚ SOBREPUESTO ---
func _on_open_menu_pressed():
	overlay_menu.show()
	pause_box.show()
	settings_box.hide()

func _on_continue_pressed():
	overlay_menu.hide()

func _on_settings_pressed():
	pause_box.hide()
	settings_box.show()

func _on_back_pressed():
	settings_box.hide()
	pause_box.show()

func _on_exit_pressed():
	multiplayer.multiplayer_peer = null
	NetworkManager.players.clear()
	NetworkManager.is_in_game = false
	await Transition.fade_to_scene("res://Menus/MainMenu.tscn")

# --- FUNCIONES DE AUDIO ---
func _on_master_volume_changed(value: float): AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(value))
func _on_sfx_volume_changed(value: float): AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(value))
func _on_music_volume_changed(value: float): AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(value))
func _on_voz_volume_changed(value: float): AudioServer.set_bus_volume_db(voz_bus_idx, linear_to_db(value))

# --- FUNCIONES DE COMUNICACIÓN CON TABLE.GD ---
func set_status(text: String):
	status_label.text = text

func transition_to_game(message: String):
	set_status(message)
	game_panel.show()
	start_button.hide()
	clear_button.hide()

func show_start_button(text: String = "Repartir Cartas"):
	start_button.text = text
	start_button.show()

func hide_start_button(): start_button.hide()
func hide_game_panel(): game_panel.hide()
func show_clear_button(): clear_button.show()
func hide_clear_button(): clear_button.hide()

func spawn_jokers(joker_ids: Array):
	joker_action_box.hide()
	selected_joker = null
	
	for child in jokers_container.get_children():
		child.queue_free()

	var JOKER_INFO = {
		"burn": {"n": "🔥 Quemar", "d": "Destruye la carta en la cima del mazo."},
		"peek": {"n": "👁️ Visión", "d": "Mira en secreto la siguiente carta."},
		"shield": {"n": "🛡️ Amnesia", "d": "Elimina 1 derrota de tu historial."},
		"shuffle": {"n": "🔄 Mezclar", "d": "Baraja todo el mazo."},
		"prophecy": {"n": "🔮 Profecía", "d": "Revela las siguientes 3 cartas."},
		"sabotage": {"n": "💣 Sabotaje", "d": "Pone un '10' en la cima del mazo."},
		"curse": {"n": "☠️ Maldición", "d": "+1 derrota a todos los demás."},
		"salvation": {"n": "👼 Salvación", "d": "Cura 2 derrotas de golpe."},
		"bury": {"n": "🕳️ Enterrar", "d": "Manda la carta de arriba al fondo."},
		"expose": {"n": "🚨 Exponer", "d": "Revela públicamente la próxima carta."}
	}

	for j_id in joker_ids:
		var btn = joker_scene.instantiate()
		jokers_container.add_child(btn)
		var info = JOKER_INFO[j_id]
		btn.setup(j_id, info["n"], info["d"])
		btn.joker_selected.connect(_on_joker_selected)

func _on_joker_selected(joker: Button):
	if selected_joker != null and selected_joker != joker:
		selected_joker.girar_a_titulo()
	
	selected_joker = joker
	selected_joker.girar_a_descripcion()
	
	# JUICE: Animación de pop-in fluida para la caja de acciones del comodín
	joker_action_box.show()
	joker_action_box.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(joker_action_box, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_joker_canceled():
	if selected_joker:
		selected_joker.girar_a_titulo()
		selected_joker = null
	
	# JUICE: Animación de ocultar fluida
	var tween = create_tween()
	tween.tween_property(joker_action_box, "scale", Vector2(0.1, 0.1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	joker_action_box.hide()

func _on_joker_confirmed():
	if selected_joker:
		# Avisamos al servidor que lo usamos
		joker_used.emit(selected_joker.mi_efecto)
		
		# --- ¡AQUÍ ESTÁ EL TRUCO! ---
		# En lugar de usar queue_free(), usamos esto:
		selected_joker.quemar_y_destruir()
		
		selected_joker = null
