extends Node3D

@onready var ui = $TableUI 
@onready var players_container = $PlayersContainer
@onready var dealer_area = $TableCenter
@onready var spawn_points = $SpawnPoints
@onready var dealer = $DEALER
@onready var scoreboard_3d = $ScoreBoard3D

# --- SISTEMA DE AUDIO CENTRALIZADO (POOLING) ---
@onready var sfx_player = $sfx_player
var sfx_pool: Array = []
var sfx_index: int = 0
var max_sfx_players: int = 3 

# --- SISTEMA DE MÚSICA DINÁMICA ---
var bgm_player: AudioStreamPlayer
var is_round_ending: bool = false
var loop_start_time: float = 10.0 # 0:10
var loop_end_time: float = 65.0   # 1:05

@export_group("Efectos de Sonido")
@export var snd_bgm: AudioStream      # Tu pista musical de 1:10 mins
@export var snd_deal: AudioStream     
@export var snd_action: AudioStream   
@export var snd_shuffle: AudioStream  
@export var snd_joker: AudioStream    
@export var snd_win: AudioStream      
@export var snd_lose: AudioStream     

var player_seat_scene = preload("res://Objetos/Player.tscn")
var card_scene = preload("res://Objetos/Card3D.tscn")

var deck_cards: Array = []
var hands = {} 
var dealer_hand = []
var active_players = []
var players_done = 0
var player_losses = {}
var max_losses = 5 

var players_requesting_card = [] 
var players_stood = [] 
var players_doubled = [] 
var dealing_round = false 
var is_first_round: bool = true
var is_pvp_mode: bool = false

func _ready():
	if is_instance_valid(sfx_player):
		sfx_pool.append(sfx_player) 
		for i in range(max_sfx_players - 1):
			var new_player = sfx_player.duplicate()
			add_child(new_player)
			sfx_pool.append(new_player)
			
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	if snd_bgm: bgm_player.stream = snd_bgm
	add_child(bgm_player)
	
	ui.start_game.connect(_on_start_pressed)
	ui.hit_pressed.connect(_on_hit_pressed)
	ui.stand_pressed.connect(_on_stand_pressed)
	ui.clear_pressed.connect(_on_clear_pressed)
	ui.joker_used.connect(_on_joker_used)
	
	if ui.has_signal("double_pressed"):
		ui.double_pressed.connect(_on_double_pressed)
	
	multiplayer.server_disconnected.connect(_on_host_migrating)
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	var index = 0
	for id in NetworkManager.players:
		active_players.append(id)
		player_losses[id] = 0
		_spawn_seat_visual_local(id, index)
		index += 1
		
	if multiplayer.is_server():
		for id in active_players:
			hands[id] = []
		_build_deck()
		ui.show_start_button("Deal Cards")
	else:
		ui.hide_start_button()

	var look_timer = Timer.new()
	look_timer.wait_time = 4.0
	look_timer.autostart = true
	look_timer.timeout.connect(_on_look_timer_timeout)
	add_child(look_timer)

# --- SISTEMA DE PROTECCIÓN DE RED (Evita el Error de Dictionary) ---
func get_player_name(id: int) -> String:
	if typeof(NetworkManager.players) == TYPE_DICTIONARY:
		if NetworkManager.players.has(id):
			return NetworkManager.players[id].name
		elif NetworkManager.players.has(str(id)): # Por si se guardó como string accidentalmente
			return NetworkManager.players[str(id)].name
	return "Player " + str(id)

# --- VIGILANCIA DE MÚSICA (LOOP DINÁMICO) ---
func _process(delta):
	if is_instance_valid(bgm_player) and bgm_player.playing:
		var pos = bgm_player.get_playback_position()
		if not is_round_ending and pos >= loop_end_time:
			bgm_player.seek(loop_start_time)

func play_sfx(stream: AudioStream, randomize_pitch: bool = true):
	if stream == null or sfx_pool.is_empty(): return
	var current_player = sfx_pool[sfx_index]
	current_player.stop() 
	current_player.stream = stream
	if randomize_pitch: current_player.pitch_scale = randf_range(0.85, 1.15)
	else: current_player.pitch_scale = 1.0
	current_player.play()
	sfx_index = (sfx_index + 1) % max_sfx_players

