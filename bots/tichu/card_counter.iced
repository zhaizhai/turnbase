logic = require 'games/tichu/tichu_logic.iced'

class CardCounter
  constructor: () ->
    @cards_remaining = logic.make_deck()

  track_play: (@play) ->
    if not @play?
      return
    for card in @play
      index_to_erase = -1
      for i in [0...@cards_remaining.length]
        c = @cards_remaining[i]
        if card.suit == c.suit and (card.suit == 'phoenix' or card.value == c.value)
          index_to_erase = i
          break
      if index_to_erase >= 0
        @cards_remaining.splice(i, 1)

  get_cards_remaining: () ->
    return @cards_remaining.slice()

exports.CardCounter = CardCounter
