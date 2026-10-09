class_name JokerSystem
extends RefCounted

## Toda la lógica de los comodines vive aquí, separada de table.gd.
## table.gd solo llama a apply() y convierte el resultado en RPCs.

const JOKER_TYPES: Array[String] = [
	"burn", "peek", "shield", "shuffle", "prophecy",
	"sabotage", "curse", "salvation", "bury", "expose",
	# --- NUEVOS COMODINES ---
	"ace", "low_blow", "roulette", "vampire", "mirror", "famine"
]

## Elige 3 comodines aleatorios para el inicio de la partida.
func roll_starting_jokers(count: int = 3) -> Array[String]:
	var picked: Array[String] = []
	for i in range(count):
		picked.append(JOKER_TYPES.pick_random())
	return picked

## Aplica el efecto de un comodín.
## Devuelve un Dictionary con:
##   "broadcast": String anunciado a TODOS (rpc)
##   "whisper":   String anunciado solo al usuario (rpc_id)
func apply(effect_id: String, peer_id: int, player_name: String, round_manager, active_players: Array) -> Dictionary:
	var deck: Array = round_manager.deck_cards if "deck_cards" in round_manager else round_manager.deck.cards
	var losses: Dictionary = round_manager.player_losses
	var is_pvp: bool = active_players.size() > 1
	var max_l: int = round_manager.max_losses if "max_losses" in round_manager else 5

	if not losses.has(peer_id):
		losses[peer_id] = 0

	match effect_id:
		# ========================================================
		# 1. INFORMACIÓN Y CONTROL DEL MAZO (Equilibrados)
		# ========================================================
		"peek":
			if deck.size() > 0:
				var c = deck[0]
				return {"whisper": "👁️ Visión: La siguiente carta es un %s de %s." % [c["rank"], c["suit"]]}

		"prophecy":
			if deck.size() >= 3:
				var c1 = str(deck[0]["rank"])
				var c2 = str(deck[1]["rank"])
				var c3 = str(deck[2]["rank"])
				return {"whisper": "🔮 Profecía: Próximas cartas -> [%s, %s, %s]" % [c1, c2, c3]}

		"expose":
			if deck.size() > 0:
				var c = deck[0]
				return {"broadcast": "🚨 %s reveló la cima del mazo: ¡%s de %s!" % [player_name, c["rank"], c["suit"]]}

		"burn":
			if deck.size() > 0:
				deck.pop_front()
				return {"broadcast": "🔥 %s quemó la carta de la cima." % player_name}

		"bury":
			if deck.size() > 0:
				var c = deck.pop_front()
				deck.push_back(c)
				return {"broadcast": "🕳️ %s enterró la carta de la cima al fondo." % player_name}

		"shuffle":
			if "deck" in round_manager and round_manager.deck.has_method("shuffle"):
				round_manager.deck.shuffle()
			else:
				deck.shuffle()
			return {"broadcast": "🔄 ¡%s provocó un terremoto y barajó el mazo!" % player_name}

		# ========================================================
		# 2. INYECCIÓN DE CARTAS (Ataque y Salvación Numérica)
		# ========================================================
		"sabotage":
			# Pone un 10 arriba (ideal para hacer reventar al siguiente o al dealer)
			deck.push_front({"rank": "10", "suit": "spades", "value": 10})
			return {"broadcast": "💣 %s saboteó el mazo colocando un 10 arriba." % player_name}

		"ace": # NUEVO
			# El As es la carta más flexible (vale 1 u 11)
			deck.push_front({"rank": "A", "suit": "spades", "value": 11})
			return {"broadcast": "🃏 %s deslizó un As en la cima del mazo." % player_name}

		"low_blow": # NUEVO
			# Pone un 2 arriba (salvación perfecta para llegar a 21 cuando estás en 19)
			deck.push_front({"rank": "2", "suit": "hearts", "value": 2})
			return {"broadcast": "🩸 %s preparó una carta baja (2) en el mazo." % player_name}

		"mirror": # NUEVO
			# Duplica la carta de arriba si hay cartas
			if deck.size() > 0:
				deck.push_front(deck[0].duplicate())
				return {"broadcast": "🪞 %s clonó la carta en la cima del mazo." % player_name}

		"famine": # NUEVO
			# Quema 2 cartas de golpe (rompe las predicciones de Profecía de rivales)
			var burned = 0
			for i in range(2):
				if deck.size() > 0:
					deck.pop_front()
					burned += 1
			return {"broadcast": "🌪️ Hambruna: %s incineró las próximas %d cartas." % [player_name, burned]}

		# ========================================================
		# 3. VIDAS Y CASTIGOS (Balance Dinámico PvE / PvP)
		# ========================================================
		"shield":
			# REBALANCEO: Solo cura si tienes derrotas acumuladas
			if losses[peer_id] > 0:
				losses[peer_id] -= 1
				return {"whisper": "🛡️ Amnesia: Curaste 1 derrota. Te quedan %d/%d." % [losses[peer_id], max_l]}
			return {"whisper": "🛡️ Amnesia: Tu mente ya está despejada (0 derrotas)."}

		"salvation":
			# REBALANCEO: Solo usable en situación crítica (3 o más derrotas)
			if losses[peer_id] >= 3:
				losses[peer_id] = maxi(0, losses[peer_id] - 2)
				return {"broadcast": "👼 ¡Milagro! %s usó Salvación y recuperó 2 vidas." % player_name}
			elif losses[peer_id] > 0:
				losses[peer_id] -= 1
				return {"whisper": "👼 Salvación: Solo curaste 1 derrota (se potencian al estar en peligro)."}
			return {"whisper": "👼 Salvación: No hay heridas mortales que sanar."}

		"curse":
			# REBALANCEO: 
			# En PvP castiga únicamente al LÍDER (el que tiene menos derrotas) como catch-up.
			# En PvE embosca al Dealer colocando un 10 pesado arriba.
			if is_pvp:
				var best_player = -1
				var min_losses = 999
				for id in active_players:
					if id != peer_id:
						var l = losses.get(id, 0)
						if l < min_losses:
							min_losses = l
							best_player = id
				if best_player != -1:
					losses[best_player] += 1
					var victim_name = "Player %d" % best_player
					if "get_player_name" in round_manager:
						victim_name = round_manager.get_player_name(best_player)
					return {"broadcast": "☠️ Maldición: %s castigó al líder (%s) con +1 Derrota." % [player_name, victim_name]}
			else:
				# En PvE: Sabotea directamente la mano del Dealer
				deck.push_front({"rank": "10", "suit": "spades", "value": 10})
				return {"broadcast": "☠️ %s maldijo al Dealer con un peso muerto (10)." % player_name}

		"vampire": # NUEVO
			# Roba 1 vida del jugador que más tiene y te la da a ti
			if is_pvp:
				var target_victim = -1
				var min_l = 999
				for id in active_players:
					if id != peer_id:
						var l = losses.get(id, 0)
						if l < min_l:
							min_l = l
							target_victim = id
				if target_victim != -1 and losses[peer_id] > 0:
					losses[peer_id] -= 1
					losses[target_victim] += 1
					var v_name = "Player %d" % target_victim
					if "get_player_name" in round_manager:
						v_name = round_manager.get_player_name(target_victim)
					return {"broadcast": "🧛 %s drenó 1 vida de %s." % [player_name, v_name]}
				elif losses[peer_id] == 0 and target_victim != -1:
					losses[target_victim] += 1
					return {"broadcast": "🧛 %s mordió a un rival causándole 1 Derrota." % player_name}
			else:
				# En PvE: Absorbe energía del casino
				if losses[peer_id] > 0:
					losses[peer_id] -= 1
					return {"whisper": "🧛 Drenaje: Absorbiste la suerte del Dealer (-1 Derrota)."}
				return {"whisper": "🧛 Drenaje: Estás al máximo de salud."}

		"roulette": # NUEVO
			# Ruleta Rusa: 50% de curar 1 vida / 50% de recibir 1 daño
			if randf() < 0.5:
				losses[peer_id] += 1
				return {"broadcast": "💥 ¡BANG! %s perdió en la Ruleta Rusa (+1 Derrota)." % player_name}
			else:
				losses[peer_id] = maxi(0, losses[peer_id] - 1)
				return {"broadcast": "🕊️ *Click*... %s sobrevivió a la Ruleta Rusa (-1 Derrota)." % player_name}

	return {}