func _on_peer_disconnected(id: int):
	if not multiplayer.is_server(): return
	if id in active_players:
		active_players.erase(id)
		if id in players_stood: players_stood.erase(id)
		else: players_done += 1
		if players_done >= active_players.size() and active_players.size() > 0:
			if is_pvp_mode: evaluate_winners_pvp()
			else: play_dealer_turn()
		elif active_players.size() == 0:
			ui.show_full_restart_button()

func _on_look_timer_timeout(): _make_dealer_look_at_random_player()

func _make_dealer_look_at_random_player():
	if active_players.size() > 0 and is_instance_valid(dealer):
		var random_id = active_players.pick_random()
		if players_container.has_node(str(random_id)):
			dealer.look_at_target(players_container.get_node(str(random_id)))

func _on_host_migrating():
	ui.set_status("Host disconnected! Rescuing the table...")
	ui.hide_game_panel()
	ui.hide_start_button()
	ui.hide_clear_button()

func _spawn_seat_visual_local(id: int, index: int):
	if players_container.has_node(str(id)): return
	var seat = player_seat_scene.instantiate()
	seat.name = str(id)
	players_container.add_child(seat)
	if seat.has_method("setup"): seat.setup(id)
	_position_seat(seat, index)
	update_all_cameras()

func _position_seat(seat, index):
	var points = spawn_points.get_children()
	if index < points.size(): seat.global_position = points[index].global_position
	else: seat.global_position = Vector3((index * 3), 0, 5)
	var target_look = dealer_area.global_position
	target_look.y = seat.global_position.y
	seat.look_at(target_look, Vector3.UP)

func update_all_cameras():
	await get_tree().process_frame 
	var seats = players_container.get_children()
	for seat in seats:
		if seat.has_method("adjust_camera"):
			seat.adjust_camera(seats, dealer_area.global_position)

func _on_clear_pressed():
	if multiplayer.is_server():
		ui.hide_clear_button()
		ui.hide_start_button()
		rpc("prepare_for_new_round", active_players.is_empty())
		rpc("animate_table_cleanup")
		await animate_table_cleanup()
		ui.show_start_button("Deal Cards")

@rpc("authority", "call_local")
func prepare_for_new_round(is_full_restart: bool = false):
	ui.hide_game_panel()
	ui.set_status("Preparing table...")
	play_sfx(snd_shuffle, false)
	
	is_round_ending = false
	if is_instance_valid(bgm_player):
		if is_full_restart or not bgm_player.playing:
			bgm_player.play(0.0)

func _on_start_pressed():
	if not multiplayer.is_server(): return
	if dealing_round: return 
	dealing_round = true
	ui.hide_start_button()
	ui.hide_clear_button()
	
	if active_players.is_empty():
		for id in NetworkManager.players:
			active_players.append(id)
			player_losses[id] = 0
		is_first_round = true 
		
	is_pvp_mode = (NetworkManager.players.size() > 1)
	
	rpc("prepare_for_new_round", is_first_round)
	
	for id in NetworkManager.players:
		if not id in active_players:
			rpc("show_individual_result", id, "ELIMINATED!", Color(0.3, 0.3, 0.3))
			
	rpc("animate_table_cleanup") 
	await animate_table_cleanup() 
	
	dealer_hand.clear()
	players_done = 0
	players_stood.clear()
	players_requesting_card.clear()
	players_doubled.clear() 
	_build_deck()
	
	for id in active_players:
		if not hands.has(id): hands[id] = []
		else: hands[id].clear() 
		if not player_losses.has(id): player_losses[id] = 0 # Seguro de protección
		
	if is_first_round:
		var joker_types = ["burn", "peek", "shield", "shuffle", "prophecy", "sabotage", "curse", "salvation", "bury", "expose"]
		for id in active_players:
			var my_jokers = []
			for i in range(3): my_jokers.append(joker_types.pick_random()) 
			rpc_id(id, "receive_jokers_ui", my_jokers)
		is_first_round = false 
		
	update_scoreboard_logic()
	rpc("announce_global_result", "Dealing cards...")
	
	for round_num in range(2): 
		for id in active_players:
			deal_card(id, false)
			await get_tree().create_timer(0.35).timeout 
		if not is_pvp_mode:
			var is_hole_card = (round_num == 1)
			deal_card(0, is_hole_card)
			await get_tree().create_timer(0.5).timeout 
			
	dealing_round = false
	if not is_pvp_mode and calculate_score(dealer_hand) == 21:
		rpc("announce_global_result", "¡EL DEALER TIENE BLACKJACK!")
		rpc("reveal_dealer_hole_card")
		await get_tree().create_timer(1.5).timeout 
		for id in active_players:
			player_finished_turn(id) 
		return
		
	rpc("start_game_clients", active_players)
	for id in active_players:
		if calculate_score(hands.get(id, [])) == 21:
			player_finished_turn(id)

