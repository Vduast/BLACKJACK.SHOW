class_name JokerSystem
extends RefCounted

## Toda la lógica de los comodines vive aquí, separada de table.gd.
## table.gd solo llama a apply() y convierte el resultado en RPCs.

const JOKER_TYPES: Array[String] = [
	"burn", "peek", "shield", "shuffle", "prophecy",
	"sabotage", "curse", "salvation", "bury", "expose"
]

## Elige 3 comodines aleatorios para el inicio de la partida.
func roll_starting_jokers() -> Array:
	var picked: Array = []
	for i in range(3):
		picked.append(JOKER_TYPES.pick_random())
	return picked

## Aplica el efecto de un comodín.
## round_manager: instancia de RoundManager (para tocar el mazo / player_losses).
## Devuelve un Dictionary con, opcionalmente:
##   "broadcast": String a anunciar a TODOS los jugadores (rpc)
##   "whisper":   String a anunciar solo al jugador que usó el comodín (rpc_id)
func apply(effect_id: String, peer_id: int, player_name: String, round_manager: RoundManager, active_players: Array) -> Dictionary:
	var deck := round_manager.deck.cards
	var losses := round_manager.player_losses

	match effect_id:
		"burn":
			if deck.size() > 0:
				deck.pop_front()
				return {"broadcast": "🔥 %s burned the next card!" % player_name}

		"peek":
			if deck.size() > 0:
				var c = deck[0]
				return {"whisper": "👁️ Vision: %s of %s" % [c["rank"], c["suit"]]}

		"shield":
			if not losses.has(peer_id): losses[peer_id] = 0
			if losses[peer_id] > 0:
				losses[peer_id] -= 1
				return {"whisper": "🛡️ Amnesia: You removed 1 loss."}

		"shuffle":
			round_manager.deck.shuffle()
			return {"broadcast": "🔄 %s caused an Earthquake! Shuffled." % player_name}

		"prophecy":
			if deck.size() >= 3:
				var c1 = str(deck[0]["rank"])
				var c2 = str(deck[1]["rank"])
				var c3 = str(deck[2]["rank"])
				return {"whisper": "🔮 Prophecy: %s, %s, %s" % [c1, c2, c3]}

		"sabotage":
			deck.push_front({"rank": "10", "suit": "spades", "value": 10})
			return {"broadcast": "💣 %s sabotaged the deck!" % player_name}

		"curse":
			for id in active_players:
				if id != peer_id:
					if not losses.has(id): losses[id] = 0
					losses[id] += 1
			return {"broadcast": "☠️ %s cast a Curse! +1 Loss to everyone." % player_name}

		"salvation":
			if not losses.has(peer_id): losses[peer_id] = 0
			if losses[peer_id] >= 2: losses[peer_id] -= 2
			else: losses[peer_id] = 0
			return {"whisper": "👼 Salvation: Removed up to 2 losses."}

		"bury":
			if deck.size() > 0:
				var c = deck.pop_front()
				deck.push_back(c)
				return {"broadcast": "🕳️ %s buried the top card!" % player_name}

		"expose":
			if deck.size() > 0:
				var c = deck[0]
				var n = "%s of %s" % [c["rank"], c["suit"]]
				return {"broadcast": "🚨 %s sounded alarms! Next card: %s" % [player_name, n]}

	return {}
