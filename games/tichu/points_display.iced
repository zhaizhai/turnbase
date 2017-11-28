{MultiStyleTextBox} = require 'canvas/window.iced'

class PointsDisplay
  constructor: (@gc, @player_id, opts) ->
    @_elt = new MultiStyleTextBox opts
    @_elt.layout()

  elt: -> @_elt

  _card_to_part: (card) ->
    suit = card.suit
    if suit == 'phoenix'
      return {text: 'P', color: 'orange'}
    if suit == 'dragon'
      return {text: 'D', color: 'purple'}

    suit_color = switch suit
      when 'C' then 'green'
      when 'D' then 'blue'
      when 'H' then 'red'
      when 'S' then 'black'
      else null

    value_str = switch card.value
      when 5 then '5'
      when 10 then '10'
      when 13 then 'K'
      else null

    return {text: value_str, color: suit_color}

  set_cards: (cards) ->
    parts = (@_card_to_part card for card in cards)
    @_elt.set_parts parts

  update: ->
    points_taken = @gc.state().players[@player_id].points_taken
    @set_cards points_taken

exports.PointsDisplay = PointsDisplay