@rpc("authority", "call_remote")
func animate_table_cleanup():
	if is_instance_valid(dealer):
		var dealer_cards = []
		for card in get_tree().get_nodes_in_group("cartas"):
			if is_instance_valid(card) and card.get_parent() == dealer_area:
				dealer_cards.append(card)
		if dealer_cards.size() > 0:
			_make_dealer_look_at_random_player()
			dealer.deal_to_position(dealer_area.global_position)
			await get_tree().create_timer(0.3).timeout 
			for c in dealer_cards:
				if is_instance_valid(c): c.desaparecer() 
			await get_tree().create_timer(0.4).timeout 
		for seat in players_container.get_children():
			var seat_cards = []
			for card in get_tree().get_nodes_in_group("cartas"):
				if is_instance_valid(card) and seat.is_ancestor_of(card):
					seat_cards.append(card)
			if seat_cards.size() > 0:
				var target_pos = seat.global_position
				if "card_position" in seat and is_instance_valid(seat.card_position):
					target_pos = seat.card_position.global_position
				dealer.look_at_target(seat) 
				dealer.deal_to_position(target_pos)
				await get_tree().create_timer(0.3).timeout
				for c in seat_cards:
					if is_instance_valid(c): c.desaparecer()
				await get_tree().create_timer(0.4).timeout 
		_make_dealer_look_at_random_player()
	else:
		var all_cards = get_tree().get_nodes_in_group("cartas")
		for card in all_cards:
			if is_instance_valid(card): card.desaparecer()
	for seat in players_container.get_children():
		if seat.has_method("reset_ui"): seat.reset_ui()

@rpc("authority", "call_local")
func start_game_clients(current_active: Array):
	var my_id = multiplayer.get_unique_id()
	if my_id in current_active:
		ui.transition_to_game("Your turn! Hit, Stand or Double.")
		ui.hit_button.disabled = false
		ui.stand_button.disabled = false
		if "double_button" in ui and ui.double_button:
			ui.double_button.disabled = false
			ui.double_button.visible = true
	else:
		ui.set_status("You are eliminated. Spectating...")
		ui.hide_game_panel()
		ui.hide_start_button()
		ui.hide_clear_button()

func _build_deck():
	deck_cards.clear()
	var suits = ["hearts", "diamonds", "clubs", "spades"]
	var ranks = {"A":11, "2":2, "3":3, "4":4, "5":5, "6":6, "7":7, "8":8, "9":9, "10":10, "J":10, "Q":10, "K":10}
	for suit in suits:
		for rank in ranks.keys():
			deck_cards.append({"rank": rank, "suit": suit, "value": ranks[rank]})
	deck_cards.shuffle()

func deal_card(target_id: int, is_hidden: bool = false):
	if deck_cards.is_empty(): 
		_build_deck()
		rpc("announce_global_result", "Reshuffling deck...")
	var card = deck_cards.pop_front()
	if target_id == 0:
		dealer_hand.append(card)
		rpc("sync_card_visual", 0, card, dealer_hand.size(), is_hidden)
		if not is_hidden and is_instance_valid(scoreboard_3d): update_scoreboard_logic() 
	else:
		if not hands.has(target_id): hands[target_id] = []
		hands[target_id].append(card)
		rpc("sync_card_visual", target_id, card, hands[target_id].size(), false)
		var score = calculate_score(hands[target_id])
		rpc("update_player_score", target_id, score)
		update_scoreboard_logic()

