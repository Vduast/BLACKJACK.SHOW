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

@onready var jokers_container = get_node_or_null("UI/JokersContainer")   # el viejo HBox: ahora solo se oculta
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
var selected_joker: JokerUI = null
var joker_hand: JokerHand = null            # [JOKERS] la mano en abanico (se crea por código)
var joker_toggle: Button = null             # [JOKERS] botón para ocultar / mostrar la mano
var _action_tween: Tween = null             # [JOKERS] animación de la caja USAR/CANCELAR

# [JOKERS] Botones USAR/CANCELAR más compactos para que quepan bajo la carta elegida.
const COMPACT_ACTION_BUTTONS: bool = true

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
	
	_setup_joker_hand()           # [JOKERS]
	_setup_joker_action_box()     # [JOKERS]
	
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
	btn.pivot_offset = btn.size / 2.0   # [JOKERS] antes se calculaba en _ready con tamaño 0
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

# ===================== [JOKERS] MANO, SELECCIÓN Y CAJA DE ACCIONES =====================

const JOKER_INFO: Dictionary = {
	"burn": {"n": "🔥 Quemar", "d": "Destruye la carta en la cima del mazo."},
	"peek": {"n": "👁️ Visión", "d": "Mira en secreto la siguiente carta."},
	"shield": {"n": "🛡️ Amnesia", "d": "Elimina 1 derrota de tu historial."},
	"shuffle": {"n": "🔄 Mezclar", "d": "Baraja todo el mazo."},
	"prophecy": {"n": "🔮 Profecía", "d": "Revela las siguientes 3 cartas."},
	"sabotage": {"n": "💣 Sabotaje", "d": "Pone un '10' en la cima del mazo."},
	"curse": {"n": "☠️ Maldición", "d": "PvP: Castiga al líder. PvE: Sabotea al Dealer."},
	"salvation": {"n": "👼 Salvación", "d": "Cura 2 derrotas si estás en peligro crítico."},
	"bury": {"n": "🕳️ Enterrar", "d": "Manda la carta de arriba al fondo."},
	"expose": {"n": "🚨 Exponer", "d": "Revela públicamente la próxima carta."},
	"ace": {"n": "🃏 As Oculto", "d": "Coloca un As (1 u 11) en la cima del mazo."},
	"low_blow": {"n": "🩸 Golpe Bajo", "d": "Coloca un '2' en la cima para afinar tu 21."},
	"mirror": {"n": "🪞 Espejo", "d": "Duplica la carta en la cima del mazo."},
	"famine": {"n": "🌪️ Hambruna", "d": "Quema de golpe las 2 próximas cartas."},
	"vampire": {"n": "🧛 Vampirismo", "d": "Transfiere 1 derrota de ti hacia un rival."},
	"roulette": {"n": "🎲 Ruleta", "d": "50% de curar 1 derrota, 50% de recibir 1 daño."}
}

func _setup_joker_hand() -> void:
	joker_hand = JokerHand.new()
	joker_hand.name = "JokerHand"
	var parent: Node = $UI
	if jokers_container != null:
		parent = jokers_container.get_parent()
	parent.add_child(joker_hand)
	joker_hand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if jokers_container != null:
		# Justo después del viejo contenedor: así queda DEBAJO del menú de pausa
		parent.move_child(joker_hand, jokers_container.get_index() + 1)
		jokers_container.hide()
	joker_hand.joker_selected.connect(_on_joker_selected)
	_setup_joker_toggle(parent)

func _setup_joker_action_box() -> void:
	if not COMPACT_ACTION_BUTTONS:
		return
	joker_action_box.add_theme_constant_override("separation", 14)
	joker_action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_cancelar.custom_minimum_size = Vector2(170, 64)
	btn_usar.custom_minimum_size = Vector2(230, 64)
	btn_cancelar.add_theme_font_size_override("font_size", 30)
	btn_usar.add_theme_font_size_override("font_size", 34)

# ---- Botón para ocultar / mostrar la mano de comodines ----
func _setup_joker_toggle(parent: Node) -> void:
	joker_toggle = Button.new()
	joker_toggle.name = "JokerToggleButton"
	joker_toggle.theme = hit_button.theme          # mismo estilo que los demás botones del HUD
	joker_toggle.focus_mode = Control.FOCUS_NONE
	joker_toggle.custom_minimum_size = Vector2(330, 48)
	joker_toggle.add_theme_font_size_override("font_size", 22)
	joker_toggle.tooltip_text = "Atajo: J"
	joker_toggle.visible = false
	parent.add_child(joker_toggle)
	# Justo después de la mano: queda encima de ella y DEBAJO del menú de pausa
	parent.move_child(joker_toggle, joker_hand.get_index() + 1)
	joker_toggle.pressed.connect(_on_joker_toggle_pressed)
	joker_hand.collapsed_changed.connect(_on_joker_hand_collapsed)
	joker_hand.hand_changed.connect(_on_joker_hand_changed)
	get_viewport().size_changed.connect(_dock_joker_toggle)

func _on_joker_toggle_pressed() -> void:
	joker_hand.toggle_collapsed()

