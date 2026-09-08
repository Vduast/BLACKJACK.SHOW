class_name RoundManager
extends RefCounted

## Estado y reglas del blackjack: mazo, manos, derrotas y evaluación de rondas.
## No sabe nada de red ni de UI — table.gd es quien decide qué RPC mandar
## con la información que este objeto le devuelve.

var deck := Deck.new()
var hands: Dictionary = {}          # { peer_id: Array[Dictionary] }
var dealer_hand: Array = []
var player_losses: Dictionary = {}  # { peer_id: int }
var players_doubled: Array = []     # peer_ids que doblaron esta ronda
var max_losses: int = 5

func build_deck() -> void:
	deck.build_deck()
	deck.shuffle()

## Prepara el estado para una nueva ronda: limpia manos, mano del dealer,
## dobles, y asegura que cada jugador activo tenga un contador de derrotas.
func reset_for_round(active_players: Array) -> void:
	dealer_hand.clear()
	players_doubled.clear()
	for id in active_players:
		hands[id] = []
		if not player_losses.has(id):
			player_losses[id] = 0

func draw_card() -> Dictionary:
	if deck.cards.is_empty():
		build_deck()
	return deck.draw_card()

func deal_to_dealer() -> Dictionary:
	var card := draw_card()
	dealer_hand.append(card)
	return card

func deal_to_player(id: int) -> Dictionary:
	var card := draw_card()
	if not hands.has(id):
		hands[id] = []
	hands[id].append(card)
	return card

func calculate_score(hand: Array) -> int:
	var score := 0
	var aces := 0
	for card in hand:
		if card["rank"] in ["J", "Q", "K"]:
			score += 10
		elif card["rank"] == "A":
			aces += 1
			score += 11
		else:
			score += int(card["rank"])
	while score > 21 and aces > 0:
		score -= 10
		aces -= 1
	return score

func score_of(id: int) -> int:
	return calculate_score(hands.get(id, []))

func dealer_score() -> int:
	return calculate_score(dealer_hand)

## Evalúa la ronda contra el dealer (modo un jugador / cooperativo).
## Devuelve: { results: [{id, result, color}], winners: [ids], ties: [ids],
##            eliminated: [ids], default_msg: String }
func evaluate_pve(active_players: Array) -> Dictionary:
	var d_score := dealer_score()
	var dealer_is_blackjack: bool = (d_score == 21 and dealer_hand.size() == 2)

	var results: Array = []
	var winners: Array = []
	var ties: Array = []
	var eliminated: Array = []

	for id in active_players:
		if not hands.has(id): hands[id] = []
		if not player_losses.has(id): player_losses[id] = 0

		var p_score := score_of(id)
		var is_blackjack: bool = (p_score == 21 and hands[id].size() == 2)
		var damage := 2 if id in players_doubled else 1
		var result := ""
		var color := Color.WHITE

		if is_blackjack and not dealer_is_blackjack:
			if player_losses[id] > 0: player_losses[id] -= 1
			result = "¡BLACKJACK!"
			color = Color(1, 0.84, 0)
			winners.append(id)
		elif p_score > 21:
			player_losses[id] += damage
			result = "¡Doble Bust!" if damage > 1 else "Bust (%d/%d)" % [player_losses[id], max_losses]
			color = Color(1, 0, 0)
		elif d_score > 21 or p_score > d_score:
			result = "You win!"
			color = Color(0, 1, 0)
			winners.append(id)
		elif p_score < d_score:
			player_losses[id] += damage
			result = "¡Doble Pérdida!" if damage > 1 else "You lose (%d/%d)" % [player_losses[id], max_losses]
			color = Color(1, 0, 0)
		else:
			result = "Push (Empate)"
			color = Color(1, 1, 0)
			ties.append(id)

		if player_losses[id] >= max_losses:
			result = "ELIMINATED!"
			color = Color(0.3, 0.3, 0.3)
			eliminated.append(id)

		results.append({"id": id, "result": result, "color": color})

	var default_msg := "Dealer Busts! Surviving players win." if d_score > 21 else "Dealer wins the round!"
	return {
		"results": results, "winners": winners, "ties": ties,
		"eliminated": eliminated, "default_msg": default_msg
	}

## Evalúa la ronda entre jugadores (modo PvP).
func evaluate_pvp(active_players: Array) -> Dictionary:
	var highest := 0
	for id in active_players:
		if not hands.has(id): hands[id] = []
		var s := score_of(id)
		if s <= 21 and s > highest: highest = s

	var results: Array = []
	var winners: Array = []
	var ties: Array = []
	var eliminated: Array = []

	for id in active_players:
		if not hands.has(id): hands[id] = []
		if not player_losses.has(id): player_losses[id] = 0

		var p_score := score_of(id)
		var is_blackjack: bool = (p_score == 21 and hands[id].size() == 2)
		var damage := 2 if id in players_doubled else 1
		var result := ""
		var color := Color.WHITE

		if p_score > 21:
			player_losses[id] += damage
			result = "¡Doble Bust!" if damage > 1 else "Bust (%d/%d)" % [player_losses[id], max_losses]
			color = Color(1, 0, 0)
		elif p_score == highest:
			var count_ties := 0
			for other_id in active_players:
				if score_of(other_id) == highest: count_ties += 1
			if count_ties > 1:
				result = "Empate"
				color = Color(1, 1, 0)
				ties.append(id)
			else:
				result = "¡Ganaste!"
				color = Color(0, 1, 0)
				winners.append(id)
				if is_blackjack:
					if player_losses[id] > 0: player_losses[id] -= 1
					result = "¡BLACKJACK!"
					color = Color(1, 0.84, 0)
		else:
			player_losses[id] += damage
			result = "¡Doble Pérdida!" if damage > 1 else "Perdiste (%d/%d)" % [player_losses[id], max_losses]
			color = Color(1, 0, 0)

		if player_losses[id] >= max_losses:
			result = "ELIMINADO!"
			color = Color(0.3, 0.3, 0.3)
			eliminated.append(id)

		results.append({"id": id, "result": result, "color": color})

	return {
		"results": results, "winners": winners, "ties": ties,
		"eliminated": eliminated, "default_msg": "¡Ronda Multijugador Terminada!"
	}
