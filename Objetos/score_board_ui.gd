extends Control
class_name ScoreBoardUI

@onready var players_list_container = $PlayersList
@onready var status_display_label = $StatusDisplay

# Guardamos los últimos datos para mantener la lista actualizada
var last_players_data: Array = []
var last_dealer_score: int = 0

func _ready():
	status_display_label.hide()

# --- AHORA RECIBE EL PUNTAJE DEL DEALER ---
func update_data(players_data: Array, dealer_score: int = 0):
	last_players_data = players_data
	last_dealer_score = dealer_score
	
	# Quitamos el 'if not visible' para que SIEMPRE se actualice en tiempo real,
	# incluso si está oculto temporalmente por el flash_status.
	_rebuild_list()

# En ScoreBoardUI.gd, dentro de _rebuild_list:
func _rebuild_list():
	for child in players_list_container.get_children():
		child.queue_free()
		
	# Muestra al dealer solo si el score es mayor a 0
	if last_dealer_score > 0:
		var dealer_lbl = Label.new()
		dealer_lbl.text = "🎩 DEALER  |  🃏 Puntos: %d" % last_dealer_score
		# ... resto de tu código igual ...
		players_list_container.add_child(dealer_lbl)
		
	# 2. Añadimos la lista de jugadores normales
	for p in last_players_data:
		var lbl = Label.new()
		lbl.text = "👤 %s  |  ❤️ Vidas: %d  |  🃏 Puntos: %d" % [p["name"], p["lives"], p["score"]]
		lbl.add_theme_font_size_override("font_size", 32)
		players_list_container.add_child(lbl)

# --- FUNCIÓN MÁGICA DE FLASH STATUS ---
func flash_status(message: String, seconds: float = 3.0):
	# 1. Ocultamos la lista de jugadores
	players_list_container.hide()
	
	# 2. Mostramos el mensaje de estado en grande
	status_display_label.text = message
	status_display_label.show()
	
	# 3. Esperamos los segundos indicados
	await get_tree().create_timer(seconds).timeout
	
	# 4. Revertimos todo
	status_display_label.hide()
	players_list_container.show()
