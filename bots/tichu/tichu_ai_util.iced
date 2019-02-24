


class StateUtils
  constructor: (@gc, @player_id) ->

  player: -> @gc.state().players[@player_id]

  phx_idx: ->
    player = @gc.state().players[@player_id]
    for card, idx in player.cards
      if card.suit is 'phoenix'
        return idx
    return null

  my_cards: ->
    player = @gc.state().players[@player_id]
    cards = ({suit: c.suit, value: c.value} for c in player.cards)
    idx = @_phx_idx()
    phx = if idx? then cards[idx] else null
    phx?.value = 14 # TODO: hard-coded for now
    return {cards, phx}
