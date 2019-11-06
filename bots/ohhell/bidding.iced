util_m = require 'shared/util.iced'

exports.get_bid = (hand, tricks_left) ->
  spade_values = []
  winners = 0
  for card in hand
    if card.suit is 'S'
      spade_values.push card.value
    else if card.value >= 13
      winners += 1
  spade_values.sort util_m.by_value
  for val, idx in spade_values
    if val >= 11 or idx >= 3
      winners += 1
  return Math.min winners, tricks_left
