extends Node3D
class_name PlayerSeat

@onready var card_position = $CardPosition
@onready var score_label = $ScoreLabel
@onready var name_label = $NameLabel
@onready var player_model = $PlayerModel 
@onready var camera = $Camera3D

var visual_cards: Array = []

func setup(player_id_raw):
	# Convertimos a String por seguridad para las etiquetas
	var p_id_str = str(player_id_raw)
	
	name_label.text = "Jugador: " + p_id_str
	score_label.text = "Suma: 0"
	score_label.modulate = Color(1, 1, 1)
	
	# Verificación de la Cámara
	# Comparamos el ID recibido con nuestro ID local de red
	if int(player_id_raw) == multiplayer.get_unique_id():
		camera.make_current() # Fuerza a Godot a usar ESTA cámara
		print("Cámara activada para el jugador local: ", p_id_str)
	else:
		camera.current = false

func add_visual_card(card_instance: Card3D):
	# 1. Añadimos la carta nueva a la escena y a la lista
	add_child(card_instance)
	visual_cards.append(card_instance)
	
	# 2. Le damos su posición inicial (arriba en el aire, viniendo del dealer)
	card_instance.position = Vector3(0, 5, -3) 
	
	# 3. Llamamos a la función que reacomoda TODAS las cartas
	_rearrange_cards()
	
func reset_ui():
	score_label.text = "Suma: 0"
	score_label.modulate = Color.WHITE
	# Si guardas las cartas en una lista local, vacíala también
	if "visual_cards" in self:
		visual_cards.clear()
func _rearrange_cards():
	var total = visual_cards.size()
	var spread = 0.4 # Separación horizontal entre cartas
	
	for i in range(total):
		var card = visual_cards[i]
		var x_offset = (i - (total - 1) / 2.0) * spread
		var y_offset = 0.01 * i
		
		var target_pos = card_position.position + Vector3(x_offset, y_offset, 0)
		
		var tween = create_tween()
		tween.tween_property(card, "position", target_pos, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
func adjust_camera(_all_seats: Array, dealer_pos: Vector3):
	if not camera.current: return

	# En lugar de promediar a todos los jugadores (que alejaría la vista),
	# nos enfocamos en el punto medio entre el Dealer y nuestras cartas.
	var my_cards_pos = card_position.global_position
	var look_target = (dealer_pos + my_cards_pos) / 2.0
	
	# Suavizamos el giro para que no sea instantáneo
	var tween = create_tween()
	
	# Queremos que la cámara mire al objetivo pero manteniendo su altura
	# para no marear al jugador con rotaciones en el eje Z.
	var current_transform = camera.global_transform
	camera.look_at(look_target, Vector3.UP)
	var target_transform = camera.global_transform
	
	# Regresamos la cámara a donde estaba para animar la transición
	camera.global_transform = current_transform
	
	# Animamos hacia la nueva rotación de enfoque
	tween.tween_property(camera, "global_transform", target_transform, 0.8).set_trans(Tween.TRANS_SINE)
	
func update_score_display(score: int):
	score_label.text = "Suma: " + str(score)
	if score > 21:
		score_label.text += " (Voló)"
		score_label.modulate = Color(1, 0, 0)
	elif score == 21:
		score_label.text += " ¡Blackjack!"
		score_label.modulate = Color(0, 1, 0)

func set_result(result_text: String, color: Color):
	score_label.text = result_text
	score_label.modulate = color
