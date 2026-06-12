extends Node

signal players_updated
signal connection_succeeded
signal connection_failed

const PORT = 8080
var peer = ENetMultiplayerPeer.new()

var players = {} 
var my_info = {"name": "Jugador", "ip": ""}
var my_id = 0
var is_in_game = false 
var is_connecting = false # <-- Aquí está la variable, global y visible para todos
var game_mode = "multiplayer"

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# --- CONEXIÓN ---
func start_singleplayer(player_name: String):
	game_mode = "singleplayer"
	host_game(player_name)
	is_in_game = true
	await Transition.fade_to_scene("res://Objetos/Table.tscn")
	
func host_game(player_name: String):
	my_info["name"] = player_name
	my_info["ip"] = get_local_ip()
	my_id = 1 
	is_in_game = false 
	
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	players[my_id] = my_info
	players_updated.emit()

func join_game(ip: String, player_name: String):
	my_info["name"] = player_name
	my_info["ip"] = get_local_ip()
	
	var err = peer.create_client(ip, PORT)
	
	if err != OK:
		call_deferred("_on_connection_failed")
		return
		
	multiplayer.multiplayer_peer = peer
	is_connecting = true
	
	# Temporizador de 5 segundos para no quedarse colgado
	await get_tree().create_timer(5.0).timeout
	
	if is_connecting:
		print("Tiempo de conexión agotado. Cancelando...")
		_on_connection_failed()

# --- EVENTOS DE RED ---

func _on_peer_connected(id: int):
	rpc_id(id, "register_player", my_info)

func _on_peer_disconnected(id: int):
	players.erase(id)
	players_updated.emit()

func _on_connected_to_server():
	is_connecting = false # Apagamos la alarma
	my_id = multiplayer.get_unique_id()
	connection_succeeded.emit()
	rpc_id(1, "register_player", my_info)

func _on_connection_failed():
	is_connecting = false # Apagamos la alarma
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

@rpc("any_peer", "reliable")
func register_player(info: Dictionary):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = info
	players_updated.emit()
	if multiplayer.is_server():
		for id in players:
			rpc("sync_players", players)

@rpc("authority", "reliable")
func sync_players(all_players: Dictionary):
	players = all_players
	players_updated.emit()

@rpc("authority", "call_local", "reliable")
func start_game():
	is_in_game = true
	await Transition.fade_to_scene("res://Objetos/Table.tscn")

# --- MIGRACIÓN DE HOST ---

func _on_server_disconnected():
	print("El Host se desconectó. Iniciando migración...")
	var remaining_ids = players.keys()
	remaining_ids.erase(1) 
	
	if remaining_ids.size() == 0:
		is_in_game = false
		players.clear()
		await Transition.fade_to_scene("res://Menus/MainMenu.tscn")
		return
		
	remaining_ids.sort()
	var new_host_id = remaining_ids[0]
	var new_host_ip = players[new_host_id].ip
	
	multiplayer.multiplayer_peer = null
	peer = ENetMultiplayerPeer.new()
	players.clear() 
	
	if my_id == new_host_id:
		host_game(my_info.name)
		if is_in_game:
			await get_tree().create_timer(3.0).timeout 
			rpc("reload_game_scene")
	else:
		await get_tree().create_timer(1.0).timeout
		join_game(new_host_ip, my_info.name)

@rpc("authority", "call_local", "reliable")
func reload_game_scene():
	get_tree().call_deferred("reload_current_scene")

# --- SISTEMA DE CÓDIGOS DE SALA (BASE62) ---

const BASE62_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

func get_local_ip() -> String:
	var ip_local = "127.0.0.1"
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172.") or ip.begins_with("25.") or ip.begins_with("26."):
			ip_local = ip
			break
	return ip_local

func ip_to_int(ip: String) -> int:
	var parts = ip.split(".")
	if parts.size() != 4: return 0
	return (int(parts[0]) << 24) + (int(parts[1]) << 16) + (int(parts[2]) << 8) + int(parts[3])

func int_to_ip(n: int) -> String:
	var p1 = (n >> 24) & 255
	var p2 = (n >> 16) & 255
	var p3 = (n >> 8) & 255
	var p4 = n & 255
	return "%d.%d.%d.%d" % [p1, p2, p3, p4]

func generate_room_code() -> String:
	var ip = get_local_ip()
	var num = ip_to_int(ip)
	if num == 0: return "ERROR"
	
	var code = ""
	while num > 0:
		var rem = num % 62
		code = BASE62_CHARS[rem] + code
		@warning_ignore("integer_division")
		num = num / 62
		
	while code.length() < 6:
		code = "0" + code
		
	return code

func decode_room_code(code: String) -> String:
	code = code.strip_edges()
	if code.length() > 6 or code.length() < 1: return ""
	
	var num: int = 0
	for i in range(code.length()):
		var char_val = BASE62_CHARS.find(code[i])
		if char_val == -1: return ""
		num = (num * 62) + char_val
		
	return int_to_ip(num)