func calculate_score(hand: Array) -> int:
	var score = 0
	var aces = 0
	for card in hand:
		if card["rank"] in ["J", "Q", "K"]: score += 10
		elif card["rank"] == "A":
			aces += 1
			score += 11
		else: score += int(card["rank"])
	while score > 21 and aces > 0:
		score -= 10
		aces -= 1
	return score

func _on_double_pressed():
	play_sfx(snd_action, false) 
	ui.hit_button.disabled = true
	ui.stand_button.disabled = true
	if "double_button" in ui: ui.double_button.disabled = true
	rpc_id(1, "request_double")

@rpc("any_peer", "call_local")
func request_double():
	if not multiplayer.is_server(): return
	var peer_id = multiplayer.get_remote_sender_id()
	if dealing_round: return 
	if not peer_id in active_players: return 
	if peer_id in players_stood: return 
	if not hands.has(peer_id) or hands[peer_id].size() != 2: return
	if peer_id in players_requesting_card: return 
	players_requesting_card.append(peer_id)
	players_doubled.append(peer_id)
	
	rpc("announce_global_result", get_player_name(peer_id) + " Dobló su apuesta!")
	
	deal_card(peer_id)
	await get_tree().create_timer(0.6).timeout
	player_finished_turn(peer_id)
	players_requesting_card.erase(peer_id)

func _on_hit_pressed():
	play_sfx(snd_action, false) 
	ui.hit_button.disabled = true
	if "double_button" in ui: ui.double_button.disabled = true 
	rpc_id(1, "request_hit")
	await get_tree().create_timer(0.6).timeout
	if ui.game_panel.visible and not (multiplayer.get_unique_id() in players_stood): 
		ui.hit_button.disabled = false

@rpc("any_peer", "call_local")
func request_hit():
	if not multiplayer.is_server(): return
	var peer_id = multiplayer.get_remote_sender_id()
	if dealing_round: return 
	if not peer_id in active_players: return 
	if peer_id in players_stood: return 
	if not hands.has(peer_id): hands[peer_id] = []
	if calculate_score(hands[peer_id]) >= 21:
		player_finished_turn(peer_id)
		return
	if peer_id in players_requesting_card: return 
	players_requesting_card.append(peer_id)
	deal_card(peer_id)
	await get_tree().create_timer(0.5).timeout 
	if calculate_score(hands[peer_id]) >= 21:
		player_finished_turn(peer_id)
	players_requesting_card.erase(peer_id)
			
func _on_stand_pressed():
	play_sfx(snd_action, false) 
	rpc_id(1, "request_stand")

@rpc("any_peer", "call_local")
func request_stand():
	if not multiplayer.is_server(): return
	var peer_id = multiplayer.get_remote_sender_id()
	if dealing_round: return 
	if not peer_id in active_players: return 
	player_finished_turn(peer_id)

func player_finished_turn(peer_id: int):
	if peer_id in players_stood: return
	players_stood.append(peer_id)
	players_done += 1
	rpc_id(peer_id, "force_stand_ui") 
	if players_done >= active_players.size():
		if is_pvp_mode: evaluate_winners_pvp()
		else: play_dealer_turn()

@rpc("authority", "call_local")
func force_stand_ui():
	ui.hide_game_panel()
	ui.set_status("Waiting for others...")

