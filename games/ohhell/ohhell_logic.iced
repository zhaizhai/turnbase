exports.winner_idx_of_trick = (played_cards) ->
  winner = { card: played_cards[0], idx: 0 }
  for card, idx in played_cards
    if card.suit is winner.card.suit
      if card.value > winner.card.value
        winner = { card, idx }
    else if card.suit is 'S'
      winner = { card, idx }
  return winner.idx
