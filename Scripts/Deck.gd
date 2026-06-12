extends Node
class_name Deck

var cards: Array = []

func build_deck():
	cards.clear()
	var suits = ["hearts", "diamonds", "clubs", "spades"]
	var ranks = {
		"A": 11,
		"2": 2, "3": 3, "4": 4, "5": 5, "6": 6,
		"7": 7, "8": 8, "9": 9, "10": 10,
		"J": 10, "Q": 10, "K": 10
	}
	for suit in suits:
		for rank in ranks.keys():
			var card = {"rank": rank, "suit": suit, "value": ranks[rank]}
			cards.append(card)

func shuffle():
	cards.shuffle()

func draw_card() -> Dictionary:
	if cards.is_empty():
		return {}
	return cards.pop_at(0) 