@rpc("authority", "call_local")
func reveal_dealer_hole_card():
	for c in dealer_area.get_children():
		if abs(c.rotation_degrees.z) > 170 or abs(c.rotation_degrees.x) > 170:
			var tween = create_tween()
			var target_rot = c.rotation_degrees
			target_rot.z = 0 
			target_rot.x = -90 
			tween.tween_property(c, "rotation_degrees", target_rot, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func play_dealer_turn():
	rpc("announce_dealer_turn")
	rpc("reveal_dealer_hole_card")
	await get_tree().create_timer(0.8).timeout 
	update_scoreboard_logic() 
	var dealer_score = calculate_score(dealer_hand)
	while dealer_score < 17:
		await get_tree().create_timer(0.6).timeout 
		deal_card(0)
		dealer_score = calculate_score(dealer_hand)
	await get_tree().create_timer(0.8).timeout 
	evaluate_winners_pve(dealer_score)

@rpc("authority", "call_local")
func announce_dealer_turn(): ui.set_status("Dealer's turn...")

func evaluate_winners_pvp():
	var highest_score = 0
	var winners_names = []
	var tie_names = []
	var just_eliminated = []
	
	for id in active_players:
		if not hands.has(id): hands[id] = []
		var p_score = calculate_score(hands[id])
		if p_score <= 21 and p_score > highest_score: highest_score = p_score
			
	for id in active_players:
		if not hands.has(id): hands[id] = []
		if not player_losses.has(id): player_losses[id] = 0
		
		var p_score = calculate_score(hands[id])
		var is_blackjack = (p_score == 21 and hands[id].size() == 2)
		var damage_multiplier = 2 if id in players_doubled else 1 
		var result = ""
		var color = Color.WHITE
		
		if p_score > 21:
			player_losses[id] += (1 * damage_multiplier)
			result = "Bust (%d/%d)" % [player_losses[id], max_losses]
			if damage_multiplier > 1: result = "¡Doble Bust!"
			color = Color(1, 0, 0)
		elif p_score == highest_score:
			var count_ties = 0
			for other_id in active_players:
				if calculate_score(hands.get(other_id, [])) == highest_score: count_ties += 1
			if count_ties > 1:
				result = "Empate"
				color = Color(1, 1, 0)
				tie_names.append(get_player_name(id))
			else:
				result = "¡Ganaste!"
				color = Color(0, 1, 0)
				winners_names.append(get_player_name(id))
				if is_blackjack:
					if player_losses[id] > 0: player_losses[id] -= 1
					result = "¡BLACKJACK!"
					color = Color(1, 0.84, 0)
		else:
			player_losses[id] += (1 * damage_multiplier)
			result = "Perdiste (%d/%d)" % [player_losses[id], max_losses]
			if damage_multiplier > 1: result = "¡Doble Pérdida!"
			color = Color(1, 0, 0)
			
		if player_losses[id] >= max_losses:
			result = "ELIMINADO!"
			color = Color(0.3, 0.3, 0.3) 
			just_eliminated.append(id)
			
		rpc("show_individual_result", id, result, color)
		
	_finalize_round(winners_names, tie_names, just_eliminated, "¡Ronda Multijugador Terminada!")

func evaluate_winners_pve(dealer_score: int):
	var winners_names = []
	var tie_names = []
	var just_eliminated = [] 
	
	for id in active_players:
		if not hands.has(id): hands[id] = []
		if not player_losses.has(id): player_losses[id] = 0 # <-- PROTECCIÓN CONTRA EL ERROR DE DICIONARIO
		
		var p_score = calculate_score(hands[id])
		var is_blackjack = (p_score == 21 and hands[id].size() == 2)
		var dealer_is_blackjack = (dealer_score == 21 and dealer_hand.size() == 2)
		var damage_multiplier = 2 if id in players_doubled else 1 
		var result = ""
		var color = Color.WHITE
		
		if is_blackjack and not dealer_is_blackjack:
			if player_losses[id] > 0: player_losses[id] -= 1
			result = "¡BLACKJACK!"
			color = Color(1, 0.84, 0) 
			winners_names.append(get_player_name(id))
		elif p_score > 21:
			player_losses[id] += (1 * damage_multiplier)
			result = "Bust (%d/%d)" % [player_losses[id], max_losses]
			if damage_multiplier > 1: result = "¡Doble Bust!"
			color = Color(1, 0, 0)
		elif dealer_score > 21:
			result = "You win!"
			color = Color(0, 1, 0)
			winners_names.append(get_player_name(id))
		elif p_score > dealer_score:
			result = "You win!"
			color = Color(0, 1, 0)
			winners_names.append(get_player_name(id))
		elif p_score < dealer_score:
			player_losses[id] += (1 * damage_multiplier)
			result = "You lose (%d/%d)" % [player_losses[id], max_losses]
			if damage_multiplier > 1: result = "¡Doble Pérdida!"
			color = Color(1, 0, 0)
		else:
			result = "Push (Empate)"
			color = Color(1, 1, 0) 
			tie_names.append(get_player_name(id))
			
		if player_losses[id] >= max_losses:
			result = "ELIMINATED!"
			color = Color(0.3, 0.3, 0.3) 
			just_eliminated.append(id)
			
		rpc("show_individual_result", id, result, color)
		
	var default_msg = "Dealer wins the round!"
	if dealer_score > 21: default_msg = "Dealer Busts! Surviving players win."
	_finalize_round(winners_names, tie_names, just_eliminated, default_msg)

func _finalize_round(winners_names: Array, tie_names: Array, just_eliminated: Array, default_msg: String):
	for id in just_eliminated: active_players.erase(id)
	var global_message = ""
	if active_players.is_empty(): global_message = "Everyone was eliminated! The Casino wins."
	elif winners_names.size() > 0: global_message = "Winner(s): " + ", ".join(PackedStringArray(winners_names)) + "!"
	elif tie_names.size() > 0:
		if is_pvp_mode: global_message = "Empate entre: " + ", ".join(PackedStringArray(tie_names))
		else: global_message = "Push with Dealer: " + ", ".join(PackedStringArray(tie_names))
	else: global_message = default_msg
		
	rpc("announce_global_result", global_message)
	if active_players.size() > 0:
		update_scoreboard_logic()
		rpc_id(1, "show_restart_button")
	else:
		update_scoreboard_logic()
		rpc_id(1, "show_full_restart_button")

func trigger_outro_music():
	is_round_ending = true
	if is_instance_valid(bgm_player) and bgm_player.playing:
		if bgm_player.get_playback_position() < loop_end_time:
			bgm_player.seek(loop_end_time)

@rpc("authority", "call_local")
func show_restart_button():
	ui.show_start_button("Next Round")
	ui.show_clear_button()
	
@rpc("authority", "call_local")
func show_full_restart_button():
	ui.show_start_button("Restart Full Game")
	ui.show_clear_button()
	trigger_outro_music() 

@rpc("authority", "call_local")
func show_individual_result(target_id: int, result_text: String, color: Color):
	if players_container.has_node(str(target_id)):
		players_container.get_node(str(target_id)).set_result(result_text, color)
	if target_id == multiplayer.get_unique_id():
		var txt = result_text.to_lower()
		if "win" in txt or "ganaste" in txt or "blackjack" in txt: play_sfx(snd_win, false)
		elif "lose" in txt or "perdiste" in txt or "bust" in txt or "eliminado" in txt: play_sfx(snd_lose, false)

@rpc("authority", "call_local")
func announce_global_result(message: String):
	ui.set_status(message)
	if is_instance_valid(scoreboard_3d): scoreboard_3d.show_temporary_status(message)
	if is_instance_valid(dealer):
		dealer.speak(true) 
		get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(dealer): dealer.speak(false))