func _on_joker_hand_collapsed(collapsed: bool) -> void:
	# Si había una carta elegida, JokerHand ya la devolvió a la mano: limpiamos el HUD
	if collapsed and selected_joker != null:
		selected_joker = null
		_hide_action_box()
	_update_joker_toggle()

func _on_joker_hand_changed(count: int) -> void:
	# Sin comodines no hay nada que ocultar: la próxima partida empieza con la mano abierta
	if count == 0 and joker_hand.is_collapsed():
		joker_hand.set_collapsed(false, false)
	_update_joker_toggle()

func _update_joker_toggle() -> void:
	if joker_toggle == null:
		return
	var n: int = joker_hand.get_count()
	joker_toggle.visible = n > 0
	if joker_hand.is_collapsed():
		joker_toggle.text = "MOSTRAR JOKERS (%d)" % n
	else:
		joker_toggle.text = "OCULTAR JOKERS"
	_dock_joker_toggle()

# Centrado bajo el abanico, pegado al borde inferior de la pantalla
func _dock_joker_toggle() -> void:
	if joker_toggle == null or joker_hand == null:
		return
	var vp: Vector2 = joker_hand.get_viewport_rect().size
	var sz: Vector2 = joker_toggle.get_combined_minimum_size()
	joker_toggle.size = sz
	joker_toggle.pivot_offset = sz * 0.5
	joker_toggle.position = Vector2(joker_hand.get_hand_center().x - sz.x * 0.5, vp.y - sz.y - 70.0)

func spawn_jokers(joker_ids: Array):
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	joker_action_box.hide()
	selected_joker = null
	joker_hand.clear_hand()
	joker_hand.set_collapsed(false, false)   # las cartas nuevas siempre entran con la mano abierta
	
	var i: int = 0
	for j_id in joker_ids:
		var btn: JokerUI = joker_scene.instantiate() as JokerUI
		var info: Dictionary = JOKER_INFO[j_id]
		btn.setup(j_id, info["n"], info["d"])
		joker_hand.add_joker(btn, 0.25 + float(i) * 0.16)   # entran escalonadas
		i += 1

func _on_joker_selected(joker: JokerUI):
	# Clic en la carta ya elegida = deseleccionar
	if joker == selected_joker:
		_on_joker_canceled()
		return
	selected_joker = joker
	joker_hand.select(joker)    # la saca de la mano, la gira y opaca las demás
	_show_action_box()

func _on_joker_canceled():
	if selected_joker != null:
		joker_hand.deselect()
		selected_joker = null
	_hide_action_box()

func _on_joker_confirmed():
	if selected_joker == null or not is_instance_valid(selected_joker):
		return
	var j: JokerUI = selected_joker
	selected_joker = null
	joker_used.emit(j.mi_efecto)     # avisamos al servidor
	joker_hand.consume_selected()    # la carta arde y las demás se reacomodan
	_hide_action_box()

# Esc cancela la carta elegida; J oculta / muestra la mano de comodines
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		if joker_toggle != null and joker_toggle.visible and not overlay_menu.visible:
			_on_joker_toggle_pressed()
			get_viewport().set_input_as_handled()
			return
	if selected_joker != null and event.is_action_pressed("ui_cancel"):
		_on_joker_canceled()
		get_viewport().set_input_as_handled()

# USAR / CANCELAR aparecen justo debajo de la carta elegida
func _dock_action_box():
	var c: Vector2 = joker_hand.get_showcase_center()
	var half_h: float = joker_hand.card_size.y * joker_hand.select_scale * 0.5
	var vp: Vector2 = joker_hand.get_viewport_rect().size
	var local: Vector2 = Vector2(c.x - joker_action_box.size.x * 0.5, c.y + half_h + 18.0)
	local.x = clampf(local.x, 12.0, vp.x - joker_action_box.size.x - 12.0)
	local.y = minf(local.y, vp.y - joker_action_box.size.y - 12.0)
	# Transformación de espacio local a espacio global en CanvasItem
	joker_action_box.global_position = joker_hand.get_global_transform() * local

func _show_action_box():
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	joker_action_box.show()
	joker_action_box.size = joker_action_box.get_combined_minimum_size()
	_dock_action_box()
	joker_action_box.pivot_offset = Vector2(joker_action_box.size.x * 0.5, 0.0)
	joker_action_box.scale = Vector2(0.6, 0.6)
	joker_action_box.modulate.a = 0.0
	# Espera 0.12 s a que la carta llegue a su sitio y entonces "brota" debajo de ella
	_action_tween = create_tween().set_parallel(true)
	_action_tween.tween_property(joker_action_box, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.12)
	_action_tween.tween_property(joker_action_box, "modulate:a", 1.0, 0.18).set_delay(0.12)

func _hide_action_box():
	if not joker_action_box.visible:
		return
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	_action_tween = create_tween().set_parallel(true)
	_action_tween.tween_property(joker_action_box, "scale", Vector2(0.7, 0.7), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(joker_action_box, "modulate:a", 0.0, 0.15)
	_action_tween.chain().tween_callback(joker_action_box.hide)