@rpc("authority", "call_local")
func sync_card_visual(target_id: int, card_data: Dictionary, card_index: int, is_hidden: bool = false):
	play_sfx(snd_deal)
	var card_instance = card_scene.instantiate()
	var target_pos: Vector3
	var espaciado_x = 0.15 
	var espaciado_y = 0.01
	var offset = Vector3((card_index - 1) * espaciado_x, (card_index - 1) * espaciado_y, 0)
	
	if target_id == 0:
		dealer_area.add_child(card_instance)
		card_instance.set_card(card_data)
		target_pos = offset 
		if is_instance_valid(dealer):
			_make_dealer_look_at_random_player()
			dealer.deal_to_position(dealer_area.to_global(target_pos))
	else:
		if players_container.has_node(str(target_id)):
			var seat = players_container.get_node(str(target_id))
			seat.add_visual_card(card_instance)
			card_instance.set_card(card_data)
			target_pos = seat.card_position.position + offset 
			if is_instance_valid(dealer):
				dealer.look_at_target(seat) 
				dealer.deal_to_position(seat.to_global(target_pos))

	var rotacion_nativa = card_instance.rotation_degrees
	card_instance.position = Vector3(0, 5, -2) 
	card_instance.rotation_degrees = rotacion_nativa + Vector3(0, 0, 180) 
	var tween = create_tween().set_parallel(true)
	tween.tween_property(card_instance, "position", target_pos, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not is_hidden:
		tween.tween_property(card_instance, "rotation_degrees", rotacion_nativa, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

@rpc("authority", "call_local")
func update_player_score(target_id: int, score: int):
	if players_container.has_node(str(target_id)):
		players_container.get_node(str(target_id)).update_score_display(score)
		
# --- JOKERS SYSTEM ---
@rpc("authority", "call_local")
func receive_jokers_ui(joker_list: Array):
	ui.spawn_jokers(joker_list)

func _on_joker_used(effect_id: String):
	play_sfx(snd_joker, false) 
	rpc_id(1, "request_use_joker", effect_id)

@rpc("any_peer", "call_local")
func request_use_joker(effect_id: String):
	if not multiplayer.is_server(): return
	var peer_id = multiplayer.get_remote_sender_id()
	if dealing_round: return 
	if not peer_id in active_players: return 
	
	var player_name = get_player_name(peer_id)
	
	match effect_id:
		"burn": 
			if deck_cards.size() > 0:
				deck_cards.pop_front()
				rpc("announce_global_result", "🔥 " + player_name + " burned the next card!")
		"peek": 
			if deck_cards.size() > 0:
				var next_card = deck_cards[0]
				var card_name = str(next_card["rank"]) + " of " + next_card["suit"]
				rpc_id(peer_id, "announce_global_result", "👁️ Vision: " + card_name)
		"shield": 
			if not player_losses.has(peer_id): player_losses[peer_id] = 0
			if player_losses[peer_id] > 0:
				player_losses[peer_id] -= 1
				rpc_id(peer_id, "announce_global_result", "🛡️ Amnesia: You removed 1 loss.")
		"shuffle": 
			deck_cards.shuffle()
			rpc("announce_global_result", "🔄 " + player_name + " caused an Earthquake! Shuffled.")
		"prophecy": 
			if deck_cards.size() >= 3:
				var c1 = str(deck_cards[0]["rank"])
				var c2 = str(deck_cards[1]["rank"])
				var c3 = str(deck_cards[2]["rank"])
				rpc_id(peer_id, "announce_global_result", "🔮 Prophecy: " + c1 + ", " + c2 + ", " + c3)
		"sabotage": 
			deck_cards.push_front({"rank": "10", "suit": "spades", "value": 10})
			rpc("announce_global_result", "💣 " + player_name + " sabotaged the deck!")
		"curse": 
			for id in active_players:
				if id != peer_id: 
					if not player_losses.has(id): player_losses[id] = 0
					player_losses[id] += 1
			rpc("announce_global_result", "☠️ " + player_name + " cast a Curse! +1 Loss to everyone.")
		"salvation": 
			if not player_losses.has(peer_id): player_losses[peer_id] = 0
			if player_losses[peer_id] >= 2: player_losses[peer_id] -= 2
			else: player_losses[peer_id] = 0
			rpc_id(peer_id, "announce_global_result", "👼 Salvation: Removed up to 2 losses.")
		"bury": 
			if deck_cards.size() > 0:
				var card = deck_cards.pop_front()
				deck_cards.push_back(card)
				rpc("announce_global_result", "🕳️ " + player_name + " buried the top card!")
		"expose": 
			if deck_cards.size() > 0:
				var c = deck_cards[0]
				var n = str(c["rank"]) + " of " + c["suit"]
				rpc("announce_global_result", "🚨 " + player_name + " sounded alarms! Next card: " + n)
				
# --- 3D SCREEN SYSTEM ---
func update_scoreboard_logic():
	if not multiplayer.is_server(): return
	var data = []
	for id in active_players:
		var p_name = get_player_name(id)
		var lives = max_losses - player_losses.get(id, 0)
		var score = 0
		if hands.has(id): score = calculate_score(hands[id])
		data.append({"name": p_name, "lives": lives, "score": score})
	var visible_dealer_score = 0
	if not is_pvp_mode and dealer_hand.size() > 0:
		if players_done >= active_players.size(): visible_dealer_score = calculate_score(dealer_hand)
		else: visible_dealer_score = calculate_score([dealer_hand[0]])
	rpc("sync_scoreboard", data, visible_dealer_score)

@rpc("authority", "call_local")
func sync_scoreboard(data: Array, dealer_visible_score: int = 0):
	if is_instance_valid(scoreboard_3d): scoreboard_3d.refresh_board(data, dealer_visible_score)
